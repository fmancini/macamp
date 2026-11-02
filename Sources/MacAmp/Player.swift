import AVFoundation
import MediaPlayer
import Observation
import UniformTypeIdentifiers
import MacAmpKit

/// Plays the Queue. Local files go through AVAudioEngine; the next track is
/// scheduled before the current one ends, so same-format tracks play gapless.
@Observable
final class Player {
    /// The one player. The app, the menus, and test modes all use it.
    static let shared = Player()

    private(set) var queue = QueueState() {
        didSet { queueChanged(from: oldValue) }
    }
    private(set) var isPlaying = false
    /// Tracks whose file could not be found or decoded.
    private(set) var unavailable: Set<Track.ID> = []
    /// The last problem, shown inline. nil when there is none.
    private(set) var message: String?
    /// True once the next track is scheduled behind the current one.
    private(set) var nextScheduled = false

    var volume: Float {
        didSet {
            engine.mainMixerNode.outputVolume = Store.isOverridden ? 0 : volume
            Store.defaults.set(volume, forKey: "player.volume")
        }
    }
    var undoManager: UndoManager?

    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private var file: AVAudioFile?
    private var nextFile: AVAudioFile?
    private var connectedFormat: AVAudioFormat?
    /// Frame of `file` where the current segment started (after a seek).
    private var startFrame: AVAudioFramePosition = 0
    /// Samples the node played before the current segment began (gapless hand-offs).
    private var baseSample: AVAudioFramePosition = 0
    private var pausedAt: Double = 0
    private var generation = 0

    init() {
        let saved = Store.defaults.object(forKey: "player.volume") as? Float
        volume = saved ?? 0.8
        engine.attach(node)
        engine.mainMixerNode.outputVolume = Store.isOverridden ? 0 : volume
        if let restored = QueueStore.load(from: Store.queueURL) {
            queue = restored
            unavailable = Set(restored.tracks.filter { !FileManager.default.fileExists(atPath: $0.path) }.map(\.id))
        }
        // Samples leaving the player node, before the volume. Self-test reads it.
        Self.installPeakTap(on: node, store: peakStore)
        // A device change (a display with speakers, headphones, Bluetooth) stops the
        // engine. Without this, the window says "playing" and nothing sounds.
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine,
                                               queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.engineConfigurationChanged() }
        }
        setUpRemoteCommands()
    }

    /// Largest sample seen since the last read, then resets. Self-test only.
    func takePeak() -> Float {
        let value = peakStore.value
        peakStore.value = 0
        return value
    }
    private let peakStore = PeakStore()

    /// Runs on the audio thread, so it must not be main-actor code.
    private nonisolated static func installPeakTap(on node: AVAudioPlayerNode, store: PeakStore) {
        node.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, _ in
            guard let data = buffer.floatChannelData?[0] else { return }
            var peak: Float = 0
            for i in 0..<Int(buffer.frameLength) { peak = max(peak, abs(data[i])) }
            store.value = max(peak, store.value)
        }
    }

    private func engineConfigurationChanged() {
        guard file != nil else { return }
        let position = isPlaying ? elapsed : pausedAt
        let wasPlaying = isPlaying
        connectedFormat = nil
        stopEngine()
        isPlaying = wasPlaying
        seekAfterRestart(to: position, playing: wasPlaying)
    }

    private func seekAfterRestart(to seconds: Double, playing: Bool) {
        guard let file else { return }
        connect(format: file.processingFormat)
        startEngineIfNeeded()
        let rate = file.processingFormat.sampleRate
        startFrame = min(AVAudioFramePosition(seconds * rate), max(0, file.length - 1))
        baseSample = 0
        scheduleCurrent(from: startFrame)
        if playing { node.play(); scheduleNext() } else { pausedAt = Double(startFrame) / rate }
        isPlaying = playing
        updateNowPlaying()
    }

    // MARK: Reading state

    var current: Track? { queue.current }
    var hasTracks: Bool { !queue.isEmpty }

    var duration: Double {
        if let file { return Double(file.length) / file.processingFormat.sampleRate }
        return current?.duration ?? 0
    }

    /// Seconds into the current track.
    var elapsed: Double {
        guard let file else { return 0 }
        guard isPlaying else { return pausedAt }
        let rate = file.processingFormat.sampleRate
        // Right after a seek the node has not rendered yet: the segment start is the position.
        guard let last = node.lastRenderTime, let time = node.playerTime(forNodeTime: last) else {
            return Double(startFrame) / rate
        }
        let played = Double(time.sampleTime - baseSample) / rate + Double(startFrame) / rate
        return min(max(0, played), duration)
    }

    // MARK: Adding tracks

    /// Adds audio files (and the audio files inside folders) to the end of the
    /// Queue, and plays the first one added unless something is already playing.
    func open(_ urls: [URL], play: Bool = true) {
        let files = Self.audioFiles(in: urls)
        guard !files.isEmpty else {
            message = "No audio files found."
            return
        }
        message = nil
        let new = files.map { Track(url: $0) }
        let wasEmpty = queue.isEmpty
        registerUndo("Add to Queue")
        queue.append(new)
        for track in new { loadMetadata(track) }
        if play, let first = new.first, !isPlaying || wasEmpty {
            playTrack(first.id)
        }
    }

    static func audioFiles(in urls: [URL]) -> [URL] {
        var result: [URL] = []
        for url in urls {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                let inside = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil,
                                                            options: [.skipsHiddenFiles])?
                    .compactMap { $0 as? URL }.filter(isAudio).sorted { $0.path < $1.path } ?? []
                result += inside
            } else if isAudio(url) {
                result.append(url)
            }
        }
        return result
    }

    private static func isAudio(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension.lowercased())?.conforms(to: .audio) ?? false
    }

    private func loadMetadata(_ track: Track) {
        let url = track.url, id = track.id
        Task {
            let found = await Self.readMetadata(url)
            queue.update(id, title: found.title, artist: found.artist, duration: found.duration)
        }
    }

    /// Reads title, artist, and duration from a file's tags.
    private nonisolated static func readMetadata(_ url: URL) async -> (title: String?, artist: String?, duration: Double?) {
        let asset = AVURLAsset(url: url)
        let duration = (try? await asset.load(.duration))?.seconds
        let items = (try? await asset.load(.commonMetadata)) ?? []
        let title = try? await AVMetadataItem.metadataItems(from: items, filteredByIdentifier: .commonIdentifierTitle)
            .first?.load(.stringValue)
        let artist = try? await AVMetadataItem.metadataItems(from: items, filteredByIdentifier: .commonIdentifierArtist)
            .first?.load(.stringValue)
        return (title ?? nil, artist ?? nil, duration.flatMap { $0.isFinite ? $0 : nil })
    }

    // MARK: Playing from the Library and playlists

    /// Replaces the Queue with `tracks` and plays the one at `index`.
    func play(_ tracks: [Track], startAt index: Int) {
        guard tracks.indices.contains(index) else { return }
        registerUndo("Replace Queue")
        queue.clear()
        queue.append(tracks)
        file = nil
        message = nil
        playTrack(tracks[index].id)
    }

    /// Adds tracks to the end of the Queue without changing what plays.
    func addToQueue(_ tracks: [Track]) {
        guard !tracks.isEmpty else { return }
        registerUndo("Add to Queue")
        queue.append(tracks)
    }

    // MARK: Queue editing

    func remove(ids: Set<Track.ID>) {
        guard !ids.isEmpty else { return }
        let removingCurrent = current.map { ids.contains($0.id) } ?? false
        registerUndo(ids.count == 1 ? "Remove from Queue" : "Remove \(ids.count) Tracks from Queue")
        queue.remove(ids: ids)
        if removingCurrent {
            stopEngine()
            file = nil
            if isPlaying, let id = queue.currentID { playTrack(id) } else { isPlaying = false; pausedAt = 0 }
        }
    }

    func clearQueue() {
        registerUndo("Clear Queue")
        queue.clear()
        stopEngine()
        file = nil
        nextFile = nil
        isPlaying = false
        pausedAt = 0
        updateNowPlaying()
    }

    func move(from offsets: IndexSet, to destination: Int) {
        registerUndo("Move in Queue")
        queue.move(from: offsets, to: destination)
    }

    private func registerUndo(_ name: String) {
        guard let undoManager else { return }
        let snapshot = queue
        undoManager.registerUndo(withTarget: self) { player in
            MainActor.assumeIsolated { player.restore(snapshot, name: name) }
        }
        undoManager.setActionName(name)
    }

    private func restore(_ snapshot: QueueState, name: String) {
        let redo = queue
        undoManager?.registerUndo(withTarget: self) { player in
            MainActor.assumeIsolated { player.restore(redo, name: name) }
        }
        let currentChanged = snapshot.currentID != queue.currentID
        queue = snapshot
        if currentChanged {
            stopEngine()
            file = nil
            pausedAt = 0
            isPlaying = false
        }
    }

    // MARK: Transport

    func togglePlay() {
        if isPlaying {
            pause()
        } else if file != nil {
            resume()
        } else if let id = queue.currentID {
            playTrack(id)
        }
    }

    func pause() {
        guard isPlaying else { return }
        pausedAt = elapsed
        node.pause()
        isPlaying = false
        updateNowPlaying()
    }

    private func resume() {
        if !engine.isRunning, file != nil { seekAfterRestart(to: pausedAt, playing: true); return }
        startEngineIfNeeded()
        node.play()
        isPlaying = true
        updateNowPlaying()
    }

    func stop() {
        stopEngine()
        isPlaying = false
        pausedAt = 0
        startFrame = 0
        // Back to the start of the current track, ready for Play.
        if let id = queue.currentID { prepare(id) }
        updateNowPlaying()
    }

    /// Next: always moves on, even with Repeat One.
    func next() {
        guard let id = queue.advance(auto: false) else { stopAtEnd(); return }
        playTrack(id)
    }

    /// Previous: restarts the track after 3 seconds, otherwise goes back one.
    func previous() {
        if elapsed > 3 { seek(to: 0); return }
        if let id = queue.goBack() { playTrack(id) }
    }

    func playTrack(_ id: Track.ID) {
        queue.setCurrent(id)
        beginPlayback(of: id, attempts: 0)
    }

    private func beginPlayback(of id: Track.ID, attempts: Int) {
        stopEngine()
        guard let track = queue.track(id) else { return }
        do {
            let opened = try AVAudioFile(forReading: track.url)
            unavailable.remove(id)
            file = opened
        } catch {
            unavailable.insert(id)
            message = "Can't play \"\(track.title)\": " + (FileManager.default.fileExists(atPath: track.path)
                ? "unsupported format." : "file not found.")
            file = nil
            if attempts < queue.tracks.count, let following = queue.advance(auto: true) {
                beginPlayback(of: following, attempts: attempts + 1)
            } else {
                isPlaying = false
            }
            return
        }
        message = nil
        startFrame = 0
        baseSample = 0
        connect(format: file!.processingFormat)
        startEngineIfNeeded()
        scheduleCurrent(from: 0)
        node.play()
        isPlaying = true
        pausedAt = 0
        scheduleNext()
        updateNowPlaying()
    }

    /// Loads a track without playing it (Stop, restored queue, undo).
    private func prepare(_ id: Track.ID) {
        guard let track = queue.track(id), let opened = try? AVAudioFile(forReading: track.url) else { return }
        file = opened
    }

    func seek(to seconds: Double) {
        guard let file else { return }
        let rate = file.processingFormat.sampleRate
        let frame = AVAudioFramePosition(max(0, min(seconds, duration)) * rate)
        let wasPlaying = isPlaying
        stopEngine()
        startFrame = min(frame, max(0, file.length - 1))
        baseSample = 0
        connect(format: file.processingFormat)
        startEngineIfNeeded()
        scheduleCurrent(from: startFrame)
        if wasPlaying {
            node.play()
            scheduleNext()
        } else {
            pausedAt = Double(startFrame) / rate
        }
        isPlaying = wasPlaying
        updateNowPlaying()
    }

    func seek(by delta: Double) { seek(to: elapsed + delta) }

    func adjustVolume(by delta: Float) { volume = min(1, max(0, volume + delta)) }

    // MARK: Engine

    private func connect(format: AVAudioFormat) {
        guard connectedFormat != format else { return }
        let running = engine.isRunning
        if running { engine.stop() }
        engine.disconnectNodeOutput(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        connectedFormat = format
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else { return }
        engine.prepare()
        do { try engine.start() } catch { message = "Can't start audio output." }
    }

    private func stopEngine() {
        generation += 1
        node.stop()
        nextFile = nil
        nextScheduled = false
    }

    private func scheduleCurrent(from frame: AVAudioFramePosition) {
        guard let file else { return }
        let gen = generation
        let count = AVAudioFrameCount(max(0, file.length - frame))
        guard count > 0 else { return }
        node.scheduleSegment(file, startingFrame: frame, frameCount: count, at: nil,
                             completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in self?.segmentFinished(generation: gen) }
        }
    }

    /// Schedules the next track behind the current one when it has the same
    /// format. A different format cannot be scheduled on the same node, so that
    /// boundary is not gapless (it reconnects when the track ends).
    private func scheduleNext() {
        guard file != nil, !nextScheduled, let id = queue.planNext(auto: true), id != queue.currentID || queue.repeatMode == .one,
              let track = queue.track(id), let opened = try? AVAudioFile(forReading: track.url),
              opened.processingFormat == connectedFormat else { return }
        let gen = generation
        node.scheduleFile(opened, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in self?.segmentFinished(generation: gen) }
        }
        nextFile = opened
        nextScheduled = true
    }

    /// A scheduled segment finished. Either the next track already follows (gapless)
    /// or the Queue moves on, or playback ends.
    private func segmentFinished(generation gen: Int) {
        guard gen == generation, isPlaying else { return }
        if nextScheduled, let opened = nextFile {
            baseSample += file?.length ?? 0
            file = opened
            startFrame = 0
            nextFile = nil
            nextScheduled = false
            _ = queue.advance(auto: true)
            scheduleNext()
            updateNowPlaying()
        } else if let id = queue.advance(auto: true) {
            beginPlayback(of: id, attempts: 0)
        } else {
            stopAtEnd()
        }
    }

    private func stopAtEnd() {
        stopEngine()
        isPlaying = false
        pausedAt = 0
        startFrame = 0
        if let id = queue.currentID { prepare(id) }
        updateNowPlaying()
    }

    private func queueChanged(from old: QueueState) {
        if !Store.isOverridden || ProcessInfo.processInfo.environment["APP_SELFTEST_SAVE"] != nil {
            QueueStore.save(queue, to: Store.queueURL)
        }
        // The planned next track changed: drop the scheduled one and schedule again.
        if nextScheduled, old.upNext != queue.upNext || old.currentID != queue.currentID {
            let position = elapsed
            seek(to: position)
        }
    }

    // MARK: Now Playing and media keys

    private func updateNowPlaying() {
        let center = MPNowPlayingInfoCenter.default()
        guard let track = current else {
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
            return
        }
        center.nowPlayingInfo = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        center.playbackState = isPlaying ? .playing : (file == nil ? .stopped : .paused)
    }

    private func setUpRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        func bind(_ command: MPRemoteCommand, _ action: @escaping @MainActor (Player) -> Void) {
            command.isEnabled = true
            command.addTarget { [weak self] _ in
                Task { @MainActor in if let self { action(self) } }
                return .success
            }
        }
        bind(commands.playCommand) { if !$0.isPlaying { $0.togglePlay() } }
        bind(commands.pauseCommand) { $0.pause() }
        bind(commands.togglePlayPauseCommand) { $0.togglePlay() }
        bind(commands.nextTrackCommand) { $0.next() }
        bind(commands.previousTrackCommand) { $0.previous() }
        commands.changePlaybackPositionCommand.isEnabled = true
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }
    }

    // MARK: Modes

    func toggleShuffle() { queue.shuffle.toggle(); if isPlaying { reschedule() } }
    func cycleRepeat() { queue.repeatMode = queue.repeatMode.next; if isPlaying { reschedule() } }

    private func reschedule() {
        let position = elapsed
        seek(to: position)
    }
}


/// A float shared between the audio thread and the main actor.
nonisolated final class PeakStore: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Float = 0
    var value: Float {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}
