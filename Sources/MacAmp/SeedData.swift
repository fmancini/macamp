import Foundation
import SwiftData

/// Sample tracks for snapshots: APP_SEED=1 with APP_STORE in /tmp fills an
/// empty Queue with the Mac's own system sounds (real audio files).
/// Seed only what a person can create in the app: these are ordinary files
/// added with Open Files.
@MainActor
enum SeedData {
    static func insertIfRequested(player: Player) {
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
        try? library.context.save()
    }
}
