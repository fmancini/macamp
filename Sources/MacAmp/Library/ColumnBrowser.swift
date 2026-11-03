import SwiftUI

/// Genre, Artist, and Album columns that narrow the track table.
struct ColumnBrowser: View {
    @Binding var genre: String
    @Binding var artist: String
    @Binding var album: String
    let genres: [(value: String, count: Int)]
    let artists: [(value: String, count: Int)]
    let albums: [(value: String, count: Int)]

    var body: some View {
        HStack(spacing: 0) {
            column(String(localized: "Genres"), selection: $genre, entries: genres)
            Divider()
            column(String(localized: "Artists"), selection: $artist, entries: artists)
            Divider()
            column(String(localized: "Albums"), selection: $album, entries: albums)
        }
        .frame(height: 120) // grid: ok
    }

    private func column(_ title: String, selection: Binding<String>, entries: [(value: String, count: Int)]) -> some View {
        List(selection: selection) {
            Text("All (\(entries.count) \(title))").foregroundStyle(.secondary).tag("")
            ForEach(entries, id: \.value) { entry in
                Text(entry.value).lineLimit(1).tag(entry.value)
            }
        }
        .listStyle(.plain)
        .accessibilityLabel(title)
    }
}
