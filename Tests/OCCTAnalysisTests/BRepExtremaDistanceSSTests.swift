import Foundation
import Testing
import simd

@testable import OCCTSwift

/// `Shape.box(width:height:depth:)` is centred, so the unit box spans -0.5...0.5;
/// `Shape.box(origin:...)` puts its corner at `origin`.
///
/// Both tests used to nest every assertion inside an `if let` chain and assert only
/// `distance > 0`, so a bridge returning no vertices at all, or any positive distance, passed
/// (#1793, #1794). The fixtures are now required, and the distances are derived from the two
/// shapes rather than read off a run: the witness points are asserted alongside, and the
/// distance is asserted to be the distance between them, so no pair of wrong points can agree
/// with a right distance.
@Suite("BRepExtrema_DistanceSS")
struct BRepExtremaDistanceSSTests {
    /// #1793. `BRepExtrema_DistanceSS` on a vertex pair has one answer and one solution: the two
    /// points themselves.
    @Test("distance between box vertices")
    func vertexDistance() throws {
        let box1 = try #require(Shape.box(width: 1, height: 1, depth: 1))
        let box2 = try #require(Shape.box(origin: SIMD3(10, 0, 0), width: 1, height: 1, depth: 1))
        let v1 = try #require(box1.subShapes(ofType: .vertex).first)
        let v2 = try #require(box2.subShapes(ofType: .vertex).first)
        let p1 = v1.vertexPoint
        let p2 = v2.vertexPoint

        let r = v1.distanceSS(to: v2)
        #expect(r.isDone)
        #expect(r.solutionCount == 1, "got \(r.solutionCount)")
        // The only extremum between two vertices is the pair of vertices.
        #expect(simd_distance(r.point1, p1) < 1e-12, "p1 got \(r.point1), vertex is \(p1)")
        #expect(simd_distance(r.point2, p2) < 1e-12, "p2 got \(r.point2), vertex is \(p2)")
        #expect(
            abs(r.distance - simd_distance(p1, p2)) < 1e-12,
            "expected \(simd_distance(p1, p2)), got \(r.distance)")
        // ...and the two boxes are 9 apart along x, so that distance is sqrt(110.75), not some
        // smaller number a wrong vertex pairing would give.
        #expect(abs(r.distance - (110.75 as Double).squareRoot()) < 1e-9, "got \(r.distance)")
    }

    /// #1794. OCCT 8.0's low-level `BRepExtrema_DistanceSS` deliberately skips edge-vertex pairs
    /// whose closest point lands at one of the edge's endpoint-vertices (it expects the caller to
    /// pair vertices with vertices separately). This uses the high-level
    /// `BRepExtrema_DistShapeShape` wrapper, `Shape.distance(to:)`, which handles every subshape
    /// pair combination including the endpoint case, and the fixture is exactly that case.
    @Test("distance between edge and vertex")
    func edgeVertexDistance() throws {
        let box1 = try #require(Shape.box(width: 1, height: 1, depth: 1))
        let box2 = try #require(Shape.box(origin: SIMD3(5, 5, 0), width: 1, height: 1, depth: 1))
        let e = try #require(box1.subShapes(ofType: .edge).first)
        let v = try #require(box2.subShapes(ofType: .vertex).first)
        let target = v.vertexPoint
        let ends = e.subShapes(ofType: .vertex).map(\.vertexPoint)
        #expect(ends.count == 2, "an edge has two vertices, got \(ends.count)")

        let r = try #require(e.distance(to: v), "edge-vertex distance resolves via DistShapeShape")
        #expect(simd_distance(r.pointOnShape2, target) < 1e-12, "p2 got \(r.pointOnShape2)")
        // The nearest point on the edge is one of its own endpoints, which is what makes this the
        // case the low-level algorithm skips.
        let nearestEnd = ends.min { simd_distance($0, target) < simd_distance($1, target) }
        if let nearestEnd {
            #expect(
                simd_distance(r.pointOnShape1, nearestEnd) < 1e-9,
                "p1 got \(r.pointOnShape1), nearest endpoint is \(nearestEnd)")
            #expect(
                abs(r.distance - simd_distance(nearestEnd, target)) < 1e-9,
                "expected \(simd_distance(nearestEnd, target)), got \(r.distance)")
        }
        // That endpoint is (-0.5, -0.5, 0.5) and the vertex is (5, 5, 1), so the answer is
        // sqrt(5.5^2 + 5.5^2 + 0.5^2) = sqrt(60.75).
        #expect(abs(r.distance - (60.75 as Double).squareRoot()) < 1e-9, "got \(r.distance)")
    }
}
