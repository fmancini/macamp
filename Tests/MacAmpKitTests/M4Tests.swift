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

// MARK: M5

@Test func segmentsKeepAudioAndTitlesInOrder() {
    var parser = ICYStreamParser(metaInterval: 4)
    var data = Data([1, 2, 3, 4])
    var block = Data("StreamTitle='A';".utf8)
    block.append(Data(repeating: 0, count: 16 - block.count))
    data.append(1); data.append(block)
    data.append(Data([5, 6, 7, 8]))
    #expect(parser.segments(data) == [.audio(Data([1, 2, 3, 4])), .title("A"), .audio(Data([5, 6, 7, 8]))])
}

@Test func recordingNamesAreSafe() {
    #expect(RecordingNames.sanitize("AC/DC: Back in Black?") == "AC-DC- Back in Black-")
    #expect(RecordingNames.sanitize("..hidden") == "hidden")
    #expect(RecordingNames.sanitize(String(repeating: "x", count: 300)).count == 120)
    #expect(RecordingNames.fileExtension(forContentType: "audio/mpeg") == "mp3")
    #expect(RecordingNames.fileExtension(forContentType: "audio/aacp") == "aac")
    #expect(RecordingNames.fileExtension(forContentType: "audio/ogg") == nil)
}

@Test func takenNamesGetANumber() {
    let folder = URL(fileURLWithPath: "/tmp/rec")
    let taken: Set<String> = ["/tmp/rec/Song.mp3", "/tmp/rec/Song 2.mp3"]
    #expect(RecordingNames.unique("Song", ext: "mp3", in: folder, exists: { taken.contains($0.path) }).lastPathComponent == "Song 3.mp3")
}

@Test func duplicatesMatchOnTagsAndDuration() {
    let items = [
        DuplicateFinder.Item(id: "a", title: "Café Song", artist: "The Band", duration: 200),
        DuplicateFinder.Item(id: "b", title: "cafe  song", artist: "the band", duration: 201.5),
        DuplicateFinder.Item(id: "c", title: "Café Song", artist: "The Band", duration: 260),
        DuplicateFinder.Item(id: "d", title: "Other", artist: "The Band", duration: 200),
    ]
    #expect(DuplicateFinder.groups(items) == [["a", "b"]])
}

@Test func replayGainParsesAndLimits() {
    #expect(ReplayGain.parseGain("-6.54 dB") == -6.54)
    #expect(ReplayGain.parseGain("+3.2dB") == 3.2)
    #expect(ReplayGain.parseGain("loud") == nil)
    #expect(abs(ReplayGain.volume(gain: -6) - 0.5012) < 0.001)
    #expect(ReplayGain.volume(gain: 6) == 1)
    #expect(ReplayGain.volume(gain: nil) == 1)
    #expect(ReplayGain.volume(gain: -1, peak: 1.5) < 0.9)
}

@Test func helpDocumentSplitsTopicsAndBlocks() {
    let text = """
    # Help

    ## First
    One paragraph
    over two lines.

    - A bullet
    1. A step

    ## Second
    Text with **bold**.
    """
    let topics = HelpDocument.parse(text)
    #expect(topics.map(\.title) == ["First", "Second"])
    #expect(topics[0].blocks == [.paragraph("One paragraph over two lines."), .bullet("A bullet"), .step(1, "A step")])
    #expect(topics[1].plainText == "Text with **bold**.")
}
