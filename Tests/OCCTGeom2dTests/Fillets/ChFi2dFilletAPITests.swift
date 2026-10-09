import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ChFi2d_FilletAPI Tests")
struct ChFi2dFilletAPITests {
    @Test("fillet between two edges")
    func filletEdges() {
        let e1 = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0))
        let e2 = Shape.edgeFromPoints(SIMD3(10, 0, 0), SIMD3(10, 10, 0))
        if let e1, let e2 {
            let result = Shape.fillet2dEdges(
                edge1: e1, edge2: e2,
                planeNormal: SIMD3(0, 0, 1), radius: 2.0,
                nearPoint: SIMD3(10, 0, 0))
            if let r = result {
                #expect(r.solutionCount >= 1)
            }
        }
    }

    // #1459: OCCTChFi2dFilletEdges used to hardcode the fillet plane's origin to world (0,0,0),
    // ignoring any plane the caller's edges actually lie in. Two edges meeting at (0,0,10), in
    // the z=10 plane (not through the world origin), are the issue's own demonstrating input:
    // the fillet's circle center gets reconstructed via ElSLib::Value/PlaneValue against the
    // wrong (z=0) plane location. Measured directly against the pre-fix bridge (prove-the-test-
    // fails, okf/policies/prove-the-test-fails.md): for this exact input, ChFi2d_AnaFilletAlgo's
    // downstream edge-trimming then fails outright once the reconstructed geometry no longer
    // lines up with the real (z=10) edges, so `Shape.fillet2dEdges` returns nil rather than the
    // issue's predicted "disconnected but reported success" — a broken *and even more visibly*
    // failing result than predicted, not a milder one. With `planeOrigin` threaded through
    // correctly, the fillet succeeds and lands in the plane the edges actually occupy.
    @Test("fillet plane origin off world origin stays connected to the input edges (#1459)")
    func filletPlaneOriginOffWorldOrigin() throws {
        let e1 = try #require(Shape.edgeFromPoints(SIMD3(0, 0, 10), SIMD3(5, 0, 10)))
        let e2 = try #require(Shape.edgeFromPoints(SIMD3(0, 0, 10), SIMD3(0, 5, 10)))

        let result = Shape.fillet2dEdges(
            edge1: e1, edge2: e2,
            planeOrigin: SIMD3(0, 0, 10),
            planeNormal: SIMD3(0, 0, 1),
            radius: 1.0,
            nearPoint: SIMD3(0, 0, 10))
        let r = try #require(result)
        #expect(r.solutionCount >= 1)

        // Every vertex of every returned edge must stay on the z=10 plane the input edges are
        // actually in, not drift to z=0 (the plane the old hardcoded-origin bug would have used).
        let filletVerts = r.filletEdge.vertices()
        #expect(!filletVerts.isEmpty)
        for v in filletVerts {
            #expect(abs(v.z - 10) < 1e-6, "fillet vertex \(v) is not on the z=10 plane")
        }
        for v in r.modifiedEdge1.vertices() {
            #expect(abs(v.z - 10) < 1e-6, "modifiedEdge1 vertex \(v) is not on the z=10 plane")
        }
        for v in r.modifiedEdge2.vertices() {
            #expect(abs(v.z - 10) < 1e-6, "modifiedEdge2 vertex \(v) is not on the z=10 plane")
        }

        // The fillet arc must actually meet the trimmed neighbour edges (a connected result),
        // not sit disconnected at the wrong depth.
        let filletEndpoints = filletVerts
        let neighbourVerts = r.modifiedEdge1.vertices() + r.modifiedEdge2.vertices()
        let connects = filletEndpoints.contains { fp in
            neighbourVerts.contains { nv in simd_distance(fp, nv) < 1e-6 }
        }
        #expect(connects, "fillet edge does not meet either trimmed neighbour edge")
    }
}
