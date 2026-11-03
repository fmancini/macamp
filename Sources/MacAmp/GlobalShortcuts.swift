import AppKit
import Carbon.HIToolbox
import MacAmpKit
import Observation

/// System-wide shortcuts for Play/Pause, Next, and Previous. They work while
/// another app is in front, and need no Accessibility permission (Carbon hot keys).
@Observable
final class GlobalShortcuts {
    static let shared = GlobalShortcuts()

    enum Action: UInt32, CaseIterable, Identifiable {
        case playPause = 1, next, previous

        var id: UInt32 { rawValue }

        var title: String {
            switch self {
            case .playPause: String(localized: "Play / Pause")
            case .next: String(localized: "Next Track")
            case .previous: String(localized: "Previous Track")
            }
        }

        var defaultCombo: KeyCombo {
            let modifiers = KeyCombo.control | KeyCombo.option
            switch self {
            case .playPause: return KeyCombo(keyCode: 49, modifiers: modifiers)
            case .next: return KeyCombo(keyCode: 124, modifiers: modifiers)
            case .previous: return KeyCombo(keyCode: 123, modifiers: modifiers)
            }
        }
    }

    private(set) var combos: [UInt32: KeyCombo] = [:]
    /// Actions whose shortcut another app already owns.
    private(set) var conflicts: Set<UInt32> = []
    private var references: [UInt32: EventHotKeyRef] = [:]
    private var handlerInstalled = false

    private init() {
        if let data = Store.defaults.data(forKey: "shortcuts.combos"),
           let saved = try? JSONDecoder().decode([UInt32: KeyCombo].self, from: data) {
            combos = saved
        } else {
            combos = Dictionary(uniqueKeysWithValues: Action.allCases.map { ($0.rawValue, $0.defaultCombo) })
        }
    }

    func combo(for action: Action) -> KeyCombo? { combos[action.rawValue] }

    func set(_ combo: KeyCombo?, for action: Action) {
        combos[action.rawValue] = combo
        save()
        register(action)
    }

    func resetToDefaults() {
        combos = Dictionary(uniqueKeysWithValues: Action.allCases.map { ($0.rawValue, $0.defaultCombo) })
        save()
        registerAll()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(combos) { Store.defaults.set(data, forKey: "shortcuts.combos") }
    }

    /// Registers every shortcut. Test and snapshot runs never grab keys.
    func registerAll(force: Bool = false) {
        guard force || !Store.isOverridden else { return }
        installHandler()
        for action in Action.allCases { register(action, force: force) }
    }

    func unregisterAll() {
        for reference in references.values { UnregisterEventHotKey(reference) }
        references = [:]
    }

    private func register(_ action: Action, force: Bool = false) {
        guard force || !Store.isOverridden else { return }
        if let old = references.removeValue(forKey: action.rawValue) { UnregisterEventHotKey(old) }
        conflicts.remove(action.rawValue)
        guard let combo = combos[action.rawValue], combo.isValidGlobal else { return }
        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: OSType(0x4D41_4D50), id: action.rawValue)
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, identifier, GetApplicationEventTarget(), 0, &reference)
        if status == noErr, let reference { references[action.rawValue] = reference } else { conflicts.insert(action.rawValue) }
    }

    private func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var identifier = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            let id = identifier.id
            DispatchQueue.main.async { GlobalShortcuts.fire(id) }
            return noErr
        }, 1, &spec, nil, nil)
    }

    static func fire(_ id: UInt32) {
        let player = Player.shared
        switch Action(rawValue: id) {
        case .playPause: player.togglePlay()
        case .next: player.next()
        case .previous: player.previous()
        case nil: break
        }
    }

    /// Carbon modifier flags for an AppKit event.
    static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= KeyCombo.command }
        if flags.contains(.shift) { result |= KeyCombo.shift }
        if flags.contains(.option) { result |= KeyCombo.option }
        if flags.contains(.control) { result |= KeyCombo.control }
        return result
    }
}
