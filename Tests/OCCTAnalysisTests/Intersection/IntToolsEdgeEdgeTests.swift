import Foundation
import Testing
import simd

@testable import OCCTSwift

/// The fixtures are required rather than `if let`-wrapped: a nil edge used to skip every
/// assertion and pass (#1754, #1756).
///
/// The counts, parameter ranges and points are what `IntTools_EdgeEdge` reports for these
/// inputs, each derivable from the two edges rather than read off a run.
///
/// **A part carries two facts and #3012 keeps them apart.** `param1Range` and `param2Range` are the
/// kernel's own `Range1()` and `Ranges2()(1)`, the extent of the part, and `vertexParameter1` and
/// `vertexParameter2` are where OCCT places the new vertex of a `.vertex` part. Until #3012 the
/// bridge overwrote the first with the second on every `.vertex` part, which is how a tangential
/// overlap came back as a point. `BOPAlgo_PaveFiller::PerformEE` reads both off a vertex part and
/// never one in place of the other (`BOPAlgo_PaveFiller_3.cxx:381-394`), so neither does this API.
@Suite("IntTools_EdgeEdge Tests")
struct IntToolsEdgeEdgeTests {
    /// What `IntTools_EdgeEdge` adds to each edge's own tolerance before it computes a crossing's
    /// window: half of its default fuzzy value, which is `Precision::Confusion()`
    /// (`IntTools_EdgeEdge.lxx:24`, applied at `IntTools_EdgeEdge.cxx:149-151`).
    private static let halfFuzzyValue = 0.5e-7

    /// #1754: this read `type` and a 0.1-wide box round the origin, with every assertion inside
    /// an `if let` on the two edges.
    ///
    /// The X-axis edge and the Y-axis edge cross once, at the origin. Each is parameterised by
    /// length from its own start, and each start is 1 from the origin, so the crossing is at
    /// parameter 1 on both.
    ///
    /// #3012: the crossing and the window round it are asserted as two things. The vertex
    /// parameters are the crossing, exactly 1 on each edge. The ranges are the tolerance window
    /// `IntTools_EdgeEdge::ComputeLineLine` puts round it, `(t - dt, t + dt)` on each edge, where
    /// `dt = ComputeIntRange(tol1, tol2, angle)` is just the other edge's tolerance at a right
    /// angle (`IntTools_Tools.cxx:783`). Each edge carries `edgeTolerance`, and the kernel adds
    /// half its fuzzy value, so the half-width is `edgeTolerance + 0.5e-7`. A `(1, 1)` range, which
    /// is what the bridge reported before #3012, fails all four range assertions.
    @Test("Intersecting edges produce vertex common part")
    func edgeEdgeVertex() throws {
        let edge1 = try #require(Shape.edgeFromPoints(SIMD3(-1, 0, 0), SIMD3(1, 0, 0)))
        let edge2 = try #require(Shape.edgeFromPoints(SIMD3(0, -1, 0), SIMD3(0, 1, 0)))
        let parts = try #require(edge1.edgeEdgeIntersection(with: edge2))
        #expect(parts.count == 1)
        let first = try #require(parts.first)
        #expect(first.type == .vertex)

        let vertex1 = try #require(first.vertexParameter1, "a vertex part has a vertex parameter")
        let vertex2 = try #require(first.vertexParameter2, "an edge-edge vertex part has two")
        #expect(abs(vertex1 - 1) < 1e-9, "vertex parameter on edge 1 is \(vertex1)")
        #expect(abs(vertex2 - 1) < 1e-9, "vertex parameter on edge 2 is \(vertex2)")

        let halfWidth1 = edge2.edgeTolerance + Self.halfFuzzyValue
        let halfWidth2 = edge1.edgeTolerance + Self.halfFuzzyValue
        #expect(abs(first.param1Range.first - (1 - halfWidth1)) < 1e-12, "r1 \(first.param1Range)")
        #expect(abs(first.param1Range.last - (1 + halfWidth1)) < 1e-12, "r1 \(first.param1Range)")
        #expect(abs(first.param2Range.first - (1 - halfWidth2)) < 1e-12, "r2 \(first.param2Range)")
        #expect(abs(first.param2Range.last - (1 + halfWidth2)) < 1e-12, "r2 \(first.param2Range)")

        let point = try #require(first.point, "a vertex part reported no point")
        #expect(simd_length(point) < 1e-6, "point \(point) is not the origin")
    }

    /// #3012: a shallower crossing carries a wider window, and the width is the kernel's own.
    ///
    /// `ComputeLineLine` sets each edge's window to `ComputeIntRange(tol1, tol2, angle)`, which
    /// is `tol1 * tan(pi/2 - angle) + tol2 / sin(angle)` away from a right angle
    /// (`IntTools_Tools.cxx:783`), so the window grows as the angle falls. The two lines cross at
    /// the origin at parameter 1 on each, at one degree and at one hundredth of one. The bridge's
    /// `(t, t)` could not show the widening, and the old `abs(first - 1) < 1e-6` assertion held
    /// only for a right angle: at 0.01 degrees the window is 1.7e-3 either side.
    ///
    /// The vertex parameter is the crossing at every angle, which is what separates it from the
    /// range: the range changes by a factor of a hundred and the parameter does not move.
    @Test("A shallower crossing carries a wider window, the kernel's own (#3012)")
    func shallowerCrossingsCarryWiderWindows() throws {
        let x = try #require(Shape.edgeFromPoints(SIMD3(-1, 0, 0), SIMD3(1, 0, 0)))
        var halfWidths: [Double] = []
        for degrees in [1.0, 0.01] {
            let angle = degrees * .pi / 180
            let other = try #require(
                Shape.edgeFromPoints(
                    SIMD3(-cos(angle), -sin(angle), 0), SIMD3(cos(angle), sin(angle), 0)))
            // Both edges came from `edgeFromPoints`, so both carry the same tolerance.
            let tolerance = x.edgeTolerance + Self.halfFuzzyValue
            let halfWidth = tolerance * tan(.pi / 2 - angle) + tolerance / sin(angle)

            let parts = try #require(x.edgeEdgeIntersection(with: other))
            #expect(parts.count == 1, "\(degrees) degrees: \(parts.count) parts")
            let part = try #require(parts.first)
            #expect(part.type == .vertex)
            let vertex1 = try #require(part.vertexParameter1)
            #expect(abs(vertex1 - 1) < 1e-9, "\(degrees) degrees: vertex parameter \(vertex1)")
            #expect(
                abs(part.param1Range.first - (1 - halfWidth)) < 1e-12,
                "\(degrees) degrees: r1 \(part.param1Range), expected half-width \(halfWidth)")
            #expect(
                abs(part.param1Range.last - (1 + halfWidth)) < 1e-12,
                "\(degrees) degrees: r1 \(part.param1Range), expected half-width \(halfWidth)")
            halfWidths.append((part.param1Range.last - part.param1Range.first) / 2)
        }
        #expect(halfWidths.count == 2)
        // sin and tan both scale with the angle at these sizes, so a hundredth of the angle is a
        // hundred times the window.
        #expect(
            abs(halfWidths[1] / halfWidths[0] - 100) < 0.01,
            "the two windows should differ by 100x, got \(halfWidths[1] / halfWidths[0])")
    }

    /// #2251: an edge-type part's point has to sit inside the overlap, not at the origin.
    ///
    /// `IntTools_EdgeEdge` never calls `IntTools_CommonPrt::SetBoundingPoints`, so the bounding
    /// points it hands back are the `(0, 0, 0)` its own constructor set, and the bridge's midpoint of
    /// the two was the origin whatever the overlap. This test read only `type` before, which is why
    /// it passed throughout.
    ///
    /// The two edges overlap x in [1, 2], and the origin is outside that, so no fabricated zero can
    /// satisfy the range assertion.
    ///
    /// The `.edge` here is also half of #2994's finding, and the half that is a real
    /// inconsistency inside OCCT. Two straight edges short-circuit into
    /// `IntTools_EdgeEdge::ComputeLineLine`, which never reaches `MergeSolutions` and types
    /// **every** coincident overlap `TopAbs_EDGE` (`IntTools_EdgeEdge.cxx:989`), whole-range or
    /// not. The overlap here covers neither edge, and the geometrically identical arc fixture
    /// below (`arcOverlapPointLiesOnTheArc`) comes back `.vertex` for exactly that reason. If a
    /// kernel bump makes these two agree, this assertion and that one are where it shows up.
    ///
    /// #3012: an `.edge` part has no vertex parameter, because OCCT never sets one on it
    /// (`IntTools_EdgeEdge.cxx:804`, inside `if (theType == TopAbs_VERTEX)`). The field it would
    /// read is the `0.0` `IntTools_CommonPrt`'s constructor gave it, so reporting it would be a
    /// default standing in for a measurement.
    @Test("Overlapping collinear edges produce edge common part")
    func edgeEdgeOverlap() throws {
        let edge1 = try #require(Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(2, 0, 0)))
        let edge2 = try #require(Shape.edgeFromPoints(SIMD3(1, 0, 0), SIMD3(3, 0, 0)))
        let parts = try #require(edge1.edgeEdgeIntersection(with: edge2))
        #expect(parts.count == 1)
        let first = try #require(parts.first)
        #expect(first.type == .edge)
        #expect(first.param1Range.first == 1.0)
        #expect(first.param1Range.last == 2.0)
        // The same overlap on the second edge, which starts at x = 1, is [0, 1].
        #expect(abs(first.param2Range.first) < 1e-9, "r2 \(first.param2Range)")
        #expect(abs(first.param2Range.last - 1) < 1e-9, "r2 \(first.param2Range)")
        #expect(first.vertexParameter1 == nil, "an edge part has no vertex parameter")
        #expect(first.vertexParameter2 == nil, "an edge part has no vertex parameter")
        let point = try #require(
            first.point, "an edge part over a real overlap reported no point")
        #expect(point.x > 1.0, "point x = \(point.x), outside the overlap")
        #expect(point.x < 2.0, "point x = \(point.x), outside the overlap")
        #expect(abs(point.y) < 1e-12)
        #expect(abs(point.z) < 1e-12)
    }

    /// #2251, on a curve, where a fabricated point and a real one are far apart.
    ///
    /// Two arcs of one radius-10 circle, [0, pi] and [pi/2, 3pi/2], meet over [pi/2, pi]. The point
    /// reported has to lie on the circle, so it is 10 from the centre; the origin, which the
    /// unset bounding points produced, is 0 from it.
    ///
    /// `type` is `.vertex` here and `.edge` for the contained overlap below, and #2994 settled
    /// why. `IntTools_EdgeEdge::MergeSolutions` starts at `TopAbs_VERTEX` and promotes the merged
    /// range to `TopAbs_EDGE` only when it covers the **whole** of one of the two edges
    /// (`IntTools_EdgeEdge.cxx:756-765`). `[pi/2, pi]` is the whole of neither `[0, pi]` nor
    /// `[pi/2, 3pi/2]`, so it stays a vertex. Predicted from that rule and confirmed on seven arc
    /// fixtures in `Scripts/repro/2994-edgeedge-overlap-type/`, which also retires #2994's guess
    /// that the trigger is the overlap reaching an edge endpoint: `[0, pi]` against `[pi/2, pi]`
    /// ends at `a`'s own last parameter and comes back `.edge`.
    ///
    /// #3012: the part is a `.vertex` and still carries the whole overlap. This test used to
    /// assert only that `param1Range` sat inside `[pi/2, pi]`, which the bridge's collapsed
    /// `(3pi/4, 3pi/4)` satisfied, so it could not tell a quarter circle of coincidence from a
    /// single point. It now asserts the extent, on both edges, and then where the vertex goes:
    /// the midpoint of the overlap, 3pi/4, which is `FindBestSolution`'s answer for a flat
    /// coincidence and is OCCT's representative parameter rather than its extent. The point is
    /// that parameter on the circle, `(10 cos 3pi/4, 10 sin 3pi/4, 0)`, not merely some point at
    /// radius 10.
    @Test("An overlap on a circular arc reports a point on the arc (#2251)")
    func arcOverlapPointLiesOnTheArc() throws {
        let part = try Self.singleArcPart(a: 0...(.pi), b: (.pi / 2)...(3 * .pi / 2))
        #expect(
            part.type == .vertex,
            "neither range is wholly covered, so #2994's rule says vertex")

        // The overlap [pi/2, pi] on a, and on b, whose parameterisation is the same angle. The
        // kernel's own ranges carry 3e-8 of slack at one end, which is why this is 1e-6.
        #expect(abs(part.param1Range.first - .pi / 2) < 1e-6, "r1 \(part.param1Range)")
        #expect(abs(part.param1Range.last - .pi) < 1e-6, "r1 \(part.param1Range)")
        #expect(abs(part.param2Range.first - .pi / 2) < 1e-6, "r2 \(part.param2Range)")
        #expect(abs(part.param2Range.last - .pi) < 1e-6, "r2 \(part.param2Range)")
        let extent = part.param1Range.last - part.param1Range.first
        #expect(abs(extent - .pi / 2) < 1e-6, "a quarter circle of coincidence, got \(extent)")

        let vertex1 = try #require(part.vertexParameter1)
        let vertex2 = try #require(part.vertexParameter2)
        #expect(abs(vertex1 - 3 * .pi / 4) < 1e-6, "vertex parameter on a is \(vertex1)")
        #expect(abs(vertex2 - 3 * .pi / 4) < 1e-6, "vertex parameter on b is \(vertex2)")
        #expect(
            vertex1 > part.param1Range.first && vertex1 < part.param1Range.last,
            "the vertex parameter lies inside the range it was resolved against")

        let point = try #require(part.point, "a part on two coincident arcs reported no point")
        #expect(abs(point.x - 10 * cos(vertex1)) < 1e-9, "point \(point)")
        #expect(abs(point.y - 10 * sin(vertex1)) < 1e-9, "point \(point)")
        #expect(abs(point.z) < 1e-9, "point \(point)")
        // And where that is: 3pi/4 on a radius-10 circle, upper left.
        let expected = 10 / 2.0.squareRoot()
        #expect(abs(point.x + expected) < 1e-5, "point \(point)")
        #expect(abs(point.y - expected) < 1e-5, "point \(point)")
    }

    /// #3012: a second staggered overlap, so the first is not the only shape pinned.
    ///
    /// `[0, pi/2]` against `[pi/4, 3pi/4]` meet over `[pi/4, pi/2]`, which covers neither arc, so
    /// `MergeSolutions` types it `.vertex` (fixture F of
    /// `Scripts/repro/2994-edgeedge-overlap-type/`). The overlap is an eighth of a circle, and its
    /// midpoint, 3pi/8, is the vertex parameter.
    @Test("A second staggered arc overlap is a vertex part over the whole overlap (#3012)")
    func secondStaggeredArcOverlap() throws {
        let part = try Self.singleArcPart(a: 0...(.pi / 2), b: (.pi / 4)...(3 * .pi / 4))
        #expect(part.type == .vertex)
        #expect(abs(part.param1Range.first - .pi / 4) < 1e-6, "r1 \(part.param1Range)")
        #expect(abs(part.param1Range.last - .pi / 2) < 1e-6, "r1 \(part.param1Range)")
        #expect(abs(part.param2Range.first - .pi / 4) < 1e-6, "r2 \(part.param2Range)")
        #expect(abs(part.param2Range.last - .pi / 2) < 1e-6, "r2 \(part.param2Range)")
        let vertex1 = try #require(part.vertexParameter1)
        let vertex2 = try #require(part.vertexParameter2)
        #expect(abs(vertex1 - 3 * .pi / 8) < 1e-6, "vertex parameter on a is \(vertex1)")
        #expect(abs(vertex2 - 3 * .pi / 8) < 1e-6, "vertex parameter on b is \(vertex2)")
        let point = try #require(part.point)
        #expect(abs(point.x - 10 * cos(3 * .pi / 8)) < 1e-5, "point \(point)")
        #expect(abs(point.y - 10 * sin(3 * .pi / 8)) < 1e-5, "point \(point)")
    }

    /// The companion fixture that makes #2994's rule visible rather than leaving it one
    /// observation.
    ///
    /// Same circle, same `a`, and a `b` that `a` wholly contains: the merged range is then the
    /// whole of `b`, `MergeSolutions` promotes it, and the part is `.edge` over the real overlap
    /// instead of a vertex at its middle.
    ///
    /// The two rows together are the invariant worth pinning: `param1Range` is the true overlap in
    /// **both** cases, whatever the type says, which is what a caller asking "do these overlap,
    /// and over what" should read. `type` is OCCT's directive to a boolean operation, not a
    /// geometric classification, and `BOPAlgo_PaveFiller::PerformEE` discards both of these parts
    /// (the vertex one at its `bIsOnPave` test, the edge one at `HasSameBounds`) and still splits
    /// both fixtures correctly, because `PerformVE` ran first. Measured in
    /// `Scripts/repro/2994-edgeedge-overlap-type/`.
    ///
    /// #3012: before it, that first sentence was false for the `.vertex` row, whose `param1Range`
    /// was a point. It is true now, and this row is the control: an `.edge` part has the same
    /// range and no vertex parameter, so the vertex parameter is what distinguishes the two types,
    /// not the range.
    @Test("A wholly contained arc overlap is an edge part over the overlap (#2994)")
    func containedArcOverlapIsAnEdgePart() throws {
        let part = try Self.singleArcPart(a: 0...(.pi), b: (.pi / 4)...(3 * .pi / 4))
        #expect(part.type == .edge, "b is wholly covered, so #2994's rule says edge")
        // The whole of b's range, reported on a, where a and b share a parameterisation.
        #expect(abs(part.param1Range.first - .pi / 4) < 1e-6, "r1 \(part.param1Range)")
        #expect(abs(part.param1Range.last - 3 * .pi / 4) < 1e-6, "r1 \(part.param1Range)")
        #expect(part.vertexParameter1 == nil, "an edge part has no vertex parameter")
        #expect(part.vertexParameter2 == nil, "an edge part has no vertex parameter")
        // An edge part's point is interior to the overlap and on the circle, not on the chord.
        let point = try #require(part.point)
        #expect(
            abs(simd_length(point) - 10.0) < 1e-6,
            "point \(point) is \(simd_length(point)) from the centre, not 10")
        #expect(abs(point.z) < 1e-9)
    }

    /// #3012: each fact belongs to its own edge, in whichever order the edges are passed.
    ///
    /// A line through the middle of a radius-10 circle crosses it twice, at (0, 10, 0) and
    /// (0, -10, 0). The line is parameterised by length from (0, -20, 0), so the crossings are at
    /// 30 and 10 on it, and the circle by angle, so they are at pi/2 and 3pi/2 on it. Every one of
    /// the four numbers is different, which a crossing of two edges that both start 1 from the
    /// origin cannot give: swapping the edges' ranges or their vertex parameters there changes
    /// nothing, and swapping them here changes everything.
    ///
    /// The circle is the more complex curve, so `IntTools_EdgeEdge::Prepare` swaps the pair
    /// internally when the line comes first (`IntTools_EdgeEdge.cxx:132-146`). Both argument orders
    /// are run so that the swap and the straight path are each pinned to the caller's order: the
    /// first edge's parameters come back as `vertexParameter1` and `param1Range` either way.
    @Test("Each edge's range and vertex parameter stay with that edge (#3012)")
    func eachEdgeKeepsItsOwnRangeAndVertexParameter() throws {
        let line = try #require(Shape.edgeFromPoints(SIMD3(0, -20, 0), SIMD3(0, 20, 0)))
        let circle = try #require(
            Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10))
        let ring = try #require(Shape.edgeFromCurve(circle, u1: 0, u2: 2 * .pi))
        // (parameter on the line, parameter on the circle, y of the crossing)
        let crossings: [(onLine: Double, onCircle: Double, y: Double)] = [
            (30, .pi / 2, 10), (10, 3 * .pi / 2, -10),
        ]

        for lineFirst in [true, false] {
            let parts = try #require(
                lineFirst
                    ? line.edgeEdgeIntersection(with: ring)
                    : ring.edgeEdgeIntersection(with: line))
            let order = lineFirst ? "line first" : "circle first"
            #expect(parts.count == 2, "\(order): \(parts.count) parts, expected the two crossings")
            var seen: Set<Double> = []
            for part in parts {
                #expect(part.type == .vertex, "\(order): a transversal crossing is a vertex")
                let vertex1 = try #require(part.vertexParameter1, "\(order)")
                let vertex2 = try #require(part.vertexParameter2, "\(order)")
                let onLine = lineFirst ? vertex1 : vertex2
                let onCircle = lineFirst ? vertex2 : vertex1
                let found = crossings.first(where: {
                    abs($0.onLine - onLine) < 1e-6 && abs($0.onCircle - onCircle) < 1e-6
                })
                let match = try #require(
                    found,
                    "\(order): vertex parameters (\(vertex1), \(vertex2)) are neither crossing")
                seen.insert(match.y)

                // Each range is on its own edge: it holds its own edge's vertex parameter.
                #expect(
                    part.param1Range.first < vertex1 && vertex1 < part.param1Range.last,
                    "\(order): vertex parameter \(vertex1) outside r1 \(part.param1Range)")
                #expect(
                    part.param2Range.first < vertex2 && vertex2 < part.param2Range.last,
                    "\(order): vertex parameter \(vertex2) outside r2 \(part.param2Range)")
                // And the point is the first edge's curve at the first edge's parameter.
                let point = try #require(part.point, "\(order)")
                #expect(abs(point.x) < 1e-6, "\(order): point \(point)")
                #expect(abs(point.y - match.y) < 1e-6, "\(order): point \(point)")
            }
            #expect(seen.count == 2, "\(order): the two parts are the two different crossings")
        }
    }

    /// #1756: this nested `isEmpty` inside an `if let` on the two edges, so a nil edge passed it.
    ///
    /// Two parallel segments 5 apart do not meet, and `IntTools_EdgeEdge` succeeds and reports
    /// nothing, which is a different answer from failing.
    @Test("Non-intersecting edges return empty array")
    func edgeEdgeNoIntersection() throws {
        let edge1 = try #require(Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(1, 0, 0)))
        let edge2 = try #require(Shape.edgeFromPoints(SIMD3(0, 5, 0), SIMD3(1, 5, 0)))
        let parts = try #require(edge1.edgeEdgeIntersection(with: edge2))
        #expect(parts.isEmpty, "got \(parts.count) parts between two edges 5 apart")
    }

    /// The one part two arcs of the radius-10 circle about the origin share.
    ///
    /// `a` and `b` are the arcs' parameter ranges. Both come from one circle, so they share a
    /// parameterisation and a range on `a` reads as the same range on `b`.
    private static func singleArcPart(
        a: ClosedRange<Double>, b: ClosedRange<Double>
    ) throws -> Shape.CommonPart {
        let circle = try #require(
            Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10))
        let first = try #require(
            Shape.edgeFromCurve(circle, u1: a.lowerBound, u2: a.upperBound))
        let second = try #require(
            Shape.edgeFromCurve(circle, u1: b.lowerBound, u2: b.upperBound))
        let parts = try #require(first.edgeEdgeIntersection(with: second))
        #expect(parts.count == 1, "two arcs of one circle share one part, got \(parts.count)")
        return try #require(parts.first)
    }
}
