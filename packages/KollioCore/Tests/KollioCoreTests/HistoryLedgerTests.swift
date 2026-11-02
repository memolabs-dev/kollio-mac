import Foundation
import Testing
@testable import KollioCore

/// The question the document itself cannot answer: what happened to this thing?
///
/// The document holds state plus decisions. A decision preserves a *judgement*; it
/// does not record that a line was retyped or that a relationship was removed. So
/// the history of an object is not recoverable from the object, and these tests
/// are about the ledger that can answer it — and, just as much, about what the
/// ledger refuses to claim to be.
@Suite("History ledger")
struct HistoryLedgerTests {
    private var ctx: ObjectID { ObjectID("object:ctx") }
    private var method: ObjectID { ObjectID("object:method") }

    private func session() -> KollioSession {
        KollioSession(document: KollioDocument())
    }

    private func add(_ object: ObjectID, _ text: String, kind: ContentObject.Kind = .context) -> Command {
        .createObject(.init(
            id: object, kind: kind, text: LocalizedText(text), provenance: .human("me")
        ))
    }

    // MARK: - It records what happened

    @Test("An applied action is recorded with what it did and where")
    func recordsAnAppliedAction() throws {
        var session = session()
        let applied = session.apply([add(ctx, "Reduce the flow")], label: "add context")
        #expect(applied)

        let entry = session.document.history.entries.first
        let recorded = try #require(entry)
        #expect(recorded.kind == .applied)
        #expect(recorded.label == "add context")
        #expect(recorded.commands.count == 1)
        #expect(recorded.revisionBefore == 0)
        #expect(recorded.revisionAfter == 1)
        #expect(recorded.movedMeaning == true)
    }

    @Test("An action that changed nothing is not recorded")
    func noOpIsNotRecorded() {
        var session = session()
        // A command batch that applies and changes nothing: the undo stack drops
        // it, so the ledger must too. A ledger counting an action nobody can take
        // back would be counting something that did not happen.
        let empty: [Command] = []
        _ = session.apply(empty, label: "nothing")
        #expect(session.document.history.isEmpty)
    }

    @Test("A refused action is not recorded")
    func refusedIsNotRecorded() {
        var session = session()
        let refused = session.apply([add(ctx, "Reduce the flow"), add(ctx, "Duplicate")], label: "add twice")
        #expect(refused == false)
        #expect(session.document.history.isEmpty)
        #expect(session.lastError != nil)
    }

    // MARK: - The question it exists to answer

    @Test("The history of an object is answerable")
    func historyOfAnObject() {
        var session = session()
        _ = session.apply([add(ctx, "Reduce the flow")], label: "add context")
        _ = session.apply([add(method, "Instrument each step")], label: "add method")
        _ = session.apply([
            .updateObjectText(.init(id: ctx, text: LocalizedText("Reduce to three steps"), provenance: .human("me")))
        ], label: "retype the context")

        let entries = session.document.history.entries(touching: ctx, in: session.document)
        #expect(entries.count == 2)
        #expect(entries.map(\.label) == ["add context", "retype the context"])
        // And the other object is not polluted by the first one's work.
        let other = session.document.history.entries(touching: method, in: session.document)
        #expect(other.map(\.label) == ["add method"])
    }

    @Test("A relationship edit lands in the history of both ends")
    func relationshipTouchesBothEnds() {
        var session = session()
        _ = session.apply([add(ctx, "A"), add(method, "B")], label: "seed")
        let relationship = RelationshipID("rel:1")
        _ = session.apply([
            .addRelationship(.init(
                id: relationship, from: ctx, to: method, kind: .supports, provenance: .human("me")
            ))
        ], label: "link them")

        #expect(session.document.history.entries(touching: ctx, in: session.document).map(\.label) == ["seed", "link them"])
        #expect(session.document.history.entries(touching: method, in: session.document).map(\.label) == ["seed", "link them"])
    }

    @Test("A decision lands in the history of what it was taken on")
    func decisionTouchesItsTarget() {
        var session = session()
        _ = session.apply([add(ctx, "A"), add(method, "B")], label: "seed")
        _ = session.apply([.recordDecision(.init(
            id: DecisionID("d1"), kind: .setAside, targetObjectID: method,
            rationale: LocalizedText("No budget"), provenance: .human("me")
        ))], label: "set aside")

        let entries = session.document.history.entries(touching: method, in: session.document)
        #expect(entries.map(\.label) == ["seed", "set aside"])
        #expect(session.document.history.entries(touching: ctx, in: session.document).map(\.label) == ["seed"])
    }

    // MARK: - It is append-only, and that is the point

    @Test("An undo is recorded as a reversal, and the original stays")
    func undoIsAReversalNotAnErasure() {
        var session = session()
        _ = session.apply([add(ctx, "Reduce the flow")], label: "add context")
        let undone = session.undo(at: Date(timeIntervalSince1970: 10))
        #expect(undone)

        #expect(session.document.history.count == 2)
        // The first entry is untouched, which is the whole claim.
        #expect(session.document.history.entries[0].kind == .applied)
        #expect(session.document.history.entries[0].label == "add context")
        // And the second says what was taken back rather than hiding that it was.
        if case .reversed(let target) = session.document.history.entries[1].kind {
            #expect(target == session.document.history.entries[0].id)
        } else {
            Issue.record("expected a reversal, got \(session.document.history.entries[1].kind)")
        }
    }

    @Test("A narrative folds a reversal into the action it cancels")
    func narrativeFoldsReversals() {
        var session = session()
        _ = session.apply([add(ctx, "Reduce the flow")], label: "add context")
        _ = session.undo(at: Date(timeIntervalSince1970: 10))
        _ = session.apply([add(ctx, "Reduce the flow to two steps")], label: "add it again")

        let narrative = session.document.history.narrative(for: ctx, in: session.document)
        // Two rows, not three: a person should not have to do the arithmetic to
        // find out that the first attempt was taken back.
        #expect(narrative.map(\.label) == ["add it again"])
    }

    @Test("A kept action says so in the narrative")
    func keptActionsAreMarked() {
        var session = session()
        _ = session.apply([add(ctx, "Reduce the flow")], label: "add context")
        let narrative = session.document.history.narrative(for: ctx, in: session.document)
        #expect(narrative.count == 1)
        #expect(narrative[0].wasLaterReverted == false)
        #expect(narrative[0].movedMeaning)
    }

    @Test("Presentation does not count as meaning, though it is still recorded")
    func presentationIsRecordedButIsNotMeaning() {
        var session = session()
        _ = session.apply([add(ctx, "Reduce the flow")], label: "add context")
        let before = session.document.semanticRevision
        _ = session.apply([.createFrame(.init(frame: Frame(
            id: FrameID("f1"), name: LocalizedText("A group"), position: .zero
        )))], label: "frame it")

        let entry = session.document.history.entries.last
        #expect(entry?.label == "frame it")
        #expect(session.document.semanticRevision == before)
        #expect(entry?.movedMeaning == false)
    }

    // MARK: - What it is not

    @Test("The ledger is not authoritative, and a file may arrive without one")
    func ledgerIsOptional() throws {
        let document = KollioDocument()
        let encoded = try DocumentCodec.encode(document)
        let decoded = try DocumentCodec.decode(encoded)
        // A document with no history says so. Back-filling an invented past would
        // be worse than admitting there is none.
        #expect(decoded.history.isEmpty)
    }

    @Test("The ledger survives a save and a reload")
    func survivesAReload() throws {
        var session = session()
        _ = session.apply([add(ctx, "Reduce the flow")], label: "add context")
        _ = session.apply([add(method, "Instrument each step")], label: "add method")

        let decoded = try DocumentCodec.decode(DocumentCodec.encode(session.document))
        #expect(decoded.history.count == 2)
        #expect(decoded.history.entries[0].commands.count == 1)
        #expect(decoded.history.entries(touching: ctx, in: decoded).map(\.label) == ["add context"])
    }

    @Test("A command about the document is not in the history of every object")
    func aDocumentCommandTouchesNoObject() {
        var session = session()
        _ = session.apply([add(ctx, "A"), add(method, "B")], label: "seed")
        _ = session.apply([.createFrame(.init(frame: Frame(
            id: FrameID("f1"), name: LocalizedText("A group"), position: .zero
        )))], label: "frame them")

        // The frame holds both objects, and the framing is still nobody's business
        // but the person's. Claiming otherwise would put a canvas tidy-up into the
        // history of every object it happened to contain.
        let framings = session.document.history.entries.filter { $0.label == "frame them" }
        #expect(framings.count == 1)
        #expect(framings[0].touchedObjectIDs(in: session.document).isEmpty)
    }
}
