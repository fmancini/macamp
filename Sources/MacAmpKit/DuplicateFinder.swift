import Foundation

/// Finds tracks that are probably the same song.
public enum DuplicateFinder {
    public struct Item: Sendable {
        public var id: String
        public var title: String
        public var artist: String
        public var duration: Double

        public init(id: String, title: String, artist: String, duration: Double) {
            self.id = id
            self.title = title
            self.artist = artist
            self.duration = duration
        }
    }

    /// Groups of two or more tracks with the same title and artist (ignoring case,
    /// accents, and spacing) and durations within `tolerance` seconds.
    public static func groups(_ items: [Item], tolerance: Double = 2) -> [[String]] {
        var byKey: [String: [Item]] = [:]
        for item in items where !item.title.isEmpty {
            byKey[key(item), default: []].append(item)
        }
        var result: [[String]] = []
        for bucket in byKey.values where bucket.count > 1 {
            // Split by duration: sort, then start a new cluster at each gap larger than the tolerance.
            let sorted = bucket.sorted { $0.duration < $1.duration }
            var cluster: [Item] = [sorted[0]]
            for item in sorted.dropFirst() {
                if item.duration - (cluster.last?.duration ?? 0) <= tolerance {
                    cluster.append(item)
                } else {
                    if cluster.count > 1 { result.append(cluster.map(\.id).sorted()) }
                    cluster = [item]
                }
            }
            if cluster.count > 1 { result.append(cluster.map(\.id).sorted()) }
        }
        return result.sorted { $0[0] < $1[0] }
    }

    private static func key(_ item: Item) -> String {
        func normal(_ text: String) -> String {
            text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        return normal(item.title) + "\u{1}" + normal(item.artist)
    }
}
