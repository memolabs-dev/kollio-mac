import Foundation
import KollioCore

/// The actions a selected object offers, split into what is shown and what is
/// behind the single named secondary control.
///
/// `SPECIFICATIONS.md` §Surfaces U02 fixes the primary set for an ordinary idea —
/// Explore, Add, Set aside — and names a secondary menu for the rest. The
/// requirement "contextual actions are few, named and reachable" adds the shape:
/// at most three primary, everything else behind one named entry.
///
/// The set lives here, in the model, rather than in the view, for one reason: a
/// limit that only exists as a layout is a limit nobody can test. This is the
/// only place that decides which actions an object has, and `maximumPrimary` is
/// checked here rather than hoped for in a `HStack`.
public struct ContextualActionSet: Hashable, Sendable {
    /// How many primary actions may be shown at once. Three is the specification's
    /// number, not a preference.
    public static let maximumPrimary = 3

    public enum Role: Hashable, Sendable {
        /// Shown as a button next to the object.
        case primary
        /// Reached through the one named secondary control.
        case secondary
    }

    public enum Kind: Hashable, Sendable, CaseIterable {
        case explore
        case add
        case setAside
        case reopen
        case edit
        case addSource
        case assertClaim
        case link
        case comment
        /// A second drawing of the same idea.
        case duplicateOccurrence
        /// The same thought as a new, linked idea.
        case duplicateVariant
        /// Take one drawing off the canvas.
        case removeOccurrence
        /// Take the idea out of the document.
        case removeObject
        /// See what new information touched, and what it left alone.
        case reviewImpact
        /// Put the selection in a named frame, and name it.
        case groupInFrame
        /// Weigh the selected directions against criteria, without inventing scores.
        case compareDirections
        case composeSynthesis
        /// Build a validation experiment on this reasoning (DEC-04).
        case buildExperiment
        /// Read an experiment already built on this reasoning.
        case reviewExperiment
        /// Read what happened to this object, in order (DEC-06).
        case reviewHistory

        /// The French and English label lives in `L10n`, not here, so the String
        /// Catalog stays the only place an interface string is written.
        ///
        /// Every value is a key that exists in the catalog. They did not all, and
        /// `String(localized:)` fails quietly: given a key it cannot find, it
        /// returns the key. The local action bar was therefore showing
        /// `explore`, `clarify` and `setAside` in a French window. The check that
        /// would have caught it is in `ContextualActionLabelTests`.
        public var localizationKey: String {
            switch self {
            case .explore: return "canvas.explore"
            case .add: return "canvas.add"
            case .setAside: return "canvas.setAside"
            case .reopen: return "canvas.reopen"
            case .edit: return "canvas.edit"
            case .addSource: return "source.add"
            case .assertClaim: return "claim.composerPrompt"
            case .link: return "action.link"
            case .comment: return "action.comment"
            case .duplicateOccurrence: return "action.duplicateOccurrence"
            case .duplicateVariant: return "action.duplicateVariant"
            case .removeOccurrence: return "action.removeOccurrence"
            case .removeObject: return "action.removeObject"
            case .reviewImpact: return "impact.reviewAction"
            case .groupInFrame: return "frame.group"
            case .compareDirections: return "comparison.action"
            case .composeSynthesis: return "summary.action"
            case .buildExperiment: return "experiment.composerPrompt"
            case .reviewExperiment: return "experiment.reviewAction"
            case .reviewHistory: return "history.reviewAction"
            }
        }
    }

    public let primary: [Kind]
    public let secondary: [Kind]
    /// The one action a person is most likely to want, and the only one drawn
    /// with the accent fill.
    public let isDefault: Kind?

    public init(primary: [Kind], secondary: [Kind], isDefault: Kind? = nil) {
        // The limit is enforced here rather than by a caller remembering it. A
        // fourth primary action is a programming error, not a layout problem, so
        // it is refused instead of silently demoted.
        precondition(
            primary.count <= Self.maximumPrimary,
            "\(primary.count) primary actions for one object; the specification allows \(Self.maximumPrimary)."
        )
        self.primary = primary
        self.secondary = secondary
        self.isDefault = isDefault
    }

    /// What an action does to the idea, as opposed to to the canvas. Used to group
    /// the menu and, in a confirmation, to say which of the two is being asked for.
    public enum Reach: Hashable, Sendable {
        /// Touches only what is drawn.
        case presentation
        /// Changes what the document says.
        case meaning
    }

    public func reach(of kind: Kind) -> Reach {
        switch kind {
        case .duplicateOccurrence, .removeOccurrence:
            return .presentation
        case .duplicateVariant, .removeObject:
            return .meaning
        case .explore, .add, .setAside, .reopen, .edit, .addSource,
             .assertClaim, .link, .comment, .reviewImpact, .groupInFrame,
             .buildExperiment, .reviewExperiment, .reviewHistory,
             .compareDirections, .composeSynthesis:
            return .meaning
        }
    }

    /// The question the two removals both have to answer, in the words of the one
    /// being considered. The specification requires the difference to be written
    /// out rather than left to the person to infer from a destructive button.
    public static func confirmation(for kind: Kind) -> (question: String, keeps: Kind)? {
        switch kind {
        case .removeOccurrence:
            return (L10n.actionKeepOccurrence, .removeOccurrence)
        case .removeObject:
            return (L10n.actionLoseIdea, .removeObject)
        default:
            return nil
        }
    }

    public func contains(_ kind: Kind) -> Bool {
        primary.contains(kind) || secondary.contains(kind)
    }

    /// Nothing at all is on offer. Used by the reading tour, where CAN-10 keeps
    /// exit, source and navigation and none of them live in this bar.
    public var isEmpty: Bool { primary.isEmpty && secondary.isEmpty }

    /// The set for an object the model can act on.
    ///
    /// A set-aside direction offers exactly one thing, because there is only one
    /// thing to do with it. Everything else is the ordinary case.
    public static func forObject(
        id: ObjectID,
        kind: ContentObject.Kind,
        canReopen: Bool,
        canAttachSource: Bool,
        canAssertClaim: Bool,
        canReviewImpact: Bool = false,
        canGroupInFrame: Bool = false,
        canCompareDirections: Bool = false,
        canComposeSynthesis: Bool = false,
        canBuildExperiment: Bool = true,
        canReviewExperiment: Bool = false,
        canReviewHistory: Bool = false
    ) -> ContextualActionSet {
        if canReopen {
            return ContextualActionSet(primary: [.reopen], secondary: [], isDefault: .reopen)
        }

        // Primary: the three the specification names for an ordinary idea.
        var secondary: [Kind] = [.edit]
        if canAttachSource { secondary.append(.addSource) }
        if canAssertClaim { secondary.append(.assertClaim) }
        // Offered only when the document says there is something to look at: a
        // citation that moved, or a mark nobody has looked at yet. A control that
        // opens an empty answer every time is a control that trains people to stop
        // opening it.
        if canReviewImpact { secondary.append(.reviewImpact) }
        // Offered only with something selected, because the frame's members are the
        // current selection. A frame around nothing is not a mistake to allow.
        if canGroupInFrame { secondary.append(.groupInFrame) }
        // Only with two directions selected. A comparison of one thing is a note,
        // and the action is not offered rather than offered and refused.
        if canCompareDirections { secondary.append(.compareDirections) }
        // Offered whenever there is something at all to read. A synthesis composes
        // from the selection or from the whole document, so the only condition for
        // it to be a dead button is an empty document, and a document with nothing
        // in it has no card to open either.
        if canComposeSynthesis { secondary.append(.composeSynthesis) }
        // An experiment is built on a reasoning, and any object can carry one.
        // Offered with the claim: both are the person committing to something
        // they will be held to later.
        if canBuildExperiment { secondary.append(.buildExperiment) }
        // Reading comes before building: offered only when an experiment exists,
        // for the same reason the impact review is. An action that opens an empty
        // answer trains people to stop opening actions.
        if canReviewExperiment { secondary.append(.reviewExperiment) }
        // The history is offered only when something happened: a timeline with
        // one row that says "created" is an answer to a question nobody asked.
        if canReviewHistory { secondary.append(.reviewHistory) }
        // Not implemented yet, so not offered. A disabled button is worse than an
        // absent one, and the specification forbids a decorative action.
        //
        // if linked { secondary.append(.link) }
        // if discussable { secondary.append(.comment) }

        // CAN-05: "The difference between occurrence and variant is written in the
        // menu." So they are two entries and never one "Duplicate": their labels
        // say what happens to the idea, not what happens to the button. The two
        // removals are the same pair, and the destructive one is last.
        secondary.append(.duplicateOccurrence)
        secondary.append(.duplicateVariant)
        secondary.append(.removeOccurrence)
        secondary.append(.removeObject)

        return ContextualActionSet(
            primary: [.explore, .add, .setAside],
            secondary: secondary,
            isDefault: .explore
        )
    }
}
