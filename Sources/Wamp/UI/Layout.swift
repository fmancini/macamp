import CoreGraphics

/// Fixed sizes. All on the 4 pt grid.
enum Layout {
    /// Main player window width and height.
    static let playerWidth: CGFloat = 320
    static let playerHeight: CGFloat = 148
    /// Equalizer window width; the queue window matches the player width.
    static let equalizerWidth: CGFloat = 320
    /// Windowshade bar height.
    static let shadeHeight: CGFloat = 24
    /// Snap distance when windows meet.
    static let snapDistance: CGFloat = 8
    /// Library sidebar width range.
    static let sidebarMin: CGFloat = 180
    static let sidebarIdeal: CGFloat = 220
    /// Menu bar popover width.
    static let popoverWidth: CGFloat = 280
}
