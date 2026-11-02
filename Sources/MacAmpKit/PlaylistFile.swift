import Foundation

/// One line of a playlist file: a file path or a stream URL, and an optional title.
public struct PlaylistEntry: Equatable, Sendable {
    public var location: String
    public var title: String?

    public init(location: String, title: String? = nil) {
        self.location = location
        self.title = title
    }

    /// True for http and https addresses (radio streams).
    public var isStream: Bool {
        let lower = location.lowercased()
        return lower.hasPrefix("http://") || lower.hasPrefix("https://")
    }
}

/// Reads and writes M3U, M3U8, and PLS playlists.
public enum PlaylistFile {
    /// Parses either format; PLS is recognized by its `[playlist]` header.
    /// Relative paths resolve against `baseURL` (the folder of the playlist file).
    public static func parse(_ text: String, baseURL: URL? = nil) -> [PlaylistEntry] {
        let clean = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        let lines = clean.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        let entries = lines.first(where: { !$0.isEmpty })?.lowercased() == "[playlist]" ? parsePLS(lines) : parseM3U(lines)
        return entries.map { entry in
            var entry = entry
            entry.location = resolve(entry.location, baseURL: baseURL)
            return entry
        }
    }

    private static func parseM3U(_ lines: [String]) -> [PlaylistEntry] {
        var entries: [PlaylistEntry] = []
        var pendingTitle: String?
        for line in lines where !line.isEmpty {
            if line.hasPrefix("#") {
                if line.uppercased().hasPrefix("#EXTINF:"), let comma = line.firstIndex(of: ",") {
                    let title = line[line.index(after: comma)...].trimmingCharacters(in: .whitespaces)
                    pendingTitle = title.isEmpty ? nil : title
                }
                continue
            }
            entries.append(PlaylistEntry(location: line, title: pendingTitle))
            pendingTitle = nil
        }
        return entries
    }

    private static func parsePLS(_ lines: [String]) -> [PlaylistEntry] {
        var files: [Int: String] = [:], titles: [Int: String] = [:]
        for line in lines {
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if key.hasPrefix("file"), let n = Int(key.dropFirst(4)) { files[n] = value }
            if key.hasPrefix("title"), let n = Int(key.dropFirst(5)) { titles[n] = value }
        }
        return files.keys.sorted().map { PlaylistEntry(location: files[$0]!, title: titles[$0]) }
    }

    private static func resolve(_ location: String, baseURL: URL?) -> String {
        if location.contains("://") {
            if let url = URL(string: location), url.isFileURL { return url.path }
            return location
        }
        if location.hasPrefix("/") { return location }
        guard let baseURL else { return location }
        return baseURL.appending(path: location).standardizedFileURL.path
    }

    public static func m3u(_ entries: [PlaylistEntry]) -> String {
        var out = "#EXTM3U\n"
        for entry in entries {
            out += "#EXTINF:-1,\(entry.title ?? "")\n\(entry.location)\n"
        }
        return out
    }

    public static func pls(_ entries: [PlaylistEntry]) -> String {
        var out = "[playlist]\n"
        for (i, entry) in entries.enumerated() {
            out += "File\(i + 1)=\(entry.location)\nTitle\(i + 1)=\(entry.title ?? "")\nLength\(i + 1)=-1\n"
        }
        out += "NumberOfEntries=\(entries.count)\nVersion=2\n"
        return out
    }
}
