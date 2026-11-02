import Foundation

/// A textual search over one document.
///
/// CAN-09 asks for search, and then asks for four things that are easy to skip.
/// Each of them is a property of this type rather than of the interface that
/// calls it:
///
/// - **A reason somebody wrote is findable.** A direction that was set aside is
///   remembered for its reason, not for its text, and a search that only reads
///   bodies cannot find "no budget" if nobody typed it into a body. Decisions are
///   searched.
/// - **Three states, not one.** A result says whether it is on the canvas, set
///   aside, or a piece of history whose decision no longer stands. Presenting a
///   superseded reason as a current one is worse than not finding it.
/// - **Nothing is searched that the person may not read.** A shared document is
///   searched inside the caller's permitted set, and what fell outside is
///   reported rather than passed over in silence. Rights are applied before the
///   search, never after it.
/// - **An unloaded source is not pretended to have been searched.** A source with
///   no extracted text is named in `notSearched`. A result set that looks complete
///   while whole documents were never read is a lie with a count on it.
///
/// A search is a pure function of the document. It asks no model, writes nothing,
/// and the same query on the same document always gives the same answer, in the
/// same order. That is what makes "returning alters no status" checkable rather
/// than merely intended.
public struct DocumentSearch: Sendable {
    public init() {}

    /// Where a result was found, which is also what it is.
    ///
    /// The state is a property of *the match*, not only of the object. An object
    /// can be on the canvas and still be found through the reason it was once set
    /// aside for, and that reason is history by the time the person is reading it.
    public enum State: String, Hashable, Sendable, CaseIterable {
        /// On the canvas, with no decision governing it.
        case visible
        /// Set aside, and the decision that did it still stands.
        case setAside
        /// The text was found through a decision that is no longer current.
        case archived
    }

    /// Which part of the entry carried the words.
    public enum Field: Hashable, Sendable, CaseIterable {
        case title
        case body
        case reason

        /// The order a person reads results in. A title match is the thing they
        /// were looking for; a body match is a mention; a reason is a piece of
        /// history that happens to contain the words.
        var rank: Int {
            switch self {
            case .title: return 0
            case .reason: return 1
            case .body: return 2
            }
        }
    }

    public struct Result: Hashable, Sendable, Identifiable {
        public var objectID: ObjectID
        public var state: State
        public var field: Field
        /// The text that matched, shortened. Never the whole object: a result list
        /// is not a place to read somebody's document.
        public var excerpt: String
        /// The decision that explains a set-aside result, and the one a superseded
        /// result came from. Present whenever there is one, so a result can say
        /// why it is in the state it is in.
        public var decisionID: DecisionID?

        public var id: String { objectID.rawValue }
    }

    /// Something that exists and was not searched. Named, so the interface can say
    /// the result set is narrower than the document.
    public enum NotSearched: Hashable, Sendable, Identifiable {
        /// Outside the set the caller may read. Filtered before the search, not
        /// after it.
        case outsideScope(ObjectID)
        /// The content of this many sources was not searched.
        ///
        /// A count and not a list, because it is a property of the product rather
        /// than of one source: Kollio does not read inside a file to look for
        /// words, and a result set that appeared to cover a person's evidence
        /// without having read it would be the exact lie CAN-09 forbids.
        case sourceContent(count: Int)

        public var id: String {
            switch self {
            case .outsideScope(let id): return "scope:\(id.rawValue)"
            case .sourceContent(let count): return "sources:\(count)"
            }
        }

        public var count: Int {
            switch self {
            case .outsideScope: return 1
            case .sourceContent(let count): return count
            }
        }
    }

    public struct Outcome: Hashable, Sendable {
        public var query: String
        public var results: [Result]
        public var notSearched: [NotSearched]

        public init(query: String, results: [Result] = [], notSearched: [NotSearched] = []) {
            self.query = query
            self.results = results
            self.notSearched = notSearched
        }

        /// Whether the result set is narrower than the document it came from.
        ///
        /// A person deciding whether to trust a result list needs to know that
        /// something was not in it, and "no results" and "nothing was searched"
        /// are different answers.
        public var isPartial: Bool { notSearched.isEmpty == false }
    }

    /// How much of a matched text a result carries.
    public static let excerptLimit = 90

    /// Searches titles, bodies and reasons.
    ///
    /// - Parameters:
    ///   - permitted: the objects the caller may read. `nil` means the whole
    ///     document, which is the local case; a shared document passes the set, and
    ///     whatever is outside it is reported rather than searched.
    ///   - languageCode: used only to resolve which variant of an authored text is
    ///     read and excerpted. The search does not machine-translate anything.
    public func search(
        _ text: String,
        in document: KollioDocument,
        permitted: Set<ObjectID>? = nil,
        languageCode: String = "fr"
    ) -> Outcome {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // An empty query is not a search that found nothing; it is not a search.
        // The interface keeps what was typed, so nothing is lost by saying so.
        guard query.isEmpty == false else { return Outcome(query: text) }

        var results: [Result] = []
        var notSearched: [NotSearched] = []
        // One entry per decision, not per object. A reason belongs to a branch,
        // and a list that repeated the same sentence once per member of that
        // branch would be a list about the search rather than about the document.
        // It was, and a capture of the card is what showed it: two identical rows
        // with identical labels and no way to tell them apart.
        var reasonsTold: Set<DecisionID> = []

        for object in document.objects {
            if let permitted, permitted.contains(object.id) == false {
                notSearched.append(.outsideScope(object.id))
                continue
            }
            guard let result = match(
                object: object, query: query, in: document,
                languageCode: languageCode, reasonsTold: &reasonsTold
            ) else { continue }
            results.append(result)
        }

        // A source's own content is not searched, and the result set says so
        // rather than appearing to have covered a person's evidence.
        let sourceCount = document.sources.sources.count
        if sourceCount > 0 {
            notSearched.append(.sourceContent(count: sourceCount))
        }

        return Outcome(
            query: text,
            results: sorted(results),
            notSearched: notSearched.sorted { $0.id < $1.id }
        )
    }

    // MARK: - Matching

    /// The first field that matches, in the order a person reads them.
    ///
    /// One result per object, not one per field: a list where the same object
    /// appears three times is a list about the search rather than about the
    /// document.
    private func match(
        object: ContentObject,
        query: String,
        in document: KollioDocument,
        languageCode: String,
        reasonsTold: inout Set<DecisionID>
    ) -> Result? {
        let title = object.text.resolve(languageCode: languageCode)
        if contains(title, query) {
            return Result(
                objectID: object.id, state: state(of: object), field: .title,
                excerpt: Self.excerpt(title, around: query), decisionID: governingDecision(of: object, in: document)?.id
            )
        }
        if let body = object.detail?.resolve(languageCode: languageCode), contains(body, query) {
            return Result(
                objectID: object.id, state: state(of: object), field: .body,
                excerpt: Self.excerpt(body, around: query), decisionID: governingDecision(of: object, in: document)?.id
            )
        }
        // The reason last, because a reason is history: the words are there, and
        // whether they are current depends on the decision that holds them.
        //
        // Every decision that ever concerned this object is considered, not only
        // the standing one, because a reopened direction keeps the reason it was
        // set aside for. Somebody looking for why a decision was taken is looking
        // for the decision that took it, and the one that undid it is not it.
        for decision in decisionsConcerning(object.id, in: document) {
            guard let reason = decision.rationale?.resolve(languageCode: languageCode),
                  contains(reason, query) else { continue }
            guard reasonsTold.insert(decision.id).inserted else { continue }
            return Result(
                // The root of the decided direction, not whichever member of the
                // branch happened to be reached first. It is the object a person
                // wants to see, and the one whose context the reason is about.
                objectID: decision.targetObjectID,
                state: decision.status == .active ? .setAside : .archived,
                field: .reason,
                excerpt: Self.excerpt(reason, around: query),
                decisionID: decision.id
            )
        }
        return nil
    }

    /// Every decision that concerned an object, newest first.
    ///
    /// Superseded ones included, and the order is by date rather than by
    /// identifier: the person who reopened something in March wants the reason
    /// from January, and a list ordered by id would not say which is which.
    func decisionsConcerning(_ objectID: ObjectID, in document: KollioDocument) -> [Decision] {
        document.decisions.values
            .filter { $0.targetObjectID == objectID || $0.branchObjectIDs.contains(objectID) }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
                return lhs.id.rawValue > rhs.id.rawValue
            }
    }

    /// The decision that currently explains this object, if one does.
    ///
    /// Only the standing one. A superseded decision is history and is reached
    /// through the reason search, where it is labelled as such rather than being
    /// presented as the reason that applies today.
    private func governingDecision(of object: ContentObject, in document: KollioDocument) -> Decision? {
        decisionsConcerning(object.id, in: document).first { $0.status == .active }
    }

    private func state(of object: ContentObject) -> State {
        object.isSetAside ? .setAside : .visible
    }

    /// Case- and accent-insensitive, because a French person typing "reduction"
    /// is looking for "réduction" and a search that misses it looks broken.
    ///
    /// The accent is not dropped from what is displayed: the excerpt is the
    /// person's own text, unchanged.
    func contains(_ haystack: String, _ needle: String) -> Bool {
        guard haystack.isEmpty == false else { return false }
        return haystack.range(
            of: needle,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) != nil
    }

    /// The words around the match, not the first words of a long object.
    ///
    /// A result list that shows the top of a paragraph is a result list that
    /// sends the person to the wrong place.
    static func excerpt(_ text: String, around query: String? = nil, limit: Int = excerptLimit) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        guard let query,
              let range = trimmed.range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive]
              ) else {
            return String(trimmed.prefix(limit)) + "…"
        }
        let start = trimmed.index(range.lowerBound, offsetBy: -24, limitedBy: trimmed.startIndex)
            ?? trimmed.startIndex
        let prefix = start > trimmed.startIndex ? "…" : ""
        let slice = trimmed[start...].prefix(limit)
        return prefix + slice + (trimmed.index(start, offsetBy: slice.count) < trimmed.endIndex ? "…" : "")
    }

    private func sorted(_ results: [Result]) -> [Result] {
        results.sorted { lhs, rhs in
            if lhs.field.rank != rhs.field.rank { return lhs.field.rank < rhs.field.rank }
            return lhs.objectID.rawValue < rhs.objectID.rawValue
        }
    }
}
