import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtPElS Point-Torus")
struct ExtremaExtPElSTorusTests {
    @Test func pointToTorus() {
        let results = ExtremaPointSurface.pointToTorus(
            point: SIMD3(20, 0, 0),
            center: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1),
            majorRadius: 10, minorRadius: 3
        )
        #expect(results.count > 0)
    }
}
