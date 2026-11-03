import SwiftUI

/// The live spectrum in the player display: 20 bars that rise at once and fall slowly.
struct SpectrumView: View {
    @Environment(Player.self) private var player
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var smoother = Smoother()

    private static let demo: [Float] = (0..<20).map { Float(0.25 + 0.6 * abs(sin(Double($0) * 0.55))) }

    var body: some View {
        let live = player.isPlaying && !reduceMotion && player.avPlayer == nil
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live)) { _ in
            Canvas { context, size in
                let source: [Float]
                if ProcessInfo.processInfo.environment["APP_SNAPSHOT"] != nil {
                    source = Self.demo
                } else {
                    source = live ? player.spectrum.bars : [Float](repeating: 0, count: 20)
                }
                let levels = smoother.update(source)
                let count = levels.count
                let gap: CGFloat = 2
                let width = (size.width - gap * CGFloat(count - 1)) / CGFloat(count)
                for (index, level) in levels.enumerated() {
                    let height = max(2, size.height * CGFloat(level))
                    let rect = CGRect(x: CGFloat(index) * (width + gap), y: size.height - height, width: width, height: height)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(Surface.readout))
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// Keeps the last levels, so bars fall instead of dropping.
    final class Smoother {
        private var levels = [Float](repeating: 0, count: 20)

        func update(_ new: [Float]) -> [Float] {
            for i in 0..<min(new.count, levels.count) {
                levels[i] = new[i] > levels[i] ? new[i] : max(new[i], levels[i] - 0.06)
            }
            return levels
        }
    }
}
