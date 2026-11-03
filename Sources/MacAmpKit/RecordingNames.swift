import Foundation

/// File names for recorded radio.
public enum RecordingNames {
    /// A safe file name from a song title: no slashes or control characters,
    /// no leading dots, at most 120 characters.
    public static func sanitize(_ text: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)
        var clean = text.unicodeScalars.map { bad.contains($0) ? "-" : Character($0) }.map(String.init).joined()
        clean = clean.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        while clean.hasPrefix(".") { clean.removeFirst() }
        return String(clean.prefix(120)).trimmingCharacters(in: .whitespaces)
    }

    /// The file extension for a stream's content type, or nil when it is not recordable as-is.
    public static func fileExtension(forContentType type: String) -> String? {
        let lower = type.lowercased()
        if lower.contains("mpeg") || lower.contains("mp3") { return "mp3" }
        if lower.contains("aac") { return "aac" }
        return nil
    }

    /// `name.ext`, or `name 2.ext`, `name 3.ext`... when the name is taken.
    public static func unique(_ name: String, ext: String, in folder: URL, exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) -> URL {
        var candidate = folder.appending(path: "\(name).\(ext)")
        var n = 2
        while exists(candidate) {
            candidate = folder.appending(path: "\(name) \(n).\(ext)")
            n += 1
        }
        return candidate
    }
}
