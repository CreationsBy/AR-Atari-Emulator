import SwiftUI
import RealityKit
import ARKit
import AVFoundation
import Combine
import QuartzCore

struct DioramaView: UIViewRepresentable {
    @ObservedObject var model: AppModel
    func makeCoordinator() -> Coordinator { Coordinator(model: model) }
    func makeUIView(context: Context) -> ARView {
        let isAR = model.settings.view == "Free AR" && ARWorldTrackingConfiguration.isSupported
        let view = ARView(frame: .zero, cameraMode: isAR ? .ar : .nonAR, automaticallyConfigureSession: false)
        context.coordinator.setup(view, isAR: isAR)
        return view
    }
    func updateUIView(_ view: ARView, context: Context) {}
    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) { coordinator.stop() }

    @MainActor final class Coordinator: NSObject, ARSessionDelegate, UIGestureRecognizerDelegate {
        let model: AppModel
        weak var view: ARView?
        let world = Entity()
        private var anchor = AnchorEntity(world: SIMD3<Float>.zero)
        private var arAnchor: ARAnchor?
        private var entities: [UInt64: ModelEntity] = [:]
        private var geometry: [UInt64: UInt64] = [:]
        private var colors: [UInt64: UInt32] = [:]
        private var meshCache: [UInt64: MeshResource] = [:]
        private var materialCache: [UInt32: SimpleMaterial] = [:]
        private var observations = Set<AnyCancellable>()
        private var updateSubscription: (any Combine.Cancellable)?
        private var camera: PerspectiveCamera?
        private var isAR = false
        private var pinchWidth: Float = 0.35
        private var rotationStart: Float = 0
        private var lastScene: UInt64 = UInt64.max
        private var lastReset = 0, lastReposition = 0
        private var lastFPS: TimeInterval = 0
        private var frameCount = 0
        private var scanningHit = false
        private var floor: ModelEntity?
        private var mapSharePending = false
        private var mapCaptureBusy = false
        private var mapRetryTime: TimeInterval = 0
        private var expectedSharedAnchor: UUID?
        private var waitingForRelocalization = false
        init(model: AppModel) { self.model = model }

        func setup(_ view: ARView, isAR: Bool) {
            self.view = view; self.isAR = isAR
            view.scene.addAnchor(anchor); anchor.addChild(world)
            let base = ModelEntity(mesh: .generateBox(width: 1.04, height: 0.008, depth: 0.79),
                materials: [SimpleMaterial(color: UIColor(red: 0.045, green: 0.065, blue: 0.075, alpha: 1), roughness: 0.85, isMetallic: false)])
            base.position.y = -0.008; world.addChild(base); floor = base
            let light = DirectionalLight()
            light.light.intensity = 1200
            light.shadow = DirectionalLightComponent.Shadow(maximumDistance: 3, depthBias: 1)
            light.look(at: .zero, from: SIMD3<Float>(0.5, 1.5, 0.7), relativeTo: nil)
            world.addChild(light)
            if !isAR {
                let camera = PerspectiveCamera(); camera.camera.fieldOfViewInDegrees = 45
                let cameraAnchor = AnchorEntity(world: .zero); cameraAnchor.addChild(camera)
                view.scene.addAnchor(cameraAnchor); self.camera = camera
                view.environment.background = .color(UIColor(red: 0.035, green: 0.047, blue: 0.063, alpha: 1))
                model.placementMessage = "3D viewer · switch to Free AR to place on a table"
                model.placed = true
                if model.isGuest { model.guestAligned() }
                if model.settings.view == "Free AR" { model.toast = "AR world tracking is unavailable on this device. Showing the 3D viewer." }
            } else {
                world.isEnabled = false
                view.session.delegate = self
                authorizeCamera()
            }
            let tap = UITapGestureRecognizer(target: self, action: #selector(place(_:)))
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:)))
            let rotate = UIRotationGestureRecognizer(target: self, action: #selector(rotate(_:)))
            pinch.delegate = self; rotate.delegate = self
            view.addGestureRecognizer(tap); view.addGestureRecognizer(pinch); view.addGestureRecognizer(rotate)
            model.$snapshot.compactMap { $0 }.sink { [weak self] in self?.render($0) }.store(in: &observations)
            model.$settings.sink { [weak self] in self?.configure($0) }.store(in: &observations)
            model.$sharedPresentation.sink { [weak self] _ in
                guard let self else { return }; self.configure(self.model.settings)
            }.store(in: &observations)
            model.$sharedWorldMap.sink { [weak self] data in
                guard let self, self.model.isGuest, self.isAR else { return }
                if let data { self.applySharedMap(data) }
                else {
                    self.expectedSharedAnchor = nil; self.waitingForRelocalization = false
                    self.world.isEnabled = false; self.model.placed = false
                }
            }.store(in: &observations)
            model.$shareMapToken.dropFirst().sink { [weak self] _ in
                self?.mapSharePending = true; self?.mapRetryTime = 0
            }.store(in: &observations)
            model.$resetTrackingToken.sink { [weak self] token in
                guard let self, self.lastReset != token else { return }; self.lastReset = token; self.runSession(reset: true)
            }.store(in: &observations)
            model.$repositionToken.sink { [weak self] token in
                guard let self, self.lastReposition != token else { return }; self.lastReposition = token; self.beginPlacement()
            }.store(in: &observations)
            updateSubscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
                // RealityKit delivers SceneEvents.Update on the main thread.
                self?.update(delta: event.deltaTime)
            }
            configure(model.settings)
        }
        func stop() { view?.session.pause(); observations.removeAll(); updateSubscription?.cancel(); updateSubscription = nil }
        private func authorizeCamera() {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: runSession(reset: false)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
                    Task { @MainActor in
                        if allowed { self?.runSession(reset: false) }
                        else { self?.model.error = "Enable camera access in iPhone Settings to use tabletop AR." }
                    }
                }
            default: model.error = "Camera access is disabled. Enable it in Settings, or select an isometric 3D view."
            }
        }
        private func runSession(reset: Bool) {
            guard isAR, AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
            let config = ARWorldTrackingConfiguration()
            config.planeDetection = [.horizontal]
            config.environmentTexturing = .automatic
            config.isLightEstimationEnabled = true
            if model.isGuest, let data = model.sharedWorldMap { applySharedMap(data); return }
            if reset { beginPlacement() }
            view?.session.run(config, options: reset ? [.resetTracking, .removeExistingAnchors] : [])
        }
        private func beginPlacement() {
            guard isAR, let view else { return }
            if model.isGuest { model.requestSharedMap(); return }
            if model.isHosting {
                model.network.send(.placementPending); mapSharePending = false
                model.spatialStatus = "Place the diorama, then scan the table to share it"
            }
            if let arAnchor { view.session.remove(anchor: arAnchor) }; arAnchor = nil
            anchor.removeFromParent()
            anchor = AnchorEntity(world: .zero); view.scene.addAnchor(anchor); anchor.addChild(world)
            world.isEnabled = false; scanningHit = false; model.placed = false
            model.placementMessage = "Move your phone slowly to find a table"
        }
        private func update(delta: TimeInterval) {
            frameCount += 1; lastFPS += delta
            if lastFPS >= 1 { model.arFPS = Double(frameCount) / lastFPS; lastFPS = 0; frameCount = 0 }
            if model.isHosting, mapSharePending, !mapCaptureBusy, CACurrentMediaTime() >= mapRetryTime {
                captureSharedMap()
            }
            if model.isGuest, isAR {
                if waitingForRelocalization, let frame = view?.session.currentFrame,
                   case .normal = frame.camera.trackingState,
                   let fixed = frame.anchors.first(where: { $0.identifier == expectedSharedAnchor }) {
                    anchor.removeFromParent(); anchor = AnchorEntity(anchor: fixed)
                    view?.scene.addAnchor(anchor); anchor.addChild(world); world.isEnabled = true
                    waitingForRelocalization = false
                    model.placementMessage = "Shared table anchored · walk around to change your view"
                    model.guestAligned()
                }
                return
            }
            guard isAR, !model.placed, let view else { return }
            let point = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            if let hit = view.raycast(from: point, allowing: .existingPlaneGeometry, alignment: .horizontal).first {
                anchor.transform = Transform(matrix: hit.worldTransform)
                world.isEnabled = true
                if !scanningHit { scanningHit = true; model.placementMessage = "Surface found · tap to place your diorama" }
            } else {
                world.isEnabled = false
                if scanningHit { scanningHit = false; model.placementMessage = "Keep scanning for a horizontal surface" }
            }
        }
        @objc private func place(_ gesture: UITapGestureRecognizer) {
            guard !model.isGuest, isAR, !model.placed, let view,
                  let hit = view.raycast(from: gesture.location(in: view), allowing: .existingPlaneGeometry, alignment: .horizontal).first else { return }
            let fixed = ARAnchor(name: "AtariDiorama", transform: hit.worldTransform)
            view.session.add(anchor: fixed); arAnchor = fixed
            anchor.removeFromParent(); anchor = AnchorEntity(anchor: fixed)
            view.scene.addAnchor(anchor); anchor.addChild(world); world.isEnabled = true
            model.placed = true; model.placementMessage = "Anchored · walk around your miniature world"
            model.setPaused(false)
            if model.isHosting { mapSharePending = true; mapRetryTime = 0 }
            if model.settings.haptics { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        }
        @objc private func pinch(_ gesture: UIPinchGestureRecognizer) {
            guard !model.isGuest else { return }
            if gesture.state == .began { pinchWidth = model.settings.worldWidth }
            model.settings.worldWidth = min(1.5, max(0.08, pinchWidth * Float(gesture.scale)))
        }
        @objc private func rotate(_ gesture: UIRotationGestureRecognizer) {
            guard !model.isGuest else { return }
            if gesture.state == .began { rotationStart = model.settings.rotation }
            model.settings.rotation = rotationStart - Float(gesture.rotation) * 180 / .pi
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
        private func configure(_ settings: AppSettings) {
            let presentation = model.isGuest ? model.presentation : SharedPresentation(settings)
            world.scale = SIMD3<Float>(repeating: presentation.width)
            world.orientation = simd_quatf(angle: presentation.rotation * .pi / 180, axis: [0, 1, 0]) *
                simd_quatf(angle: presentation.tilt * .pi / 180, axis: [1, 0, 0])
            view?.environment.lighting.intensityExponent = settings.ambient * 2 - 1
            if let camera {
                let size = presentation.width
                let side = model.profile.perspective == "sideView"
                let target = SIMD3<Float>(0, side ? 0.30 * size : 0.025 * size, 0)
                let offset: SIMD3<Float>
                switch settings.view {
                case "Top Down": offset = [0, 1.8, 0.001]
                case "Original": offset = side ? [0, 0.3, 1.8] : [0, 1.8, 0.001]
                default: offset = [1.05, 1.25, 1.35]
                }
                camera.look(at: target, from: offset * size, relativeTo: nil)
            }
        }
        private func captureSharedMap() {
            guard isAR, model.isHosting, model.network.connected, model.placed, let view else { return }
            mapRetryTime = CACurrentMediaTime() + 2
            guard let frame = view.session.currentFrame,
                  frame.worldMappingStatus == .mapped || frame.worldMappingStatus == .extending else {
                model.spatialStatus = "Scan around the table so Player 2 can align"
                return
            }
            mapCaptureBusy = true
            view.session.getCurrentWorldMap { [weak self] map, _ in
                Task { @MainActor in
                    guard let self else { return }; self.mapCaptureBusy = false
                    guard self.model.isHosting, self.model.network.connected, let map,
                          let id = self.arAnchor?.identifier, map.anchors.contains(where: { $0.identifier == id }) else { return }
                    do {
                        let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                        self.model.network.send(.worldMap, data); self.mapSharePending = false
                        self.model.spatialStatus = "Map sent · Player 2 should scan this same table"
                    } catch { self.model.spatialStatus = "Could not share the table map. Try Share table again." }
                }
            }
        }
        private func applySharedMap(_ data: Data) {
            guard isAR, AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
            do {
                guard let map = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data),
                      let fixed = map.anchors.first(where: { $0.name == "AtariDiorama" }) else {
                    throw DioramaError.message("The host's map has no diorama anchor. Ask the host to place it again.")
                }
                expectedSharedAnchor = fixed.identifier; waitingForRelocalization = true
                world.isEnabled = false; model.placed = false; model.setPaused(true)
                let config = ARWorldTrackingConfiguration()
                config.initialWorldMap = map; config.planeDetection = [.horizontal]
                config.environmentTexturing = .automatic; config.isLightEstimationEnabled = true
                view?.session.run(config, options: [.resetTracking, .removeExistingAnchors])
                model.placementMessage = "Aim at the same table the host scanned · move slowly to align"
                model.spatialStatus = "Aligning with the host's table…"
            } catch { model.error = error.localizedDescription }
        }
        private func render(_ snapshot: FrameSnapshot) {
            if lastScene != snapshot.sceneID {
                entities.values.forEach { $0.removeFromParent() }
                entities.removeAll(); geometry.removeAll(); colors.removeAll(); lastScene = snapshot.sceneID
            }
            var live = Set<UInt64>()
            for object in snapshot.objects {
                live.insert(object.id)
                let entity = entities[object.id] ?? ModelEntity()
                if entities[object.id] == nil { world.addChild(entity); entities[object.id] = entity }
                entity.position = [object.x, object.y, object.z]
                if geometry[object.id] != object.geometry_hash || colors[object.id] != object.color_rgba {
                    do {
                        let mesh: MeshResource
                        if let cached = meshCache[object.geometry_hash] { mesh = cached }
                        else {
                            let first = Int(object.first_box), end = first + Int(object.box_count)
                            guard first >= 0, end <= snapshot.boxes.count else { continue }
                            mesh = try Self.mesh(Array(snapshot.boxes[first..<end]))
                            if meshCache.count >= 512 { meshCache.removeAll(keepingCapacity: true) }
                            meshCache[object.geometry_hash] = mesh
                        }
                        let material: SimpleMaterial
                        if let cached = materialCache[object.color_rgba] { material = cached }
                        else {
                            let c = object.color_rgba
                            let color = UIColor(red: CGFloat(c & 255) / 255, green: CGFloat((c >> 8) & 255) / 255,
                                                blue: CGFloat((c >> 16) & 255) / 255, alpha: 1)
                            material = SimpleMaterial(color: color, roughness: 0.8, isMetallic: false)
                            materialCache[c] = material
                        }
                        entity.model = ModelComponent(mesh: mesh, materials: [material])
                        geometry[object.id] = object.geometry_hash; colors[object.id] = object.color_rgba
                    } catch { model.sceneErrors += 1 }
                }
            }
            for id in Array(entities.keys) where !live.contains(id) {
                entities.removeValue(forKey: id)?.removeFromParent(); geometry.removeValue(forKey: id); colors.removeValue(forKey: id)
            }
        }
        private static func mesh(_ boxes: [ADBox]) throws -> MeshResource {
            var positions = [SIMD3<Float>](), normals = [SIMD3<Float>](), triangles = [UInt32]()
            // Each face has its own normal, preserving the crisp voxel edges.
            let faces: [(SIMD3<Float>, [Int])] = [([0,0,-1],[0,3,2,1]), ([0,0,1],[4,5,6,7]),
                ([-1,0,0],[0,4,7,3]), ([1,0,0],[1,2,6,5]), ([0,-1,0],[0,1,5,4]), ([0,1,0],[3,7,6,2])]
            positions.reserveCapacity(boxes.count * 24); normals.reserveCapacity(boxes.count * 24)
            for b in boxes {
                let c = SIMD3<Float>(b.x, b.y, b.z), s = SIMD3<Float>(b.width, b.height, b.depth) / 2
                let corners: [SIMD3<Float>] = [c + s * [-1,-1,-1], c + s * [1,-1,-1], c + s * [1,1,-1], c + s * [-1,1,-1],
                    c + s * [-1,-1,1], c + s * [1,-1,1], c + s * [1,1,1], c + s * [-1,1,1]]
                for (normal, face) in faces {
                    let first = UInt32(positions.count)
                    positions += face.map { corners[$0] }; normals += Array(repeating: normal, count: 4)
                    triangles += [first, first+1, first+2, first, first+2, first+3]
                }
            }
            var descriptor = MeshDescriptor(name: "AtariVoxelObject")
            descriptor.positions = MeshBuffers.Positions(positions)
            descriptor.normals = MeshBuffers.Normals(normals)
            descriptor.primitives = .triangles(triangles)
            return try MeshResource.generate(from: [descriptor])
        }
        nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
            Task { @MainActor in self.model.error = "AR tracking: " + error.localizedDescription; self.model.setPaused(true) }
        }
        nonisolated func sessionWasInterrupted(_ session: ARSession) {
            Task { @MainActor in self.model.placementMessage = "Camera interrupted · resume and scan the table again"; self.model.setPaused(true) }
        }
        nonisolated func sessionInterruptionEnded(_ session: ARSession) {
            Task { @MainActor in self.runSession(reset: true) }
        }
        nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            switch camera.trackingState {
            case .limited(let reason):
                let message: String
                switch reason {
                case .excessiveMotion: message = "Move your phone more slowly"
                case .insufficientFeatures: message = "Aim at a well-lit, textured surface"
                case .relocalizing: message = "Return to the placed diorama to recover tracking"
                default: message = "Move slowly while the camera initializes"
                }
                Task { @MainActor in self.model.placementMessage = message }
            default: break
            }
        }
    }
}
