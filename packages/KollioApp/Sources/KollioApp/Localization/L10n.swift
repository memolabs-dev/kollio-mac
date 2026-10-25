import Foundation

/// Every user-facing string in the interface, in French and English.
///
/// Strings live in a native String Catalog (`Resources/Localizable.xcstrings`).
/// Keys are semantic, never shown. User-authored document content is *not*
/// translated when the interface language changes: only the interface is.
/// Anchor used to find the app bundle when the code is not built by SwiftPM.
private final class BundleToken {}

public enum L10n {
    /// The catalog lives in a resource bundle under SwiftPM, and in the app
    /// bundle under Xcode. One accessor serves both build systems.
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return Bundle(for: BundleToken.self)
        #endif
    }

    static func callAsFunction(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), table: "Localizable", bundle: bundle)
    }

    // Canvas actions
    public static var explore: String { callAsFunction("canvas.explore") }
    public static var add: String { callAsFunction("canvas.add") }
    public static var setAside: String { callAsFunction("canvas.setAside") }
    public static var moreActions: String { callAsFunction("canvas.moreActions") }
    public static var keep: String { callAsFunction("canvas.keep") }
    /// The action that centres the view on a proposal that is off screen. It is
    /// never automatic: a camera that moves by itself takes the view away.
    public static var seeProposal: String { callAsFunction("action.seeProposal") }
    public static var seeProposalHint: String { callAsFunction("action.seeProposalHint") }
    public static var reopen: String { callAsFunction("canvas.reopen") }
    public static var clarify: String { callAsFunction("canvas.clarify") }
    public static var proposal: String { callAsFunction("canvas.proposal") }
    public static var setAsideReason: String { callAsFunction("canvas.setAsideReason") }
    public static var cancel: String { callAsFunction("canvas.cancel") }

    // First experience
    public static var initialTitle: String { callAsFunction("document.initialPrompt") }
    public static var initialSubtitle: String { callAsFunction("document.initialSubtitle") }
    public static var initialPlaceholder: String { callAsFunction("document.initialPlaceholder") }
    public static var seedDirectionA: String { callAsFunction("seed.directionA") }
    public static var seedDirectionB: String { callAsFunction("seed.directionB") }
    public static var seedDirectionAEN: String { callAsFunction("seed.directionA.en") }
    public static var seedDirectionBEN: String { callAsFunction("seed.directionB.en") }

    // Composer
    public static var composerPlaceholder: String { callAsFunction("composer.placeholder") }
    public static var composerAddPlaceholder: String { callAsFunction("composer.addPlaceholder") }
    public static var composerHint: String { callAsFunction("composer.hint") }
    public static var composerEditPlaceholder: String { callAsFunction("composer.editPlaceholder") }
    public static var edit: String { callAsFunction("canvas.edit") }
    public static var composerSetAsidePlaceholder: String { callAsFunction("composer.setAsidePlaceholder") }
    public static var composerSetAsideHint: String { callAsFunction("composer.setAsideHint") }

    // Sources
    public static var sourceReadFailed: String { callAsFunction("source.readFailed") }
    public static var addSource: String { callAsFunction("source.add") }
    public static var addSourceHint: String { callAsFunction("source.addHint") }
    public static var undoAttachSource: String { callAsFunction("undo.attachSource") }
    public static var undoRecordVerification: String { callAsFunction("undo.recordVerification") }
    public static var undoAddCitation: String { callAsFunction("undo.addCitation") }
    public static var claimScopeEmpty: String { callAsFunction("claim.scopeEmpty") }
    public static var undoAssertClaim: String { callAsFunction("undo.assertClaim") }
    public static var undoRecordStance: String { callAsFunction("undo.recordStance") }
    public static var statusAnswerSuperseded: String { callAsFunction("status.answerSuperseded") }
    public static var retry: String { callAsFunction("action.retry") }
    public static var retryHint: String { callAsFunction("action.retryHint") }
    public static var cancelHint: String { callAsFunction("action.cancelHint") }
    public static var undoAskClarification: String { callAsFunction("undo.askClarification") }
    public static var undoAnswerClarification: String { callAsFunction("undo.answerClarification") }
    public static var undoMarkUnknown: String { callAsFunction("undo.markUnknown") }
    public static var clarificationEmpty: String { callAsFunction("clarification.empty") }
    public static var clarificationAnswerPlaceholder: String { callAsFunction("clarification.answerPlaceholder") }
    public static var clarificationAnswer: String { callAsFunction("clarification.answer") }
    public static var clarificationUnknown: String { callAsFunction("clarification.unknown") }
    public static var clarificationUnknownHint: String { callAsFunction("clarification.unknownHint") }

    // Relations: what a link says, and the explicit ways to change it.
    public static var relationshipIncomplete: String { callAsFunction("relationship.incomplete") }
    public static var relationshipFromPerson: String { callAsFunction("relationship.fromPerson") }
    public static var relationshipFromModel: String { callAsFunction("relationship.fromModel") }
    public static var relationshipChangeKind: String { callAsFunction("relationship.changeKind") }
    public static var relationshipChangeKindHint: String { callAsFunction("relationship.changeKindHint") }
    public static var relationshipReverse: String { callAsFunction("relationship.reverse") }
    public static var relationshipReverseHint: String { callAsFunction("relationship.reverseHint") }
    public static var clarificationUnknownDone: String { callAsFunction("clarification.unknownDone") }
    public static func claimScopeTitle(default object: String) -> String {
        String(format: callAsFunction("claim.scopeTitle"), object)
    }
    public static var claimStateHypothesis: String { callAsFunction("claim.hypothesis") }
    public static var claimStateConstraint: String { callAsFunction("claim.constraint") }
    public static var claimStateOpen: String { callAsFunction("claim.open") }
    public static var claimStateSupported: String { callAsFunction("claim.supported") }
    public static var claimStateContradicted: String { callAsFunction("claim.contradicted") }
    public static var claimStateRefuted: String { callAsFunction("claim.refuted") }
    public static var claimStateSatisfied: String { callAsFunction("claim.satisfied") }
    public static var claimStateNotApplicable: String { callAsFunction("claim.notApplicable") }
    public static var claimComposerPrompt: String { callAsFunction("claim.composerPrompt") }
    public static var experimentComposerPrompt: String { callAsFunction("experiment.composerPrompt") }
    public static var experimentQuestionPlaceholder: String { callAsFunction("experiment.questionPlaceholder") }
    public static var experimentCriterionPlaceholder: String { callAsFunction("experiment.criterionPlaceholder") }
    public static var experimentMethodPlaceholder: String { callAsFunction("experiment.methodPlaceholder") }
    public static var experimentBuild: String { callAsFunction("experiment.build") }
    public static var experimentIsSimulation: String { callAsFunction("experiment.isSimulation") }
    public static var experimentSimulationHint: String { callAsFunction("experiment.simulationHint") }
    public static var experimentEvidenceHint: String { callAsFunction("experiment.evidenceHint") }
    public static var experimentQuestionEmpty: String { callAsFunction("experiment.questionEmpty") }
    public static var experimentCriterionEmpty: String { callAsFunction("experiment.criterionEmpty") }
    public static var undoCreateExperiment: String { callAsFunction("undo.createExperiment") }
    public static var experimentReviewAction: String { callAsFunction("experiment.reviewAction") }
    public static var resultPrompt: String { callAsFunction("result.prompt") }
    public static var resultRecorded: (Int) -> String { { count in
        String(format: callAsFunction("result.recorded"), count)
    } }
    public static var resultObservedLabel: String { callAsFunction("result.observedLabel") }
    public static var resultMeasuredLabel: String { callAsFunction("result.measuredLabel") }
    public static var resultLimitsLabel: String { callAsFunction("result.limitsLabel") }
    public static var resultLearningPlaceholder: String { callAsFunction("result.learningPlaceholder") }
    public static var historyTitle: String { callAsFunction("history.title") }
    public static var historyReviewAction: String { callAsFunction("history.reviewAction") }
    public static var historyLaterReverted: String { callAsFunction("history.laterReverted") }
    public static var historyClose: String { callAsFunction("history.close") }
    public static var historyPreview: String { callAsFunction("history.preview") }
    public static var historyPreviewTitle: String { callAsFunction("history.previewTitle") }
    public static var historyRestore: String { callAsFunction("history.restore") }
    public static var historyRestoreLabel: String { callAsFunction("history.restoreLabel") }
    public static var historyPurge: String { callAsFunction("history.purge") }
    public static var historyPurgeTitle: String { callAsFunction("history.purgeTitle") }
    /// %1$@ days, %2$@ actions. The count is in the button, not only in the
    /// message, so the decision is taken with the number in front of it.
    public static func historyPurgeConfirm(_ days: Int, _ count: Int) -> String {
        String(format: callAsFunction("history.purgeConfirm"), days, count)
    }
    public static var historyPurgeWarning: String { callAsFunction("history.purgeWarning") }
    public static var historyPreviewNothingChanged: String { callAsFunction("history.previewNothingChanged") }
    /// %1$@ was the text, %2$@ is the text. Both readings, because "changed"
    /// without "to what" says nothing.
    public static func historyDiffText(_ from: String, _ to: String) -> String {
        String(format: callAsFunction("history.diffText"), from, to)
    }
    public static func historyDiffAdded(_ now: String) -> String {
        String(format: callAsFunction("history.diffAdded"), now)
    }
    public static func historyDiffRemoved(_ then: String) -> String {
        String(format: callAsFunction("history.diffRemoved"), then)
    }
    /// %1$@ is the kind's verb in the interface's language, %2$@ the other end's
    /// identifier. An identifier rather than a title: the other object may be one
    /// this person cannot read, and naming it by what it says would be inventing.
    public static func historyDiffLinkAdded(_ verb: String, _ other: String) -> String {
        String(format: callAsFunction("history.diffLinkAdded"), verb, other)
    }
    public static func historyDiffLinkRemoved(_ verb: String, _ other: String) -> String {
        String(format: callAsFunction("history.diffLinkRemoved"), verb, other)
    }
    /// %1$@ objects, %2$@ relations, revision %3$@. Counts, never a sentence
    /// about what the document contains: this is a position, not a summary.
    public static func historyPreviewSummary(_ objects: Int, _ relations: Int, _ revision: Int) -> String {
        String(
            format: callAsFunction("history.previewSummary"),
            objects, relations, revision
        )
    }
    public static var resultObservationPlaceholder: String { callAsFunction("result.observationPlaceholder") }
    public static var resultMeasurementPlaceholder: String { callAsFunction("result.measurementPlaceholder") }
    public static var resultUnitPlaceholder: String { callAsFunction("result.unitPlaceholder") }
    public static var resultLimitsPlaceholder: String { callAsFunction("result.limitsPlaceholder") }
    public static var resultInconclusive: String { callAsFunction("result.inconclusive") }
    public static var resultReasonPlaceholder: String { callAsFunction("result.reasonPlaceholder") }
    public static var resultCriterionMet: String { callAsFunction("result.criterionMet") }
    public static var resultCriterionNotMet: String { callAsFunction("result.criterionNotMet") }
    public static var resultRecord: String { callAsFunction("result.record") }
    public static var resultObservationEmpty: String { callAsFunction("result.observationEmpty") }
    public static var resultMeasurementIncomplete: String { callAsFunction("result.measurementIncomplete") }
    public static var resultReasonMissing: String { callAsFunction("result.reasonMissing") }
    public static var resultLearningEmpty: String { callAsFunction("result.learningEmpty") }
    public static var resultOutcomeLabel: String { callAsFunction("result.outcomeLabel") }
    public static var undoRecordResult: String { callAsFunction("undo.recordResult") }
    public static var undoProposeLearning: String { callAsFunction("undo.proposeLearning") }
    public static var experimentCardTitle: String { callAsFunction("experiment.cardTitle") }
    public static var experimentCardQuestion: String { callAsFunction("experiment.cardQuestion") }
    public static var experimentCardMethod: String { callAsFunction("experiment.cardMethod") }
    public static var experimentCardCriterion: String { callAsFunction("experiment.cardCriterion") }
    public static var experimentCardEvidence: String { callAsFunction("experiment.cardEvidence") }
    public static var experimentCardClose: String { callAsFunction("experiment.cardClose") }
    public static func experimentCardRevisions(_ count: Int) -> String {
        String(format: callAsFunction("experiment.cardRevisions"), count)
    }
    public static var claimCriterionPlaceholder: String { callAsFunction("claim.criterionPlaceholder") }
    public static var claimScopeHint: String { callAsFunction("claim.scopeHint") }
    public static var claimStateIt: String { callAsFunction("claim.stateIt") }
    public static var claimObservationPlaceholder: String { callAsFunction("claim.observationPlaceholder") }
    public static var claimRecordStance: String { callAsFunction("claim.recordStance") }
    public static func claimScopeCount(_ count: Int) -> String {
        String(format: callAsFunction("claim.scopeCount"), count)
    }
    public static var citationSelectPrompt: String { callAsFunction("citations.selectPrompt") }
    public static var citationSelectHint: String { callAsFunction("citations.selectHint") }
    public static var citationCiteSelection: String { callAsFunction("citations.citeSelection") }
    public static var citationsTitle: String { callAsFunction("citations.title") }
    public static var citationVerify: String { callAsFunction("citations.verify") }
    public static var citationVerifyHint: String { callAsFunction("citations.verifyHint") }
    public static var citationObservationPlaceholder: String { callAsFunction("citations.observation") }
    public static var citationRecord: String { callAsFunction("citations.record") }
    public static var citationUnverified: String { callAsFunction("citations.unverified") }
    public static var citationVerified: String { callAsFunction("citations.verified") }
    public static var citationNeedsReview: String { callAsFunction("citations.needsReview") }
    public static var citationSuperseded: String { callAsFunction("citations.superseded") }
    public static var citationNoPassage: String { callAsFunction("citations.noPassage") }
    public static var citationsEmpty: String { callAsFunction("citations.empty") }
    public static var sourceOpenInReader: String { callAsFunction("source.openInReader") }
    public static var sourceOpenInReaderHint: String { callAsFunction("source.openInReaderHint") }
    /// %lld is how many rows the file really has, so the cap is not a mystery.
    public static func citationTableCapped(_ rows: Int) -> String {
        String(format: callAsFunction("citations.tableCapped"), rows)
    }
    public static func sourceAttached(_ title: String) -> String {
        String(format: callAsFunction("source.attached"), title)
    }
    public static func sourceAttachedWithoutText(_ title: String, _ reason: String) -> String {
        String(format: callAsFunction("source.attachedWithoutText"), title, reason)
    }
    public static func sourceChip(_ title: String) -> String { callAsFunction("source.chip") }
    public static func sourceChipCount(_ title: String, _ count: Int) -> String {
        String(format: callAsFunction("source.chipCount"), title, count)
    }
    public static func sourceChipAccessibility(_ title: String, _ state: String) -> String {
        String(format: callAsFunction("source.chipAccessibility"), title, state)
    }
    public static var sourceStateNotRead: String { callAsFunction("source.state.notRead") }
    public static var sourceStateImporting: String { callAsFunction("source.state.importing") }
    public static var sourceStateReady: String { callAsFunction("source.state.ready") }
    public static var sourceStatePartial: String { callAsFunction("source.state.partial") }
    public static var sourceStateNoText: String { callAsFunction("source.state.noText") }
    public static var sourceStateUnsupported: String { callAsFunction("source.state.unsupported") }
    public static var sourceStateMissing: String { callAsFunction("source.state.missing") }
    public static var sourceStateUnverifiable: String { callAsFunction("source.state.unverifiable") }

    // Impact of new information
    public static var impactReviewAction: String { callAsFunction("impact.reviewAction") }
    public static var impactTitle: String { callAsFunction("impact.title") }
    public static var impactNeedsReview: String { callAsFunction("impact.needsReview") }
    public static var impactStaysValid: String { callAsFunction("impact.staysValid") }
    public static var impactMark: String { callAsFunction("impact.mark") }
    public static var impactMarkHint: String { callAsFunction("impact.markHint") }
    public static var impactNotNow: String { callAsFunction("impact.notNow") }
    public static var impactNothingMoved: String { callAsFunction("impact.nothingMoved") }
    public static var impactReasonMoved: String { callAsFunction("impact.reason.moved") }
    public static var impactReasonLost: String { callAsFunction("impact.reason.lost") }
    public static var impactReasonRelies: String { callAsFunction("impact.reason.relies") }
    public static var impactUnaffectedCurrent: String { callAsFunction("impact.unaffected.current") }
    public static var impactUnaffectedLink: String { callAsFunction("impact.unaffected.link") }
    public static var impactUnaffectedSetAside: String { callAsFunction("impact.unaffected.setAside") }
    public static var impactTruncated: String { callAsFunction("impact.truncated") }
    public static var undoApplyImpact: String { callAsFunction("undo.applyImpact") }
    /// %lld citations read, %lld objects walked, %lld links followed.
    public static func impactReadSet(_ citations: Int, _ objects: Int, _ links: Int) -> String {
        String(format: callAsFunction("impact.readSet"), citations, objects, links)
    }
    /// %lld is how many objects were marked, said after the fact rather than before.
    public static func impactMarked(_ count: Int) -> String {
        String(format: callAsFunction("impact.marked"), count)
    }

    // Status
    public static var statusNoChange: String { callAsFunction("status.noChange") }
    public static var statusKept: String { callAsFunction("status.kept") }
    public static var statusDiscarded: String { callAsFunction("status.discarded") }
    public static var statusSaved: String { callAsFunction("status.saved") }
    public static var statusThinking: String { callAsFunction("status.thinking") }
    /// %lld is how many directions have arrived so far, while the answer streams.
    public static func progressDirections(_ count: Int, languageCode: String) -> String {
        String(format: callAsFunction("progress.directions"), count)
    }
    public static var errorGeneric: String { callAsFunction("error.generic") }
    public static var errorEditConflict: String { callAsFunction("error.editConflict") }
    public static var errorSaveFailed: String { callAsFunction("error.saveFailed") }
    public static var errorLoadFailed: String { callAsFunction("error.loadFailed") }
    public static var submitHint: String { callAsFunction("action.submitHint") }
    public static var sourceOnDevice: String { callAsFunction("source.onDevice") }
    /// %@ is the real reason reported by the framework, in the user's language.
    public static func sourceUnavailable(_ reason: String) -> String {
        String(format: callAsFunction("source.unavailable"), reason)
    }

    // Frames: a named group on the canvas, folded or not
    public static var frameGroupAction: String { callAsFunction("frame.group") }
    public static var frameDefaultName: String { callAsFunction("frame.defaultName") }
    public static var frameNamePrompt: String { callAsFunction("frame.namePrompt") }
    public static var frameNameEmpty: String { callAsFunction("frame.nameEmpty") }
    public static var frameNamePlaceholder: String { callAsFunction("frame.namePlaceholder") }
    public static var frameRename: String { callAsFunction("frame.rename") }
    public static var frameRenameHint: String { callAsFunction("frame.renameHint") }
    public static var frameFold: String { callAsFunction("frame.fold") }
    public static var frameFoldHint: String { callAsFunction("frame.foldHint") }
    public static var frameUnfold: String { callAsFunction("frame.unfold") }
    public static var frameRemove: String { callAsFunction("frame.remove") }
    public static var frameRemoveHint: String { callAsFunction("frame.removeHint") }
    public static var frameRemoveConfirm: String { callAsFunction("frame.removeConfirm") }
    public static var frameNothingSelected: String { callAsFunction("frame.nothingSelected") }
    /// %lld is how many drawings the frame holds.
    public static func frameCount(_ count: Int) -> String {
        String(format: callAsFunction("frame.count"), count)
    }
    /// %@ is the frame's name, %@ how much is inside it.
    public static func frameFoldedAccessibility(_ name: String, _ count: String) -> String {
        String(format: callAsFunction("frame.foldedAccessibility"), name, count)
    }
    public static var undoCreateFrame: String { callAsFunction("undo.createFrame") }
    public static var undoRenameFrame: String { callAsFunction("undo.renameFrame") }
    public static var undoSetFrameMembers: String { callAsFunction("undo.setFrameMembers") }
    public static var undoMoveFrame: String { callAsFunction("undo.moveFrame") }
    public static var undoFoldFrame: String { callAsFunction("undo.foldFrame") }
    public static var undoRemoveFrame: String { callAsFunction("undo.removeFrame") }

    // Comparison: directions weighed against criteria, without invented scores
    public static var comparisonAction: String { callAsFunction("comparison.action") }
    public static var comparisonTitle: String { callAsFunction("comparison.title") }
    // MARK: Syntheses
    //
    // Every one of these is a catalog key rather than a `switch`, because the whole
    // point of the String Catalog is that a translator sees the string and its
    // context, and a French literal inside a Swift file is neither.

    // MARK: Proposal attribution (AI-11)

    public static var proposalLeftThisMachine: String { callAsFunction("proposal.leftThisMachine") }
    public static var proposalPromptVersionUnknown: String { callAsFunction("proposal.promptVersionUnknown") }
    public static var proposalWhy: String { callAsFunction("proposal.why") }
    public static var proposalLimitations: String { callAsFunction("proposal.limitations") }
    public static var proposalReferenceMissing: String { callAsFunction("proposal.referenceMissing") }
    public static var proposalDestinationOnDevice: String { callAsFunction("proposal.destination.onDevice") }
    public static var proposalDestinationPrivateCloud: String { callAsFunction("proposal.destination.privateCloud") }
    public static var proposalDestinationRemote: String { callAsFunction("proposal.destination.remote") }
    public static var proposalDestinationDemo: String { callAsFunction("proposal.destination.demo") }

    public static func proposalRead(_ count: Int) -> String {
        String(
            format: callAsFunction(count > 1 ? "proposal.readPlural" : "proposal.read"),
            count
        )
    }

    // MARK: The scope of an answer (AI-12)

    public static var proposalScopeTitle: String { callAsFunction("proposal.scopeTitle") }
    /// The whole answer, every time. Said in full rather than only when something
    /// was left out, so the line that is normally quiet is still a fact.
    public static func proposalScopeComplete(_ read: Int) -> String {
        String(format: callAsFunction("proposal.scopeComplete"), read)
    }
    public static func proposalScopeNarrowed(_ read: Int, _ omitted: Int) -> String {
        String(format: callAsFunction("proposal.scopeNarrowed"), read, omitted)
    }
    /// The status line, when the answer was produced from less than the whole
    /// document. Not the attribution panel: this one is not behind a disclosure,
    /// because the scope of an answer is part of the answer.
    public static func statusContextNarrowed(_ omitted: Int) -> String {
        String(format: callAsFunction("status.contextNarrowed"), omitted)
    }

    // MARK: The on-device model (AI-12, CTX-06)

    public static var appleOnThisMac: String { callAsFunction("apple.onThisMac") }
    public static var appleNotEligible: String { callAsFunction("apple.notEligible") }
    public static var appleIntelligenceDisabled: String { callAsFunction("apple.intelligenceDisabled") }
    public static var appleAssetsNotReady: String { callAsFunction("apple.assetsNotReady") }
    public static var appleFrameworkUnavailable: String { callAsFunction("apple.frameworkUnavailable") }
    public static func appleUnsupportedLanguage(_ language: String) -> String {
        String(format: callAsFunction("apple.unsupportedLanguage"), language)
    }
    public static var appleGenerationFailed: String { callAsFunction("apple.generationFailed") }
    /// Shown when a required part of the request does not fit the model's window.
    /// It asks for a narrower question rather than answering about less and saying
    /// nothing, which is the only honest way to handle a constraint that will not
    /// fit.
    public static var appleContextTooLarge: String { callAsFunction("apple.contextTooLarge") }

    // MARK: Presentation (CAN-10)

    public static var presentation: String { callAsFunction("presentation.title") }
    public static var presentationStart: String { callAsFunction("presentation.start") }
    public static var presentationExit: String { callAsFunction("presentation.exit") }
    public static var presentationNext: String { callAsFunction("presentation.next") }
    public static var presentationPrevious: String { callAsFunction("presentation.previous") }
    public static var presentationReadOnly: String { callAsFunction("presentation.readOnly") }
    public static var presentationNothingToPresent: String { callAsFunction("presentation.nothingToPresent") }
    public static var presentationSkipped: String { callAsFunction("presentation.skipped") }
    public static var presentationNoAnchor: String { callAsFunction("presentation.noAnchor") }
    public static var presentationOpenSource: String { callAsFunction("presentation.openSource") }
    public static var presentationKindObject: String { callAsFunction("presentation.kind.object") }
    public static var presentationKindSource: String { callAsFunction("presentation.kind.source") }
    public static var presentationKindDecision: String { callAsFunction("presentation.kind.decision") }
    public static func presentationProgress(_ position: Int, _ total: Int) -> String {
        String(format: callAsFunction("presentation.progress"), position, total)
    }

    // MARK: Search (CAN-09)

    public static var search: String { callAsFunction("search.title") }
    public static var searchPlaceholder: String { callAsFunction("search.placeholder") }
    public static var searchClear: String { callAsFunction("search.clear") }
    public static var searchClearHint: String { callAsFunction("search.clearHint") }
    public static var searchNoResults: String { callAsFunction("search.noResults") }
    public static var searchStateVisible: String { callAsFunction("search.state.visible") }
    public static var searchStateSetAside: String { callAsFunction("search.state.setAside") }
    public static var searchStateArchived: String { callAsFunction("search.state.archived") }
    public static var searchFieldTitle: String { callAsFunction("search.field.title") }
    public static var searchFieldBody: String { callAsFunction("search.field.body") }
    public static var searchFieldReason: String { callAsFunction("search.field.reason") }
    public static var searchNotSearched: String { callAsFunction("search.notSearched") }
    public static func searchNotSearchedSources(_ count: Int) -> String {
        String(format: callAsFunction("search.notSearchedSources"), count)
    }
    /// What is not in the result set, in one line. "No results" and "nothing was
    /// searched" are different answers and only one of them is ever true.
    public static func searchPartial(_ skipped: Int) -> String {
        String(format: callAsFunction("search.partial"), skipped)
    }
    public static var searchReopenHint: String { callAsFunction("search.reopenHint") }

    public static var summaryDefaultTitle: String { callAsFunction("summary.defaultTitle") }
    public static var summaryDefaultObjective: String { callAsFunction("summary.defaultObjective") }
    public static var summaryNothingRecorded: String { callAsFunction("summary.nothingRecorded") }
    public static var summaryNotWritten: String { callAsFunction("summary.notWritten") }
    public static var summaryUncertainties: String { callAsFunction("summary.uncertainties") }
    public static var summaryNothingUncertain: String { callAsFunction("summary.nothingUncertain") }
    public static var summaryOutdated: String { callAsFunction("summary.outdated") }
    public static var summaryDraft: String { callAsFunction("summary.draft") }
    public static var summaryConfirm: String { callAsFunction("summary.confirm") }
    public static var summaryExport: String { callAsFunction("summary.export") }
    public static var summaryExpand: String { callAsFunction("summary.expand") }
    public static var summaryCollapse: String { callAsFunction("summary.collapse") }
    public static var summaryCorrected: String { callAsFunction("summary.corrected") }
    public static var summaryExported: String { callAsFunction("summary.exported") }
    public static var summaryExportedOutdated: String { callAsFunction("summary.exportedOutdated") }
    public static var undoStartSummary: String { callAsFunction("undo.startSummary") }
    public static var undoConfirmSummary: String { callAsFunction("undo.confirmSummary") }

    /// Named after the count, so two syntheses can be told apart in a list before
    /// either is opened.
    public static func summaryTitle(forSelection count: Int) -> String {
        String(
            format: callAsFunction(count > 1 ? "summary.titlePlural" : "summary.titleSingular"),
            count
        )
    }

    public static func summaryCannotConfirm(section: String) -> String {
        String(format: callAsFunction("summary.cannotConfirm"), section)
    }

    public static func summaryUncertaintyCount(_ count: Int) -> String {
        String(
            format: callAsFunction(count > 1 ? "summary.uncertaintyCountPlural" : "summary.uncertaintyCount"),
            count
        )
    }

    public static func summaryRevision(_ revision: Int) -> String {
        String(format: callAsFunction("summary.revision"), revision)
    }

    public static func summarySourceCount(_ count: Int) -> String {
        String(
            format: callAsFunction(count > 1 ? "summary.sourceCountPlural" : "summary.sourceCount"),
            count
        )
    }

    public static var comparisonDefaultTitle: String { callAsFunction("comparison.defaultTitle") }
    public static var comparisonNeedsTwo: String { callAsFunction("comparison.needsTwo") }
    public static var comparisonCriterionEmpty: String { callAsFunction("comparison.criterionEmpty") }
    public static var comparisonIsDraft: String { callAsFunction("comparison.isDraft") }
    public static var comparisonDraftHint: String { callAsFunction("comparison.draftHint") }
    public static var comparisonConfirm: String { callAsFunction("comparison.confirm") }
    public static var comparisonCriteria: String { callAsFunction("comparison.criteria") }
    public static var comparisonCriterionPlaceholder: String { callAsFunction("comparison.criterionPlaceholder") }
    public static var comparisonAddCriterion: String { callAsFunction("comparison.addCriterion") }
    public static var comparisonNoCriterion: String { callAsFunction("comparison.noCriterion") }
    public static var comparisonNotRecorded: String { callAsFunction("comparison.notRecorded") }
    public static var comparisonRecord: String { callAsFunction("comparison.record") }
    public static var comparisonRecordValue: String { callAsFunction("comparison.recordValue") }
    public static var comparisonValuePlaceholder: String { callAsFunction("comparison.valuePlaceholder") }
    public static var comparisonNoMeasure: String { callAsFunction("comparison.noMeasure") }
    public static var comparisonMeasure: String { callAsFunction("comparison.measure") }
    public static var comparisonWeight: String { callAsFunction("comparison.weight") }
    public static var comparisonUnitPlaceholder: String { callAsFunction("comparison.unitPlaceholder") }
    public static var comparisonWeightPlaceholder: String { callAsFunction("comparison.weightPlaceholder") }
    public static var comparisonDirectionHint: String { callAsFunction("comparison.directionHint") }
    public static var comparisonWeightInvalid: String { callAsFunction("comparison.weightInvalid") }
    public static var comparisonSave: String { callAsFunction("comparison.save") }
    public static var comparisonNoTotal: String { callAsFunction("comparison.noTotal") }
    public static var comparisonKeep: String { callAsFunction("comparison.keep") }
    public static var comparisonKept: String { callAsFunction("comparison.kept") }
    public static var comparisonKeepHint: String { callAsFunction("comparison.keepHint") }
    /// %lld is how many things a cell rests on.
    public static func comparisonReferences(_ count: Int) -> String {
        String(format: callAsFunction("comparison.references"), count)
    }
    public static var comparisonNeedsReview: String { callAsFunction("comparison.needsReview") }
    public static var comparisonReviewGone: String { callAsFunction("comparison.reviewGone") }
    public static var comparisonReviewObjectChanged: String { callAsFunction("comparison.reviewObjectChanged") }
    public static var comparisonReviewEvidenceMoved: String { callAsFunction("comparison.reviewEvidenceMoved") }
    /// %lld is how many cells of a direction hold something.
    public static func comparisonCellCount(_ count: Int) -> String {
        String(format: callAsFunction("comparison.cellCount"), count)
    }
    public static var comparisonClose: String { callAsFunction("comparison.close") }
    public static var undoStartComparison: String { callAsFunction("undo.startComparison") }
    public static var undoSetComparisonCriteria: String { callAsFunction("undo.setComparisonCriteria") }
    public static var undoConfirmComparison: String { callAsFunction("undo.confirmComparison") }
    public static var undoRecordCell: String { callAsFunction("undo.recordCell") }
    public static var undoSetWeight: String { callAsFunction("undo.setWeight") }
    public static var undoSetMeasure: String { callAsFunction("undo.setMeasure") }
    public static var undoKeepDirection: String { callAsFunction("undo.keepDirection") }

    // Undo labels
    public static var undoMove: String { callAsFunction("undo.move") }
    public static var undoRenameDocument: String { callAsFunction("undo.renameDocument") }
    public static var actionDuplicateOccurrence: String { callAsFunction("action.duplicateOccurrence") }
    public static var actionDuplicateVariant: String { callAsFunction("action.duplicateVariant") }
    public static var actionRemoveOccurrence: String { callAsFunction("action.removeOccurrence") }
    public static var actionRemoveObject: String { callAsFunction("action.removeObject") }
    public static var actionKeepOccurrence: String { callAsFunction("action.keepOccurrence") }
    public static var actionLoseIdea: String { callAsFunction("action.loseIdea") }
    public static var undoAddNote: String { callAsFunction("undo.addNote") }
    public static var undoCreate: String { callAsFunction("undo.create") }
    public static var undoDuplicateOccurrence: String { callAsFunction("undo.duplicateOccurrence") }
    public static var undoDuplicateVariant: String { callAsFunction("undo.duplicateVariant") }
    public static var undoRemoveOccurrence: String { callAsFunction("undo.removeOccurrence") }
    public static var undoRemoveObject: String { callAsFunction("undo.removeObject") }
    public static var undoKeepProposal: String { callAsFunction("undo.keepProposal") }
    public static var undoSetAside: String { callAsFunction("undo.setAside") }
    public static var undoReopen: String { callAsFunction("undo.reopen") }
    public static var undoEdit: String { callAsFunction("undo.edit") }

    // Menu
    public static var newDocument: String { callAsFunction("menu.newDocument") }
    public static var openDemo: String { callAsFunction("menu.openDemo") }
    public static var save: String { callAsFunction("menu.save") }
    public static var renameDocument: String { callAsFunction("document.rename") }
    public static var duplicateDocument: String { callAsFunction("document.duplicate") }
    public static var documentName: String { callAsFunction("document.name") }
    public static var exportMarkdown: String { callAsFunction("document.exportMarkdown") }
    public static var exportKollio: String { callAsFunction("document.exportKollio") }
    public static var exportPNG: String { callAsFunction("document.exportPNG") }
    public static var exportAssets: String { callAsFunction("document.exportAssets") }
    public static var assetsArchiveSuffix: String { callAsFunction("document.assetsArchiveSuffix") }
    public static var assetsArchiveEmpty: String { callAsFunction("document.assetsArchiveEmpty") }
    public static func assetsArchived(copied: Int, missing: Int) -> String {
        String(format: callAsFunction("document.assetsArchived"), copied, missing)
    }
    public static var copySuffix: String { callAsFunction("document.copySuffix") }
    public static var fit: String { callAsFunction("menu.fit") }
    public static var actualSize: String { callAsFunction("menu.actualSize") }
    public static var undo: String { callAsFunction("menu.undo") }
    public static var redo: String { callAsFunction("menu.redo") }
}
