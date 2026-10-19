import Foundation
import QuartzCore

struct FrameSnapshot {
    var number: UInt64
    var width, height: Int
    var pixels: Data
    var ram: [UInt8]
    var objects: [ADObject]
    var boxes: [ADBox]
    var sceneID: UInt64
    var fps, analysisMS: Double
    var traceCount, traceDropped, droppedObjects: UInt32
}

// All libretro/core calls and borrowed-pointer reads stay on this queue.
// A value snapshot crosses to the main thread. Input and audio use native atomics.
final class EmulationEngine {
    private let queue = DispatchQueue(label: "atari.emulation", qos: .userInteractive)
    private var profile = GameProfile.generic
    private var depth: Float = 1
    private var quality = 1
    private var deadline: CFTimeInterval = 0
    private var loaded = false
    private var stateFrames: UInt64 = 0

    func load(data: Data, filename: String, profile: GameProfile, controller: String,
              completion: @escaping (Result<Double, Error>) -> Void) {
        queue.async {
            do {
                _ = ad_initialize(Storage.root.path)
                let valid = data.withUnsafeBytes { buffer in
                    ad_load_rom(buffer.bindMemory(to: UInt8.self).baseAddress, data.count, filename)
                }
                guard valid else { throw DioramaError.message(String(cString: ad_last_error())) }
                self.profile = profile
                self.loaded = true
                self.deadline = 0
                self.stateFrames = 0
                self.setControllerOnQueue(controller)
                let rate = ad_current_frame()?.pointee.sample_rate ?? 31400
                DispatchQueue.main.async { completion(.success(rate)) }
            } catch { DispatchQueue.main.async { completion(.failure(error)) } }
        }
    }
    private func setControllerOnQueue(_ controller: String) {
        let type = controller == "paddles" ? UInt32(AD_PADDLES) : UInt32(AD_JOYSTICK)
        ad_set_controller(0, type); ad_set_controller(1, type)
    }
    func configure(depth: Float, quality: Int, controller: String) {
        queue.async {
            self.depth = depth; self.quality = quality
            self.setControllerOnQueue(controller)
        }
    }
    func resumeClock() { queue.async { self.deadline = 0 } }
    func advance(now: CFTimeInterval, completion: @escaping (FrameSnapshot?) -> Void) {
        queue.async {
            guard self.loaded else { DispatchQueue.main.async { completion(nil) }; return }
            var f = ad_current_frame()
            let fps = f?.pointee.fps ?? 60
            if self.deadline == 0 || now - self.deadline > 0.25 { self.deadline = now }
            var count = 0
            while now >= self.deadline && count < 4 {
                f = ad_run_frame(); count += 1; self.stateFrames += 1
                self.deadline += 1.0 / max(f?.pointee.fps ?? fps, 1)
            }
            guard count > 0, let pointer = f, pointer.pointee.width > 0 else {
                DispatchQueue.main.async { completion(nil) }; return
            }
            let frame = pointer.pointee
            let ram = Array(UnsafeBufferPointer(start: frame.ram, count: 128))
            let scene = self.profile.withNative(ram: ram, depth: self.depth, quality: self.quality) { p in
                ad_reconstruct(pointer, &p)!.pointee
            }
            var writes: UInt32 = 0, dropped: UInt32 = 0
            _ = ad_tia_writes(&writes, &dropped)
            let snapshot = FrameSnapshot(number: self.stateFrames, width: Int(frame.width), height: Int(frame.height),
                pixels: Data(bytes: frame.rgba!, count: Int(frame.width * frame.height * 4)), ram: ram,
                objects: Array(UnsafeBufferPointer(start: scene.objects, count: Int(scene.object_count))),
                boxes: Array(UnsafeBufferPointer(start: scene.boxes, count: Int(scene.box_count))), sceneID: scene.scene_id,
                fps: frame.fps, analysisMS: scene.analysis_ms, traceCount: writes, traceDropped: dropped,
                droppedObjects: scene.dropped_objects)
            DispatchQueue.main.async { completion(snapshot) }
        }
    }
    func reset() { queue.async { ad_reset(); self.deadline = 0; self.stateFrames = 0 } }
    func save(completion: @escaping (Result<Data, Error>) -> Void) {
        queue.async {
            let size = ad_state_size()
            guard size > 0 else { DispatchQueue.main.async { completion(.failure(DioramaError.message("This core cannot save the current game."))) }; return }
            var data = Data(count: size)
            let ok = data.withUnsafeMutableBytes { ad_save_state($0.bindMemory(to: UInt8.self).baseAddress, size) }
            DispatchQueue.main.async {
                completion(ok ? .success(data) : .failure(DioramaError.message("The core could not serialize this game.")))
            }
        }
    }
    func restore(_ data: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            let ok = data.withUnsafeBytes { ad_load_state($0.bindMemory(to: UInt8.self).baseAddress, data.count) }
            self.deadline = 0
            let error = String(cString: ad_last_error())
            DispatchQueue.main.async { completion(ok ? .success(()) : .failure(DioramaError.message(error))) }
        }
    }
}
