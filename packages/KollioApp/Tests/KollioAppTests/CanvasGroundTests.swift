import CoreGraphics
import Foundation
import Testing
@testable import KollioApp

/// The ground's behaviour, decided before it is drawn.
///
/// These tests hold the rules a picture cannot: the band keeps the dots present
/// but never noise, dense grain climbs to the major step rather than whispering,
/// and silence at the camera floor is stated by both sides agreeing on the
/// number.
@Suite("The ground under a zooming document")
struct CanvasGroundTests {
    @Test("Mid-zoom: the minor step, present and honest")
    func minorAtMidZoom() {
        let scale = CanvasGround.scale(zoom: 1)
        #expect(scale.draws)
        #expect(!scale.isMajor)
        #expect(scale.worldStep == CanvasGround.minorWorldStep)
        #expect(scale.screenStep == CanvasGround.minorWorldStep)
    }

    @Test("Zoom-out: the minor step recedes, the major stride answers")
    func majorAppearsWhenZoomingOut() {
        // 0.5 puts the minor step at 12: inside the band, so this is the minor
        // step. Half again puts it at 6: grain. The major stride comes back to
        // 30: present.
        #expect(CanvasGround.scale(zoom: 0.5).isMajor == false)
        let scale = CanvasGround.scale(zoom: 0.25)
        #expect(scale.draws)
        #expect(scale.isMajor)
        #expect(scale.screenStep == 30)
    }

    @Test("Zoom-out to the camera floor: the major stride answers, not silence")
    func majorAtTheFloor() {
        // 0.25 puts the minor step at 6: grain. The major stride answers at 30,
        // present. The fully zoomed-out document keeps a ground, because that
        // is where a person is most lost.
        let scale = CanvasGround.scale(zoom: 0.25)
        #expect(scale.draws)
        #expect(scale.isMajor)

        // The camera floor itself: the floor is 0.2, and the stride at 24
        // stays inside the band. Silence would only mean abandonment. Measured
        // with tolerance because 24 * 0.2 * 5 is not exactly 24.
        let floor = CanvasGround.scale(zoom: 0.2)
        #expect(floor.draws)
        #expect(floor.isMajor)
        #expect(abs(floor.screenStep - 24) < 0.0001)
    }

    @Test("Zoom way in: texture climbs or goes quiet, never a hairline grain")
    func zoomedInTheDocumentGrain() {
        // 1.5 puts the minor step at 36 — still in the band. So a moderately
        // zoomed-in document keeps its ground without doubling.
        let scale = CanvasGround.scale(zoom: 1.5)
        #expect(scale.draws)
        #expect(scale.screenStep == 36)
    }

    @Test("The band bounds hold, and contradict noise")
    func bandBounds() {
        #expect(CanvasGround.screenBand.lowerBound > 0)
        #expect(CanvasGround.screenBand.lowerBound < CanvasGround.screenBand.upperBound)
    }

    @Test("The major stride is a multiple, not a second grid")
    func majorIsAMultiple() {
        #expect(CanvasGround.majorStepMultiple > 1)
    }

    @Test("A zoom of zero cannot draw, and this is stated")
    func zeroZoomCannotDraw() {
        #expect(CanvasGround.scale(zoom: 0).isSilent)
    }
}
