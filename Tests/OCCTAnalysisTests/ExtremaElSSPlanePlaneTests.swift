import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtElSS Plane-Plane")
struct ExtremaElSSPlanePlaneTests {
    @Test func parallelPlanes() {
        let r = ExtremaElSS.planeToPlane(
            plane1Point: SIMD3(0, 0, 0), plane1Normal: SIMD3(0, 0, 1),
            plane2Point: SIMD3(0, 0, 10), plane2Normal: SIMD3(0, 0, 1)
        )
        #expect(r.isParallel)
        if let first = r.results.first {
            #expect(abs(first.squareDistance - 100) < 0.1)
        }
    }

    @Test func intersectingPlanes() {
        let r = ExtremaElSS.planeToPlane(
            plane1Point: SIMD3(0, 0, 0), plane1Normal: SIMD3(0, 0, 1),
            plane2Point: SIMD3(0, 0, 0), plane2Normal: SIMD3(1, 0, 0)
        )
        #expect(!r.isParallel)
    }
}
