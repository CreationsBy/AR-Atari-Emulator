import AVFoundation

final class AudioOutput {
    private var engine: AVAudioEngine?
    private var source: AVAudioSourceNode?
    var volume: Float = 0.7 { didSet { engine?.mainMixerNode.outputVolume = volume } }

    func start(sampleRate: Double) throws {
        stop()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setPreferredIOBufferDuration(0.01)
        try session.setActive(true)
        let engine = AVAudioEngine()
        // Native ring is stereo interleaved, source bus is stereo noninterleaved.
        // Scratch allocation happens once, outside the real-time render callback.
        let scratch = UnsafeMutablePointer<Float>.allocate(capacity: 16384 * 2)
        scratch.initialize(repeating: 0, count: 16384 * 2)
        let storage = AudioScratch(pointer: scratch)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let source = AVAudioSourceNode(format: format) { _, _, count, list -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(list)
            let frames = min(Int(count), 16384)
            _ = ad_audio_read(storage.pointer, frames)
            for channel in 0..<buffers.count {
                guard let data = buffers[channel].mData?.assumingMemoryBound(to: Float.self) else { continue }
                for i in 0..<frames { data[i] = storage.pointer[i * 2 + min(channel, 1)] }
                if Int(count) > frames { for i in frames..<Int(count) { data[i] = 0 } }
            }
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = volume
        engine.prepare()
        try engine.start()
        self.source = source; self.engine = engine
    }
    func pause() { engine?.pause() }
    func resume() throws { if let engine, !engine.isRunning { try engine.start() } }
    func stop() {
        engine?.stop()
        if let engine, let source { engine.detach(source) }
        source = nil; engine = nil
    }
    deinit { stop() }
}
private final class AudioScratch {
    let pointer: UnsafeMutablePointer<Float>
    init(pointer: UnsafeMutablePointer<Float>) { self.pointer = pointer }
    deinit { pointer.deallocate() }
}
