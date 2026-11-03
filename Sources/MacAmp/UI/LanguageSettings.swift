import AppKit
import SwiftUI

/// The interface language: follow the Mac, or force English or Spanish.
/// macOS reads the choice at launch, so changing it needs a restart.
enum LanguageChoice: String, CaseIterable, Identifiable {
    case system, english = "en", spanish = "es"

    var id: String { rawValue }

    /// What the app was launched with.
    static var current: LanguageChoice {
        let saved = UserDefaults.standard.array(forKey: "AppleLanguages")?.first as? String
        return LanguageChoice.allCases.first { $0 != .system && saved?.hasPrefix($0.rawValue) == true } ?? .system
    }

    /// Saved for the next launch. Test and snapshot runs never write it.
    func save() {
        guard !Store.isOverridden else { return }
        if self == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
        }
    }

    /// Opens a fresh copy of the app and quits this one.
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}

/// Settings > Appearance: the language picker.
struct LanguageSection: View {
    @State private var choice = LanguageChoice.current
    @State private var changed = false

    var body: some View {
        Section {
            Picker("Language", selection: $choice) {
                Text("System").tag(LanguageChoice.system)
                Text(verbatim: "English").tag(LanguageChoice.english)
                Text(verbatim: "Espa\u{00F1}ol").tag(LanguageChoice.spanish)
            }
            .onChange(of: choice) {
                choice.save()
                changed = true
            }
            if changed {
                Button("Restart Now") { LanguageChoice.relaunch() }
            }
        } footer: {
            Text("The language changes the next time MacAmp opens.")
        }
    }
}
