import MacAmpKit
import SwiftUI

/// Details of the selected tracks. Read-only for now: writing tags needs a tag library.
struct TrackInspector: View {
    let tracks: [LibraryTrack]

    var body: some View {
        if tracks.isEmpty {
            ContentUnavailableView("No Selection", systemImage: "sidebar.right")
        } else {
            Form {
                Section {
                    field("Title", \.title)
                    field("Artist", \.artist)
                    field("Album", \.album)
                    field("Genre", \.genre)
                    number("Year", \.year)
                    number("Track", \.trackNumber)
                }
                Section {
                    LabeledContent("Time", value: tracks.count == 1 ? Track.clock(tracks[0].duration)
                                   : Track.clock(tracks.map(\.duration).reduce(0, +)))
                    if tracks.count == 1 {
                        LabeledContent("File", value: tracks[0].url.lastPathComponent)
                        LabeledContent("Folder", value: tracks[0].url.deletingLastPathComponent().path)
                    } else {
                        LabeledContent("Tracks", value: "\(tracks.count)")
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    private func field(_ title: String, _ key: KeyPath<LibraryTrack, String>) -> some View {
        let values = Set(tracks.map { $0[keyPath: key] })
        return LabeledContent(title, value: values.count == 1 ? (values.first ?? "") : "Multiple values")
    }

    private func number(_ title: String, _ key: KeyPath<LibraryTrack, Int>) -> some View {
        let values = Set(tracks.map { $0[keyPath: key] })
        let text = values.count == 1 ? (values.first == 0 ? "" : String(values.first ?? 0)) : "Multiple values"
        return LabeledContent(title, value: text)
    }
}
