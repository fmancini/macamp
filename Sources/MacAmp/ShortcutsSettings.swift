import AppKit
import MacAmpKit
import SwiftUI

/// Settings > Shortcuts: the system-wide keys.
struct ShortcutsSettings: View {
    private var shortcuts = GlobalShortcuts.shared

    var body: some View {
        Section {
            ForEach(GlobalShortcuts.Action.allCases) { action in
                LabeledContent(action.title) {
                    ShortcutRecorder(action: action)
                }
            }
            Button("Restore Defaults") { shortcuts.resetToDefaults() }
        } header: {
            Text("Global Shortcuts")
        } footer: {
            Text("These work while another app is in front. Use at least one of \u{2318}, \u{2325}, or \u{2303}.")
        }
    }
}

/// Shows a shortcut and records a new one when clicked.
struct ShortcutRecorder: View {
    let action: GlobalShortcuts.Action
    private var shortcuts = GlobalShortcuts.shared
    @State private var recording = false
    @State private var monitor: Any?
    @State private var hint: String?

    init(action: GlobalShortcuts.Action) { self.action = action }

    var body: some View {
        HStack(spacing: Space.sm) {
            if let hint { Text(hint).font(.caption).foregroundStyle(Surface.warning) }
            else if shortcuts.conflicts.contains(action.rawValue) {
                Text("In use by another app").font(.caption).foregroundStyle(Surface.warning)
            }
            Button {
                recording ? stop() : start()
            } label: {
                if recording { Text("Press keys\u{2026}") } else if let display = shortcuts.combo(for: action)?.display { Text(display) } else { Text("Record Shortcut") }
            }
            .help("Click, then press the keys you want. Escape cancels.")
            .accessibilityLabel("\(action.title) shortcut")
            .accessibilityValue(shortcuts.combo(for: action)?.display ?? "None")
            if shortcuts.combo(for: action) != nil {
                Button("Clear", systemImage: "xmark.circle.fill") { shortcuts.set(nil, for: action); hint = nil }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Remove this shortcut")
            }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        hint = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stop(); return nil }
            let combo = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: GlobalShortcuts.carbonModifiers(event.modifierFlags))
            guard combo.isValidGlobal else {
                hint = String(localized: "Add \u{2318}, \u{2325}, or \u{2303}")
                return nil
            }
            shortcuts.set(combo, for: action)
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
    }
}
