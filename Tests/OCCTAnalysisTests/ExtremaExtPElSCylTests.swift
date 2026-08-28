import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtPElS Point-Cylinder")
struct ExtremaExtPElSCylTests {
    @Test func pointToCylinder() {
        let results = ExtremaPointSurface.pointToCylinder(
            point: SIMD3(20, 0, 0),
            center: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5
        )
        #expect(results.count > 0)
    }
}
