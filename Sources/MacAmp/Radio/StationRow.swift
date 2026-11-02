import MacAmpKit
import SwiftUI

/// One station in a list: play on double click, a star to keep it.
struct StationRow: View {
    let station: Station
    let isCurrent: Bool
    let isPlaying: Bool
    let isFavorite: Bool
    let toggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: Space.md) {
            Image(systemName: isCurrent ? (isPlaying ? "speaker.wave.2.fill" : "speaker.fill") : "dot.radiowaves.left.and.right")
                .foregroundStyle(isCurrent ? Palette.accentText : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 0) {
                Text(station.name).lineLimit(1)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: Space.sm)
            Button(action: toggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? Palette.accentText : .secondary)
            }
            .buttonStyle(.borderless)
            .help(isFavorite ? "Remove from Favorites" : "Add to Favorites")
            .accessibilityLabel(isFavorite ? "Remove from Favorites" : "Add to Favorites")
        }
        .accessibilityElement(children: .contain)
    }

    private var detail: String {
        var parts: [String] = []
        if !station.country.isEmpty { parts.append(station.country) }
        if !station.codec.isEmpty { parts.append(station.codec) }
        if station.bitrate > 0 { parts.append("\(station.bitrate) kbps") }
        return parts.joined(separator: " \u{2022} ")
    }
}
