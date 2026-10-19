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
            if !isGuest { engine.configure(depth: settings.depth, quality: settings.quality, controller: controller) }
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
    @Published var showMultiplayer = false
    @Published var sharedPresentation: SharedPresentation?
    @Published var sharedWorldMap: Data?
    @Published var shareMapToken = 0
    @Published var spatialStatus = ""

    let engine = EmulationEngine()
    let audio = AudioOutput()
    let network = LocalSession()
    let profiles = Storage.profiles()
    private var displayLink: CADisplayLink?
    private var busy = false
    private var directions: [UInt16] = [0, 0]
    private var fires = [false, false]
    private var gamepadMasks: [UInt16] = [0, 0]
    private var paddleValues: [Float] = [0, 0]
    private var consoleHeld: UInt16 = 0
    private var gamepadObservers: [NSObjectProtocol] = []
    private var networkObservation: AnyCancellable?
    private var remoteInput = RemoteInput()
    private var lastRemoteInput = Date.distantPast
    private var inputSequence: UInt64 = 0
    private var remoteController = "joystick"
    private var remotePaused = true
    private var guestSuspended = false
    private var guestSampleRate: Double = 31400
    private let remoteDecodeQueue = DispatchQueue(label: "atari.received-scene", qos: .userInteractive)

    var isGuest: Bool { network.role == .guest }
    var isHosting: Bool { network.role == .host }
    var isMultiplayer: Bool { network.role != .none }
    var hostIsPaused: Bool { isGuest && remotePaused }
    var localPlayer: Int { isGuest ? 1 : (isHosting ? 0 : settings.player) }
    var controller: String { isGuest ? remoteController : (settings.controller == "auto" ? profile.controller : settings.controller) }
    var presentation: SharedPresentation { isGuest ? (sharedPresentation ?? SharedPresentation(settings)) : SharedPresentation(settings) }
    var paddlePosition: Float { paddleValues[localPlayer] }
    var saveURL: URL? {
        guard let game = activeGame else { return nil }
        return try? Storage.directory("Saves").appendingPathComponent(game.id + "-slot1.json")
    }
    var hasSave: Bool { !isGuest && (saveURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false) }
    func profile(for game: LibraryGame) -> GameProfile {
        profiles.first { $0.sha256.contains(game.id) || $0.md5.contains(game.md5) } ?? .generic
    }
    override init() {
        super.init()
        networkObservation = network.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        network.onConnected = { [weak self] in self?.networkConnected() }
        network.onMessage = { [weak self] type, data in self?.receiveNetwork(type, data) }
        network.onDisconnect = { [weak self] reason in
            guard let self else { return }
            self.remoteInput = RemoteInput(); self.emitInput()
            if self.isGuest {
                self.audio.stop(); self.paused = true; self.activeGame = nil; self.snapshot = nil
                self.sharedWorldMap = nil; self.showMultiplayer = true
            } else { self.setPaused(true) }
            self.toast = reason
        }
        network.onTick = { [weak self] in self?.networkTick() }
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
        guard !isGuest, activeGame != nil, !paused, !loading, !busy else { return }
        busy = true
        engine.advance(now: link.timestamp) { [weak self] snapshot in
            guard let self else { return }
            self.busy = false
            guard !self.isGuest else { return }
            if let snapshot { self.snapshot = snapshot; self.broadcast(snapshot) }
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
        if isMultiplayer { leaveMultiplayer() }
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
        if isGuest {
            guestSuspended = value; applyGuestPause()
            if value { releaseInput() }
            return
        }
        paused = value
        if value { audio.pause(); releaseInput() }
        else { engine.resumeClock(); do { try audio.resume() } catch { self.error = error.localizedDescription } }
        if let snapshot { broadcast(snapshot, includeAudio: false) }
    }
    func exit() { leaveMultiplayer(); setPaused(true); audio.stop(); activeGame = nil; snapshot = nil; showOriginal = false; placed = false }
    func setDirection(_ mask: UInt16) { directions[localPlayer] = mask; emitInput() }
    func setFire(_ held: Bool) {
        if held && !fires[localPlayer] && settings.haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        fires[localPlayer] = held; emitInput()
    }
    func setPaddle(_ value: Float) { paddleValues[localPlayer] = min(1, max(-1, value)); emitInput() }
    func setConsole(_ bit: Int, held: Bool) {
        guard !isGuest else { return }
        if held { consoleHeld |= 1 << bit } else { consoleHeld &= ~(1 << bit) }
        emitInput()
    }
    func releaseInput() {
        directions = [0, 0]; fires = [false, false]; gamepadMasks = [0, 0]; consoleHeld = 0
        emitInput()
    }
    private func emitInput() {
        if isGuest { sendGuestInput(); return }
        var switches = consoleHeld
        switches |= UInt16(1 << (settings.difficultyLeftA ? 10 : 12))
        switches |= UInt16(1 << (settings.difficultyRightA ? 11 : 13))
        switches |= UInt16(1 << (settings.monochrome ? 15 : 14))
        if controller == "paddles" {
            let fire0 = fires[0] || gamepadMasks[0] & 1 != 0
            let fire1 = isHosting ? (remoteInput.safeButtons & 1 != 0) : (fires[1] || gamepadMasks[1] & 1 != 0)
            let mask = switches | (fire0 ? UInt16(1 << 8) : 0) | (fire1 ? 1 : 0)
            let paddle2 = isHosting ? remoteInput.safePaddle : paddleValues[1]
            ad_set_input(0, paused ? 0 : mask, Int16(paddleValues[0] * 32767), Int16(paddle2 * 32767))
            ad_set_input(1, 0, 0, 0)
        } else {
            for port in 0..<2 {
                let mask = isHosting && port == 1 ? remoteInput.safeButtons :
                    (directions[port] | (fires[port] ? 1 : 0) | gamepadMasks[port] | (port == 0 ? switches : 0))
                ad_set_input(UInt32(port), paused ? 0 : mask, 0, 0)
            }
        }
    }
    func save() {
        guard !isGuest else { return }
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
        guard !isGuest else { return }
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
        for (index, controller) in GCController.controllers().prefix(2).enumerated() {
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
                    guard let self else { return }
                    if self.isMultiplayer && index > 0 { return }
                    let port = self.isGuest ? 1 : index
                    self.gamepadMasks[port] = value
                    if self.controller == "paddles" { self.paddleValues[port] = x }
                    self.emitInput()
                }
            }
        }
    }

    func hostMultiplayer() {
        guard activeGame != nil, !isGuest, !loading else { return }
        releaseInput(); remoteInput = RemoteInput(); sharedWorldMap = nil
        network.host(); engine.streamAudio(true)
        spatialStatus = placed ? "Ready to share this table" : "Place the diorama before Player 2 aligns"
    }
    func joinMultiplayer(_ code: String) {
        setPaused(true); audio.stop(); activeGame = nil; snapshot = nil; placed = false
        sharedWorldMap = nil; sharedPresentation = nil; guestSuspended = false; remotePaused = true
        remoteInput = RemoteInput(); inputSequence = 0; engine.streamAudio(false)
        network.join(code)
    }
    func leaveMultiplayer() {
        let wasGuest = isGuest
        releaseInput(); network.stop(); engine.streamAudio(false); remoteInput = RemoteInput()
        sharedWorldMap = nil; sharedPresentation = nil; spatialStatus = ""
        if wasGuest { audio.stop(); activeGame = nil; snapshot = nil; placed = false; paused = true }
        emitInput()
    }
    func applicationInactive() {
        setPaused(true)
        if isMultiplayer {
            leaveMultiplayer()
            toast = "Local multiplayer ended because the app left the foreground. Host or join again to reconnect."
        }
    }
    private func networkConnected() {
        remoteInput = RemoteInput(); lastRemoteInput = .distantPast
        if isHosting, let game = activeGame {
            let welcome = RoomWelcome(title: game.title, profile: profile, controller: controller,
                sampleRate: snapshot?.sampleRate ?? 31400, paused: paused, presentation: presentation)
            do { network.send(.welcome, try RoomCodec.plist(welcome)) }
            catch { network.disconnect(error.localizedDescription) }
            if let snapshot { broadcast(snapshot, includeAudio: false) }
            shareMapToken += 1
        }
    }
    private func networkTick() {
        if isGuest { sendGuestInput() }
        else if isHosting {
            if Date().timeIntervalSince(lastRemoteInput) > 0.5, remoteInput.buttons != 0 || remoteInput.paddle != 0 {
                remoteInput = RemoteInput(); emitInput()
            }
            if paused, let snapshot { broadcast(snapshot, includeAudio: false) }
        }
    }
    private func sendGuestInput() {
        guard network.connected else { return }
        inputSequence &+= 1
        let input = RemoteInput(buttons: paused ? 0 : (directions[1] | (fires[1] ? 1 : 0) | gamepadMasks[1]),
            paddle: paused ? 0 : paddleValues[1], sequence: inputSequence)
        if let body = try? RoomCodec.plist(input) { network.send(.input, body) }
    }
    private func broadcast(_ snapshot: FrameSnapshot, includeAudio: Bool = true) {
        guard isHosting, network.connected else { return }
        var frame = snapshot
        if !includeAudio { frame.pcm = Data() }
        network.offer(SharedFrame(snapshot: frame, paused: paused, presentation: presentation))
    }
    private func receiveNetwork(_ type: RoomMessage, _ data: Data) {
        do {
            switch type {
            case .welcome where isGuest:
                let welcome = try RoomCodec.read(RoomWelcome.self, data)
                try welcome.presentation.validate()
                guard welcome.title.count <= 256, ["joystick", "paddles"].contains(welcome.controller),
                      (8000...96000).contains(welcome.sampleRate), welcome.profile.rules.count <= 128,
                      welcome.profile.schemaVersion == 1, (0..<1).contains(welcome.profile.hudTop),
                      (0..<1).contains(welcome.profile.hudBottom), welcome.profile.hudTop + welcome.profile.hudBottom < 1 else {
                    throw MultiplayerError.invalid("Invalid host game description.")
                }
                remoteController = welcome.controller; profile = welcome.profile
                sharedPresentation = welcome.presentation; remotePaused = welcome.paused
                guestSampleRate = welcome.sampleRate
                activeGame = LibraryGame(id: "remote-session", md5: "", title: welcome.title,
                    filename: "", importedAt: Date(), byteCount: 0)
                ad_audio_clear(); try audio.start(sampleRate: guestSampleRate); audio.pause()
                showMultiplayer = false; spatialStatus = "Waiting for the host's table map"
                applyGuestPause(); network.send(.mapRequest)
            case .frame where isGuest:
                let token = network.connectionToken
                remoteDecodeQueue.async {
                    let result = Result { try SharedFrame.decode(data) }
                    DispatchQueue.main.async {
                        guard self.isGuest, self.network.connected, self.network.connectionToken == token else { return }
                        do {
                            let frame = try result.get()
                            self.snapshot = frame.snapshot; self.sharedPresentation = frame.presentation
                            self.remotePaused = frame.paused; self.applyGuestPause()
                            if !self.paused, !frame.snapshot.pcm.isEmpty {
                                self.engine.receiveAudio(frame.snapshot.pcm)
                            }
                            self.network.send(.frameAck)
                        } catch { self.network.disconnect(error.localizedDescription) }
                    }
                }
            case .input where isHosting:
                let input = try RoomCodec.read(RemoteInput.self, data)
                if input.sequence > remoteInput.sequence {
                    remoteInput = input; lastRemoteInput = Date(); emitInput()
                }
            case .worldMap where isGuest:
                sharedWorldMap = data
            case .mapRequest where isHosting:
                shareMapToken += 1
            case .aligned where isHosting:
                spatialStatus = "Both players aligned to the shared table"
            case .placementPending where isGuest:
                sharedWorldMap = nil; placed = false; spatialStatus = "Waiting for the host to place the diorama"
                applyGuestPause(); releaseInput()
            default: break
            }
        } catch { network.disconnect(error.localizedDescription) }
    }
    private func applyGuestPause() {
        guard isGuest else { return }
        let shouldPause = remotePaused || guestSuspended || !placed
        if paused != shouldPause {
            paused = shouldPause
            if paused { audio.pause(); sendGuestInput() }
            else { do { try audio.resume() } catch { self.error = error.localizedDescription } }
        }
    }
    func guestAligned() {
        placed = true; guestSuspended = false; applyGuestPause(); network.send(.aligned)
        spatialStatus = "Shared table aligned · you are Player 2"
    }
    func requestSharedMap() {
        if isGuest { network.send(.mapRequest); spatialStatus = "Requesting the host's table map…" }
        else if isHosting { shareMapToken += 1 }
    }
}
