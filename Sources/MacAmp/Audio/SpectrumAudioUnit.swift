import AVFoundation
import AudioToolbox

/// A pass-through audio unit that copies what flows through it into the
/// spectrum analyzer. It runs once per render pass (about every 10 ms), unlike
/// an engine tap, which delivers audio in blocks of about 100 ms.
nonisolated final class SpectrumAudioUnit: AUAudioUnit, @unchecked Sendable {
    /// Set before the unit is created.
    nonisolated(unsafe) static var analyzer: SpectrumAnalyzer?

    static let description = AudioComponentDescription(
        componentType: kAudioUnitType_Effect, componentSubType: 0x6D73_7063, // 'mspc'
        componentManufacturer: 0x6D61_6D70, componentFlags: 0, componentFlagsMask: 0) // 'mamp'

    private var inputs: AUAudioUnitBusArray!
    private var outputs: AUAudioUnitBusArray!

    override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        inputs = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [try AUAudioUnitBus(format: format)])
        outputs = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [try AUAudioUnitBus(format: format)])
    }

    override var inputBusses: AUAudioUnitBusArray { inputs }
    override var outputBusses: AUAudioUnitBusArray { outputs }
    override var canProcessInPlace: Bool { true }

    override func shouldChange(to format: AVAudioFormat, for bus: AUAudioUnitBus) -> Bool {
        format.commonFormat == .pcmFormatFloat32 && !format.isInterleaved
    }

    override var internalRenderBlock: AUInternalRenderBlock {
        let analyzer = Self.analyzer
        return { flags, timestamp, frameCount, _, output, _, pull in
            guard let pull else { return kAudioUnitErr_NoConnection }
            let status = pull(flags, timestamp, frameCount, 0, output)
            if status == noErr, let analyzer {
                // The sample rate is only needed for the bar layout; the first bus format has it.
                analyzer.capture(output, frames: Int(frameCount), sampleRate: 0)
            }
            return status
        }
    }

    private static let registration: Void = {
        AUAudioUnit.registerSubclass(SpectrumAudioUnit.self, as: description, name: "MacAmp: Spectrum", version: 1)
    }()

    /// Creates the unit as an engine node.
    static func make(analyzer: SpectrumAnalyzer) async -> AVAudioUnit? {
        Self.analyzer = analyzer
        _ = registration
        return try? await AVAudioUnit.instantiate(with: description, options: [])
    }
}
