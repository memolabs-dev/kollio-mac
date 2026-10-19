import CoreGraphics
import Foundation
import Testing
@testable import KollioApp

/// CAN-02: "select and reach the actions", and the part that was never true.
///
/// The local action cluster used to be placed with a hard-coded width of 300 and a
/// hard-coded height, then clamped. Nothing tested it, because nothing could:
/// the numbers were chosen inside the view, so the view agreed with itself by
/// construction. The consequence was a bar that left the window as soon as its
/// labels were longer than the guess allowed, which in practice meant French.
///
/// These are tests of arithmetic, so they are exact.
@Suite("CAN-02: the local controls stay inside the window")
struct ContextualPlacementTests {
    private let viewport = CGSize(width: 1000, height: 700)
    private let cluster = CGSize(width: 320, height: 52)
    private let inset = ContextualPlacement.viewportInset

    private func fits(_ placement: ContextualPlacement, _ size: CGSize) -> Bool {
        let half = CGSize(width: size.width / 2, height: size.height / 2)
        return placement.point.x - half.width >= inset - 0.001
            && placement.point.x + half.width <= viewport.width - inset + 0.001
            && placement.point.y - half.height >= inset - 0.001
            && placement.point.y + half.height <= viewport.height - inset + 0.001
    }

    @Test("Below the object, when there is room below")
    func prefersBelow() {
        let object = CGRect(x: 400, y: 100, width: 200, height: 60)
        let placement = ContextualPlacement.resolve(object: object, size: cluster, viewport: viewport)

        // Both sides are CGFloat on purpose: the expectation macro compares the
        // expression as written, and a mixed CGFloat/Double comparison is the sort
        // of thing that reports 198.0 == 198.0 as false.
        let expectedY = object.maxY + CGFloat(ContextualPlacement.gap) + 26
        #expect(placement.side == .below)
        #expect(placement.point.x == 500, "it stays on the object's centre line")
        #expect(placement.point.y == expectedY)
    }

    @Test("Above the object, when the object sits at the bottom")
    func fallsBackToAbove() {
        let object = CGRect(x: 400, y: 600, width: 200, height: 60)
        let placement = ContextualPlacement.resolve(object: object, size: cluster, viewport: viewport)

        #expect(placement.side == .above)
        #expect(fits(placement, cluster))
    }

    @Test("A side, when neither vertical side has room")
    func fallsBackToASide() {
        // Tall enough that neither above nor below fits: the object is in the
        // middle of a short window.
        let tall = CGSize(width: 320, height: 200)
        let shortViewport = CGSize(width: 1000, height: 260)
        let object = CGRect(x: 400, y: 100, width: 200, height: 60)
        let placement = ContextualPlacement.resolve(object: object, size: tall, viewport: shortViewport)

        #expect(placement.side == .trailing || placement.side == .leading)
        let half = CGSize(width: tall.width / 2, height: tall.height / 2)
        #expect(
            placement.point.x - half.width >= inset - 0.001
                && placement.point.x + half.width <= shortViewport.width - inset + 0.001
        )
    }

    @Test("A cluster larger than the window is centred, not shoved off one side")
    func centresWhenTheClusterCannotFit() {
        // No clamping can make a 1600-point cluster fit in a 1000-point window.
        // What matters is which way it overflows: centred, both ends are equally
        // out and the object stays under its middle. Clamped to one side, the
        // whole cluster ends up outside, which is the bug this replaced.
        let huge = CGSize(width: 1600, height: 900)
        let object = CGRect(x: 400, y: 300, width: 200, height: 60)
        let placement = ContextualPlacement.resolve(object: object, size: huge, viewport: viewport)

        #expect(placement.side == .below)
        #expect(placement.point.x == CGFloat(viewport.width) / 2)
        #expect(placement.point.y == CGFloat(viewport.height) / 2)
    }

    @Test("An object at the left edge does not push the bar off screen")
    func holdsAtTheLeftEdge() {
        let object = CGRect(x: 0, y: 100, width: 120, height: 60)
        let placement = ContextualPlacement.resolve(object: object, size: cluster, viewport: viewport)

        #expect(placement.point.x - cluster.width / 2 >= inset - 0.001)
    }

    @Test("A longer French label is measured, not assumed")
    func aWiderClusterIsRespected() {
        // « Comparer les directions » is materially wider than « Compare ». Under
        // the old 300-point guess the two were indistinguishable to the layout.
        let object = CGRect(x: 820, y: 100, width: 160, height: 60)
        let french = CGSize(width: 430, height: 52)
        let placement = ContextualPlacement.resolve(object: object, size: french, viewport: viewport)

        #expect(placement.point.x + french.width / 2 <= viewport.width - inset + 0.001)
        // Too wide to sit under the object, so it must have moved off the centre
        // line rather than been clipped.
        #expect(placement.point.x != object.midX)
    }

    @Test("A first pass with no measurement yet is stable and centred")
    func unmeasuredIsStable() {
        let object = CGRect(x: 400, y: 300, width: 200, height: 60)
        let placement = ContextualPlacement.resolve(object: object, size: .zero, viewport: viewport)

        #expect(placement.side == .below)
        #expect(placement.point.x.isFinite && placement.point.y.isFinite)
    }

    @Test("A cluster wider than the window overflows evenly, not to one side")
    func aNarrowViewportDoesNotInvert() {
        // `min(max(value, lower), upper)` with an inverted range returns the lower
        // bound, which put the entire cluster outside a window it was supposed to
        // stay in. Centring is the honest answer: the cluster cannot fit, so both
        // ends overflow by the same amount and the object stays under its middle.
        let object = CGRect(x: 40, y: 300, width: 200, height: 60)
        let narrow = CGSize(width: 300, height: 200)
        let placement = ContextualPlacement.resolve(object: object, size: cluster, viewport: narrow)

        #expect(placement.point.x == CGFloat(narrow.width) / 2)
        let overflowLeft = 0 - (placement.point.x - cluster.width / 2)
        let overflowRight = (placement.point.x + cluster.width / 2) - narrow.width
        #expect(abs(overflowLeft - overflowRight) < 0.001, "the cluster overflows one way only")
    }

    @Test("A tight but sufficient window still contains the cluster")
    func aTightWindowContainsTheCluster() {
        // 360 by 200 holds a 320 by 52 cluster with the 16-point inset intact
        // (320 + 32 = 352), so the centre is clamped rather than centred. 340 was
        // tried first and is 12 points too narrow to honour the inset.
        let object = CGRect(x: 10, y: 90, width: 100, height: 40)
        let tight = CGSize(width: 360, height: 200)
        let placement = ContextualPlacement.resolve(object: object, size: cluster, viewport: tight)

        #expect(placement.point.x - cluster.width / 2 >= inset - 0.001)
        #expect(placement.point.x + cluster.width / 2 <= tight.width - inset + 0.001)
        #expect(placement.point.y - cluster.height / 2 >= inset - 0.001)
        #expect(placement.point.y + cluster.height / 2 <= tight.height - inset + 0.001)
    }
}
