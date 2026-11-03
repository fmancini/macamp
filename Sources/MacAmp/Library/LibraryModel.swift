import Foundation
import Observation
import SwiftData

/// The Library: folders, tracks, and keeping them in step with the disk.
@Observable
final class LibraryModel {
    static let shared = LibraryModel()

    let container: ModelContainer
    private(set) var isScanning = false
    private(set) var scanned = 0
    private(set) var total = 0
    private var watcher: LibraryWatcher?
    private var pendingFolders: Set<String> = []

    var context: ModelContext { container.mainContext }

    private init() {
        container = Store.makeContainer()
        startWatching()
    }

    var folders: [LibraryFolder] {
        (try? context.fetch(FetchDescriptor<LibraryFolder>(sortBy: [SortDescriptor(\.addedAt)]))) ?? []
    }

    var trackCount: Int { (try? context.fetchCount(FetchDescriptor<LibraryTrack>())) ?? 0 }

    // MARK: Folders

    func addFolder(_ url: URL) async {
        let path = url.standardizedFileURL.path
        if !folders.contains(where: { $0.path == path }) {
            context.insert(LibraryFolder(path: path))
            try? context.save()
            startWatching()
        }
        await sync(path)
    }

    func removeFolder(_ folder: LibraryFolder) {
        let path = folder.path
        if let tracks = try? context.fetch(FetchDescriptor<LibraryTrack>(predicate: #Predicate { $0.folderPath == path })) {
            for track in tracks { context.delete(track) }
        }
        context.delete(folder)
        try? context.save()
        startWatching()
    }

    /// Removes the Library entries whose files are gone from disk (files that
    /// came back are revived first). Returns how many entries were removed.
    @discardableResult
    func removeMissing(inFolder folder: String? = nil) -> Int {
        let all = (try? context.fetch(FetchDescriptor<LibraryTrack>())) ?? []
        var removed = 0
        for track in all where folder == nil || track.folderPath == folder {
            if FileManager.default.fileExists(atPath: track.path) {
                if !track.isAvailable { track.isAvailable = true }
            } else {
                context.delete(track)
                removed += 1
            }
        }
        try? context.save()
        return removed
    }

    /// Removes entries from the Library. The files stay on disk.
    func remove(_ tracks: [LibraryTrack]) {
        for track in tracks { context.delete(track) }
        try? context.save()
    }

    func syncAll() async {
        for folder in folders { await sync(folder.path) }
    }

    // MARK: Syncing with the disk

    /// Adds new files, marks vanished files unavailable, and revives returned ones.
    func sync(_ folderPath: String) async {
        guard !isScanning else { pendingFolders.insert(folderPath); return }
        isScanning = true
        scanned = 0
        total = 0
        defer { isScanning = false }

        let files = await LibraryScanner.audioFiles(in: URL(fileURLWithPath: folderPath))
        let filePaths = Set(files.map(\.path))
        let existing = (try? context.fetch(FetchDescriptor<LibraryTrack>(predicate: #Predicate { $0.folderPath == folderPath }))) ?? []
        let known = Dictionary(existing.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })

        for track in existing {
            let present = filePaths.contains(track.path)
            if track.isAvailable != present { track.isAvailable = present }
        }
        let fresh = files.filter { known[$0.path] == nil }
        total = fresh.count
        for batch in stride(from: 0, to: fresh.count, by: 200).map({ Array(fresh[$0..<min($0 + 200, fresh.count)]) }) {
            let base = scanned
            let read = await LibraryScanner.read(batch) { [weak self] count in
                Task { @MainActor in self?.scanned = base + count }
            }
            for file in read { insert(file, folderPath: folderPath) }
            scanned = base + batch.count
            try? context.save()
        }
        try? context.save()

        isScanning = false
        if let next = pendingFolders.popFirst() { await sync(next) }
    }

    private func insert(_ file: ScannedFile, folderPath: String) {
        let track = LibraryTrack(path: file.path, title: file.title, folderPath: folderPath)
        track.artist = file.artist
        track.album = file.album
        track.genre = file.genre
        track.year = file.year
        track.trackNumber = file.trackNumber
        track.duration = file.duration
        context.insert(track)
    }

    // MARK: Watching

    private func startWatching() {
        let paths = folders.map(\.path)
        watcher = LibraryWatcher(paths: paths) { [weak self] changed in
            guard let self else { return }
            // FSEvents reports real paths (/private/var), folders may be saved through a symlink (/var).
            let touched = paths.filter { folder in
                let real = URL(fileURLWithPath: folder).resolvingSymlinksInPath().path
                return changed.contains { $0.hasPrefix(real) || $0.hasPrefix(folder) }
            }
            Task { @MainActor in for folder in touched { await self.sync(folder) } }
        }
    }
}
