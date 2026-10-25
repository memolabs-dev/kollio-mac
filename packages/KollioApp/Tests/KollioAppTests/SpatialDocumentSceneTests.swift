import Foundation
import Testing
import KollioCore
@testable import KollioApp

@Suite("Spatial Ink — real .kollio canvas scene")
struct SpatialDocumentSceneTests {
    @Test("Sarah renders all semantic objects and links without touching the document")
    func sarah() {
        let document = SarahFixture.document()
        let before = document
        let semantic = SpatialDocumentProjection(document: document)
        let rendered = SpatialDocumentScene(projection: semantic)
        #expect(rendered.documentID == document.documentId)
        #expect(rendered.revision == document.revision)
        #expect(rendered.semanticRevision == document.semanticRevision)
        #expect(rendered.nodes.count == document.content.count)
        #expect(rendered.edges.count == document.relationships.count)
        #expect(Set(rendered.nodes.map(\.id)) == Set(document.content.keys.map(\.rawValue)))
        #expect(Set(rendered.edges.map(\.id)) == Set(document.relationships.keys.map(\.rawValue)))
        #expect(document == before)
        for edge in rendered.edges {
            #expect(edge.points.count >= 2)
            #expect(edge.points.allSatisfy { $0.x.isFinite && $0.y.isFinite })
        }
        for instance in document.presentation.instances {
            let visual = rendered.nodes.first { $0.id == instance.objectID.rawValue }
            #expect(visual != nil)
            if let visual {
                #expect(abs(visual.x * 1000 - instance.position.x) < 0.01)
                #expect(abs(visual.y * 640 - instance.position.y) < 0.01)
            }
        }
    }
    @Test("A real .kollio file can be reopened and displayed without writing it back")
    @MainActor
    func onDiskReopen() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kollio-spatial-c2-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DocumentFileStore(directory: directory)
        let document = SarahFixture.document()
        let url = store.defaultDocumentURL
        try store.save(document, to: url)
        let originalBytes = try Data(contentsOf: url)

        // The same path taken by a normal app launch, but using an isolated
        // temporary document directory instead of the user's real files.
        let reopened = KollioModel.deterministicModel(fileStore: store)
        let view = SpatialDocumentScene(projection: SpatialDocumentProjection(document: reopened.document))
        #expect(reopened.document == document)
        #expect(view.nodes.count == document.content.count)
        #expect(view.edges.count == document.relationships.count)
        #expect(try Data(contentsOf: url) == originalBytes)
    }

    @Test("The same active KollioModel projects newly loaded and cleared documents")
    @MainActor
    func followsActiveModel() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kollio-c2-live-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = KollioModel.deterministicModel(
            document: KollioDocument(),
            fileStore: DocumentFileStore(directory: directory)
        )
        #expect(SpatialDocumentScene(projection: SpatialDocumentProjection(document: model.document)).nodes.isEmpty)
        model.loadDemo()
        let sarah = SpatialDocumentScene(projection: SpatialDocumentProjection(document: model.document))
        #expect(sarah.nodes.count == model.document.content.count)
        #expect(sarah.edges.count == model.document.relationships.count)
        #expect(!sarah.nodes.isEmpty)
        model.newDocument()
        let cleared = SpatialDocumentScene(projection: SpatialDocumentProjection(document: model.document))
        #expect(cleared.nodes.isEmpty)
        #expect(cleared.edges.isEmpty)
    }

    @Test("Empty documents stay empty, without demo content")
    func emptyDocument() {
        let document = KollioDocument()
        let scene = SpatialDocumentScene(projection: SpatialDocumentProjection(document: document))
        #expect(scene.nodes.isEmpty)
        #expect(scene.edges.isEmpty)
    }
    @Test("Scene positioning and connector endpoints are deterministic")
    func stableScene() {
        let projection = SpatialDocumentProjection(document: SarahFixture.document())
        let first = SpatialDocumentScene(projection: projection)
        let second = SpatialDocumentScene(projection: projection)
        #expect(first.nodes == second.nodes)
        #expect(first.edges == second.edges)
    }

    @Test("C2.4 routes a real relationship around another real document object")
    func detoursRealDocumentObstacle() throws {
        var document = SarahFixture.document()
        let relation = try #require(document.relationships.values.first { $0.from != $0.to })
        let obstructingID = try #require(document.content.keys.first {
            $0 != relation.from && $0 != relation.to
        })
        document.presentation.instances = [
            NodeInstance(id: InstanceID("c24-source"), objectID: relation.from,
                         position: Position(x: 150, y: 200)),
            NodeInstance(id: InstanceID("c24-target"), objectID: relation.to,
                         position: Position(x: 850, y: 200)),
            NodeInstance(id: InstanceID("c24-obstacle"), objectID: obstructingID,
                         position: Position(x: 500, y: 200))
        ]
        let before = document
        let scene = SpatialDocumentScene(projection: SpatialDocumentProjection(document: document))
        let edge = try #require(scene.edges.first { $0.id == relation.id.rawValue })
        #expect(!edge.blocked)
        #expect(edge.crossings == 0)
        #expect(edge.points.count >= 3)
        let envelope = CGRect(x: 500 - 127, y: 200 - 82, width: 254, height: 164)
        for (start, end) in zip(edge.points, edge.points.dropFirst()) {
            #expect(!SpatialDocumentRouter.segmentHits(from: start, to: end, rect: envelope))
        }
        #expect(document == before)
    }

    @Test("C2.4 clear direct connections stay straight and stable")
    func straightConnectionStaysStraight() {
        let a = CGPoint(x: 100, y: 80)
        let b = CGPoint(x: 900, y: 80)
        let blocker = CGRect(x: 350, y: 350, width: 200, height: 100)
        let first = SpatialDocumentRouter.route(from: a, to: b, avoiding: [blocker])
        let second = SpatialDocumentRouter.route(from: a, to: b, avoiding: [blocker])
        #expect(first.points == [a, b])
        #expect(first.points == second.points)
        #expect(!first.blocked)
        #expect(first.crossings == 0)
    }

    @Test("C2.4 impossible route is identified as blocked")
    func routeFailClosed() {
        let a = CGPoint(x: 100, y: 100)
        let b = CGPoint(x: 900, y: 100)
        let surroundingCard = CGRect(x: 60, y: 60, width: 100, height: 100)
        let route = SpatialDocumentRouter.route(from: a, to: b, avoiding: [surroundingCard])
        #expect(route.blocked)
        #expect(route.crossings == 1)
    }

    @Test("C2.5 two authored occurrences stay individually visible without copying the semantic object")
    func multipleOccurrences() throws {
        var document = SarahFixture.document()
        let relation = try #require(document.relationships.values.sorted {
            $0.id.rawValue < $1.id.rawValue
        }.first { $0.from != $0.to })
        let objectID = relation.from
        let otherID = relation.to
        document.presentation.instances = [
            NodeInstance(id: "copy-b", objectID: objectID, position: Position(x: 750, y: 600)),
            NodeInstance(id: "copy-a", objectID: objectID, position: Position(x: 100, y: 200)),
            NodeInstance(id: "target", objectID: otherID, position: Position(x: 400, y: 600))
        ]
        let before = document
        let projection = SpatialDocumentProjection(document: document)
        let projectedObject = try #require(projection.nodes.first { $0.id == objectID.rawValue })
        #expect(projectedObject.occurrences.map(\.id) == ["copy-a", "copy-b"])
        let rendered = SpatialDocumentScene(projection: projection)
        let copies = rendered.nodes.filter { rendered.objectID(for: $0.id) == objectID.rawValue }
        #expect(copies.count == 2)
        #expect(rendered.semanticObjectCount == document.content.count)
        #expect(rendered.nodes.count == document.content.count + 1)
        #expect(Set(rendered.nodes.map(\.id)).count == rendered.nodes.count)
        #expect(rendered.visualID(for: objectID.rawValue) == objectID.rawValue)
        #expect(rendered.occurrenceCount(for: objectID.rawValue) == 2)
        let first = try #require(copies.first { $0.id == objectID.rawValue })
        let alternate = try #require(copies.first { $0.id != objectID.rawValue })
        #expect(abs(first.x * 1000 - 100) < 0.01)
        #expect(abs(first.y * 640 - 200) < 0.01)
        #expect(abs(alternate.x * 1000 - 750) < 0.01)
        #expect(abs(alternate.y * 640 - 600) < 0.01)
        #expect(first.label == alternate.label)
        #expect(rendered.objectID(for: alternate.id) == objectID.rawValue)
        #expect(rendered.edges.count == document.relationships.count)
        let edge = try #require(rendered.edges.first { $0.id == relation.id.rawValue })
        #expect(edge.source == alternate.id) // Nearest presentation copy
        #expect(edge.target == otherID.rawValue)
        #expect(SpatialDocumentScene(projection: projection).nodes == rendered.nodes)
        #expect(SpatialDocumentScene(projection: projection).edges == rendered.edges)
        #expect(document == before)
    }

    @Test("C2.5 hidden copies never leak into the visible scene")
    func hiddenOccurrence() throws {
        var document = SarahFixture.document()
        let objectID = try #require(document.content.keys.sorted { $0.rawValue < $1.rawValue }.first)
        document.presentation.instances = [
            NodeInstance(id: "visible", objectID: objectID, position: Position(x: 150, y: 200)),
            NodeInstance(id: "hidden", objectID: objectID,
                         position: Position(x: 700, y: 450), hidden: true)
        ]
        let projection = SpatialDocumentProjection(document: document)
        let content = try #require(projection.nodes.first { $0.id == objectID.rawValue })
        #expect(content.occurrences.count == 2)
        #expect(content.occurrences.filter(\.isHidden).count == 1)
        let rendered = SpatialDocumentScene(projection: projection)
        #expect(rendered.occurrenceCount(for: objectID.rawValue) == 1)
        #expect(rendered.nodes.filter { rendered.objectID(for: $0.id) == objectID.rawValue }.count == 1)
        #expect(document.presentation.instances.count == 2)
    }

    @Test("C2.5 only hidden representations do not create synthetic replacements")
    func allCopiesHidden() throws {
        var document = SarahFixture.document()
        let objectID = try #require(document.content.keys.sorted { $0.rawValue < $1.rawValue }.first)
        document.presentation.instances = [
            NodeInstance(id: "hidden", objectID: objectID,
                         position: Position(x: 700, y: 450), hidden: true)
        ]
        let rendered = SpatialDocumentScene(projection: SpatialDocumentProjection(document: document))
        #expect(rendered.occurrenceCount(for: objectID.rawValue) == 0)
        #expect(rendered.visualID(for: objectID.rawValue) == nil)
        #expect(!rendered.nodes.contains { rendered.objectID(for: $0.id) == objectID.rawValue })
    }

    @Test("C2.5 folding a frame hides only its member instance, not the shared object")
    func foldedFrameDoesNotHideOtherCopy() throws {
        var document = SarahFixture.document()
        let objectID = try #require(document.content.keys.sorted { $0.rawValue < $1.rawValue }.first)
        document.presentation.instances = [
            NodeInstance(id: "inside-frame", objectID: objectID,
                         position: Position(x: 100, y: 180)),
            NodeInstance(id: "outside-frame", objectID: objectID,
                         position: Position(x: 820, y: 450))
        ]
        document.presentation.frames = [
            Frame(id: "c25-frame", name: LocalizedText("Zone repliée"),
                  position: Position(x: 0, y: 0),
                  memberInstanceIDs: [InstanceID("inside-frame")], isFolded: true)
        ]
        let before = document
        let projection = SpatialDocumentProjection(document: document)
        let occurrences = try #require(projection.nodes.first { $0.id == objectID.rawValue }).occurrences
        #expect(occurrences.first { $0.id == "inside-frame" }?.isHidden == true)
        #expect(occurrences.first { $0.id == "outside-frame" }?.isHidden == false)
        let displayed = SpatialDocumentScene(projection: projection)
        #expect(displayed.occurrenceCount(for: objectID.rawValue) == 1)
        let soleCopy = try #require(displayed.nodes.first {
            displayed.objectID(for: $0.id) == objectID.rawValue
        })
        #expect(abs(soleCopy.x * 1000 - 820) < 0.01)
        #expect(abs(soleCopy.y * 640 - 450) < 0.01)
        #expect(document == before)
    }
}

@Suite("Spatial Ink C2.10 — readable graph navigation without pointer gestures")
struct SpatialV3ReadingOrderTests {
    private func node(_ id: String, y: Double) -> SpatialV3Node {
        SpatialV3Node(id: id, kind: "idea", label: id, eyebrow: "IDEA",
                      detail: "", status: "active", depth: 2, x: 0.5, y: y)
    }

    private func edge(_ source: String, _ target: String) -> SpatialV3Edge {
        SpatialV3Edge(id: source + ">" + target, source: source, target: target,
                      type: "relates", label: "", depth: 2, points: [],
                      blocked: false, crossings: 0)
    }

    @Test("Dependencies read before their children even when child is higher on screen")
    func graphFirst() {
        let nodes = [
            node("c", y: 0.2), node("b", y: 0.1),
            node("d", y: 0.9), node("a", y: 0.6)
        ]
        let links = [edge("b", "c"), edge("a", "b")]
        let read = SpatialV3ReadingOrder.ordered(nodes, edges: links).map(\.id)
        #expect(read == ["a", "b", "c", "d"])
        #expect(SpatialV3ReadingOrder.ordered(Array(nodes.reversed()), edges: Array(links.reversed()))
            .map(\.id) == read)
    }

    @Test("Cycles and disconnected drawings are reachable once, with stable ordering")
    func disconnectedAndCycles() {
        let nodes = [node("a", y: 0.3), node("b", y: 0.1), node("c", y: 0.7)]
        let edges = [edge("a", "b"), edge("b", "a")]
        let first = SpatialV3ReadingOrder.ordered(nodes, edges: edges).map(\.id)
        let second = SpatialV3ReadingOrder.ordered(Array(nodes.reversed()), edges: Array(edges.reversed()))
            .map(\.id)
        #expect(first == second)
        #expect(first.count == 3)
        #expect(Set(first) == Set(["a", "b", "c"]))
    }

    @Test("Browse uses the visual scene without changing the real .kollio document")
    func actualDocument() {
        let document = SarahFixture.document()
        let before = document
        let scene = SpatialDocumentScene(projection: SpatialDocumentProjection(document: document))
        let browsable = SpatialV3ReadingOrder.ordered(scene.nodes, edges: scene.edges)
        #expect(browsable.count == scene.nodes.count)
        #expect(Set(browsable.map(\.id)) == Set(scene.nodes.map(\.id)))
        #expect(document == before)
        #expect(SpatialV3Copy(languageCode: "fr").format("spatial.navigation.count", 7)
                == "Parcourir 7 cartes")
        #expect(SpatialV3Copy(languageCode: "en").format("spatial.navigation.count", 7)
                == "Browse 7 cards")
    }
}
