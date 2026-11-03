import AppKit
import AVFoundation
import MediaPlayer
import MacAmpKit

/// What the system shows and controls: Now Playing, media keys, album art,
/// and the ReplayGain volume of the current track.
extension Player {
    /// The system asks for the picture from a background queue, so this closure
    /// must not be main-actor code.
    private nonisolated static func mediaArtwork(_ image: NSImage) -> MPMediaItemArtwork {
        nonisolated(unsafe) let image = image
        return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    /// Loads the art (and the ReplayGain volume) when the current track changes.
    func refreshArtwork() {
        guard station == nil, let track = current else {
            if artworkID != nil { artworkID = nil; artwork = nil }
            if station != nil { node.volume = 1 }
            return
        }
        guard artworkID != track.id else { return }
        artworkID = track.id
        artwork = nil
        let id = track.id, path = track.path
        Task {
            let image = await ArtworkLoader.image(forPath: path)
            guard artworkID == id else { return }
            artwork = image
            updateNowPlaying()
        }
        applyReplayGain(for: track)
    }

    /// Sets the player volume from the track's ReplayGain tags, per Settings > Playback.
    func applyReplayGain(for track: Track) {
        let mode = ReplayGain.Mode(rawValue: Store.defaults.string(forKey: "replaygain.mode") ?? "track") ?? .track
        guard mode != .off else { node.volume = 1; return }
        let preamp = Store.defaults.double(forKey: "replaygain.preamp")
        let limit = Store.defaults.object(forKey: "replaygain.limit") as? Bool ?? true
        let id = track.id, url = track.url
        Task {
            let tags = await ReplayGainReader.read(url)
            guard artworkID == id else { return }
            let gain = mode == .album ? (tags.albumGain ?? tags.trackGain) : (tags.trackGain ?? tags.albumGain)
            let peak = mode == .album ? (tags.albumPeak ?? tags.trackPeak) : tags.trackPeak
            node.volume = ReplayGain.volume(gain: gain, preamp: preamp, peak: peak, preventClipping: limit)
        }
    }

    // MARK: Now Playing and media keys

    func updateNowPlaying() {
        refreshArtwork()
        let center = MPNowPlayingInfoCenter.default()
        if let station {
            center.nowPlayingInfo = [MPMediaItemPropertyTitle: streamTitle ?? station.name,
                                     MPMediaItemPropertyArtist: station.name,
                                     MPNowPlayingInfoPropertyIsLiveStream: true,
                                     MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0]
            center.playbackState = isPlaying ? .playing : .paused
            return
        }
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
        if let artwork {
            center.nowPlayingInfo?[MPMediaItemPropertyArtwork] = Self.mediaArtwork(artwork)
        }
        center.playbackState = isPlaying ? .playing : (file == nil ? .stopped : .paused)
    }

    func setUpRemoteCommands() {
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
}
