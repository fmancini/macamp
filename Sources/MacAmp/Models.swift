import Foundation
import Observation
import SwiftUI
import MacAmpKit

/// The Library window's sidebar pages. Snapshot mode walks through every case.
enum SidebarItem: String, CaseIterable, Identifiable {
    case library, queue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .library: "Library"
        case .queue: "Queue"
        }
    }

    var symbol: String {
        switch self {
        case .library: "music.note.house"
        case .queue: "list.bullet"
        }
    }
}

/// App-wide state that menus, toolbars, and views share.
@Observable
final class AppModel {
    var sidebar: SidebarItem? = .library
    /// Settings reopens on the last tab. Test and snapshot runs leave it alone.
    var settingsTab: SettingsTab = SettingsTab(rawValue: UserDefaults.standard.string(forKey: "settings.tab") ?? "") ?? .general {
        didSet { if !Store.isOverridden { UserDefaults.standard.set(settingsTab.rawValue, forKey: "settings.tab") } }
    }
}
