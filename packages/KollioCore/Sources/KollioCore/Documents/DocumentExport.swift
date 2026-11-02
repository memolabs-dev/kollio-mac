import Foundation

public enum DocumentExportScope: Hashable, Sendable {
    case document
    case objects(Set<ObjectID>)
}

/// One line of the exported scope, before it is given a physical form.
///
/// Markdown and PNG are two renderings of the same blocks, which is what makes
/// "the export matches the preview" checkable rather than aspirational: there is
/// only one description of the scope, and neither format can invent another.
public struct DocumentExportBlock: Hashable, Sendable {
    public enum Role: Hashable, Sendable {
        case title
        case heading
        case meta
        case bullet
        case spacer
    }

    public var role: Role
    public var text: String

    public init(role: Role, text: String = "") {
        self.role = role
        self.text = text
    }

    /// Markdown prefix for this line, empty for a spacer.
    var markdownPrefix: String {
        switch role {
        case .title: return "# "
        case .heading: return "## "
        case .meta, .bullet: return "- "
        case .spacer: return ""
        }
    }

    public var markdownLine: String {
        role == .spacer ? "" : markdownPrefix + text
    }
}

/// Immutable export material. Preview and final write consume these same bytes,
/// so changing the selection after preview cannot silently change the export.
public struct DocumentExportSnapshot: Hashable, Sendable {
    public var documentID: String
    public var revision: Int
    public var objectIDs: [ObjectID]
    public var blocks: [DocumentExportBlock]
    public var markdown: Data

    public init(
        documentID: String,
        revision: Int,
        objectIDs: [ObjectID],
        blocks: [DocumentExportBlock],
        markdown: Data
    ) {
        self.documentID = documentID
        self.revision = revision
        self.objectIDs = objectIDs
        self.blocks = blocks
        self.markdown = markdown
    }

    /// The plain text a person can read, whatever the physical format is.
    public var readableText: [String] { blocks.map(\.text) }
}

public enum DocumentExporter {
    /// A portable document containing exactly the frozen export scope and the
    /// records that remain valid inside it.
    public static func portableDocument(
        from document: KollioDocument,
        scope: DocumentExportScope
    ) -> KollioDocument {
        guard case .objects(let requested) = scope else { return document }
        let included = requested.filter { document.content[$0] != nil }
        var export = document
        export.content = document.content.filter { included.contains($0.key) }
        export.relationships = document.relationships.filter {
            included.contains($0.value.from) && included.contains($0.value.to)
        }
        export.decisions = document.decisions.filter {
            included.contains($0.value.targetObjectID)
        }
        export.products = document.products.filter { included.contains($0.key) }
        let contributionIDs = Set(export.content.values.compactMap(\.contributionID))
            .union(export.products.values.flatMap(\.memberContributionIDs))
        export.contributions = document.contributions.filter { contributionIDs.contains($0.key) }

        export.presentation.instances = document.presentation.instances.filter {
            included.contains($0.objectID)
        }
        let instanceIDs = Set(export.presentation.instances.map(\.id))
        export.presentation.frames = document.presentation.frames.compactMap { frame in
            var scoped = frame
            scoped.memberInstanceIDs = frame.memberInstanceIDs.filter(instanceIDs.contains)
            return scoped.memberInstanceIDs.isEmpty ? nil : scoped
        }

        let citations = document.sources.citations.values.filter { included.contains($0.claimID) }
        let sourceIDs = Set(citations.map(\.sourceID))
        export.sources = SourceLedger(
            sources: document.sources.sources.values.filter { sourceIDs.contains($0.id) },
            citations: Array(citations)
        )
        export.claims = ClaimLedger(claims: document.claims.allClaims().filter {
            $0.scope.objectIDs.isSubset(of: included)
        })
        export.clarifications = ClarificationLedger(clarifications: document.clarifications.all().filter {
            included.contains($0.objectID)
        })
        export.comparisons = ComparisonLedger(comparisons: document.comparisons.all().filter {
            Set($0.directionIDs).isSubset(of: included)
        })
        export.summaries = SummaryLedger(summaries: document.summaries.all().filter {
            Set($0.readSet.objectIDs).isSubset(of: included)
        })
        export.experiments = ExperimentLedger(experiments: document.experiments.experiments.filter {
            let experiment = $0.value
            let resultSources = experiment.results.compactMap(\.sourceObjectID)
            return included.contains(experiment.targetObjectID)
                && Set(experiment.expectedEvidence).isSubset(of: included)
                && Set(resultSources).isSubset(of: included)
        })
        // A scoped file is a document snapshot, not a misleading partial audit
        // trail whose entries may describe excluded objects.
        export.history = HistoryLedger()
        return export
    }

    public static func snapshot(
        of document: KollioDocument,
        scope: DocumentExportScope
    ) -> DocumentExportSnapshot {
        let blocks = blocks(of: document, scope: scope)
        let markdown = Data(blocks.map(\.markdownLine).joined(separator: "\n").utf8)
        return DocumentExportSnapshot(
            documentID: document.documentId,
            revision: document.revision,
            objectIDs: includedObjectIDs(of: document, scope: scope),
            blocks: blocks,
            markdown: markdown
        )
    }

    /// The frozen scope, described once. Every format is a rendering of this.
    public static func blocks(
        of document: KollioDocument,
        scope: DocumentExportScope
    ) -> [DocumentExportBlock] {
        let ids = includedObjectIDs(of: document, scope: scope)
        let included = Set(ids)

        var blocks: [DocumentExportBlock] = [
            DocumentExportBlock(role: .title, text: document.title),
            DocumentExportBlock(role: .spacer)
        ]
        for id in ids {
            guard let object = document.content[id] else { continue }
            let state = object.isSetAside ? "set aside" : "active"
            blocks.append(DocumentExportBlock(role: .heading, text: object.text.text))
            blocks.append(DocumentExportBlock(role: .spacer))
            blocks.append(DocumentExportBlock(role: .meta, text: "Status: \(state)"))
            blocks.append(DocumentExportBlock(role: .meta, text: "Kind: \(object.kind.rawValue)"))
            blocks.append(DocumentExportBlock(role: .spacer))
        }

        let decisions = document.decisions.values
            .filter { included.contains($0.targetObjectID) }
            .sorted { $0.id.rawValue < $1.id.rawValue }
        if decisions.isEmpty == false {
            blocks.append(DocumentExportBlock(role: .heading, text: "Decisions and discussions"))
            blocks.append(DocumentExportBlock(role: .spacer))
            for decision in decisions {
                let rationale = decision.rationale?.text ?? "—"
                blocks.append(DocumentExportBlock(role: .bullet, text: "\(decision.kind.rawValue): \(rationale)"))
            }
            blocks.append(DocumentExportBlock(role: .spacer))
        }

        let citations = document.sources.citations.values
            .filter { included.contains($0.claimID) }
            .sorted { $0.id.rawValue < $1.id.rawValue }
        if citations.isEmpty == false {
            blocks.append(DocumentExportBlock(role: .heading, text: "Sources"))
            blocks.append(DocumentExportBlock(role: .spacer))
            for citation in citations {
                let title = document.sources.sources[citation.sourceID]?.title ?? citation.sourceID.rawValue
                blocks.append(DocumentExportBlock(role: .bullet, text: "\(title): \(citation.quote)"))
            }
            blocks.append(DocumentExportBlock(role: .spacer))
        }
        return blocks
    }

    static func includedObjectIDs(
        of document: KollioDocument,
        scope: DocumentExportScope
    ) -> [ObjectID] {
        switch scope {
        case .document:
            return document.objects.map(\.id)
        case .objects(let requested):
            return requested.filter { document.content[$0] != nil }
                .sorted { $0.rawValue < $1.rawValue }
        }
    }
}

/// What the archive should do with one source of the exported scope.
///
/// A link has no bytes to copy, and a file that has moved is a warning rather
/// than a reason to fail the whole export: the person keeps the rest of what they
/// asked for, and the manifest says plainly what is absent.
public enum AssetArchiveOutcome: Hashable, Sendable {
    case copyable
    case linkOnly
    case missing
}

public struct AssetArchiveEntry: Hashable, Sendable, Identifiable {
    public var id: SourceID { sourceID }
    public var sourceID: SourceID
    public var title: String
    public var locator: String
    public var kind: SourceReference.Kind
    public var outcome: AssetArchiveOutcome

    public init(
        sourceID: SourceID,
        title: String,
        locator: String,
        kind: SourceReference.Kind,
        outcome: AssetArchiveOutcome
    ) {
        self.sourceID = sourceID
        self.title = title
        self.locator = locator
        self.kind = kind
        self.outcome = outcome
    }
}

extension DocumentExporter {
    /// The assets of the exported scope, and what can honestly be done with them.
    ///
    /// Only sources a claim in the scope actually cites are considered: an
    /// archive is meant to make the evidence travel with the content, not to sweep
    /// up every file the document ever mentioned. `existingPaths` is supplied by
    /// the caller because whether a file is still there is a fact about the
    /// machine, not about the document.
    public static func assetPlan(
        for document: KollioDocument,
        scope: DocumentExportScope,
        existingPaths: Set<String>
    ) -> [AssetArchiveEntry] {
        let included = Set(includedObjectIDs(of: document, scope: scope))
        let citations = document.sources.citations.values.filter { included.contains($0.claimID) }
        let citedSourceIDs = Set(citations.map(\.sourceID))
        return citedSourceIDs
            .compactMap { document.sources.sources[$0] }
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .map { source in
                let outcome: AssetArchiveOutcome
                if source.kind == .link {
                    outcome = .linkOnly
                } else if source.locator.isEmpty == false, existingPaths.contains(source.locator) {
                    outcome = .copyable
                } else {
                    outcome = .missing
                }
                return AssetArchiveEntry(
                    sourceID: source.id,
                    title: source.title,
                    locator: source.locator,
                    kind: source.kind,
                    outcome: outcome
                )
            }
    }
}
