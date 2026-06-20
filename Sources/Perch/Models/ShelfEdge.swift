import CoreGraphics
import Foundation

/// Which screen edge the shelf docks to. The shelf is a vertical strip, so only
/// the left and right edges are meaningful (matching the genre's convention).
enum ShelfEdge: String, CaseIterable, Codable, Sendable, Identifiable {
    case left
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .left: return "左端"
        case .right: return "右端"
        }
    }

    /// The frame for a docked shelf of `size`, vertically centred on `screen`
    /// with a small gap from the physical edge.
    func shelfFrame(size: CGSize, on screen: CGRect, gap: CGFloat) -> CGRect {
        let y = screen.midY - size.height / 2
        switch self {
        case .left:
            return CGRect(x: screen.minX + gap, y: y, width: size.width, height: size.height)
        case .right:
            return CGRect(x: screen.maxX - size.width - gap, y: y, width: size.width, height: size.height)
        }
    }

    /// The off-screen frame the shelf animates from/to when hiding, so it slides
    /// out past the edge rather than just fading.
    func hiddenFrame(size: CGSize, on screen: CGRect) -> CGRect {
        let y = screen.midY - size.height / 2
        switch self {
        case .left:
            return CGRect(x: screen.minX - size.width, y: y, width: size.width, height: size.height)
        case .right:
            return CGRect(x: screen.maxX, y: y, width: size.width, height: size.height)
        }
    }
}
