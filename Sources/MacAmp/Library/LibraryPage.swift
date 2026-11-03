import SwiftData
import SwiftUI
import MacAmpKit

/// The Library: a column browser over a sortable table of every track.
struct LibraryPage: View {
    @Environment(Player.self) private var player
    /// Only this folder's tracks, or the whole Library when nil.
    let folder: String?
    @Query(sort: \LibraryTrack.title) private var allTracks: [LibraryTrack]
    @Query(sort: \Playlist.createdAt) private var playlists: [Playlist]
    private var library = LibraryModel.shared
    @Environment(AppModel.self) private var model

    init(folder: String? = nil) { self.folder = folder }

    private var tracks: [LibraryTrack] { folder.map { path in allTracks.filter { $0.folderPath == path } } ?? allTracks }

    @State private var query = ""
    @State private var sortOrder = [KeyPathComparator(\LibraryTrack.title)]
    @State private var selection: Set<PersistentIdentifier> = []
    @State private var genre = ""
    @State private var artist = ""
    @State private var album = ""
    @State private var showInspector = false
    @State private var showDuplicates = false
    @State private var confirmMissing = false
    @SceneStorage("libraryColumns") private var columns: TableColumnCustomization<LibraryTrack>

    // MARK: Rows

    private var byGenre: [LibraryTrack] { genre.isEmpty ? tracks : tracks.filter { $0.genre == genre } }
    private var byArtist: [LibraryTrack] { artist.isEmpty ? byGenre : byGenre.filter { $0.artist == artist } }
    private var byAlbum: [LibraryTrack] { album.isEmpty ? byArtist : byArtist.filter { $0.album == album } }

    private var rows: [LibraryTrack] {
        var list = byAlbum
        if !query.isEmpty {
            list = list.filter {
                $0.title.localizedStandardContains(query) || $0.artist.localizedStandardContains(query)
                    || $0.album.localizedStandardContains(query)
            }
        }
        return list.sorted(using: sortOrder)
    }

    private var missingCount: Int { tracks.filter { !$0.isAvailable }.count }

    private var selectedTracks: [LibraryTrack] { rows.filter { selection.contains($0.persistentModelID) } }

    var body: some View {
        VStack(spacing: 0) {
            if !tracks.isEmpty {
                ColumnBrowser(genre: $genre, artist: $artist, album: $album,
                              genres: counts(\.genre, in: tracks),
                              artists: counts(\.artist, in: byGenre),
                              albums: counts(\.album, in: byArtist))
                Divider()
            }
            if tracks.isEmpty { empty } else { table }
        }
        .inspector(isPresented: $showInspector) {
            TrackInspector(tracks: selectedTracks)
                .inspectorColumnWidth(min: 220, ideal: 260, max: 360)
        }
        .searchable(text: $query, prompt: "Search Library")
        .overlay {
            if !tracks.isEmpty, rows.isEmpty {
                if query.isEmpty {
                    ContentUnavailableView("No Matching Tracks", systemImage: "line.3.horizontal.decrease.circle",
                                           description: Text("Choose All in the Genre, Artist, or Album column to see more."))
                } else {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .navigationTitle(folder.map { URL(fileURLWithPath: $0).lastPathComponent } ?? String(localized: "Library"))
        .navigationSubtitle(tracks.isEmpty ? Text("") : Text("\(rows.count) of \(tracks.count) tracks"))
        .toolbar { toolbar }
        .sheet(isPresented: $showDuplicates) { DuplicatesSheet() }
        .confirmationDialog("Remove \(missingCount) Missing Tracks?", isPresented: $confirmMissing) {
            Button("Remove from Library", role: .destructive) { library.removeMissing(inFolder: folder) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("These files are no longer on your Mac. Only the Library entries are removed.")
        }
        .onChange(of: genre) { artist = ""; album = "" }
        .onChange(of: artist) { album = "" }
    }

    private var table: some View {
        Table(of: LibraryTrack.self, selection: $selection, sortOrder: $sortOrder, columnCustomization: $columns) {
            TableColumn("Title", value: \.title) { track in
                HStack(spacing: Space.xs) {
                    if !track.isAvailable {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Surface.warning)
                            .help("File not found")
                    }
                    Text(track.title).lineLimit(1)
                }
                .opacity(track.isAvailable ? 1 : 0.6)
            }
            .customizationID("title")
            TableColumn("Artist", value: \.artist) { Text($0.artist).lineLimit(1) }
                .customizationID("artist")
            TableColumn("Album", value: \.album) { Text($0.album).lineLimit(1) }
                .customizationID("album")
            TableColumn("Genre", value: \.genre) { Text($0.genre).lineLimit(1) }
                .customizationID("genre")
            TableColumn("Year", value: \.year) { Text($0.year == 0 ? "" : String($0.year)).monospacedDigit() }
                .width(min: 44, ideal: 52, max: 64)
                .customizationID("year")
            TableColumn("#", value: \.trackNumber) { Text($0.trackNumber == 0 ? "" : String($0.trackNumber)).monospacedDigit() }
                .width(min: 32, ideal: 40, max: 48)
                .customizationID("number")
            TableColumn("Time", value: \.duration) {
                Text($0.duration > 0 ? Track.clock($0.duration) : "").monospacedDigit().foregroundStyle(.secondary)
            }
            .width(min: 48, ideal: 56, max: 72)
            .customizationID("time")
        } rows: {
            ForEach(rows) { track in
                TableRow(track).draggable(track.url)
            }
        }
        .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
            menu(for: ids)
        } primaryAction: { ids in
            if let id = ids.first { play(from: id) }
        }
    }

    @ViewBuilder
    private func menu(for ids: Set<PersistentIdentifier>) -> some View {
        if let first = ids.first {
            Button("Play") { play(from: first) }
            Button("Add to Queue") {
                player.addToQueue(rows.filter { ids.contains($0.persistentModelID) }.map(\.queueTrack))
            }
            Menu("Add to Playlist") {
                if playlists.isEmpty { Text("No Playlists") }
                ForEach(playlists) { playlist in
                    Button(playlist.name) {
                        library.add(rows.filter { ids.contains($0.persistentModelID) }.map(\.path), to: playlist)
                    }
                }
            }
            Divider()
            Button("Remove from Library") {
                library.remove(rows.filter { ids.contains($0.persistentModelID) })
                selection = []
            }
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting(rows.filter { ids.contains($0.persistentModelID) }.map(\.url))
            }
        }
    }

    @ViewBuilder
    private var empty: some View {
        if folder != nil {
            ContentUnavailableView {
                Label(library.isScanning ? LocalizedStringKey("Reading this folder\u{2026}") : LocalizedStringKey("No Music in This Folder"), systemImage: "folder")
            } description: {
                library.isScanning ? Text("Tracks appear as they are read.") : Text("MacAmp found no audio files here.")
            }
        } else {
            emptyLibrary
        }
    }

    private var emptyLibrary: some View {
        ContentUnavailableView {
            Label("No Music Yet", systemImage: "music.note.house")
        } description: {
            Text("Add a folder with your music. MacAmp reads it once and then watches it for changes.")
        } actions: {
            Button("Add Folder\u{2026}") { addFolder() }
                .buttonStyle(.borderedProminent)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem {
            Button("Add Folder\u{2026}", systemImage: "folder.badge.plus") { addFolder() }
                .help("Add a music folder to the Library (\u{21E7}\u{2318}O)")
        }
        ToolbarItem {
            Button("Remove Missing Tracks\u{2026}", systemImage: "trash.slash") { confirmMissing = true }
                .help(missingCount == 0 ? Text("No tracks are missing") : Text("Remove the \(missingCount) tracks whose files were deleted"))
                .disabled(missingCount == 0)
        }
        ToolbarItem {
            Button("Find Duplicates\u{2026}", systemImage: "square.on.square") { showDuplicates = true }
                .help("Find tracks that appear more than once")
                .disabled(tracks.count < 2)
        }
        ToolbarItem {
            Button("Inspector", systemImage: "sidebar.trailing") { showInspector.toggle() }
                .help("Show or hide the track inspector (\u{2325}\u{2318}I)")
        }
        ToolbarItem(placement: .status) {
            if library.isScanning {
                HStack(spacing: Space.sm) {
                    ProgressView().controlSize(.small)
                    (library.total > 0 ? Text("Scanning \(library.scanned) of \(library.total)") : Text("Scanning\u{2026}"))
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
    }

    // MARK: Actions

    private func addFolder() {
        LibraryPanels.chooseFolder { url in
            Task {
                await library.addFolder(url)
                model.selection = .folder(url.standardizedFileURL.path)
            }
        }
    }

    private func play(from id: PersistentIdentifier) {
        let playable = rows.filter(\.isAvailable)
        guard let index = playable.firstIndex(where: { $0.persistentModelID == id }) else { return }
        player.play(playable.map(\.queueTrack), startAt: index)
    }

    /// Distinct non-empty values with their counts, sorted the way Finder sorts.
    private func counts(_ key: KeyPath<LibraryTrack, String>, in list: [LibraryTrack]) -> [(value: String, count: Int)] {
        Dictionary(grouping: list.filter { !$0[keyPath: key].isEmpty }, by: { $0[keyPath: key] })
            .map { ($0.key, $0.value.count) }
            .sorted { $0.0.localizedStandardCompare($1.0) == .orderedAscending }
    }
}
