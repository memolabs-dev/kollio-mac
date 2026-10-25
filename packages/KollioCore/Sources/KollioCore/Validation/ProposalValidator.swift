import Foundation

/// A syntactically valid JSON answer is not a valid proposal. The client runs
/// these checks before showing a ghost branch, and the server runs them again
/// before answering.
public struct ProposalValidator: Sendable {
    public struct Limits: Codable, Hashable, Sendable {
        public var maxOperations: Int
        public var maxNewObjects: Int
        public var maxRationaleLength: Int

        public init(maxOperations: Int = 8, maxNewObjects: Int = 6, maxRationaleLength: Int = 400) {
            self.maxOperations = maxOperations
            self.maxNewObjects = maxNewObjects
            self.maxRationaleLength = maxRationaleLength
        }
    }

    public init() {}

    public func validate(
        _ proposal: Proposal,
        against document: KollioDocument,
        scope: ProposalRequest.Scope,
        limits: Limits = Limits()
    ) throws {
        guard proposal.documentId == document.documentId else {
            throw DocumentError.staleProposal(reason: "documentId mismatch")
        }
        guard proposal.baseSemanticRevision == document.semanticRevision else {
            throw DocumentError.staleProposal(
                reason: "baseSemanticRevision \(proposal.baseSemanticRevision) != \(document.semanticRevision)"
            )
        }
        guard proposal.operations.count <= min(limits.maxOperations, scope.maxOperations) else {
            throw DocumentError.tooManyOperations(proposal.operations.count)
        }
        guard proposal.rationale?.text.count ?? 0 <= limits.maxRationaleLength else {
            throw DocumentError.forbiddenOperation("rationale too long")
        }

        var newObjectCount = 0
        var virtual: Set<ObjectID> = []
        for operation in proposal.operations {
            switch operation {
            case .renameDocument:
                throw DocumentError.forbiddenOperation("document identity is the user's to change")
            case .createObject(let create):
                guard scope.allowNewObjects else {
                    throw DocumentError.forbiddenOperation("createObject outside scope")
                }
                newObjectCount += 1
                guard newObjectCount <= limits.maxNewObjects else {
                    throw DocumentError.tooManyOperations(proposal.operations.count)
                }
                guard document.content[create.id] == nil else {
                    throw DocumentError.duplicateObject(create.id)
                }
                guard !create.text.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw DocumentError.emptyText(create.id)
                }
                virtual.insert(create.id)
            case .updateObjectText(let update):
                guard document.content[update.id] != nil || virtual.contains(update.id) else {
                    throw DocumentError.unknownObject(update.id)
                }
            case .addRelationship(let add):
                guard add.from != add.to else { throw DocumentError.selfRelationship(add.id) }
                for endpoint in [add.from, add.to] {
                    guard document.content[endpoint] != nil || virtual.contains(endpoint) else {
                        throw DocumentError.unknownObject(endpoint)
                    }
                }
                guard document.relationships[add.id] == nil else {
                    throw DocumentError.duplicateRelationship(add.id)
                }
            case .removeRelationship(let remove):
                guard document.relationships[remove.id] != nil else {
                    throw DocumentError.unknownRelationship(remove.id)
                }
            case .moveNodeInstances(let move):
                for one in move.moves where document.presentation.instance(id: one.instanceID) == nil {
                    throw DocumentError.unknownInstance(one.instanceID)
                }
            case .recordDecision(let decision):
                guard document.content[decision.targetObjectID] != nil || virtual.contains(decision.targetObjectID) else {
                    throw DocumentError.decisionTargetNotFound(decision.targetObjectID)
                }
            case .revokeDecision(let revoke):
                guard document.decisions[revoke.id] != nil else {
                    throw DocumentError.unknownDecision(revoke.id)
                }
            case .addContributionToProduct(let add):
                guard document.contributions[add.contributionID] != nil else {
                    throw DocumentError.unknownContribution(add.contributionID)
                }
                guard (0...1).contains(add.share) else {
                    throw DocumentError.invalidShareRange(add.share)
                }
            case .duplicateObject(let duplicate):
                // A variant is an addition, so a proposal may make one. It is
                // charged against the same new-object budget as any other creation:
                // a patch that can fork the world is not bounded.
                guard scope.allowNewObjects else {
                    throw DocumentError.forbiddenOperation("duplicateObject outside scope")
                }
                guard document.content[duplicate.sourceID] != nil else {
                    throw DocumentError.unknownObject(duplicate.sourceID)
                }
                guard document.content[duplicate.id] == nil else {
                    throw DocumentError.duplicateObject(duplicate.id)
                }
                guard document.relationships[duplicate.relationshipID] == nil else {
                    throw DocumentError.duplicateRelationship(duplicate.relationshipID)
                }
                newObjectCount += 1
                guard newObjectCount <= limits.maxNewObjects else {
                    throw DocumentError.tooManyOperations(proposal.operations.count)
                }
                virtual.insert(duplicate.id)
            case .duplicateNodeInstance(let duplicate):
                guard document.presentation.instance(id: duplicate.instanceID) != nil else {
                    throw DocumentError.unknownInstance(duplicate.instanceID)
                }
            case .removeObject:
                // Intelligence never removes what a person wrote. A proposal is a
                // bounded addition; deletion is a decision, and the only actor
                // allowed to make it is the person whose thinking it would remove.
                throw DocumentError.forbiddenOperation("removeObject from a proposal")
            case .removeNodeInstance:
                throw DocumentError.forbiddenOperation("removeNodeInstance from a proposal")
            case .createScenario:
                throw DocumentError.forbiddenOperation("createScenario from a proposal")
            case .applyProposal:
                throw DocumentError.forbiddenOperation("nested applyProposal")
            case .rejectProposal:
                throw DocumentError.forbiddenOperation("rejectProposal")
            case .askClarification(let ask):
                // Asking is the one thing intelligence is allowed to do here. The
                // question is attached to an object and carries no answer, so a
                // proposal cannot pre-empt a person or write their reply for them.
                guard ask.clarification.state == .open else {
                    throw DocumentError.forbiddenOperation("a proposed question arrives open")
                }
            case .editRelationship:
                // Reversing a link is the most dangerous edit in the document: the
                // two ends look identical before and after and only the sentence
                // inverts. That is a person's to do, and so is rewriting what a
                // link is claimed to mean.
                throw DocumentError.forbiddenOperation("editing a relation is the user's to do")
            case .createFrame, .renameFrame, .setFrameMembers, .moveFrame,
                 .setFrameFolded, .removeFrame:
                // A frame is how a person tidies the canvas, and tidying is theirs.
                // A model that could create or fold a frame would be reorganising a
                // person's thinking to make its own output easier to present.
                throw DocumentError.forbiddenOperation("arranging the canvas is the user's to do")
            case .startComparison, .setComparisonCriteria, .confirmComparisonCriteria,
                 .recordComparisonCell,
                 .setCriterionWeight, .setCriterionMeasure, .keepDirection:
                // A comparison is a record of what a person weighed against what.
                // Intelligence may interpret a document; it may not write down that
                // one direction scored higher, and it may certainly not keep a
                // direction on the person's behalf, because keeping is a decision
                // with a rationale.
                throw DocumentError.forbiddenOperation("a comparison is the user's to record")
            case .startSummary, .setSummaryLine, .setSummarySection, .confirmSummary,
                 .removeSummary:
                // A synthesis is a deliverable, which makes it the most dangerous
                // thing in this list. Intelligence may interpret a document, and a
                // model that could write a synthesis could also hand it over: a
                // person who reads a summary and acts on it is reading something
                // nobody agreed to. Worse, it could confirm its own, and
                // confirmation is the act that makes it a deliverable.
                //
                // So every one of the five is refused, including the ones that
                // look harmless. A summary is produced here as a *proposal* of
                // lines, validated like any other proposal, and written by the
                // person who keeps it.
                throw DocumentError.forbiddenOperation("a synthesis is the user's to write and to hand over")
            case .applyImpact:
                // CTX-05: "intelligence may propose interpretations, never apply
                // them". An assessment is already a bounded interpretation, and
                // applying it writes durable decisions into the document. A model
                // that could mark a person's own hypothesis as needing review would
                // be annotating somebody's reasoning about their own work.
                throw DocumentError.forbiddenOperation("applying an impact is the user's to do")
            case .answerClarification, .markClarificationUnknown:                // Only a person answers. A model that could answer its own question
                // would be manufacturing the contribution the answer is supposed to
                // be, and would be able to record "I do not know" as a fact about
                // somebody else's uncertainty.
                throw DocumentError.forbiddenOperation("answering a question is the user's to do")
            case .assessHypothesis, .resolveConstraint:
                // Intelligence may suggest a claim and the role it plays, and the
                // person corrects it. It may not record how the claim stands: a
                // model that could mark its own hypothesis supported would be
                // grading its own work, and one that could mark a constraint
                // satisfied would be removing the obstacles to its own proposal.
                // Both are a person's to say.
                throw DocumentError.forbiddenOperation("assessing a claim is the user's to do")
            case .assertClaim(let assertion):
                // A suggested claim is allowed, but only as an open one. The
                // standing is dropped rather than refused, so a proposal can carry
                // "this looks like a constraint" without being able to assert that
                // the constraint is met.
                guard assertion.claim.assessment.isOpen,
                      assertion.claim.resolution.evidence == nil else {
                    throw DocumentError.forbiddenOperation("a proposed claim arrives open")
                }
            case .attachSource, .importSourceRevision, .addCitation,
                 .recordVerification, .removeSource:
                // Intelligence may propose an idea, never attach evidence to it and
                // never mark it verified. A model that could add a citation would be
                // able to manufacture the appearance of support, and one that could
                // record a verification could award itself a badge. Both are a
                // person's to do.
                throw DocumentError.forbiddenOperation("sources and citations are the user's to manage")
            case .createExperiment, .editExperiment:
                // Building and editing a validation experiment is a person's to do.
                // A model that could write the criterion a thing will be judged
                // against would be grading its own homework, and DEC-04 puts the
                // question and the criterion on the person's side of the line.
                throw DocumentError.forbiddenOperation("experiments are the user's to build")
            case .recordExperimentResult, .proposeLearning, .acceptLearning:
                // DEC-05 AC03, enforced rather than hoped for: the result is what
                // a person saw when they ran something, and a model that could
                // record, propose or accept it could manufacture the whole
                // outcome. The observation is on the person's side of the line.
                throw DocumentError.forbiddenOperation("results and learnings are the user's to record")
            case .restoreDocument:
                // Restoring replaces the canonical authored state. It is a
                // person's explicit history action, never an operation an
                // intelligence source may smuggle into a proposal.
                throw DocumentError.forbiddenOperation("history restoration is the user's to perform")
            }
        }

        for hint in proposal.placementHints {
            guard document.content[hint.objectID] != nil || virtual.contains(hint.objectID) else {
                throw DocumentError.unknownObject(hint.objectID)
            }
            if let relative = hint.relativeTo {
                guard document.content[relative] != nil || virtual.contains(relative) else {
                    throw DocumentError.unknownObject(relative)
                }
            }
        }
    }
}
