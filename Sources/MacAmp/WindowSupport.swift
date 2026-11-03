import AppKit
import MacAmpKit
import SwiftUI

/// Gives a SwiftUI view its NSWindow.
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { if let window = view.window { onWindow(window) } }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}

/// Makes the player windows (player and equalizer) snap together, and move
/// together while they touch. The geometry is `WindowSnap` in MacAmpKit.
@MainActor
final class WindowSnapper {
    static let shared = WindowSnapper()

    private var windows: [NSWindow] = []
    /// Windows that move with the dragged one, with their offset from it at the start of the drag.
    private var group: [(window: NSWindow, offset: NSPoint)] = []
    private var adjusting = false

    func register(_ window: NSWindow) {
        guard !windows.contains(window) else { return }
        windows.append(window)
        let center = NotificationCenter.default
        let box = WeakWindow(window)
        center.addObserver(forName: NSWindow.willMoveNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if let w = box.value { self?.willMove(w) } }
        }
        center.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if let w = box.value { self?.didMove(w) } }
        }
        center.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if let w = box.value { self?.windows.removeAll { $0 === w } } }
        }
    }

    /// Lets notification closures refer to a window without owning it.
    private final class WeakWindow: @unchecked Sendable {
        weak var value: NSWindow?
        init(_ window: NSWindow) { value = window }
    }

    func window(titled title: String) -> NSWindow? { windows.first { $0.title == title } }

    private func willMove(_ window: NSWindow) {
        group = windows
            .filter { $0 !== window && $0.isVisible && WindowSnap.areDocked(window.frame, $0.frame) }
            .map { ($0, NSPoint(x: $0.frame.origin.x - window.frame.origin.x, y: $0.frame.origin.y - window.frame.origin.y)) }
    }

    private func didMove(_ window: NSWindow) {
        guard !adjusting else { return }
        adjusting = true
        defer { adjusting = false }
        // Snap to a window that is not already moving with this one.
        let moving = group.map(\.window)
        let others = windows.filter { $0 !== window && $0.isVisible && !moving.contains($0) }.map(\.frame)
        let snap = WindowSnap.offset(for: window.frame, to: others, distance: Layout.snapDistance) // grid: ok
        if snap != .zero {
            window.setFrameOrigin(NSPoint(x: window.frame.origin.x + snap.x, y: window.frame.origin.y + snap.y))
        }
        // The system places the dragged window from the mouse, ignoring our snap, so the
        // others are placed from its final position: they never drift apart.
        for (docked, offset) in group {
            docked.setFrameOrigin(NSPoint(x: window.frame.origin.x + offset.x, y: window.frame.origin.y + offset.y))
        }
    }
}
