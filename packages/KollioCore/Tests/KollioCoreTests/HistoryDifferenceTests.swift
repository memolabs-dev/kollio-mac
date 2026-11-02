import Foundation
import Testing
@testable import KollioCore

/// What DEC-06 asks a preview to carry: the differences, not the whole past.
@Suite("DEC-06: what changed between two states of one object")
struct HistoryDifferenceTests {
    private func document() -> KollioDocument {
        var builder = DocumentBuilder()
        builder.object("cause", kind: .context, "Cause", en: "Cause", at: Position(x: 0, y: 0))
        builder.object("effect", kind: .hypothesis, "Effet", en: "Effect", at: Position(x: 400, y: 0))
        builder.object("other", kind: .hypothesis, "Autre", en: "Other", at: Position(x: 0, y: 400))
        builder.link("l1", from: KollioID.object("cause"), to: KollioID.object("effect"), .supports)
        builder.link("l2", from: KollioID.object("cause"), to: KollioID.object("other"), .contradicts)
        return builder.document
    }

    private let effect = KollioID.object("effect")
    private let other = KollioID.object("other")

    @Test("Nothing moved is reported as nothing moved")
    func unchanged() {
        let same = document()
        let difference = HistoryDifference.between(
            objectID: effect, past: same, present: same, languageCode: "fr"
        )
        #expect(difference.isEmpty)
    }

    @Test("A rewritten text carries both readings, not a verdict")
    func changedText() {
        let past = document()
        var present = past
        present.content[effect]?.text = LocalizedText("Effet mesuré")

        let difference = HistoryDifference.between(
            objectID: effect, past: past, present: present, languageCode: "fr"
        )
        guard case .changed(let from, let to) = difference.text else {
            Issue.record("a rewritten text is a change, not an absence")
            return
        }
        #expect(from == "Effet")
        #expect(to == "Effet mesuré")
        #expect(difference.isEmpty == false)
    }

    @Test("A relation that did not exist then is added, and one that is gone is removed")
    func addedAndRemoved() {
        let past = document()
        var present = past
        // Reverse the contradiction into a support, and drop the support.
        present.relationships = [
            KollioID.relationship("l1"): Relationship(
                id: KollioID.relationship("l1"), from: effect, to: other, kind: .supports,
                provenance: .human("test")
            )
        ]

        let difference = HistoryDifference.between(
            objectID: effect, past: past, present: present, languageCode: "fr"
        )
        // The relation to `cause` is gone; the one to `other` is new.
        #expect(difference.connections[other] == .added(kind: .supports))
        #expect(difference.connections[KollioID.object("cause")] == .removed(kind: .supports))
    }

    @Test("Changing a relation kind carries both the old and new readings")
    func changedRelationshipKind() {
        let past = document()
        var present = past
        present.relationships[KollioID.relationship("l1")]?.kind = .contradicts

        let difference = HistoryDifference.between(
            objectID: effect, past: past, present: present, languageCode: "fr"
        )

        #expect(
            difference.connections[KollioID.object("cause")]
                == .changed(from: .supports, to: .contradicts)
        )
    }

    @Test("A relation read from either end is the same relation")
    func bothDirectionsCount() {
        let same = document()
        // `other` reaches `cause` from the far end; the timeline is open on it.
        let difference = HistoryDifference.between(
            objectID: other, past: same, present: same, languageCode: "fr"
        )
        #expect(difference.connections[effect] == nil)
        #expect(difference.connections[KollioID.object("cause")] == .unchanged)
    }

    @Test("An object that is gone now is a removal, not a silence")
    func removedObject() {
        let past = document()
        var present = past
        present.content.removeValue(forKey: other)

        let difference = HistoryDifference.between(
            objectID: other, past: past, present: present, languageCode: "fr"
        )
        guard case .removed(let text) = difference.text else {
            Issue.record("an object that no longer exists is something that happened")
            return
        }
        #expect(text == "Autre")
    }

    @Test("The comparison is of the interface's variant, never a translation")
    func languageIsTheReaders() {
        let past = document()
        var present = past
        present.content[effect]?.text = LocalizedText("Effet", variants: ["en": "Effect, measured"])

        let inFrench = HistoryDifference.between(
            objectID: effect, past: past, present: present, languageCode: "fr"
        )
        let inEnglish = HistoryDifference.between(
            objectID: effect, past: past, present: present, languageCode: "en"
        )
        // In French the text is the same word, so nothing moved; in English it
        // moved. Neither reading is a translation of the other.
        #expect(inFrench.isEmpty)
        #expect(inEnglish.isEmpty == false)
    }
}
