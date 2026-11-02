import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension Player {
    /// The system open panel for audio files and folders.
    static func chooseFiles(_ handle: @escaping ([URL]) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Open Files"
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.prompt = "Open"
        if panel.runModal() == .OK { handle(panel.urls) }
    }
}
