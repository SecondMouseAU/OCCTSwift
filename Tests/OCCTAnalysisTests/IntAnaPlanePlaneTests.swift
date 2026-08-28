import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntAna PlanePlane Tests")
struct IntAnaPlanePlaneTests {

    @Test func planePlaneIntersection() {
        let r = IntAna.planePlane(
            p1Origin: SIMD3(0, 0, 0), p1Normal: SIMD3(0, 0, 1),
            p2Origin: SIMD3(0, 0, 0), p2Normal: SIMD3(0, 1, 0))
        #expect(r.count >= 1)
    }

    @Test func planePlaneLine() {
        let r = IntAna.planePlane(
            p1Origin: SIMD3(0, 0, 0), p1Normal: SIMD3(0, 0, 1),
            p2Origin: SIMD3(0, 0, 0), p2Normal: SIMD3(0, 1, 0))
        if r.count >= 1 {
            let dir = r.lines[0].direction
            let len = sqrt(dir.x * dir.x + dir.y * dir.y + dir.z * dir.z)
            #expect(abs(len - 1.0) < 1e-6)
        }
    }
}
