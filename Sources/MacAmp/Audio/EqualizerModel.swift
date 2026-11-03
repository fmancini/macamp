import AVFoundation
import MacAmpKit
import Observation

/// The 10-band equalizer between the player node and the volume. Radio and
/// local files both pass through it. The settings are saved.
@Observable
final class EqualizerModel {
    let unit = AVAudioUnitEQ(numberOfBands: 10)
    var state: EqualizerState {
        didSet {
            if let data = try? JSONEncoder().encode(state) { Store.defaults.set(data, forKey: "equalizer.state") }
            apply()
        }
    }

    init() {
        if let data = Store.defaults.data(forKey: "equalizer.state"),
           let saved = try? JSONDecoder().decode(EqualizerState.self, from: data) {
            state = saved
        } else {
            state = EqualizerState()
        }
        for (index, band) in unit.bands.enumerated() {
            band.filterType = .parametric
            band.frequency = EqualizerState.frequencies[index]
            band.bandwidth = 1.0
        }
        apply()
    }

    private func apply() {
        for (index, band) in unit.bands.enumerated() {
            band.gain = state.bands[index]
            band.bypass = false
        }
        unit.globalGain = state.preamp
        unit.bypass = !state.enabled
    }
}
