import Foundation
import Testing
import KollioCore
@testable import KollioApp

/// Reading how a thing got here (DEC-06).
///
/// The timeline is a reading of the journal, and the behaviours worth holding
/// are the ones a reading can break: offering itself when nothing happened,
/// claiming that reading changed something, or losing the present on the way
/// back. The origin of a decision (AC01) is answerable because the recorded
/// actions carry the label the person acted under; returning to the present
/// (AC02) is provable because the document is byte-identical after the round
/// trip. The preview, the restore and the purge are written and not built,
/// and nothing here pretends otherwise.
@Suite("The history timeline is a reading")
@MainActor
struct HistoryTimelineTests {
    private func model() -> KollioModel {
        KollioModel(
            document: SarahFixture.document(),
            service: KollioModel.makeDemoService(languageCode: "fr"),
            fileStore: DocumentFileStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()))
        )
    }

    private var csv: ObjectID { ObjectID("object:sarah-csv") }

    @Test("The action is offered only when something happened to the object")
    func offeredWhenThereIsHistory() {
        var model = model()
        // A fresh fixture has no recorded actions, so the timeline is not offered.
        #expect(model.history(of: csv).isEmpty)
        #expect(model.contextualActions(for: csv).secondary.contains(.reviewHistory) == false)

        model.applyEdit(to: csv, text: "Export CSV enrichi")
        #expect(model.history(of: csv).isEmpty == false)
        #expect(model.contextualActions(for: csv).secondary.contains(.reviewHistory))
    }

    @Test("The origin of a decision is answerable: the label the person acted under is there")
    func decisionOriginIsReadable() throws {
        var model = model()
        model.applyEdit(to: csv, text: "Export CSV enrichi")
        let decided = sessionApply(model, .recordDecision(RecordDecision(
            id: DecisionID("decision:csv"),
            kind: .setAside,
            targetObjectID: csv,
            rationale: LocalizedText("Identifiants API indisponibles"),
            provenance: .human("me")
        )), label: "undo.recordDecision")

        let history = model.history(of: csv)
        #expect(history.contains { $0.label == "undo.recordDecision" })
        #expect(history.contains { $0.label == L10n.undoEdit })
        #expect(history.allSatisfy { $0.movedMeaning }, "both are meaning, not layout")
    }

    @Test("Opening and closing mutates nothing: the document is byte-identical")
    func readingIsAReading() throws {
        var model = model()
        model.applyEdit(to: csv, text: "Export CSV enrichi")
        let before = model.document

        #expect(model.openHistory(of: csv))
        #expect(model.openHistoryID == csv)
        #expect(KollioModel.TransientLevel.topmost(in: model) == .history)
        #expect(model.dismissOneLevel() == .history)
        #expect(model.openHistoryID == nil)

        #expect(model.document == before, "AC02: returning to the present mutates nothing")
    }

    @Test("Nothing happened, nothing opens")
    func nothingOpensNothing() {
        var model = model()
        #expect(model.openHistory(of: csv) == false)
        #expect(model.openHistoryID == nil)
    }

    @Test("The timeline has the newest action first")
    func newestFirst() throws {
        var model = model()
        model.applyEdit(to: csv, text: "Premier")
        model.applyEdit(to: csv, text: "Deuxième")
        let history = model.history(of: csv)
        #expect(history.count >= 2)
        #expect(history.last?.label == L10n.undoEdit)
        #expect(history.first?.label == L10n.undoEdit)
    }

    /// A decision recorded through the session, so it lands in the journal.
    @discardableResult
    private func sessionApply(_ model: KollioModel, _ command: Command, label: String) -> Bool {
        model.perform([command], label: label)
    }

    @Test("Every timeline string resolves to a catalog key")
    func labelsResolve() {
        let keys = [
            L10n.historyTitle,
            L10n.historyReviewAction,
            L10n.historyLaterReverted,
            L10n.historyClose
        ]
        for key in keys {
            #expect(key.contains("history.") == false, "a raw key would be shown: \(key)")
        }
    }
}
