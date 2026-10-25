import Foundation
import CoreGraphics
import KollioCore

/// Translates a lossless read projection of a real .kollio v7 document to
/// the existing native spatial renderer. No write, file IO, or model mutation.
/// The renderer's simplified visual kinds are never written back to .kollio.
struct SpatialDocumentScene {
    let documentID: String
    let revision: Int
    let semanticRevision: Int
    let semanticObjectCount: Int
    let nodes: [SpatialV3Node]
    let edges: [SpatialV3Edge]
    /// Only the view owns these visual identities. They never enter the file.
    let objectIDByVisualID: [String: String]
    let instanceIDByVisualID: [String: String]
    let visualIDsByObjectID: [String: [String]]

    func objectID(for visualID: String) -> String? { objectIDByVisualID[visualID] }
    func visualID(for objectID: String) -> String? { visualIDsByObjectID[objectID]?.first }
    func occurrenceCount(for objectID: String) -> Int { visualIDsByObjectID[objectID]?.count ?? 0 }

    private struct Renderable {
        let visualID: String
        let objectID: String
        let instanceID: String?
        let authored: CGPoint?
    }

    init(projection: SpatialDocumentProjection) {
        documentID = projection.documentID
        revision = projection.revision
        semanticRevision = projection.semanticRevision
        semanticObjectCount = projection.nodes.count

        let reservedIDs = Set(projection.nodes.map(\.id))
        var usedIDs: Set<String> = []
        var renderables: [Renderable] = []
        // Every visible occurrence gets a separate card. The first card keeps
        // the historical object ID for backwards compatibility; additional
        // cards get a stable presentation-only ID derived from the instance.
        // Objects without any authored occurrence still get a derived slot.
        // Explicitly hidden/folded occurrences must NOT reappear as fallbacks.
        for node in projection.nodes {
            let visible = node.occurrences.filter { !$0.isHidden }
            if node.occurrences.isEmpty {
                renderables.append(Renderable(
                    visualID: node.id, objectID: node.id, instanceID: nil, authored: nil
                ))
                usedIDs.insert(node.id)
            }
            for (index, occurrence) in visible.enumerated() {
                var candidate = index == 0 ? node.id : "\(node.id)::occurrence::\(occurrence.id)"
                let base = candidate
                var suffix = 2
                while usedIDs.contains(candidate) || (index > 0 && reservedIDs.contains(candidate)) {
                    candidate = "\(base)::\(suffix)"
                    suffix += 1
                }
                usedIDs.insert(candidate)
                renderables.append(Renderable(
                    visualID: candidate,
                    objectID: node.id,
                    instanceID: occurrence.id,
                    authored: CGPoint(x: occurrence.position.x, y: occurrence.position.y)
                ))
            }
        }
        objectIDByVisualID = Dictionary(uniqueKeysWithValues: renderables.map { ($0.visualID, $0.objectID) })
        instanceIDByVisualID = Dictionary(uniqueKeysWithValues: renderables.compactMap { item in
            item.instanceID.map { (item.visualID, $0) }
        })
        let groupedVisualIDs = Dictionary(grouping: renderables, by: \.objectID)
            .mapValues { $0.map(\.visualID) }
        visualIDsByObjectID = groupedVisualIDs

        // Authored instance positions remain untouched. Missing positions
        // receive deterministic view-only slots clear of every authored card.
        let columns = max(1, Int(ceil(sqrt(Double(renderables.count) * 1.5))))
        var occupied = renderables.compactMap(\.authored)
        var positioned: [String: CGPoint] = [:]
        for renderable in renderables {
            if let saved = renderable.authored {
                positioned[renderable.visualID] = saved
                continue
            }
            var slot = 0
            while true {
                let proposal = CGPoint(
                    x: CGFloat(slot % columns) * 270 + 150,
                    y: CGFloat(slot / columns) * 160 + 115
                )
                if occupied.allSatisfy({ abs($0.x - proposal.x) >= 250 || abs($0.y - proposal.y) >= 145 }) {
                    positioned[renderable.visualID] = proposal
                    occupied.append(proposal)
                    break
                }
                slot += 1
            }
        }

        let semantic = Dictionary(uniqueKeysWithValues: projection.nodes.map { ($0.id, $0) })
        nodes = renderables.compactMap { display in
            guard let original = semantic[display.objectID],
                  let position = positioned[display.visualID] else { return nil }
            let family: String
            switch original.kind {
            case "evidence", "contribution": family = "source"
            case "question": family = "question"
            default: family = "idea"
            }
            return SpatialV3Node(
                id: display.visualID,
                kind: family,
                label: original.label,
                eyebrow: original.kind.uppercased(),
                detail: original.detail ?? "",
                status: original.isSetAside ? "set-aside" : "active",
                depth: 2,
                x: Double(position.x) / 1000,
                y: Double(position.y) / 640
            )
        }

        // Relationships remain *semantic*: one displayed edge per real
        // relationship. Pick the nearest visible pair of occurrences, with
        // stable ID tie-breaks, rather than multiplying links by N × M.
        // This is purely visual, with no changes to authored relationships.
        edges = projection.edges.compactMap { relation in
            let sources = groupedVisualIDs[relation.source] ?? []
            let targets = groupedVisualIDs[relation.target] ?? []
            var pairs: [(source: String, target: String, distance: CGFloat)] = []
            for source in sources {
                for target in targets where source != target {
                    guard let a = positioned[source], let b = positioned[target] else { continue }
                    pairs.append((source, target, hypot(a.x - b.x, a.y - b.y)))
                }
            }
            guard let chosen = pairs.min(by: { a, b in
                if abs(a.distance - b.distance) > 0.001 { return a.distance < b.distance }
                if a.source != b.source { return a.source < b.source }
                return a.target < b.target
            }),
                let start = positioned[chosen.source],
                let end = positioned[chosen.target]
            else { return nil }
            let delta = CGPoint(x: end.x - start.x, y: end.y - start.y)
            let a = Self.border(from: start, toward: delta)
            let b = Self.border(from: end, toward: CGPoint(x: -delta.x, y: -delta.y))
            let obstacles = positioned
                .filter { $0.key != chosen.source && $0.key != chosen.target }
                .map { _, center in
                    CGRect(x: center.x - 115, y: center.y - 70, width: 230, height: 140)
                }
            let route = SpatialDocumentRouter.route(from: a, to: b, avoiding: obstacles)
            let style: String
            switch relation.kind {
            case "supports": style = "supports"
            case "contradicts": style = "questions"
            case "alternativeTo": style = "proposes"
            default: style = "relates"
            }
            return SpatialV3Edge(
                id: relation.id,
                source: chosen.source,
                target: chosen.target,
                type: style,
                label: relation.label ?? relation.kind,
                depth: 2,
                points: route.points,
                blocked: route.blocked,
                crossings: route.crossings
            )
        }
    }

    private static func border(from center: CGPoint, toward delta: CGPoint) -> CGPoint {
        let dx = abs(delta.x), dy = abs(delta.y)
        if dx < 0.001 && dy < 0.001 { return center }
        let factor = min(dx < 0.001 ? .infinity : 110 / dx,
                         dy < 0.001 ? .infinity : 52 / dy)
        return CGPoint(x: center.x + delta.x * factor, y: center.y + delta.y * factor)
    }
}


/// A deterministic, bounded presentation-only corridor router. It tests
/// unobstructed direct/L routes first, then scans lanes immediately outside
/// neighbouring card envelopes. If none is safe, it reports a *blocked*
/// fallback rather than claiming a line through a card was routed.
enum SpatialDocumentRouter {
    struct Result {
        let points: [CGPoint]
        let blocked: Bool
        let crossings: Int
    }

    private static let clearance: CGFloat = 12

    static func route(from start: CGPoint, to end: CGPoint, avoiding cards: [CGRect]) -> Result {
        let blockers = cards.map { $0.insetBy(dx: -clearance, dy: -clearance) }
        guard start.x.isFinite, start.y.isFinite, end.x.isFinite, end.y.isFinite,
              start != end else {
            return Result(points: [start, end], blocked: true, crossings: 0)
        }

        func clean(_ candidate: [CGPoint]) -> [CGPoint] {
            var path: [CGPoint] = []
            for point in candidate where path.last != point {
                path.append(point)
            }
            return path
        }
        func isClear(_ path: [CGPoint]) -> Bool {
            zip(path, path.dropFirst()).allSatisfy { from, to in
                blockers.allSatisfy { !segmentHits(from: from, to: to, rect: $0) }
            }
        }
        // Preserve the original native straight-line treatment where safe.
        let direct = [start, end]
        if isClear(direct) { return Result(points: direct, blocked: false, crossings: 0) }

        let horizontalFirst = clean([start, CGPoint(x: end.x, y: start.y), end])
        let verticalFirst = clean([start, CGPoint(x: start.x, y: end.y), end])
        var winner: [CGPoint]?
        var bestLength = CGFloat.infinity
        func consider(_ path: [CGPoint]) {
            guard isClear(path) else { return }
            let length = zip(path, path.dropFirst()).reduce(CGFloat.zero) { sum, pair in
                sum + hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
            } + CGFloat(max(0, path.count - 2)) * 12
            if length < bestLength {
                bestLength = length
                winner = path
            }
        }
        consider(horizontalFirst)
        consider(verticalFirst)

        // Candidate lanes are deterministic even if the dictionary iteration
        // ordering changes; routes with equal length keep their first winner.
        let ys = Array(Set(blockers.flatMap { [$0.minY - clearance, $0.maxY + clearance] })).sorted()
        let xs = Array(Set(blockers.flatMap { [$0.minX - clearance, $0.maxX + clearance] })).sorted()
        for y in ys {
            consider(clean([start, CGPoint(x: start.x, y: y), CGPoint(x: end.x, y: y), end]))
        }
        for x in xs {
            consider(clean([start, CGPoint(x: x, y: start.y), CGPoint(x: x, y: end.y), end]))
        }

        if let winner { return Result(points: winner, blocked: false, crossings: 0) }
        let collisions = blockers.filter { segmentHits(from: start, to: end, rect: $0) }.count
        return Result(points: direct, blocked: true, crossings: collisions)
    }

    /// Closed-rectangle intersection via Liang–Barsky clipping. A segment
    /// touching the clearance envelope is unsafe, including diagonal lines.
    static func segmentHits(from start: CGPoint, to end: CGPoint, rect: CGRect) -> Bool {
        guard !rect.isNull, !rect.isEmpty else { return false }
        let dx = end.x - start.x
        let dy = end.y - start.y
        var low: CGFloat = 0
        var high: CGFloat = 1
        for (p, q) in [
            (-dx, start.x - rect.minX),
            (dx, rect.maxX - start.x),
            (-dy, start.y - rect.minY),
            (dy, rect.maxY - start.y)
        ] {
            if abs(p) < 0.000001 {
                if q < 0 { return false }
            } else {
                let t = q / p
                if p < 0 { low = max(low, t) } else { high = min(high, t) }
                if low > high { return false }
            }
        }
        return true
    }
}
