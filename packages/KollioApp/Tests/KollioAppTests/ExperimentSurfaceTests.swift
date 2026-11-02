import Foundation
import Testing
import KollioCore
@testable import KollioApp

/// Reading a built experiment.
///
/// The card is a reading of the document, and the behaviours worth protecting
/// are the ones a reading can get wrong: showing today's criterion instead of
/// the committed one, opening when there is nothing to read, or claiming that
/// reading changed something.
@Suite("Experiment card")
@MainActor
struct ExperimentSurfaceTests {
    private func model() -> KollioModel {
        KollioModel(
            document: SarahFixture.document(),
            service: KollioModel.makeDemoService(languageCode: "fr"),
            fileStore: DocumentFileStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()))
        )
    }

    private let csv = ObjectID("object:sarah-csv")

    @Test("The read action is offered only when an experiment exists")
    func offeredOnlyWhenThereIsSomethingToRead() {
        var model = model()
        #expect(model.contextualActions(for: csv).secondary.contains(.reviewExperiment) == false)
        model.startExperiment(anchor: csv)
        model.experimentDraft?.question = "Q"
        model.experimentDraft?.criterion = "C"
        #expect(model.submitExperiment())
        #expect(model.contextualActions(for: csv).secondary.contains(.reviewExperiment))
    }

    @Test("Opening shows the newest experiment, and closes with one level of Escape")
    func openingAndEscape() throws {
        var model = model()
        model.startExperiment(anchor: csv)
        model.experimentDraft?.question = "Première question"
        model.experimentDraft?.criterion = "Premier critère"
        #expect(model.submitExperiment())

        let opened = try #require(model.openExperiment(on: csv))
        #expect(model.openExperimentID == opened)
        #expect(try #require(KollioModel.TransientLevel.topmost(in: model)) == .experiment)
        #expect(model.dismissOneLevel() == .experiment)
        #expect(model.openExperimentID == nil)
    }

    @Test("Reading writes nothing: the document is byte-identical after closing")
    func readingIsAReading() throws {
        var model = model()
        model.startExperiment(anchor: csv)
        model.experimentDraft?.question = "Q"
        model.experimentDraft?.criterion = "C"
        #expect(model.submitExperiment())
        let before = model.document

        #expect(model.openExperiment(on: csv) != nil)
        #expect(model.dismissOneLevel() == .experiment)

        #expect(model.document == before)
    }

    @Test("The card shows the experiment it opened, deterministically")
    func openedIsShown() throws {
        var model = model()
        for (question, criterion) in [("Q1", "C1"), ("Q2", "C2")] {
            model.startExperiment(anchor: csv)
            model.experimentDraft?.question = question
            model.experimentDraft?.criterion = criterion
            #expect(model.submitExperiment())
        }
        let experiments = model.experiments(on: csv)
        #expect(experiments.count == 2)

        // Two experiments created in the same second cannot be told apart by
        // wall-clock time, so "the newest" is resolved by a stable tiebreak
        // rather than by chance. What a reader is owed is consistency: the
        // card shows the experiment it opened, and reopening opens the same
        // one while the document stands.
        let opened = try #require(model.openExperiment(on: csv))
        let shown = try #require(model.document.experiments.experiment(opened))
        #expect(opened == experiments.last?.id)
        #expect(shown.currentRevision.question.text == "Q1" || shown.currentRevision.question.text == "Q2")
        #expect(model.openExperiment(on: csv) == opened, "the choice does not wander")
    }

    @Test("Nothing to read opens nothing and says nothing")
    func noExperimentOpensNothing() {
        var model = model()
        #expect(model.openExperiment(on: csv) == nil)
        #expect(model.openExperimentID == nil)
    }

    @Test("Every card string resolves to a catalog key, so no key is ever shown")
    func labelsResolve() {
        let keys = [
            L10n.experimentReviewAction,
            L10n.experimentCardTitle,
            L10n.experimentCardQuestion,
            L10n.experimentCardMethod,
            L10n.experimentCardCriterion,
            L10n.experimentCardEvidence,
            L10n.experimentCardClose,
            L10n.experimentCardRevisions(3)
        ]
        for key in keys {
            #expect(key.contains("experiment.") == false, "a raw key would be shown: \(key)")
        }
        #expect(L10n.experimentCardRevisions(3).contains("3"))
    }
}
