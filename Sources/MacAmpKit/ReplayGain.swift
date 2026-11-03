import Foundation

/// ReplayGain: play tracks at similar loudness using gain tags in the files.
public enum ReplayGain {
    public enum Mode: String, CaseIterable, Sendable { case off, track, album }

    /// Reads "-6.54 dB", "+3.2dB" or "-6.54" as decibels.
    public static func parseGain(_ text: String) -> Double? {
        let cleaned = text.lowercased().replacingOccurrences(of: "db", with: "").trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    /// Reads a peak like "0.988553" (1.0 is full scale).
    public static func parsePeak(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces))
    }

    /// The linear volume (0...1) for a track.
    /// - gain: the tag's gain in dB; preamp: extra dB; peak: the track's peak, to avoid clipping.
    /// The player's volume cannot go above 1, so positive gains are limited to what the peak allows.
    public static func volume(gain: Double?, preamp: Double = 0, peak: Double? = nil, preventClipping: Bool = true) -> Float {
        guard let gain else { return 1 }
        var factor = pow(10, (gain + preamp) / 20)
        if preventClipping, let peak, peak > 0 { factor = min(factor, 1 / peak) }
        return Float(min(max(factor, 0), 1))
    }
}
