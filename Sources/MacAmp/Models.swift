import Foundation
import Observation
import SwiftUI
import MacAmpKit

/// The Library window's sidebar pages. Snapshot mode walks through every case.
enum SidebarItem: String, CaseIterable, Identifiable {
    case library, queue, radio, favorites, history

    var id: String { rawValue }

    /// The page and window title.
    var title: String {
        switch self {
        case .library: "Library"
        case .queue: "Queue"
        case .radio: "Radio"
        case .favorites: "Favorites"
        case .history: "History"
        }
    }

    /// The label in the sidebar (Radio is "Browse" under the Radio heading).
    var sidebarTitle: String { self == .radio ? "Browse" : title }

    var symbol: String {
        switch self {
        case .library: "music.note.house"
        case .queue: "list.bullet"
        case .radio: "dot.radiowaves.left.and.right"
        case .favorites: "star"
        case .history: "clock"
        }
    }

    static let musicPages: [SidebarItem] = [.library, .queue]
    static let radioPages: [SidebarItem] = [.radio, .favorites, .history]
}

/// What the Library window's sidebar has selected.
enum SidebarSelection: Hashable {
    case page(SidebarItem)
    case playlist(UUID)
}

/// App-wide state that menus, toolbars, and views share.
@Observable
final class AppModel {
    var selection: SidebarSelection? = .page(.library)
    /// The page selected, when a page (not a playlist) is.
    var sidebar: SidebarItem? {
        get { if case .page(let page) = selection { page } else { nil } }
        set { if let newValue { selection = .page(newValue) } }
    }
    /// Settings reopens on the last tab. Test and snapshot runs leave it alone.
    var settingsTab: SettingsTab = SettingsTab(rawValue: UserDefaults.standard.string(forKey: "settings.tab") ?? "") ?? .library {
        didSet { if !Store.isOverridden { UserDefaults.standard.set(settingsTab.rawValue, forKey: "settings.tab") } }
    }
}
