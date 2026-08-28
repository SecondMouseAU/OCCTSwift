import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtElCS Line-Plane")
struct ExtremaElCSLinPlaneTests {
    @Test func parallelLinePlane() {
        let r = ExtremaElCS.lineToPlane(
            linePoint: SIMD3(0, 0, 10), lineDir: SIMD3(1, 0, 0),
            planePoint: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1)
        )
        #expect(r.isParallel)
        if let first = r.results.first {
            #expect(abs(first.squareDistance - 100) < 0.1)
        }
    }

    @Test func intersectingLinePlane() {
        let r = ExtremaElCS.lineToPlane(
            linePoint: SIMD3(0, 0, 10), lineDir: SIMD3(0, 0, -1),
            planePoint: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1)
        )
        // Not parallel since line goes through the plane
        #expect(!r.isParallel)
    }
}
