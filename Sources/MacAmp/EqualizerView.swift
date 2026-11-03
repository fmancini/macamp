import MacAmpKit
import SwiftUI

/// The equalizer window: a preamp and 10 bands, with presets.
struct EqualizerView: View {
    @Environment(Player.self) private var player
    private var theme = PlayerThemeStore.shared

    private let labels = ["60", "170", "310", "600", "1K", "3K", "6K", "12K", "14K", "16K"]

    var body: some View {
        @Bindable var eq = player.equalizer
        VStack(spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                Toggle("On", isOn: $eq.state.enabled)
                    .toggleStyle(.checkbox)
                    .help("Turn the equalizer on or off")
                Spacer()
                Menu(eq.state.matchingPreset?.name ?? String(localized: "Custom")) {
                    ForEach(EqualizerPreset.all) { preset in
                        Button(preset.name) { eq.state.apply(preset) }
                    }
                }
                .menuStyle(.button)
                .controlSize(.small)
                .fixedSize()
                .help("Choose a preset")
                Button("Reset") { eq.state.apply(EqualizerPreset.all[0]) }
                    .controlSize(.small)
                    .help("Set every band to 0 dB")
            }
            HStack(alignment: .top, spacing: Space.xs) {
                column(title: "Pre", gain: $eq.state.preamp, name: "Preamp")
                Divider().frame(height: 116) // grid: ok
                ForEach(0..<10, id: \.self) { index in
                    column(title: labels[index],
                           gain: Binding(get: { eq.state.bands[index] }, set: { eq.state.setBand(index, to: $0) }),
                           name: "\(labels[index]) hertz")
                }
            }
            .padding(Space.sm)
            .background(Surface.display, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .opacity(eq.state.enabled ? 1 : 0.5)
            if player.avPlayer != nil {
                Text("The equalizer does not apply to this stream.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(Space.md)
        .fixedSize(horizontal: false, vertical: true) // height follows the content; only the width is free
        .frame(minWidth: Layout.equalizerWidth, maxWidth: Layout.maxPlayerWidth)
        .background(Surface.playerBody)
        .noInitialFocus()
        .background(WindowAccessor { window in
            WindowSnapper.shared.register(window)
            // First time on screen: dock under the player.
            if let player = WindowSnapper.shared.window(titled: "MacAmp") {
                WindowSnapper.shared.makeRoom(below: player, for: window)
                window.setFrameTopLeftPoint(NSPoint(x: player.frame.minX, y: player.frame.minY))
            }
        })
    }

    private func column(title: String, gain: Binding<Float>, name: LocalizedStringKey) -> some View {
        VStack(spacing: Space.xs) {
            Slider(value: gain, in: EqualizerState.range, step: 0.5)
                .controlSize(.mini)
                .frame(width: 96) // grid: ok
                .rotationEffect(.degrees(-90))
                .frame(width: 20, height: 96) // grid: ok
                .accessibilityLabel(name)
                .accessibilityValue("\(gain.wrappedValue, specifier: "%.1f") decibels")
                .help("\(name): \(gain.wrappedValue, specifier: "%+.1f") dB")
            Text(title)
                .font(.system(size: 10, design: .monospaced)) // grid: ok
                .foregroundStyle(Surface.readoutDim)
        }
        .frame(maxWidth: .infinity)
    }
}
