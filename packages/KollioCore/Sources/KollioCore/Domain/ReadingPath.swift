import Foundation

/// An ordered list of things to read, and what is left of it.
///
/// CAN-10: "Follow a chosen path of points, open sources and decisions, exit to
/// the previous camera. A reader cannot trigger a modification by accident.
/// Presentation mode hides editing commands but keeps exit, source and
/// navigation. Deleted points are skipped with an indication, never remapped to
/// another object."
///
/// Three of those five are properties of this type rather than of the view that
/// shows it:
///
/// - **The order is the path.** Points are visited in the order they were chosen,
///   and a path built from the same document is the same path twice, so a tour is
///   repeatable and a test can compare it.
/// - **A point that no longer resolves is skipped, and it is named.** It is never
///   quietly replaced by whatever now sits at that index, because a reading tour
///   that silently shows something else is worse than one that admits a gap.
/// - **A source and a decision are points too.** A document is not only its
///   objects, and a tour that cannot open the evidence and the reasoning is not a
///   presentation of the document.
///
/// Nothing here is stored in the document. A path is a reading somebody chose, not
/// a fact about the work, so it lives in the view and disappears with it.
public struct ReadingPath: Hashable, Sendable {
    /// One stop on the path.
    public enum Point: Hashable, Sendable, Identifiable {
        case object(ObjectID)
        case source(SourceID)
        case decision(DecisionID)

        public var id: String {
            switch self {
            case .object(let id): return "object:\(id.rawValue)"
            case .source(let id): return "source:\(id.rawValue)"
            case .decision(let id): return "decision:\(id.rawValue)"
            }
        }

        public enum Kind: String, Hashable, Sendable, CaseIterable {
            case object
            case source
            case decision
        }

        public var kind: Kind {
            switch self {
            case .object: return .object
            case .source: return .source
            case .decision: return .decision
            }
        }
    }

    public var points: [Point]

    public init(points: [Point]) {
        self.points = points
    }

    public init(objects: [ObjectID]) {
        self.points = objects.map { .object($0) }
    }

    public var isEmpty: Bool { points.isEmpty }

    public func contains(_ point: Point) -> Bool { points.contains(point) }

    // MARK: Building

    /// A tour of the whole document, in a reading order rather than a sorted one.
    ///
    /// It starts at the contexts, because that is where a person begins, and walks
    /// the relationships outwards, so a branch and what constrains it arrive
    /// together rather than in the order their identifiers happen to sort. What is
    /// left over follows, then the evidence, then the reasoning.
    ///
    /// Deterministic in every tie: by identifier, and by date for decisions. A tour
    /// that came out differently twice would be a tour nobody could describe.
    public static func automatic(in document: KollioDocument) -> ReadingPath {
        var ordered: [ObjectID] = []
        var seen: Set<ObjectID> = []

        let roots = document.objects
            .filter { $0.kind == .context }
            .sorted { $0.id.rawValue < $1.id.rawValue }
        var queue: [ObjectID] = []
        for root in roots {
            if seen.insert(root.id).inserted {
                ordered.append(root.id)
                queue.append(root.id)
            }
        }
        // Breadth first, and within a node by identifier, so two objects linked to
        // the same one are always visited in the same order.
        var index = 0
        while index < queue.count {
            let current = queue[index]
            index += 1
            let next = document.relationships(from: current)
                .map(\.to)
                .sorted { $0.rawValue < $1.rawValue }
            for id in next where seen.insert(id).inserted {
                ordered.append(id)
                queue.append(id)
            }
        }
        // Anything the walk did not reach: a set-aside branch is only reachable
        // through its root, and an orphan is reachable from nothing at all.
        for object in document.objects where seen.contains(object.id) == false {
            ordered.append(object.id)
        }

        let sources = document.sources.sources.values
            .map(\.id)
            .sorted { $0.rawValue < $1.rawValue }
        let decisions = document.decisions.values.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.rawValue < rhs.id.rawValue
        }

        return ReadingPath(points:
            ordered.map { .object($0) }
            + sources.map { .source($0) }
            + decisions.map { .decision($0.id) }
        )
    }

    // MARK: Resolving

    /// A stop that is ready to be shown.
    public struct Entry: Hashable, Sendable, Identifiable {
        public var point: Point
        /// What to call it, in the language being read. Never the content it points
        /// at: a title is a label, not a quotation of somebody's document.
        public var label: String
        /// The object the view should centre on, when there is one.
        ///
        /// A decision is shown at the direction it decided. A source is shown at
        /// something that cites it, and at nothing at all when nothing does, which
        /// is a fact about the document rather than a failure to find something.
        public var anchorObjectID: ObjectID?

        public var id: String { point.id }
        public var kind: Point.Kind { point.kind }
    }

    /// A point that is not there any more, and why the reader is not being shown
    /// something else in its place.
    public struct Skipped: Hashable, Sendable, Identifiable {
        public var point: Point
        /// The identifier, so the gap can be named. A gap nobody can identify is a
        /// gap nobody can fix.
        public var id: String { point.id }
    }

    public struct Resolution: Hashable, Sendable {
        public var entries: [Entry]
        public var skipped: [Skipped]
        /// The number of points the path named, including the ones that are gone.
        public var requested: Int

        public init(entries: [Entry] = [], skipped: [Skipped] = [], requested: Int = 0) {
            self.entries = entries
            self.skipped = skipped
            self.requested = requested
        }

        public var isEmpty: Bool { entries.isEmpty }
        /// Whether the tour is shorter than the path asked for.
        public var isPartial: Bool { skipped.isEmpty == false }
        public var count: Int { entries.count }
    }

    /// Resolves a path against the document as it is now.
    ///
    /// The order of the path is kept, gaps are kept as gaps, and nothing is
    /// substituted: a point whose object has been removed is skipped, and the entry
    /// after it is the entry that was after it.
    public func resolved(in document: KollioDocument, languageCode: String = "fr") -> Resolution {
        var entries: [Entry] = []
        var skipped: [Skipped] = []

        for point in points {
            if let entry = Self.entry(for: point, in: document, languageCode: languageCode) {
                entries.append(entry)
            } else {
                skipped.append(Skipped(point: point))
            }
        }
        return Resolution(entries: entries, skipped: skipped, requested: points.count)
    }

    /// Whether a point still resolves, without building its entry. Used when a tour
    /// is running and a deletion happens under it.
    public func containsLivePoint(_ point: Point, in document: KollioDocument) -> Bool {
        Self.entry(for: point, in: document, languageCode: "fr") != nil
    }

    private static func entry(
        for point: Point,
        in document: KollioDocument,
        languageCode: String
    ) -> Entry? {
        switch point {
        case .object(let id):
            guard let object = document.object(id) else { return nil }
            let text = object.text.resolve(languageCode: languageCode)
            return Entry(
                point: point,
                label: text.isEmpty ? id.rawValue : DocumentSearch.excerpt(text, limit: 60),
                anchorObjectID: id
            )
        case .decision(let id):
            guard let decision = document.decisions[id] else { return nil }
            // A decision is shown at the direction it decided, which is also what
            // makes it legible: the reasoning is on screen next to the thing it is
            // reasoning about.
            let rationaleText = decision.rationale?.resolve(languageCode: languageCode) ?? ""
            let label = rationaleText.isEmpty
                ? id.rawValue
                : DocumentSearch.excerpt(rationaleText, limit: 60)
            return Entry(
                point: point,
                label: label,
                anchorObjectID: document.object(decision.targetObjectID) != nil
                    ? decision.targetObjectID
                    : nil
            )
        case .source(let id):
            guard let source = document.sources.source(id) else { return nil }
            // Something that cites it is the best place to stand. A source nothing
            // cites has no place on the canvas, and the reader is told so by the
            // card rather than by the view moving to nowhere.
            let citing = document.sources.citations(of: id)
                .compactMap { $0.claimID }
                .sorted { $0.rawValue < $1.rawValue }
            return Entry(
                point: point,
                label: source.title.isEmpty ? id.rawValue : DocumentSearch.excerpt(source.title, limit: 60),
                anchorObjectID: citing.first
            )
        }
    }
}
