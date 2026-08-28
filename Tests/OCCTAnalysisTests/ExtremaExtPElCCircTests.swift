import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtPElC Point-Circle")
struct ExtremaExtPElCCircTests {
    @Test func pointToCircle() {
        let results = ExtremaPointCurve.pointToCircle(
            point: SIMD3(10, 0, 0),
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5
        )
        #expect(results.count > 0)
    }

    @Test func pointOnCircle() {
        let results = ExtremaPointCurve.pointToCircle(
            point: SIMD3(5, 0, 0),
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5
        )
        #expect(results.count > 0)
        if let first = results.first {
            #expect(first.squareDistance < 1e-6)
        }
    }
}
