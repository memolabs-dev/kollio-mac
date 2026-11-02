import Foundation
import Testing
import KollioCore
@testable import KollioApp

/// Building a validation experiment from the interface.
///
/// The behaviours worth protecting are the ones a person can get wrong, and the
/// one the domain already refuses: an experiment with no criterion cannot lose,
/// so the interface says why nothing was built instead of building something
/// that cannot be judged. The evidence comes from the selection, because the
/// usual way to build an experiment is to have just looked at the things it
/// will judge.
@Suite("Experiment interface")
@MainActor
struct ExperimentInterfaceTests {
    private func model() -> KollioModel {
        KollioModel(
            document: SarahFixture.document(),
            service: KollioModel.makeDemoService(languageCode: "fr"),
            fileStore: DocumentFileStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()))
        )
    }

    private let csv = ObjectID("object:sarah-csv")
    private let viable = ObjectID("object:sarah-viable")

    @Test("The action is offered, and opens a draft on the object being worked on")
    func theActionOpensADraft() {
        var model = model()
        let set = model.contextualActions(for: csv)
        #expect(set.secondary.contains(.buildExperiment))
        model.startExperiment(anchor: csv)
        #expect(model.experimentDraft?.anchor == csv)
        #expect(model.experimentDraft?.isSimulation == false)
    }

    @Test("Evidence is prefilled from the selection, not from nowhere")
    func evidenceComesFromTheSelection() {
        var model = model()
        model.selection = [viable, csv]
        model.startExperiment(anchor: csv)
        #expect(model.experimentDraft?.expectedEvidence == [viable], "the anchor is not its own evidence")
    }

    @Test("With nothing selected, the experiment judges against nothing yet")
    func emptySelectionStartsWithNoEvidence() {
        var model = model()
        model.selection = []
        model.startExperiment(anchor: csv)
        #expect(model.experimentDraft?.expectedEvidence.isEmpty == true)
    }

    @Test("A built experiment lands in the document, and the draft closes")
    func buildingAnExperiment() throws {
        var model = model()
        model.selection = [viable]
        model.startExperiment(anchor: csv)
        model.experimentDraft?.question = "L'export tient-il avec les tags ?"
        model.experimentDraft?.method = "Charger cent prospects"
        model.experimentDraft?.criterion = "Cent prospects en moins de trois secondes"
        #expect(model.submitExperiment())

        let experiments = model.experiments(on: csv)
        #expect(experiments.count == 1)
        #expect(experiments.first?.currentRevision.successCriterion.text.contains("trois secondes") == true)
        #expect(experiments.first?.expectedEvidence == [viable])
        #expect(model.experimentDraft == nil)
    }

    @Test("A simulation is labelled as one, from the interface down to the document")
    func simulationIsLabelled() throws {
        var model = model()
        model.startExperiment(anchor: csv)
        model.experimentDraft?.question = "Q"
        model.experimentDraft?.criterion = "C"
        model.experimentDraft?.isSimulation = true
        #expect(model.submitExperiment())
        #expect(model.experiments(on: csv).first?.isSimulation == true)
    }

    @Test("No criterion states nothing and says why")
    func emptyCriterionIsRefusedWithAReason() {
        var model = model()
        model.startExperiment(anchor: csv)
        model.experimentDraft?.question = "Une question"
        model.experimentDraft?.criterion = "   "
        let before = model.document
        #expect(model.submitExperiment() == false)
        #expect(model.status?.isEmpty == false, "the refusal says what is missing")
        #expect(model.document == before, "nothing was built")
        #expect(model.experimentDraft != nil, "the draft stays open for the person to finish")
    }

    @Test("No question states nothing, for the same reason")
    func emptyQuestionIsRefused() {
        var model = model()
        model.startExperiment(anchor: csv)
        model.experimentDraft?.criterion = "Un critère"
        let before = model.document
        #expect(model.submitExperiment() == false)
        #expect(model.document == before)
    }

    @Test("Building an experiment is undoable, and undo restores the document")
    func undoRemovesTheExperiment() {
        var model = model()
        model.startExperiment(anchor: csv)
        model.experimentDraft?.question = "Q"
        model.experimentDraft?.criterion = "C"
        #expect(model.submitExperiment())
        #expect(model.experiments(on: csv).count == 1)
        model.undo()
        #expect(model.experiments(on: csv).isEmpty)
    }

    @Test("One commitment at a time: opening one draft closes the other")
    func oneDraftAtATime() {
        var model = model()
        model.startClaim(role: .hypothesis, anchor: csv)
        #expect(model.claimDraft != nil)
        model.startExperiment(anchor: csv)
        #expect(model.claimDraft == nil, "the experiment draft took over")
        #expect(model.experimentDraft != nil)
        model.startClaim(role: .constraint, anchor: csv)
        #expect(model.experimentDraft == nil)
    }
}
