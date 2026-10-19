import Foundation

/// Every meaningful mutation goes through a validated command. A view never
/// mutates several pieces of state on its own.
public enum Command: Codable, Hashable, Sendable {
    case renameDocument(RenameDocument)
    case createObject(CreateObject)
    case updateObjectText(UpdateObjectText)
    case addRelationship(AddRelationship)
    case removeRelationship(RemoveRelationship)
    case moveNodeInstances(MoveNodeInstances)
    case duplicateObject(DuplicateObject)
    case duplicateNodeInstance(DuplicateNodeInstance)
    case removeObject(RemoveObject)
    case removeNodeInstance(RemoveNodeInstance)
    case createScenario(CreateScenario)
    case recordDecision(RecordDecision)
    case revokeDecision(RevokeDecision)
    case addContributionToProduct(AddContributionToProduct)
    case applyProposal(ApplyProposal)
    case rejectProposal(RejectProposal)
    case attachSource(AttachSource)
    case importSourceRevision(ImportSourceRevision)
    case addCitation(AddCitation)
    case recordVerification(RecordVerification)
    case removeSource(RemoveSource)
    case assertClaim(AssertClaim)
    case assessHypothesis(AssessHypothesis)
    case resolveConstraint(ResolveConstraint)
    case askClarification(AskClarification)
    case answerClarification(AnswerClarification)
    case markClarificationUnknown(MarkClarificationUnknown)
    case editRelationship(EditRelationship)
    case applyImpact(ApplyImpact)
    case createFrame(CreateFrame)
    case renameFrame(RenameFrame)
    case setFrameMembers(SetFrameMembers)
    case moveFrame(MoveFrame)
    case setFrameFolded(SetFrameFolded)
    case removeFrame(RemoveFrame)
    case startComparison(StartComparison)
    case setComparisonCriteria(SetComparisonCriteria)
    case confirmComparisonCriteria(ConfirmComparisonCriteria)
    case recordComparisonCell(RecordComparisonCell)
    case setCriterionWeight(SetCriterionWeight)
    case setCriterionMeasure(SetCriterionMeasure)
    case keepDirection(KeepDirection)
    case startSummary(StartSummary)
    case setSummaryLine(SetSummaryLine)
    case setSummarySection(SetSummarySection)
    case confirmSummary(ConfirmSummary)
    case removeSummary(RemoveSummary)
    case createExperiment(CreateExperiment)
    case editExperiment(EditExperiment)
    case recordExperimentResult(RecordExperimentResult)
    case proposeLearning(ProposeLearning)
    case acceptLearning(AcceptLearning)
    case restoreDocument(RestoreDocument)

    /// Presentation-only commands never change the meaning of the document.
    public var isSemantic: Bool {
        switch self {
        case .createFrame, .renameFrame, .setFrameMembers, .moveFrame,
             .setFrameFolded, .removeFrame,
             .moveNodeInstances, .duplicateNodeInstance, .removeNodeInstance:
            // A frame is presentation too, and so is everything done to one. CAN-07
            // says it outright: "a frame is a presentation concern", and folding a
            // branch to tidy the canvas must not change what the document means.
            //
            // An occurrence is presentation. Putting a second one on the canvas, or
            // taking one away, changes where something is drawn and nothing about
            // what it means, so it must not move semanticRevision. A *variant* is a
            // new claim, and is deliberately not in this list.
            return false
        case .renameDocument, .createObject, .updateObjectText, .addRelationship, .removeRelationship,
             .createScenario, .recordDecision, .revokeDecision,
             .addContributionToProduct, .applyProposal, .rejectProposal,
             .attachSource, .importSourceRevision, .addCitation, .recordVerification,
             .removeSource, .assertClaim, .assessHypothesis, .resolveConstraint,
             .duplicateObject, .removeObject,
             .askClarification, .answerClarification, .markClarificationUnknown,
             .editRelationship, .applyImpact,
             .startComparison, .setComparisonCriteria, .confirmComparisonCriteria,
             .recordComparisonCell,
             .setCriterionWeight, .setCriterionMeasure, .keepDirection,
             .startSummary, .setSummaryLine, .setSummarySection, .confirmSummary,
             .removeSummary, .createExperiment, .editExperiment,
             .recordExperimentResult, .proposeLearning, .acceptLearning,
             .restoreDocument:
            // A comparison is a record of what a person weighed against what, and
            // a synthesis is a record of what was read and what was concluded from
            // it, so both are meaning rather than layout. A synthesis is a
            // deliverable above all: folding it away must not change what the
            // document says.
            return true
        }
    }

    /// The experiment a learning learned from, or nil. One lookup, two uses.
    private static func experimentTarget(in document: KollioDocument, experimentID: ExperimentID) -> ObjectID? {
        document.experiments.experiment(experimentID)?.targetObjectID
    }

    private static func finding(in document: KollioDocument, id: FindingID) -> LearnedFinding? {
        document.experiments.finding(id)
    }

    /// A short label used as the undo label.
    public var undoLabel: String {
        switch self {
        case .renameDocument: return "undo.renameDocument"
        case .createObject: return "undo.createObject"
        case .updateObjectText: return "undo.updateObjectText"
        case .addRelationship: return "undo.addRelationship"
        case .removeRelationship: return "undo.removeRelationship"
        case .moveNodeInstances: return "undo.move"
        case .duplicateObject: return "undo.duplicateObject"
        case .duplicateNodeInstance: return "undo.duplicateNodeInstance"
        case .removeObject: return "undo.removeObject"
        case .removeNodeInstance: return "undo.removeNodeInstance"
        case .createScenario: return "undo.createScenario"
        case .recordDecision: return "undo.recordDecision"
        case .revokeDecision: return "undo.revokeDecision"
        case .addContributionToProduct: return "undo.addContribution"
        case .applyProposal: return "undo.applyProposal"
        case .rejectProposal: return "undo.rejectProposal"
        case .attachSource: return "undo.attachSource"
        case .importSourceRevision: return "undo.importSourceRevision"
        case .addCitation: return "undo.addCitation"
        case .recordVerification: return "undo.recordVerification"
        case .removeSource: return "undo.removeSource"
        case .assertClaim: return "undo.assertClaim"
        case .assessHypothesis: return "undo.assessHypothesis"
        case .resolveConstraint: return "undo.resolveConstraint"
        case .askClarification: return "undo.askClarification"
        case .answerClarification: return "undo.answerClarification"
        case .markClarificationUnknown: return "undo.markClarificationUnknown"
        case .editRelationship: return "undo.editRelationship"
        case .applyImpact: return "undo.applyImpact"
        case .createFrame: return "undo.createFrame"
        case .renameFrame: return "undo.renameFrame"
        case .setFrameMembers: return "undo.setFrameMembers"
        case .moveFrame: return "undo.moveFrame"
        case .setFrameFolded: return "undo.foldFrame"
        case .removeFrame: return "undo.removeFrame"
        case .startComparison: return "undo.startComparison"
        case .setComparisonCriteria: return "undo.setComparisonCriteria"
        case .confirmComparisonCriteria: return "undo.confirmComparison"
        case .recordComparisonCell: return "undo.recordComparisonCell"
        case .setCriterionWeight: return "undo.setCriterionWeight"
        case .setCriterionMeasure: return "undo.setCriterionMeasure"
        case .keepDirection: return "undo.keepDirection"
        case .startSummary: return "undo.startSummary"
        case .setSummaryLine: return "undo.setSummaryLine"
        case .setSummarySection: return "undo.setSummarySection"
        case .confirmSummary: return "undo.confirmSummary"
        case .removeSummary: return "undo.removeSummary"
        case .createExperiment: return "undo.createExperiment"
        case .editExperiment: return "undo.editExperiment"
        case .recordExperimentResult: return "undo.recordResult"
        case .proposeLearning: return "undo.proposeLearning"
        case .acceptLearning: return "undo.acceptLearning"
        case .restoreDocument: return "undo.restoreDocument"
        }
    }
}

public struct RenameDocument: Codable, Hashable, Sendable {
    public var title: String
    public var provenance: Provenance

    public init(title: String, provenance: Provenance) {
        self.title = title
        self.provenance = provenance
    }
}

public struct CreateObject: Codable, Hashable, Sendable {
    public var id: ObjectID
    public var kind: ContentObject.Kind
    public var text: LocalizedText
    public var detail: LocalizedText?
    public var contributionID: ActorID?
    public var position: Position?
    public var size: Size?
    public var provenance: Provenance

    public init(
        id: ObjectID,
        kind: ContentObject.Kind,
        text: LocalizedText,
        detail: LocalizedText? = nil,
        contributionID: ActorID? = nil,
        position: Position? = nil,
        size: Size? = nil,
        provenance: Provenance
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.detail = detail
        self.contributionID = contributionID
        self.position = position
        self.size = size
        self.provenance = provenance
    }
}

public struct UpdateObjectText: Codable, Hashable, Sendable {
    public var id: ObjectID
    public var text: LocalizedText
    public var detail: LocalizedText?
    public var provenance: Provenance
    /// The version this text was written against, when the writer knows it.
    ///
    /// `nil` means "I did not look", which is allowed and is how a first edit of
    /// a freshly created object is expressed. A number means "I saw this version",
    /// and a mismatch is refused rather than merged. The distinction matters: a
    /// writer that never looked is asking to overwrite, and one that looked and is
    /// out of date is asking a question the interface should answer.
    public var expectedVersion: Int?

    public init(
        id: ObjectID,
        text: LocalizedText,
        detail: LocalizedText? = nil,
        provenance: Provenance,
        expectedVersion: Int? = nil
    ) {
        self.id = id
        self.text = text
        self.detail = detail
        self.provenance = provenance
        self.expectedVersion = expectedVersion
    }
}

public struct AddRelationship: Codable, Hashable, Sendable {
    public var id: RelationshipID
    public var from: ObjectID
    public var to: ObjectID
    public var kind: Relationship.Kind
    public var label: LocalizedText?
    public var fromAnchor: Relationship.Anchor
    public var toAnchor: Relationship.Anchor
    public var provenance: Provenance

    public init(
        id: RelationshipID,
        from: ObjectID,
        to: ObjectID,
        kind: Relationship.Kind,
        label: LocalizedText? = nil,
        fromAnchor: Relationship.Anchor = .bottom,
        toAnchor: Relationship.Anchor = .top,
        provenance: Provenance
    ) {
        self.id = id
        self.from = from
        self.to = to
        self.kind = kind
        self.label = label
        self.fromAnchor = fromAnchor
        self.toAnchor = toAnchor
        self.provenance = provenance
    }
}

public struct RemoveRelationship: Codable, Hashable, Sendable {
    public var id: RelationshipID
}

/// A second appearance of the *same* object.
///
/// CAN-05 separates this from `DuplicateObject` in one sentence: "Duplicating an
/// occurrence keeps the referenced object." The person sees two of the same thing
/// on the canvas; the document still contains one object, one author, one
/// contribution and one share. Nothing semantic changes, which is why this is
/// presentation-only.
public struct DuplicateNodeInstance: Codable, Hashable, Sendable {
    public var instanceID: InstanceID
    /// The instance handed to the new one. Nil places the copy where the camera
    /// is looking rather than exactly on top of the original.
    public var id: InstanceID
    public var position: Position?

    public init(instanceID: InstanceID, id: InstanceID, position: Position? = nil) {
        self.instanceID = instanceID
        self.id = id
        self.position = position
    }
}

/// A new object that says the same thing differently.
///
/// This is a *variant*: a new claim, related to its origin by `derivedFrom` so
/// the reasoning stays readable. It is a new object rather than a second
/// occurrence precisely because a variant can be changed without changing the
/// thing it came from.
public struct DuplicateObject: Codable, Hashable, Sendable {
    public var sourceID: ObjectID
    public var id: ObjectID
    public var instanceID: InstanceID
    public var relationshipID: RelationshipID
    public var position: Position?
    public var provenance: Provenance

    public init(
        sourceID: ObjectID,
        id: ObjectID,
        instanceID: InstanceID,
        relationshipID: RelationshipID,
        position: Position? = nil,
        provenance: Provenance
    ) {
        self.sourceID = sourceID
        self.id = id
        self.instanceID = instanceID
        self.relationshipID = relationshipID
        self.position = position
        self.provenance = provenance
    }
}

/// Removes an object from the document: its relationships and its instances go
/// with it.
///
/// CAN-05 requires this to be a *distinct action* from removing an occurrence,
/// because they lose different things. Removing an occurrence leaves the idea;
/// this one does not, which is why the interface never offers it behind the same
/// gesture.
public struct RemoveObject: Codable, Hashable, Sendable {
    public var id: ObjectID

    // Written out rather than left to the memberwise initialiser, which Swift makes
    // internal even on a public struct. Without it this type is constructible only
    // inside KollioCore, and the next module to try gets `init(from:)` instead, with
    // an error about a Decoder rather than about visibility.
    public init(id: ObjectID) {
        self.id = id
    }
}

/// Removes one occurrence, and leaves the object it was drawing.
public struct RemoveNodeInstance: Codable, Hashable, Sendable {
    public var instanceID: InstanceID

    // Public for the reason given on RemoveObject.
    public init(instanceID: InstanceID) {
        self.instanceID = instanceID
    }
}

public struct MoveNodeInstance: Codable, Hashable, Sendable {
    public var instanceID: InstanceID
    public var position: Position

    public init(instanceID: InstanceID, position: Position) {
        self.instanceID = instanceID
        self.position = position
    }
}

public struct MoveNodeInstances: Codable, Hashable, Sendable {
    public var moves: [MoveNodeInstance]

    public init(moves: [MoveNodeInstance]) {
        self.moves = moves
    }
}

/// Creates a scenario with its initial context. Used by the first experience and
/// by fixtures; it stays a plain transaction so it is undoable as one action.
public struct CreateScenario: Codable, Hashable, Sendable {
    public var context: CreateObject
    public var children: [CreateObject]
    public var links: [AddRelationship]
    public var rootPosition: Position

    public init(context: CreateObject, children: [CreateObject], links: [AddRelationship], rootPosition: Position) {
        self.context = context
        self.children = children
        self.links = links
        self.rootPosition = rootPosition
    }
}

public struct RecordDecision: Codable, Hashable, Sendable {
    public var id: DecisionID
    public var kind: Decision.Kind
    public var targetObjectID: ObjectID
    public var rationale: LocalizedText?
    public var provenance: Provenance

    public init(id: DecisionID, kind: Decision.Kind, targetObjectID: ObjectID, rationale: LocalizedText? = nil, provenance: Provenance) {
        self.id = id
        self.kind = kind
        self.targetObjectID = targetObjectID
        self.rationale = rationale
        self.provenance = provenance
    }
}

public struct RevokeDecision: Codable, Hashable, Sendable {
    public var id: DecisionID
}

public struct AddContributionToProduct: Codable, Hashable, Sendable {
    public var productID: ObjectID
    public var contributionID: ActorID
    public var share: Double
    public var provenance: Provenance

    public init(productID: ObjectID, contributionID: ActorID, share: Double = 0, provenance: Provenance) {
        self.productID = productID
        self.contributionID = contributionID
        self.share = share
        self.provenance = provenance
    }
}

/// Applying a proposal is a single transaction: it either fully succeeds or
/// leaves the document untouched, and it is undone as one coherent action.
public struct ApplyProposal: Codable, Hashable, Sendable {
    public var proposal: Proposal
    public var placements: [ObjectID: Position]
    public var provenance: Provenance

    public init(proposal: Proposal, placements: [ObjectID: Position], provenance: Provenance) {
        self.proposal = proposal
        self.placements = placements
        self.provenance = provenance
    }
}

public struct RejectProposal: Codable, Hashable, Sendable {
    public var proposalId: String
    public var reason: RejectReason
    public var provenance: Provenance

    public enum RejectReason: String, Codable, Sendable {
        case setAside
        case declined
    }

    public init(proposalId: String, reason: RejectReason, provenance: Provenance) {
        self.proposalId = proposalId
        self.reason = reason
        self.provenance = provenance
    }
}

// MARK: - Sources and citations
//
// Every one of these is a validated command like any other, so attaching a source
// is undoable, transactional and versioned with the rest of the document rather
// than being a side effect a view performs.

public struct AttachSource: Codable, Hashable, Sendable {
    public var source: SourceReference
    /// The object this source belongs to, when it was brought for a particular
    /// piece of the document rather than for the whole of it.
    public var attachedTo: ObjectID?
    public var provenance: Provenance

    public init(source: SourceReference, attachedTo: ObjectID? = nil, provenance: Provenance) {
        self.source = source
        self.attachedTo = attachedTo
        self.provenance = provenance
    }
}

public struct ImportSourceRevision: Codable, Hashable, Sendable {
    public var sourceID: SourceID
    public var revision: SourceRevision
    public var provenance: Provenance

    public init(sourceID: SourceID, revision: SourceRevision, provenance: Provenance) {
        self.sourceID = sourceID
        self.revision = revision
        self.provenance = provenance
    }
}

public struct AddCitation: Codable, Hashable, Sendable {
    public var citation: Citation
    /// The claim being supported. Required: a citation with nothing to attach to is
    /// evidence for no one.
    public var claimID: ObjectID
    public var provenance: Provenance

    public init(citation: Citation, claimID: ObjectID, provenance: Provenance) {
        self.citation = citation
        self.claimID = claimID
        self.provenance = provenance
    }
}

/// Recording a check. The observation and the author are both required by the
/// type, so there is no command that can mark something verified on its own.
public struct RecordVerification: Codable, Hashable, Sendable {
    public var citationID: CitationID
    public var observation: String
    public var author: ActorID
    public var at: Date

    public init(citationID: CitationID, observation: String, author: ActorID, at: Date = Date()) {
        self.citationID = citationID
        self.observation = observation
        self.author = author
        self.at = at
    }
}

public struct RemoveSource: Codable, Hashable, Sendable {
    public var sourceID: SourceID
    public var reason: String

    public init(sourceID: SourceID, reason: String) {
        self.sourceID = sourceID
        self.reason = reason
    }
}


// MARK: - Claims
//
// A claim needs a scope. The command layer refuses one without, because an
// unscoped constraint would behave as a law of the universe and quietly forbid
// everything a person did not mean it to.

public struct AssertClaim: Codable, Hashable, Sendable {
    public var claim: Claim
    public var provenance: Provenance

    public init(claim: Claim, provenance: Provenance) {
        self.claim = claim
        self.provenance = provenance
    }
}

public struct AssessHypothesis: Codable, Hashable, Sendable {
    public var claimID: ClaimID
    /// The new standing. Carries its own evidence, so a bare "supported" is not
    /// expressible.
    public var assessment: HypothesisAssessment
    public var provenance: Provenance

    public init(claimID: ClaimID, assessment: HypothesisAssessment, provenance: Provenance) {
        self.claimID = claimID
        self.assessment = assessment
        self.provenance = provenance
    }
}

public struct ResolveConstraint: Codable, Hashable, Sendable {
    public var claimID: ClaimID
    /// `notApplicable` is a real answer and is not satisfaction.
    public var resolution: ConstraintResolution
    public var provenance: Provenance

    public init(claimID: ClaimID, resolution: ConstraintResolution, provenance: Provenance) {
        self.claimID = claimID
        self.resolution = resolution
        self.provenance = provenance
    }
}


// MARK: - Clarifications
//
// A question is asked by intelligence and answered by a person, so these commands
// exist in both directions. The empty case is refused at the command layer and
// nowhere else: an empty field is not a fact, and letting it through would put a
// blank answer in the document looking like a considered one.

public struct AskClarification: Codable, Hashable, Sendable {
    public var clarification: Clarification
    public var provenance: Provenance

    public init(clarification: Clarification, provenance: Provenance) {
        self.clarification = clarification
        self.provenance = provenance
    }
}

/// A person answering, which becomes a linked contribution.
public struct AnswerClarification: Codable, Hashable, Sendable {
    public var clarificationID: ClarificationID
    public var text: String
    public var provenance: Provenance

    public init(clarificationID: ClarificationID, text: String, provenance: Provenance) {
        self.clarificationID = clarificationID
        self.text = text
        self.provenance = provenance
    }
}

/// A person saying they do not know. A real answer, and not an empty one.
public struct MarkClarificationUnknown: Codable, Hashable, Sendable {
    public var clarificationID: ClarificationID
    public var reason: String?
    public var provenance: Provenance

    public init(clarificationID: ClarificationID, reason: String? = nil, provenance: Provenance) {
        self.clarificationID = clarificationID
        self.reason = reason
        self.provenance = provenance
    }
}


// MARK: - Editing a relationship

/// Changing what a link means, as a named operation.
///
/// CAN-06 insists the change is explicit rather than a drag, because a reversed
/// link looks identical before and after and only the sentence differs. Reversing
/// therefore carries the pair it was requested for, and the store checks it.
public struct EditRelationship: Codable, Hashable, Sendable {
    public var id: RelationshipID
    public var edit: RelationshipEdit
    public var provenance: Provenance

    public init(id: RelationshipID, edit: RelationshipEdit, provenance: Provenance) {
        self.id = id
        self.edit = edit
        self.provenance = provenance
    }
}

// MARK: - Impact
//
// Applying an impact is one transaction and one undo step, whatever the
// assessment names. That is AC03 stated as a type constraint: a single command
// carrying a single assessment either lands whole or leaves nothing behind.

/// Records the objects an assessment says need another look.
///
/// It carries the assessment rather than a list of conclusions, so the durable
/// record can always be read back against the reasons that produced it. The
/// decision identifiers are supplied rather than minted here, for the same reason
/// every other command in this file does: an actor that does not own the document
/// does not get to invent identifiers inside it.
public struct ApplyImpact: Codable, Hashable, Sendable {
    public var assessment: ImpactAssessment
    /// One decision per impacted object, in the same order as
    /// `assessment.proposedChanges`.
    public var decisionIDs: [DecisionID]
    public var provenance: Provenance

    public init(assessment: ImpactAssessment, decisionIDs: [DecisionID], provenance: Provenance) {
        self.assessment = assessment
        self.decisionIDs = decisionIDs
        self.provenance = provenance
    }
}


// MARK: - Frames
//
// A named frame with explicit members. Every command here is presentation-only, so
// none of them may move `semanticRevision`: grouping, folding, moving and renaming
// are what a person does to the canvas, and the document's meaning is not what
// changes.

public struct CreateFrame: Codable, Hashable, Sendable {
    public var frame: Frame

    public init(frame: Frame) {
        self.frame = frame
    }
}

/// Renaming a branch renames the frame and nothing else.
///
/// The specification is explicit that it does not rename its sources, so this
/// command carries no object ids at all: there is no version of it that could.
public struct RenameFrame: Codable, Hashable, Sendable {
    public var id: FrameID
    public var name: LocalizedText

    public init(id: FrameID, name: LocalizedText) {
        self.id = id
        self.name = name
    }
}

/// Replaces the frame's members with an explicit list.
///
/// An empty list is accepted: "an empty frame stays until the user chooses", so
/// removing everything from a frame is a normal state and not an error.
public struct SetFrameMembers: Codable, Hashable, Sendable {
    public var id: FrameID
    public var memberInstanceIDs: [InstanceID]

    public init(id: FrameID, memberInstanceIDs: [InstanceID]) {
        self.id = id
        self.memberInstanceIDs = memberInstanceIDs
    }
}

/// Moves the frame, and every occurrence it holds, by one delta.
///
/// One transaction so one undo restores the whole group, and the same delta for
/// every member so the offsets inside the frame are preserved exactly, which is
/// AC02. An occurrence of the same object that is not a member is not touched,
/// which is AC03.
public struct MoveFrame: Codable, Hashable, Sendable {
    public var id: FrameID
    public var delta: Position

    public init(id: FrameID, delta: Position) {
        self.id = id
        self.delta = delta
    }
}

/// Folding hides the members in this view. It is not a decision and it does not
/// change what the document says.
public struct SetFrameFolded: Codable, Hashable, Sendable {
    public var id: FrameID
    public var isFolded: Bool

    public init(id: FrameID, isFolded: Bool) {
        self.id = id
        self.isFolded = isFolded
    }
}

public struct RemoveFrame: Codable, Hashable, Sendable {
    public var id: FrameID

    public init(id: FrameID) {
        self.id = id
    }
}


// MARK: - Comparison
//
// A comparison records what a person weighed against what. Nothing here computes
// an opinion: the commands store what was said, and `Comparison.total(for:)`
// refuses to produce a number the person did not define the terms for.

/// Opens a comparison over two or more existing objects.
public struct StartComparison: Codable, Hashable, Sendable {
    public var comparison: Comparison
    public var provenance: Provenance

    public init(comparison: Comparison, provenance: Provenance) {
        self.comparison = comparison
        self.provenance = provenance
    }
}

/// Replaces the criteria of a comparison, **without** confirming it.
///
/// Separate from `ConfirmComparisonCriteria` because the two are different acts and
/// the first version merged them: adding a criterion to a draft silently confirmed
/// the whole comparison, which is exactly the shortcut the draft exists to prevent.
/// A person who types a criterion has agreed to *that criterion*; agreeing to the
/// set, and therefore to recording values against it, is a separate press.
public struct SetComparisonCriteria: Codable, Hashable, Sendable {
    public var comparisonID: ComparisonID
    public var criteria: [Criterion]
    public var provenance: Provenance

    public init(comparisonID: ComparisonID, criteria: [Criterion], provenance: Provenance) {
        self.comparisonID = comparisonID
        self.criteria = criteria
        self.provenance = provenance
    }
}

/// Confirms the criteria that are there, so cells can be recorded against them.
///
/// Explicit, and it carries no criteria of its own: confirming is agreeing to the
/// set as it stands, and a command that could bring its own list would be a way to
/// confirm something other than what is on screen.
public struct ConfirmComparisonCriteria: Codable, Hashable, Sendable {
    public var comparisonID: ComparisonID
    public var provenance: Provenance

    public init(comparisonID: ComparisonID, provenance: Provenance) {
        self.comparisonID = comparisonID
        self.provenance = provenance
    }
}

/// Records or corrects one cell.
///
/// The comparison is named on the command rather than on the cell. The cell is
/// stored inside its comparison, so naming it there would be a second place for one
/// fact to live; the first version left it off the cell entirely and had the store
/// *search* every comparison for the owner of the criterion, which would have put a
/// cell into the wrong comparison the day two comparisons reused a criterion.
public struct RecordComparisonCell: Codable, Hashable, Sendable {
    public var comparisonID: ComparisonID
    public var cell: Cell
    public var provenance: Provenance

    public init(comparisonID: ComparisonID, cell: Cell, provenance: Provenance) {
        self.comparisonID = comparisonID
        self.cell = cell
        self.provenance = provenance
    }
}

/// Sets or removes a criterion's weight. `nil` removes it, and a removed weight is
/// not a weight of one.
public struct SetCriterionWeight: Codable, Hashable, Sendable {
    public var comparisonID: ComparisonID
    public var criterionID: CriterionID
    public var weight: Double?
    public var provenance: Provenance

    public init(comparisonID: ComparisonID, criterionID: CriterionID, weight: Double?, provenance: Provenance) {
        self.comparisonID = comparisonID
        self.criterionID = criterionID
        self.weight = weight
        self.provenance = provenance
    }
}

/// States, or removes, what a criterion is measured in and which way is better.
///
/// Its own command rather than a field on `SetCriterionWeight` because the two
/// facts are decided at different moments and for different reasons: a person
/// usually knows what a criterion is *about* long before they know how much it
/// counts, and a criterion that is judged in words has no measure at all.
public struct SetCriterionMeasure: Codable, Hashable, Sendable {
    public var comparisonID: ComparisonID
    public var criterionID: CriterionID
    /// Nil means "judged in words", which is a real state and not a missing value.
    public var measure: Measure?
    public var provenance: Provenance

    public init(comparisonID: ComparisonID, criterionID: CriterionID, measure: Measure?, provenance: Provenance) {
        self.comparisonID = comparisonID
        self.criterionID = criterionID
        self.measure = measure
        self.provenance = provenance
    }
}

/// Keeps a direction. Names one and removes nothing, which is AC03 in the shape of
/// a command: there is no version of it that deletes a sibling.
public struct KeepDirection: Codable, Hashable, Sendable {
    public var comparisonID: ComparisonID
    public var directionID: ObjectID
    public var rationale: String?
    public var provenance: Provenance

    public init(comparisonID: ComparisonID, directionID: ObjectID, rationale: String? = nil, provenance: Provenance) {
        self.comparisonID = comparisonID
        self.directionID = directionID
        self.rationale = rationale
        self.provenance = provenance
    }
}

// A synthesis is a derivative: a reading of the document, prepared to hand over.
// Nothing here writes to content, and nothing here can replace what it read. The
// five commands below are the whole surface, and each of them exists because the
// two acts it could have been merged into are genuinely different acts.

/// Opens a synthesis as a draft.
///
/// A draft is not a lesser synthesis. It is the state in which nothing has been
/// agreed, and `ConfirmSummary` is a separate press because confirming means the
/// deliverable will be handed to someone, which is not the same as having written
/// it.
public struct StartSummary: Codable, Hashable, Sendable {
    public var summary: SummaryArtifact
    public var provenance: Provenance

    public init(summary: SummaryArtifact, provenance: Provenance) {
        self.summary = summary
        self.provenance = provenance
    }
}

/// Records a result against an experiment (DEC-05).
///
/// Recording is appending: there is no edit-a-result command, because the
/// observation a person wrote after running something is a record of what they
/// saw, and a record that can be rewritten is a draft. The command validates
/// the two refusals that keep a result honest — an observation with nothing in
/// it, and an inconclusive outcome with no reason — plus the two quieter ones:
/// a measurement without a unit, and a source that names nothing.
public struct RecordExperimentResult: Codable, Hashable, Sendable {
    public var id: ExperimentID
    public var observation: String
    public var measurements: [ExperimentMeasurement]
    public var limits: String?
    public var sourceObjectID: ObjectID?
    public var outcome: ExperimentResultVersion.Outcome
    public var provenance: Provenance

    public init(
        id: ExperimentID,
        observation: String,
        measurements: [ExperimentMeasurement] = [],
        limits: String? = nil,
        sourceObjectID: ObjectID? = nil,
        outcome: ExperimentResultVersion.Outcome,
        provenance: Provenance
    ) {
        self.id = id
        self.observation = observation
        self.measurements = measurements
        self.limits = limits
        self.sourceObjectID = sourceObjectID
        self.outcome = outcome
        self.provenance = provenance
    }
}

/// Proposes a learning from a recorded result (DEC-05).
///
/// The learning is authored: this command carries words a person wrote, not a
/// conclusion computed from numbers. It lands as `proposed`, and it changes
/// nothing in the document by existing — the possible decision it points at
/// remains a separate act.
public struct ProposeLearning: Codable, Hashable, Sendable {
    public var id: FindingID
    public var experimentID: ExperimentID
    public var statement: LocalizedText
    public var scopeObjectIDs: [ObjectID]
    public var provenance: Provenance

    public init(
        id: FindingID,
        experimentID: ExperimentID,
        statement: LocalizedText,
        scopeObjectIDs: [ObjectID],
        provenance: Provenance
    ) {
        self.id = id
        self.experimentID = experimentID
        self.statement = statement
        self.scopeObjectIDs = scopeObjectIDs
        self.provenance = provenance
    }
}

/// Accepts a proposed learning by naming the decision that was taken (DEC-05).
///
/// The decision is not created here. It already exists, recorded through
/// DEC-01, and this command links the learning to it after checking the two
/// belong together: the decision must be about something the learning's scope
/// covers. Accepting a learning without a decision would be a way to change
/// the document by saying that something was learned, which is a decision in
/// disguise.
/// A validated replacement of the document's authored state.
///
/// History is deliberately excluded from the encoded snapshot. The journal is
/// the record of how the current document was reached; restoring content must
/// append to that record, never replace it with the older record carried by the
/// preview. Metadata and revisions are likewise owned by `DocumentStore`, which
/// applies this as one ordinary transaction.
public struct RestoreDocument: Codable, Hashable, Sendable {
    public var snapshot: Data

    public init(document: KollioDocument) throws {
        var state = document
        state.history = HistoryLedger()
        self.snapshot = try DocumentCodec.encode(state)
    }
}

public struct AcceptLearning: Codable, Hashable, Sendable {
    public var id: FindingID
    public var decisionID: DecisionID
    public var provenance: Provenance

    public init(id: FindingID, decisionID: DecisionID, provenance: Provenance) {
        self.id = id
        self.decisionID = decisionID
        self.provenance = provenance
    }
}

/// Builds a validation experiment on an object's reasoning (DEC-04).
///
/// The command validates the two things the block cannot survive without: a
/// question and a success criterion. It also validates every evidence link
/// against the document, because a link to a thing that does not exist is not
/// a link, it is a hope.
public struct CreateExperiment: Codable, Hashable, Sendable {
    public var id: ExperimentID
    public var targetObjectID: ObjectID
    public var question: LocalizedText
    public var method: LocalizedText?
    public var successCriterion: LocalizedText
    public var expectedEvidence: [ObjectID]
    public var owner: ActorID?
    public var dueDate: Date?
    public var isSimulation: Bool
    public var provenance: Provenance

    public init(
        id: ExperimentID,
        targetObjectID: ObjectID,
        question: LocalizedText,
        method: LocalizedText? = nil,
        successCriterion: LocalizedText,
        expectedEvidence: [ObjectID] = [],
        owner: ActorID? = nil,
        dueDate: Date? = nil,
        isSimulation: Bool = false,
        provenance: Provenance
    ) {
        self.id = id
        self.targetObjectID = targetObjectID
        self.question = question
        self.method = method
        self.successCriterion = successCriterion
        self.expectedEvidence = expectedEvidence
        self.owner = owner
        self.dueDate = dueDate
        self.isSimulation = isSimulation
        self.provenance = provenance
    }
}

/// Edits a validation experiment by appending a revision (DEC-04 AC03).
///
/// Editing never rewrites: the fields a result will be judged against go into a
/// new revision, and the old ones stay readable. Before a result exists this is
/// ordinary refinement; after one exists it is the visible revision the
/// specification asks for, and the same append does both.
public struct EditExperiment: Codable, Hashable, Sendable {
    public var id: ExperimentID
    public var question: LocalizedText
    public var method: LocalizedText?
    public var successCriterion: LocalizedText
    public var expectedEvidence: [ObjectID]
    public var provenance: Provenance

    public init(
        id: ExperimentID,
        question: LocalizedText,
        method: LocalizedText? = nil,
        successCriterion: LocalizedText,
        expectedEvidence: [ObjectID] = [],
        provenance: Provenance
    ) {
        self.id = id
        self.question = question
        self.method = method
        self.successCriterion = successCriterion
        self.expectedEvidence = expectedEvidence
        self.provenance = provenance
    }
}

/// Adds a line to a section, or replaces one that is already there.
///
/// One command for both, because they are one act: a person writing a line into a
/// synthesis, whether the line is new or a correction of what was there. The
/// correction is what makes AC01 checkable, so it is handled here rather than by a
/// separate `editLine` that could be used to overwrite without a trace.
public struct SetSummaryLine: Codable, Hashable, Sendable {
    public var summaryID: SummaryID
    public var section: SummaryArtifact.Section
    public var line: SummaryArtifact.SummaryLine
    public var provenance: Provenance

    public init(
        summaryID: SummaryID,
        section: SummaryArtifact.Section,
        line: SummaryArtifact.SummaryLine,
        provenance: Provenance
    ) {
        self.summaryID = summaryID
        self.section = section
        self.line = line
        self.provenance = provenance
    }
}

/// Replaces a section wholesale, including declaring that nothing was recorded.
///
/// The declaration is the reason this is a command and not a property. "Nobody
/// wrote down what is not known" and "nothing was written here" look identical in
/// a list and mean opposite things, so a person has to be able to say which one
/// they mean.
public struct SetSummarySection: Codable, Hashable, Sendable {
    public var summaryID: SummaryID
    /// Named rather than inferred from the section's identifier. The first version
    /// reverse-mapped `SummarySectionID` back to a `Section` and fell back to
    /// `.currentState` for anything it did not recognise, which meant a typo in an
    /// identifier would have written a person's section into the wrong place.
    public var kind: SummaryArtifact.Section
    public var section: SummaryArtifact.SummarySection
    public var provenance: Provenance

    public init(
        summaryID: SummaryID,
        kind: SummaryArtifact.Section,
        section: SummaryArtifact.SummarySection,
        provenance: Provenance
    ) {
        self.summaryID = summaryID
        self.kind = kind
        self.section = section
        self.provenance = provenance
    }
}

/// Confirms a draft, which is what makes it a deliverable.
///
/// Refuses while any section is silently blank. That refusal is the whole of
/// "the AI does not fabricate conclusions to fill a template", expressed as
/// something a command can check: a confirmed synthesis has said something about
/// every part of itself, or has declared that there was nothing to say.
public struct ConfirmSummary: Codable, Hashable, Sendable {
    public var summaryID: SummaryID
    public var provenance: Provenance

    public init(summaryID: SummaryID, provenance: Provenance) {
        self.summaryID = summaryID
        self.provenance = provenance
    }
}

/// Removes a synthesis.
///
/// Removing is not setting aside, and there is no other kind of removal here: a
/// synthesis holds no content, so nothing is lost with it that the document does
/// not still hold. The read set goes with it, which is the one thing worth saying
/// out loud, and is why this is a command a person presses.
public struct RemoveSummary: Codable, Hashable, Sendable {
    public var summaryID: SummaryID
    public var provenance: Provenance

    public init(summaryID: SummaryID, provenance: Provenance) {
        self.summaryID = summaryID
        self.provenance = provenance
    }
}

extension Command {
    /// The objects a command touches.
    ///
    /// It takes the document, and the first version did not. A relationship
    /// command carries only a `RelationshipID`, so its two ends cannot be known
    /// without looking the relationship up, and a version that guessed an id
    /// format would have put relationship edits in the history of nothing.
    ///
    /// This exists so "what happened to this object?" is answerable from the
    /// commands. A command that resolves to no object returns an empty set rather
    /// than guessing: `applyProposal` is not about every object it happened to
    /// contain, and claiming otherwise would put a whole accepted proposal into
    /// the history of each of its members.
    public func touchedObjectIDs(in document: KollioDocument) -> Set<ObjectID> {
        switch self {
        case .createObject(let create):
            return [create.id]
        case .updateObjectText(let update):
            return [update.id]
        case .addRelationship(let add):
            return Set([add.from, add.to])
        case .removeRelationship(let remove):
            guard let relationship = document.relationships[remove.id] else { return [] }
            return Set([relationship.from, relationship.to])
        case .moveNodeInstances(let move):
            // An instance is not an object: the same object may be drawn several
            // times, and the mapping lives in the presentation. Resolving through
            // it is the only honest answer to "what did this touch".
            return Set(move.moves.compactMap { document.presentation.instance(id: $0.instanceID)?.objectID })
        case .createScenario(let scenario):
            // The context and every child are objects this command brings into
            // being, so they are what it touched.
            return Set([scenario.context.id] + scenario.children.map(\.id))
        case .duplicateObject(let duplicate):
            return Set([duplicate.sourceID, duplicate.id])
        case .duplicateNodeInstance(let duplicate):
            // The new drawing is not on the canvas yet, so what the command
            // touched is the object it duplicates.
            guard let source = document.presentation.instance(id: duplicate.instanceID) else { return [] }
            return [source.objectID]
        case .removeObject(let remove):
            return [remove.id]
        case .removeNodeInstance(let remove):
            return Set([document.presentation.instance(id: remove.instanceID)?.objectID].compactMap { $0 })
        case .recordDecision(let decision):
            return [decision.targetObjectID]
        case .revokeDecision(let revoke):
            guard let decision = document.decisions[revoke.id] else { return [] }
            return [decision.targetObjectID]
        case .addContributionToProduct(let add):
            return [add.productID]
        case .assertClaim(let claim):
            return [claim.claim.objectID]
        case .assessHypothesis(let assess):
            // A claim id is not an object id. Resolving it needs the ledger, and
            // the first version built an `ObjectID` out of the raw string, which
            // would have invented an object that does not exist.
            guard let claim = document.claims.claim(assess.claimID) else { return [] }
            return [claim.objectID]
        case .addCitation(let citation):
            return Set([citation.claimID, citation.citation.claimID])
        case .recordVerification(let verification):
            guard let citation = document.sources.citation(verification.citationID) else { return [] }
            return [citation.claimID]
        case .attachSource(let attach):
            return Set([attach.attachedTo].compactMap { $0 })
        case .askClarification(let ask):
            return [ask.clarification.objectID]
        case .answerClarification(let answer):
            guard let entry = document.clarifications.clarification(answer.clarificationID) else { return [] }
            return [entry.objectID]
        case .editRelationship(let edit):
            guard let relationship = document.relationships[edit.id] else { return [] }
            return Set([relationship.from, relationship.to])
        case .applyImpact(let impact):
            return Set(impact.assessment.proposedChanges.map(\.objectID))
        case .keepDirection(let keep):
            return [keep.directionID]
        case .startSummary(let start):
            return Set(start.summary.readSet.objectIDs)
        case .createExperiment(let create):
            return Set([create.targetObjectID] + create.expectedEvidence)
        case .editExperiment(let edit):
            // The command names an experiment, not an object. Resolving through
            // the ledger is the honest answer, and it also returns the evidence
            // the edit re-attached, because those are what the edit touched.
            guard let experiment = document.experiments.experiment(edit.id) else { return [] }
            return Set([experiment.targetObjectID] + edit.expectedEvidence)
        case .recordExperimentResult(let record):
            guard let experiment = document.experiments.experiment(record.id) else { return [] }
            var touched = [experiment.targetObjectID]
            if let source = record.sourceObjectID { touched.append(source) }
            return Set(touched)
        case .proposeLearning(let propose):
            guard let experiment = document.experiments.experiment(propose.experimentID) else { return [] }
            return Set([experiment.targetObjectID] + propose.scopeObjectIDs)
        case .acceptLearning(let accept):
            // The learning and the decision both anchor in the document; the
            // command touched the learning, and the decision's target through it.
            guard let finding = Self.finding(in: document, id: accept.id),
                  let decision = document.decisions[accept.decisionID] else { return [] }
            return Set([Self.experimentTarget(in: document, experimentID: finding.experimentID) ?? decision.targetObjectID, decision.targetObjectID])
        case .setSummaryLine(let line):
            return Set(line.line.references.compactMap {
                $0.kind == .object ? ObjectID($0.id) : nil
            })
        default:
            // A command about the document as a whole, about a comparison, a
            // frame, a source revision, or a synthesis, is not about any one
            // object in it.
            return []
        }
    }
}
