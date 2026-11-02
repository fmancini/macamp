import CoreGraphics

/// Corner radii. Inner radius = outer radius - inset (concentric).
enum Radius {
    /// Chips and key caps.
    static let xs: CGFloat = 6
    /// Controls, the display inset.
    static let sm: CGFloat = 8
    /// Row hover fills.
    static let row: CGFloat = 10
    /// Cards.
    static let md: CGFloat = 12
    /// Widgets, the menu bar popover.
    static let lg: CGFloat = 18
    /// Floating glass.
    static let xl: CGFloat = 26
}
