import Foundation

/// The part of the document an answer was actually allowed to see.
///
/// AI-12 asks for three things, and this type is the record of all three: a limit
/// does not lose text, a known constraint does not disappear silently, and the
/// output states its scope. The first is enforced by the source that builds the
/// payload, the second is refused rather than resolved, and the third is what this
/// value is for.
///
/// It is a set of facts and never a sentence. The interface renders it, so the same
/// answer says the same thing in French and English, and a record written in one
/// language is not mistranslated in the other.
public struct ProposalContextScope: Codable, Hashable, Sendable {
    /// The objects whose text was in the payload, in the order they were sent.
    ///
    /// This is the answer to "what did this read", taken from what was built rather
    /// than from what was available. A list read off the request would claim to
    /// have read material the model never saw.
    public var readObjectIDs: [ObjectID]
    /// The objects that did not fit, and were not required.
    ///
    /// Optional material only. A required object that does not fit is refused
    /// before generation rather than recorded here, so this list is never a place
    /// where a constraint goes to hide.
    public var omittedObjectIDs: [ObjectID]
    /// The size of the payload that was actually built.
    public var measuredCharacters: Int
    /// The room it had to fit into.
    public var budgetCharacters: Int
    /// Whether the count is characters rather than tokens.
    ///
    /// Always true today: the app cannot know the model's tokenizer, and a number
    /// that looks precise while being a guess is worse than an honest unit. It is
    /// carried as a value so a source that can count tokens does not have to lie
    /// about the unit it used.
    public var countsTokens: Bool

    public init(
        readObjectIDs: [ObjectID],
        omittedObjectIDs: [ObjectID] = [],
        measuredCharacters: Int,
        budgetCharacters: Int,
        countsTokens: Bool = false
    ) {
        self.readObjectIDs = readObjectIDs
        self.omittedObjectIDs = omittedObjectIDs
        self.measuredCharacters = measuredCharacters
        self.budgetCharacters = budgetCharacters
        self.countsTokens = countsTokens
    }

    /// Whether the answer saw everything that was available.
    ///
    /// False is not a failure and is not hidden: it is the scope of the answer, and
    /// an answer about less than the whole document is only useful if the person
    /// knows it is.
    public var isComplete: Bool { omittedObjectIDs.isEmpty }

    /// Whether anything was left out. Read by the interface to decide whether to
    /// say so at all, so a complete answer stays quiet.
    public var isNarrowed: Bool { isComplete == false }

    /// Builds the record from a projection, so the number a person sees is the
    /// number that was measured rather than a recount done at display time.
    public init(_ projection: ContextProjection) {
        self.init(
            readObjectIDs: projection.included.compactMap { item in
                if case .object(let id) = item { return id }
                return nil
            },
            omittedObjectIDs: projection.omissions.map(\.item).compactMap { item in
                if case .object(let id) = item { return id }
                return nil
            },
            measuredCharacters: projection.measuredCharacters,
            budgetCharacters: projection.budgetCharacters
        )
    }
}
