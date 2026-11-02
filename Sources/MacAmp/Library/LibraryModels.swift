import Foundation
import MacAmpKit
import SwiftData

/// One audio file in the Library. The file path identifies it.
@Model
final class LibraryTrack {
    @Attribute(.unique) var path: String
    var title: String
    var artist: String = ""
    var album: String = ""
    var genre: String = ""
    var year: Int = 0
    var trackNumber: Int = 0
    var duration: Double = 0
    var addedAt: Date = Date.now
    /// False when the file is gone from disk (shown dimmed, never dropped silently).
    var isAvailable: Bool = true
    var folderPath: String = ""

    init(path: String, title: String, folderPath: String) {
        self.path = path
        self.title = title
        self.folderPath = folderPath
    }

    /// A queue entry for this track.
    var queueTrack: Track { Track(url: URL(fileURLWithPath: path), title: title, artist: artist, duration: duration) }
    var url: URL { URL(fileURLWithPath: path) }
}

/// A music folder the user added to the Library.
@Model
final class LibraryFolder {
    @Attribute(.unique) var path: String
    var addedAt: Date = Date.now

    init(path: String) { self.path = path }
}

/// A saved, named list of tracks. Items are file paths or stream addresses.
@Model
final class Playlist {
    var uuid: UUID = UUID()
    var name: String
    var items: [String] = []
    var createdAt: Date = Date.now

    init(name: String, items: [String] = []) {
        self.name = name
        self.items = items
    }
}
