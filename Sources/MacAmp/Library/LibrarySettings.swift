import SwiftData
import SwiftUI

/// Settings > Library: the folders MacAmp reads.
struct LibrarySettings: View {
    @Query(sort: \LibraryFolder.addedAt) private var folders: [LibraryFolder]
    @Query private var tracks: [LibraryTrack]

    var body: some View {
        Section {
            if folders.isEmpty {
                Text("No folders yet. Add one to fill the Library.").foregroundStyle(.secondary)
            }
            ForEach(folders) { folder in
                LabeledContent {
                    Button("Remove") { LibraryModel.shared.removeFolder(folder) }
                        .help("Stop reading this folder. The files stay on your Mac.")
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(URL(fileURLWithPath: folder.path).lastPathComponent)
                        Text(folder.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                }
            }
            Button("Add Folder\u{2026}") {
                LibraryPanels.chooseFolder { url in Task { await LibraryModel.shared.addFolder(url) } }
            }
        } header: {
            Text("Music Folders")
        } footer: {
            Text("\(tracks.count) tracks. MacAmp watches these folders and picks up new files on its own.")
        }
    }
}
