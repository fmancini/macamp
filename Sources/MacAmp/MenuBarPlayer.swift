import SwiftUI
import MacAmpKit

/// The player in the menu bar: what is playing, transport, and volume.
struct MenuBarPlayer: View {
    @Environment(Player.self) private var player
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(title).font(.headline).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            HStack(spacing: Space.lg) {
                Spacer()
                button("backward.fill", "Previous", queueOnly: true) { player.previous() }
                button(player.isPlaying ? "pause.fill" : "play.fill", player.isPlaying ? LocalizedStringKey("Pause") : LocalizedStringKey("Play")) { player.togglePlay() }
                button("forward.fill", "Next", queueOnly: true) { player.next() }
                Spacer()
            }
            .font(.title3)
            HStack(spacing: Space.sm) {
                Image(systemName: "speaker.fill").font(.caption).foregroundStyle(.secondary).accessibilityHidden(true)
                Slider(value: Binding(get: { Double(player.volume) }, set: { player.volume = Float($0) }), in: 0...1)
                    .controlSize(.small)
                    .help("Change the volume")
                    .accessibilityLabel("Volume")
                Image(systemName: "speaker.wave.3.fill").font(.caption).foregroundStyle(.secondary).accessibilityHidden(true)
            }
            Divider()
            HStack {
                Button("Player") { openWindow(id: "main"); NSApp.activate() }
                Button("Library") { openWindow(id: "library"); NSApp.activate() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .controlSize(.small)
        }
        .padding(Space.lg)
        .frame(width: Layout.popoverWidth)
    }

    private var title: String {
        if let station = player.station { return station.name }
        return player.current?.title ?? String(localized: "Nothing Playing")
    }

    private var subtitle: String {
        if player.isLive { return player.streamTitle ?? player.radioStatus ?? String(localized: "Live") }
        if let track = player.current { return track.artist.isEmpty ? String(localized: "Queue") : track.artist }
        return String(localized: "Open files or pick a station")
    }

    private func button(_ symbol: String, _ label: LocalizedStringKey, queueOnly: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 28, height: 28) } // grid: ok
            .buttonStyle(.borderless)
            .disabled(queueOnly ? !(player.hasTracks && !player.isLive) : !player.canPlay)
            .help(label)
            .accessibilityLabel(label)
    }
}
