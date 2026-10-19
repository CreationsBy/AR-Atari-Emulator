import SwiftUI

struct HoldControl<Content: View>: View {
    let onHold: (Bool) -> Void
    @ViewBuilder var label: () -> Content
    @State private var held = false
    var body: some View {
        label()
            .brightness(held ? 0.15 : 0)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in if !held { held = true; onHold(true) } }
                .onEnded { _ in held = false; onHold(false) })
            .onDisappear { if held { held = false; onHold(false) } }
            .accessibilityAddTraits(.isButton)
    }
}

struct Joystick: View {
    let size: CGFloat
    let sensitivity: Float
    let changed: (UInt16) -> Void
    @State private var offset = CGSize.zero
    var body: some View {
        ZStack {
            Circle().fill(.black.opacity(0.65))
            Circle().stroke(.white.opacity(0.18), lineWidth: 1)
            ForEach(0..<4) { i in
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .bold))
                    .offset(y: -size * 0.34)
                    .rotationEffect(.degrees(Double(i * 90)))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Circle()
                .fill(LinearGradient(colors: [Color(white: 0.3), Color(white: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().stroke(Color.mint.opacity(0.6), lineWidth: 1))
                .frame(width: size * 0.42, height: size * 0.42)
                .shadow(color: .black.opacity(0.7), radius: 6, y: 4)
                .offset(offset)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dx = value.location.x - size / 2, dy = value.location.y - size / 2
                let length = sqrt(dx * dx + dy * dy), radius = size * 0.24
                let scale = length > radius ? radius / length : 1
                offset = CGSize(width: dx * scale, height: dy * scale)
                let threshold = size * 0.10 / CGFloat(sensitivity)
                var mask: UInt16 = 0
                if dx < -threshold { mask |= 1 << 6 }; if dx > threshold { mask |= 1 << 7 }
                if dy < -threshold { mask |= 1 << 4 }; if dy > threshold { mask |= 1 << 5 }
                changed(mask)
            }
            .onEnded { _ in offset = .zero; changed(0) })
        .onDisappear { changed(0) }
        .accessibilityLabel("Joystick. Drag in a direction to move.")
    }
}

struct ControllerOverlay: View {
    @ObservedObject var model: AppModel
    @State private var paddle: Float = 0
    @State private var stickStart: CGSize?
    @State private var fireStart: CGSize?
    var body: some View {
        HStack(alignment: .bottom) {
            if model.settings.leftHanded { fire; Spacer(minLength: 12); movement }
            else { movement; Spacer(minLength: 12); fire }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 10)
        .opacity(Double(model.settings.controlOpacity))
    }
    private var movement: some View {
        VStack(spacing: 8) {
            if model.editControls { moveHandle(stick: true) }
            if model.controller == "paddles" {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PADDLE \(model.localPlayer + 1)").font(.system(size: 10, weight: .bold, design: .monospaced))
                    Slider(value: $paddle, in: -1...1).tint(.mint)
                        .onChange(of: paddle) { model.setPaddle($0) }
                        .onAppear { paddle = model.paddlePosition }
                        .onChange(of: model.localPlayer) { _ in paddle = model.paddlePosition }
                }
                .padding(16).frame(width: 210 * CGFloat(model.settings.controlSize))
                .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 20))
            } else {
                Joystick(size: 136 * CGFloat(model.settings.controlSize), sensitivity: model.settings.sensitivity,
                         changed: model.setDirection)
                    .allowsHitTesting(!model.editControls)
            }
        }
        .offset(x: CGFloat(model.settings.joystickX), y: CGFloat(model.settings.joystickY))
    }
    private var fire: some View {
        VStack(spacing: 8) {
            if model.editControls { moveHandle(stick: false) }
            HoldControl(onHold: model.setFire) {
                ZStack {
                    Circle().fill(.black.opacity(0.5))
                    Circle().fill(LinearGradient(colors: [.orange, Color(red: 0.82, green: 0.23, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .padding(8)
                    Text("FIRE").font(.system(size: 13, weight: .black, design: .monospaced)).foregroundStyle(.white)
                }
                .frame(width: 90 * CGFloat(model.settings.controlSize), height: 90 * CGFloat(model.settings.controlSize))
                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            }
            .allowsHitTesting(!model.editControls)
        }
        .offset(x: CGFloat(model.settings.fireX), y: CGFloat(model.settings.fireY))
    }
    private func moveHandle(stick: Bool) -> some View {
        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
            .padding(12).background(.mint, in: Capsule()).foregroundStyle(.black)
            .gesture(DragGesture().onChanged { value in
                if stick {
                    if stickStart == nil { stickStart = CGSize(width: CGFloat(model.settings.joystickX), height: CGFloat(model.settings.joystickY)) }
                    model.settings.joystickX = Float(min(100, max(-20, stickStart!.width + value.translation.width)))
                    model.settings.joystickY = Float(min(0, max(-220, stickStart!.height + value.translation.height)))
                } else {
                    if fireStart == nil { fireStart = CGSize(width: CGFloat(model.settings.fireX), height: CGFloat(model.settings.fireY)) }
                    model.settings.fireX = Float(min(20, max(-100, fireStart!.width + value.translation.width)))
                    model.settings.fireY = Float(min(0, max(-220, fireStart!.height + value.translation.height)))
                }
            }.onEnded { _ in stickStart = nil; fireStart = nil })
    }
}
