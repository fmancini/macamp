import SwiftUI
import MacAmpKit

/// The main player window: display, seek bar, transport, volume.
/// Custom compact chrome on purpose: the display is MacAmp's identity
/// (docs/DESIGN.md). Colors come from `Surface`.
struct PlayerView: View {
    @Environment(Player.self) private var player
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @Environment(\.undoManager) private var undoManager
    @State private var dragging: Double?
    private var theme = PlayerThemeStore.shared
    private var windowState = PlayerWindowState.shared

    var body: some View {
        Group {
            if windowState.shade {
                shadeBar
            } else {
                VStack(spacing: Space.sm) {
                    display
                    seekBar
                    controls
                }
            }
        }
        .padding(windowState.shade ? Space.sm : Space.md)
        .frame(width: Layout.playerWidth)
        .background(Surface.playerBody)
        .noInitialFocus()
        .dropDestination(for: URL.self) { urls, _ in
            player.open(urls)
            return true
        }
        .background(WindowAccessor { WindowSnapper.shared.register($0) })
        .onAppear { player.undoManager = undoManager }
        .task {
            Snapshot.runIfRequested(model: model, player: player, openSettings: openSettings, openWindow: openWindow)
        }
        .accessibilityLabel("Audio files drop area")
    }

    // MARK: Display

    private var display: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            VStack(spacing: Space.sm) {
            HStack(alignment: .top, spacing: Space.md) {
                Text(player.isLive ? "LIVE" : Track.clock(shownTime))
                    .font(.system(size: 28, weight: .medium, design: .monospaced)) // grid: ok
                    .foregroundStyle(Surface.readout)
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(titleText)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(Surface.readout)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(subtitleColor)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let artwork = player.artwork, !player.isLive {
                    Image(nsImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40) // grid: ok
                        .clipShape(RoundedRectangle(cornerRadius: Radius.xs, style: .continuous))
                        .accessibilityLabel("Album art")
                }
                Button { windowState.shade = true } label: {
                    Image(systemName: "rectangle.compress.vertical")
                        .font(.caption)
                        .foregroundStyle(Surface.readoutDim)
                }
                .buttonStyle(.borderless)
                .help("Shrink to a thin bar (\u{2325}\u{2318}M)")
                .accessibilityLabel("Windowshade Mode")
            }
            SpectrumView()
                .frame(height: 24) // grid: ok
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Surface.display, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        }
        .accessibilityElement(children: .combine)
    }

    private var shownTime: Double { dragging ?? player.elapsed }

    private var titleText: String {
        if let station = player.station { return station.name }
        if let track = player.current { return track.title }
        return "MacAmp"
    }

    private var subtitleText: String {
        if let message = player.message { return message }
        if player.isLive {
            let base = player.radioStatus ?? player.streamTitle ?? (player.isPlaying ? "Live" : "Stopped")
            if let recorder = player.recorder {
                let files = recorder.fileCount
                return "\u{25CF} REC \(files) \(files == 1 ? "file" : "files") \u{2022} \(base)"
            }
            return base
        }
        guard let track = player.current else { return "Drop audio files here, or press \u{2318}O" }
        return track.artist.isEmpty ? "Total \(Track.clock(player.duration))" : "\(track.artist) \u{2022} \(Track.clock(player.duration))"
    }

    private var subtitleColor: Color { player.message == nil ? Surface.readoutDim : Surface.warning }

    // MARK: Seek and volume

    private var seekBar: some View {
        Slider(value: Binding(get: { shownTime }, set: { dragging = $0 }),
               in: 0...max(player.duration, 1)) { editing in
            if !editing, let target = dragging {
                player.seek(to: target)
                dragging = nil
            }
        }
        .controlSize(.small)
        .disabled(!player.hasTracks || player.current == nil || player.isLive)
        .help("Seek in this track")
        .accessibilityLabel("Position")
        .accessibilityValue("\(Track.clock(shownTime)) of \(Track.clock(player.duration))")
    }

    private var controls: some View {
        HStack(spacing: Space.sm) {
            transport("backward.fill", "Go to the previous track (\u{2318}\u{2190})", "Previous", queueOnly: true) { player.previous() }
            transport(player.isPlaying ? "pause.fill" : "play.fill",
                      player.isPlaying ? "Pause (Space)" : "Play (Space)",
                      player.isPlaying ? "Pause" : "Play") { player.togglePlay() }
            transport("stop.fill", "Stop playback (\u{2318}.)", "Stop") { player.stop() }
            recordButton
            transport("forward.fill", "Go to the next track (\u{2318}\u{2192})", "Next", queueOnly: true) { player.next() }
            Spacer(minLength: Space.sm)
            toggle("shuffle", "Play the Queue in random order (\u{2318}S)", "Shuffle", on: player.queue.shuffle) { player.toggleShuffle() }
            toggle(player.queue.repeatMode == .one ? "repeat.1" : "repeat",
                   "Repeat: \(player.queue.repeatMode.label). Click to change (\u{2318}R)", "Repeat",
                   on: player.queue.repeatMode != .off) { player.cycleRepeat() }
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Slider(value: Binding(get: { Double(player.volume) }, set: { player.volume = Float($0) }), in: 0...1)
                .controlSize(.small)
                .frame(width: 64)
                .help("Change the volume")
                .accessibilityLabel("Volume")
                .accessibilityValue("\(Int(player.volume * 100)) percent")
        }
    }

    /// Record is for stations: it saves the stream to files (Radio settings pick the folder).
    private var recordButton: some View {
        Button { player.toggleRecording() } label: {
            Image(systemName: player.isRecording ? "record.circle.fill" : "record.circle")
                .frame(width: 24, height: 24)
                .foregroundStyle(player.isRecording ? Color.red : .primary)
        }
        .buttonStyle(.borderless)
        .disabled(!player.canRecord && !player.isRecording)
        .help(player.isRecording ? "Stop recording (\u{21E7}\u{2318}R)"
              : (player.isLive ? "Record this station (\u{21E7}\u{2318}R)" : "Recording works with radio stations"))
        .accessibilityLabel(player.isRecording ? "Stop Recording" : "Record Station")
    }

    private func transport(_ symbol: String, _ help: String, _ label: String, queueOnly: Bool = false, action: @escaping () -> Void) -> some View {
        let enabled = queueOnly ? (player.hasTracks && !player.isLive) : player.canPlay
        return Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .help(help)
        .accessibilityLabel(label)
    }

    private func toggle(_ symbol: String, _ help: String, _ label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 24, height: 24)
                .foregroundStyle(on ? Palette.accentText : .secondary)
        }
        .buttonStyle(.borderless)
        .help(help)
        .accessibilityLabel(label)
        .accessibilityValue(on ? "On" : "Off")
    }

    // MARK: Windowshade mode

    /// One thin row: transport, what is playing, the time, and a way back.
    private var shadeBar: some View {
        HStack(spacing: Space.sm) {
            shadeButton("backward.fill", "Previous", queueOnly: true) { player.previous() }
            shadeButton(player.isPlaying ? "pause.fill" : "play.fill", player.isPlaying ? "Pause" : "Play") { player.togglePlay() }
            shadeButton("forward.fill", "Next", queueOnly: true) { player.next() }
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                HStack(spacing: Space.sm) {
                    Text(shadeTitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Surface.readout)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: Space.xs)
                    Text(player.isLive ? "LIVE" : Track.clock(player.elapsed))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Surface.readout)
                        .monospacedDigit()
                }
                .padding(.horizontal, Space.sm)
                .frame(maxWidth: .infinity, minHeight: Layout.shadeHeight, alignment: .leading)
                .background(Surface.display, in: RoundedRectangle(cornerRadius: Radius.xs, style: .continuous))
            }
            Button { windowState.shade = false } label: {
                Image(systemName: "rectangle.expand.vertical").frame(width: 20, height: 20) // grid: ok
            }
            .buttonStyle(.borderless)
            .help("Show the full player (\u{2325}\u{2318}M)")
            .accessibilityLabel("Show Full Player")
        }
    }

    private var shadeTitle: String {
        guard player.station != nil || player.current != nil else { return "MacAmp" }
        return titleText + (player.isLive ? (player.streamTitle.map { " \u{2013} \($0)" } ?? "") : "")
    }

    private func shadeButton(_ symbol: String, _ label: String, queueOnly: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 20, height: 20) } // grid: ok
            .buttonStyle(.borderless)
            .disabled(queueOnly ? !(player.hasTracks && !player.isLive) : !player.canPlay)
            .help(label)
            .accessibilityLabel(label)
    }
}
