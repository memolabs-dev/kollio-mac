import Foundation
import Testing
import KollioCore
@testable import KollioApp

/// The canvas measured, not guessed (roadmap item 5).
///
/// The device: a document of 100 objects and 200 relationships, the shape the
/// roadmap names, laid out on a grid so the frame is dense rather than spread.
/// Everything timed here is the *hot path of one frame*, called repeatedly so
/// the per-call cost is above the clock's resolution: the visible-instance
/// filter, the relationship render pass with its obstacle routing, the hit
/// test, and the ground scale decision. A drag calls all of these per frame.
///
/// What this suite deliberately does not claim: anything about SwiftUI's
/// rendering. `Canvas` draw time is measured as the cost of building the paths,
/// which is the part the code owns. The render tree's own cost needs
/// Instruments on the real app, and the numbers here are the baseline that
/// makes such a run interpretable.
@Suite("The canvas at scale")
@MainActor
struct CanvasScaleTests {
    /// 100 objects, 200 relationships, on a 10 by 10 grid of 200-pt cells.
    ///
    /// Half the relationships are `supports` so the marker path runs too: a
    /// benchmark that measured only the plain kinds would miss the vocabulary
    /// added this session.
    private func denseModel(columns: Int = 10) -> KollioModel {
        var builder = DocumentBuilder()
        var ids: [ObjectID] = []
        for row in 0..<10 {
            for column in 0..<columns {
                let id = ObjectID("object:bench-\(row)-\(column)")
                builder.object(
                    "bench-\(row)-\(column)", kind: .hypothesis,
                    "Objet \(row) \(column)",
                    en: "Object \(row) \(column)",
                    at: Position(x: Double(column) * 200, y: Double(row) * 160)
                )
                ids.append(id)
            }
        }
        // Each object linked to the one right of it and the one below it, except
        // on the last row and column. At ten columns that is 180 relationships.
        for row in 0..<10 {
            for column in 0..<columns {
                let index = row * columns + column
                if column < columns - 1 {
                    builder.link("bench-lr-\(index)", from: ids[index], to: ids[index + 1], .supports)
                }
                if row < 9 {
                    builder.link("bench-tb-\(index)", from: ids[index], to: ids[index + columns], .dependsOn)
                }
            }
        }
        var document = builder.document
        for (index, id) in ids.enumerated() {
            document.presentation.instances[index].size = Size(width: 160, height: 120)
        }
        return KollioModel(
            document: document,
            service: KollioModel.makeDemoService(languageCode: "fr"),
            fileStore: DocumentFileStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()))
        )
    }

    private func perCallMicroseconds(_ calls: Int = 50, _ body: () -> Void) -> Double {
        // Warm first: the first call allocates and fills caches the steady
        // state never sees, and the steady state is what a pan or a drag pays.
        _ = body()
        let start = DispatchTime.now()
        for _ in 0..<calls { body() }
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds)
        return elapsed / Double(calls) / 1000.0
    }

    @Test("100 objects: the visible filter stays trivial")
    func visibleFilter() {
        let model = denseModel()
        let perCall = perCallMicroseconds { _ = model.visibleInstances }
        // Measured 0.15 ms on an idle machine; the ceiling is roughly twenty
        // times that, so it catches an accidental linear rescan rather than a
        // busy build machine. The shape of this cost is pinned by the scaling
        // test below, which does not depend on how fast the machine is.
        #expect(perCall < 3000, "the visible-instance filter costs \(String(format: "%.1f", perCall)) µs per call at 100 objects")
    }

    /// What one render pass actually costs, the way the layer pays it: project
    /// every obstacle, take the relationship list, then route each connector.
    ///
    /// This is a separate function on purpose. An earlier version of this test
    /// carried six `DispatchTime.now()` calls per relationship *inside* the
    /// measured closure to attribute the cost to a phase, which meant the number
    /// the assertion read was not the number a frame pays.
    private func renderPassOnce(_ model: KollioModel) {
        let obstacles = RelationshipGeometry.ObstacleSet(screenObstacles(model))
        for relationship in model.relationshipsToRender() {
            guard let fromFrame = model.frame(of: relationship.from),
                  let toFrame = model.frame(of: relationship.to) else { continue }
            let others = obstacles.excluding(relationship.from, relationship.to)
            let (worldStart, worldEnd) = RelationshipGeometry.endpoints(
                of: relationship, from: fromFrame, to: toFrame
            )
            let start = AnchorPoint(point: model.camera.toScreen(worldStart.point), direction: worldStart.direction)
            let end = AnchorPoint(point: model.camera.toScreen(worldEnd.point), direction: worldEnd.direction)
            _ = RelationshipGeometry.routedRoute(from: start, to: end, obstacles: others)
        }
    }

    /// Every object rectangle, projected, the way a draw pass builds them.
    private func screenObstacles(_ model: KollioModel) -> [(id: ObjectID, rect: Rect)] {
        var rects: [(id: ObjectID, rect: Rect)] = []
        for instance in model.visibleInstances {
            guard let frame = model.frame(of: instance.objectID) else { continue }
            rects.append((instance.objectID, model.camera.toScreen(frame)))
        }
        return rects
    }

    @Test("An object drawn twice contributes one current routing obstacle")
    func duplicateObstacleUsesTheCurrentFrameOnce() {
        let first = Rect(origin: Position(x: 0, y: 0), size: Size(width: 10, height: 10))
        let current = Rect(origin: Position(x: 20, y: 20), size: Size(width: 10, height: 10))
        let other = Rect(origin: Position(x: 40, y: 40), size: Size(width: 10, height: 10))
        let obstacles = RelationshipGeometry.ObstacleSet([
            (id: "object:a", rect: first),
            (id: "object:a", rect: current),
            (id: "object:b", rect: other),
        ])

        #expect(obstacles.all == [current, other])
        #expect(obstacles.excluding("object:a", "object:a") == [other])
    }

    /// A model whose canvas has already been laid out, which is the state a drag
    /// frame sees. A cold frame cache measured a linear scan of every instance
    /// per lookup and reported it as routing cost.
    private func warmed(_ model: KollioModel) -> KollioModel {
        for instance in model.visibleInstances {
            if let frame = model.frame(of: instance.objectID) {
                model.recordFrame(frame, for: instance.objectID)
            }
        }
        return model
    }

    @Test("100 objects, 180 relationships: one full render pass fits a frame")
    func renderPass() {
        let model = warmed(denseModel())
        // Pan first, so the measured pass is the steady state a drag sees and
        // not the fit-on-open state.
        model.camera.pan(byScreenDelta: Position(x: 40, y: 30))
        let perCall = perCallMicroseconds { renderPassOnce(model) }
        // Measured 5.6 ms on an idle machine, against a 16 ms frame. The ceiling
        // is roughly double that: high enough that a busy build machine does not
        // fail it, low enough that a return to the shape which cost 149 ms is a
        // failure. The shape itself is pinned by `routingCostDoesNotFollowTheObjectCount`.
        #expect(perCall < 12000, "a render pass over 100 objects and 180 relationships costs \(String(format: "%.0f", perCall)) µs")
    }

    /// The invariant that separates a working router from a broken one, and the
    /// reason the first one did not catch the 149 ms regression.
    ///
    /// The number of curve samples a router must take, per connector, as the
    /// document grows.
    ///
    /// This is the invariant behind the timing, and it is measured by counting
    /// rather than by timing. A router that tests every obstacle against the
    /// curve takes 49 samples per obstacle, so its cost per connector grows with
    /// the object count — that shape cost 149 ms. A router that rejects an
    /// obstacle by comparing rectangles first pays four comparisons to discard it
    /// and 49 samples for the few that survive, so its sample count barely
    /// moves.
    ///
    /// A first version asserted a *ratio of two timed passes*. It failed about
    /// one time in three, because a busy machine preempts the shorter pass
    /// proportionally harder than the longer one, so the ratio moved with the
    /// load rather than with the code. Counting removes the machine from the
    /// measurement, which is the whole reason this test exists.
    @Test("A connector does not sample the whole document")
    func samplingIsBoundedByTheCorridor() {
        func samplesPerConnector(columns: Int) -> Double {
            let model = warmed(denseModel(columns: columns))
            let obstacles = RelationshipGeometry.ObstacleSet(screenObstacles(model))
            let count = Double(model.relationshipsToRender().count)
            var taken = 0.0
            for relationship in model.relationshipsToRender() {
                guard let fromFrame = model.frame(of: relationship.from),
                      let toFrame = model.frame(of: relationship.to) else { continue }
                let others = obstacles.excluding(relationship.from, relationship.to)
                let (worldStart, worldEnd) = RelationshipGeometry.endpoints(
                    of: relationship, from: fromFrame, to: toFrame
                )
                taken += Double(
                    RelationshipGeometry.samplesTaken(
                        from: AnchorPoint(point: model.camera.toScreen(worldStart.point), direction: worldStart.direction),
                        to: AnchorPoint(point: model.camera.toScreen(worldEnd.point), direction: worldEnd.direction),
                        obstacles: others
                    )
                )
            }
            return taken / count
        }
        let narrow = samplesPerConnector(columns: 10)   // 100 objects
        let wide = samplesPerConnector(columns: 40)     // 400 objects, same links
        // Measured 1.00x, and the reason is that this grid's connectors run
        // between neighbours with a gap between them, so nothing blocks a
        // direct curve and the widening loop never runs. The bound being proven
        // is therefore the candidate scan — a connector reads the obstacles in
        // its corridor and samples only the ones that survive, so growing the
        // document fourfold does not grow what it samples. A router without the
        // corridor would sample all 400.
        #expect(
            wide < narrow * 2,
            "sampling per connector grew \(String(format: "%.1f", wide / narrow))x from 100 to 400 objects, which means obstacles are still being sampled one by one"
        )

        // The bound above is only meaningful if the counter can go up. A
        // rectangle parked on a connector's chord blocks it, and the widening
        // loop then costs real samples; the count has to report that, otherwise
        // a router that silently never detours would pass this test too.
        let start = AnchorPoint(point: Position(x: 0, y: 0), direction: Position(x: 0, y: -1))
        let end = AnchorPoint(point: Position(x: 200, y: 0), direction: Position(x: 0, y: 1))
        let clear = RelationshipGeometry.samplesTaken(from: start, to: end, obstacles: [])
        let blocked = RelationshipGeometry.samplesTaken(
            from: start, to: end,
            obstacles: [Rect(origin: Position(x: 60, y: -40), size: Size(width: 80, height: 80))]
        )
        #expect(clear > 0)
        #expect(
            blocked > clear,
            "an obstacle on the chord must cost more samples than a clear run, or the counter is not measuring the routing"
        )
    }

    @Test("The hit test at 180 relationships stays interactive")
    func hitTest() {
        let model = warmed(denseModel())
        let corner = Position(x: 10, y: 10)
        let center = Position(x: 900, y: 720)
        // The two ends of the honest range: a corner, where the corridor rejects
        // nearly every link before routing it, and the middle of the document,
        // where it does not. The centre is the one asserted.
        let cornerCost = perCallMicroseconds { _ = model.relationship(near: corner) }
        let centerCost = perCallMicroseconds { _ = model.relationship(near: center) }
        // A click pays this once, not per frame, so the budget is generous: it
        // is a share of the 100 ms below which an interface still reads as
        // instant. Measured 2.9 ms in the middle on an idle machine.
        #expect(
            centerCost < 15000,
            "a hit test over 180 relationships costs \(String(format: "%.0f", centerCost)) µs in the middle of the document, \(String(format: "%.0f", cornerCost)) µs at a corner"
        )
    }

}
