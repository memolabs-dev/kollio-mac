import CoreGraphics
import Foundation
import KollioCore

/// The ground the document stands on.
///
/// A spatial surface has a problem a page does not: zoomed in, space loses its
/// landmarks; zoomed out, the landmarks drown. The ground is what answers, and
/// it answers by moving and scaling with the *world*, not the screen — because
/// its whole job is making zoom and pan legible. A fixed backdrop is wallpaper,
/// and wallpaper cannot tell a person where they are.
///
/// The decisions, held as rules rather than taste:
///
/// - **Points, not lines.** Lines cut space into corridors and imply a table.
///   Points hold the space open without carving it.
/// - **One minor step, one major step.** The major step is the minor one taken
///   in larger strides — not a second grid, because a third scale would tell a
///   person nothing they can act on.
/// - **The screen spacing stays in a band.** Dots closer than the band are
///   texture, then noise; further than the band the ground has receded into
///   nothing. One rule decides everything, including silence: when even the
///   major stride would land below the band, there is nothing honest left to
///   draw, and the ground stops.
/// - **Never silent inside the camera's reach.** The camera's floor keeps the
///   major stride inside the band, so a fully zoomed-out document keeps a
///   ground — that is where a person is most lost, and the ground does not
///   abandon them there.
public enum CanvasGround {
    /// World distance between dots of the minor step.
    public static let minorWorldStep: Double = 24
    /// How many minor strides one major stride spans.
    public static let majorStepMultiple: Double = 5
    /// The screen band inside which a dot grid is present rather than noise.
    public static let screenBand = ClosedRange(uncheckedBounds: (9.0, 72.0))

    /// The chosen scale, decided purely from a camera zoom.
    public struct Scale: Equatable, Sendable {
        /// World distance between the dots that will be drawn.
        public let worldStep: Double
        /// The same distance on screen, `worldStep * zoom`.
        public let screenStep: Double
        /// True when the drawn dots are the major stride, drawn as emphasis.
        public let isMajor: Bool
        /// True when nothing is drawn. The values and the decision stay together.
        public let isSilent: Bool

        public var draws: Bool { !isSilent }

        public static let silent = Scale(worldStep: 0, screenStep: 0, isMajor: false, isSilent: true)
    }

    public static func scale(zoom: Double) -> Scale {
        // No viewer: no zoom, no ground. Every real camera zoom is past this.
        guard zoom > 0, zoom.isFinite else { return .silent }

        let minorScreen = minorWorldStep * zoom
        if screenBand.contains(minorScreen) {
            return Scale(
                worldStep: minorWorldStep,
                screenStep: minorScreen,
                isMajor: false,
                isSilent: false
            )
        }
        // Minor would draw as grain: climb one stride, once. If even the major
        // stride is outside the band, the ground has nothing to say and stops.
        let majorScreen = minorScreen * majorStepMultiple
        if screenBand.contains(majorScreen) {
            return Scale(
                worldStep: minorWorldStep * majorStepMultiple,
                screenStep: majorScreen,
                isMajor: true,
                isSilent: false
            )
        }
        return .silent
    }
}
