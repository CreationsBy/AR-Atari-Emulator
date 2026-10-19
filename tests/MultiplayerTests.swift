import Foundation
import Network
import Combine
import simd

enum TestFailure: Error { case failed(String) }
func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure.failed(message) }
}
func rejects(_ body: () throws -> Void) throws {
    do { try body() } catch { return }
    throw TestFailure.failed("Malformed packet was accepted")
}

@main struct MultiplayerTests {
    @MainActor static func wait(_ description: String, seconds: Double = 15, until condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(seconds)
        while !condition() {
            if Date() > deadline { throw TestFailure.failed("Timed out: " + description) }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }
    static func fixture() -> FrameSnapshot {
        let box = ADBox(x: 0, y: 0.02, z: 0, width: 0.05, height: 0.04, depth: 0.05)
        var object = ADObject(); object.id = 9; object.geometry_hash = 123; object.pattern = 456
        object.box_count = 1; object.color_rgba = 0xff33ccaa; object.role = 2; object.color_index = 132
        object.pixel_width = 8; object.pixel_height = 8
        var s = FrameSnapshot(number: 42, width: 160, height: 210,
            pixels: Data(repeating: 70, count: 160 * 210 * 4), ram: [UInt8](repeating: 3, count: 128),
            objects: [object], boxes: [box], sceneID: 7, fps: 59.92, analysisMS: 0.4,
            traceCount: 824, traceDropped: 0, droppedObjects: 0)
        s.pcm = Data(repeating: 1, count: 524 * 4)
        return s
    }
    static func protocolTests() throws {
        for _ in 0..<100 { try expect(RoomCode.valid(RoomCode.make()), "Generated room code invalid") }
        try expect(RoomCode.normalize(" abcd-efgh ") == "ABCDEFGH", "Room code normalization")
        try expect(RoomCode.serviceName("ABCDEFGH") != RoomCode.serviceName("ABCDEFGJ"), "Room discovery collision")
        try expect(RoomCode.key("ABCDEFGH") != RoomCode.key("ABCDEFGJ"), "TLS keys must differ")
        let malicious = RemoteInput(buttons: .max, paddle: .nan)
        try expect(malicious.safeButtons == 0xf1 && malicious.safePaddle == 0, "Guest input can access host switches")
        var settings = AppSettings()
        settings.volume = 0.23; settings.player = 1
        let legacy = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        try expect(legacy.upright == nil && legacy.volume == 0.23 && legacy.player == 1, "Legacy preferences lost during orientation migration")
        settings.upright = true
        let pose = SharedPresentation(settings)
        let bottom = pose.worldRotation(nativeUpright: false).act(SIMD3<Float>(0,0,0.375)) * pose.width + pose.worldOffset(nativeUpright: false)
        let top = pose.worldRotation(nativeUpright: false).act(SIMD3<Float>(0,0,-0.375)) * pose.width + pose.worldOffset(nativeUpright: false)
        try expect(simd_length(bottom) < 0.0001 && top.y > 0.25, "Upright world is not standing on its bottom edge")
        try expect(abs(pose.worldRotation(nativeUpright: true).angle) < 0.0001, "Side-view profile rotated twice")
        var tilted = settings; tilted.tilt = 30; tilted.rotation = 45
        let tiltedPose = SharedPresentation(tilted)
        let foot = tiltedPose.worldRotation(nativeUpright: false).act(SIMD3<Float>(0,0,0.375)) * tiltedPose.width + tiltedPose.worldOffset(nativeUpright: false)
        try expect(simd_length(foot) < 0.0001, "Vertical tilt detached its bottom edge")
        let snapshot = fixture()
        let frame = SharedFrame(snapshot: snapshot, paused: false, presentation: SharedPresentation(settings))
        let bytes = try frame.encode(), packet = try RoomCodec.packet(.frame, bytes)
        try expect(packet.count < bytes.count / 4, "Frame compression ineffective")
        var parser = TCPMessages(); var messages = [Data]()
        for chunk in stride(from: 0, to: packet.count, by: 13) {
            messages += try parser.append(packet.subdata(in: chunk..<min(chunk + 13, packet.count)))
        }
        try expect(messages.count == 1, "Fragmented TCP packet framing")
        let (kind, body) = try RoomCodec.unpack(messages[0]); let result = try SharedFrame.decode(body)
        try expect(kind == .frame && result.snapshot.number == 42 && result.snapshot.sceneID == 7, "Scene identity roundtrip")
        try expect(result.presentation.upright, "Vertical mode was not synchronized")
        try expect(result.snapshot.pixels == snapshot.pixels && result.snapshot.pcm == snapshot.pcm, "Pixels/audio roundtrip")
        try expect(result.snapshot.objects[0].geometry_hash == 123 && result.snapshot.boxes[0].height == 0.04, "Volumetric geometry roundtrip")
        var combined = TCPMessages()
        let ping = try RoomCodec.packet(.ping, Data())
        let coalesced = try combined.append(ping + ping)
        try expect(coalesced.count == 2, "Coalesced TCP messages")
        var shortHeader = TCPMessages()
        try rejects { _ = try shortHeader.append(Data([255, 255, 255, 127])) }
        try rejects { _ = try RoomCodec.unpack(Data([RoomCodec.version, RoomMessage.frame.rawValue, 1, 1, 0, 0, 0])) }
        try rejects { _ = try RoomCodec.unpack(Data([1, RoomMessage.ping.rawValue, 0, 0, 0, 0, 0])) }
        try rejects { _ = try SharedFrame.decode(bytes.dropLast()) }
        var broken = snapshot; broken.objects[0].box_count = 24001
        try rejects { _ = try SharedFrame.decode(SharedFrame(snapshot: broken, paused: false, presentation: SharedPresentation(settings)).encode()) }
        broken = snapshot; broken.boxes[0].width = .nan
        try rejects { _ = try SharedFrame.decode(SharedFrame(snapshot: broken, paused: false, presentation: SharedPresentation(settings)).encode()) }
        var version = Data(messages[0]); version[0] = 99
        try rejects { _ = try RoomCodec.unpack(version) }
        print("PASS: room codes, input authority, scene/audio roundtrip, compression, fragmented/coalesced TCP, malformed/oversized/version packets")
    }
    @MainActor static func transportTests() async throws {
        let host = LocalSession(interface: .loopback), guest = LocalSession(interface: .loopback)
        let observations = [host.$status.sink { print("HOST: \($0)") }, guest.$status.sink { print("GUEST: \($0)") }]
        defer { observations.forEach { $0.cancel() } }
        defer { guest.stop(); host.stop() }
        host.host()
        try await wait("host listener ready with an assigned port") { host.acceptingGuest }
        print("Loopback listener port: \(host.listenerPort!.rawValue)")
        let endpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: host.listenerPort!)
        let wrong = LocalSession(interface: .loopback)
        defer { wrong.stop() }
        var wrongConnected = false
        wrong.onConnected = { wrongConnected = true }
        wrong.join(host.code == "ABCDEFGH" ? "ABCDEFGJ" : "ABCDEFGH", endpoint: endpoint)
        try await wait("wrong code rejected") { wrong.status.contains("rejected") || wrong.status.contains("Could not connect") }
        try expect(!wrongConnected && !host.connected, "Incorrect code authenticated")
        try await wait("host releases rejected handshake") { host.acceptingGuest }
        var input: RemoteInput?, receivedFrame: SharedFrame?, mapReceived = false
        var frameCount = 0
        host.onMessage = { type, data in if type == .input { input = try? RoomCodec.read(RemoteInput.self, data) } }
        guest.onMessage = { type, data in
            if type == .frame { receivedFrame = try? SharedFrame.decode(data); frameCount += 1 }
            if type == .worldMap { mapReceived = data == Data(repeating: 17, count: 200_000) }
        }
        guest.join(host.code, endpoint: endpoint)
        do { try await wait("encrypted peer connection") { host.connected && guest.connected } }
        catch { throw TestFailure.failed("TLS host: \(host.status); guest: \(guest.status); accepting: \(host.acceptingGuest)") }
        guest.send(.input, try RoomCodec.plist(RemoteInput(buttons: 0x81, paddle: 0.5, sequence: 1)))
        host.offer(SharedFrame(snapshot: fixture(), paused: false, presentation: SharedPresentation(AppSettings())))
        host.send(.worldMap, Data(repeating: 17, count: 200_000))
        try await wait("bidirectional input, frame and map") { input != nil && receivedFrame != nil && mapReceived }
        try expect(input?.safeButtons == 0x81 && receivedFrame?.snapshot.objects.count == 1, "Transport corrupted data")
        var newest = fixture()
        for n in 43...99 { newest.number = UInt64(n); host.offer(SharedFrame(snapshot: newest, paused: false, presentation: SharedPresentation(AppSettings()))) }
        try await Task.sleep(nanoseconds: 200_000_000)
        try expect(frameCount == 1, "Host sent unbounded frames without ACK")
        guest.send(.frameAck)
        try await wait("latest frame replaces backlog") { receivedFrame?.snapshot.number == 99 }
        try expect(frameCount == 2, "Backpressure did not coalesce old scenes")
        try expect((receivedFrame?.snapshot.pcm.count ?? 0) > fixture().pcm.count && (receivedFrame?.snapshot.pcm.count ?? 0) <= 8192 * 4,
            "Coalescing dropped audio or exceeded its latency budget")
        let third = LocalSession(interface: .loopback)
        defer { third.stop() }
        third.join(host.code, endpoint: endpoint)
        try await Task.sleep(nanoseconds: 500_000_000)
        try expect(!third.connected && host.connected && guest.connected, "Third player replaced Player 2")
        third.stop(); guest.stop()
        try await wait("guest disconnect") { !host.connected }
        guest.join(host.code, endpoint: endpoint)
        try await wait("guest rejoins") { host.connected && guest.connected }
        print("PASS: real TLS-PSK loopback, wrong-code rejection, bidirectional input/scene/audio/map delivery, ACK backpressure, third-peer rejection, disconnect/rejoin")
    }
    @MainActor static func main() async {
        do {
            try protocolTests(); try await transportTests()
            print("All multiplayer tests passed. Physical Wi-Fi and shared-AR alignment still require two iPhones.")
        } catch { print("FAIL: \(error)"); exit(1) }
    }
}
