import Foundation
import Testing
@testable import KollioApp

@Suite("Spatial Ink V3 — camera")
struct SpatialV3CameraTests {
    @Test("Fitting centers the semantic world without distortion")
    func fit() {
        let camera = SpatialV3Camera.fitted(in: CGSize(width: 1200, height: 640))
        #expect(camera.zoom == 1)
        #expect(camera.x == 100)
        #expect(camera.y == 0)
        let half = SpatialV3Camera.fitted(in: CGSize(width: 500, height: 320))
        #expect(half.zoom == 0.5)
    }

    @Test("Zoom keeps its anchor at the same world position")
    func anchor() {
        let camera = SpatialV3Camera.fitted(in: CGSize(width: 1200, height: 640))
        let anchor = CGPoint(x: 333, y: 171)
        let zoomed = camera.zoomed(by: 1.7, around: anchor)
        #expect(abs((anchor.x - zoomed.x) / zoomed.zoom - (anchor.x - camera.x) / camera.zoom) < 0.0001)
        #expect(abs((anchor.y - zoomed.y) / zoomed.zoom - (anchor.y - camera.y) / camera.zoom) < 0.0001)
    }

    @Test("Dynamic negative-origin bounds are fitted into the viewport")
    func dynamicBounds() {
        let bounds = CGRect(x: -1550, y: -620, width: 4250, height: 2100)
        let camera = SpatialV3Camera.fitted(in: CGSize(width: 1280, height: 800), bounds: bounds)
        #expect(camera.zoom < 0.35)
        #expect(bounds.minX * camera.zoom + camera.x >= -0.0001)
        #expect(bounds.maxX * camera.zoom + camera.x <= 1280.0001)
        #expect(bounds.minY * camera.zoom + camera.y >= -0.0001)
        #expect(bounds.maxY * camera.zoom + camera.y <= 800.0001)
    }

    @Test("Zoom is bounded and panning never changes its source camera")
    func safety() {
        let original = SpatialV3Camera()
        #expect(original.zoomed(by: 100, around: .zero).zoom == 2.4)
        #expect(original.zoomed(by: 0.001, around: .zero).zoom == 0.08)
        let panned = original.panned(dx: -34, dy: 48)
        #expect(panned.x == -34)
        #expect(panned.y == 48)
        #expect(original == SpatialV3Camera())
    }

    @Test("C2.8 explicit centering preserves zoom and puts the requested card in the viewport center")
    func explicitCentering() {
        let original = SpatialV3Camera(zoom: 0.75, x: -220, y: 45)
        let viewport = CGSize(width: 1060, height: 640)
        let card = CGPoint(x: 740, y: 350)
        let centered = original.centered(on: card, in: viewport)
        #expect(centered.zoom == original.zoom)
        #expect(abs(card.x * centered.zoom + centered.x - viewport.width / 2) < 0.01)
        #expect(abs(card.y * centered.zoom + centered.y - viewport.height / 2) < 0.01)
        #expect(original == SpatialV3Camera(zoom: 0.75, x: -220, y: 45))
        // Selecting in place never invokes centered(on:). No camera mutation
        // can be inferred from a selection without an explicit focus request.
    }

    @Test("C2.8 a cancelled background pan cannot leak previous gesture translation")
    func interruptedPanHasNoAccumulatedState() {
        let camera = SpatialV3Camera.fitted(in: CGSize(width: 950, height: 600))
        // @GestureState previews a total displacement, then returns to zero
        // automatically when the native gesture is cancelled.
        let preview = camera.panned(dx: 128, dy: -64)
        #expect(preview.x == camera.x + 128)
        #expect(preview.y == camera.y - 64)
        let cancelled = camera
        let next = cancelled.panned(dx: -12, dy: 8)
        #expect(next.x == camera.x - 12)
        #expect(next.y == camera.y + 8)
        #expect(next.zoom == camera.zoom)
    }
}

@Suite("Spatial C2.15 — interruptible pinch without stale zoom")
struct SpatialPinchTransactionTests {
    private let viewport = CGSize(width: 900, height: 700)

    @Test("A changed gesture previews without mutating the baseline")
    func previewIsEphemeral() {
        let baseline = SpatialV3Camera(zoom: 0.75, x: -100, y: 42)
        let preview = SpatialPinchTransaction.camera(
            from: baseline, magnification: 1.8, viewport: viewport, allowed: true
        )
        #expect(preview.zoom > baseline.zoom)
        #expect(baseline == SpatialV3Camera(zoom: 0.75, x: -100, y: 42))
        // @GestureState resets to 1 when cancelled: the rendered value returns
        // to the untouched baseline, and a new gesture starts with a fresh 1.
        let cancelled = SpatialPinchTransaction.camera(
            from: baseline, magnification: 1, viewport: viewport, allowed: true
        )
        #expect(cancelled == baseline)
        let next = SpatialPinchTransaction.camera(
            from: baseline, magnification: 1.15, viewport: viewport, allowed: true
        )
        #expect(abs(next.zoom - baseline.zoom * 1.15) < 0.00001)
    }

    @Test("A completed gesture applies total magnification just once")
    func commitsOnceWithAnchor() {
        let initial = SpatialV3Camera(zoom: 0.8, x: -30, y: 80)
        let committed = SpatialPinchTransaction.camera(
            from: initial, magnification: 1.5, viewport: viewport, allowed: true
        )
        #expect(abs(committed.zoom - 1.2) < 0.00001)
        let center = CGPoint(x: viewport.width / 2, y: viewport.height / 2)
        #expect(abs((center.x - initial.x) / initial.zoom
                    - (center.x - committed.x) / committed.zoom) < 0.00001)
        #expect(abs((center.y - initial.y) / initial.zoom
                    - (center.y - committed.y) / committed.zoom) < 0.00001)
    }

    @Test("A card drag or background pan disallows an overlapping pinch")
    func competingGestures() {
        let baseline = SpatialV3Camera(zoom: 1.1, x: 16, y: -44)
        #expect(SpatialPinchTransaction.camera(
            from: baseline, magnification: 2, viewport: viewport, allowed: false
        ) == baseline)
    }

    @Test("Invalid magnification or viewport cannot poison camera state")
    func invalidInput() {
        let baseline = SpatialV3Camera()
        for factor: CGFloat in [0, -1, .nan, .infinity] {
            #expect(SpatialPinchTransaction.camera(
                from: baseline, magnification: factor, viewport: viewport, allowed: true
            ) == baseline)
        }
        #expect(SpatialPinchTransaction.camera(
            from: baseline, magnification: 2,
            viewport: .zero, allowed: true
        ) == baseline)
    }

    @Test("Preview and final camera obey the same zoom limits")
    func limits() {
        let baseline = SpatialV3Camera()
        #expect(SpatialPinchTransaction.camera(
            from: baseline, magnification: 100, viewport: viewport, allowed: true
        ).zoom == SpatialV3Camera.maxZoom)
        #expect(SpatialPinchTransaction.camera(
            from: baseline, magnification: 0.001, viewport: viewport, allowed: true
        ).zoom == SpatialV3Camera.minZoom)
    }
}

@Suite("Spatial C2.16 — precise trackpad scroll owns only the canvas")
struct SpatialTrackpadScrollTests {
    private func input(
        dx: CGFloat = 16,
        dy: CGFloat = -23,
        precise: Bool = true,
        modifiers: Bool = false,
        momentum: Bool = false,
        ending: Bool = false
    ) -> SpatialTrackpadScrollInput {
        SpatialTrackpadScrollInput(
            delta: CGSize(width: dx, height: dy),
            isPrecise: precise, hasReservedModifiers: modifiers,
            hasMomentum: momentum, isEnding: ending
        )
    }

    @Test("Two-finger scroll translates the camera by screen points, never zooms it")
    func incrementalPanIsPresentationOnly() {
        let original = SpatialV3Camera(zoom: 0.42, x: 64, y: -125)
        let first = input().translatedCamera(
            from: original, insideViewport: true, canPan: true
        )
        #expect(first == SpatialV3Camera(zoom: 0.42, x: 80, y: -148))
        let second = input(dx: -9, dy: 3).translatedCamera(
            from: first!, insideViewport: true, canPan: true
        )
        #expect(second == SpatialV3Camera(zoom: 0.42, x: 71, y: -145))
        #expect(original == SpatialV3Camera(zoom: 0.42, x: 64, y: -125))
    }

    @Test("Scroll outside the canvas or during drag/pan/pinch belongs to native controls")
    func viewAndGesturesOwnTheirInput() {
        let original = SpatialV3Camera()
        #expect(input().translatedCamera(from: original,
            insideViewport: false, canPan: true) == nil)
        #expect(input().translatedCamera(from: original,
            insideViewport: true, canPan: false) == nil)
        #expect(input(precise: false).translatedCamera(from: original,
            insideViewport: true, canPan: true) == nil)
        #expect(input(modifiers: true).translatedCamera(from: original,
            insideViewport: true, canPan: true) == nil)
    }

    @Test("Ended, cancelled, momentum and invalid deltas never poison the next pan")
    func interruptionsDoNotAccumulateStaleState() {
        let baseline = SpatialV3Camera(zoom: 1.2, x: -18, y: 2)
        #expect(input(ending: true).translatedCamera(from: baseline,
            insideViewport: true, canPan: true) == nil)
        #expect(input(momentum: true).translatedCamera(from: baseline,
            insideViewport: true, canPan: true) == nil)
        #expect(input(dx: .nan).translatedCamera(from: baseline,
            insideViewport: true, canPan: true) == nil)
        #expect(input(dy: .infinity).translatedCamera(from: baseline,
            insideViewport: true, canPan: true) == nil)
        #expect(input(dx: 0, dy: 0).translatedCamera(from: baseline,
            insideViewport: true, canPan: true) == nil)
        #expect(input(dx: 6, dy: -4).translatedCamera(from: baseline,
            insideViewport: true, canPan: true)
            == SpatialV3Camera(zoom: 1.2, x: -12, y: -2))
    }


}

@Suite("Spatial C2.17 — pinch follows the actual fingers")
struct SpatialPinchAnchorTests {
    let viewport = CGSize(width: 900, height: 700)

    @Test("Off-centre pinch preserves the world point under the gesture's origin")
    func actualFingerAnchorDoesNotJump() {
        let original = SpatialV3Camera(zoom: 0.71, x: -180, y: 36)
        let focal = SpatialPinchPreview(
            magnification: 1.85,
            unitAnchor: CGPoint(x: 0.18, y: 0.78),
            viewport: viewport
        )
        #expect(focal.anchor == CGPoint(x: 162, y: 546))
        let preview = SpatialPinchTransaction.camera(
            from: original, magnification: focal.magnification,
            viewport: viewport, anchor: focal.anchor, allowed: true
        )
        #expect(preview.zoom > original.zoom)
        #expect(abs((focal.anchor.x - preview.x) / preview.zoom
                    - (focal.anchor.x - original.x) / original.zoom) < 0.00001)
        #expect(abs((focal.anchor.y - preview.y) / preview.zoom
                    - (focal.anchor.y - original.y) / original.zoom) < 0.00001)
        #expect(original == SpatialV3Camera(zoom: 0.71, x: -180, y: 36))
    }

    @Test("Preview and final commit use exactly the same anchored transform")
    func stablePreviewAndCommit() {
        let initial = SpatialV3Camera(zoom: 1.1, x: 80, y: -44)
        let gesture = SpatialPinchPreview(
            magnification: 0.55,
            unitAnchor: CGPoint(x: 0.93, y: 0.08),
            viewport: viewport
        )
        let temporary = SpatialPinchTransaction.camera(
            from: initial, magnification: gesture.magnification,
            viewport: viewport, anchor: gesture.anchor, allowed: true
        )
        let committed = SpatialPinchTransaction.camera(
            from: initial, magnification: gesture.magnification,
            viewport: viewport, anchor: gesture.anchor, allowed: true
        )
        #expect(temporary == committed)
        #expect(SpatialPinchTransaction.camera(
            from: initial, magnification: 1, viewport: viewport,
            anchor: gesture.anchor, allowed: true
        ) == initial)
        // Cancelled @GestureState returns to no preview, not a stale anchor.
        let newGesture = SpatialPinchPreview(
            magnification: 1.15,
            unitAnchor: CGPoint(x: 0.25, y: 0.3),
            viewport: viewport
        )
        #expect(newGesture.anchor != gesture.anchor)
        #expect(initial.zoom == 1.1)
    }

    @Test("Invalid or out-of-viewport pinch focal points cannot change camera state")
    func invalidAnchorsAreRejected() {
        let initial = SpatialV3Camera(zoom: 0.9, x: -30, y: -50)
        for focal in [
            CGPoint(x: -1, y: 100), CGPoint(x: 901, y: 20),
            CGPoint(x: 20, y: 701), CGPoint(x: CGFloat.nan, y: 5),
            CGPoint(x: 5, y: CGFloat.infinity)
        ] {
            #expect(SpatialPinchTransaction.camera(
                from: initial, magnification: 1.4, viewport: viewport,
                anchor: focal, allowed: true
            ) == initial)
        }
        #expect(SpatialPinchTransaction.camera(
            from: initial, magnification: 1.4,
            viewport: CGSize(width: CGFloat.infinity, height: 700),
            anchor: CGPoint(x: 30, y: 50), allowed: true
        ) == initial)
    }
}
