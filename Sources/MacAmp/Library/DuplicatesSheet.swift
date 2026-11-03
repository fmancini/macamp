import AppKit
import MacAmpKit
import SwiftData
import SwiftUI

/// Find Duplicates: tracks with the same title, artist, and length.
struct DuplicatesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \LibraryTrack.path) private var tracks: [LibraryTrack]
    @State private var groups: [[LibraryTrack]] = []
    @State private var marked: Set<String> = []
    @State private var searched = false
    @State private var confirming = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if !searched {
                    ProgressView("Looking for duplicates\u{2026}")
                } else if groups.isEmpty {
                    ContentUnavailableView("No Duplicates", systemImage: "checkmark.circle",
                                           description: Text("No two tracks share a title, artist, and length."))
                } else {
                    List {
                        ForEach(groups.indices, id: \.self) { index in
                            Section("\(groups[index][0].title) \u{2013} \(groups[index][0].artist.isEmpty ? "Unknown Artist" : groups[index][0].artist)") {
                                ForEach(groups[index], id: \.path) { track in
                                    Toggle(isOn: Binding(get: { marked.contains(track.path) },
                                                         set: { if $0 { marked.insert(track.path) } else { marked.remove(track.path) } })) {
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text(track.url.lastPathComponent).lineLimit(1)
                                            Text(track.url.deletingLastPathComponent().path)
                                                .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                                        }
                                    }
                                    .toggleStyle(.checkbox)
                                    .accessibilityLabel("Remove \(track.url.lastPathComponent)")
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack {
                Text(marked.isEmpty ? "Tick the copies you want to remove. The first of each group is kept." : "\(marked.count) tracks marked")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Remove\u{2026}") { confirming = true }
                    .disabled(marked.isEmpty)
            }
            .padding(Space.lg)
        }
        .frame(width: 560, height: 440) // grid: ok
        .navigationTitle("Find Duplicates")
        .task { await find() }
        .confirmationDialog("Remove \(marked.count) Tracks?", isPresented: $confirming) {
            Button("Remove from Library") { remove(trashFiles: false) }
            Button("Move Files to Trash", role: .destructive) { remove(trashFiles: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove from Library keeps the files on your Mac. Move Files to Trash can be undone from the Trash.")
        }
    }

    private func find() async {
        let items = tracks.map { DuplicateFinder.Item(id: $0.path, title: $0.title, artist: $0.artist, duration: $0.duration) }
        let found = DuplicateFinder.groups(items)
        let byPath = Dictionary(tracks.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        groups = found.map { $0.compactMap { byPath[$0] } }
        // Keep the first copy of each group; the others start ticked.
        marked = Set(groups.flatMap { $0.dropFirst().map(\.path) })
        searched = true
    }

    private func remove(trashFiles: Bool) {
        let context = LibraryModel.shared.context
        let doomed = tracks.filter { marked.contains($0.path) }
        if trashFiles { NSWorkspace.shared.recycle(doomed.map(\.url)) }
        for track in doomed { context.delete(track) }
        try? context.save()
        marked = []
        Task { await find() }
    }
}
