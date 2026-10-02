import Foundation
import Testing
import simd

@testable import OCCTSwift

/// The fixtures are required rather than `if let`-wrapped: a nil edge used to skip every
/// assertion and pass (#1754, #1756). The counts, parameter ranges and points are what
/// `IntTools_EdgeEdge` reports for these inputs, each derivable from the two edges rather than
/// read off a run.
@Suite("IntTools_EdgeEdge Tests")
struct IntToolsEdgeEdgeTests {
    /// #1754: this read `type` and a 0.1-wide box round the origin, with every assertion inside
    /// an `if let` on the two edges.
    ///
    /// The X-axis edge and the Y-axis edge cross once, at the origin. Each is parameterised by
    /// length from its own start, and each start is 1 from the origin, so the crossing is at
    /// parameter 1 on both.
    @Test("Intersecting edges produce vertex common part")
    func edgeEdgeVertex() throws {
        let edge1 = try #require(Shape.edgeFromPoints(SIMD3(-1, 0, 0), SIMD3(1, 0, 0)))
        let edge2 = try #require(Shape.edgeFromPoints(SIMD3(0, -1, 0), SIMD3(0, 1, 0)))
        let parts = try #require(edge1.edgeEdgeIntersection(with: edge2))
        #expect(parts.count == 1)
        guard let first = parts.first else {
            Issue.record("two crossing edges have a common part")
            return
        }
        #expect(first.type == .vertex)
        #expect(abs(first.param1Range.first - 1) < 1e-6, "r1 \(first.param1Range)")
        #expect(abs(first.param2Range.first - 1) < 1e-6, "r2 \(first.param2Range)")
        guard let point = first.point else {
            Issue.record("a vertex part reported no point")
            return
        }
        #expect(simd_length(point) < 1e-6, "point \(point) is not the origin")
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
    @Test("Overlapping collinear edges produce edge common part")
    func edgeEdgeOverlap() throws {
        let edge1 = try #require(Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(2, 0, 0)))
        let edge2 = try #require(Shape.edgeFromPoints(SIMD3(1, 0, 0), SIMD3(3, 0, 0)))
        let parts = try #require(edge1.edgeEdgeIntersection(with: edge2))
        #expect(parts.count == 1)
        guard let first = parts.first else {
            Issue.record("two overlapping edges have a common part")
            return
        }
        #expect(first.type == .edge)
        #expect(first.param1Range.first == 1.0)
        #expect(first.param1Range.last == 2.0)
        // The same overlap on the second edge, which starts at x = 1, is [0, 1].
        #expect(abs(first.param2Range.first) < 1e-9, "r2 \(first.param2Range)")
        #expect(abs(first.param2Range.last - 1) < 1e-9, "r2 \(first.param2Range)")
        guard let point = first.point else {
            Issue.record("an edge part over a real overlap reported no point")
            return
        }
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
    /// `type` is deliberately not asserted. Measured on the pinned kernel, this fixture comes back
    /// as a single **vertex** part at 3pi/4, the midpoint of the overlap, while the same two arcs
    /// with one contained in the other ([0, pi] against [pi/4, 3pi/4]) come back as an **edge**
    /// part over the whole overlap. `fillCommonPart` passes `IntTools_CommonPrt::Type()` through
    /// unchanged, so that difference is the kernel's; it is recorded in #2994 and pinning either
    /// answer here would pin whichever of the two turns out to be wrong.
    @Test("An overlap on a circular arc reports a point on the arc (#2251)")
    func arcOverlapPointLiesOnTheArc() throws {
        let circle = try #require(
            Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10))
        let a = try #require(Shape.edgeFromCurve(circle, u1: 0, u2: .pi))
        let b = try #require(Shape.edgeFromCurve(circle, u1: .pi / 2, u2: 3 * .pi / 2))

        let parts = try #require(a.edgeEdgeIntersection(with: b))
        #expect(parts.count == 1)
        for part in parts {
            // Whatever the part's type, it has to sit inside the overlap, [pi/2, pi] on a.
            #expect(part.param1Range.first >= .pi / 2 - 1e-6, "r1 \(part.param1Range)")
            #expect(part.param1Range.last <= .pi + 1e-6, "r1 \(part.param1Range)")
            guard let point = part.point else {
                Issue.record("a part on two coincident arcs reported no point")
                continue
            }
            #expect(
                abs(simd_length(point) - 10.0) < 1e-6,
                "point \(point) is \(simd_length(point)) from the centre, not 10")
            #expect(abs(point.z) < 1e-9)
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
}
