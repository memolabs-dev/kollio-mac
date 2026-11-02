import CoreGraphics
import Foundation
import Testing
import KollioCore
@testable import KollioApp

/// The connector vocabulary, decided before it is drawn.
///
/// The reason this can be a test at all: the appearance of a relationship is a
/// *decision* about what the stroke says, and a decision that lives in a table
/// can be read rather than screenshotted. The one rule worth enforcing is the
/// one a small vocabulary lives or dies by — that most connectors wear nothing
/// at all — and the test can say what no picture can.
@Suite("The connector vocabulary is small on purpose")
struct RelationshipAppearanceTests {
    @Test("The kinds that assert wear a marker, and their pair is the meaning")
    func assertionsAreMarked() {
        #expect(RelationshipAppearance.treatment(for: .supports) == .support)
        #expect(RelationshipAppearance.treatment(for: .contradicts) == .contradiction)
    }

    @Test("Everything else is plain, and that is most of the vocabulary")
    func plainIsTheCommonCase() {
        // Nine kinds, two marked. Adding a marker for a kind whose meaning is
        // not an assertion is how a connector language turns into UML.
        let marked = Relationship.Kind.allCases.filter {
            RelationshipAppearance.treatment(for: $0) != .plain
        }
        #expect(marked == [.supports, .contradicts])
    }

    @Test("A missing kind draws nothing rather than guessing")
    func unknownIsPlain() {
        #expect(RelationshipAppearance.treatment(for: nil) == .plain)
    }

    @Test("Nothing about the marker touches the label's own legibility")
    func theLabelStaysUnmarked() {
        // The design's hard rule: meaning is never expressed by making text hard
        // to read. The marker lives on the stroke; the label keeps its own font
        // and colour. Asserted here as the one thing that would be tempting to
        // "simplify" later — marking the label too, so the marker can be found.
        #expect(TypeScale.spec(.metadata).weightRank == 0, "relationship labels must stay regular")
    }
}
