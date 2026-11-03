import Foundation
import MacAmpKit

/// Saves the raw audio of a radio stream to files, without re-encoding.
/// With `splitByTitle` it starts a new file at each song change. Files are
/// cut at the byte where the title changes, so a file may begin or end in the
/// middle of an MP3 frame; players skip that.
nonisolated final class StreamRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private let folder: URL
    private let stationName: String
    private let splitByTitle: Bool
    private var fileExtension: String
    private var handle: FileHandle?
    private var currentTitle: String?
    private var files: [URL] = []
    private var bytes = 0

    init(folder: URL, stationName: String, fileExtension: String, splitByTitle: Bool, currentTitle: String?) {
        self.folder = folder
        self.stationName = stationName
        self.fileExtension = fileExtension
        self.splitByTitle = splitByTitle
        self.currentTitle = currentTitle
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    // MARK: Status (readable from any thread)

    var fileCount: Int { lock.withLock { files.count } }
    var byteCount: Int { lock.withLock { bytes } }
    var savedFiles: [URL] { lock.withLock { files } }
    var currentFileName: String? { lock.withLock { files.last?.lastPathComponent } }

    // MARK: Writing

    func setExtension(_ ext: String) { lock.withLock { if handle == nil { fileExtension = ext } } }

    func write(_ data: Data) {
        lock.withLock {
            if handle == nil { openFile(partial: currentTitle != nil && splitByTitle) }
            try? handle?.write(contentsOf: data)
            bytes += data.count
        }
    }

    /// A new song title arrived. With splitting, the next audio goes to a new file.
    func title(_ title: String) {
        lock.withLock {
            guard title != currentTitle else { return }
            currentTitle = title
            if splitByTitle {
                closeFile()
                openFile(partial: false)
            }
        }
    }

    func finish() { lock.withLock { closeFile() } }

    // MARK: Files (lock held)

    private func openFile(partial: Bool) {
        let stamp = Date.now.formatted(.iso8601.year().month().day().dateTimeSeparator(.space).time(includingFractionalSeconds: false))
            .replacingOccurrences(of: ":", with: ".")
        var name: String
        if splitByTitle, let title = currentTitle, !RecordingNames.sanitize(title).isEmpty {
            name = RecordingNames.sanitize(title) + (partial ? " (partial)" : "")
        } else {
            name = RecordingNames.sanitize(stationName) + " - " + stamp
        }
        if name.isEmpty { name = "Recording " + stamp }
        let url = RecordingNames.unique(name, ext: fileExtension, in: folder)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try? FileHandle(forWritingTo: url)
        files.append(url)
    }

    private func closeFile() {
        try? handle?.close()
        handle = nil
    }
}
