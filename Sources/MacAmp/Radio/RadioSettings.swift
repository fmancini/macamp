import SwiftUI

/// Settings > Radio.
struct RadioSettings: View {
    @AppStorage("radio.buffer", store: Store.defaults) private var buffer = "normal"
    @AppStorage("recording.split", store: Store.defaults) private var split = true
    @State private var folder = Player.recordingsFolder

    var body: some View {
        Section {
            Picker("Buffer", selection: $buffer) {
                Text("Small").tag("small")
                Text("Normal").tag("normal")
                Text("Large").tag("large")
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Streaming")
        } footer: {
            Text("A larger buffer waits a few seconds longer to start but survives a weak connection better.")
        }
        Section {
            LabeledContent("Save to") {
                HStack {
                    Text(folder.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    Button("Choose\u{2026}") { chooseFolder() }
                    Button("Show") { NSWorkspace.shared.open(folder) }
                        .help("Open the recordings folder in Finder")
                }
            }
            Toggle("Start a new file for each song", isOn: $split)
        } header: {
            Text("Recording")
        } footer: {
            Text("Recordings are saved as they arrive, without re-encoding. You are responsible for using them legally.")
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Recordings Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = folder
        if panel.runModal() == .OK, let url = panel.url {
            Store.defaults.set(url.path, forKey: "recording.folder")
            folder = url
        }
    }
}
