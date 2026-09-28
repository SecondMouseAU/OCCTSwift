import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntTools_EdgeEdge Tests")
struct IntToolsEdgeEdgeTests {
    @Test("Intersecting edges produce vertex common part")
    func edgeEdgeVertex() {
        // Two edges crossing at origin: X-axis and Y-axis
        let e1 = Shape.edgeFromPoints(SIMD3(-1, 0, 0), SIMD3(1, 0, 0))
        let e2 = Shape.edgeFromPoints(SIMD3(0, -1, 0), SIMD3(0, 1, 0))
        if let edge1 = e1, let edge2 = e2 {
            let parts = edge1.edgeEdgeIntersection(with: edge2)
            #expect(parts != nil)
            if let p = parts {
                #expect(p.count >= 1)
                if let first = p.first {
                    #expect(first.type == .vertex)
                    if let point = first.point {
                        #expect(abs(point.x) < 0.1)
                        #expect(abs(point.y) < 0.1)
                    } else {
                        Issue.record("a vertex part reported no point")
                    }
                }
            }
        }
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
    func edgeEdgeOverlap() {
        let e1 = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(2, 0, 0))
        let e2 = Shape.edgeFromPoints(SIMD3(1, 0, 0), SIMD3(3, 0, 0))
        if let edge1 = e1, let edge2 = e2 {
            let parts = edge1.edgeEdgeIntersection(with: edge2)
            #expect(parts != nil)
            if let p = parts {
                #expect(p.count >= 1)
                if let first = p.first {
                    #expect(first.type == .edge)
                    #expect(first.param1Range.first == 1.0)
                    #expect(first.param1Range.last == 2.0)
                    if let point = first.point {
                        #expect(point.x > 1.0, "point x = \(point.x), outside the overlap")
                        #expect(point.x < 2.0, "point x = \(point.x), outside the overlap")
                        #expect(abs(point.y) < 1e-12)
                        #expect(abs(point.z) < 1e-12)
                    } else {
                        Issue.record("an edge part over a real overlap reported no point")
                    }
                }
            }
        }
    }

    /// #2251, on a curve, where a fabricated point and a real one are far apart.
    ///
    /// Two arcs of one radius-10 circle, [0, pi] and [pi/2, 3pi/2], meet over [pi/2, pi]. The point
    /// reported has to lie on the circle, so it is 10 from the centre; the origin, which the
    /// unset bounding points produced, is 0 from it.
    @Test("An overlap on a circular arc reports a point on the arc (#2251)")
    func arcOverlapPointLiesOnTheArc() throws {
        let circle = try #require(
            Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10))
        let a = try #require(Shape.edgeFromCurve(circle, u1: 0, u2: .pi))
        let b = try #require(Shape.edgeFromCurve(circle, u1: .pi / 2, u2: 3 * .pi / 2))

        let parts = try #require(a.edgeEdgeIntersection(with: b))
        #expect(parts.count >= 1)
        for part in parts {
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

    @Test("Non-intersecting edges return empty array")
    func edgeEdgeNoIntersection() {
        let e1 = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(1, 0, 0))
        let e2 = Shape.edgeFromPoints(SIMD3(0, 5, 0), SIMD3(1, 5, 0))
        if let edge1 = e1, let edge2 = e2 {
            let parts = edge1.edgeEdgeIntersection(with: edge2)
            #expect(parts != nil)
            if let p = parts {
                #expect(p.isEmpty)
            }
        }
    }
}
