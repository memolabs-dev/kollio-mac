import Foundation

public enum DocumentError: Error, Equatable, CustomStringConvertible {
    case emptyDocumentTitle
    case unknownObject(ObjectID)
    case unknownRelationship(RelationshipID)
    case unknownInstance(InstanceID)
    case unknownContribution(ActorID)
    case duplicateObject(ObjectID)
    case duplicateRelationship(RelationshipID)
    case duplicateInstance(InstanceID)
    case selfRelationship(RelationshipID)
    case missingInstanceForObject(ObjectID)
    case emptyText(ObjectID)
    case unknownDecision(DecisionID)
    case duplicateDecision(DecisionID)
    /// An assessment with nothing in it. Applying it would record a decision about
    /// a question nobody asked.
    case nothingToReview
    case unknownFrame(FrameID)
    case duplicateFrame(FrameID)
    /// An occurrence cannot be put in a frame that is not drawn. Naming one would
    /// mean a frame could hold something the canvas cannot show, which is the
    /// opposite of an explicit member.
    case unknownInstanceForFrame(InstanceID)
    /// A drawing cannot be in two frames. Two overlapping frames are fine, but a
    /// fold would then have to guess which one owns the drawing, and one of the two
    /// would hide something the person expected to see.
    case occurrenceAlreadyFramed(InstanceID, FrameID)
    /// A cell wants a number and the criterion has no measure. AC01 refused at the
    /// only place where refusing is worth anything.
    case criterionHasNoMeasure(CriterionID)
    // A synthesis, its sections and its lines. Each refusal below is one of the
    // ways a synthesis could have lied, named so the interface can explain itself.
    case unknownSummary(SummaryID)
    case duplicateSummary(SummaryID)
    case emptySummaryTitle(SummaryID)
    case emptySummaryLine(SummaryLineID)
    /// An engine line that rests on nothing.
    case unsupportedSummaryAssertion(SummaryLineID)
    /// A section that says nothing was recorded and carries lines anyway.
    case contradictorySummarySection(SummaryID)
    /// A section that is present but neither says something nor declares absence.
    case silentSummarySection(SummaryID, SummaryArtifact.Section)
    case unknownComparison(ComparisonID)
    case unknownCriterion(CriterionID)
    case duplicateComparison(ComparisonID)
    /// A cell recorded against a criterion the person has not confirmed. A draft is
    /// a question, and a question cannot hold a value.
    case comparisonIsDraft(ComparisonID)
    case notAComparisonDirection(ComparisonID, ObjectID)
    /// A weight that is not a number a person could mean.
    case invalidWeight(Double)
    /// A measure with no unit, which would let a number exist without saying what it
    /// counts.
    case emptyMeasureUnit(CriterionID)
    /// A comparison over fewer than two directions, which compares nothing.
    case comparisonNeedsTwoDirections(ComparisonID)
    case decisionTargetNotFound(ObjectID)
    // An experiment, its fields and its evidence links. Each refusal below is
    // one of the ways an experiment could have been built to lie: a question
    // nobody asked, a criterion that judges nothing, a link to a thing that is
    // not there.
    case unknownExperiment(ExperimentID)
    case duplicateExperiment(ExperimentID)
    case emptyExperimentQuestion(ExperimentID)
    case emptyExperimentCriterion(ExperimentID)
    /// The same evidence linked twice, which would make the block count one
    /// thing twice when a result is judged.
    case duplicateEvidenceLink(ExperimentID, ObjectID)
    // A result and a learning. Each refusal below is one of the ways a result
    // could have lied: an observation with nothing observed, a shrug of an
    // inconclusive answer, a number with no unit, a learning proposed about
    // nothing, and an acceptance pointing at a decision that is not there or
    // is not about the learning's scope.
    case emptyObservation(ExperimentID)
    case inconclusiveWithoutReason(ExperimentID)
    case measurementWithoutUnit(ExperimentID)
    /// The result names where the numbers came from, and the document does not
    /// hold it. Kept apart from the source ledger's own error because the two
    /// recover differently.
    case experimentSourceNotFound(ExperimentID, ObjectID)
    case emptyLearningStatement(FindingID)
    case learningWithoutScope(FindingID)
    case unknownFinding(FindingID)
    case learningAlreadyAccepted(FindingID)
    case decisionOutsideLearningScope(FindingID, DecisionID)
    case staleProposal(reason: String)
    /// Someone else changed this object's text after the writer last looked.
    /// Named apart from a stale proposal because the recovery is different: a
    /// person has to choose between two texts, not recalculate a branch.
    case staleObjectText(id: ObjectID, expected: Int, actual: Int)
    /// The last drawing of an object was removed, which would leave the idea
    /// invisible rather than gone. Removing the idea is a different decision
    /// and has to be taken as one.
    case lastOccurrence(ObjectID)
    /// A decision still points at this object, so removing it would orphan a
    /// durable record. The decision is revoked first, never silently dropped.
    case objectHasDecision(ObjectID, DecisionID)
    case tooManyOperations(Int)
    case forbiddenOperation(String)
    case unknownContributionReference(ObjectID, ActorID)
    case invalidShareRange(Double)
    case duplicateSource(SourceID)
    case unknownSource(SourceID)
    case unknownSourceRevision(SourceID, SourceRevisionID)
    case unknownCitation(CitationID)
    /// The import ran and produced nothing usable, so the previous version stays
    /// active. Named rather than folded into a generic failure because "your file
    /// has no text layer" and "that file is gone" call for different reactions.
    case sourceExtractionFailed(SourceID)
    /// A claim with nothing in its scope. Refused rather than treated as
    /// "everything", because that reading would make a constraint a law of the
    /// universe.
    case emptyScope(ClaimID)
    case unknownClaim(ClaimID)
    /// An assessment on something that is not a hypothesis, or a resolution on
    /// something that is not a constraint.
    case wrongClaimRole(ClaimID, expected: String)
    case duplicateClaim(ClaimID)
    case duplicateClarification(ClarificationID)
    case emptyClarification(ClarificationID)
    case alreadyAnswered(ClarificationID)
    case unknownClarification(ClarificationID)
    /// A reverse was asked for on a pair it was not requested for, so it would have
    /// turned into a different link.
    case relationshipEditPreconditionFailed(RelationshipID, RelationshipEditPrecondition)

    public var description: String {
        switch self {
        case .emptyDocumentTitle: return "Document title cannot be empty"
        case .unknownObject(let id): return "Unknown object \(id)"
        case .unknownRelationship(let id): return "Unknown relationship \(id)"
        case .unknownInstance(let id): return "Unknown instance \(id)"
        case .unknownContribution(let id): return "Unknown contribution \(id)"
        case .duplicateObject(let id): return "Duplicate object \(id)"
        case .duplicateRelationship(let id): return "Duplicate relationship \(id)"
        case .duplicateInstance(let id): return "Duplicate instance \(id)"
        case .selfRelationship(let id): return "Relationship \(id) points at itself"
        case .missingInstanceForObject(let id): return "No visual instance for object \(id)"
        case .emptyText(let id): return "Object \(id) has empty text"
        case .unknownDecision(let id): return "Unknown decision \(id)"
        case .duplicateDecision(let id): return "Duplicate decision \(id)"
        case .nothingToReview: return "That assessment has nothing to review"
        case .unknownFrame(let id): return "Unknown frame \(id)"
        case .duplicateFrame(let id): return "Duplicate frame \(id)"
        case .unknownInstanceForFrame(let id): return "Frame member \(id) is not drawn anywhere"
        case .occurrenceAlreadyFramed(let instance, let frame):
            return "\(instance) is already in frame \(frame)"
        case .criterionHasNoMeasure(let id):
            return "Criterion \(id) has no measure, so it cannot hold a number"
        case .unknownSummary(let id): return "Unknown synthesis \(id)"
        case .duplicateSummary(let id): return "Synthesis \(id) already exists"
        case .emptySummaryTitle(let id): return "Synthesis \(id) has no title"
        case .emptySummaryLine(let id): return "Line \(id) is empty"
        case .unsupportedSummaryAssertion(let id):
            return "Line \(id) came from a model and rests on nothing"
        case .contradictorySummarySection(let id):
            return "Synthesis \(id) says a section is empty and fills it"
        case .silentSummarySection(let id, let section):
            return "Synthesis \(id) has a \(section.rawValue) section that says nothing"
        case .unknownComparison(let id): return "Unknown comparison \(id)"        case .unknownCriterion(let id): return "Unknown criterion \(id)"
        case .duplicateComparison(let id): return "Duplicate comparison \(id)"
        case .comparisonIsDraft(let id):
            return "Comparison \(id) is still a draft: confirm its criteria first"
        case .notAComparisonDirection(let comparison, let object):
            return "\(object) is not a direction of comparison \(comparison)"
        case .invalidWeight(let value): return "Invalid weight \(value)"
        case .emptyMeasureUnit(let id): return "Criterion \(id) has no unit to measure in"
        case .comparisonNeedsTwoDirections(let id):
            return "Comparison \(id) compares fewer than two directions"
        case .decisionTargetNotFound(let id): return "Decision target \(id) not found"
        case .staleProposal(let reason): return "Stale proposal: \(reason)"
        case .objectHasDecision(let object, let decision):
            return "Object \(object) is the target of decision \(decision); revoke or reopen it first"
        case .lastOccurrence(let id):
            return "Object \(id) has only one occurrence left; removing it would hide the idea rather than remove it"
        case .staleObjectText(let id, let expected, let actual):
            return "Object \(id) was edited by someone else: expected version \(expected), found \(actual)"
        case .tooManyOperations(let n): return "Too many operations: \(n)"
        case .forbiddenOperation(let name): return "Forbidden operation \(name)"
        case .unknownContributionReference(let object, let contribution): return "Object \(object) references unknown contribution \(contribution)"
        case .invalidShareRange(let value): return "Invalid share \(value)"
        case .duplicateSource(let id): return "Duplicate source \(id)"
        case .unknownSource(let id): return "Unknown source \(id)"
        case .unknownSourceRevision(let source, let revision): return "Source \(source) has no revision \(revision)"
        case .unknownCitation(let id): return "Unknown citation \(id)"
        case .sourceExtractionFailed(let id): return "Source \(id) produced no readable text; the previous version stays active"
        case .emptyScope(let id): return "Claim \(id) has an empty scope, so it would apply to everything"
        case .unknownClaim(let id): return "Unknown claim \(id)"
        case .wrongClaimRole(let id, let expected): return "Claim \(id) is not a \(expected)"
        case .duplicateClaim(let id): return "Duplicate claim \(id)"
        case .duplicateClarification(let id): return "Duplicate clarification \(id)"
        case .emptyClarification(let id): return "Clarification \(id) has no question"
        case .alreadyAnswered(let id): return "Clarification \(id) already has an answer"
        case .unknownExperiment(let id): return "Unknown experiment \(id)"
        case .duplicateExperiment(let id): return "Duplicate experiment \(id)"
        case .emptyExperimentQuestion(let id): return "Experiment \(id) has no question"
        case .emptyExperimentCriterion(let id): return "Experiment \(id) has no success criterion"
        case .duplicateEvidenceLink(let experiment, let object):
            return "Experiment \(experiment) links evidence \(object) twice"
        case .emptyObservation(let id): return "Experiment \(id) has no observation"
        case .inconclusiveWithoutReason(let id): return "Experiment \(id) is inconclusive without saying what is missing"
        case .measurementWithoutUnit(let id): return "Experiment \(id) has a measurement with no unit"
        case .experimentSourceNotFound(let experiment, let object):
            return "Experiment \(experiment) names source \(object), which the document does not hold"
        case .emptyLearningStatement(let id): return "Learning \(id) says nothing"
        case .learningWithoutScope(let id): return "Learning \(id) applies to nothing"
        case .unknownFinding(let id): return "Unknown learning \(id)"
        case .learningAlreadyAccepted(let id): return "Learning \(id) was already accepted"
        case .decisionOutsideLearningScope(let learning, let decision):
            return "Decision \(decision) is not about anything learning \(learning) covers"
        case .unknownClarification(let id): return "Unknown clarification \(id)"
        case .relationshipEditPreconditionFailed(let id, let reason): return "Cannot edit \(id): \(reason)"
        }
    }
}

/// The only way a document changes.
///
/// A transaction either fully succeeds or fails: the store mutates a value copy
/// and only publishes it when every command has been applied.
public struct DocumentStore: Sendable {
    public private(set) var document: KollioDocument

    public init(document: KollioDocument = KollioDocument()) {
        self.document = document
    }

    public var revision: Int { document.revision }
    public var semanticRevision: Int { document.semanticRevision }

    @discardableResult
    public mutating func apply(
        _ commands: [Command],
        at date: Date = Date(),
        undoLabel: String? = nil
    ) throws -> KollioDocument {
        guard !commands.isEmpty else { return document }
        _ = undoLabel
        let date = date.kollioNormalized
        var candidate = document
        var changedSemantics = false

        for command in commands {
            try Self.applyCommand(command, to: &candidate, at: date)
            changedSemantics = changedSemantics || command.isSemantic
        }

        candidate.revision += 1
        if changedSemantics {
            candidate.semanticRevision += 1
        }
        candidate.updatedAt = date
        document = candidate
        return document
    }

    public mutating func replace(with newDocument: KollioDocument) {
        document = newDocument
    }

    // MARK: - Command application

    private static func applyCommand(_ command: Command, to document: inout KollioDocument, at date: Date) throws {
        switch command {
        case .renameDocument(let rename):
            let title = rename.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard title.isEmpty == false else { throw DocumentError.emptyDocumentTitle }
            document.title = title
        case .createObject(let create):
            try createObject(create, in: &document)
        case .updateObjectText(let update):
            try updateObjectText(update, in: &document)
        case .addRelationship(let add):
            try addRelationship(add, in: &document)
        case .removeRelationship(let remove):
            try removeRelationship(remove, from: &document)
        case .moveNodeInstances(let moves):
            try move(moves, in: &document)
        case .duplicateObject(let duplicate):
            try duplicateObject(duplicate, in: &document)
        case .duplicateNodeInstance(let duplicate):
            try duplicateNodeInstance(duplicate, in: &document)
        case .removeObject(let remove):
            try removeObject(remove, from: &document)
        case .removeNodeInstance(let remove):
            try removeNodeInstance(remove, from: &document)
        case .createScenario(let scenario):
            try createScenario(scenario, in: &document, at: date)
        case .recordDecision(let decision):
            try recordDecision(decision, in: &document, at: date)
        case .revokeDecision(let revoke):
            try revokeDecision(revoke, in: &document)
        case .addContributionToProduct(let add):
            try addContribution(add, in: &document)
        case .applyProposal(let apply):
            try applyProposal(apply, in: &document, at: date)
        case .rejectProposal(let reject):
            // see note in applyCommand
            _ = reject
        case .attachSource(let attach):
            try attachSource(attach, in: &document)
        case .importSourceRevision(let importRevision):
            try importSourceRevision(importRevision, in: &document)
        case .addCitation(let citation):
            try addCitation(citation, in: &document)
        case .recordVerification(let verification):
            try recordVerification(verification, in: &document)
        case .removeSource(let remove):
            try removeSource(remove, in: &document)
        case .assertClaim(let assertion):
            try assertClaim(assertion, in: &document)
        case .assessHypothesis(let assessment):
            try assessHypothesis(assessment, in: &document)
        case .resolveConstraint(let resolution):
            try resolveConstraint(resolution, in: &document)
        case .askClarification(let ask):
            try askClarification(ask, in: &document)
        case .answerClarification(let answer):
            try answerClarification(answer, in: &document)
        case .markClarificationUnknown(let unknown):
            try markClarificationUnknown(unknown, in: &document)
        case .editRelationship(let edit):
            try editRelationship(edit, in: &document)
        case .applyImpact(let impact):
            try applyImpact(impact, in: &document, at: date)
        case .createFrame(let create):
            try createFrame(create, in: &document)
        case .renameFrame(let rename):
            try renameFrame(rename, in: &document)
        case .setFrameMembers(let members):
            try setFrameMembers(members, in: &document)
        case .moveFrame(let move):
            try moveFrame(move, in: &document)
        case .setFrameFolded(let folded):
            try setFrameFolded(folded, in: &document)
        case .removeFrame(let remove):
            try removeFrame(remove, from: &document)
        case .startComparison(let start):
            try startComparison(start, in: &document)
        case .setComparisonCriteria(let criteria):
            try setComparisonCriteria(criteria, in: &document)
        case .confirmComparisonCriteria(let confirm):
            try confirmComparisonCriteria(confirm, in: &document)
        case .recordComparisonCell(let record):
            try recordComparisonCell(record, in: &document)
        case .setCriterionWeight(let weight):
            try setCriterionWeight(weight, in: &document)
        case .setCriterionMeasure(let measure):
            try setCriterionMeasure(measure, in: &document)
        case .keepDirection(let keep):
            try keepDirection(keep, in: &document)
        case .startSummary(let start):
            try startSummary(start, in: &document)
        case .setSummaryLine(let line):
            try setSummaryLine(line, in: &document)
        case .setSummarySection(let section):
            try setSummarySection(section, in: &document)
        case .confirmSummary(let confirm):
            try confirmSummary(confirm, in: &document)
        case .removeSummary(let remove):
            try removeSummary(remove, from: &document)
        case .createExperiment(let create):
            try createExperiment(create, in: &document, at: date)
        case .editExperiment(let edit):
            try editExperiment(edit, in: &document, at: date)
        case .recordExperimentResult(let record):
            try recordExperimentResult(record, in: &document, at: date)
        case .proposeLearning(let propose):
            try proposeLearning(propose, in: &document, at: date)
        case .acceptLearning(let accept):
            try acceptLearning(accept, in: &document, at: date)
        case .restoreDocument(let restore):
            try restoreDocument(restore, in: &document)
        }
    }

    /// Replaces every authored and presented part of the document while keeping
    /// the identity, revision clock and append-only journal of the live file.
    /// Decoding happens before the inout document is changed, so malformed or
    /// foreign snapshots leave the transaction untouched.
    private static func restoreDocument(_ command: RestoreDocument, in document: inout KollioDocument) throws {
        let restored: KollioDocument
        do {
            restored = try DocumentCodec.decode(command.snapshot)
        } catch {
            throw DocumentError.forbiddenOperation("restore snapshot is unreadable")
        }
        guard restored.documentId == document.documentId else {
            throw DocumentError.forbiddenOperation("restore snapshot belongs to another document")
        }

        document.content = restored.content
        document.relationships = restored.relationships
        document.decisions = restored.decisions
        document.contributions = restored.contributions
        document.products = restored.products
        document.presentation = restored.presentation
        document.sources = restored.sources
        document.claims = restored.claims
        document.clarifications = restored.clarifications
        document.comparisons = restored.comparisons
        document.summaries = restored.summaries
        document.experiments = restored.experiments
    }

    private static func createExperiment(_ command: CreateExperiment, in document: inout KollioDocument, at date: Date) throws {
        // Attached to the reasoning means attached to a thing that exists.
        guard document.content[command.targetObjectID] != nil else {
            throw DocumentError.decisionTargetNotFound(command.targetObjectID)
        }
        // Whitespace-only is empty in meaning, and the document does not store
        // meaning that is not there.
        guard command.question.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw DocumentError.emptyExperimentQuestion(command.id)
        }
        guard command.successCriterion.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw DocumentError.emptyExperimentCriterion(command.id)
        }
        try validateEvidenceLinks(command.expectedEvidence, of: command.id, in: document)
        guard document.experiments.experiment(command.id) == nil else {
            throw DocumentError.duplicateExperiment(command.id)
        }
        let experiment = Experiment(
            id: command.id,
            targetObjectID: command.targetObjectID,
            question: command.question,
            method: command.method,
            successCriterion: command.successCriterion,
            expectedEvidence: command.expectedEvidence,
            owner: command.owner,
            dueDate: command.dueDate,
            isSimulation: command.isSimulation,
            createdAt: date,
            provenance: command.provenance
        )
        document.experiments.experiments[experiment.id] = experiment
    }

    private static func editExperiment(_ command: EditExperiment, in document: inout KollioDocument, at date: Date) throws {
        guard var experiment = document.experiments.experiment(command.id) else {
            throw DocumentError.unknownExperiment(command.id)
        }
        guard command.question.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw DocumentError.emptyExperimentQuestion(command.id)
        }
        guard command.successCriterion.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw DocumentError.emptyExperimentCriterion(command.id)
        }
        try validateEvidenceLinks(command.expectedEvidence, of: command.id, in: document)

        experiment.revisions.append(ExperimentRevision(
            question: command.question,
            method: command.method,
            successCriterion: command.successCriterion,
            expectedEvidence: command.expectedEvidence,
            provenance: command.provenance,
            recordedAt: date
        ))
        // The live fields follow the newest revision, so a reader of the block
        // and a reader of the revision list can never disagree.
        experiment.question = command.question
        experiment.method = command.method
        experiment.successCriterion = command.successCriterion
        experiment.expectedEvidence = command.expectedEvidence
        document.experiments.experiments[command.id] = experiment
    }

    private static func recordExperimentResult(_ command: RecordExperimentResult, in document: inout KollioDocument, at date: Date) throws {
        guard var experiment = document.experiments.experiment(command.id) else {
            throw DocumentError.unknownExperiment(command.id)
        }
        // AC01 lives at this guard: the observation is what the person wrote
        // after running something, and a whitespace field has nothing in it.
        guard command.observation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw DocumentError.emptyObservation(command.id)
        }
        for measurement in command.measurements {
            guard measurement.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw DocumentError.measurementWithoutUnit(command.id)
            }
        }
        if let source = command.sourceObjectID {
            guard document.content[source] != nil else {
                throw DocumentError.experimentSourceNotFound(command.id, source)
            }
        }
        switch command.outcome {
        case .inconclusive(let reason):
            guard reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw DocumentError.inconclusiveWithoutReason(command.id)
            }
        case .conclusive:
            break
        }
        experiment.results.append(ExperimentResultVersion(
            observation: command.observation,
            measurements: command.measurements,
            limits: command.limits,
            sourceObjectID: command.sourceObjectID,
            outcome: command.outcome,
            provenance: command.provenance,
            recordedAt: date
        ))
        document.experiments.experiments[command.id] = experiment
    }

    private static func proposeLearning(_ command: ProposeLearning, in document: inout KollioDocument, at date: Date) throws {
        guard let experiment = document.experiments.experiment(command.experimentID) else {
            throw DocumentError.unknownExperiment(command.experimentID)
        }
        guard command.statement.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw DocumentError.emptyLearningStatement(command.id)
        }
        // A learning proposed about nothing applies to nothing, and nothing is
        // the one scope the command layer refuses everywhere.
        guard command.scopeObjectIDs.isEmpty == false else {
            throw DocumentError.learningWithoutScope(command.id)
        }
        for objectID in command.scopeObjectIDs {
            guard document.content[objectID] != nil else {
                throw DocumentError.unknownObject(objectID)
            }
        }
        let finding = LearnedFinding(
            id: command.id,
            statement: command.statement,
            experimentID: experiment.id,
            revisionIndex: experiment.results.count - 1,
            scopeObjectIDs: command.scopeObjectIDs,
            proposedAt: date,
            provenance: command.provenance
        )
        document.experiments.experiments[command.experimentID]?.findings.append(finding)
    }

    private static func acceptLearning(_ command: AcceptLearning, in document: inout KollioDocument, at date: Date) throws {
        _ = date
        guard let finding = document.experiments.finding(command.id) else {
            throw DocumentError.unknownFinding(command.id)
        }
        guard let decision = document.decisions[command.decisionID] else {
            throw DocumentError.unknownDecision(command.decisionID)
        }
        guard finding.status == .proposed else {
            throw DocumentError.learningAlreadyAccepted(command.id)
        }
        // The decision must be about something the learning covers. A learning
        // about the export route cannot be accepted by a decision about the
        // CRM connection; that would be accepting one thing by naming another.
        let decisionCoversScope = finding.scopeObjectIDs.contains(decision.targetObjectID)
        guard decisionCoversScope else {
            throw DocumentError.decisionOutsideLearningScope(command.id, command.decisionID)
        }
        if var experiment = document.experiments.experiment(finding.experimentID) {
            guard let index = experiment.findings.firstIndex(where: { $0.id == command.id }) else { return }
            experiment.findings[index].status = .accepted
            experiment.findings[index].acceptedByDecision = decision.id
            document.experiments.experiments[finding.experimentID] = experiment
        }
    }

    /// Every expected-evidence link must name an object the document holds, and    /// Every expected-evidence link must name an object the document holds, and
    /// name it once. A link to a thing that is not there is not a link, it is a
    /// hope, and the document does not store hopes.
    private static func validateEvidenceLinks(_ ids: [ObjectID], of experiment: ExperimentID, in document: KollioDocument) throws {
        var seen: Set<ObjectID> = []
        for id in ids {
            guard document.content[id] != nil else {
                throw DocumentError.unknownObject(id)
            }
            guard seen.insert(id).inserted else {
                throw DocumentError.duplicateEvidenceLink(experiment, id)
            }
        }
    }

    private static func startSummary(_ start: StartSummary, in document: inout KollioDocument) throws {
        let summary = start.summary
        guard document.summaries.summary(summary.id) == nil else {
            throw DocumentError.duplicateSummary(summary.id)
        }
        try validate(summary, in: document)
        var ledger = document.summaries
        // Always stored as a draft. A synthesis that arrived confirmed would let
        // an engine hand over a deliverable without anybody agreeing to it, and
        // the draft is the only thing standing between a proposal and authority.
        var stored = summary
        stored.isDraft = true
        ledger.upsert(stored)
        document.summaries = ledger
    }

    private static func setSummaryLine(_ set: SetSummaryLine, in document: inout KollioDocument) throws {
        guard var summary = document.summaries.summary(set.summaryID) else {
            throw DocumentError.unknownSummary(set.summaryID)
        }
        var line = set.line
        guard !line.text.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DocumentError.emptySummaryLine(line.id)
        }
        // AC01. A line that already exists keeps the text it had, and the person
        // who replaced it is recorded. Without this, an edit is indistinguishable
        // from a generation and "the initial text stays intact" is a claim nobody
        // can check.
        if let existing = summary.line(line.id) {
            line.originalText = existing.originalText ?? existing.text
            // The person who replaced it. The first version kept the original
            // text and forgot the author of the edit, which made a correction
            // indistinguishable from a line nobody had touched.
            line.editedBy = set.provenance.actor
        }
        try validateLine(line, in: document)

        // The objective is the person's purpose and is written once, at open. A
        // later write to it through a section would be ambiguous about which of
        // the two it meant, so it is refused rather than guessed at.
        guard line.id != summary.objective.id else {
            throw DocumentError.forbiddenOperation("the objective is written when the synthesis opens")
        }
        var section = summary.sections(set.section).first {
            $0.lines.contains { $0.id == line.id }
        } ?? SummaryArtifact.SummarySection(set.section)
        if let index = section.lines.firstIndex(where: { $0.id == line.id }) {
            section.lines[index] = line
        } else {
            section.lines.append(line)
        }
        section.lines.sort { $0.id.rawValue < $1.id.rawValue }
        // Writing a line makes the section no longer a declaration of absence:
        // the person has now said something about it.
        section.isNothingRecorded = false
        summary = summary.settingSections([section], for: set.section)
        var ledger = document.summaries
        ledger.upsert(summary)
        document.summaries = ledger
    }

    private static func setSummarySection(
        _ set: SetSummarySection,
        in document: inout KollioDocument
    ) throws {
        guard var summary = document.summaries.summary(set.summaryID) else {
            throw DocumentError.unknownSummary(set.summaryID)
        }
        var section = set.section
        // A declaration of nothing recorded and a section with lines contradict
        // each other, and the contradiction is refused rather than resolved: a
        // person who means both has not decided what they mean.
        if section.isNothingRecorded && !section.lines.isEmpty {
            throw DocumentError.contradictorySummarySection(set.summaryID)
        }
        for line in section.lines { try validateLine(line, in: document) }
        section.lines.sort { $0.id.rawValue < $1.id.rawValue }
        summary = summary.settingSections([section], for: set.kind)
        var ledger = document.summaries
        ledger.upsert(summary)
        document.summaries = ledger
    }

    private static func confirmSummary(
        _ confirm: ConfirmSummary,
        in document: inout KollioDocument
    ) throws {
        guard var summary = document.summaries.summary(confirm.summaryID) else {
            throw DocumentError.unknownSummary(confirm.summaryID)
        }
        guard summary.isDraft else { return }
        // Every section has to have said something, or said that there was nothing
        // to say. A confirmed template with silent blanks is exactly what "the AI
        // does not fabricate conclusions to fill a template" forbids, and this is
        // where it is checked.
        for section in SummaryArtifact.Section.allCases {
            let value = summary.sections(section)
            if value.isEmpty {
                throw DocumentError.silentSummarySection(confirm.summaryID, section)
            }
            if value.allSatisfy({ $0.lines.isEmpty && !$0.isNothingRecorded }) {
                throw DocumentError.silentSummarySection(confirm.summaryID, section)
            }
        }
        try validate(summary, in: document)
        summary.isDraft = false
        // The revision the claim is made about. Confirming is itself a semantic
        // change and moves the revision by one, so the revision the claim covers
        // is the one *after* this command. Reading it off the document as it stands
        // here would record a revision the synthesis has never described, and the
        // staleness check would fire immediately on a document nobody has touched.
        summary.confirmedAtSemanticRevision = document.semanticRevision + 1
        var ledger = document.summaries
        ledger.upsert(summary)
        document.summaries = ledger
    }

    private static func removeSummary(_ remove: RemoveSummary, from document: inout KollioDocument) throws {
        guard document.summaries.summary(remove.summaryID) != nil else {
            throw DocumentError.unknownSummary(remove.summaryID)
        }
        var ledger = document.summaries
        ledger.remove(remove.summaryID)
        document.summaries = ledger
    }

    /// The source that carries a revision, or nothing.
    ///
    /// A `SourceRevision` names its source, but the ledger is keyed by source, so
    /// the lookup goes the other way round. It is spelled out here rather than
    /// guessed at by prefix, because a source id is not a prefix of every
    /// revision id in general and a lookup that assumed it would accept a
    /// revision belonging to a source that had been removed.
    private static func findSource(
        of revision: SourceRevisionID,
        in document: KollioDocument
    ) -> SourceID? {
        for (id, source) in document.sources.sources where source.revision(revision) != nil {
            return id
        }
        return nil
    }

    private static func validate(_ summary: SummaryArtifact, in document: KollioDocument) throws {
        if summary.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw DocumentError.emptySummaryTitle(summary.id)
        }
        for object in summary.readSet.objectIDs where document.content[object] == nil {
            throw DocumentError.unknownObject(object)
        }
        for revision in summary.readSet.sourceRevisionIDs
        where findSource(of: revision, in: document) == nil {
            throw DocumentError.unknownSourceRevision(SourceID(revision.rawValue), revision)
        }
        for ref in summary.sourceRefs {
            guard document.sources.source(ref.sourceID) != nil else {
                throw DocumentError.unknownSource(ref.sourceID)
            }
            guard findSource(of: ref.revisionID, in: document) == nil else { continue }
            throw DocumentError.unknownSourceRevision(ref.sourceID, ref.revisionID)
        }
        try validateLine(summary.objective, in: document)
        for line in summary.allLines.dropFirst() { try validateLine(line, in: document) }
    }

    private static func validateLine(
        _ line: SummaryArtifact.SummaryLine,
        in document: KollioDocument
    ) throws {
        guard !line.text.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DocumentError.emptySummaryLine(line.id)
        }
        // An engine line that rests on nothing is an assertion, and an assertion
        // with no reference is the shape a fabricated conclusion takes. A person's
        // own line needs no reference: they are the source.
        guard !line.isUnsupportedAssertion else {
            throw DocumentError.unsupportedSummaryAssertion(line.id)
        }
        for reference in line.references {
            switch reference.kind {
            case .object:
                guard document.content[ObjectID(reference.id)] != nil else {
                    throw DocumentError.unknownObject(ObjectID(reference.id))
                }
            case .source, .citation:
                break
            case .claim, .decision, .note:
                break
            }
        }
    }

    private static func createObject(_ create: CreateObject, in document: inout KollioDocument) throws {
        guard document.content[create.id] == nil else { throw DocumentError.duplicateObject(create.id) }
        guard !create.text.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DocumentError.emptyText(create.id)
        }
        if let contributionID = create.contributionID, document.contributions[contributionID] == nil {
            throw DocumentError.unknownContributionReference(create.id, contributionID)
        }
        let object = ContentObject(
            id: create.id,
            kind: create.kind,
            text: create.text,
            detail: create.detail,
            contributionID: create.contributionID,
            provenance: create.provenance
        )
        document.content[create.id] = object
        document.presentation.instances.append(
            NodeInstance(
                id: InstanceID("instance:\(create.id.rawValue)"),
                objectID: create.id,
                position: create.position ?? .zero,
                size: create.size
            )
        )
    }

    private static func updateObjectText(_ update: UpdateObjectText, in document: inout KollioDocument) throws {
        guard var object = document.content[update.id] else { throw DocumentError.unknownObject(update.id) }
        guard !update.text.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DocumentError.emptyText(update.id)
        }
        // The version check is what makes a concurrent edit a question instead of a
        // silent overwrite. It runs before anything is written, so a refusal leaves
        // the object exactly as it was.
        if let expected = update.expectedVersion, expected != object.objectVersion {
            throw DocumentError.staleObjectText(id: update.id, expected: expected, actual: object.objectVersion)
        }
        guard object.text != update.text || object.detail != update.detail else {
            // Nothing actually changed, so the version does not move. A version that
            // rises on a no-op would make every writer look stale for no reason.
            return
        }
        object.text = update.text
        object.detail = update.detail
        object.provenance = update.provenance
        object.objectVersion += 1
        document.content[update.id] = object
    }

    private static func addRelationship(_ add: AddRelationship, in document: inout KollioDocument) throws {
        guard document.content[add.from] != nil else { throw DocumentError.unknownObject(add.from) }
        guard document.content[add.to] != nil else { throw DocumentError.unknownObject(add.to) }
        guard add.from != add.to else { throw DocumentError.selfRelationship(add.id) }
        guard document.relationships[add.id] == nil else { throw DocumentError.duplicateRelationship(add.id) }
        document.relationships[add.id] = Relationship(
            id: add.id,
            from: add.from,
            to: add.to,
            kind: add.kind,
            label: add.label,
            fromAnchor: add.fromAnchor,
            toAnchor: add.toAnchor,
            provenance: add.provenance
        )
    }

    private static func removeRelationship(_ remove: RemoveRelationship, from document: inout KollioDocument) throws {
        guard document.relationships.removeValue(forKey: remove.id) != nil else {
            throw DocumentError.unknownRelationship(remove.id)
        }
    }

    private static func move(_ move: MoveNodeInstances, in document: inout KollioDocument) throws {
        for one in move.moves {
            guard let index = document.presentation.instances.firstIndex(where: { $0.id == one.instanceID }) else {
                throw DocumentError.unknownInstance(one.instanceID)
            }
            document.presentation.instances[index].position = one.position
        }
    }

    /// A second occurrence of one object.
    ///
    /// Nothing here copies an object, a contribution or a share, and that is the
    /// whole of AC01: a person who puts the same thing in two places has not
    /// created a second author or a second claim. If the source is a reference to
    /// somebody else's contribution, the copy is a reference to the *same*
    /// contribution id, which is what makes the share count stay at one.
    private static func duplicateNodeInstance(
        _ duplicate: DuplicateNodeInstance,
        in document: inout KollioDocument
    ) throws {
        guard let source = document.presentation.instance(id: duplicate.instanceID) else {
            throw DocumentError.unknownInstance(duplicate.instanceID)
        }
        guard document.presentation.instance(id: duplicate.id) == nil else {
            throw DocumentError.duplicateInstance(duplicate.id)
        }
        document.presentation.instances.append(
            NodeInstance(
                id: duplicate.id,
                objectID: source.objectID,
                position: duplicate.position ?? source.position,
                size: source.size,
                hidden: source.hidden
            )
        )
    }

    /// A variant: a new object, related to the one it came from.
    ///
    /// The text is copied because a variant starts as the same thought, and the
    /// `contributionID` is copied as a *reference*. The contribution record itself
    /// is never touched, so two variants of a contributed object still owe the
    /// original owner one share between them, not two.
    private static func duplicateObject(
        _ duplicate: DuplicateObject,
        in document: inout KollioDocument
    ) throws {
        guard let source = document.content[duplicate.sourceID] else {
            throw DocumentError.unknownObject(duplicate.sourceID)
        }
        guard document.content[duplicate.id] == nil else {
            throw DocumentError.duplicateObject(duplicate.id)
        }
        guard document.relationships[duplicate.relationshipID] == nil else {
            throw DocumentError.duplicateRelationship(duplicate.relationshipID)
        }
        var copy = source
        copy.id = duplicate.id
        copy.provenance = duplicate.provenance
        // A fresh object has never been edited, so it starts at zero rather than
        // inheriting the version of the thing it was copied from.
        copy.objectVersion = 0
        document.content[duplicate.id] = copy

        if let contributionID = source.contributionID, document.contributions[contributionID] == nil {
            throw DocumentError.unknownContributionReference(duplicate.id, contributionID)
        }

        let origin = document.presentation.instance(for: duplicate.sourceID)
        document.presentation.instances.append(
            NodeInstance(
                id: duplicate.instanceID,
                objectID: duplicate.id,
                position: duplicate.position ?? origin?.position ?? .zero,
                size: origin?.size
            )
        )
        try addRelationship(
            AddRelationship(
                id: duplicate.relationshipID,
                from: duplicate.id,
                to: duplicate.sourceID,
                kind: .derivedFrom,
                provenance: duplicate.provenance
            ),
            in: &document
        )
    }

    /// Removes one occurrence and keeps the idea.
    private static func removeNodeInstance(
        _ remove: RemoveNodeInstance,
        from document: inout KollioDocument
    ) throws {
        guard let index = document.presentation.instances.firstIndex(where: { $0.id == remove.instanceID }) else {
            throw DocumentError.unknownInstance(remove.instanceID)
        }
        // The last occurrence of an object is not an occurrence any more: removing
        // it would leave a node with nothing drawing it, and the next save would
        // write a document nobody can see. That is a decision to remove the idea,
        // so it is refused here and has to be asked for as `removeObject`.
        let objectID = document.presentation.instances[index].objectID
        let remaining = document.presentation.instances.filter { $0.objectID == objectID }.count
        guard remaining > 1 else {
            throw DocumentError.lastOccurrence(objectID)
        }
        document.presentation.instances.remove(at: index)
    }

    /// Removes an object from the document, with everything that pointed at it.
    ///
    /// A decision that set an object aside keeps its memory, so a decision pointing
    /// here is a reason to refuse rather than to clean up: removing the object would
    /// leave a durable record about something that no longer exists, and deciding
    /// what that record meant is the owner's call, not a side effect. Revoke or
    /// reopen the decision first.
    private static func removeObject(
        _ remove: RemoveObject,
        from document: inout KollioDocument
    ) throws {
        guard document.content[remove.id] != nil else {
            throw DocumentError.unknownObject(remove.id)
        }
        if let decision = document.decisions.values.first(where: { $0.targetObjectID == remove.id }) {
            throw DocumentError.objectHasDecision(remove.id, decision.id)
        }
        document.content[remove.id] = nil
        for (id, relationship) in document.relationships where
            relationship.from == remove.id || relationship.to == remove.id {
            document.relationships[id] = nil
        }
        document.presentation.instances.removeAll { $0.objectID == remove.id }
    }

    private static func createScenario(_ scenario: CreateScenario, in document: inout KollioDocument, at date: Date) throws {
        var context = scenario.context
        context.position = scenario.rootPosition
        try createObject(context, in: &document)
        for child in scenario.children {
            try createObject(child, in: &document)
        }
        for link in scenario.links {
            try addRelationship(link, in: &document)
        }
        _ = date
    }

    /// Records a durable decision. `setAside` collapses the branch without
    /// deleting anything; `reopened` restores it exactly as it was, positions
    /// included.
    private static func recordDecision(_ command: RecordDecision, in document: inout KollioDocument, at date: Date) throws {
        // An impact is only ever recorded together with the assessment that produced
        // it, so that the reasons travel with the mark. Accepting a bare `.impacted`
        // here would allow a durable "look again" with nothing behind it, which is
        // the badge-with-no-observation this document refuses everywhere else.
        guard command.kind != .impacted else {
            throw DocumentError.forbiddenOperation("an impact is applied with the assessment that produced it")
        }
        guard let target = document.content[command.targetObjectID] else {
            throw DocumentError.decisionTargetNotFound(command.targetObjectID)
        }

        var branch: Set<ObjectID> = []
        switch command.kind {
        case .setAside, .kept:
            branch = document.exclusiveDescendants(of: command.targetObjectID)
        case .reopened:
            branch = Set(
                document.decisions.values
                    .filter { $0.targetObjectID == command.targetObjectID && $0.kind == .setAside }
                    .flatMap(\.branchObjectIDs)
                    .map { ObjectID($0.rawValue) }
            )
            if branch.isEmpty { branch = [command.targetObjectID] }
        case .impacted:
            // Unreachable: refused above. `applyImpact` writes this kind itself, and
            // it names the one object rather than walking a branch.
            branch = [command.targetObjectID]
        }

        // A new decision supersedes the previous active decision on the same target.
        for (id, decision) in document.decisions
        where decision.targetObjectID == command.targetObjectID && decision.status == .active {
            var superseded = decision
            superseded.status = .superseded
            document.decisions[id] = superseded
        }

        let decision = Decision(
            id: command.id,
            kind: command.kind,
            targetObjectID: command.targetObjectID,
            branchObjectIDs: branch.sorted { $0.rawValue < $1.rawValue },
            rationale: command.rationale,
            createdAt: date,
            provenance: command.provenance
        )
        document.decisions[command.id] = decision

        switch command.kind {
        case .setAside:
            for id in branch {
                guard var object = document.content[id] else { continue }
                object.lifecycle = .setAside
                object.setAsideByDecision = command.id
                document.content[id] = object
            }
        case .reopened:
            for id in branch {
                guard var object = document.content[id] else { continue }
                // Only restore what this decision actually closed.
                guard object.setAsideByDecision != nil else { continue }
                object.lifecycle = .active
                object.setAsideByDecision = nil
                document.content[id] = object
            }
        case .kept:
            break
        case .impacted:
            // Unreachable: refused at the top of this function. Listed rather than
            // folded into `default` so that adding a fifth kind is a compile error
            // here instead of a silently unhandled decision.
            break
        }
        _ = target
    }

    private static func revokeDecision(_ revoke: RevokeDecision, in document: inout KollioDocument) throws {
        guard var decision = document.decisions[revoke.id] else { throw DocumentError.unknownDecision(revoke.id) }
        decision.status = .superseded
        document.decisions[revoke.id] = decision
        if decision.kind == .setAside {
            let branch: [ObjectID] = decision.branchObjectIDs.map { ObjectID($0.rawValue) }
            for id in branch {
                guard var object = document.content[id] else { continue }
                guard object.setAsideByDecision == revoke.id else { continue }
                object.lifecycle = .active
                object.setAsideByDecision = nil
                document.content[id] = object
            }
        }
    }

    private static func addContribution(_ add: AddContributionToProduct, in document: inout KollioDocument) throws {
        guard document.contributions[add.contributionID] != nil else {
            throw DocumentError.unknownContribution(add.contributionID)
        }
        guard (0...1).contains(add.share) else { throw DocumentError.invalidShareRange(add.share) }
        var product = document.products[add.productID] ?? ProductComposition(
            id: add.productID,
            name: document.content[add.productID]?.text ?? LocalizedText(add.productID.rawValue)
        )
        if !product.memberContributionIDs.contains(add.contributionID) {
            product.memberContributionIDs.append(add.contributionID)
        }
        product.shares[add.contributionID.rawValue] = add.share
        document.products[add.productID] = product
    }

    private static func applyProposal(_ apply: ApplyProposal, in document: inout KollioDocument, at date: Date) throws {
        let validator = ProposalValidator()
        try validator.validate(apply.proposal, against: document, scope: .init(maxOperations: 32, allowNewObjects: true))

        for operation in apply.proposal.operations {
            try applyCommand(operation, to: &document, at: date)
        }
        for (objectID, position) in apply.placements {
            guard let instance = document.presentation.instance(for: objectID) else { continue }
            if let index = document.presentation.instances.firstIndex(where: { $0.id == instance.id }) {
                document.presentation.instances[index].position = position
            }
        }
        _ = apply.provenance
    }

    private static func createdObjectID(_ command: Command) -> ObjectID? {
        if case .createObject(let create) = command { return create.id }
        return nil
    }
}

/// Rejecting a proposal never touches the document: a proposal that was never
/// kept has no branch on the canvas. Setting a *kept* branch aside is a durable
/// decision, expressed with `RecordDecision`, so it keeps its rationale and can be
/// reopened.
extension DocumentStore {
    public static func setAsideProposalReason(for reject: RejectProposal) -> RejectProposal.RejectReason {
        reject.reason
    }

    // MARK: - Sources and citations

    private static func attachSource(_ attach: AttachSource, in document: inout KollioDocument) throws {
        guard document.sources.source(attach.source.id) == nil else {
            throw DocumentError.duplicateSource(attach.source.id)
        }
        if let target = attach.attachedTo, document.content[target] == nil {
            // A source attached to nothing in particular is legitimate, so this is
            // only refused when an attachment was named and does not exist.
            throw DocumentError.unknownObject(target)
        }
        document.sources.add(attach.source)
    }

    private static func importSourceRevision(
        _ importRevision: ImportSourceRevision,
        in document: inout KollioDocument
    ) throws {
        // The attempt is recorded even when it produced nothing, because "we read it
        // and there is no text" is a fact a person needs. What must not happen is a
        // broken import replacing a good earlier version, and the ledger decides
        // that rather than this function.
        switch document.sources.importRevision(importRevision.revision, for: importRevision.sourceID) {
        case .imported:
            return
        case .rejected(.unknownSource):
            throw DocumentError.unknownSource(importRevision.sourceID)
        }
    }

    private static func addCitation(_ add: AddCitation, in document: inout KollioDocument) throws {
        guard document.content[add.claimID] != nil else {
            throw DocumentError.unknownObject(add.claimID)
        }
        // The claim named by the command is the claim recorded on the citation. Two
        // places to state one thing would be two places to disagree.
        var citation = add.citation
        citation.claimID = add.claimID
        switch document.sources.cite(citation) {
        case .success:
            return
        case .failure(.unknownSource):
            throw DocumentError.unknownSource(citation.sourceID)
        case .failure(.unknownRevision(let revision)):
            throw DocumentError.unknownSourceRevision(citation.sourceID, revision)
        case .failure(.unknownCitation(let citation)):
            throw DocumentError.unknownCitation(citation)
        }
    }

    private static func recordVerification(
        _ verification: RecordVerification,
        in document: inout KollioDocument
    ) throws {
        guard verification.observation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            // A verification with nothing to say is not a verification.
            throw DocumentError.forbiddenOperation("a verification needs an observation")
        }
        switch document.sources.recordVerification(
            verification.citationID,
            observation: verification.observation,
            by: verification.author,
            at: verification.at
        ) {
        case .success:
            return
        case .failure:
            throw DocumentError.unknownCitation(verification.citationID)
        }
    }

    private static func removeSource(_ remove: RemoveSource, in document: inout KollioDocument) throws {
        guard document.sources.source(remove.sourceID) != nil else {
            throw DocumentError.unknownSource(remove.sourceID)
        }
        // The history stays. What is lost is the ability to check quietly, and every
        // citation says so.
        document.sources.removeSourceKeepingHistory(remove.sourceID)
    }

    // MARK: - Claims

    private static func assertClaim(_ assertion: AssertClaim, in document: inout KollioDocument) throws {
        let claim = assertion.claim
        guard document.content[claim.objectID] != nil else {
            throw DocumentError.unknownObject(claim.objectID)
        }
        // Every object the claim is about has to exist, or the scope names things
        // the document has never heard of.
        for object in claim.scope.objectIDs where document.content[object] == nil {
            throw DocumentError.unknownObject(object)
        }
        guard claim.scope.objectIDs.isEmpty == false else {
            throw DocumentError.emptyScope(claim.id)
        }
        guard document.claims.claim(claim.id) == nil else {
            throw DocumentError.duplicateClaim(claim.id)
        }
        var ledger = document.claims
        ledger.upsert(claim)
        document.claims = ledger
    }

    private static func assessHypothesis(
        _ assessment: AssessHypothesis,
        in document: inout KollioDocument
    ) throws {
        guard var claim = document.claims.claim(assessment.claimID) else {
            throw DocumentError.unknownClaim(assessment.claimID)
        }
        guard claim.role == .hypothesis else {
            throw DocumentError.wrongClaimRole(assessment.claimID, expected: "hypothesis")
        }
        // The evidence is required here rather than in the type alone, because a
        // caller can build the enum by hand and `.supported` needs an observation.
        if let evidence = assessment.assessment.evidence {
            guard evidence.observation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw DocumentError.forbiddenOperation("an assessment needs an observation")
            }
        }
        claim.assessment = assessment.assessment
        // Assessing a hypothesis never resolves a constraint: the two stay apart.
        var ledger = document.claims
        ledger.upsert(claim)
        document.claims = ledger
        // The person has now said how it stands, so the mark that said "look again"
        // has been looked at. Nothing about the earlier record is erased; it becomes
        // superseded, which is the same thing that happens to a decision a person
        // has replaced.
        clearImpactReview(on: claim.objectID, in: &document)
    }

    private static func resolveConstraint(
        _ resolution: ResolveConstraint,
        in document: inout KollioDocument
    ) throws {
        guard var claim = document.claims.claim(resolution.claimID) else {
            throw DocumentError.unknownClaim(resolution.claimID)
        }
        guard claim.role == .constraint else {
            throw DocumentError.wrongClaimRole(resolution.claimID, expected: "constraint")
        }
        if let evidence = resolution.resolution.evidence {
            guard evidence.observation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw DocumentError.forbiddenOperation("a resolution needs an observation")
            }
        }
        claim.resolution = resolution.resolution
        var ledger = document.claims
        ledger.upsert(claim)
        document.claims = ledger
        clearImpactReview(on: claim.objectID, in: &document)
    }

    // MARK: - Clarifications

    private static func askClarification(_ ask: AskClarification, in document: inout KollioDocument) throws {
        let clarification = ask.clarification
        guard document.content[clarification.objectID] != nil else {
            throw DocumentError.unknownObject(clarification.objectID)
        }
        guard !clarification.question.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DocumentError.emptyClarification(clarification.id)
        }
        guard document.clarifications.clarification(clarification.id) == nil else {
            throw DocumentError.duplicateClarification(clarification.id)
        }
        var ledger = document.clarifications
        ledger.upsert(clarification)
        document.clarifications = ledger
    }

    private static func answerClarification(
        _ answer: AnswerClarification,
        in document: inout KollioDocument
    ) throws {
        guard var clarification = document.clarifications.clarification(answer.clarificationID) else {
            throw DocumentError.unknownClarification(answer.clarificationID)
        }
        let text = answer.text.trimmingCharacters(in: .whitespacesAndNewlines)
        // An empty field is not sent as a fact. It is refused here rather than
        // stored as a blank answer, because a blank answer in the document reads as
        // something a person considered and had nothing to say about.
        guard text.isEmpty == false else {
            throw DocumentError.emptyClarification(answer.clarificationID)
        }
        clarification.state = .answered(.init(
            text: text,
            by: answer.provenance.actor,
            at: answer.provenance.kind == .human ? Date() : Date(timeIntervalSince1970: 0)
        ))
        var ledger = document.clarifications
        ledger.upsert(clarification)
        document.clarifications = ledger
    }

    private static func markClarificationUnknown(
        _ unknown: MarkClarificationUnknown,
        in document: inout KollioDocument
    ) throws {
        guard var clarification = document.clarifications.clarification(unknown.clarificationID) else {
            throw DocumentError.unknownClarification(unknown.clarificationID)
        }
        // A reason is optional here. "I do not know" is a complete answer; being
        // pressed for a reason would turn an honest gap back into a task.
        clarification.state = .unknown(unknown.reason ?? "")
        var ledger = document.clarifications
        ledger.upsert(clarification)
        document.clarifications = ledger
    }

    // MARK: - Editing a relationship

    private static func editRelationship(_ edit: EditRelationship, in document: inout KollioDocument) throws {
        guard var relationship = document.relationships[edit.id] else {
            throw DocumentError.unknownRelationship(edit.id)
        }
        // The precondition is part of the request, not a hope. A reverse names the
        // pair it was asked about, so it cannot be applied to whatever happens to be
        // at that identifier later.
        if let precondition = edit.edit.precondition(for: relationship) {
            guard precondition.isSatisfied(relationship) else {
                throw DocumentError.relationshipEditPreconditionFailed(edit.id, precondition)
            }
        }
        switch edit.edit {
        case .retitle(let label):
            relationship.label = label
        case .changeKind(let kind):
            relationship.kind = kind
        case .reverse:
            // The swap is the edit. A self-relation cannot be produced by reversing
            // one, but a link that was made between two different objects and now
            // has a single object on both ends is refused rather than stored.
            let (first, second) = (relationship.from, relationship.to)
            guard first != second else { throw DocumentError.selfRelationship(edit.id) }
            relationship.from = second
            relationship.to = first
        }
        relationship.provenance = edit.provenance
        document.relationships[edit.id] = relationship
    }

    // MARK: - Impact of new information

    /// Records the objects an assessment marks, one precise decision each.
    ///
    /// What this deliberately does **not** do is the thing CTX-05 names as the
    /// failure mode. It does not set anything aside, does not clear a lifecycle,
    /// does not remove an object, and does not supersede a decision a person took
    /// earlier. A branch whose ground moved is still a branch, and the honest state
    /// of it is "look again", which is exactly what a durable record of "look again"
    /// says.
    ///
    /// The rationale carries the reason and the path rather than a bare flag, so a
    /// person reading the record months later can see *why* this object is marked
    /// and what it was marked because of, without re-running the walk.
    private static func applyImpact(
        _ impact: ApplyImpact,
        in document: inout KollioDocument,
        at date: Date
    ) throws {
        let assessment = impact.assessment
        guard assessment.proposedChanges.isEmpty == false else {
            throw DocumentError.nothingToReview
        }
        guard impact.decisionIDs.count == assessment.proposedChanges.count else {
            throw DocumentError.forbiddenOperation("an assessment needs one decision per impacted object")
        }
        for decisionID in impact.decisionIDs where document.decisions[decisionID] != nil {
            throw DocumentError.duplicateDecision(decisionID)
        }
        for change in assessment.proposedChanges {
            guard document.content[change.objectID] != nil else {
                throw DocumentError.unknownObject(change.objectID)
            }
        }

        for (change, decisionID) in zip(assessment.proposedChanges, impact.decisionIDs) {
            document.decisions[decisionID] = Decision(
                id: decisionID,
                kind: .impacted,
                targetObjectID: change.objectID,
                // Exactly the one object, never the branch it sits in. The whole
                // point is that marking is precise: a decision whose
                // `branchObjectIDs` named the branch would be the purge this
                // command refuses to perform.
                branchObjectIDs: [change.objectID],
                rationale: LocalizedText(change.reason.rationale),
                createdAt: date,
                provenance: impact.provenance
            )
        }
    }

    /// Marks an assessment as looked at, on the object it was about.
    ///
    /// Called by the two commands that record a person taking a position. A mark
    /// that no stance can ever clear is a mark that never goes away, which is
    /// another way of saying the review does not matter.
    private static func clearImpactReview(on objectID: ObjectID, in document: inout KollioDocument) {
        for (id, decision) in document.decisions
        where decision.kind == .impacted && decision.status == .active && decision.targetObjectID == objectID {
            var looked = decision
            looked.status = .superseded
            document.decisions[id] = looked
        }
    }
}


// MARK: - Frames
//
// A frame is presentation. Nothing in this section may touch an object's text, its
// lifecycle, a claim, a citation or a decision, and none of it moves
// `semanticRevision`, which is enforced by `Command.isSemantic` rather than by
// remembering to be careful here.

extension DocumentStore {
    private static func createFrame(_ create: CreateFrame, in document: inout KollioDocument) throws {
        guard document.presentation.frame(create.frame.id) == nil else {
            throw DocumentError.duplicateFrame(create.frame.id)
        }
        // The members are checked up front, so a frame can never exist holding a
        // drawing that does not exist. An *empty* frame is fine: the specification
        // says it stays until the user chooses otherwise.
        try validate(members: create.frame.memberInstanceIDs, of: create.frame.id, in: document)
        var presentation = document.presentation
        presentation.setFrame(create.frame)
        document.presentation = presentation
    }

    private static func renameFrame(_ rename: RenameFrame, in document: inout KollioDocument) throws {
        var frame = try requireFrame(rename.id, in: document)
        // Only the frame's own name. A member's text, and the quote of a citation
        // made from a source it names, are somebody else's words.
        guard frame.name != rename.name else { return }
        frame.name = rename.name
        var presentation = document.presentation
        presentation.setFrame(frame)
        document.presentation = presentation
    }

    private static func setFrameMembers(
        _ members: SetFrameMembers,
        in document: inout KollioDocument
    ) throws {
        var frame = try requireFrame(members.id, in: document)
        try validate(members: members.memberInstanceIDs, of: members.id, in: document)
        // Membership is replaced, never merged, so removing an occurrence from a
        // frame is possible at all.
        frame.memberInstanceIDs = members.memberInstanceIDs
        var presentation = document.presentation
        presentation.setFrame(frame)
        document.presentation = presentation
    }

    /// One delta for every member, so the shape inside the frame is preserved
    /// exactly. Two overlapping frames cause no cascade: each moves only the
    /// occurrences it holds, and an occurrence belongs to at most one frame.
    private static func moveFrame(_ move: MoveFrame, in document: inout KollioDocument) throws {
        var frame = try requireFrame(move.id, in: document)
        try validate(members: frame.memberInstanceIDs, of: frame.id, in: document)
        for index in document.presentation.instances.indices
        where frame.contains(document.presentation.instances[index].id) {
            document.presentation.instances[index].position = document.presentation.instances[index].position
                .offset(dx: move.delta.x, dy: move.delta.y)
        }
        // The frame travels with its contents, so it never has to be told twice
        // where its members are.
        frame.position = frame.position.offset(dx: move.delta.x, dy: move.delta.y)
        var presentation = document.presentation
        presentation.setFrame(frame)
        document.presentation = presentation
    }

    /// Hides or shows the members in this view. `lifecycle` is deliberately not
    /// touched: folding is not "set aside", it is not a decision, and undoing it
    /// must never reopen a branch a person actually closed.
    private static func setFrameFolded(
        _ folded: SetFrameFolded,
        in document: inout KollioDocument
    ) throws {
        var frame = try requireFrame(folded.id, in: document)
        guard frame.isFolded != folded.isFolded else { return }
        frame.isFolded = folded.isFolded
        var presentation = document.presentation
        presentation.setFrame(frame)
        document.presentation = presentation
    }

    private static func removeFrame(_ remove: RemoveFrame, from document: inout KollioDocument) throws {
        guard document.presentation.frame(remove.id) != nil else {
            throw DocumentError.unknownFrame(remove.id)
        }
        // The members stay. Removing a frame is removing the frame.
        var presentation = document.presentation
        presentation.removeFrame(remove.id)
        document.presentation = presentation
    }

    private static func requireFrame(_ id: FrameID, in document: KollioDocument) throws -> Frame {
        guard let frame = document.presentation.frame(id) else {
            throw DocumentError.unknownFrame(id)
        }
        return frame
    }

    private static func validate(
        members: [InstanceID],
        of frame: FrameID,
        in document: KollioDocument
    ) throws {
        for member in members {
            guard document.presentation.instance(id: member) != nil else {
                throw DocumentError.unknownInstanceForFrame(member)
            }
            // One drawing, one frame. Checked here rather than left to the caller,
            // because "the model keeps it straight" is exactly how a folded canvas
            // ends up hiding a drawing somebody is looking for.
            if let other = document.presentation.frame(containing: member), other.id != frame {
                throw DocumentError.occurrenceAlreadyFramed(member, other.id)
            }
        }
    }
}


// MARK: - Comparison
//
// Four refusals carry the whole of AI-05, and each of them is a thing the
// specification names: a number needs a measure, a draft holds nothing, keeping
// removes nothing, and a total is never invented.

extension DocumentStore {
    private static func startComparison(_ start: StartComparison, in document: inout KollioDocument) throws {
        let comparison = start.comparison
        guard document.comparisons.comparison(comparison.id) == nil else {
            throw DocumentError.duplicateComparison(comparison.id)
        }
        // A comparison of one thing is a note with extra steps.
        guard comparison.directionIDs.count >= 2 else {
            throw DocumentError.comparisonNeedsTwoDirections(comparison.id)
        }
        for direction in comparison.directionIDs where document.content[direction] == nil {
            throw DocumentError.unknownObject(direction)
        }
        var criteria = comparison.criteria
        for criterion in criteria {
            guard criterion.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw DocumentError.emptyText(ObjectID(criterion.id.rawValue))
            }
            if let weight = criterion.weight, (weight.isFinite == false || weight < 0) {
                throw DocumentError.invalidWeight(weight)
            }
        }
        criteria = unique(criteria)
        var stored = comparison
        stored.criteria = criteria
        var ledger = document.comparisons
        ledger.upsert(stored)
        document.comparisons = ledger
    }

    /// Replaces the criteria and keeps the draft state.
    private static func setComparisonCriteria(
        _ command: SetComparisonCriteria,
        in document: inout KollioDocument
    ) throws {
        var comparison = try requireComparison(command.comparisonID, in: document)
        for criterion in command.criteria {
            guard criterion.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw DocumentError.emptyText(ObjectID(criterion.id.rawValue))
            }
        }
        // A cell whose criterion is no longer asked is dropped, because a value
        // recorded against a question that is not being asked any more is a number
        // on screen that nothing can be checked against.
        let keptIDs = Set(command.criteria.map(\.id))
        comparison.criteria = unique(command.criteria)
        comparison.cells = comparison.cells.filter { keptIDs.contains($0.criterionID) }
        var ledger = document.comparisons
        ledger.upsert(comparison)
        document.comparisons = ledger
    }

    /// Clears the draft flag, and nothing else. The criteria are whatever is on
    /// screen, so this cannot be used to confirm a list the person never saw.
    private static func confirmComparisonCriteria(
        _ confirm: ConfirmComparisonCriteria,
        in document: inout KollioDocument
    ) throws {
        var comparison = try requireComparison(confirm.comparisonID, in: document)
        guard comparison.isDraft else { return }
        comparison.isDraft = false
        var ledger = document.comparisons
        ledger.upsert(comparison)
        document.comparisons = ledger
    }

    private static func recordComparisonCell(
        _ record: RecordComparisonCell,
        in document: inout KollioDocument
    ) throws {
        var comparison = try requireComparison(record.comparisonID, in: document)
        guard comparison.isDraft == false else {
            throw DocumentError.comparisonIsDraft(comparison.id)
        }
        guard let criterion = comparison.criterion(record.cell.criterionID) else {
            throw DocumentError.unknownCriterion(record.cell.criterionID)
        }
        guard comparison.directionIDs.contains(record.cell.directionID) else {
            throw DocumentError.notAComparisonDirection(comparison.id, record.cell.directionID)
        }
        // AC01. A number without a measure is a rating, and a rating is an opinion.
        if case .number = record.cell.value, criterion.measure == nil {
            throw DocumentError.criterionHasNoMeasure(criterion.id)
        }
        for reference in record.cell.references {
            switch reference.kind {
            case .citation where document.sources.citation(CitationID(reference.id)) == nil:
                throw DocumentError.unknownCitation(CitationID(reference.id))
            case .source where document.sources.source(SourceID(reference.id)) == nil:
                throw DocumentError.unknownSource(SourceID(reference.id))
            case .object where document.content[ObjectID(reference.id)] == nil:
                throw DocumentError.unknownObject(ObjectID(reference.id))
            case .claim where document.claims.claim(ClaimID(reference.id)) == nil:
                throw DocumentError.unknownClaim(ClaimID(reference.id))
            case .citation, .source, .object, .claim, .note:
                break
            }
        }
        // Correcting a cell is an ordinary record: the previous value is replaced
        // and the new one says who wrote it and when, so a comparison that changed
        // its mind is readable rather than mysterious.
        comparison.cells.removeAll {
            $0.criterionID == record.cell.criterionID && $0.directionID == record.cell.directionID
        }
        comparison.cells.append(record.cell)
        comparison.cells.sort { $0.id < $1.id }
        var ledger = document.comparisons
        ledger.upsert(comparison)
        document.comparisons = ledger
    }

    private static func setCriterionWeight(
        _ command: SetCriterionWeight,
        in document: inout KollioDocument
    ) throws {
        var comparison = try requireComparison(command.comparisonID, in: document)
        guard let index = comparison.criteria.firstIndex(where: { $0.id == command.criterionID }) else {
            throw DocumentError.unknownCriterion(command.criterionID)
        }
        if let weight = command.weight {
            guard weight.isFinite, weight >= 0 else { throw DocumentError.invalidWeight(weight) }
        }
        comparison.criteria[index].weight = command.weight
        var ledger = document.comparisons
        ledger.upsert(comparison)
        document.comparisons = ledger
    }

    /// A number is only reachable through here, and only with a unit.
    ///
    /// The two checks live in the store rather than in the type because a caller can
    /// build a `Criterion` by hand with any `Measure` it likes, including one with an
    /// empty unit: "3" with nothing saying what the 3 is is the exact shape of an
    /// invented rating.
    private static func setCriterionMeasure(
        _ command: SetCriterionMeasure,
        in document: inout KollioDocument
    ) throws {
        var comparison = try requireComparison(command.comparisonID, in: document)
        guard let index = comparison.criteria.firstIndex(where: { $0.id == command.criterionID }) else {
            throw DocumentError.unknownCriterion(command.criterionID)
        }
        if let measure = command.measure {
            guard measure.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw DocumentError.emptyMeasureUnit(command.criterionID)
            }
        }
        comparison.criteria[index].measure = command.measure
        var ledger = document.comparisons
        ledger.upsert(comparison)
        document.comparisons = ledger
    }

    private static func keepDirection(_ keep: KeepDirection, in document: inout KollioDocument) throws {
        var comparison = try requireComparison(keep.comparisonID, in: document)
        guard comparison.directionIDs.contains(keep.directionID) else {
            throw DocumentError.notAComparisonDirection(keep.comparisonID, keep.directionID)
        }
        // Explicit, cumulative, reversible, and it removes nothing. The sibling
        // directions and their cells are still there afterwards, which is AC03.
        if comparison.keptDirectionIDs.contains(keep.directionID) == false {
            comparison.keptDirectionIDs.append(keep.directionID)
        }
        var ledger = document.comparisons
        ledger.upsert(comparison)
        document.comparisons = ledger
    }

    private static func requireComparison(_ id: ComparisonID, in document: KollioDocument) throws -> Comparison {
        guard let comparison = document.comparisons.comparison(id) else {
            throw DocumentError.unknownComparison(id)
        }
        return comparison
    }

    private static func unique(_ criteria: [Criterion]) -> [Criterion] {
        var seen: Set<CriterionID> = []
        return criteria.filter { seen.insert($0.id).inserted }
    }
}
