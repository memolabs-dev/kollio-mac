import Foundation

/// The versioned `.kollio` document.
///
/// Everything in this type is portable, renderer independent data. No SwiftUI
/// type, no CGPoint, no class name, no platform callback object is ever stored.
public struct KollioDocument: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var documentId: String
    /// Authored document name. It is never translated when the interface language changes.
    public var title: String
    /// Bumped on every accepted mutation, presentation included.
    public var revision: Int
    /// Bumped only when the meaning of the document changed.
    public var semanticRevision: Int
    public var createdAt: Date
    public var updatedAt: Date

    public var content: [ObjectID: ContentObject]
    public var relationships: [RelationshipID: Relationship]
    public var decisions: [DecisionID: Decision]
    public var contributions: [ActorID: ContributionRecord]
    public var products: [ObjectID: ProductComposition]
    public var presentation: Presentation
    /// Sources and the citations made from them. Part of the document rather than a
    /// side store, so a claim and what it was based on travel together in one file
    /// and are versioned by the same revision.
    public var sources: SourceLedger
    /// Claims with an explicit scope and a stance. Part of the document for the
    /// same reason sources are: a claim and the ground it applies to are one thing.
    public var claims: ClaimLedger
    /// Questions intelligence asked, and the state of their answers. Part of the
    /// document because an answer is a contribution: it has to survive a failure,
    /// a restart and a share, which is the whole of AI-04's first criterion.
    public var clarifications: ClarificationLedger
    /// The comparisons of directions, criterion by criterion. Part of the document
    /// for the same reason the ledgers above are: a comparison is a record of what
    /// was weighed against what, and it has to outlive the session that produced it.
    public var comparisons: ComparisonLedger
    /// The syntheses prepared for handing over. Part of the document because a
    /// synthesis is a deliverable: it has to survive a quit, a failure and a
    /// share, and because the read set it carries is the only record of what was
    /// consulted when the conclusions were drawn.
    public var summaries: SummaryLedger
    /// The validation experiments built on the reasoning. Part of the document
    /// because an experiment and the claim it will judge are one thing: they
    /// travel together, survive together, and a file without one still says
    /// truthfully that the document built no experiments yet.
    public var experiments: ExperimentLedger
    /// What a person did, in order. Append-only, and never authoritative: the
    /// document above is the truth and a file may arrive without one. It is here
    /// because the document cannot answer "what happened to this object?", and
    /// because a record that can be edited is not a record.
    public var history: HistoryLedger

    public init(
        schemaVersion: Int = KollioDocument.currentSchemaVersion,
        documentId: String = UUID().uuidString,
        title: String = "Kollio",
        revision: Int = 0,
        semanticRevision: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        content: [ObjectID: ContentObject] = [:],
        relationships: [RelationshipID: Relationship] = [:],
        decisions: [DecisionID: Decision] = [:],
        contributions: [ActorID: ContributionRecord] = [:],
        products: [ObjectID: ProductComposition] = [:],
        presentation: Presentation = Presentation(),
        sources: SourceLedger = SourceLedger(),
        claims: ClaimLedger = ClaimLedger(),
        clarifications: ClarificationLedger = ClarificationLedger(),
        comparisons: ComparisonLedger = ComparisonLedger(),
        summaries: SummaryLedger = SummaryLedger(),
        experiments: ExperimentLedger = ExperimentLedger(),
        history: HistoryLedger = HistoryLedger()
    ) {
        self.schemaVersion = schemaVersion
        self.documentId = documentId
        self.title = title
        self.revision = revision
        self.semanticRevision = semanticRevision
        self.createdAt = createdAt.kollioNormalized
        self.updatedAt = updatedAt.kollioNormalized
        self.content = content
        self.relationships = relationships
        self.decisions = decisions
        self.contributions = contributions
        self.products = products
        self.presentation = presentation
        self.sources = sources
        self.claims = claims
        self.clarifications = clarifications
        self.comparisons = comparisons
        self.summaries = summaries
        self.experiments = experiments
        self.history = history
    }

    /// 7 added the `history` ledger. 6 added `summaries`. 5 added the `comparisons` ledger. A file written before it decodes to a
    /// document with no comparisons, which is the truth about it.
    /// 6 adds `summaries`.
    /// 7 adds `history`.
    /// 8 adds `experiments`.
    public static let currentSchemaVersion = 9

    /// 2 added the `sources` ledger. A file written at version 1 has no `sources`
    /// key and decodes as a document with no sources, which is the truth about it.


    // MARK: - Codable

    /// Ids are encoded as JSON object keys rather than as an array of
    /// alternating values, so a `.kollio` file stays greppable and reviewable by
    /// a human, which is the whole point of the format.
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, documentId, title, revision, semanticRevision, createdAt, updatedAt
        case content, relationships, decisions, contributions, products
        case presentation, sources, claims, clarifications, comparisons, summaries
        case experiments, history
    }

    private struct IdKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ value: String) { self.stringValue = value }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        documentId = try container.decode(String.self, forKey: .documentId)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Kollio"
        revision = try container.decode(Int.self, forKey: .revision)
        semanticRevision = try container.decode(Int.self, forKey: .semanticRevision)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        content = try Self.decodeMap(ObjectID.self, from: container, forKey: .content, of: ContentObject.self)
        relationships = try Self.decodeMap(RelationshipID.self, from: container, forKey: .relationships, of: Relationship.self)
        decisions = try Self.decodeMap(DecisionID.self, from: container, forKey: .decisions, of: Decision.self)
        contributions = try Self.decodeMap(ActorID.self, from: container, forKey: .contributions, of: ContributionRecord.self)
        products = try Self.decodeMap(ObjectID.self, from: container, forKey: .products, of: ProductComposition.self)
        presentation = try container.decode(Presentation.self, forKey: .presentation)
        // Absent in a file written before sources existed, which is a document with
        // no sources rather than a corrupt one.
        sources = try container.decodeIfPresent(SourceLedger.self, forKey: .sources) ?? SourceLedger()
        claims = try container.decodeIfPresent(ClaimLedger.self, forKey: .claims) ?? ClaimLedger()
        clarifications = try container.decodeIfPresent(ClarificationLedger.self, forKey: .clarifications) ?? ClarificationLedger()
        comparisons = try container.decodeIfPresent(ComparisonLedger.self, forKey: .comparisons) ?? ComparisonLedger()
        // A file written before syntheses existed decodes to a document with none,
        // which is the truth about it rather than a file to repair.
        summaries = try container.decodeIfPresent(SummaryLedger.self, forKey: .summaries) ?? SummaryLedger()
        // A file written before experiments existed decodes to a document that
        // built none, which is the truth about it.
        experiments = try container.decodeIfPresent(ExperimentLedger.self, forKey: .experiments) ?? ExperimentLedger()
        // A file written before the ledger existed decodes to a document with no
        // history, which is the truth about it. It is not an error and it is not
        // back-filled: inventing a past nobody recorded would be worse than
        // admitting there is none.
        history = try container.decodeIfPresent(HistoryLedger.self, forKey: .history) ?? HistoryLedger()
    }

    private static func decodeMap<Key: KollioIdentifier, Value: Decodable>(
        _ type: Key.Type,
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys,
        of valueType: Value.Type
    ) throws -> [Key: Value] {
        let nested = try container.nestedContainer(keyedBy: IdKey.self, forKey: key)
        var result: [Key: Value] = [:]
        for idKey in nested.allKeys {
            let key = Key(idKey.stringValue)
            result[key] = try nested.decode(Value.self, forKey: idKey)
        }
        return result
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(documentId, forKey: .documentId)
        try container.encode(title, forKey: .title)
        try container.encode(revision, forKey: .revision)
        try container.encode(semanticRevision, forKey: .semanticRevision)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try Self.encodeMap(content, into: &container, forKey: .content)
        try Self.encodeMap(relationships, into: &container, forKey: .relationships)
        try Self.encodeMap(decisions, into: &container, forKey: .decisions)
        try Self.encodeMap(contributions, into: &container, forKey: .contributions)
        try Self.encodeMap(products, into: &container, forKey: .products)
        try container.encode(presentation, forKey: .presentation)
        try container.encode(sources, forKey: .sources)
        try container.encode(claims, forKey: .claims)
        try container.encode(experiments, forKey: .experiments)
        try container.encode(clarifications, forKey: .clarifications)
        try container.encode(comparisons, forKey: .comparisons)
        try container.encode(summaries, forKey: .summaries)
        try container.encode(history, forKey: .history)
    }

    private static func encodeMap<Key: KollioIdentifier, Value: Encodable>(
        _ map: [Key: Value],
        into container: inout KeyedEncodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws {
        var nested = container.nestedContainer(keyedBy: IdKey.self, forKey: key)
        for (id, value) in map {
            try nested.encode(value, forKey: IdKey(id.idString))
        }
    }

    // MARK: - Read helpers

    public var objects: [ContentObject] {
        content.values.sorted { $0.id.rawValue < $1.id.rawValue }
    }

    public var activeObjects: [ContentObject] {
        objects.filter { $0.lifecycle == .active }
    }

    public func object(_ id: ObjectID) -> ContentObject? { content[id] }
    public func relationship(_ id: RelationshipID) -> Relationship? { relationships[id] }

    public func relationships(from id: ObjectID) -> [Relationship] {
        relationships.values.filter { $0.from == id }.sorted { $0.id.rawValue < $1.id.rawValue }
    }

    public func relationships(to id: ObjectID) -> [Relationship] {
        relationships.values.filter { $0.to == id }.sorted { $0.id.rawValue < $1.id.rawValue }
    }

    public func incidents(of id: ObjectID) -> [Relationship] {
        relationships(from: id) + relationships(to: id)
    }

    /// Object ids reachable from `root` by following relationships, `root` included.
    /// Used to decide what a decision about a direction covers.
    public func descendants(of root: ObjectID) -> Set<ObjectID> {
        var visited: Set<ObjectID> = [root]
        var queue: [ObjectID] = [root]
        while let current = queue.popLast() {
            for rel in relationships.values where rel.from == current {
                guard !visited.contains(rel.to) else { continue }
                visited.insert(rel.to)
                queue.append(rel.to)
            }
        }
        return visited
    }

    /// Objects of a branch that are *only* reachable through `root`: closing the
    /// branch therefore hides them, while shared objects stay visible.
    public func exclusiveDescendants(of root: ObjectID) -> Set<ObjectID> {
        let reachable = descendants(of: root)
        var exclusive: Set<ObjectID> = [root]
        for id in reachable where id != root {
            let shared = relationships.values.contains { $0.to == id && !reachable.contains($0.from) }
            if !shared { exclusive.insert(id) }
        }
        return exclusive
    }

    public func activeDecisions(targeting id: ObjectID) -> [Decision] {
        decisions.values
            .filter { $0.status == .active && $0.targetObjectID == id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public func contribution(_ id: ActorID) -> ContributionRecord? { contributions[id] }

    /// Lightweight fingerprint of the semantics an AI request depended on. Used
    /// to reject a proposal computed against a document that has since changed.
    public func semanticFingerprint(for ids: Set<ObjectID>) -> String {
        var parts: [String] = []
        for id in ids.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let object = content[id] else { continue }
            parts.append("\(id.rawValue):\(object.kind.rawValue):\(object.lifecycle.rawValue):\(object.text.text.hashValue)")
        }
        return String(parts.joined(separator: "|").hashValue, radix: 16)
    }
}
