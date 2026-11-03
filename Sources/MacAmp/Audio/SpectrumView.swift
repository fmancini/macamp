import SwiftUI

/// The live spectrum in the player display: 20 bars, drawn 60 times a second, that rise fast and fall slowly.
struct SpectrumView: View {
    @Environment(Player.self) private var player
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var smoother = Smoother()

    private static let demo: [Float] = (0..<20).map { Float(0.25 + 0.6 * abs(sin(Double($0) * 0.55))) }

    var body: some View {
        let live = player.isPlaying && !reduceMotion && player.avPlayer == nil
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !live)) { timeline in
            // The Canvas must read the timeline date, or SwiftUI sees the same
            // drawing and skips the redraw (the bars then move only when
            // something else invalidates the view).
            let now = timeline.date
            Canvas { context, size in
                _ = now
                let source: [Float]
                if ProcessInfo.processInfo.environment["APP_SNAPSHOT"] != nil, player.hasTracks {
                    source = Self.demo
                } else {
                    source = live ? player.spectrum.bars : [Float](repeating: 0, count: 20)
                }
                if Self.debug { Self.count() }
                let (levels, peaks) = smoother.update(source, at: now)
                let count = levels.count
                let gap: CGFloat = 2
                let width = (size.width - gap * CGFloat(count - 1)) / CGFloat(count)
                for (index, level) in levels.enumerated() {
                    let height = max(2, size.height * CGFloat(level))
                    let rect = CGRect(x: CGFloat(index) * (width + gap), y: size.height - height, width: width, height: height)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(Surface.readout))
                    // The peak cap: a thin mark that hangs above the bar and falls slowly.
                    let capY = size.height - max(2, size.height * CGFloat(peaks[index])) - 3
                    if peaks[index] > 0.04, capY > 0 {
                        context.fill(Path(CGRect(x: rect.minX, y: capY, width: width, height: 2)), with: .color(Surface.readoutDim))
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// APP_SPECTRUM_DEBUG=1 prints how many times the bars are drawn per second.
    private static let debug = ProcessInfo.processInfo.environment["APP_SPECTRUM_DEBUG"] == "1"
    nonisolated(unsafe) private static var draws = 0
    nonisolated(unsafe) private static var since = Date.now
    private static func count() {
        draws += 1
        if Date.now.timeIntervalSince(since) >= 1 {
            FileHandle.standardError.write(Data("SPECTRUM draws/s \(draws)\n".utf8))
            draws = 0
            since = .now
        }
    }

    /// Moves each bar toward its new level with a spring, and keeps a peak cap
    /// that hangs a moment and then falls. Bars rise fast and fall slower.
    final class Smoother {
        private var levels = [Double](repeating: 0, count: 20)
        private var velocities = [Double](repeating: 0, count: 20)
        private var peaks = [Double](repeating: 0, count: 20)
        private var holds = [Double](repeating: 0, count: 20)
        private var lastTime: Date?
        private let rise = Spring(duration: 0.07, bounce: 0.1)
        private let fall = Spring(duration: 0.22, bounce: 0)

        /// Returns the levels and peak caps (0...1) for the time `now`.
        func update(_ target: [Float], at now: Date) -> (levels: [Double], peaks: [Double]) {
            let dt = min(max(now.timeIntervalSince(lastTime ?? now), 1.0 / 240), 0.1)
            lastTime = now
            for i in 0..<min(target.count, levels.count) {
                let goal = Double(target[i])
                let spring = goal > levels[i] ? rise : fall
                spring.update(value: &levels[i], velocity: &velocities[i], target: goal, deltaTime: dt)
                levels[i] = min(max(levels[i], 0), 1)
                if levels[i] >= peaks[i] {
                    peaks[i] = levels[i]
                    holds[i] = 0.35
                } else if holds[i] > 0 {
                    holds[i] -= dt
                } else {
                    peaks[i] = max(levels[i], peaks[i] - 0.9 * dt)
                }
            }
            return (levels, peaks)
        }
    }
}
