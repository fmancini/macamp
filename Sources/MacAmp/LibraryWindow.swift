import SwiftData
import SwiftUI
import MacAmpKit

/// The Library window: a native sidebar window with the Library, the Queue, and playlists.
struct LibraryWindow: View {
    @Environment(AppModel.self) private var model
    @Environment(Player.self) private var player
    @Environment(\.undoManager) private var undoManager
    @Query(sort: \Playlist.createdAt) private var playlists: [Playlist]
    @State private var naming: NameRequest?
    @State private var name = ""

    /// A pending "name this playlist" dialog: a new one, or a rename.
    private struct NameRequest: Identifiable {
        let id = UUID()
        var renaming: Playlist?
    }

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(selection: $model.selection) {
                Section {
                    ForEach(SidebarItem.allCases) { page in
                        Label(page.title, systemImage: page.symbol).tag(SidebarSelection.page(page))
                    }
                }
                Section("Playlists") {
                    ForEach(playlists) { playlist in
                        Label(playlist.name, systemImage: "music.note.list")
                            .tag(SidebarSelection.playlist(playlist.uuid))
                            .dropDestination(for: URL.self) { urls, _ in
                                let paths = Player.audioFiles(in: urls).map(\.path)
                                LibraryModel.shared.add(paths, to: playlist)
                                return !paths.isEmpty
                            }
                            .contextMenu {
                                Button("Rename\u{2026}") { name = playlist.name; naming = NameRequest(renaming: playlist) }
                                Button("Delete", role: .destructive) { delete(playlist) }
                            }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: Layout.sidebarMin, ideal: Layout.sidebarIdeal)
            .safeAreaInset(edge: .bottom) {
                Button("New Playlist", systemImage: "plus") { name = ""; naming = NameRequest() }
                    .buttonStyle(.borderless)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Space.md)
                    .help("Create an empty playlist")
            }
        } detail: {
            switch model.selection ?? .page(.library) {
            case .page(.library): LibraryPage()
            case .page(.queue): QueuePage()
            case .playlist(let id): PlaylistPage(id: id)
            }
        }
        .onAppear { player.undoManager = undoManager }
        .alert(naming?.renaming == nil ? "New Playlist" : "Rename Playlist", isPresented: Binding(
            get: { naming != nil }, set: { if !$0 { naming = nil } })) {
            TextField("Name", text: $name)
            Button(naming?.renaming == nil ? "Create" : "Rename") { commitName() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func commitName() {
        if let playlist = naming?.renaming {
            let clean = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            if !clean.isEmpty { playlist.name = clean }
        } else {
            let created = LibraryModel.shared.createPlaylist(name: name)
            model.selection = .playlist(created.uuid)
        }
        naming = nil
    }

    private func delete(_ playlist: Playlist) {
        if model.selection == .playlist(playlist.uuid) { model.selection = .page(.library) }
        LibraryModel.shared.deletePlaylist(playlist)
    }
}
