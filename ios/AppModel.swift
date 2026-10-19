import SwiftUI
import GameController
import Combine
import AVFoundation
import QuartzCore

@MainActor final class AppModel: NSObject, ObservableObject {
    @Published var games: [LibraryGame] = Storage.read([LibraryGame].self, name: "library.json") ?? []
    @Published var settings: AppSettings = Storage.read(AppSettings.self, name: "settings.json") ?? AppSettings() {
        didSet {
            try? Storage.write(settings, name: "settings.json")
            audio.volume = settings.volume
            engine.configure(depth: settings.depth, quality: settings.quality, controller: controller)
            emitInput()
        }
    }
    @Published var activeGame: LibraryGame?
    @Published var profile = GameProfile.generic
    @Published var snapshot: FrameSnapshot?
    @Published var paused = true
    @Published var error: String?
    @Published var toast: String?
    @Published var loading = false
    @Published var showSettings = false
    @Published var showInspector = false
    @Published var showOriginal = false
    @Published var editControls = false
    @Published var placementMessage = "Move your phone slowly to find a table"
    @Published var placed = false
    @Published var arFPS: Double = 0
    @Published var sceneErrors = 0
    @Published var resetTrackingToken = 0
    @Published var repositionToken = 0

    let engine = EmulationEngine()
    let audio = AudioOutput()
    let profiles = Storage.profiles()
    private var displayLink: CADisplayLink?
    private var busy = false
    private var directions: [UInt16] = [0, 0]
    private var fires = [false, false]
    private var gamepadMasks: [UInt16] = [0, 0]
    private var paddleValues: [Float] = [0, 0]
    private var consoleHeld: UInt16 = 0
    private var gamepadObservers: [NSObjectProtocol] = []

    var controller: String { settings.controller == "auto" ? profile.controller : settings.controller }
    var paddlePosition: Float { paddleValues[settings.player] }
    var saveURL: URL? {
        guard let game = activeGame else { return nil }
        return try? Storage.directory("Saves").appendingPathComponent(game.id + "-slot1.json")
    }
    var hasSave: Bool { saveURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false }
    func profile(for game: LibraryGame) -> GameProfile {
        profiles.first { $0.sha256.contains(game.id) || $0.md5.contains(game.md5) } ?? .generic
    }
    override init() {
        super.init()
        audio.volume = settings.volume
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
        for name in [Notification.Name.GCControllerDidConnect, Notification.Name.GCControllerDidDisconnect] {
            gamepadObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.configureGamepads() }
            })
        }
        gamepadObservers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.setPaused(true) }
        })
        configureGamepads()
    }
    @objc private func tick(_ link: CADisplayLink) {
        guard activeGame != nil, !paused, !loading, !busy else { return }
        busy = true
        engine.advance(now: link.timestamp) { [weak self] snapshot in
            guard let self else { return }
            self.busy = false
            if let snapshot { self.snapshot = snapshot }
        }
    }
    func importROM(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            guard ["a26", "bin", "rom"].contains(url.pathExtension.lowercased()) else {
                throw DioramaError.message("Choose a raw .a26, .bin or .rom Atari 2600 cartridge. Unzip archives first.")
            }
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard (2048...1_048_576).contains(size) else { throw DioramaError.message("Choose a raw cartridge between 2 KB and 1 MB.") }
            let data = try Data(contentsOf: url)
            let sha = Storage.sha(data), md5 = Storage.md5(data)
            let matched = profiles.first { $0.sha256.contains(sha) || $0.md5.contains(md5) }
            let game = LibraryGame(id: sha, md5: md5, title: matched?.title ?? url.deletingPathExtension().lastPathComponent,
                filename: url.lastPathComponent, importedAt: Date(), byteCount: data.count)
            try data.write(to: Storage.directory("ROMs").appendingPathComponent(sha + ".a26"), options: .atomic)
            if !games.contains(where: { $0.id == sha }) { games.insert(game, at: 0) }
            try Storage.write(games, name: "library.json")
            play(game, data: data)
        } catch { self.error = error.localizedDescription }
    }
    func demo() {
        do {
            guard let url = Bundle.main.url(forResource: "TabletopTest", withExtension: "a26") else { throw DioramaError.message("Test cartridge is missing from this build.") }
            let data = try Data(contentsOf: url)
            play(LibraryGame(id: Storage.sha(data), md5: Storage.md5(data), title: "Tabletop Test", filename: "TabletopTest.a26", importedAt: Date(), byteCount: data.count), data: data)
        } catch { self.error = error.localizedDescription }
    }
    func play(_ game: LibraryGame, data supplied: Data? = nil) {
        guard !loading else { return }
        do {
            let data = try supplied ?? Data(contentsOf: Storage.directory("ROMs").appendingPathComponent(game.id + ".a26"))
            setPaused(true); audio.stop(); loading = true; snapshot = nil; placed = false
            let chosen = profile(for: game)
            profile = chosen
            let selectedController = settings.controller == "auto" ? chosen.controller : settings.controller
            engine.load(data: data, filename: game.filename, profile: chosen, controller: selectedController) { [weak self] result in
                guard let self else { return }
                self.loading = false
                switch result {
                case .success(let rate):
                    self.activeGame = game
                    self.engine.configure(depth: self.settings.depth, quality: self.settings.quality, controller: self.controller)
                    do { try self.audio.start(sampleRate: rate) } catch { self.error = "Audio: " + error.localizedDescription }
                    self.repositionToken += 1
                    self.audio.pause()
                    self.engine.advance(now: CACurrentMediaTime()) { [weak self] snapshot in self?.snapshot = snapshot }
                case .failure(let error): self.error = error.localizedDescription
                }
            }
        } catch { self.error = error.localizedDescription }
    }
    func setPaused(_ value: Bool) {
        paused = value
        if value { audio.pause(); releaseInput() }
        else { engine.resumeClock(); do { try audio.resume() } catch { self.error = error.localizedDescription } }
    }
    func exit() { setPaused(true); audio.stop(); activeGame = nil; snapshot = nil; showOriginal = false; placed = false }
    func setDirection(_ mask: UInt16) { directions[settings.player] = mask; emitInput() }
    func setFire(_ held: Bool) {
        if held && !fires[settings.player] && settings.haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        fires[settings.player] = held; emitInput()
    }
    func setPaddle(_ value: Float) { paddleValues[settings.player] = min(1, max(-1, value)); emitInput() }
    func setConsole(_ bit: Int, held: Bool) {
        if held { consoleHeld |= 1 << bit } else { consoleHeld &= ~(1 << bit) }
        emitInput()
    }
    func releaseInput() {
        directions = [0, 0]; fires = [false, false]; gamepadMasks = [0, 0]; consoleHeld = 0
        emitInput()
    }
    private func emitInput() {
        var switches = consoleHeld
        switches |= UInt16(1 << (settings.difficultyLeftA ? 10 : 12))
        switches |= UInt16(1 << (settings.difficultyRightA ? 11 : 13))
        switches |= UInt16(1 << (settings.monochrome ? 15 : 14))
        if controller == "paddles" {
            let fire0 = fires[0] || gamepadMasks[0] & 1 != 0
            let fire1 = fires[1] || gamepadMasks[1] & 1 != 0
            let mask = switches | (fire0 ? UInt16(1 << 8) : 0) | (fire1 ? 1 : 0)
            ad_set_input(0, paused ? 0 : mask, Int16(paddleValues[0] * 32767), Int16(paddleValues[1] * 32767))
            ad_set_input(1, 0, 0, 0)
        } else {
            for port in 0..<2 {
                let mask = directions[port] | (fires[port] ? 1 : 0) | gamepadMasks[port] | (port == 0 ? switches : 0)
                ad_set_input(UInt32(port), paused ? 0 : mask, 0, 0)
            }
        }
    }
    func save() {
        guard let game = activeGame, let url = saveURL else { return }
        let profileID = profile.id, controller = controller
        engine.save { [weak self] result in
            do {
                let data = try result.get()
                let save = SavedGame(romSHA256: game.id, coreRevision: Storage.coreRevision, profileID: profileID, created: Date(), emulator: data, controller: controller)
                try JSONEncoder().encode(save).write(to: url, options: .atomic)
                self?.toast = "State saved"
            } catch { self?.error = error.localizedDescription }
        }
    }
    func loadSave() {
        guard let url = saveURL, let game = activeGame else { return }
        do {
            let saved = try JSONDecoder().decode(SavedGame.self, from: Data(contentsOf: url))
            guard saved.formatVersion == 1, saved.romSHA256 == game.id, saved.coreRevision == Storage.coreRevision,
                  saved.profileID == profile.id, saved.controller == controller else {
                throw DioramaError.message("This state belongs to a different ROM, core, profile or controller. Restore its original configuration first.")
            }
            engine.restore(saved.emulator) { [weak self] result in
                switch result { case .success: self?.toast = "State restored"; case .failure(let error): self?.error = error.localizedDescription }
            }
        } catch { self.error = error.localizedDescription }
    }
    func exportDiagnostics() -> URL? {
        guard let s = snapshot else { return nil }
        let info: [String: Any] = ["core": Storage.coreRevision, "rom": activeGame?.id ?? "", "profile": profile.id,
            "compatibility": profile.compatibility, "frame": s.number, "fps": s.fps, "analysisMS": s.analysisMS,
            "objects": s.objects.count, "boxes": s.boxes.count, "traceWrites": s.traceCount,
            "traceDropped": s.traceDropped, "objectsDropped": s.droppedObjects, "arFPS": arFPS,
            "sceneErrors": sceneErrors, "audioDropped": ad_audio_dropped(), "ramHex": s.ram.map { String(format: "%02x", $0) }.joined()]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("atari-diagnostics.json")
        do { try JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic); return url }
        catch { self.error = error.localizedDescription; return nil }
    }
    private func configureGamepads() {
        gamepadMasks = [0, 0]; emitInput()
        for (port, controller) in GCController.controllers().prefix(2).enumerated() {
            guard let pad = controller.extendedGamepad else { continue }
            pad.valueChangedHandler = { [weak self] pad, _ in
                var mask: UInt16 = 0
                let x = pad.leftThumbstick.xAxis.value, y = pad.leftThumbstick.yAxis.value
                if pad.dpad.up.isPressed || y > 0.3 { mask |= 1 << 4 }
                if pad.dpad.down.isPressed || y < -0.3 { mask |= 1 << 5 }
                if pad.dpad.left.isPressed || x < -0.3 { mask |= 1 << 6 }
                if pad.dpad.right.isPressed || x > 0.3 { mask |= 1 << 7 }
                if pad.buttonA.isPressed { mask |= 1 }
                if pad.buttonMenu.isPressed { mask |= 1 << 3 }
                let value = mask
                Task { @MainActor in
                    self?.gamepadMasks[port] = value
                    if self?.controller == "paddles" { self?.paddleValues[port] = x }
                    self?.emitInput()
                }
            }
        }
    }
}
