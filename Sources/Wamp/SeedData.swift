import Foundation

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
    }
}
