import SwiftUI

/// Every animation goes through here, so Reduce Motion applies everywhere.
enum Motion {
    static let hover = Animation.easeOut(duration: 0.12)
    static let quick = Animation.easeOut(duration: 0.15)
    static let ui = Animation.easeInOut(duration: 0.25)
    static let select = Animation.easeOut(duration: 0.1)
    static let appear = Animation.easeOut(duration: 0.2)
    static let dismiss = Animation.easeIn(duration: 0.15)
    static let listChange = Animation.easeInOut(duration: 0.2)
    /// Spectrum smoothing: bars fall slowly, rise at once.
    static let spectrumFall = Animation.easeOut(duration: 0.18)
}

extension View {
    /// `animation` that turns into no animation under Reduce Motion.
    func motionSafe<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(MotionSafe(animation: animation, value: value))
    }
}

private struct MotionSafe<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}
