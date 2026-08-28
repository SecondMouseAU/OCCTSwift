import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtPElS Point-Sphere")
struct ExtremaExtPElSSphereTests {
    @Test func pointToSphere() {
        let results = ExtremaPointSurface.pointToSphere(
            point: SIMD3(20, 0, 0),
            center: SIMD3(0, 0, 0), radius: 5
        )
        #expect(results.count > 0)
    }
}
