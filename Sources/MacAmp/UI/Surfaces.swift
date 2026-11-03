import Observation
import SwiftUI

/// The player look. Only the player windows (main, equalizer, queue, mini)
/// use it; the Library window and Settings stay native.
/// Why custom: the compact LCD-style display is the product's identity.
enum PlayerTheme: String, CaseIterable, Identifiable {
    case classic
    case mac

    var id: String { rawValue }
    var name: String { self == .classic ? String(localized: "Classic") : String(localized: "Mac") }
}

/// The chosen player theme, saved in UserDefaults.
@Observable
final class PlayerThemeStore {
    static let shared = PlayerThemeStore()

    var theme: PlayerTheme {
        didSet { Store.defaults.set(theme.rawValue, forKey: "appearance.player") }
    }

    private init() {
        let raw = ProcessInfo.processInfo.environment["APP_PLAYER_THEME"]
            ?? Store.defaults.string(forKey: "appearance.player")
        theme = raw.flatMap(PlayerTheme.init(rawValue:)) ?? .classic
    }
}

/// Surface and readout tokens for the player windows. Never hard-code these in views.
enum Surface {
    private static var theme: PlayerTheme { PlayerThemeStore.shared.theme }

    /// The window body behind the controls.
    static var playerBody: Color {
        theme == .classic ? Color(light: 0xD8DAD9, dark: 0x2A2D2B, highContrastLight: 0xFFFFFF, highContrastDark: 0x000000)
                          : Color(nsColor: .windowBackgroundColor)
    }
    /// The inset display that holds the title, time, and spectrum.
    static var display: Color {
        theme == .classic ? Color(light: 0x0E1410, dark: 0x070A08)
                          : Color(light: 0xEDEDF0, dark: 0x1C1C20, highContrastLight: 0xFFFFFF, highContrastDark: 0x000000)
    }
    /// Main text and bars in the display.
    static var readout: Color {
        theme == .classic ? Color(light: 0x58F58A, dark: 0x58F58A) : Palette.accentText
    }
    /// Secondary text and unlit bars in the display.
    static var readoutDim: Color {
        theme == .classic ? Color(light: 0x2A8A47, dark: 0x2A8A47, highContrastLight: 0x58F58A, highContrastDark: 0x58F58A)
                          : Color.secondary
    }
    /// A thin line between regions.
    static let hairline = Color.primary.opacity(0.12)
    /// A hovered control in the player.
    static let surfaceHover = Color.primary.opacity(0.08)
    /// The one warning color (Unavailable tracks, connection errors).
    static let warning = Color(light: 0xB45309, dark: 0xFBBF24)
}
