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
    /// Docked windows, attached as child windows of the dragged one while the drag lasts.
    /// AppKit moves children together with the parent in the same frame, with no lag.
    private var group: [NSWindow] = []
    private weak var dragged: NSWindow?
    private var mouseUpMonitor: Any?
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
        center.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if let w = box.value { self?.didResize(w) } }
        }
        center.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let w = box.value else { return }
                if w.title == "Equalizer" { self?.closeGap(left: w) }
                self?.windows.removeAll { $0 === w }
            }
        }
    }

    /// Lets notification closures refer to a window without owning it.
    private final class WeakWindow: @unchecked Sendable {
        weak var value: NSWindow?
        init(_ window: NSWindow) { value = window }
    }

    func window(titled title: String) -> NSWindow? { windows.first { $0.title == title } }

    /// Windows (the Library) docked under `upper`, other than `except`.
    private func windowsDocked(below upper: NSWindow, except: NSWindow) -> [NSWindow] {
        windows.filter {
            $0 !== upper && $0 !== except && $0.isVisible
                && abs($0.frame.maxY - upper.frame.minY) <= 1
                && $0.frame.minX < upper.frame.maxX && $0.frame.maxX > upper.frame.minX
        }
    }

    /// The equalizer is about to sit under the player: whatever was docked there moves down, under it.
    func makeRoom(below player: NSWindow, for equalizer: NSWindow) {
        for other in windowsDocked(below: player, except: equalizer) {
            other.setFrameOrigin(NSPoint(x: other.frame.origin.x, y: other.frame.origin.y - equalizer.frame.height))
        }
    }

    /// The equalizer closed: whatever was docked under it moves up, under the player.
    private func closeGap(left equalizer: NSWindow) {
        // Only when the equalizer sits right under the player.
        guard let player = window(titled: "MacAmp"), abs(equalizer.frame.maxY - player.frame.minY) <= 1 else { return }
        for other in windowsDocked(below: equalizer, except: equalizer) {
            other.setFrameOrigin(NSPoint(x: other.frame.origin.x, y: other.frame.origin.y + equalizer.frame.height))
        }
    }

    /// Resizing the player or the equalizer gives the other the same width while they are stacked.
    private func didResize(_ window: NSWindow) {
        guard !adjusting, window.title == "MacAmp" || window.title == "Equalizer" else { return }
        let partnerTitle = window.title == "MacAmp" ? "Equalizer" : "MacAmp"
        guard let partner = self.window(titled: partnerTitle), partner.isVisible,
              abs(partner.frame.minX - window.frame.minX) <= 1,
              abs(partner.frame.maxY - window.frame.minY) <= 1 || abs(window.frame.maxY - partner.frame.minY) <= 1,
              abs(partner.frame.width - window.frame.width) > 0.5 else { return }
        adjusting = true
        defer { adjusting = false }
        var frame = partner.frame
        frame.size.width = window.frame.width
        partner.setFrame(frame, display: true)
    }

    private func willMove(_ window: NSWindow) {
        endDrag()
        let docked = windows.filter { $0 !== window && $0.isVisible && WindowSnap.areDocked(window.frame, $0.frame) }
        for other in docked { window.addChildWindow(other, ordered: .above) }
        group = docked
        dragged = window
        if mouseUpMonitor == nil {
            mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
                MainActor.assumeIsolated { self?.endDrag() }
                return event
            }
        }
    }

    /// The mouse button went up: the windows stay where they are, but move on their own again.
    private func endDrag() {
        if let dragged { for other in group { dragged.removeChildWindow(other) } }
        group = []
        dragged = nil
        if let monitor = mouseUpMonitor { NSEvent.removeMonitor(monitor); mouseUpMonitor = nil }
    }

    private func didMove(_ window: NSWindow) {
        guard !adjusting, window === dragged else { return }
        adjusting = true
        defer { adjusting = false }
        // Snap to a window that is not already moving with this one.
        let others = windows.filter { $0 !== window && $0.isVisible && !group.contains($0) }.map(\.frame)
        let snap = WindowSnap.offset(for: window.frame, to: others, distance: Layout.snapDistance) // grid: ok
        if snap != .zero {
            window.setFrameOrigin(NSPoint(x: window.frame.origin.x + snap.x, y: window.frame.origin.y + snap.y))
        }
    }
}
