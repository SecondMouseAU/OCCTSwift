import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtPElC Point-Parabola")
struct ExtremaExtPElCParabTests {
    @Test func pointToParabola() {
        let results = ExtremaPointCurve.pointToParabola(
            point: SIMD3(0, 10, 0),
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), xDir: SIMD3(1, 0, 0),
            focal: 2
        )
        #expect(results.count > 0)
    }
}
