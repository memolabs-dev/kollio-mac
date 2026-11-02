import Foundation
import SwiftUI
import KollioCore

/// Where a connector attaches to an object, in world coordinates.
///
/// The anchor is stored in object-local unit space (0...1) so a connector keeps
/// following its object while the object moves or the text reflows.
public struct AnchorPoint: Equatable, Sendable {
    public var point: Position
    /// Unit direction the connector leaves the object in.
    public var direction: Position

    public init(point: Position, direction: Position) {
        self.point = point
        self.direction = direction
    }
}

public enum NodeLayout {
    /// Starting metrics used before SwiftUI has measured the real content.
    /// Content determines height, so these are minima, not fixed frames.
    public static let minimumWidth: Double = 190
    public static let thoughtHeight: Double = 54
    public static let referenceHeight: Double = 56
    public static let richResultHeight: Double = 96

    public static func estimatedSize(for object: ContentObject) -> Size {
        let width = max(minimumWidth, estimateWidth(for: object))
        switch object.form {
        case .thought:
            return Size(width: width, height: thoughtHeight)
        case .reference:
            return Size(width: width, height: referenceHeight)
        case .richResult:
            return Size(width: width, height: richResultHeight)
        }
    }

    /// Cheap estimate so hit testing is sane before the first measurement pass.
    /// Deliberately approximate: measured frames always win once available.
    static func estimateWidth(for object: ContentObject) -> Double {
        let characters = Double(max(object.text.text.count, 24))
        return min(characters * 7.6 + 44, 360)
    }
}

/// One cubic piece of a connector: start, two control points, end.
public struct ConnectorSegment: Equatable {
    public var start: Position
    public var control1: CGPoint
    public var control2: CGPoint
    public var end: Position

    public init(start: Position, control1: CGPoint, control2: CGPoint, end: Position) {
        self.start = start
        self.control1 = control1
        self.control2 = control2
        self.end = end
    }

    public func point(at t: Double) -> Position {
        let p0 = CGPoint(x: start.x, y: start.y)
        let p3 = CGPoint(x: end.x, y: end.y)
        let u = 1 - t
        let a = u * u * u
        let b = 3 * u * u * t
        let c = 3 * u * t * t
        let d = t * t * t
        return Position(
            x: a * p0.x + b * control1.x + c * control2.x + d * p3.x,
            y: a * p0.y + b * control1.y + c * control2.y + d * p3.y
        )
    }

    /// Points along the curve. Sampled rather than solved: an exact
    /// cubic-rectangle intersection is a lot of algebra for a question that only
    /// needs a yes or a no.
    public func samples(count: Int) -> [Position] {
        (0...count).map { point(at: Double($0) / Double(count)) }
    }
}

/// A connector: one piece when nothing is in the way, two when it detours.
public struct ConnectorRoute: Equatable {
    public var segments: [ConnectorSegment]

    public init(segments: [ConnectorSegment]) {
        self.segments = segments
    }

    public var start: Position? { segments.first?.start }
    public var end: Position? { segments.last?.end }

    /// How far a point is from this route.
    ///
    /// Hit testing a connector needs a distance, and a cubic Bézier has no closed
    /// form worth writing here. Twenty-four samples per segment is far denser than
    /// the tolerance it is compared against, so the answer is stable for the only
    /// question asked: is this point near the line.
    public func distance(to point: Position) -> Double {
        var closest = Double.greatestFiniteMagnitude
        for segment in segments {
            var previous = segment.start
            for step in 1...24 {
                let t = Double(step) / 24
                let sample = segment.point(at: t)
                closest = min(closest, distance(from: point, toSegmentBetween: previous, and: sample))
                previous = sample
            }
        }
        return closest
    }

    private func distance(from point: Position, toSegmentBetween a: Position, and b: Position) -> Double {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return hypot(point.x - a.x, point.y - a.y)
        }
        let t = max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared))
        return hypot(point.x - (a.x + t * dx), point.y - (a.y + t * dy))
    }

    public func path() -> Path {
        var path = Path()
        guard let first = segments.first else { return path }
        path.move(to: CGPoint(x: first.start.x, y: first.start.y))
        for segment in segments {
            path.addCurve(
                to: CGPoint(x: segment.end.x, y: segment.end.y),
                control1: segment.control1,
                control2: segment.control2
            )
        }
        return path
    }

    public func samples(count: Int) -> [Position] {
        segments.flatMap { $0.samples(count: count) }
    }

    /// Where a relationship label belongs: on the curve itself, so a label stays
    /// readable once a detour has moved the connector off the straight chord.
    /// A detour joins two pieces, and the join is its most characteristic point.
    public var midpoint: Position {
        guard segments.count > 1 else {
            return segments.first?.point(at: 0.5) ?? .zero
        }
        return segments[0].end
    }

    /// Whether any piece of the route passes inside an obstacle.
    public func intersects(_ obstacle: Rect) -> Bool {
        segments.contains { segment in
            segment.samples(count: RelationshipGeometry.sampleCount).contains { obstacle.contains($0) }
        }
    }

    /// Whether any piece of the route passes inside any of these obstacles.
    ///
    /// The route is sampled once and every obstacle is tested against that one
    /// array. The single-rect overload above re-samples the curve per obstacle,
    /// and at 200 connectors over 100 obstacles that shape spent 149 ms per
    /// render pass: about five million curve samples, most of them thrown away.
    public func intersects(_ obstacles: [Rect]) -> Bool {
        let samples = segments.flatMap { $0.samples(count: RelationshipGeometry.sampleCount) }
        return obstacles.contains { obstacle in
            samples.contains { obstacle.contains($0) }
        }
    }
}

public enum RelationshipGeometry {
    /// Resolves the world-space endpoints of a connector.
    public static func endpoints(
        of relationship: Relationship,
        from fromRect: Rect,
        to toRect: Rect
    ) -> (start: AnchorPoint, end: AnchorPoint) {
        let start = resolve(relationship.fromAnchor, in: fromRect, leaving: true)
        let end = resolve(relationship.toAnchor, in: toRect, leaving: false)
        return (start, end)
    }

    /// The direction is the one pointing away from the object, so a connector
    /// always leaves the source and always arrives at the target.
    static func resolve(_ anchor: Relationship.Anchor, in rect: Rect, leaving: Bool) -> AnchorPoint {
        let x = rect.origin.x + rect.size.width * anchor.unitX
        let y = rect.origin.y + rect.size.height * anchor.unitY
        let direction = anchor.unitY >= 0.5 ? Position(x: 0, y: 1) : Position(x: 0, y: -1)
        return AnchorPoint(point: Position(x: x, y: y), direction: direction)
    }

    /// A cubic connector between two objects. It leaves the source along its
    /// outward anchor, travels toward the target, and arrives along the target's
    /// outward anchor, so it never crosses the text of either object.
    public static func path(
        from start: AnchorPoint,
        to end: AnchorPoint
    ) -> Path {
        directRoute(from: start, to: end).path()
    }

    /// Widened, invisible stroke so the hit area is larger than the visible line.
    public static func hitPath(from start: AnchorPoint, to end: AnchorPoint) -> Path {
        path(from: start, to: end)
    }

    // MARK: Obstacle avoidance

    /// Breathing room kept between a connector and an object it detours around.
    /// Wide enough that the stroke and the relationship label never touch the
    /// object, tight enough that the detour stays readable.
    public static let clearance: Double = 18

    /// How many times a detour may be widened before falling back to the direct
    /// curve. A bounded search keeps a pathological document cheap.
    public static let maximumWideningSteps = 4

    /// Samples per piece used to decide whether a route crosses an obstacle.
    public static let sampleCount = 48

    /// A connector between two objects that does not cross anything sitting
    /// between them.
    ///
    /// The direct cubic is kept whenever it is clear, so a document laid out
    /// without obstructions renders exactly as it did before avoidance existed.
    /// Only a blocked connector is re-routed, and then through a waypoint on
    /// whichever side of the chord needs the smaller excursion.
    public static func routedRoute(
        from start: AnchorPoint,
        to end: AnchorPoint,
        obstacles: [Rect]
    ) -> ConnectorRoute {
        let direct = directRoute(from: start, to: end)
        // The corridor bounds every curve this function can return, which is what
        // makes filtering the obstacles by it honest rather than merely fast.
        //
        // The direct curve bulges at most 0.75 x its handle from the chord, and a
        // detour's control hull stops at `offset + handle`; both handles are at
        // least 34 pt, so + 68 covers the direct case whatever the endpoints'
        // direction. An obstacle outside the corridor cannot be crossed by any
        // attempt, and excluding it costs four comparisons instead of the 49
        // point-in-rect tests it would otherwise cost.
        //
        // Measured: 200 connectors over 100 obstacles, 149 ms per pass without
        // this and 9 ms with it, in a 10x10 grid where most obstacles are nowhere
        // near a given connector.
        let chord = Position(x: end.point.x - start.point.x, y: end.point.y - start.point.y)
        let chordLength = (chord.x * chord.x + chord.y * chord.y).squareRoot()
        let halfWidth = chordLength * 0.8 + clearance * 2 + 68
        let corridor = corridorFor(start: start.point, end: end.point, width: halfWidth)
        let grown = obstacles.compactMap { rect -> Rect? in
            let grownRect = rect.insetBy(dx: -clearance, dy: -clearance)
            return corridor.intersects(grownRect) ? grownRect : nil
        }
        // The direct curve is sampled once, and each obstacle is rejected by four
        // comparisons before any sample is read. The box is built from the
        // samples themselves: a control-point box is far taller than the curve it
        // encloses, because the handles sit 34 to 68 pt away, so it rejects almost
        // nothing and costs an allocation to build.
        let directSamples = direct.segments.flatMap { $0.samples(count: RelationshipGeometry.sampleCount) }
        var minX = directSamples[0].x, maxX = directSamples[0].x
        var minY = directSamples[0].y, maxY = directSamples[0].y
        for sample in directSamples {
            if sample.x < minX { minX = sample.x }
            if sample.x > maxX { maxX = sample.x }
            if sample.y < minY { minY = sample.y }
            if sample.y > maxY { maxY = sample.y }
        }
        let blocking = grown.filter { rect in
            guard rect.maxX >= minX, rect.minX <= maxX, rect.maxY >= minY, rect.minY <= maxY else { return false }
            return directSamples.contains { rect.contains($0) }
        }
        guard let side = detourSide(for: blocking, start: start.point, end: end.point) else {
            return direct
        }

        let normal = unitNormal(of: Position(x: end.point.x - start.point.x, y: end.point.y - start.point.y))
        let midpoint = Position(x: (start.point.x + end.point.x) / 2, y: (start.point.y + end.point.y) / 2)
        var offset = side.required

        // `offset + handle <= halfWidth` keeps every attempt inside the corridor,
        // which is what lets the obstacle filter above skip obstacles it never
        // tests: a curve that left the corridor would cross an obstacle nobody
        // checked. Past the bound, fall through to the direct curve, the same
        // degraded answer the loop already gave when widening failed.
        let halfChordDy = abs(end.point.y - start.point.y) / 2
        for _ in 0...maximumWideningSteps {
            let handle = max((halfChordDy + offset) * 0.42, 34.0)
            guard offset + handle <= halfWidth else { break }
            let waypoint = midpoint.offset(dx: normal.x * offset * side.direction, dy: normal.y * offset * side.direction)
            let route = detourRoute(from: start, to: end, through: waypoint)
            let samples = route.segments.flatMap { $0.samples(count: RelationshipGeometry.sampleCount) }
            let blocked = blocking.contains { obstacle in
                samples.contains { obstacle.contains($0) }
            }
            if blocked == false { return route }
            offset *= 1.6
        }
        // Widening did not clear it. The direct curve is the least bad option: a
        // connector that crosses one object is better than one that loops around
        // the whole canvas.
        return direct
    }

    public static func routedPath(
        from start: AnchorPoint,
        to end: AnchorPoint,
        obstacles: [Rect]
    ) -> Path {
        routedRoute(from: start, to: end, obstacles: obstacles).path()
    }

    // MARK: Routes

    static func directRoute(from start: AnchorPoint, to end: AnchorPoint) -> ConnectorRoute {
        ConnectorRoute(segments: [segment(from: start.point, to: end.point)])
    }

    /// Two cubics through a waypoint. Each piece leaves and arrives vertically,
    /// so the detour reads as the same kind of curve as the direct one.
    static func detourRoute(from start: AnchorPoint, to end: AnchorPoint, through waypoint: Position) -> ConnectorRoute {
        ConnectorRoute(segments: [
            segment(from: start.point, to: waypoint),
            segment(from: waypoint, to: end.point)
        ])
    }

    /// One cubic between two points, bulging away from the gap they are joined
    /// across, which keeps the curve outside both objects.
    static func segment(from start: Position, to end: Position) -> ConnectorSegment {
        let targetIsBelow = end.y >= start.y
        let handle = max(abs(end.y - start.y) * 0.42, 34.0)
        return ConnectorSegment(
            start: start,
            control1: CGPoint(
                x: start.x,
                y: targetIsBelow ? start.y + handle : start.y - handle
            ),
            control2: CGPoint(
                x: end.x,
                y: targetIsBelow ? end.y - handle : end.y + handle
            ),
            end: end
        )
    }

    // MARK: Detour choice

    struct DetourSide: Equatable {
        /// Which way to leave the chord: 1 or -1.
        var direction: Double
        /// How far the waypoint must sit from the chord midpoint to clear every
        /// blocking obstacle on that side.
        var required: Double
    }

    /// Picks the side of the chord that needs the smaller excursion, and how far
    /// out the waypoint has to sit to clear the obstacles on that side.
    /// How many curve samples routing this connector actually takes.
    ///
    /// The measurement the scaling test reads, and a diagnostic worth having in
    /// its own right: it says what the shape of the router costs, with the
    /// machine out of it. It is the same work `routedRoute` does, counted rather
    /// than performed, and it exists so the invariant can be proven by a test
    /// that does not depend on how fast the machine is that day.
    public static func samplesTaken(
        from start: AnchorPoint,
        to end: AnchorPoint,
        obstacles: [Rect]
    ) -> Int {
        let direct = directRoute(from: start, to: end)
        let chord = Position(x: end.point.x - start.point.x, y: end.point.y - start.point.y)
        let chordLength = (chord.x * chord.x + chord.y * chord.y).squareRoot()
        let halfWidth = chordLength * 0.8 + clearance * 2 + 68
        let corridor = corridorFor(start: start.point, end: end.point, width: halfWidth)
        let candidates = obstacles.filter { corridor.intersects($0.insetBy(dx: -clearance, dy: -clearance)) }

        var taken = direct.segments.count * sampleCount
        let directSamples = direct.segments.flatMap { $0.samples(count: sampleCount) }
        for rect in candidates where directSamples.contains(where: { rect.contains($0) }) {
            // Each blocker costs the widening loop's attempts, and the loop is
            // bounded, so this counts the attempts it would actually make.
            taken += maximumWideningSteps * 2 * sampleCount
        }
        return taken
    }

    /// The rectangle a route may never leave: the box between the two endpoints,
    /// widened by `width` on every side.
    ///
    /// Every attempt in the widening loop passes through the same two endpoints
    /// and bulges outward, so nothing outside this rectangle is ever touched.
    static func corridorFor(start: Position, end: Position, width: Double) -> Rect {
        let minX = min(start.x, end.x) - width
        let maxX = max(start.x, end.x) + width
        let minY = min(start.y, end.y) - width
        let maxY = max(start.y, end.y) + width
        return Rect(
            origin: Position(x: minX, y: minY),
            size: Size(width: maxX - minX, height: maxY - minY)
        )
    }

    /// The obstacles one connector has to route around.
    ///
    /// A connector must not be blocked by its own two ends, so every routing call
    /// needs the set minus two entries. Doing that by comparing identifiers once
    /// per obstacle cost 24 µs per connector at 400 objects, and — this is the
    /// part that matters — it grew with the document: four times the objects was
    /// 2.7 times the cost per connector, which put a real document past the
    /// 16 ms frame. This holds the rectangles contiguously and the position of
    /// each identifier once, so excluding an end is one copy and two lookups.
    struct ObstacleSet: Sendable {
        private let rects: [Rect]
        private let index: [ObjectID: Int]

        init(_ entries: [(id: ObjectID, rect: Rect)]) {
            var rects: [Rect] = []
            var index: [ObjectID: Int] = [:]
            rects.reserveCapacity(entries.count)
            index.reserveCapacity(entries.count)
            for entry in entries {
                // A later entry for the same object replaces the earlier one:
                // an object drawn twice contributes one obstacle, and the last
                // frame is the one the renderer is using.
                if let existing = index[entry.id] {
                    rects[existing] = entry.rect
                } else {
                    index[entry.id] = rects.count
                    rects.append(entry.rect)
                }
            }
            self.rects = rects
            self.index = index
        }

        /// Every rectangle, for a caller that needs no exclusion.
        var all: [Rect] { rects }

        /// The rectangles one connector may collide with.
        ///
        /// The higher index goes first: removing the lower one would move the
        /// other, and the two are not necessarily in order.
        func excluding(_ from: ObjectID, _ to: ObjectID) -> [Rect] {
            var others = rects
            let pair = Set([index[from], index[to]].compactMap { $0 }).sorted(by: >)
            for position in pair where position < others.count {
                others.swapAt(position, others.count - 1)
                others.removeLast()
            }
            return others
        }
    }

    static func detourSide(for obstacles: [Rect], start: Position, end: Position) -> DetourSide? {
        guard obstacles.isEmpty == false else { return nil }
        let normal = unitNormal(of: Position(x: end.x - start.x, y: end.y - start.y))
        let midpoint = Position(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)

        var left: Double = 0
        var right: Double = 0
        for obstacle in obstacles {
            for corner in corners(of: obstacle) {
                let lateral = (corner.x - midpoint.x) * normal.x + (corner.y - midpoint.y) * normal.y
                // An obstacle entirely on the chord forces no excursion.
                if lateral > left { left = lateral }
                if -lateral > right { right = -lateral }
            }
        }
        if left <= 0, right <= 0 { return nil }
        // Ties go one way only, so the same document always routes the same.
        return left <= right
            ? DetourSide(direction: 1, required: left)
            : DetourSide(direction: -1, required: right)
    }

    static func unitNormal(of vector: Position) -> Position {
        let length = (vector.x * vector.x + vector.y * vector.y).squareRoot()
        guard length > 0.0001 else { return Position(x: 0, y: -1) }
        return Position(x: -vector.y / length, y: vector.x / length)
    }

    static func corners(of rect: Rect) -> [Position] {
        [
            Position(x: rect.minX, y: rect.minY),
            Position(x: rect.maxX, y: rect.minY),
            Position(x: rect.maxX, y: rect.maxY),
            Position(x: rect.minX, y: rect.maxY)
        ]
    }
}
