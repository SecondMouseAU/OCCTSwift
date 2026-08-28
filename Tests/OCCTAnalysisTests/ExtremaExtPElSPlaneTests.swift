import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtPElS Point-Plane")
struct ExtremaExtPElSPlaneTests {
    @Test func pointToPlane() {
        let results = ExtremaPointSurface.pointToPlane(
            point: SIMD3(0, 0, 10),
            planePoint: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1)
        )
        #expect(results.count > 0)
        if let first = results.first {
            #expect(abs(first.squareDistance - 100) < 0.1)
        }
    }
}
