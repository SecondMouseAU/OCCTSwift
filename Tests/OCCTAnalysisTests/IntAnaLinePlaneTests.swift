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
    }
}
