import SwiftUI
import WampKit

/// The main player window: display, seek bar, transport, volume.
/// Custom compact chrome on purpose: the display is Wamp's identity
/// (docs/DESIGN.md). Colors come from `Surface`.
struct PlayerView: View {
    @Environment(Player.self) private var player
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @Environment(\.undoManager) private var undoManager
    @State private var dragging: Double?
    private var theme = PlayerThemeStore.shared

    var body: some View {
        VStack(spacing: Space.sm) {
            display
            seekBar
            controls
        }
        .padding(Space.md)
        .frame(width: Layout.playerWidth)
        .background(Surface.playerBody)
        .noInitialFocus()
        .dropDestination(for: URL.self) { urls, _ in
            player.open(urls)
            return true
        }
        .onAppear { player.undoManager = undoManager }
        .task {
            Snapshot.runIfRequested(model: model, player: player, openSettings: openSettings, openWindow: openWindow)
        }
        .accessibilityLabel("Audio files drop area")
    }

    // MARK: Display

    private var display: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            HStack(alignment: .top, spacing: Space.md) {
                Text(Track.clock(shownTime))
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
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading) // grid: ok
            .background(Surface.display, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        }
        .accessibilityElement(children: .combine)
    }

    private var shownTime: Double { dragging ?? player.elapsed }

    private var titleText: String {
        if let track = player.current { return track.title }
        return "Wamp"
    }

    private var subtitleText: String {
        if let message = player.message { return message }
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
        .disabled(!player.hasTracks || player.current == nil)
        .help("Seek in this track")
        .accessibilityLabel("Position")
        .accessibilityValue("\(Track.clock(shownTime)) of \(Track.clock(player.duration))")
    }

    private var controls: some View {
        HStack(spacing: Space.sm) {
            transport("backward.fill", "Go to the previous track (\u{2318}\u{2190})", "Previous") { player.previous() }
            transport(player.isPlaying ? "pause.fill" : "play.fill",
                      player.isPlaying ? "Pause (Space)" : "Play (Space)",
                      player.isPlaying ? "Pause" : "Play") { player.togglePlay() }
            transport("stop.fill", "Stop playback (\u{2318}.)", "Stop") { player.stop() }
            transport("forward.fill", "Go to the next track (\u{2318}\u{2192})", "Next") { player.next() }
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

    private func transport(_ symbol: String, _ help: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .disabled(!player.hasTracks)
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
}
