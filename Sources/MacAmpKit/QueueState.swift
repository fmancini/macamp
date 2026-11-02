import Foundation

/// The Queue: the ordered tracks that play now and next, with shuffle and
/// repeat. Pure logic, so tests run it without the app.
public struct QueueState: Codable, Sendable, Equatable {
    public private(set) var tracks: [Track] = []
    public private(set) var currentID: Track.ID?
    public var shuffle = false { didSet { if shuffle != oldValue { resetShuffle() } } }
    public var repeatMode: RepeatMode = .off { didSet { upNext = nil } }
    /// The track that follows the current one, once decided. The player
    /// schedules it ahead of time so playback is gapless.
    public private(set) var upNext: Track.ID?
    /// Tracks not yet played in this shuffle round.
    private var bag: [Track.ID] = []
    /// Tracks played before the current one, for Previous in shuffle.
    private var history: [Track.ID] = []

    public init() {}

    public var current: Track? { currentID.flatMap(track) }
    public func track(_ id: Track.ID) -> Track? { tracks.first { $0.id == id } }
    public var isEmpty: Bool { tracks.isEmpty }
    private var currentIndex: Int? { currentID.flatMap { id in tracks.firstIndex { $0.id == id } } }

    // MARK: Editing

    public mutating func append(_ new: [Track]) {
        tracks += new
        if currentID == nil { currentID = new.first?.id }
        bag += new.map(\.id).filter { $0 != currentID }
        upNext = nil
    }

    /// Removes tracks. If the current track goes, the one that followed it becomes current.
    public mutating func remove(ids: Set<Track.ID>) {
        let oldIndex = currentIndex
        tracks.removeAll { ids.contains($0.id) }
        bag.removeAll { ids.contains($0) }
        history.removeAll { ids.contains($0) }
        if let id = currentID, ids.contains(id) {
            if let i = oldIndex, !tracks.isEmpty {
                currentID = tracks[min(i, tracks.count - 1)].id
            } else {
                currentID = nil
            }
        }
        upNext = nil
    }

    public mutating func clear() {
        tracks = []
        currentID = nil
        bag = []
        history = []
        upNext = nil
    }

    /// Moves the tracks at `offsets` to `destination`, like SwiftUI's `onMove`.
    public mutating func move(from offsets: IndexSet, to destination: Int) {
        let moving = offsets.map { tracks[$0] }
        let before = offsets.filter { $0 < destination }.count
        for i in offsets.reversed() { tracks.remove(at: i) }
        tracks.insert(contentsOf: moving, at: destination - before)
        upNext = nil
    }

    public mutating func update(_ id: Track.ID, title: String? = nil, artist: String? = nil, duration: Double? = nil) {
        guard let i = tracks.firstIndex(where: { $0.id == id }) else { return }
        if let title { tracks[i].title = title }
        if let artist { tracks[i].artist = artist }
        if let duration { tracks[i].duration = duration }
    }

    // MARK: Moving through the Queue

    /// Makes `id` the current track (a click, or Next landing on it).
    public mutating func setCurrent(_ id: Track.ID) {
        guard tracks.contains(where: { $0.id == id }), id != currentID else { return }
        if let c = currentID { history.append(c) }
        currentID = id
        bag.removeAll { $0 == id }
        upNext = nil
    }

    /// Decides which track follows the current one, without moving to it.
    /// `auto` is true when the current track ended by itself (Repeat One repeats it).
    @discardableResult
    public mutating func planNext(auto: Bool = true, using rng: inout some RandomNumberGenerator) -> Track.ID? {
        if let upNext, auto { return upNext }
        guard let index = currentIndex else { upNext = tracks.first?.id; return upNext }
        if auto, repeatMode == .one { upNext = currentID; return upNext }
        if shuffle {
            if bag.isEmpty, repeatMode == .all {
                bag = tracks.map(\.id).filter { $0 != currentID }
            }
            upNext = bag.randomElement(using: &rng)
            return upNext
        }
        if index + 1 < tracks.count {
            upNext = tracks[index + 1].id
        } else {
            upNext = repeatMode == .all ? tracks.first?.id : nil
        }
        return upNext
    }

    @discardableResult
    public mutating func planNext(auto: Bool = true) -> Track.ID? {
        var rng = SystemRandomNumberGenerator()
        return planNext(auto: auto, using: &rng)
    }

    /// Moves to the next track and returns it, or nil at the end of the Queue.
    @discardableResult
    public mutating func advance(auto: Bool, using rng: inout some RandomNumberGenerator) -> Track.ID? {
        if !auto { upNext = nil }
        guard let next = planNext(auto: auto, using: &rng) else { return nil }
        if next == currentID { upNext = nil; return next }   // Repeat One: same track again
        setCurrent(next)
        return next
    }

    @discardableResult
    public mutating func advance(auto: Bool) -> Track.ID? {
        var rng = SystemRandomNumberGenerator()
        return advance(auto: auto, using: &rng)
    }

    /// Moves to the previous track and returns it. At the first track it stays there.
    @discardableResult
    public mutating func goBack() -> Track.ID? {
        upNext = nil
        if shuffle {
            guard let last = history.popLast() else { return currentID }
            if let c = currentID { bag.append(c) }
            currentID = last
            return last
        }
        guard let i = currentIndex, i > 0 else { return currentID }
        currentID = tracks[i - 1].id
        return currentID
    }

    private mutating func resetShuffle() {
        upNext = nil
        history = []
        bag = tracks.map(\.id).filter { $0 != currentID }
    }
}
