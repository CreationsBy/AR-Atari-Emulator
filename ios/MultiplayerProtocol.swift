import Foundation
import CryptoKit
import Compression
import simd

enum MultiplayerError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}

enum RoomCode {
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    static func make() -> String { String((0..<8).map { _ in alphabet.randomElement()! }) }
    static func normalize(_ text: String) -> String { text.uppercased().filter { !$0.isWhitespace && $0 != "-" } }
    static func valid(_ text: String) -> Bool { text.count == 8 && text.allSatisfy { alphabet.contains($0) } }
    static func display(_ text: String) -> String { String(text.prefix(4)) + "-" + String(text.suffix(4)) }
    static func serviceName(_ code: String) -> String {
        "Atari-" + SHA256.hash(data: Data(("atari-room-v1:" + code).utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
    }
    static func key(_ code: String) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: Data("atari-tls-v1".utf8), using: SymmetricKey(data: Data(code.utf8))))
    }
}

// Only these presentation properties are shared. Each phone keeps its own camera,
// volume, control layout and local settings. No ROM or emulator save state is sent.
struct SharedPresentation: Codable, Equatable {
    var width: Float
    var rotation: Float
    var tilt: Float
    var upright: Bool
    init(_ settings: AppSettings) { width = settings.worldWidth; rotation = settings.rotation; tilt = settings.tilt; upright = settings.upright ?? false }
    func worldRotation(nativeUpright: Bool) -> simd_quatf {
        let standUp: Float = upright && !nativeUpright ? .pi / 2 : 0
        return simd_quatf(angle: rotation * .pi / 180, axis: [0, 1, 0]) *
            simd_quatf(angle: standUp + tilt * .pi / 180, axis: [1, 0, 0])
    }
    func worldOffset(nativeUpright: Bool) -> SIMD3<Float> {
        // Pivot the entire upright scene around its bottom edge, including tilt.
        upright && !nativeUpright ? -worldRotation(nativeUpright: false).act(SIMD3<Float>(0,0,0.375)) * width : .zero
    }
    func actorRotation(reconstruction: String?, role: Int32) -> simd_quatf {
        // Semantic skaters already stand above their foot anchor. In a vertical
        // rink their silhouettes should stand in the screen plane, not lie on it.
        let standing = reconstruction == "iceHockeyNTSCv1" && role == 2 ||
            reconstruction == "adventureNTSCv1" && (role == 2 || role == 5)
        return upright && standing ?
            simd_quatf(angle: -.pi / 2, axis: [1,0,0]) : simd_quatf()
    }
    func objectPosition(_ position: SIMD3<Float>, reconstruction: String?, role: Int32, id: UInt64, wallFront: Float) -> SIMD3<Float> {
        var result = position
        if upright && reconstruction == "adventureNTSCv1" && (role == 2 || role == 5 || role == 0 && id == 2) {
            // In the vertical relief, keep gameplay silhouettes in front of
            // raised castle walls rather than at the bottom of a deep recess.
            result.y = max(result.y, wallFront + 0.006)
        }
        return result
    }
    func validate() throws {
        guard width.isFinite, (0.08...1.5).contains(width), rotation.isFinite, abs(rotation) < 100_000,
              tilt.isFinite, (-60...60).contains(tilt) else { throw MultiplayerError.invalid("Invalid shared placement.") }
    }
}

struct RoomWelcome: Codable {
    var title: String
    var profile: GameProfile
    var controller: String
    var sampleRate: Double
    var paused: Bool
    var presentation: SharedPresentation
}

struct RemoteInput: Codable, Equatable {
    var buttons: UInt16 = 0
    var paddle: Float = 0
    var sequence: UInt64 = 0
    // The guest cannot send Select, Reset, difficulty switches or another port.
    var safeButtons: UInt16 { buttons & 0x00f1 }
    var safePaddle: Float { paddle.isFinite ? min(1, max(-1, paddle)) : 0 }
}

enum RoomMessage: UInt8 {
    case welcome = 1, frame, input, worldMap, mapRequest, aligned, ping, pong, frameAck, placementPending
}

enum RoomCodec {
    static let version: UInt8 = 2
    static let maxPacket = 8 * 1024 * 1024
    static let maxDecoded = 24 * 1024 * 1024
    static func plist<T: Encodable>(_ value: T) throws -> Data {
        let encoder = PropertyListEncoder(); encoder.outputFormat = .binary
        return try encoder.encode(value)
    }
    static func read<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        try PropertyListDecoder().decode(type, from: data)
    }
    // Length framing over TCP, protocol version and bounded LZFSE decompression.
    static func packet(_ type: RoomMessage, _ body: Data) throws -> Data {
        guard body.count <= maxDecoded else { throw MultiplayerError.invalid("Shared scene is too large.") }
        var compressed = Data(count: max(4096, body.count + body.count / 4 + 256))
        let count = compressed.withUnsafeMutableBytes { dst in
            guard !body.isEmpty else { return 0 }
            return body.withUnsafeBytes { src in
                compression_encode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, dst.count,
                    src.bindMemory(to: UInt8.self).baseAddress!, src.count, nil, COMPRESSION_LZFSE)
            }
        }
        let useCompression = count > 0 && count < body.count
        var payload = Data([version, type.rawValue, useCompression ? 1 : 0])
        var writer = WireWriter(); writer.u32(UInt32(body.count)); payload.append(writer.data)
        payload.append(useCompression ? compressed.prefix(count) : body)
        guard payload.count <= maxPacket else { throw MultiplayerError.invalid("Network message is too large.") }
        writer = WireWriter(); writer.u32(UInt32(payload.count)); writer.data.append(payload)
        return writer.data
    }
    static func unpack(_ payload: Data) throws -> (RoomMessage, Data) {
        var reader = WireReader(data: payload)
        guard try reader.u8() == version, let type = RoomMessage(rawValue: try reader.u8()) else {
            throw MultiplayerError.invalid("Both phones need the same app version.")
        }
        let compressed = try reader.u8(), size = Int(try reader.u32())
        guard size <= maxDecoded, compressed <= 1 else { throw MultiplayerError.invalid("Invalid network message.") }
        let body = try reader.bytes(payload.count - reader.offset)
        if compressed == 0 {
            guard body.count == size else { throw MultiplayerError.invalid("Truncated network message.") }
            return (type, body)
        }
        guard size > 0, !body.isEmpty else { throw MultiplayerError.invalid("Empty compressed message.") }
        var output = Data(count: size)
        let count = output.withUnsafeMutableBytes { dst in
            body.withUnsafeBytes { src in
                compression_decode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, dst.count,
                    src.bindMemory(to: UInt8.self).baseAddress!, src.count, nil, COMPRESSION_LZFSE)
            }
        }
        guard count == size else { throw MultiplayerError.invalid("Damaged compressed message.") }
        return (type, output)
    }
}

struct TCPMessages {
    private var buffer = Data()
    mutating func append(_ data: Data) throws -> [Data] {
        guard buffer.count + data.count <= RoomCodec.maxPacket + 65540 else { throw MultiplayerError.invalid("Receive buffer exceeded.") }
        buffer.append(data)
        var result = [Data]()
        while buffer.count >= 4 {
            var reader = WireReader(data: buffer)
            let count = Int(try reader.u32())
            guard (7...RoomCodec.maxPacket).contains(count) else { throw MultiplayerError.invalid("Invalid message length.") }
            guard buffer.count >= count + 4 else { break }
            result.append(Data(buffer.dropFirst(4).prefix(count)))
            buffer = Data(buffer.dropFirst(count + 4))
        }
        return result
    }
}

// Explicit field encoding avoids sending C struct padding or relying on ABI layout.
// Every scene is self-contained: dropped frames cannot corrupt a delta cache.
struct SharedFrame {
    var snapshot: FrameSnapshot
    var paused: Bool
    var presentation: SharedPresentation

    func encode() throws -> Data {
        let s = snapshot
        var w = WireWriter()
        w.u64(s.number); w.u64(s.sceneID); w.u32(UInt32(s.width)); w.u32(UInt32(s.height))
        w.double(s.fps); w.double(s.sampleRate); w.double(s.analysisMS)
        w.u32(s.traceCount); w.u32(s.traceDropped); w.u32(s.droppedObjects)
        w.u8(paused ? 1 : 0); w.u8(presentation.upright ? 1 : 0)
        w.float(presentation.width); w.float(presentation.rotation); w.float(presentation.tilt)
        w.blob(s.pixels); w.blob(Data(s.ram)); w.blob(s.pcm)
        w.u32(UInt32(s.objects.count)); w.u32(UInt32(s.boxes.count))
        for o in s.objects {
            w.u64(o.id); w.u64(o.geometry_hash); w.u64(o.pattern)
            w.u32(o.color_rgba); w.u32(o.first_box); w.u32(o.box_count)
            w.u32(UInt32(bitPattern: o.role)); w.u32(UInt32(bitPattern: o.color_index))
            for f in [o.x, o.y, o.z, o.pixel_x, o.pixel_y, o.pixel_width, o.pixel_height] { w.float(f) }
        }
        for b in s.boxes { for f in [b.x, b.y, b.z, b.width, b.height, b.depth] { w.float(f) } }
        return w.data
    }
    static func decode(_ data: Data) throws -> SharedFrame {
        var r = WireReader(data: data)
        let number = try r.u64(), scene = try r.u64(), width = Int(try r.u32()), height = Int(try r.u32())
        let fps = try r.double(), rate = try r.double(), analysis = try r.double()
        guard (1...160).contains(width), (1...320).contains(height), (40...70).contains(fps),
              (8000...96000).contains(rate), analysis.isFinite else { throw MultiplayerError.invalid("Invalid frame dimensions or timing.") }
        let trace = try r.u32(), traceDropped = try r.u32(), objectsDropped = try r.u32(), paused = try r.u8() != 0
        let upright = try r.u8() != 0
        let presentation = try SharedPresentation(width: r.float(), rotation: r.float(), tilt: r.float(), upright: upright)
        try presentation.validate()
        let pixels = try r.blob(max: 160 * 320 * 4), ram = try r.blob(max: 128), pcm = try r.blob(max: 8192 * 4)
        guard pixels.count == width * height * 4, ram.count == 128, pcm.count % 4 == 0 else { throw MultiplayerError.invalid("Invalid frame resources.") }
        let objectCount = Int(try r.u32()), boxCount = Int(try r.u32())
        guard objectCount <= 1024, boxCount <= 24000 else { throw MultiplayerError.invalid("Scene exceeds geometry budget.") }
        var objects = [ADObject](), boxes = [ADBox]()
        for _ in 0..<objectCount {
            var o = ADObject()
            o.id = try r.u64(); o.geometry_hash = try r.u64(); o.pattern = try r.u64()
            o.color_rgba = try r.u32(); o.first_box = try r.u32(); o.box_count = try r.u32()
            o.role = Int32(bitPattern: try r.u32()); o.color_index = Int32(bitPattern: try r.u32())
            o.x = try r.float(); o.y = try r.float(); o.z = try r.float()
            o.pixel_x = try r.float(); o.pixel_y = try r.float(); o.pixel_width = try r.float(); o.pixel_height = try r.float()
            guard UInt64(o.first_box) + UInt64(o.box_count) <= UInt64(boxCount), (0...5).contains(o.role) else {
                throw MultiplayerError.invalid("Invalid object box range.")
            }
            objects.append(o)
        }
        for _ in 0..<boxCount {
            let b = try ADBox(x: r.float(), y: r.float(), z: r.float(), width: r.float(), height: r.float(), depth: r.float())
            guard b.width > 0, b.height > 0, b.depth > 0 else { throw MultiplayerError.invalid("Invalid voxel dimensions.") }
            boxes.append(b)
        }
        guard r.offset == data.count else { throw MultiplayerError.invalid("Unexpected scene data.") }
        var snapshot = FrameSnapshot(number: number, width: width, height: height, pixels: pixels, ram: Array(ram),
            objects: objects, boxes: boxes, sceneID: scene, fps: fps, analysisMS: analysis,
            traceCount: trace, traceDropped: traceDropped, droppedObjects: objectsDropped)
        snapshot.pcm = pcm; snapshot.sampleRate = rate
        return SharedFrame(snapshot: snapshot, paused: paused, presentation: presentation)
    }
}

extension SharedPresentation {
    init(width: Float, rotation: Float, tilt: Float, upright: Bool = false) {
        self.width = width; self.rotation = rotation; self.tilt = tilt; self.upright = upright
    }
}

struct WireWriter {
    var data = Data()
    mutating func u8(_ n: UInt8) { data.append(n) }
    mutating func u32(_ n: UInt32) { for shift in stride(from: 0, to: 32, by: 8) { data.append(UInt8(truncatingIfNeeded: n >> shift)) } }
    mutating func u64(_ n: UInt64) { for shift in stride(from: 0, to: 64, by: 8) { data.append(UInt8(truncatingIfNeeded: n >> shift)) } }
    mutating func float(_ n: Float) { u32(n.bitPattern) }
    mutating func double(_ n: Double) { u64(n.bitPattern) }
    mutating func blob(_ value: Data) { u32(UInt32(value.count)); data.append(value) }
}
struct WireReader {
    let data: Data
    var offset = 0
    mutating func bytes(_ n: Int) throws -> Data {
        guard n >= 0, n <= data.count - offset else { throw MultiplayerError.invalid("Truncated message.") }
        let result = Data(data.dropFirst(offset).prefix(n)); offset += n; return result
    }
    mutating func u8() throws -> UInt8 { guard offset < data.count else { throw MultiplayerError.invalid("Truncated message.") }; defer { offset += 1 }; return data[data.startIndex + offset] }
    mutating func u32() throws -> UInt32 { var n: UInt32 = 0; for shift in stride(from: 0, to: 32, by: 8) { n |= UInt32(try u8()) << shift }; return n }
    mutating func u64() throws -> UInt64 { var n: UInt64 = 0; for shift in stride(from: 0, to: 64, by: 8) { n |= UInt64(try u8()) << shift }; return n }
    mutating func float() throws -> Float { let n = Float(bitPattern: try u32()); guard n.isFinite, abs(n) < 100_000 else { throw MultiplayerError.invalid("Invalid scene coordinate.") }; return n }
    mutating func double() throws -> Double { Double(bitPattern: try u64()) }
    mutating func blob(max: Int) throws -> Data { let n = Int(try u32()); guard n <= max else { throw MultiplayerError.invalid("Resource exceeds budget.") }; return try bytes(n) }
}
