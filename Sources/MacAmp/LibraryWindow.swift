import SwiftUI
import MacAmpKit

/// The Library window: a native sidebar window with the Library and the Queue.
struct LibraryWindow: View {
    @Environment(AppModel.self) private var model
    @Environment(Player.self) private var player
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $model.sidebar) { page in
                Label(page.title, systemImage: page.symbol).tag(page)
            }
            .navigationSplitViewColumnWidth(min: Layout.sidebarMin, ideal: Layout.sidebarIdeal)
        } detail: {
            switch model.sidebar ?? .library {
            case .library: LibraryPage()
            case .queue: QueuePage()
            }
        }
        .onAppear { player.undoManager = undoManager }
    }
}

/// Empty until the Library arrives in a later milestone.
struct LibraryPage: View {
    @Environment(Player.self) private var player

    var body: some View {
        ContentUnavailableView {
            Label("No Music Yet", systemImage: "music.note.house")
        } description: {
            Text("Open some audio files to start listening. They join the Queue.")
        } actions: {
            Button("Open Files\u{2026}") { Player.chooseFiles { player.open($0) } }
                .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Library")
    }
}
