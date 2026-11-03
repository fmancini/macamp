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
    private var group: [NSWindow] = []
    private var lastOrigin = NSPoint.zero
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
        lastOrigin = window.frame.origin
        group = windows.filter { $0 !== window && $0.isVisible && WindowSnap.areDocked(window.frame, $0.frame) }
    }

    private func didMove(_ window: NSWindow) {
        guard !adjusting else { return }
        adjusting = true
        defer { adjusting = false }
        var delta = NSPoint(x: window.frame.origin.x - lastOrigin.x, y: window.frame.origin.y - lastOrigin.y)
        // Snap to a window that is not already moving with this one.
        let others = windows.filter { $0 !== window && $0.isVisible && !group.contains($0) }.map(\.frame)
        let snap = WindowSnap.offset(for: window.frame, to: others, distance: Layout.snapDistance) // grid: ok
        if snap != .zero {
            window.setFrameOrigin(NSPoint(x: window.frame.origin.x + snap.x, y: window.frame.origin.y + snap.y))
            delta.x += snap.x
            delta.y += snap.y
        }
        for docked in group {
            docked.setFrameOrigin(NSPoint(x: docked.frame.origin.x + delta.x, y: docked.frame.origin.y + delta.y))
        }
        lastOrigin = window.frame.origin
    }
}
