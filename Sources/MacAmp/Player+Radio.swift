import AVFoundation
import SwiftData
import MacAmpKit

/// Internet radio. A station plays through the same engine as local files, so
/// the volume (and later the equalizer) apply to both. MP3 and AAC streams are
/// decoded here; other streams (HLS, Ogg) fall back to AVPlayer.
extension Player {
    /// How much audio to collect before playback starts.
    var radioPrebuffer: Double {
        switch Store.defaults.string(forKey: "radio.buffer") {
        case "small": 1
        case "large": 8
        default: 3
        }
    }

    func playStation(_ station: Station) {
        guard let url = URL(string: station.url) else {
            message = "Can't play this address."
            return
        }
        stopRadio(clearStation: false)
        // The Queue pauses; the station takes over.
        stopEngine()
        file = nil
        self.station = station
        streamTitle = nil
        message = nil
        isPlaying = true
        radioAttempts = 0
        radioStatus = "Connecting\u{2026}"
        Task { await RadioBrowser.countClick(station) }
        if station.isHLS { startAVPlayer(url, station: station); return }
        openStream(url)
        updateNowPlaying()
    }

    private func openStream(_ url: URL) {
        radioGeneration += 1
        let generation = radioGeneration
        radioQueuedSeconds = 0
        radioNodeStarted = false
        let stream = RadioStream(url: url) { [weak self] event in
            Task { @MainActor in self?.handle(event, generation: generation) }
        }
        // A reconnect keeps recording into the same session.
        stream.recorder = recorder
        radioStream = stream
        stream.start()
    }

    /// Stops the stream. With `clearStation` the station is forgotten too.
    func stopRadio(clearStation: Bool) {
        stopRecording()
        radioGeneration += 1
        radioStream?.stop()
        radioStream = nil
        avPlayer?.pause()
        avPlayer = nil
        avMetadata = nil
        if station != nil { node.stop() }
        radioNodeStarted = false
        radioStatus = nil
        if clearStation {
            // Forgetting a playing station also stops "playing".
            if station != nil { isPlaying = false }
            station = nil
            streamTitle = nil
        }
    }

    private func handle(_ event: RadioEvent, generation: Int) {
        guard generation == radioGeneration, station != nil else { return }
        switch event {
        case .connected:
            radioStatus = "Buffering\u{2026}"
        case .format(let format):
            if connectedFormat != format { node.stop(); radioNodeStarted = false }
            connect(format: format)
            startEngineIfNeeded()
        case .buffer(let buffer):
            node.scheduleBuffer(buffer, completionHandler: nil)
            radioAttempts = 0
            radioQueuedSeconds += Double(buffer.frameLength) / buffer.format.sampleRate
            if !radioNodeStarted, radioQueuedSeconds >= radioPrebuffer {
                node.play()
                radioNodeStarted = true
                radioStatus = nil
                updateNowPlaying()
            }
        case .title(let title):
            streamTitle = title
            recordTitle(title)
            updateNowPlaying()
        case .unsupported:
            if let url = station.flatMap({ URL(string: $0.url) }), let station { startAVPlayer(url, station: station) }
        case .ended(let reason):
            reconnect(reason: reason)
        }
    }

    /// Tries again after a dropped connection: up to 5 times, waiting longer each time.
    private func reconnect(reason: String?) {
        guard let station, isPlaying, let url = URL(string: station.url) else { return }
        radioAttempts += 1
        guard radioAttempts <= 5 else {
            message = "Can't reach \"\(station.name)\". Check your connection and press Play."
            stopRadio(clearStation: false)
            isPlaying = false
            updateNowPlaying()
            return
        }
        radioStatus = "Reconnecting (\(radioAttempts) of 5)\u{2026}"
        let generation = radioGeneration
        let delay = min(pow(2, Double(radioAttempts - 1)), 16)
        Task {
            try? await Task.sleep(for: .seconds(delay))
            guard generation == radioGeneration, isPlaying else { return }
            let keepRunning = radioNodeStarted
            openStream(url)
            radioNodeStarted = keepRunning
        }
    }

    // MARK: Recording

    /// Where recordings go: ~/Music/MacAmp Recordings unless Settings says otherwise.
    static var recordingsFolder: URL {
        if let path = Store.defaults.string(forKey: "recording.folder"), !path.isEmpty { return URL(fileURLWithPath: path) }
        return URL.musicDirectory.appending(path: "MacAmp Recordings", directoryHint: .isDirectory)
    }

    static var splitsByTitle: Bool { Store.defaults.object(forKey: "recording.split") as? Bool ?? true }

    var isRecording: Bool { recorder != nil }

    /// A station that sends plain MP3 or AAC can be recorded; HLS and AVPlayer streams cannot.
    var canRecord: Bool { station != nil && isPlaying && radioStream != nil && avPlayer == nil }

    func toggleRecording(folder: URL? = nil) {
        if isRecording { stopRecording(); return }
        guard canRecord, let station, let stream = radioStream else { return }
        let ext = stream.fileExtension ?? (station.codec.uppercased().hasPrefix("AAC") ? "aac" : "mp3")
        let new = StreamRecorder(folder: folder ?? Self.recordingsFolder, stationName: station.name, fileExtension: ext,
                                 splitByTitle: Self.splitsByTitle, currentTitle: streamTitle)
        recorder = new
        stream.recorder = new
    }

    func stopRecording() {
        guard let finished = recorder else { return }
        radioStream?.recorder = nil
        finished.finish()
        recorder = nil
        lastRecording = finished.savedFiles
    }

    // MARK: AVPlayer fallback

    private func startAVPlayer(_ url: URL, station: Station) {
        stopRadio(clearStation: false)
        self.station = station
        let item = AVPlayerItem(url: url)
        let bridge = AVPlayerMetadataBridge { [weak self] title in
            Task { @MainActor in
                guard let self, self.station?.id == station.id else { return }
                self.streamTitle = title
                self.recordTitle(title)
                self.updateNowPlaying()
            }
        }
        item.add(bridge.output)
        let player = AVPlayer(playerItem: item)
        player.volume = Store.isOverridden ? 0 : volume
        player.play()
        avPlayer = player
        avMetadata = bridge
        isPlaying = true
        radioStatus = nil
        updateNowPlaying()
    }

    // MARK: History

    /// Keeps the last 500 titles heard on stations.
    private func recordTitle(_ title: String) {
        guard let station else { return }
        let context = LibraryModel.shared.context
        context.insert(PlayedTitle(stationName: station.name, title: title))
        if let count = try? context.fetchCount(FetchDescriptor<PlayedTitle>()), count > 500 {
            var oldest = FetchDescriptor<PlayedTitle>(sortBy: [SortDescriptor(\.playedAt)])
            oldest.fetchLimit = count - 500
            for old in (try? context.fetch(oldest)) ?? [] { context.delete(old) }
        }
        try? context.save()
    }
}

/// Reads song titles from an AVPlayer stream's timed metadata.
final class AVPlayerMetadataBridge: NSObject, AVPlayerItemMetadataOutputPushDelegate {
    let output = AVPlayerItemMetadataOutput(identifiers: nil)
    private let onTitle: (String) -> Void

    init(onTitle: @escaping (String) -> Void) {
        self.onTitle = onTitle
        super.init()
        output.setDelegate(self, queue: .main)
    }

    func metadataOutput(_ output: AVPlayerItemMetadataOutput, didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
                        from track: AVPlayerItemTrack?) {
        let items = groups.flatMap(\.items)
        let found = items.first { $0.commonKey == .commonKeyTitle || $0.identifier == .icyMetadataStreamTitle }
        if let title = found?.stringValue, !title.isEmpty { onTitle(title) }
    }
}
