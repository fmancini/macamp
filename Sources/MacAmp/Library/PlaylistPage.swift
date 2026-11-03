import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import MacAmpKit

/// One playlist: drag to reorder, Delete to remove, double-click to play.
struct PlaylistPage: View {
    @Environment(Player.self) private var player
    @Query private var found: [Playlist]
    @Query private var tracks: [LibraryTrack]
    @State private var selection: Set<Int> = []

    init(id: UUID) {
        _found = Query(filter: #Predicate<Playlist> { $0.uuid == id })
    }

    var body: some View {
        if let playlist = found.first {
            content(playlist)
        } else {
            ContentUnavailableView("No Playlist", systemImage: "music.note.list")
        }
    }

    private func content(_ playlist: Playlist) -> some View {
        let known = Dictionary(tracks.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        return List(selection: $selection) {
            ForEach(Array(playlist.items.enumerated()), id: \.offset) { index, item in
                row(index: index + 1, item: item, track: known[item]).tag(index)
            }
            .onMove { playlist.items.move(fromOffsets: $0, toOffset: $1) }
            .onDelete { playlist.items.remove(atOffsets: $0) }
        }
        .contextMenu(forSelectionType: Int.self) { indexes in
            if !indexes.isEmpty {
                Button("Remove from Playlist") { remove(indexes, from: playlist) }
            }
        } primaryAction: { indexes in
            if let index = indexes.first { play(playlist, from: index) }
        }
        .onDeleteCommand { remove(selection, from: playlist); selection = [] }
        .dropDestination(for: URL.self) { urls, _ in
            let paths = Player.audioFiles(in: urls).map(\.path)
            LibraryModel.shared.add(paths, to: playlist)
            return !paths.isEmpty
        }
        .overlay {
            if playlist.items.isEmpty {
                ContentUnavailableView("This playlist is empty", systemImage: "music.note.list",
                                       description: Text("Drag tracks here from the Library, or use Add to Playlist."))
            }
        }
        .navigationTitle(playlist.name)
        .navigationSubtitle(playlist.items.isEmpty ? Text("") : Text("\(playlist.items.count) tracks"))
        .toolbar {
            ToolbarItem {
                Button("Play", systemImage: "play.fill") { play(playlist, from: 0) }
                    .help("Play this playlist from the start")
                    .disabled(LibraryModel.shared.tracks(of: playlist).isEmpty)
            }
            ToolbarItem {
                Menu("Export", systemImage: "square.and.arrow.up") {
                    Button("M3U Playlist\u{2026}") { export(playlist, as: .m3u) }
                    Button("PLS Playlist\u{2026}") { export(playlist, as: .pls) }
                }
                .help("Save this playlist as a file")
                .disabled(playlist.items.isEmpty)
            }
        }
    }

    private func row(index: Int, item: String, track: LibraryTrack?) -> some View {
        HStack(spacing: Space.md) {
            Text("\(index)").foregroundStyle(.secondary).monospacedDigit().frame(width: 24, alignment: .center)
            VStack(alignment: .leading, spacing: 0) {
                Text(title(item, track)).lineLimit(1)
                if let track, !track.artist.isEmpty {
                    Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                } else if item.contains("://") {
                    Text(item).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: Space.sm)
            if let track, track.duration > 0 {
                Text(Track.clock(track.duration)).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .opacity(isPlayable(item) ? 1 : 0.6)
    }

    private func title(_ item: String, _ track: LibraryTrack?) -> String {
        if let track { return track.title }
        return URL(fileURLWithPath: item).deletingPathExtension().lastPathComponent
    }

    private func isPlayable(_ item: String) -> Bool {
        item.contains("://") || FileManager.default.fileExists(atPath: item)
    }

    private func remove(_ indexes: Set<Int>, from playlist: Playlist) {
        playlist.items = playlist.items.enumerated().filter { !indexes.contains($0.offset) }.map(\.element)
    }

    private func play(_ playlist: Playlist, from index: Int) {
        let playable = LibraryModel.shared.tracks(of: playlist)
        guard !playable.isEmpty else { return }
        // The row index counts streams too; map it to the playable list.
        let before = playlist.items.prefix(index).filter { !$0.contains("://") }.count
        player.play(playable, startAt: min(before, playable.count - 1))
    }

    private func export(_ playlist: Playlist, as format: UTType) {
        LibraryPanels.savePlaylist(named: playlist.name, format: format) {
            LibraryModel.shared.exportPlaylist(playlist, as: format, to: $0)
        }
    }
}
