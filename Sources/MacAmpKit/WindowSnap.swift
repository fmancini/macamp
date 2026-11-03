import CoreGraphics

/// Snapping for the player windows: when a window is dragged near another
/// one, it jumps so the edges touch. Pure geometry, so tests can run it.
public enum WindowSnap {
    /// How far to move `frame` so it docks to the nearest of `others`
    /// (within `distance` points), or `.zero` when none is close.
    public static func offset(for frame: CGRect, to others: [CGRect], distance: CGFloat) -> CGPoint {
        var bestX: CGFloat?, bestY: CGFloat?
        for other in others {
            // Only snap sideways when the windows overlap vertically (or nearly), and the reverse.
            let overlapsVertically = frame.minY < other.maxY + distance && frame.maxY > other.minY - distance
            let overlapsHorizontally = frame.minX < other.maxX + distance && frame.maxX > other.minX - distance
            if overlapsVertically {
                for delta in [other.maxX - frame.minX, other.minX - frame.maxX, other.minX - frame.minX, other.maxX - frame.maxX]
                where abs(delta) <= distance && abs(delta) < abs(bestX ?? .infinity) {
                    bestX = delta
                }
            }
            if overlapsHorizontally {
                for delta in [other.maxY - frame.minY, other.minY - frame.maxY, other.minY - frame.minY, other.maxY - frame.maxY]
                where abs(delta) <= distance && abs(delta) < abs(bestY ?? .infinity) {
                    bestY = delta
                }
            }
        }
        return CGPoint(x: bestX ?? 0, y: bestY ?? 0)
    }

    /// True when two frames touch along an edge (within a point), so they move together.
    public static func areDocked(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 1) -> Bool {
        let sideBySide = abs(a.maxX - b.minX) <= tolerance || abs(b.maxX - a.minX) <= tolerance
        let stacked = abs(a.maxY - b.minY) <= tolerance || abs(b.maxY - a.minY) <= tolerance
        let overlapsY = a.minY < b.maxY - tolerance && a.maxY > b.minY + tolerance
        let overlapsX = a.minX < b.maxX - tolerance && a.maxX > b.minX + tolerance
        return (sideBySide && overlapsY) || (stacked && overlapsX)
    }
}
