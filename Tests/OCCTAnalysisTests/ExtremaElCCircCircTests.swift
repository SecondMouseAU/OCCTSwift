import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtElC Circle-Circle")
struct ExtremaElCCircCircTests {
    @Test func coplanarCircles() {
        let results = ExtremaElC.circleToCircle(
            center1: SIMD3(0, 0, 0), normal1: SIMD3(0, 0, 1), radius1: 5,
            center2: SIMD3(20, 0, 0), normal2: SIMD3(0, 0, 1), radius2: 5
        )
        #expect(results.count > 0)
    }
}
