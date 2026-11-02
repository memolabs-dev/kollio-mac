import Foundation
import Testing
@testable import KollioCore

/// DEC-05: record a result, and keep the observation separate from what it means.
///
/// The acceptance criteria read as behaviours the type itself either allows or
/// refuses: the observation is not an automatic conclusion (AC01) because it
/// and the outcome are different fields and nothing derives one from the
/// other; missing data is visible (AC02) because an inconclusive result cannot
/// exist without its reason and a result can carry what the run could not do;
/// and the AI does not rewrite a supplied result (AC03) because there is no
/// rewrite command at all — recording appends, and proposals are refused the
/// whole family.
@Suite("A result is recorded, not concluded")
struct ExperimentResultTests {
    private func buildExperiment(_ store: inout KollioSession, id: ExperimentID = KollioID.experiment("exp-1")) {
        store.apply([.createExperiment(CreateExperiment(
            id: id,
            targetObjectID: KollioID.object("sarah-csv"),
            question: LocalizedText("L'export tient-il avec les tags ?"),
            successCriterion: LocalizedText("Cent prospects avec tags en moins de trois secondes"),
            expectedEvidence: [KollioID.object("sarah-viable")],
            provenance: .human("me")
        ))], label: "build experiment")
    }

    private func buildExperiment(_ store: inout DocumentStore, id: ExperimentID = KollioID.experiment("exp-1")) throws {
        try store.apply([.createExperiment(CreateExperiment(
            id: id,
            targetObjectID: KollioID.object("sarah-csv"),
            question: LocalizedText("L'export tient-il avec les tags ?"),
            successCriterion: LocalizedText("Cent prospects avec tags en moins de trois secondes"),
            expectedEvidence: [KollioID.object("sarah-viable")],
            provenance: .human("me")
        ))])
    }

    private func recordCommand(
        id: ExperimentID = KollioID.experiment("exp-1"),
        observation: String = "Cent prospects avec tags sont arrivés en 2,1 secondes, une fois sur trois une erreur 500.",
        measurements: [ExperimentMeasurement] = [ExperimentMeasurement(value: 2.1, unit: "secondes")],
        limits: String? = "L'erreur 111/300 n'est pas expliquée.",
        sourceObjectID: ObjectID? = nil,
        outcome: ExperimentResultVersion.Outcome = .inconclusive("Un tiers des requêtes échoue : trop peu de données fiables pour conclure."),
        provenance: Provenance = .human("me")
    ) -> Command {
        .recordExperimentResult(RecordExperimentResult(
            id: id,
            observation: observation,
            measurements: measurements,
            limits: limits,
            sourceObjectID: sourceObjectID,
            outcome: outcome,
            provenance: provenance
        ))
    }

    @Test("A recorded result appends, and the newest is the one the block shows")
    func recordingAppends() throws {
        var store = DocumentStore(document: Fixture.sarah())
        try buildExperiment(&store)
        try store.apply([recordCommand()])
        let experiment = try #require(store.document.experiments.experiment(KollioID.experiment("exp-1")))
        #expect(experiment.results.count == 1)
        #expect(experiment.results.last?.limits?.contains("111/300") == true, "the missing data is what the run could not do")
        #expect(experiment.results.last?.observation.contains("erreur 500") == true)
        #expect(experiment.results[0].recordedAt >= experiment.createdAt)

        // A second run appends; the first stays readable.
        try store.apply([recordCommand(
            measurements: [ExperimentMeasurement(value: 2.0, unit: "secondes")],
            limits: nil,
            outcome: .conclusive(.criterionMet)
        )])
        #expect(store.document.experiments.experiment(KollioID.experiment("exp-1"))?.results.count == 2)
        #expect(store.document.experiments.experiment(KollioID.experiment("exp-1"))?.results[0].observation.contains("erreur") == true)
    }

    @Test("AC01: the observation and the outcome are different fields, and nothing derives one from the other")
    func observationIsNotTheConclusion() throws {
        var store = DocumentStore(document: Fixture.sarah())
        try buildExperiment(&store)
        // A conclusive outcome whose observation says something else entirely:
        // refused by nothing, because they are separate acts of writing.
        try store.apply([recordCommand(
            observation: "La requête a mis 2,1 secondes et échoué une fois sur trois.",
            outcome: .conclusive(.criterionNotMet)
        )])
        let result = try #require(store.document.experiments.experiment(KollioID.experiment("exp-1"))?.results.last)
        #expect(result.observation.contains("2,1 secondes"))
        #expect(result.conclusion == .criterionNotMet)
        // The type carries no validity percentage at all, so none can be invented.
        #expect(Mirror(reflecting: result).children.allSatisfy { child -> Bool in
            String(describing: type(of: child.value)).contains("Double") == false || child.label != "validity"
        })
    }

    @Test("AC02: an inconclusive result cannot exist without its reason")
    func inconclusiveNeedsAReason() throws {
        var store = DocumentStore(document: Fixture.sarah())
        try buildExperiment(&store)
        #expect(throws: DocumentError.inconclusiveWithoutReason(KollioID.experiment("exp-1"))) {
            try store.apply([recordCommand(outcome: .inconclusive("   "))])
        }
        #expect(store.document.experiments.experiment(KollioID.experiment("exp-1"))?.results.isEmpty == true)
    }

    @Test("An observation with nothing observed is refused")
    func emptyObservationIsRefused() throws {
        var store = DocumentStore(document: Fixture.sarah())
        try buildExperiment(&store)
        #expect(throws: DocumentError.emptyObservation(KollioID.experiment("exp-1"))) {
            try store.apply([recordCommand(observation: "  ")])
        }
    }

    @Test("A measurement without a unit is refused, wherever the unit is empty")
    func unitlessMeasurementsAreRefused() throws {
        var store = DocumentStore(document: Fixture.sarah())
        try buildExperiment(&store)
        #expect(throws: DocumentError.measurementWithoutUnit(KollioID.experiment("exp-1"))) {
            try store.apply([recordCommand(measurements: [ExperimentMeasurement(value: 2.1, unit: "  ")])])
        }
    }

    @Test("A source that names nothing is refused, even in a conclusive result")
    func unknownSourceIsRefused() throws {
        var store = DocumentStore(document: Fixture.sarah())
        try buildExperiment(&store)
        #expect(throws: DocumentError.experimentSourceNotFound(KollioID.experiment("exp-1"), KollioID.object("ghost"))) {
            try store.apply([recordCommand(
                measurements: [],
                limits: nil,
                sourceObjectID: KollioID.object("ghost"),
                outcome: .conclusive(.criterionMet)
            )])
        }
    }

    @Test("Recording against a thing that does not exist is refused")
    func unknownExperimentIsRefused() {
        var store = DocumentStore(document: Fixture.sarah())
        #expect(throws: DocumentError.unknownExperiment(KollioID.experiment("ghost"))) {
            try store.apply([recordCommand(id: KollioID.experiment("ghost"))])
        }
    }

    @Test("A learning is proposed, references the result it came from, and cannot be empty")
    func proposingALearning() throws {
        var store = DocumentStore(document: Fixture.sarah())
        try buildExperiment(&store)
        try store.apply([recordCommand()])
        let beforeRevision = store.document.experiments.experiment(KollioID.experiment("exp-1"))?.results.count ?? 0

        try store.apply([.proposeLearning(ProposeLearning(
            id: FindingID("finding:1"),
            experimentID: KollioID.experiment("exp-1"),
            statement: LocalizedText("L'export tient, mais pas toujours : à corriger avant de s'y fier."),
            scopeObjectIDs: [KollioID.object("sarah-csv")],
            provenance: .human("me")
        ))])

        let finding = try #require(store.document.experiments.finding(FindingID("finding:1")))
        #expect(finding.status == .proposed, "a learning exists as a proposal, and as nothing else yet")
        #expect(finding.revisionIndex == beforeRevision - 1, "it names the version it learned from")
        #expect(finding.acceptedByDecision == nil)
    }

    @Test("A learning about nothing is refused, and one that says nothing too")
    func emptyLearningsAreRefused() throws {
        var store = DocumentStore(document: Fixture.sarah())
        try buildExperiment(&store)
        try store.apply([recordCommand()])

        #expect(throws: DocumentError.learningWithoutScope(FindingID("finding:1"))) {
            try store.apply([.proposeLearning(ProposeLearning(
                id: FindingID("finding:1"),
                experimentID: KollioID.experiment("exp-1"),
                statement: LocalizedText("Quelque chose"),
                scopeObjectIDs: [],
                provenance: .human("me")
            ))])
        }
        #expect(throws: DocumentError.emptyLearningStatement(FindingID("finding:2"))) {
            try store.apply([.proposeLearning(ProposeLearning(
                id: FindingID("finding:2"),
                experimentID: KollioID.experiment("exp-1"),
                statement: LocalizedText("   "),
                scopeObjectIDs: [KollioID.object("sarah-csv")],
                provenance: .human("me")
            ))])
        }
    }

    @Test("Accepting a learning requires a real decision about something the learning covers")
    func acceptanceNamesARealDecision() throws {
        var store = DocumentStore(document: Fixture.sarah())
        try buildExperiment(&store)
        try store.apply([recordCommand()])
        try store.apply([.proposeLearning(ProposeLearning(
            id: FindingID("finding:1"),
            experimentID: KollioID.experiment("exp-1"),
            statement: LocalizedText("À corriger avant de s'y fier."),
            scopeObjectIDs: [KollioID.object("sarah-csv")],
            provenance: .human("me")
        ))])

        // No decision yet: refused.
        #expect(throws: DocumentError.unknownDecision(DecisionID("decision:nope"))) {
            try store.apply([.acceptLearning(AcceptLearning(
                id: FindingID("finding:1"),
                decisionID: DecisionID("decision:nope"),
                provenance: .human("me")
            ))])
        }

        // A decision about something the learning does not cover: refused.
        try store.apply([.recordDecision(RecordDecision(
            id: DecisionID("decision:crm"),
            kind: .setAside,
            targetObjectID: KollioID.object("sarah-crm"),
            provenance: .human("me")
        ))])
        #expect(throws: DocumentError.decisionOutsideLearningScope(FindingID("finding:1"), DecisionID("decision:crm"))) {
            try store.apply([.acceptLearning(AcceptLearning(
                id: FindingID("finding:1"),
                decisionID: DecisionID("decision:crm"),
                provenance: .human("me")
            ))])
        }

        // A decision about something the learning covers: accepted.
        try store.apply([.recordDecision(RecordDecision(
            id: DecisionID("decision:csv"),
            kind: .setAside,
            targetObjectID: KollioID.object("sarah-csv"),
            provenance: .human("me")
        ))])
        try store.apply([.acceptLearning(AcceptLearning(
            id: FindingID("finding:1"),
            decisionID: DecisionID("decision:csv"),
            provenance: .human("me")
        ))])
        let finding = try #require(store.document.experiments.finding(FindingID("finding:1")))
        #expect(finding.status == .accepted)
        #expect(finding.acceptedByDecision == DecisionID("decision:csv"))
    }

    @Test("A learning cannot be accepted twice")
    func doubleAcceptanceIsRefused() throws {
        var store = DocumentStore(document: Fixture.sarah())
        try buildExperiment(&store)
        try store.apply([recordCommand()])
        try store.apply([.proposeLearning(ProposeLearning(
            id: FindingID("finding:1"),
            experimentID: KollioID.experiment("exp-1"),
            statement: LocalizedText("À corriger."),
            scopeObjectIDs: [KollioID.object("sarah-csv")],
            provenance: .human("me")
        ))])
        try store.apply([.recordDecision(RecordDecision(
            id: DecisionID("decision:csv"),
            kind: .setAside,
            targetObjectID: KollioID.object("sarah-csv"),
            provenance: .human("me")
        ))])
        try store.apply([.acceptLearning(AcceptLearning(
            id: FindingID("finding:1"),
            decisionID: DecisionID("decision:csv"),
            provenance: .human("me")
        ))])
        #expect(throws: DocumentError.learningAlreadyAccepted(FindingID("finding:1"))) {
            try store.apply([.acceptLearning(AcceptLearning(
                id: FindingID("finding:1"),
                decisionID: DecisionID("decision:csv"),
                provenance: .human("me")
            ))])
        }
    }

    @Test("AC03: intelligence may not record a result, propose a learning or accept one")
    func proposalsMayNotTouchResults() throws {
        let document = Fixture.sarah()
        var store = DocumentStore(document: document)
        try buildExperiment(&store)
        let withExperiment = store.document
        let commands: [Command] = [
            recordCommand(),
            .proposeLearning(ProposeLearning(
                id: FindingID("finding:x"),
                experimentID: KollioID.experiment("exp-1"),
                statement: LocalizedText("Conclu"),
                scopeObjectIDs: [KollioID.object("sarah-csv")],
                provenance: Provenance(actor: ActorID("model"), kind: .remoteModel, requestId: "r")
            ))
        ]
        for command in commands {
            let proposal = Proposal(
                proposalId: "proposal:x",
                requestId: "request:x",
                documentId: withExperiment.documentId,
                baseSemanticRevision: withExperiment.semanticRevision,
                summary: LocalizedText("Un résultat"),
                operations: [command],
                generator: .init(name: "test", deterministic: true)
            )
            #expect(throws: DocumentError.forbiddenOperation("results and learnings are the user's to record")) {
                try ProposalValidator().validate(
                    proposal,
                    against: withExperiment,
                    scope: ProposalRequest.Scope(maxOperations: 10, allowNewObjects: true)
                )
            }
        }
    }

    @Test("Recording a result is meaning, and undo removes exactly that")
    func semanticAndUndoable() throws {
        var session = KollioSession(document: Fixture.sarah())
        buildExperiment(&session)
        let semanticBefore = session.semanticRevision
        session.apply([recordCommand()], label: "record result")
        #expect(session.semanticRevision == semanticBefore + 1)

        let undone = session.undo()
        #expect(undone)
        #expect(session.document.experiments.experiment(KollioID.experiment("exp-1"))?.results.isEmpty == true)

        // And it survives a save and a reload.
        session.apply([recordCommand()], label: "record result")
        let reloaded = try DocumentCodec.decode(DocumentCodec.encode(session.document))
        #expect(reloaded.experiments.experiment(KollioID.experiment("exp-1"))?.results.count == 1)
    }
}
