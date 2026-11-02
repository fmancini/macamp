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

/// A radio station the user saved.
@Model
final class FavoriteStation {
    @Attribute(.unique) var stationID: String
    var name: String
    var url: String
    var codec: String = ""
    var bitrate: Int = 0
    var country: String = ""
    var tags: String = ""
    var favicon: String = ""
    var isHLS: Bool = false
    var addedAt: Date = Date.now

    init(_ station: Station) {
        stationID = station.id
        name = station.name
        url = station.url
        codec = station.codec
        bitrate = station.bitrate
        country = station.country
        tags = station.tags
        favicon = station.favicon
        isHLS = station.isHLS
    }

    var station: Station {
        Station(id: stationID, name: name, url: url, codec: codec, bitrate: bitrate, country: country,
                tags: tags, favicon: favicon, isHLS: isHLS)
    }
}

/// A song title heard on a station.
@Model
final class PlayedTitle {
    var stationName: String
    var title: String
    var playedAt: Date = Date.now

    init(stationName: String, title: String) {
        self.stationName = stationName
        self.title = title
    }
}
