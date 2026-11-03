import AppKit
import AVFoundation
import MacAmpKit

/// Album art for a file: the picture inside the tags, or cover.jpg / folder.jpg
/// (and similar) next to it.
nonisolated enum ArtworkLoader {
    nonisolated(unsafe) private static let cache = NSCache<NSString, NSImage>()
    private static let folderNames = ["cover", "folder", "front", "albumart", "album"]
    private static let folderExtensions = ["jpg", "jpeg", "png"]

    @concurrent
    static func image(forPath path: String) async -> NSImage? {
        if let cached = cache.object(forKey: path as NSString) { return cached }
        let url = URL(fileURLWithPath: path)
        if let embedded = await embeddedImage(url) { cache.setObject(embedded, forKey: path as NSString); return embedded }
        if let folderImage = folderImage(near: url) { cache.setObject(folderImage, forKey: path as NSString); return folderImage }
        return nil
    }

    private static func embeddedImage(_ url: URL) async -> NSImage? {
        let asset = AVURLAsset(url: url)
        guard let items = try? await asset.load(.commonMetadata) else { return nil }
        let art = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: .commonIdentifierArtwork)
        for item in art {
            if let data = try? await item.load(.dataValue), let image = NSImage(data: data) { return image }
        }
        return nil
    }

    static func folderImage(near url: URL) -> NSImage? {
        let folder = url.deletingLastPathComponent()
        for name in folderNames {
            for ext in folderExtensions {
                let candidate = folder.appending(path: "\(name).\(ext)")
                if FileManager.default.fileExists(atPath: candidate.path), let image = NSImage(contentsOf: candidate) { return image }
            }
        }
        return nil
    }
}

/// ReplayGain tags read through AVFoundation (ID3 TXXX and iTunes freeform atoms).
/// FLAC and Ogg comments are not exposed by AVFoundation; a tag library would cover them.
nonisolated enum ReplayGainReader {
    struct Tags: Sendable {
        var trackGain: Double?
        var albumGain: Double?
        var trackPeak: Double?
        var albumPeak: Double?
    }

    @concurrent
    static func read(_ url: URL) async -> Tags {
        let asset = AVURLAsset(url: url)
        let items = (try? await asset.load(.metadata)) ?? []
        var tags = Tags()
        for item in items {
            var names: [String] = []
            if let key = item.key { names.append("\(key)") }
            if let id = item.identifier?.rawValue { names.append(id) }
            if let info = item.extraAttributes?[AVMetadataExtraAttributeKey.info] { names.append("\(info)") }
            let name = names.joined(separator: " ").lowercased()
            guard name.contains("replaygain"), let value = try? await item.load(.stringValue) else { continue }
            if name.contains("track_gain") { tags.trackGain = ReplayGain.parseGain(value) }
            if name.contains("album_gain") { tags.albumGain = ReplayGain.parseGain(value) }
            if name.contains("track_peak") { tags.trackPeak = ReplayGain.parsePeak(value) }
            if name.contains("album_peak") { tags.albumPeak = ReplayGain.parsePeak(value) }
        }
        return tags
    }
}
