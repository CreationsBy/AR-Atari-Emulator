import SwiftUI
import UniformTypeIdentifiers

@main struct AtariDioramaApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { phase in if phase == .background { model.applicationInactive() } else if phase == .inactive { model.setPaused(true) } }
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var importing = false
    var body: some View {
        ZStack {
            if model.activeGame != nil { playView }
            else { library }
            if model.loading {
                Color.black.opacity(0.7).ignoresSafeArea()
                ProgressView("Loading cartridge…").padding(30).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
            if let toast = model.toast {
                VStack { Spacer(); Text(toast).font(.subheadline.bold()).padding(16).background(.ultraThinMaterial, in: Capsule()).padding(.bottom, 210) }
                    .allowsHitTesting(false)
                    .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { if model.toast == toast { model.toast = nil } } }
            }
        }
        .tint(.mint)
        .sheet(isPresented: $model.showSettings) { SettingsView(model: model) }
        .sheet(isPresented: $model.showInspector) { InspectorView(model: model) }
        .sheet(isPresented: $model.showMultiplayer) { MultiplayerView(model: model) }
        .onChange(of: model.showMultiplayer) { if $0 { model.releaseInput() } }
        .onChange(of: model.showSettings) { if $0 { model.setPaused(true) } }
        .onChange(of: model.showInspector) { if $0 { model.setPaused(true) } }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls): if let url = urls.first { model.importROM(url) }
            case .failure(let error): model.error = error.localizedDescription
            }
        }
        .alert("Atari Diorama", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private var library: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(spacing: 10) {
                        Image(systemName: "cube.transparent.fill").font(.system(size: 28)).foregroundStyle(.mint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ATARI DIORAMA").font(.system(size: 15, weight: .black, design: .monospaced)).tracking(2)
                            Text("A NEW DIMENSION OF PLAY").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { model.showSettings = true } label: { Image(systemName: "slider.horizontal.3").padding(12).background(.white.opacity(0.06), in: Circle()) }
                            .accessibilityLabel("Settings")
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Small worlds.\nOriginal games.")
                            .font(.system(size: 40, weight: .bold, design: .rounded)).tracking(-1.5)
                        Text("Real cartridges. Real emulation.\nA miniature world on your table.")
                            .font(.subheadline).foregroundStyle(Color(white: 0.67)).lineSpacing(5)
                        DioramaMark().frame(height: 180).frame(maxWidth: .infinity)
                        Button { model.demo() } label: {
                            HStack { Image(systemName: "play.fill"); Text("Try the test cartridge"); Spacer(); Image(systemName: "arrow.up.right") }
                                .font(.subheadline.bold()).foregroundStyle(.black).padding(18).background(.mint, in: RoundedRectangle(cornerRadius: 14))
                        }
                        Text("ORIGINAL HOMEBREW INCLUDED · NO COMMERCIAL ROMS")
                            .font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                    .padding(24)
                    .background(LinearGradient(colors: [Color(red: 0.07, green: 0.13, blue: 0.15), Color(red: 0.05, green: 0.07, blue: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 25))
                    HStack {
                        Button { model.showMultiplayer = true } label: {
                            Label("Local multiplayer · join as Player 2", systemImage: "person.2.fill").font(.subheadline.bold())
                        }
                    }
                    HStack {
                        Text("Your cartridges").font(.title3.bold())
                        Spacer()
                        Button { importing = true } label: { Label("Import ROM", systemImage: "plus").font(.subheadline.bold()) }
                    }
                    if model.games.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.down").font(.title).foregroundStyle(.mint)
                            Text("Your next world starts here").font(.headline)
                            Text("Import a legally obtained .a26 or .bin file from Files. Unprofiled games use experimental 3D conversion.")
                                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity).padding(28).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
                    }
                    ForEach(model.games) { game in
                        let p = model.profile(for: game)
                        Button { model.play(game) } label: {
                            HStack(spacing: 16) {
                                Image(systemName: p.controller == "paddles" ? "slider.horizontal.below.square.filled.and.square" : "gamecontroller.fill")
                                    .font(.title2).foregroundStyle(.mint).frame(width: 54, height: 64).background(.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(game.title).font(.headline).foregroundStyle(.white)
                                    Text(p.badge).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.orange)
                                    Text("\(game.byteCount / 1024) KB · \(p.controller.capitalized) · save states")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(); Image(systemName: "play.fill").foregroundStyle(.mint)
                            }.padding(14).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain)
                    }
                    Text("Powered by Stella 2014 · Independent GPL software\nNot affiliated with Atari or Geod Studio.")
                        .font(.caption2).foregroundStyle(.secondary).lineSpacing(4).padding(.bottom, 20)
                }.padding(22)
            }
            .background(Color(red: 0.025, green: 0.035, blue: 0.05))
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    private var playView: some View {
        ZStack {
            DioramaView(model: model)
                .id(model.settings.view == "Free AR")
                .ignoresSafeArea()
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Button { model.exit() } label: { Image(systemName: "chevron.left").padding(10) }.accessibilityLabel("Back to library")
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.activeGame?.title ?? "").font(.subheadline.bold()).lineLimit(1)
                        Text(model.profile.badge).font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(.orange)
                    }
                    Spacer(minLength: 0)
                    Button { model.setPaused(!model.paused) } label: { Image(systemName: model.paused ? "play.fill" : "pause.fill").padding(10) }.disabled(model.hostIsPaused)
                        .accessibilityLabel(model.paused ? "Resume" : "Pause")
                    Menu {
                        Button("Local multiplayer", systemImage: "person.2.fill") { model.showMultiplayer = true }
                        Button("Save state", systemImage: "square.and.arrow.down") { model.save() }.disabled(model.isGuest)
                        Button("Load state", systemImage: "arrow.counterclockwise") { model.loadSave() }.disabled(!model.hasSave)
                        Button(model.showOriginal ? "Hide original view" : "Compare original view", systemImage: "rectangle.on.rectangle") { model.showOriginal.toggle() }
                        Button(model.isGuest ? "Align shared table again" : "Reposition world", systemImage: "move.3d") {
                            if model.isGuest { model.requestSharedMap() } else { model.repositionToken += 1 }
                        }
                        Button("Inspect scene", systemImage: "waveform.path.ecg") { model.showInspector = true }
                        Button("Settings", systemImage: "slider.horizontal.3") { model.showSettings = true }
                    } label: { Image(systemName: "ellipsis").padding(12) }.accessibilityLabel("Game menu")
                }
                .padding(.horizontal, 8).padding(.vertical, 4).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                HStack(spacing: 6) {
                    Circle().fill(model.placed ? Color.mint : Color.orange).frame(width: 5, height: 5)
                    Text(model.placementMessage).font(.caption2).lineLimit(2)
                    Spacer(minLength: 0)
                }.padding(.horizontal, 12).padding(.vertical, 7).background(.black.opacity(0.55), in: Capsule())
                if model.isMultiplayer {
                    Button { model.showMultiplayer = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill")
                            Text(model.isHosting ? "P1 · " + RoomCode.display(model.network.code) : "P2 · " + model.network.status)
                            Spacer(minLength: 0)
                            if !model.spatialStatus.isEmpty { Text(model.spatialStatus).lineLimit(2) }
                        }.font(.caption2).padding(10).background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                }
                if let s = model.snapshot {
                    if model.showOriginal {
                        PixelFrame(snapshot: s).aspectRatio(4/3, contentMode: .fit)
                            .frame(maxWidth: 300, maxHeight: 210).background(.black).clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if model.profile.showsSeparateHUD {
                        PixelFrame(snapshot: s, fraction: Double(model.profile.hudTop)).frame(width: 200, height: 34).background(.black.opacity(0.6))
                    }
                }
                Spacer(minLength: 0)
                if model.paused && model.placed {
                    if model.hostIsPaused {
                        Text("Host paused the game").font(.headline).padding(16).background(.black.opacity(0.65), in: Capsule())
                    } else {
                        Button { model.setPaused(false) } label: {
                            Label(model.isGuest ? "Resume my controls" : "Resume game", systemImage: "play.fill").font(.headline).foregroundStyle(.black).padding(16).background(.mint, in: Capsule())
                        }
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 14) {
                    if !model.isGuest {
                        HoldControl(onHold: { model.setConsole(2, held: $0) }) { Text("SELECT").font(.system(size: 10, weight: .bold, design: .monospaced)).padding(12).background(.black.opacity(0.65), in: Capsule()) }
                        HoldControl(onHold: { model.setConsole(3, held: $0) }) { Text("RESET").font(.system(size: 10, weight: .bold, design: .monospaced)).padding(12).background(.black.opacity(0.65), in: Capsule()) }
                    }
                    Spacer()
                    Text("P\(model.localPlayer + 1)").font(.system(size: 10, weight: .bold, design: .monospaced)).padding(12).background(.black.opacity(0.65), in: Circle())
                }.padding(.horizontal, 12)
                if model.editControls {
                    Button("Done moving controls") { model.editControls = false }
                        .font(.caption.bold()).padding(8).background(.black.opacity(0.65), in: Capsule())
                }
                ControllerOverlay(model: model).allowsHitTesting(!model.paused || model.editControls)
            }.padding(.horizontal, 12).padding(.top, 4)
        }.foregroundStyle(.white)
    }
}

struct PixelFrame: View {
    let snapshot: FrameSnapshot
    var fraction = 1.0
    private var image: CGImage? {
        guard let provider = CGDataProvider(data: snapshot.pixels as CFData),
              let image = CGImage(width: snapshot.width, height: snapshot.height, bitsPerComponent: 8,
                bitsPerPixel: 32, bytesPerRow: snapshot.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        return fraction == 1 ? image : image.cropping(to: CGRect(x: 0, y: 0, width: CGFloat(snapshot.width), height: CGFloat(max(1, Int(Double(snapshot.height) * fraction)))))
    }
    var body: some View {
        if let image { Image(decorative: image, scale: 1).resizable().interpolation(.none) }
    }
}

struct DioramaMark: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 220, size.height / 130)
            func point(_ x: Double, _ y: Double, _ z: Double) -> CGPoint {
                CGPoint(x: size.width / 2 + (x-z)*scale*0.85, y: size.height/2 + (x+z)*scale*0.35-y*scale)
            }
            func block(_ x: Double, _ z: Double, _ w: Double, _ d: Double, _ h: Double, _ color: Color) {
                let faces: [([CGPoint], Color)] = [
                    ([point(x,0,z+d),point(x+w,0,z+d),point(x+w,h,z+d),point(x,h,z+d)], color.opacity(0.5)),
                    ([point(x+w,0,z),point(x+w,0,z+d),point(x+w,h,z+d),point(x+w,h,z)], color.opacity(0.75)),
                    ([point(x,h,z),point(x+w,h,z),point(x+w,h,z+d),point(x,h,z+d)], color)]
                for (points, fill) in faces {
                    var path = Path(); path.addLines(points); path.closeSubpath(); context.fill(path, with: .color(fill))
                }
            }
            block(-68,-48,136,96,5,Color(red: 0.10, green: 0.20, blue: 0.22))
            block(-64,-44,128,6,25,.mint)
            block(-64,-38,6,75,25,.mint)
            block(58,-38,6,75,25,.mint)
            block(-14,-8,26,6,19,.mint)
            block(6,-8,6,30,19,.mint)
            block(-34,9,12,12,20,.orange)
            block(30,-22,10,10,15,.cyan)
            block(-64,38,128,6,25,.mint)
        }
        .accessibilityLabel("Illustration of a miniature voxel diorama")
    }
}
