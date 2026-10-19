import CoreGraphics
import Foundation

/// Where a local control cluster goes, given where its object is and how big the
/// cluster actually turned out to be.
///
/// This is arithmetic on purpose. The alternative was a view that guessed: it
/// assumed a width of 300 and a height of 52, then clamped. That guess was wrong
/// the moment a label was translated — « Comparer les directions » is wider than
/// « Compare » — and it had no way to notice, because it never asked. A wrong
/// guess here is not a slightly ugly bar, it is a bar half outside the window.
///
/// So the caller measures the rendered cluster and passes the real size in, and
/// this type decides. Nothing here reads a font, a locale or a view, which is
/// also why it can be tested without a window.
public struct ContextualPlacement: Equatable, Sendable {
    /// Which side of the object the cluster settled on.
    public enum Side: String, Sendable, Equatable {
        case below
        case above
        case trailing
        case leading

        /// For tests and for the log a person reads when a bar lands oddly.
        public var isVertical: Bool { self == .below || self == .above }
    }

    public let point: CGPoint
    public let side: Side

    public init(point: CGPoint, side: Side) {
        self.point = point
        self.side = side
    }

    /// The gap between the object and the cluster, in points.
    public static let gap: Double = 12

    /// The distance kept between the cluster and the window edge.
    ///
    /// Not zero: a bar flush against the window edge reads as clipped even when
    /// nothing is clipped, and the rounded corner needs somewhere to sit.
    public static let viewportInset: Double = 16

    /// Resolve the position of a cluster of `size` attached to `object`.
    ///
    /// - Parameters:
    ///   - object: the object's frame in screen space.
    ///   - size: the cluster's **measured** size in screen space.
    ///   - viewport: the visible canvas, in screen space.
    ///
    /// The order is the one the design fixes: below first, because an action
    /// under its object is the one nobody has to look for; above if below is
    /// taken; then the sides, because a bar beside the object is worse than a bar
    /// above it but better than a bar off the screen. If every side collides,
    /// the cluster is clamped into the viewport and stays below, because a bar
    /// that covers its own object is the one outcome worth avoiding last.
    public static func resolve(
        object: CGRect,
        size: CGSize,
        viewport: CGSize
    ) -> ContextualPlacement {
        let half = CGSize(width: size.width / 2, height: size.height / 2)

        // A cluster with no measured size yet. Centring on the anchor is wrong
        // but it is stable, and the next pass corrects it.
        guard size.width > 0, size.height > 0 else {
            return ContextualPlacement(
                point: inside(
                    CGPoint(x: object.midX, y: object.maxY + gap + half.height),
                    half: half,
                    viewport: viewport
                ),
                side: .below
            )
        }

        let below = CGPoint(x: object.midX, y: object.maxY + gap + half.height)
        if fits(below, half: half, viewport: viewport) {
            return ContextualPlacement(point: below, side: .below)
        }

        let above = CGPoint(x: object.midX, y: object.minY - gap - half.height)
        if fits(above, half: half, viewport: viewport) {
            return ContextualPlacement(point: above, side: .above)
        }

        let trailing = CGPoint(x: object.maxX + gap + half.width, y: object.midY)
        if fits(trailing, half: half, viewport: viewport) {
            return ContextualPlacement(point: trailing, side: .trailing)
        }

        let leading = CGPoint(x: object.minX - gap - half.width, y: object.midY)
        if fits(leading, half: half, viewport: viewport) {
            return ContextualPlacement(point: leading, side: .leading)
        }

        // Nothing fits. Stay below and put the cluster as far inside as it can
        // go. A cluster larger than the window is centred rather than shoved
        // against one edge, because the two overflows are then equal and the
        // object it belongs to is still under its middle.
        return ContextualPlacement(
            point: inside(below, half: half, viewport: viewport),
            side: .below
        )
    }

    private static func fits(_ point: CGPoint, half: CGSize, viewport: CGSize) -> Bool {
        point.x - half.width >= viewportInset
        && point.x + half.width <= viewport.width - viewportInset
        && point.y - half.height >= viewportInset
        && point.y + half.height <= viewport.height - viewportInset
    }

    /// Clamps a centre into the viewport.
    ///
    /// When the cluster is wider than the viewport there is no centre that fits,
    /// and the range inverts. Clamping an inverted range returns its lower bound,
    /// which pushes the whole cluster off one side; centring it on the viewport is
    /// the only answer that does not lie about where the middle is.
    private static func inside(_ point: CGPoint, half: CGSize, viewport: CGSize) -> CGPoint {
        let minX = half.width + viewportInset
        let maxX = viewport.width - half.width - viewportInset
        let minY = half.height + viewportInset
        let maxY = viewport.height - half.height - viewportInset
        return CGPoint(
            x: maxX > minX ? min(max(point.x, minX), maxX) : viewport.width / 2,
            y: maxY > minY ? min(max(point.y, minY), maxY) : viewport.height / 2
        )
    }
}
