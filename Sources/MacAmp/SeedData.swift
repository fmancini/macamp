import Foundation
import SwiftData
import MacAmpKit

/// Sample tracks for snapshots: APP_SEED=1 with APP_STORE in /tmp fills an
/// empty Queue with the Mac's own system sounds (real audio files).
/// Seed only what a person can create in the app: these are ordinary files
/// added with Open Files.
@MainActor
enum SeedData {
    static func insertIfRequested(player: Player) {
        seedManyTracksIfRequested()
        if let path = ProcessInfo.processInfo.environment["APP_PLAYFILE"], Store.isOverridden {
            player.open([URL(fileURLWithPath: path)])
        }
        if let address = ProcessInfo.processInfo.environment["APP_RADIO"], Store.isOverridden, let url = URL(string: address) {
            player.playStation(Station(name: "Test station", url: url.absoluteString, codec: "AAC"))
        }
        guard ProcessInfo.processInfo.environment["APP_SEED"] == "1" else { return }
        guard Store.isOverridden else {
            print("APP_SEED ignored: APP_STORE must be a file in /tmp")
            return
        }
        guard player.queue.isEmpty else { return }
        let sounds = URL(fileURLWithPath: "/System/Library/Sounds")
        let names = ["Glass", "Hero", "Submarine", "Funk", "Blow", "Ping", "Sosumi", "Tink"]
        player.open(names.map { sounds.appending(path: "\($0).aiff") }, play: false)
        seedLibrary(from: sounds)
        if ProcessInfo.processInfo.environment["APP_SPECTRUM_DEBUG"] == "1" {
            player.cycleRepeat()   // repeat all, so the sounds keep playing
            if let first = player.queue.currentID { player.playTrack(first) }
        }
    }

    /// APP_SEED_COUNT=20000 fills the Library with that many made-up tracks, to measure
    /// memory and speed with a big Library. Test runs only.
    private static func seedManyTracksIfRequested() {
        guard let text = ProcessInfo.processInfo.environment["APP_SEED_COUNT"], let count = Int(text), count > 0, Store.isOverridden else { return }
        let library = LibraryModel.shared
        guard library.trackCount == 0 else { return }
        library.context.insert(LibraryFolder(path: "/tmp/macamp-fake"))
        let genres = ["Rock", "Jazz", "Electronic", "Classical", "Pop", "Folk", "Hip Hop", "Ambient"]
        for i in 0..<count {
            let track = LibraryTrack(path: "/tmp/macamp-fake/Artist \(i % 700)/Album \(i % 2_500)/Track \(i).mp3",
                                     title: "Track number \(i) with a reasonably long title", folderPath: "/tmp/macamp-fake")
            track.artist = "Artist \(i % 700)"
            track.album = "Album \(i % 2_500)"
            track.genre = genres[i % genres.count]
            track.year = 1970 + i % 55
            track.trackNumber = i % 14 + 1
            track.duration = 120 + Double(i % 300)
            library.context.insert(track)
        }
        try? library.context.save()
    }

    /// Library rows for the system sounds, with made-up tags so the browser,
    /// table, and inspector have something to show. Snapshot runs only.
    private static func seedLibrary(from sounds: URL) {
        let library = LibraryModel.shared
        guard library.trackCount == 0 else { return }
        library.context.insert(LibraryFolder(path: sounds.path))
        let tags: [(String, String, String, String, Int)] = [
            ("Glass", "Apple Sounds", "Alert Tones", "Effects", 2011), ("Hero", "Apple Sounds", "Alert Tones", "Effects", 2011),
            ("Submarine", "Apple Sounds", "Alert Tones", "Effects", 2011), ("Funk", "Studio Loops", "Rhythm Box", "Ambient", 2014),
            ("Blow", "Studio Loops", "Rhythm Box", "Ambient", 2014), ("Ping", "Studio Loops", "Rhythm Box", "Ambient", 2014),
            ("Sosumi", "Field Recordings", "City Notes", "Ambient", 2019), ("Tink", "Field Recordings", "City Notes", "Ambient", 2019),
            ("Basso", "Field Recordings", "City Notes", "Effects", 2019), ("Bottle", "Apple Sounds", "Alert Tones", "Effects", 2011),
            ("Frog", "Field Recordings", "Pond Life", "Ambient", 2021), ("Morse", "Field Recordings", "Pond Life", "Effects", 2021),
            ("Pop", "Studio Loops", "Rhythm Box", "Ambient", 2014), ("Purr", "Apple Sounds", "Alert Tones", "Effects", 2011),
        ]
        for (index, tag) in tags.enumerated() {
            let path = sounds.appending(path: "\(tag.0).aiff").path
            let track = LibraryTrack(path: path, title: tag.0, folderPath: sounds.path)
            track.artist = tag.1
            track.album = tag.2
            track.genre = tag.3
            track.year = tag.4
            track.trackNumber = index % 5 + 1
            track.duration = 1 + Double(index % 4) * 0.5
            library.context.insert(track)
        }
        let picks = ["Glass", "Funk", "Frog", "Hero"].map { sounds.appending(path: "\($0).aiff").path }
        library.createPlaylist(name: "Sound Effects", items: picks)
        for station in [Station(name: "101 SMOOTH JAZZ", url: "http://jking.cdnstream1.com/b22139_128mp3", codec: "MP3", bitrate: 192, country: "USA"),
                        Station(name: "Europe 1", url: "https://stream.europe1.fr/europe1.aac", codec: "AAC", bitrate: 128, country: "France"),
                        Station(name: "Radio Paradise", url: "http://stream.radioparadise.com/mp3-192", codec: "MP3", bitrate: 192, country: "USA")] {
            library.context.insert(FavoriteStation(station))
        }
        let now = Date.now
        for (i, entry) in [("Radio Paradise", "Khruangbin - Maria También"), ("101 SMOOTH JAZZ", "Norah Jones - Don't Know Why"),
                           ("Europe 1", "Stromae - Papaoutai"), ("Radio Paradise", "Bonobo - Kerala")].enumerated() {
            let title = PlayedTitle(stationName: entry.0, title: entry.1)
            title.playedAt = now.addingTimeInterval(Double(-i) * 780)
            library.context.insert(title)
        }
        try? library.context.save()
    }
}
