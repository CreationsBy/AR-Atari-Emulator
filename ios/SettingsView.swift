import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Miniature world") {
                    Picker("View", selection: $model.settings.view) {
                        ForEach(["Free AR", "Isometric", "Top Down", "Original"], id: \.self) { Text($0) }
                    }
                    HStack {
                        ForEach(Array(zip(["Tiny", "Small", "Medium", "Large"], [Float(0.12), 0.25, 0.45, 0.8])), id: \.0) { title, width in
                            Button(title) { model.settings.worldWidth = width }.font(.caption.bold()).frame(maxWidth: .infinity)
                        }
                    }.disabled(model.isGuest)
                    slider("Width", value: $model.settings.worldWidth, range: 0.08...1.5, unit: "m").disabled(model.isGuest)
                    slider("Rotation", value: $model.settings.rotation, range: -180...180, unit: "°").disabled(model.isGuest)
                    slider("Tilt", value: $model.settings.tilt, range: -60...60, unit: "°").disabled(model.isGuest)
                    if model.isGuest { Text("The host controls the shared world's size and position.").font(.caption).foregroundStyle(.secondary) }
                    Button(model.isGuest ? "Align with the host again" : "Reposition on a surface") {
                        if model.isGuest { model.requestSharedMap() } else { model.repositionToken += 1 }; dismiss()
                    }
                    Button("Reset AR tracking") { model.resetTrackingToken += 1; dismiss() }
                    Text("Free AR uses your physical camera viewpoint. The other views use a virtual camera for inspecting the same 3D geometry.").font(.caption).foregroundStyle(.secondary)
                }
                Section("3D appearance") {
                    slider("Voxel depth", value: $model.settings.depth, range: 0.2...3, unit: "×").disabled(model.isGuest)
                    slider("Lighting", value: $model.settings.ambient, range: 0...1, unit: "")
                    Picker("Geometry budget", selection: $model.settings.quality) { Text("Low").tag(0); Text("High").tag(1) }.disabled(model.isGuest)
                    Text("Colors come directly from Stella. Mesh faces retain sharp pixel edges. Quality limits geometry; diagnostics report any dropped objects.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Controller") {
                    Picker("Type", selection: $model.settings.controller) {
                        Text("Automatic").tag("auto"); Text("Joystick").tag("joystick"); Text("Paddles").tag("paddles")
                    }.onChange(of: model.settings.controller) { _ in model.releaseInput() }.disabled(model.isMultiplayer)
                    Picker("Touch player", selection: $model.settings.player) { Text("Player 1").tag(0); Text("Player 2").tag(1) }
                        .onChange(of: model.settings.player) { _ in model.releaseInput() }.disabled(model.isMultiplayer)
                    if model.isMultiplayer { Text(model.isGuest ? "This phone controls Player 2." : "This phone controls Player 1. The guest controls Player 2.").font(.caption).foregroundStyle(.mint) }
                    Toggle("Swap left and right controls", isOn: $model.settings.leftHanded)
                    Toggle("Haptic feedback", isOn: $model.settings.haptics)
                    slider("Size", value: $model.settings.controlSize, range: 0.7...1.4, unit: "×")
                    slider("Opacity", value: $model.settings.controlOpacity, range: 0.25...1, unit: "")
                    slider("Sensitivity", value: $model.settings.sensitivity, range: 0.5...2, unit: "×")
                    Button(model.editControls ? "Finish positioning controls" : "Move control positions") { model.editControls.toggle(); dismiss() }
                    Button("Reset control positions") {
                        model.settings.joystickX = 0; model.settings.joystickY = 0; model.settings.fireX = 0; model.settings.fireY = 0
                    }
                    Text("Pair a Bluetooth gamepad in iPhone Settings. A fires; the D-pad or left stick moves. A second controller maps to player 2. For paddles, each player uses a slider or stick.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Console switches") {
                    Toggle("Left difficulty A", isOn: $model.settings.difficultyLeftA)
                    Toggle("Right difficulty A", isOn: $model.settings.difficultyRightA)
                    Toggle("Black and white", isOn: $model.settings.monochrome)
                }.disabled(model.isGuest)
                Section("Original audio") { slider("Volume", value: $model.settings.volume, range: 0...1, unit: "") }
                if model.activeGame != nil && !model.isGuest {
                    Section("Save states") {
                        Button("Save to slot 1") { model.save() }
                        Button("Load slot 1") { model.loadSave(); dismiss() }.disabled(!model.hasSave)
                        Button("Power-cycle cartridge") { model.engine.reset(); dismiss() }
                    }
                    Section("Current conversion") {
                        Text(model.profile.badge).font(.caption.bold()).foregroundStyle(.orange)
                        Text(model.profile.notes).font(.caption)
                        Button("Scene inspector") { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { model.showInspector = true } }
                    }
                }
                Section("About") {
                    Text("Atari Diorama · development prototype").font(.subheadline.bold())
                    Text("Stella 2014 core · GPL-2.0-or-later\nOriginal ROM gameplay and audio remain authoritative. No commercial ROMs are included. Physical iPhone compatibility has not yet been verified.").font(.caption)
                    Link("Project source and license", destination: URL(string: "https://github.com/CreationsBy/AR-Atari-Emulator")!)
                    Link("Stella core source", destination: URL(string: "https://github.com/libretro/stella2014-libretro")!)
                }
            }
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func slider(_ title: String, value: Binding<Float>, range: ClosedRange<Float>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(title); Spacer(); Text(String(format: "%.2f", value.wrappedValue) + unit).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
            Slider(value: value, in: range)
        }.padding(.vertical, 4)
    }
}

struct InspectorView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var exportURL: URL?
    var body: some View {
        NavigationStack {
            List {
                if let s = model.snapshot {
                    Section("Pipeline") {
                        row("Emulator cadence", String(format: "%.2f FPS", s.fps))
                        row("Renderer", String(format: "%.1f FPS", model.arFPS))
                        row("Reconstruction", String(format: "%.3f ms", s.analysisMS))
                        row("Frame", "\(s.number)")
                        row("Geometry", "\(s.objects.count) objects · \(s.boxes.count) boxes")
                        row("TIA writes", "\(s.traceCount) · \(s.traceDropped) dropped")
                        row("Budget drops", "\(s.droppedObjects)")
                        row("Scene errors", "\(model.sceneErrors)")
                        Text("Emulator cadence is the core's requested rate; the renderer rate is measured. This is diagnostic data, not a device performance certification.").font(.caption).foregroundStyle(.secondary)
                    }
                    Section("ROM") {
                        Text(model.activeGame?.id ?? "").font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                        Text(model.profile.id).font(.caption.monospaced())
                        Text(model.profile.notes).font(.caption)
                    }
                    Section("RIOT RAM · read only") {
                        ForEach(0..<8) { line in
                            Text(String(format: "%02X  ", 0x80 + line * 16) + s.ram[(line*16)..<(line*16+16)].map { String(format: "%02X", $0) }.joined(separator: " "))
                                .font(.system(size: 9, design: .monospaced)).textSelection(.enabled)
                        }
                    }
                    Section("Reconstructed components") {
                        ForEach(Array(s.objects.prefix(64).enumerated()), id: \.offset) { _, object in
                            VStack(alignment: .leading, spacing: 5) {
                                Text("#\(object.id) · TIA \(object.color_index) · role \(object.role)").font(.caption.bold())
                                Text(String(format: "x %.0f y %.0f · %.0f × %.0f px · %u prisms", object.pixel_x, object.pixel_y, object.pixel_width, object.pixel_height, object.box_count)).font(.caption2)
                                Text(String(format: "mask %016llx", object.pattern)).font(.caption2.monospaced()).textSelection(.enabled)
                            }
                        }
                    }
                    if let url = exportURL { ShareLink(item: url) { Label("Export diagnostics", systemImage: "square.and.arrow.up") } }
                } else { Text("Load a cartridge to inspect the scene.") }
            }
            .navigationTitle("Scene inspector").navigationBarTitleDisplayMode(.inline)
            .onAppear { exportURL = model.exportDiagnostics() }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func row(_ label: String, _ value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).foregroundStyle(.secondary).font(.caption.monospacedDigit()) }
    }
}
