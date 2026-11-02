import CoreServices
import Foundation

/// Calls `onChange` (on the main queue) when files change inside the folders.
final class LibraryWatcher {
    private final class Box {
        let handler: ([String]) -> Void
        init(_ handler: @escaping ([String]) -> Void) { self.handler = handler }
    }

    nonisolated(unsafe) private var stream: FSEventStreamRef?
    private let box: Box

    init?(paths: [String], onChange: @escaping ([String]) -> Void) {
        guard !paths.isEmpty else { return nil }
        box = Box(onChange)
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(box).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, eventPaths, _, _ in
            guard let info else { return }
            let box = Unmanaged<Box>.fromOpaque(info).takeUnretainedValue()
            let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
            box.handler(Array(paths.prefix(count)))
        }
        guard let stream = FSEventStreamCreate(nil, callback, &context, paths as CFArray,
                                               FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 1.5,
                                               FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes
                                                                        | kFSEventStreamCreateFlagFileEvents)) else { return nil }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
    }

    deinit {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }
}
