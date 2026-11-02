import Foundation
import Testing
@testable import MacAmpKit

@Test func m3uWithExtinfParses() {
    let text = "#EXTM3U\n#EXTINF:215,Artist - Song\n/Music/song.mp3\n\n#EXTINF:-1,Radio\nhttps://example.com/stream\n"
    let entries = PlaylistFile.parse(text)
    #expect(entries.count == 2)
    #expect(entries[0] == PlaylistEntry(location: "/Music/song.mp3", title: "Artist - Song"))
    #expect(entries[1].isStream)
}

@Test func relativePathsResolveAgainstThePlaylistFolder() {
    let base = URL(fileURLWithPath: "/Users/me/Playlists")
    let entries = PlaylistFile.parse("../Music/a.mp3\nb.mp3\n", baseURL: base)
    #expect(entries.map(\.location) == ["/Users/me/Music/a.mp3", "/Users/me/Playlists/b.mp3"])
}

@Test func plsParsesInOrderAndIgnoresCase() {
    let text = "[playlist]\nTitle2=Two\nfile2=/b.mp3\nFile1=/a.mp3\nNumberOfEntries=2\nVersion=2\n"
    let entries = PlaylistFile.parse(text)
    #expect(entries == [PlaylistEntry(location: "/a.mp3", title: nil), PlaylistEntry(location: "/b.mp3", title: "Two")])
}

@Test func fileURLsBecomePaths() {
    #expect(PlaylistFile.parse("file:///Music/a.mp3\n").first?.location == "/Music/a.mp3")
}

@Test func exportThenImportGivesTheSameEntries() {
    let entries = [PlaylistEntry(location: "/a.mp3", title: "A"), PlaylistEntry(location: "https://x.test/s", title: "Radio")]
    #expect(PlaylistFile.parse(PlaylistFile.m3u(entries)) == entries)
    #expect(PlaylistFile.parse(PlaylistFile.pls(entries)) == entries)
}

@Test func byteOrderMarkAndBlankLinesAreIgnored() {
    #expect(PlaylistFile.parse("\u{FEFF}#EXTM3U\n\n/a.mp3\n").map(\.location) == ["/a.mp3"])
}
