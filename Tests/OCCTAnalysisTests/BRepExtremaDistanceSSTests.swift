import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Expected values are the pinned kernel's answers for the same inputs, measured by
/// `Scripts/repro/766-brepextrema-distancess/probe.mm` (transcript alongside it).
///
/// `Shape.box(width:height:depth:)` is centred, so the unit box spans -0.5...0.5;
/// `Shape.box(origin:...)` puts its corner at `origin`. Before #766 both tests nested every
/// assertion inside `if let` chains and asserted only `distance > 0`, so a bridge returning no
/// vertices, or any positive distance at all, passed.
@Suite("BRepExtrema_DistanceSS")
struct BRepExtremaDistanceSSTests {
    @Test("distance between box vertices")
    func vertexDistance() {
        guard let box1 = Shape.box(width: 1, height: 1, depth: 1),
            let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 1, height: 1, depth: 1)
        else {
            Issue.record("could not build the boxes")
            return
        }
        guard let v1 = box1.subShapes(ofType: .vertex).first,
            let v2 = box2.subShapes(ofType: .vertex).first
        else {
            Issue.record("a box has vertices")
            return
        }
        // Probed: the first vertices are (-0.5, -0.5, 0.5) and (10, 0, 1), so the distance is
        // sqrt(10.5^2 + 0.5^2 + 0.5^2) = sqrt(110.75), and the witness points are the vertices.
        let r = v1.distanceSS(to: v2)
        #expect(r.isDone)
        #expect(abs(r.distance - sqrt(110.75)) < 1e-9, "expected sqrt(110.75), got \(r.distance)")
        #expect(r.solutionCount == 1, "got \(r.solutionCount)")
        #expect(simd_distance(r.point1, SIMD3(-0.5, -0.5, 0.5)) < 1e-12, "p1 got \(r.point1)")
        #expect(simd_distance(r.point2, SIMD3(10, 0, 1)) < 1e-12, "p2 got \(r.point2)")
    }

    @Test("distance between edge and vertex")
    func edgeVertexDistance() {
        // OCCT 8.0's low-level BRepExtrema_DistanceSS deliberately skips
        // edge-vertex pairs whose closest point lands at one of the edge's
        // endpoint-vertices (it expects the caller to pair vertices-with-
        // vertices separately). Use the high-level BRepExtrema_DistShapeShape
        // wrapper (Shape.distance(to:)) which handles all subshape pair
        // combinations including endpoint cases.
        guard let box1 = Shape.box(width: 1, height: 1, depth: 1),
            let box2 = Shape.box(origin: SIMD3(5, 5, 0), width: 1, height: 1, depth: 1)
        else {
            Issue.record("could not build the boxes")
            return
        }
        guard let e = box1.subShapes(ofType: .edge).first,
            let v = box2.subShapes(ofType: .vertex).first
        else {
            Issue.record("a box has edges and vertices")
            return
        }
        guard let r = e.distance(to: v) else {
            Issue.record("edge-vertex distance should resolve via DistShapeShape")
            return
        }
        // Probed: the edge is x = y = -0.5, z in [-0.5, 0.5]; the vertex is (5, 5, 1). The
        // nearest edge point is its z = 0.5 endpoint, the case the comment above describes, at
        // distance sqrt(5.5^2 + 5.5^2 + 0.5^2) = sqrt(60.75).
        #expect(abs(r.distance - sqrt(60.75)) < 1e-9, "expected sqrt(60.75), got \(r.distance)")
        #expect(simd_distance(r.pointOnShape1, SIMD3(-0.5, -0.5, 0.5)) < 1e-9, "p1 got \(r.pointOnShape1)")
        #expect(simd_distance(r.pointOnShape2, SIMD3(5, 5, 1)) < 1e-12, "p2 got \(r.pointOnShape2)")
    }
}
