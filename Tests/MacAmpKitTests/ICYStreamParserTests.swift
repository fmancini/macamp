import Foundation
import Testing
@testable import MacAmpKit

/// A stream with 8 audio bytes between metadata blocks.
private func stream(titles: [String?], interval: Int = 8) -> (data: Data, audio: Data) {
    var data = Data(), audio = Data()
    for (i, title) in titles.enumerated() {
        let chunk = Data((0..<interval).map { UInt8((i * interval + $0) % 251) })
        data.append(chunk)
        audio.append(chunk)
        if let title {
            var text = Data("StreamTitle='\(title)';".utf8)
            let blocks = (text.count + 15) / 16
            text.append(Data(repeating: 0, count: blocks * 16 - text.count))
            data.append(UInt8(blocks))
            data.append(text)
        } else {
            data.append(0)
        }
    }
    return (data, audio)
}

@Test func titlesAndAudioAreSeparated() {
    let (data, audio) = stream(titles: ["Artist - Song", nil, "Next Song"])
    var parser = ICYStreamParser(metaInterval: 8)
    let out = parser.feed(data)
    #expect(out.audio == audio)
    #expect(out.titles == ["Artist - Song", "Next Song"])
}

@Test func chunksMaySplitAnywhere() {
    let (data, audio) = stream(titles: ["A long title that spans two metadata blocks!", "Short"])
    var parser = ICYStreamParser(metaInterval: 8)
    var gotAudio = Data(), gotTitles: [String] = []
    for byte in data {
        let out = parser.feed(Data([byte]))
        gotAudio.append(out.audio)
        gotTitles += out.titles
    }
    #expect(gotAudio == audio)
    #expect(gotTitles == ["A long title that spans two metadata blocks!", "Short"])
}

@Test func aStreamWithoutMetadataPassesThrough() {
    var parser = ICYStreamParser(metaInterval: 0)
    let out = parser.feed(Data([1, 2, 3]))
    #expect(out.audio == Data([1, 2, 3]) && out.titles.isEmpty)
}

@Test func emptyAndMissingTitlesAreIgnored() {
    #expect(ICYStreamParser.title(in: Data("StreamTitle='';".utf8)) == nil)
    #expect(ICYStreamParser.title(in: Data("StreamUrl='x';".utf8)) == nil)
}

@Test func titlesMayContainApostrophes() {
    #expect(ICYStreamParser.title(in: Data("StreamTitle='Don't Stop';StreamUrl='';".utf8)) == "Don't Stop")
}

@Test func latin1TitlesDecode() {
    let block = Data("StreamTitle='Caf".utf8) + Data([0xE9]) + Data("';".utf8)
    #expect(ICYStreamParser.title(in: block) == "Café")
}

@Test func radioBrowserJSONDecodes() throws {
    let json = #"[{"stationuuid":"u1","name":" Jazz FM ","url":"http://x/a.m3u","url_resolved":"http://x/a","codec":"MP3","bitrate":128,"country":"US","tags":"jazz","favicon":"","hls":0}]"#
    let station = try JSONDecoder().decode([RadioBrowserStation].self, from: Data(json.utf8)).first?.station
    #expect(station?.name == "Jazz FM" && station?.url == "http://x/a" && station?.isHLS == false)
}

@Test func historyCSVQuotesTitles() {
    let csv = HistoryCSV.make([(Date(timeIntervalSince1970: 0), "Jazz, FM", "She said \"hi\"")])
    #expect(csv == "Time,Station,Title\n1970-01-01T00:00:00Z,\"Jazz, FM\",\"She said \"\"hi\"\"\"\n")
}
