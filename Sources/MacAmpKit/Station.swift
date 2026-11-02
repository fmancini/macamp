import Foundation

/// An internet radio station.
public struct Station: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    /// The address of the stream itself (already resolved from any playlist).
    public var url: String
    public var codec: String
    public var bitrate: Int
    public var country: String
    public var tags: String
    public var favicon: String
    /// True for HLS streams (.m3u8), which the player hands to AVPlayer.
    public var isHLS: Bool

    public init(id: String = UUID().uuidString, name: String, url: String, codec: String = "", bitrate: Int = 0,
                country: String = "", tags: String = "", favicon: String = "", isHLS: Bool = false) {
        self.id = id
        self.name = name
        self.url = url
        self.codec = codec
        self.bitrate = bitrate
        self.country = country
        self.tags = tags
        self.favicon = favicon
        self.isHLS = isHLS || url.lowercased().contains(".m3u8")
    }
}

/// The JSON a Radio Browser search returns, for the fields we use.
public struct RadioBrowserStation: Decodable, Sendable {
    public var stationuuid: String
    public var name: String
    public var url_resolved: String
    public var url: String
    public var codec: String
    public var bitrate: Int
    public var country: String
    public var tags: String
    public var favicon: String
    public var hls: Int

    public var station: Station {
        Station(id: stationuuid, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                url: url_resolved.isEmpty ? url : url_resolved, codec: codec, bitrate: bitrate,
                country: country, tags: tags, favicon: favicon, isHLS: hls == 1)
    }
}

public enum RadioBrowserSearch: String, CaseIterable, Identifiable, Sendable {
    case name, country, language, tag

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}
