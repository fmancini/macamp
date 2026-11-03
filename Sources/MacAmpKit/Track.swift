import Foundation

/// One audio file in the Queue.
public struct Track: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var path: String
    public var title: String
    public var artist: String
    /// Seconds. 0 while unknown.
    public var duration: Double

    public var url: URL { URL(fileURLWithPath: path) }

    public init(url: URL, title: String? = nil, artist: String = "", duration: Double = 0) {
        id = UUID()
        path = url.path
        self.title = title ?? url.deletingPathExtension().lastPathComponent
        self.artist = artist
        self.duration = duration
    }

    /// "3:45", or "1:02:03" past an hour. A negative or unknown time shows "0:00".
    public static func clock(_ seconds: Double) -> String {
        let total = Int(max(0, seconds.isFinite ? seconds : 0))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

public enum RepeatMode: String, Codable, Sendable, CaseIterable {
    case off, all, one

    public var label: String {
        switch self {
        case .off: String(localized: "Off")
        case .all: String(localized: "All")
        case .one: String(localized: "One")
        }
    }

    public var next: RepeatMode {
        switch self {
        case .off: .all
        case .all: .one
        case .one: .off
        }
    }
}
