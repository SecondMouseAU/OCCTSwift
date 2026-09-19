import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntAna LinePlane Tests")
struct IntAnaLinePlaneTests {

    @Test func linePlaneIntersection() {
        let r = IntAna.linePlane(
            lineOrigin: SIMD3(0, 0, -5), lineDir: SIMD3(0, 0, 1),
            planeOrigin: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1))
        #expect(r.points.count == 1)
        if r.points.count == 1 {
            #expect(abs(r.points[0].z) < 1e-10)
        }
    }

    @Test func parallelLineAndPlane() {
        let r = IntAna.linePlane(
            lineOrigin: SIMD3(0, 0, 5), lineDir: SIMD3(1, 0, 0),
            planeOrigin: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1))
        #expect(r.isParallel)
        // Parallel and disjoint (the line sits at z == 5, the plane at z == 0): not embedded.
        #expect(!r.isInQuadric)
    }

    // #1582: a line lying entirely within the plane and a line merely parallel to and disjoint
    // from it (`parallelLineAndPlane` above) both report `isParallel == true` with empty
    // `points`/`params` — geometrically opposite outcomes that were indistinguishable before
    // `isInQuadric` was surfaced. Same direction/plane as `parallelLineAndPlane`, but the line's
    // origin sits ON the plane (z == 0) rather than offset from it.
    @Test func embeddedLineLiesInPlane() {
        let r = IntAna.linePlane(
            lineOrigin: SIMD3(1, 2, 0), lineDir: SIMD3(1, 0, 0),
            planeOrigin: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1))
        #expect(r.isParallel)
        #expect(r.points.isEmpty)
        #expect(r.params.isEmpty)
        #expect(r.isInQuadric)
    }
}
