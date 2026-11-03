import AppKit
import Observation

/// Light, dark, or follow the Mac. System is the default; the owner asked for
/// a choice in Settings > Appearance.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var name: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    /// nil follows the Mac.
    var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

/// The chosen mode, saved in UserDefaults. Setting it changes every window at once.
@Observable
final class AppearanceStore {
    static let shared = AppearanceStore()

    var mode: AppearanceMode {
        didSet {
            Store.defaults.set(mode.rawValue, forKey: "appearance.mode")
            apply()
        }
    }

    private init() {
        mode = Store.defaults.string(forKey: "appearance.mode").flatMap(AppearanceMode.init(rawValue:)) ?? .system
    }

    /// Snapshot runs set the appearance themselves, so they skip this.
    func apply() {
        guard ProcessInfo.processInfo.environment["APP_SNAPSHOT"] == nil else { return }
        NSApp.appearance = mode.appearance
    }
}
