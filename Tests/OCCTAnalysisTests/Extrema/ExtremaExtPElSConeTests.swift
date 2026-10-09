import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtPElS Point-Cone")
struct ExtremaExtPElSConeTests {
    @Test func pointToCone() {
        let results = ExtremaPointSurface.pointToCone(
            point: SIMD3(20, 0, 0),
            apex: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1),
            semiAngle: .pi / 4, refRadius: 5
        )
        #expect(results.count > 0)
    }
}
