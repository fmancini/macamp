import SwiftUI
import MacAmpKit

/// The Queue: tracks that play now and next. Drag to reorder, Delete to remove.
struct QueuePage: View {
    @Environment(Player.self) private var player
    @State private var selection: Set<Track.ID> = []
    @State private var confirmClear = false
    @State private var saving = false
    @State private var playlistName = ""

    var body: some View {
        List(selection: $selection) {
            ForEach(Array(player.queue.tracks.enumerated()), id: \.element.id) { index, track in
                QueueRow(index: index + 1, track: track,
                         isCurrent: track.id == player.queue.currentID,
                         isPlaying: player.isPlaying,
                         isUnavailable: player.unavailable.contains(track.id))
                    .tag(track.id)
            }
            .onMove { player.move(from: $0, to: $1) }
            .onDelete { offsets in
                player.remove(ids: Set(offsets.map { player.queue.tracks[$0].id }))
            }
        }
        .contextMenu(forSelectionType: Track.ID.self) { ids in
            if !ids.isEmpty {
                Button("Remove from Queue") { player.remove(ids: ids) }
            }
        } primaryAction: { ids in
            if let id = ids.first { player.playTrack(id) }
        }
        .onDeleteCommand { player.remove(ids: selection); selection = [] }
        .dropDestination(for: URL.self) { urls, _ in
            player.open(urls)
            return true
        }
        .overlay {
            if player.queue.isEmpty {
                ContentUnavailableView {
                    Label("The Queue is empty", systemImage: "list.bullet")
                } description: {
                    Text("Drop audio files here, or open some.")
                } actions: {
                    Button("Open Files\u{2026}") { Player.chooseFiles { player.open($0) } }
                }
            }
        }
        .navigationTitle("Queue")
        .navigationSubtitle(player.queue.isEmpty ? Text("") : Text("\(player.queue.tracks.count) tracks"))
        .toolbar {
            ToolbarItem {
                Button("Open Files\u{2026}", systemImage: "plus") { Player.chooseFiles { player.open($0) } }
                    .help("Add audio files to the Queue (\u{2318}O)")
            }
            ToolbarItem {
                Button("Save as Playlist\u{2026}", systemImage: "square.and.arrow.down") { playlistName = ""; saving = true }
                    .help("Save the Queue as a playlist")
                    .disabled(player.queue.isEmpty)
            }
            ToolbarItem {
                Button("Clear Queue", systemImage: "trash") {
                    if player.queue.tracks.count > 1 { confirmClear = true } else { player.clearQueue() }
                }
                .help("Remove every track from the Queue")
                .disabled(player.queue.isEmpty)
            }
        }
        .alert("Save as Playlist", isPresented: $saving) {
            TextField("Name", text: $playlistName)
            Button("Save") {
                LibraryModel.shared.createPlaylist(name: playlistName, items: player.queue.tracks.map(\.path))
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Remove \(player.queue.tracks.count) Tracks from the Queue?",
                            isPresented: $confirmClear) {
            Button("Remove", role: .destructive) { player.clearQueue() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The files stay on your Mac.")
        }
    }
}

private struct QueueRow: View {
    let index: Int
    let track: Track
    let isCurrent: Bool
    let isPlaying: Bool
    let isUnavailable: Bool

    var body: some View {
        HStack(spacing: Space.md) {
            Group {
                if isUnavailable {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Surface.warning)
                        .help("File not found or not playable")
                } else if isCurrent {
                    Image(systemName: isPlaying ? "speaker.wave.2.fill" : "speaker.fill").foregroundStyle(Palette.accentText)
                } else {
                    Text("\(index)").foregroundStyle(.secondary).monospacedDigit()
                }
            }
            .frame(width: 24, alignment: .center)
            VStack(alignment: .leading, spacing: 0) {
                Text(track.title).lineLimit(1)
                if !track.artist.isEmpty {
                    Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: Space.sm)
            Text(track.duration > 0 ? Track.clock(track.duration) : "")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .opacity(isUnavailable ? 0.6 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Track \(index), \(track.title), \(track.artist), \(Track.clock(track.duration))")
    }
}
