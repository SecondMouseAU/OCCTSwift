import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtPElC Point-Ellipse")
struct ExtremaExtPElCElipsTests {
    @Test func pointToEllipse() {
        let results = ExtremaPointCurve.pointToEllipse(
            point: SIMD3(10, 0, 0),
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), xDir: SIMD3(1, 0, 0),
            majorRadius: 5, minorRadius: 3
        )
        #expect(results.count > 0)
    }
}
