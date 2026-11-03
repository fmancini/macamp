import CoreGraphics
import Foundation
import Testing
@testable import MacAmpKit

@Test func equalizerClampsGains() {
    var eq = EqualizerState()
    eq.setBand(0, to: 40)
    eq.setBand(1, to: -40)
    eq.preamp = 99
    #expect(eq.bands[0] == 12 && eq.bands[1] == -12 && eq.preamp == 12)
    eq.setBand(20, to: 3)
    #expect(eq.bands.count == 10)
}

@Test func everyPresetHasTenBandsInRange() {
    for preset in EqualizerPreset.all {
        #expect(preset.bands.count == 10, "\(preset.name)")
        #expect(preset.bands.allSatisfy { EqualizerState.range.contains($0) })
    }
}

@Test func applyingAPresetMatchesIt() {
    var eq = EqualizerState()
    eq.apply(EqualizerPreset.all[1])
    #expect(eq.matchingPreset?.name == "Rock")
    eq.setBand(3, to: 11)
    #expect(eq.matchingPreset == nil)
}

@Test func equalizerSurvivesJSON() throws {
    var eq = EqualizerState()
    eq.apply(EqualizerPreset.all[3])
    let back = try JSONDecoder().decode(EqualizerState.self, from: JSONEncoder().encode(eq))
    #expect(back == eq)
}

@Test func windowsSnapWithinEightPoints() {
    let player = CGRect(x: 0, y: 0, width: 320, height: 148)
    let moving = CGRect(x: 324, y: 3, width: 320, height: 160)
    let offset = WindowSnap.offset(for: moving, to: [player], distance: 8)
    #expect(offset == CGPoint(x: -4, y: -3))
}

@Test func farWindowsDoNotSnap() {
    let player = CGRect(x: 0, y: 0, width: 320, height: 148)
    let moving = CGRect(x: 400, y: 0, width: 320, height: 160)
    #expect(WindowSnap.offset(for: moving, to: [player], distance: 8) == .zero)
}

@Test func stackedWindowsAreDocked() {
    let top = CGRect(x: 0, y: 160, width: 320, height: 148)
    let bottom = CGRect(x: 0, y: 0, width: 320, height: 160)
    #expect(WindowSnap.areDocked(top, bottom))
    #expect(!WindowSnap.areDocked(top, CGRect(x: 0, y: 0, width: 320, height: 100)))
}

@Test func keyComboDisplaysLikeAMenu() {
    #expect(KeyCombo(keyCode: 49, modifiers: KeyCombo.control | KeyCombo.option).display == "\u{2303}\u{2325}Space")
    #expect(KeyCombo(keyCode: 124, modifiers: KeyCombo.command | KeyCombo.shift).display == "\u{21E7}\u{2318}\u{2192}")
    #expect(!KeyCombo(keyCode: 0, modifiers: KeyCombo.shift).isValidGlobal)
    #expect(KeyCombo(keyCode: 0, modifiers: KeyCombo.command).isValidGlobal)
}
