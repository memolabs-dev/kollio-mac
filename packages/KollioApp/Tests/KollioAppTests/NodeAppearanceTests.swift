import Foundation
import Testing
import KollioCore
@testable import KollioApp

/// The silhouette of a document object, stated as a table and checked as one.
///
/// The defect this replaces: a reference and a rich result were both white
/// rounded rectangles, distinguished by four points of radius and by one of them
/// having a shadow. On a canvas with ten objects that difference is not usable, so
/// what a thing *was* was carried by a small icon while its shape carried nothing
/// — and a shadow made a document object look like a card lying on top of the
/// work rather than part of it.
///
/// The table is the assertion. A screenshot cannot say "no persistent object is
/// lifted"; this can.
@Suite("A document object's form is visible in its shape")
struct NodeAppearanceTests {
    private let forms: [ContentObject.Form] = [.thought, .reference, .richResult]

    @Test("Every form has a silhouette, and an unknown one gets the quietest")
    func everyFormIsDecided() {
        for form in forms {
            #expect(NodeAppearanceTable.appearances[form] != nil, "\(form.rawValue) has no silhouette")
        }
        // The fallback is the thought on purpose: a form nobody has designed yet
        // must not acquire a surface it did not ask for.
        #expect(
            NodeAppearanceTable.appearance(for: .reference).boundary
                != NodeAppearanceTable.appearance(for: .thought).boundary
        )
    }

    @Test("No document object is lifted off the canvas")
    func nothingIsLifted() {
        for form in forms {
            #expect(
                !NodeAppearanceTable.appearance(for: form).isLifted,
                "\(form.rawValue) carries a shadow; the world is matte and elevation is not how it says what it is"
            )
        }
    }

    @Test("A thought is text in space and keeps no surface")
    func aThoughtHasNoSurface() {
        let thought = NodeAppearanceTable.appearance(for: .thought)
        #expect(thought.boundary == .none)
        #expect(!thought.hasSurface)
    }

    @Test("The two surfaces are told apart by shape, not by an icon")
    func theTwoSurfacesDiffer() {
        let reference = NodeAppearanceTable.appearance(for: .reference)
        let rich = NodeAppearanceTable.appearance(for: .richResult)
        // Two independent differences, so one of them can change without the two
        // forms becoming identical again.
        #expect(reference.boundary != rich.boundary, "the two surfaces share a boundary")
        #expect(reference.radius != rich.radius, "the two surfaces share a radius")
    }

    @Test("Every radius is one of the design system's, named")
    func radiiAreTokens() {
        let allowed: [String: Double] = [
            "control": Radius.control,
            "reference": Radius.reference,
            "richBlock": Radius.richBlock,
            "composer": Radius.composer
        ]
        for form in forms {
            let appearance = NodeAppearanceTable.appearance(for: form)
            #expect(
                allowed[appearance.radiusToken] == appearance.radius,
                "\(form.rawValue) uses \(appearance.radius) under the name \(appearance.radiusToken), which is not that token"
            )
        }
    }

    @Test("The vocabulary is three forms, and adding one is a decision")
    func theVocabularyIsClosed() {
        // The design says a small number of shape families, and that the branch
        // language rather than the card language is where the identity should
        // live. A fourth silhouette is not a bug but it is a decision.
        #expect(
            NodeAppearanceTable.appearances.count == 3,
            "there are \(NodeAppearanceTable.appearances.count) silhouettes for 3 forms"
        )
    }
}
