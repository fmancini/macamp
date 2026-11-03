import Accelerate
import AVFoundation

/// Turns the audio leaving the equalizer into 20 bars for the display.
///
/// The engine hands over audio in blocks of about 100 ms, which is too slow to
/// look alive. So the tap only keeps the samples; `bars` runs the FFT at the
/// moment of drawing, on the samples that are playing right now.
nonisolated final class SpectrumAnalyzer: @unchecked Sendable {
    static let barCount = 20
    private static let size = 1_024
    private static let ringSize = 16_384

    private let setup: FFTSetup
    private let window: [Float]
    private let lockPointer: UnsafeMutablePointer<os_unfair_lock>
    private var ring = [Float](repeating: 0, count: SpectrumAnalyzer.ringSize)
    /// Samples written so far, and where the latest block began on the clock.
    private var written = 0
    private var blockStart = 0
    private var blockHostSeconds = 0.0
    private var rate: Float = 44_100
    private var active = false
    /// Frames in the latest block, for diagnostics.
    private(set) var lastBlockFrames = 0

    init() {
        lockPointer = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        lockPointer.initialize(to: os_unfair_lock())
        setup = vDSP_create_fftsetup(10, FFTRadix(kFFTRadix2))!
        var hann = [Float](repeating: 0, count: Self.size)
        vDSP_hann_window(&hann, vDSP_Length(Self.size), Int32(vDSP_HANN_NORM))
        window = hann
    }

    deinit {
        vDSP_destroy_fftsetup(setup)
        lockPointer.deallocate()
    }

    private func withLock<T>(_ body: () -> T) -> T {
        os_unfair_lock_lock(lockPointer)
        defer { os_unfair_lock_unlock(lockPointer) }
        return body()
    }

    /// How far behind the newest samples the display looks, to match what is
    /// audible (the output device's latency), in frames.
    private var latencyFrames = 0
    func setRate(_ value: Float) { withLock { rate = value } }
    func setLatency(seconds: Double) { withLock { latencyFrames = Int(max(0, min(seconds, 0.1)) * Double(rate)) } }

    /// Render thread: copy channel 0 of this render pass. Never blocks: if the
    /// reader holds the lock, this pass is skipped (one missed block is invisible).
    func capture(_ list: UnsafeMutablePointer<AudioBufferList>, frames: Int, sampleRate: Float) {
        guard os_unfair_lock_trylock(lockPointer) else { return }
        defer { os_unfair_lock_unlock(lockPointer) }
        let buffers = UnsafeMutableAudioBufferListPointer(list)
        guard let first = buffers.first, let data = first.mData?.assumingMemoryBound(to: Float.self) else { return }
        if sampleRate > 0 { rate = sampleRate }
        for i in 0..<frames { ring[(written + i) % Self.ringSize] = data[i] }
        written += frames
        lastBlockFrames = frames
        lastCapture = mach_absolute_time()
        active = true
    }
    private var lastCapture: UInt64 = 0

    func reset() { withLock { active = false } }

    /// Audio thread: keep the samples and when they were rendered.
    func process(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)
        let seconds = time.isHostTimeValid ? AVAudioTime.seconds(forHostTime: time.hostTime)
                                           : AVAudioTime.seconds(forHostTime: mach_absolute_time())
        withLock {
            blockStart = written
            blockHostSeconds = seconds
            lastCapture = mach_absolute_time()
            rate = Float(buffer.format.sampleRate)
            for i in 0..<count { ring[(written + i) % Self.ringSize] = channel[i] }
            written += count
            lastBlockFrames = count
            active = true
        }
    }

    /// 0...1 per bar, for the samples playing now.
    var bars: [Float] {
        let size = Self.size
        var samples = [Float](repeating: 0, count: size)
        let ok: Bool = withLock {
            guard active, written >= size else { return false }
            // Stale audio (playback stopped): show silence.
            let age = AVAudioTime.seconds(forHostTime: mach_absolute_time()) - AVAudioTime.seconds(forHostTime: lastCapture)
            if age > 0.3 { return false }
            let end = min(max(written - latencyFrames, size), written)
            for i in 0..<size { samples[i] = ring[(end - size + i) % Self.ringSize] }
            return true
        }
        guard ok else { return [Float](repeating: 0, count: Self.barCount) }
        return analyze(samples)
    }

    private func analyze(_ input: [Float]) -> [Float] {
        let n = Self.size
        var windowed = [Float](repeating: 0, count: n)
        vDSP_vmul(input, 1, window, 1, &windowed, 1, vDSP_Length(n))
        var real = [Float](repeating: 0, count: n / 2)
        var imag = [Float](repeating: 0, count: n / 2)
        var magnitudes = [Float](repeating: 0, count: n / 2)
        real.withUnsafeMutableBufferPointer { realPointer in
            imag.withUnsafeMutableBufferPointer { imagPointer in
                var split = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imagPointer.baseAddress!)
                windowed.withUnsafeBufferPointer { pointer in
                    pointer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: n / 2) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(n / 2))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, 10, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(n / 2))
            }
        }
        // 20 bars, log-spaced from 40 Hz to 16 kHz.
        let binWidth = rate / Float(n)
        var bars = [Float](repeating: 0, count: Self.barCount)
        for bar in 0..<Self.barCount {
            let low = 40 * pow(400, Float(bar) / Float(Self.barCount))
            let high = 40 * pow(400, Float(bar + 1) / Float(Self.barCount))
            let from = max(1, min(Int(low / binWidth), n / 2 - 1))
            let to = max(from + 1, min(Int(high / binWidth) + 1, n / 2))
            var sum: Float = 0
            vDSP_sve(Array(magnitudes[from..<to]), 1, &sum, vDSP_Length(to - from))
            let power = sum / Float(to - from) / Float(n * n)
            bars[bar] = min(max((10 * log10(power + 1e-12) + 80) / 70, 0), 1)
        }
        return bars
    }
}
