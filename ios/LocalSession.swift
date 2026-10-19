import Foundation
import Combine
import Network
import Security

// The release app only constructs this transport with .wifi. No relay, server,
// cellular path, peer-to-peer Wi-Fi or Bluetooth is used. Loopback is injectable
// for the hosted two-endpoint transport tests.
@MainActor final class LocalSession: ObservableObject {
    enum Role { case none, host, guest }
    static let serviceType = "_atari-ar._tcp"
    @Published private(set) var role: Role = .none
    @Published private(set) var code = ""
    @Published private(set) var status = "Not connected"
    @Published private(set) var connected = false
    var onConnected: (() -> Void)?
    var onMessage: ((RoomMessage, Data) -> Void)?
    var onDisconnect: ((String) -> Void)?
    var onTick: (() -> Void)?
    private let interface: NWInterface.InterfaceType
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var messages = TCPMessages()
    private let codingQueue = DispatchQueue(label: "atari.network.codec", qos: .userInteractive)
    private var timer: Timer?
    private var lastReceived = Date()
    private var lastPing = Date.distantPast
    private var frameOutstanding = false
    private var latestFrame: SharedFrame?
    private var generation = UUID()
    private var searchDeadline = Date.distantFuture
    private var connectionStarted = Date()

    init(interface: NWInterface.InterfaceType = .wifi) { self.interface = interface }
    var listenerPort: NWEndpoint.Port? { listener?.port }
    var connectionToken: UUID { generation }

    private func parameters(code: String? = nil) -> NWParameters {
        let tcp = NWProtocolTCP.Options(); tcp.noDelay = true
        let parameters: NWParameters
        if let code {
            let tls = NWProtocolTLS.Options()
            let key = RoomCode.key(code).withUnsafeBytes { DispatchData(bytes: $0) }
            let identity = Data("atari-room-v1".utf8).withUnsafeBytes { DispatchData(bytes: $0) }
            sec_protocol_options_add_pre_shared_key(tls.securityProtocolOptions, key as __DispatchData, identity as __DispatchData)
            // Network.framework's TLS-PSK API supports TLS 1.2, not TLS 1.3.
            sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, .TLSv12)
            sec_protocol_options_set_max_tls_protocol_version(tls.securityProtocolOptions, .TLSv12)
            sec_protocol_options_append_tls_ciphersuite(tls.securityProtocolOptions,
                tls_ciphersuite_t(rawValue: TLS_PSK_WITH_AES_128_GCM_SHA256)!)
            parameters = NWParameters(tls: tls, tcp: tcp)
        } else { parameters = NWParameters(tls: nil, tcp: tcp) }
        parameters.requiredInterfaceType = interface
        parameters.includePeerToPeer = false
        parameters.allowLocalEndpointReuse = true
        return parameters
    }

    func host() {
        stop()
        role = .host; code = RoomCode.make(); status = "Starting room on Wi-Fi…"
        do {
            let listener = try NWListener(using: parameters(code: code))
            self.listener = listener
            listener.service = NWListener.Service(name: RoomCode.serviceName(code), type: Self.serviceType)
            listener.stateUpdateHandler = { [weak self, weak listener] state in
                Task { @MainActor in
                guard let self, self.listener === listener else { return }
                switch state {
                case .ready: self.status = "Waiting for Player 2 · same Wi-Fi"
                case .failed(let error): self.fail("Cannot host. Allow Local Network access in Settings and connect to Wi-Fi. \(error.localizedDescription)", stopRoom: true)
                default: break
                }
                }
            }
            listener.newConnectionHandler = { [weak self] incoming in
                Task { @MainActor in
                guard let self, self.connection == nil else { incoming.cancel(); return }
                self.attach(incoming)
                }
            }
            listener.start(queue: .main)
            startTimer()
        } catch { fail(error.localizedDescription, stopRoom: true) }
    }

    func join(_ enteredCode: String, endpoint: NWEndpoint? = nil) {
        stop()
        let normalized = RoomCode.normalize(enteredCode)
        guard RoomCode.valid(normalized) else { status = "Enter the eight-character code shown on the host."; return }
        code = normalized; role = .guest; status = "Finding room on your Wi-Fi…"
        searchDeadline = Date().addingTimeInterval(25)
        startTimer()
        if let endpoint { attach(NWConnection(to: endpoint, using: parameters(code: code))); return }
        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: "local."), using: parameters())
        self.browser = browser
        browser.stateUpdateHandler = { [weak self, weak browser] state in
            Task { @MainActor in
            guard let self, self.browser === browser else { return }
            if case .failed = state {
                self.fail("Discovery failed. Allow Local Network access and connect both phones to the same Wi-Fi.", stopRoom: true)
            }
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
            guard let self, self.connection == nil else { return }
            for result in results {
                if case .service(let name, _, _, _) = result.endpoint, name == RoomCode.serviceName(self.code) {
                    self.browser?.cancel(); self.browser = nil
                    self.attach(NWConnection(to: result.endpoint, using: self.parameters(code: self.code)))
                    break
                }
            }
            }
        }
        browser.start(queue: .main)
    }

    private func attach(_ connection: NWConnection) {
        self.connection = connection; messages = TCPMessages(); connectionStarted = Date()
        status = "Connecting securely…"
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            Task { @MainActor in
            guard let self, let connection, self.connection === connection else { return }
            switch state {
            case .ready:
                self.connected = true; self.lastReceived = Date(); self.searchDeadline = .distantFuture
                self.status = self.role == .host ? "Player 2 connected" : "Connected as Player 2"
                self.receive(connection); self.onConnected?()
            case .failed:
                self.fail("Connection lost or room code rejected. Check Wi-Fi and join again.")
            case .waiting:
                self.status = "Waiting for Wi-Fi connection…"
            case .cancelled:
                break
            default: break
            }
            }
        }
        connection.start(queue: .main)
    }

    private func receive(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self, weak connection] data, _, complete, error in
            Task { @MainActor in
            guard let self, let connection, self.connection === connection else { return }
            if let data, !data.isEmpty {
                do {
                    let payloads = try self.messages.append(data)
                    let generation = self.generation
                    // Receive the next chunk only after processing this one. A slow
                    // peer cannot create an unbounded queue of decompressed scenes.
                    self.codingQueue.async {
                        let decoded = Result { try payloads.map { try RoomCodec.unpack($0) } }
                        DispatchQueue.main.async {
                            guard self.generation == generation, self.connection === connection else { return }
                            do {
                                for (type, body) in try decoded.get() {
                                    self.lastReceived = Date()
                                    switch type {
                                    case .ping: self.send(.pong)
                                    case .pong: break
                                    case .frameAck:
                                        if self.role == .host { self.frameOutstanding = false; self.flushFrame() }
                                    default: self.onMessage?(type, body)
                                    }
                                }
                                if complete || error != nil { self.fail("The other player disconnected.") }
                                else { self.receive(connection) }
                            } catch { self.fail(error.localizedDescription) }
                        }
                    }
                    return
                } catch { self.fail(error.localizedDescription); return }
            }
            if complete || error != nil { self.fail("The other player disconnected.") }
            else { self.receive(connection) }
            }
        }
    }

    func send(_ type: RoomMessage, _ body: Data = Data()) {
        guard connected, let connection else { return }
        let generation = generation
        codingQueue.async {
            let result = Result { try RoomCodec.packet(type, body) }
            DispatchQueue.main.async {
                guard self.generation == generation, self.connection === connection else { return }
                do { self.write(try result.get(), on: connection) } catch { self.fail(error.localizedDescription) }
            }
        }
    }
    private func write(_ data: Data, on connection: NWConnection) {
        connection.send(content: data, completion: .contentProcessed { [weak self, weak connection] error in
            Task { @MainActor in
            guard let self, self.connection === connection else { return }
            if let error { self.fail("Wi-Fi send failed: " + error.localizedDescription) }
            }
        })
    }
    func offer(_ frame: SharedFrame) {
        guard connected, role == .host else { return }
        // One frame in flight, one latest replacement. An application-level ACK
        // bounds latency even when TCP's socket send buffer has free space.
        var newest = frame
        if let pending = latestFrame, !frame.paused {
            // Coalesce visuals, but preserve the original audio from skipped
            // scenes. Cap retained audio at 260 ms to recover from slow Wi-Fi.
            newest.snapshot.pcm = Data((pending.snapshot.pcm + frame.snapshot.pcm).suffix(8192 * 4))
        }
        latestFrame = newest; flushFrame()
    }
    private func flushFrame() {
        guard !frameOutstanding, let frame = latestFrame, let connection, connected else { return }
        latestFrame = nil; frameOutstanding = true
        let generation = generation
        codingQueue.async {
            let result = Result { try RoomCodec.packet(.frame, frame.encode()) }
            DispatchQueue.main.async {
                guard self.generation == generation, self.connection === connection else { return }
                do { self.write(try result.get(), on: connection) } catch { self.fail(error.localizedDescription) }
            }
        }
    }
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
            guard let self else { return }
            let now = Date()
            if self.connected {
                if now.timeIntervalSince(self.lastReceived) > 8 { self.fail("Connection timed out. Check Wi-Fi and rejoin."); return }
                if now.timeIntervalSince(self.lastPing) >= 1 { self.lastPing = now; self.send(.ping) }
                self.onTick?()
            } else if self.connection != nil && now.timeIntervalSince(self.connectionStarted) > 10 {
                self.fail("Could not connect. Check the room code and try again.")
            } else if self.role == .guest && now > self.searchDeadline {
                self.fail("Room not found. Check the code, Wi-Fi and Local Network permission. Guest Wi-Fi may block connections.", stopRoom: true)
            }
            }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }
    func disconnect(_ reason: String) { fail(reason) }
    private func fail(_ reason: String, stopRoom: Bool = false) {
        let wasConnected = connected
        generation = UUID(); connection?.stateUpdateHandler = nil; connection?.cancel(); connection = nil
        connected = false; messages = TCPMessages(); frameOutstanding = false; latestFrame = nil
        if stopRoom || role == .guest { browser?.cancel(); browser = nil; listener?.cancel(); listener = nil; timer?.invalidate(); timer = nil }
        status = reason
        if wasConnected || role == .guest { onDisconnect?(reason) }
    }
    func stop() {
        generation = UUID(); timer?.invalidate(); timer = nil
        browser?.cancel(); browser = nil; listener?.cancel(); listener = nil
        connection?.stateUpdateHandler = nil; connection?.cancel(); connection = nil
        role = .none; code = ""; connected = false; status = "Not connected"
        messages = TCPMessages(); latestFrame = nil; frameOutstanding = false
    }
}
