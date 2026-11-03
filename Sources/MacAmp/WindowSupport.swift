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

    /// The player changed between full and windowshade: the window takes the height of its
    /// content again (the top edge stays), and windows docked below it follow.
    func fitHeight(of window: NSWindow) {
        guard let content = window.contentView else { return }
        let target = window.frameRect(forContentRect: NSRect(origin: .zero, size: NSSize(width: window.contentLayoutRect.width, height: content.fittingSize.height))).height
        let delta = target - window.frame.height
        guard abs(delta) > 0.5 else { return }
        // Collect what is stacked under the window before it changes.
        var below: [NSWindow] = []
        var frontier = [window]
        while let upper = frontier.popLast() {
            for other in windowsDocked(below: upper, except: upper) where !below.contains(other) {
                below.append(other)
                frontier.append(other)
            }
        }
        adjusting = true
        defer { adjusting = false }
        var frame = window.frame
        frame.origin.y -= delta
        frame.size.height = target
        window.setFrame(frame, display: true, animate: false)
        for other in below {
            other.setFrameOrigin(NSPoint(x: other.frame.origin.x, y: other.frame.origin.y - delta))
        }
    }

    /// Pulls apart every window that touches another one: each moves away from the one it
    /// was docked to, by more than the snap distance, so they stay separate.
    func detachAll() {
        let gap: CGFloat = 16 // grid: ok
        var offsets: [ObjectIdentifier: CGPoint] = [:]
        var visited: [NSWindow] = []
        for start in windows where start.isVisible && !visited.contains(start) {
            var frontier = [start]
            visited.append(start)
            offsets[ObjectIdentifier(start)] = .zero
            while let parent = frontier.popLast() {
                let base = offsets[ObjectIdentifier(parent)] ?? .zero
                for other in windows where other.isVisible && !visited.contains(other)
                    && WindowSnap.areDocked(parent.frame, other.frame) {
                    var step = CGPoint.zero
                    let p = parent.frame, o = other.frame
                    if abs(o.maxY - p.minY) <= 1 { step.y = -gap }
                    else if abs(p.maxY - o.minY) <= 1 { step.y = gap }
                    else if abs(o.minX - p.maxX) <= 1 { step.x = gap }
                    else { step.x = -gap }
                    offsets[ObjectIdentifier(other)] = CGPoint(x: base.x + step.x, y: base.y + step.y)
                    visited.append(other)
                    frontier.append(other)
                }
            }
        }
        for window in windows {
            guard let offset = offsets[ObjectIdentifier(window)], offset != .zero else { continue }
            window.setFrameOrigin(NSPoint(x: window.frame.origin.x + offset.x, y: window.frame.origin.y + offset.y))
        }
    }

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
        // The equalizer takes the width of the player.
        if abs(equalizer.frame.width - player.frame.width) > 0.5 {
            adjusting = true
            var frame = equalizer.frame
            frame.size.width = player.frame.width
            equalizer.setFrame(frame, display: true)
            adjusting = false
        }
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
        // Everything connected by touching edges moves, even through other windows
        // (player, equalizer, then Library).
        var docked: [NSWindow] = []
        var frontier = [window]
        while let current = frontier.popLast() {
            for other in windows where other !== window && other.isVisible && !docked.contains(other)
                && WindowSnap.areDocked(current.frame, other.frame) {
                docked.append(other)
                frontier.append(other)
            }
        }
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
