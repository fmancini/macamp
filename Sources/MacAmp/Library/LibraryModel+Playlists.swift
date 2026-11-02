import AppKit
import Foundation
import MacAmpKit
import SwiftData
import UniformTypeIdentifiers

extension LibraryModel {
    var playlists: [Playlist] {
        (try? context.fetch(FetchDescriptor<Playlist>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    @discardableResult
    func createPlaylist(name: String, items: [String] = []) -> Playlist {
        let clean = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let playlist = Playlist(name: clean.isEmpty ? "New Playlist" : clean, items: items)
        context.insert(playlist)
        try? context.save()
        return playlist
    }

    func deletePlaylist(_ playlist: Playlist) {
        context.delete(playlist)
        try? context.save()
    }

    func add(_ items: [String], to playlist: Playlist) {
        playlist.items += items
        try? context.save()
    }

    /// Tracks of a playlist that can be played from disk, with the Library's tags when known.
    func tracks(of playlist: Playlist) -> [Track] {
        let known = Dictionary(((try? context.fetch(FetchDescriptor<LibraryTrack>())) ?? []).map { ($0.path, $0) },
                               uniquingKeysWith: { first, _ in first })
        return playlist.items.filter { !$0.contains("://") }.map { path in
            known[path]?.queueTrack ?? Track(url: URL(fileURLWithPath: path))
        }
    }

    // MARK: Import and export

    /// Reads an M3U, M3U8, or PLS file into a new playlist named after the file.
    @discardableResult
    func importPlaylist(from url: URL) -> Playlist? {
        guard let text = try? String(contentsOf: url, encoding: .utf8)
                ?? String(contentsOf: url, encoding: .isoLatin1) else { return nil }
        let entries = PlaylistFile.parse(text, baseURL: url.deletingLastPathComponent())
        guard !entries.isEmpty else { return nil }
        return createPlaylist(name: url.deletingPathExtension().lastPathComponent, items: entries.map(\.location))
    }

    func exportPlaylist(_ playlist: Playlist, as format: UTType, to url: URL) {
        let known = Dictionary(((try? context.fetch(FetchDescriptor<LibraryTrack>())) ?? []).map { ($0.path, $0.title) },
                               uniquingKeysWith: { first, _ in first })
        let entries = playlist.items.map { PlaylistEntry(location: $0, title: known[$0]) }
        let text = format == .pls ? PlaylistFile.pls(entries) : PlaylistFile.m3u(entries)
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}

extension UTType {
    static let pls = UTType(filenameExtension: "pls") ?? .data
    static let m3u = UTType(filenameExtension: "m3u") ?? .data
    static let m3u8 = UTType(filenameExtension: "m3u8") ?? .data
}

/// Open and save panels for the Library.
enum LibraryPanels {
    static func chooseFolder(_ handle: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Add Folder to Library"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"
        if panel.runModal() == .OK, let url = panel.url { handle(url) }
    }

    static func choosePlaylist(_ handle: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Import Playlist"
        panel.allowedContentTypes = [.m3u, .m3u8, .pls]
        panel.prompt = "Import"
        if panel.runModal() == .OK, let url = panel.url { handle(url) }
    }

    static func savePlaylist(named name: String, format: UTType, _ handle: @escaping (URL) -> Void) {
        let panel = NSSavePanel()
        panel.title = "Export Playlist"
        panel.nameFieldStringValue = name + "." + (format == .pls ? "pls" : "m3u")
        panel.allowedContentTypes = [format]
        if panel.runModal() == .OK, let url = panel.url { handle(url) }
    }
}
