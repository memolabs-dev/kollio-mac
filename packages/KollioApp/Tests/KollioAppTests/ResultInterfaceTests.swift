import Foundation
import Testing
import KollioCore
@testable import KollioApp

/// Recording a result from the interface, and the separations it keeps.
///
/// The composer is the place where the observation and the interpretation
/// could quietly merge, so the tests hold them apart: the observation is
/// required with a reason, an inconclusive answer cannot be recorded without
/// saying what is missing, a half-written measurement is refused rather than
/// half-recorded, and the learning is a proposal about the selection that
/// never takes a decision.
@Suite("Result interface")
@MainActor
struct ResultInterfaceTests {
    private func model() -> KollioModel {
        KollioModel(
            document: SarahFixture.document(),
            service: KollioModel.makeDemoService(languageCode: "fr"),
            fileStore: DocumentFileStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()))
        )
    }

    private var csv: ObjectID { ObjectID("object:sarah-csv") }

    private func builtExperiment(_ model: inout KollioModel) throws -> ExperimentID {
        model.startExperiment(anchor: csv)
        model.experimentDraft?.question = "L'export tient-il ?"
        model.experimentDraft?.criterion = "Cent prospects en moins de trois secondes"
        #expect(model.submitExperiment())
        return try #require(model.experiments(on: csv).last?.id)
    }

    @Test("The card offers recording, and the draft sits beside the anchor")
    func cardOffersRecording() throws {
        var model = model()
        let id = try builtExperiment(&model)
        model.startRecordingResult(id)
        #expect(model.resultDraft?.experimentID == id)
        #expect(model.resultDraftAnchor == csv)
        #expect(model.experimentDraft == nil, "the result draft took over the commitment")
    }

    @Test("A recorded result lands append-only, with its observation and outcome apart")
    func recordingAResult() throws {
        var model = model()
        let id = try builtExperiment(&model)
        model.startRecordingResult(id)
        model.resultDraft?.observation = "Cent prospects en 2,1 secondes, une erreur sur trois."
        model.resultDraft?.measurementValue = "2,1"
        model.resultDraft?.measurementUnit = "secondes"
        model.resultDraft?.limits = "L'erreur n'est pas expliquée."
        #expect(model.submitResult())
        let result = try #require(model.experiments(on: csv).last?.results.last)
        #expect(result.observation.contains("erreur sur trois"))
        #expect(result.measurements == [ExperimentMeasurement(value: 2.1, unit: "secondes")], "the French decimal point is understood")
        #expect(result.limits == "L'erreur n'est pas expliquée.")
        #expect(result.conclusion == .criterionMet)
        #expect(model.resultDraft == nil)
    }

    @Test("The selected evidence can be recorded as the result source")
    func resultKeepsItsSource() throws {
        var model = model()
        let source = ObjectID("object:sarah-viable")
        let id = try builtExperiment(&model)
        model.selection = [source]
        model.startRecordingResult(id)
        #expect(model.resultDraft?.sourceObjectID == source)
        model.resultDraft?.observation = "Le test a été lu dans cette preuve."
        #expect(model.submitResult())
        #expect(model.experiments(on: csv).last?.results.last?.sourceObjectID == source)
    }

    @Test("No observation records nothing and says why")
    func emptyObservationIsRefused() throws {
        var model = model()
        let id = try builtExperiment(&model)
        let before = model.document
        model.startRecordingResult(id)
        model.resultDraft?.observation = "  "
        #expect(model.submitResult() == false)
        #expect(model.document == before)
        #expect(model.resultDraft != nil, "the draft stays open")
    }

    @Test("An inconclusive answer without its reason is refused, with a reason")
    func inconclusiveNeedsReason() throws {
        var model = model()
        let id = try builtExperiment(&model)
        model.startRecordingResult(id)
        model.resultDraft?.observation = "Quelque chose a été observé."
        model.resultDraft?.inconclusive = true
        model.resultDraft?.inconclusiveReason = "   "
        #expect(model.submitResult() == false)
        #expect(model.status?.isEmpty == false)
        #expect(model.experiments(on: csv).last?.results.isEmpty == true)
    }

    @Test("A half-written measurement is refused, not dropped")
    func halfMeasurementIsRefused() throws {
        var model = model()
        let id = try builtExperiment(&model)
        model.startRecordingResult(id)
        model.resultDraft?.observation = "Observé."
        model.resultDraft?.measurementValue = "2,1"
        #expect(model.submitResult() == false, "a number with no unit is refused, not half-recorded")
        #expect(model.status?.isEmpty == false)
    }

    @Test("The learning is proposed about the selection, and accepting it is not here")
    func learningIsAProposal() throws {
        var model = model()
        let id = try builtExperiment(&model)
        model.startRecordingResult(id)
        model.resultDraft?.observation = "Observé."
        #expect(model.submitResult())

        model.selection = [ObjectID("object:sarah-viable")]
        model.setLearningDraft("À corriger avant de s'y fier.", for: id)
        #expect(model.submitLearningDraft(for: id))
        let finding = try #require(model.document.experiments.findings.first)
        #expect(finding.status == .proposed)
        #expect(finding.scopeObjectIDs == [ObjectID("object:sarah-viable")])
        #expect(model.learningDraft(for: id) == nil, "the draft is spent")

        // An empty learning proposes nothing.
        model.setLearningDraft("  ", for: id)
        #expect(model.submitLearningDraft(for: id) == false)
    }

    @Test("Escape closes the result draft one level at a time")
    func escapeClosesTheDraft() throws {
        var model = model()
        let id = try builtExperiment(&model)
        model.startRecordingResult(id)
        #expect(KollioModel.TransientLevel.topmost(in: model) == .resultDraft)
        #expect(model.dismissOneLevel() == .resultDraft)
        #expect(model.resultDraft == nil)
    }

    @Test("Undo removes exactly the recorded result")
    func undoRemovesTheResult() throws {
        var model = model()
        let id = try builtExperiment(&model)
        model.startRecordingResult(id)
        model.resultDraft?.observation = "Observé."
        #expect(model.submitResult())
        model.undo()
        #expect(model.experiments(on: csv).last?.results.isEmpty == true)
    }
}
