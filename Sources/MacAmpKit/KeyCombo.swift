import Foundation

/// A keyboard shortcut: a key code and modifier flags (Carbon values:
/// command 256, shift 512, option 2048, control 4096).
public struct KeyCombo: Codable, Equatable, Hashable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32

    public static let command: UInt32 = 256
    public static let shift: UInt32 = 512
    public static let option: UInt32 = 2_048
    public static let control: UInt32 = 4_096

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// A global shortcut needs a modifier, or it would steal a plain key everywhere.
    public var isValidGlobal: Bool { modifiers & (Self.command | Self.option | Self.control) != 0 }

    /// "⌃⌥Space", the way menus write it.
    public var display: String {
        var text = ""
        if modifiers & Self.control != 0 { text += "\u{2303}" }
        if modifiers & Self.option != 0 { text += "\u{2325}" }
        if modifiers & Self.shift != 0 { text += "\u{21E7}" }
        if modifiers & Self.command != 0 { text += "\u{2318}" }
        return text + (Self.keyNames[keyCode] ?? "Key \(keyCode)")
    }

    private static let keyNames: [UInt32: String] = [
        49: "Space", 123: "\u{2190}", 124: "\u{2192}", 125: "\u{2193}", 126: "\u{2191}", 36: "Return", 48: "Tab", 51: "Delete",
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E",
        15: "R", 16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
    ]
}
