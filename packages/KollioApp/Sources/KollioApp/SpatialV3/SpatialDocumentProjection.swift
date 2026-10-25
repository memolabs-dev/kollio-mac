import Foundation
import KollioCore

/// Lossless *reference* to an existing .kollio v7 semantic document for
/// Spatial Ink. This is a read model, never a replacement file format.
/// Full kinds and relationship kinds remain unchanged, even when the V3
/// renderer cannot yet display their richer meanings.
struct SpatialDocumentProjection {
    struct Occurrence: Equatable {
        let id: String
        let position: Position
        let isHidden: Bool
    }
    struct Node: Identifiable, Equatable {
        let id: String
        let kind: String
        let label: String
        let detail: String?
        let isSetAside: Bool
        let occurrences: [Occurrence]
        var authoredPositions: [Position] { occurrences.map(\.position) }
    }
    struct Edge: Identifiable, Equatable {
        let id: String
        let source: String
        let target: String
        let kind: String
        let label: String?
    }
    let documentID: String
    let revision: Int
    let semanticRevision: Int
    let nodes: [Node]
    let edges: [Edge]

    init(document: KollioDocument, languageCode: String = "fr") {
        documentID = document.documentId
        revision = document.revision
        semanticRevision = document.semanticRevision
        let folded = Set(document.presentation.frames.filter(\.isFolded).flatMap(\.memberInstanceIDs))
        nodes = document.content.values.sorted { $0.id.rawValue < $1.id.rawValue }.map { object in
            Node(
                id: object.id.rawValue,
                kind: object.kind.rawValue,
                label: object.text.resolve(languageCode: languageCode),
                detail: object.detail?.resolve(languageCode: languageCode),
                isSetAside: object.isSetAside,
                occurrences: document.presentation.instances
                    .filter { $0.objectID == object.id }
                    .sorted { $0.id.rawValue < $1.id.rawValue }
                    .map { instance in
                        Occurrence(
                            id: instance.id.rawValue,
                            position: instance.position,
                            isHidden: instance.hidden || folded.contains(instance.id)
                        )
                    }
            )
        }
        edges = document.relationships.values.sorted { $0.id.rawValue < $1.id.rawValue }.map { relation in
            Edge(
                id: relation.id.rawValue,
                source: relation.from.rawValue,
                target: relation.to.rawValue,
                kind: relation.kind.rawValue,
                label: relation.label?.resolve(languageCode: languageCode)
            )
        }
    }
}
