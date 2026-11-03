import Foundation
import Observation

/// Whether the player is shrunk to a thin bar (windowshade mode). Saved.
@Observable
final class PlayerWindowState {
    static let shared = PlayerWindowState()

    var shade: Bool {
        didSet { Store.defaults.set(shade, forKey: "player.shade") }
    }

    private init() {
        shade = ProcessInfo.processInfo.environment["APP_SHADE"] == "1" || Store.defaults.bool(forKey: "player.shade")
    }
}
