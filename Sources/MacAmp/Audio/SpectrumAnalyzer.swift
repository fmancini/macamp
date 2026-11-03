import Accelerate
import AVFoundation

/// Turns the audio leaving the equalizer into 20 bars for the display.
/// `process` runs on the audio thread; `bars` can be read from anywhere.
nonisolated final class SpectrumAnalyzer: @unchecked Sendable {
    static let barCount = 20
    private static let size = 1_024

    private let setup: FFTSetup
    private let window: [Float]
    private let lock = NSLock()
    private var stored = [Float](repeating: 0, count: SpectrumAnalyzer.barCount)

    init() {
        setup = vDSP_create_fftsetup(10, FFTRadix(kFFTRadix2))!
        var hann = [Float](repeating: 0, count: Self.size)
        vDSP_hann_window(&hann, vDSP_Length(Self.size), Int32(vDSP_HANN_NORM))
        window = hann
    }

    deinit { vDSP_destroy_fftsetup(setup) }

    /// 0...1 per bar, most recent first reading.
    var bars: [Float] { lock.withLock { stored } }

    func reset() { lock.withLock { stored = [Float](repeating: 0, count: Self.barCount) } }

    func process(_ buffer: AVAudioPCMBuffer) {
        let n = Self.size
        guard let channel = buffer.floatChannelData?[0], Int(buffer.frameLength) >= n else { return }
        var windowed = [Float](repeating: 0, count: n)
        vDSP_vmul(channel, 1, window, 1, &windowed, 1, vDSP_Length(n))

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
        let rate = Float(buffer.format.sampleRate)
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
            let decibels = 10 * log10(power + 1e-12)
            bars[bar] = min(max((decibels + 80) / 70, 0), 1)
        }
        lock.withLock { stored = bars }
    }
}
