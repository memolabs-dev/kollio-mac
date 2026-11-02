import Foundation
import Testing
@testable import KollioCore

/// DEC-04: build a validation experiment, and keep it honest.
///
/// The three acceptance criteria read as questions the document must be able
/// to answer without being asked twice: the criterion a person committed to
/// stays readable (AC01), a link to evidence names a thing the document holds
/// and not a hope (AC02), and editing after a result exists produces a visible
/// revision rather than a rewritten past (AC03). Everything else below is one
/// of the ways the block could have been built to lie, refused at the only
/// place refusing is worth anything.
@Suite("Validation experiments are built before they run")
struct ExperimentTests {
    private func createCommand(
        id: ExperimentID = KollioID.experiment("exp-1"),
        target: ObjectID = KollioID.object("sarah-csv"),
        question: String = "L'export CSV tient-il avec les tags ?",
        criterion: String = "Les tags arrivent dans l'export sans requête supplémentaire",
        evidence: [ObjectID] = [KollioID.object("sarah-viable")],
        provenance: Provenance = .human("me")
    ) -> Command {
        .createExperiment(CreateExperiment(
            id: id,
            targetObjectID: target,
            question: LocalizedText(question),
            successCriterion: LocalizedText(criterion),
            expectedEvidence: evidence,
            provenance: provenance
        ))
    }

    @Test("An experiment is created on a real reasoning, with its first revision")
    func creationAndFirstRevision() throws {
        var store = DocumentStore(document: Fixture.sarah())
        try store.apply([createCommand()])

        let experiment = store.document.experiments.experiment(KollioID.experiment("exp-1"))
        #expect(experiment != nil)
        #expect(experiment?.targetObjectID == KollioID.object("sarah-csv"))
        #expect(experiment?.revisions.count == 1, "the creation is revision zero")
        #expect(experiment?.currentRevision.successCriterion.text.isEmpty == false)
        #expect(store.document.experiments.experiments(targeting: KollioID.object("sarah-csv")).count == 1)
    }

    @Test("AC01: the criterion committed before any result stays readable after edits")
    func criteriaAreKeptBeforeTheResult() throws {
        var store = DocumentStore(document: Fixture.sarah())
        try store.apply([createCommand()])

        let original = try #require(store.document.experiments.experiment(KollioID.experiment("exp-1"))?.currentRevision.successCriterion)
        try store.apply([.editExperiment(EditExperiment(
            id: KollioID.experiment("exp-1"),
            question: LocalizedText("L'export tient-il, et à quelle vitesse ?"),
            method: LocalizedText("Charger cent prospects avec tags"),
            successCriterion: LocalizedText("Cent prospects en moins de trois secondes"),
            expectedEvidence: [KollioID.object("sarah-viable")],
            provenance: .human("me")
        ))])

        let edited = try #require(store.document.experiments.experiment(KollioID.experiment("exp-1")))
        #expect(edited.revisions.count == 2, "editing appends, it never rewrites")
        #expect(edited.revision(0)?.successCriterion == original, "the first commitment is untouched")
        #expect(edited.currentRevision.successCriterion.text.contains("trois secondes"))
    }

    @Test("AC02: a link to evidence names a thing the document holds")
    func evidenceLinksAreReal() {
        var store = DocumentStore(document: Fixture.sarah())
        #expect(throws: DocumentError.unknownObject(KollioID.object("ghost"))) {
            try store.apply([createCommand(evidence: [KollioID.object("ghost")])])
        }
        #expect(store.document.experiments.experiment(KollioID.experiment("exp-1")) == nil)
    }

    @Test("AC03: editing after a result appends a visible experiment revision")
    func editingAfterAResultCreatesARevision() throws {
        let id = KollioID.experiment("exp-1")
        var store = DocumentStore(document: Fixture.sarah())
        try store.apply([createCommand(id: id)])
        try store.apply([.recordExperimentResult(RecordExperimentResult(
            id: id,
            observation: "Le test a traité cent prospects.",
            measurements: [ExperimentMeasurement(value: 2.1, unit: "secondes")],
            outcome: .conclusive(.criterionMet),
            provenance: .human("tester")
        ))])
        try store.apply([.editExperiment(EditExperiment(
            id: id,
            question: LocalizedText("Le test tient-il aussi avec mille prospects ?"),
            method: LocalizedText("Charger mille prospects avec tags"),
            successCriterion: LocalizedText("Mille prospects en moins de dix secondes"),
            expectedEvidence: [KollioID.object("sarah-viable")],
            provenance: .human("tester")
        ))])

        let experiment = try #require(store.document.experiments.experiment(id))
        #expect(experiment.results.count == 1)
        #expect(experiment.revisions.count == 2)
        #expect(experiment.revision(0)?.successCriterion.text.contains("tags arrivent") == true)
        #expect(experiment.currentRevision.successCriterion.text.contains("dix secondes"))
    }

    @Test("The same evidence linked twice is refused, not counted twice")
    func duplicatedEvidenceLinkIsRefused() {
        var store = DocumentStore(document: Fixture.sarah())
        #expect(throws: DocumentError.duplicateEvidenceLink(KollioID.experiment("exp-1"), KollioID.object("sarah-viable"))) {
            try store.apply([createCommand(evidence: [
                KollioID.object("sarah-viable"),
                KollioID.object("sarah-viable")
            ])])
        }
    }

    @Test("A criterion that judges nothing is refused")
    func emptyCriterionIsRefused() {
        var store = DocumentStore(document: Fixture.sarah())
        #expect(throws: DocumentError.emptyExperimentCriterion(KollioID.experiment("exp-1"))) {
            try store.apply([createCommand(criterion: "   ")])
        }
    }

    @Test("A question nobody asked is refused")
    func emptyQuestionIsRefused() {
        var store = DocumentStore(document: Fixture.sarah())
        #expect(throws: DocumentError.emptyExperimentQuestion(KollioID.experiment("exp-1"))) {
            try store.apply([createCommand(question: "")])
        }
    }

    @Test("An experiment cannot be attached to a thing that does not exist")
    func targetMustExist() {
        var store = DocumentStore(document: Fixture.sarah())
        #expect(throws: DocumentError.decisionTargetNotFound(KollioID.object("ghost"))) {
            try store.apply([createCommand(target: KollioID.object("ghost"))])
        }
    }

    @Test("The same experiment id cannot be built twice")
    func duplicateExperimentIsRefused() throws {
        var store = DocumentStore(document: Fixture.sarah())
        try store.apply([createCommand()])
        #expect(throws: DocumentError.duplicateExperiment(KollioID.experiment("exp-1"))) {
            try store.apply([createCommand()])
        }
    }

    @Test("A second experiment on the same reasoning is a second question, not an error")
    func multipleExperimentsPerTarget() throws {
        var store = DocumentStore(document: Fixture.sarah())
        try store.apply([
            createCommand(id: KollioID.experiment("exp-a")),
            createCommand(id: KollioID.experiment("exp-b"), criterion: "Les tags arrivent en un appel")
        ])
        #expect(store.document.experiments.experiments(targeting: KollioID.object("sarah-csv")).count == 2)
    }

    @Test("Editing a thing that does not exist is refused")
    func editingUnknownIsRefused() {
        var store = DocumentStore(document: Fixture.sarah())
        #expect(throws: DocumentError.unknownExperiment(KollioID.experiment("ghost"))) {
            try store.apply([.editExperiment(EditExperiment(
                id: KollioID.experiment("ghost"),
                question: LocalizedText("q"),
                successCriterion: LocalizedText("c"),
                provenance: .human("me")
            ))])
        }
    }

    @Test("An experiment survives a save, a quit and a reload")
    func experimentSurvivesSaveAndReload() throws {
        var session = KollioSession(document: Fixture.sarah())
        session.apply([createCommand()], label: "build experiment")
        let reloaded = try DocumentCodec.decode(try DocumentCodec.encode(session.document))
        let experiment = try #require(reloaded.experiments.experiment(KollioID.experiment("exp-1")))
        #expect(experiment.revisions.count == 1)
        #expect(experiment.currentRevision.successCriterion.text.isEmpty == false)

        // A file written before experiments existed decodes to a document that
        // built none, which is the truth about it rather than a file to repair.
        var json = try JSONSerialization.jsonObject(with: try DocumentCodec.encode(session.document)) as! [String: Any]
        json["experiments"] = nil
        let oldFile = try JSONSerialization.data(withJSONObject: json)
        #expect(try DocumentCodec.decode(oldFile).experiments.experiments.isEmpty)
    }

    @Test("Creating an experiment is meaning, not layout")
    func creationIsSemantic() {
        #expect(Command.createExperiment(CreateExperiment(
            id: KollioID.experiment("x"),
            targetObjectID: KollioID.object("sarah-csv"),
            question: LocalizedText("q"),
            successCriterion: LocalizedText("c"),
            provenance: .human("me")
        )).isSemantic)
    }

    @Test("An experiment is a person's to build: intelligence may not propose one")
    func proposalsMayNotBuildExperiments() throws {
        let document = Fixture.sarah()
        let proposal = Proposal(
            proposalId: "proposal:exp",
            requestId: "request:exp",
            documentId: document.documentId,
            baseSemanticRevision: document.semanticRevision,
            summary: LocalizedText("Une expérience"),
            rationale: LocalizedText("Une expérience"),
            operations: [createCommand()],
            generator: .init(name: "test", deterministic: true)
        )
        #expect(throws: DocumentError.forbiddenOperation("experiments are the user's to build")) {
            try ProposalValidator().validate(
                proposal,
                against: document,
                scope: ProposalRequest.Scope(maxOperations: 10, allowNewObjects: true)
            )
        }
    }

    @Test("Undo returns the document to before the experiment existed")
    func undoRemovesTheExperiment() throws {
        var session = KollioSession(document: Fixture.sarah())
        let applied = session.apply([createCommand()], label: "build experiment")
        let undone = session.undo()
        #expect(applied)
        #expect(undone)
        #expect(session.document.experiments.experiment(KollioID.experiment("exp-1")) == nil)
    }
}
