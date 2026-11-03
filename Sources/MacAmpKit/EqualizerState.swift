import Foundation

/// A 10-band graphic equalizer with a preamp, like Winamp's.
public struct EqualizerState: Codable, Equatable, Sendable {
    public static let frequencies: [Float] = [60, 170, 310, 600, 1_000, 3_000, 6_000, 12_000, 14_000, 16_000]
    public static let range: ClosedRange<Float> = -12...12

    public var enabled = true
    public var preamp: Float = 0 { didSet { preamp = Self.clamp(preamp) } }
    public private(set) var bands: [Float] = Array(repeating: 0, count: 10)

    public init() {}

    public mutating func setBand(_ index: Int, to gain: Float) {
        guard bands.indices.contains(index) else { return }
        bands[index] = Self.clamp(gain)
    }

    public mutating func apply(_ preset: EqualizerPreset) {
        bands = preset.bands.map(Self.clamp)
        preamp = preset.preamp
    }

    /// The preset these settings match, if any.
    public var matchingPreset: EqualizerPreset? {
        EqualizerPreset.all.first { $0.bands == bands && $0.preamp == preamp }
    }

    static func clamp(_ gain: Float) -> Float { min(max(gain, range.lowerBound), range.upperBound) }
}

public struct EqualizerPreset: Identifiable, Equatable, Sendable {
    public var id: String { name }
    public let name: String
    public let preamp: Float
    public let bands: [Float]

    public static let all: [EqualizerPreset] = [
        EqualizerPreset(name: String(localized: "Flat"), preamp: 0, bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        EqualizerPreset(name: String(localized: "Rock"), preamp: -2, bands: [5, 4, 3, 1, -1, -1, 2, 4, 5, 5]),
        EqualizerPreset(name: String(localized: "Pop"), preamp: -2, bands: [-1, 2, 4, 5, 3, 0, -1, -1, 2, 3]),
        EqualizerPreset(name: String(localized: "Jazz"), preamp: -1, bands: [3, 2, 1, 2, -2, -2, 0, 1, 2, 3]),
        EqualizerPreset(name: String(localized: "Classical"), preamp: 0, bands: [0, 0, 0, 0, 0, 0, -3, -3, -3, -5]),
        EqualizerPreset(name: String(localized: "Dance"), preamp: -2, bands: [6, 5, 2, 0, 0, -3, -4, -4, 0, 0]),
        EqualizerPreset(name: String(localized: "Vocal"), preamp: -1, bands: [-2, -3, -3, 1, 4, 4, 3, 1, 0, -1]),
        EqualizerPreset(name: String(localized: "Bass Boost"), preamp: -3, bands: [7, 6, 5, 3, 1, 0, 0, 0, 0, 0]),
        EqualizerPreset(name: String(localized: "Treble Boost"), preamp: -3, bands: [0, 0, 0, 0, 0, 1, 3, 5, 6, 7]),
    ]
}
