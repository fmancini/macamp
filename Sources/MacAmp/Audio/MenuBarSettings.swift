import Foundation
import Observation
import SwiftUI

/// Whether MacAmp shows an item in the menu bar. Saved.
/// The scene's binding only writes when the value really changes: writing the
/// same value back makes SwiftUI re-evaluate the app in a loop.
@Observable
final class MenuBarSettings {
    static let shared = MenuBarSettings()

    var visible: Bool {
        didSet { if visible != oldValue { Store.defaults.set(visible, forKey: "menubar.show") } }
    }

    private init() {
        // Test and snapshot runs keep the menu bar item out of the way.
        visible = Store.isOverridden ? false : (Store.defaults.object(forKey: "menubar.show") as? Bool ?? true)
    }

    var binding: Binding<Bool> {
        Binding(get: { self.visible }, set: { if $0 != self.visible { self.visible = $0 } })
    }
}
