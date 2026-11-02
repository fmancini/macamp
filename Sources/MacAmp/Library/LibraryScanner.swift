import AVFoundation
import Foundation
import UniformTypeIdentifiers

/// What the scanner reads from one file.
struct ScannedFile: Sendable {
    var path: String
    var title: String
    var artist = ""
    var album = ""
    var genre = ""
    var year = 0
    var trackNumber = 0
    var duration = 0.0
}

/// Finds audio files and reads their tags, off the main thread.
nonisolated enum LibraryScanner {
    static func isAudio(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension.lowercased())?.conforms(to: .audio) ?? false
    }

    /// Every audio file under a folder, sorted by path.
    @concurrent
    static func audioFiles(in folder: URL) async -> [URL] {
        let found = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil,
                                                   options: [.skipsHiddenFiles, .skipsPackageDescendants])?
            .compactMap { $0 as? URL }.filter(isAudio) ?? []
        return found.sorted { $0.path < $1.path }
    }

    /// Reads tags for many files, eight at a time.
    @concurrent
    static func read(_ urls: [URL], progress: @Sendable @escaping (Int) -> Void) async -> [ScannedFile] {
        await withTaskGroup(of: ScannedFile.self) { group in
            var results: [ScannedFile] = []
            var iterator = urls.makeIterator()
            var running = 0
            func addNext() {
                guard let url = iterator.next() else { return }
                group.addTask { await readTags(url) }
                running += 1
            }
            for _ in 0..<8 { addNext() }
            while running > 0, let file = await group.next() {
                running -= 1
                results.append(file)
                progress(results.count)
                addNext()
            }
            return results
        }
    }

    static func readTags(_ url: URL) async -> ScannedFile {
        var file = ScannedFile(path: url.path, title: url.deletingPathExtension().lastPathComponent)
        let asset = AVURLAsset(url: url)
        if let seconds = (try? await asset.load(.duration))?.seconds, seconds.isFinite { file.duration = seconds }
        let items = (try? await asset.load(.metadata)) ?? []
        func text(_ ids: [AVMetadataIdentifier]) async -> String? {
            for id in ids {
                if let value = try? await AVMetadataItem.metadataItems(from: items, filteredByIdentifier: id)
                    .first?.load(.stringValue), !value.isEmpty { return value }
            }
            return nil
        }
        if let title = await text([.commonIdentifierTitle]) { file.title = title }
        file.artist = await text([.commonIdentifierArtist]) ?? ""
        file.album = await text([.commonIdentifierAlbumName]) ?? ""
        file.genre = await text([.commonIdentifierType, .id3MetadataContentType, .iTunesMetadataUserGenre]) ?? ""
        if let date = await text([.commonIdentifierCreationDate, .id3MetadataYear, .id3MetadataRecordingTime]),
           let year = Int(date.prefix(4)) { file.year = year }
        if let number = await text([.id3MetadataTrackNumber]), let n = Int(number.split(separator: "/").first ?? "") {
            file.trackNumber = n
        }
        return file
    }
}
