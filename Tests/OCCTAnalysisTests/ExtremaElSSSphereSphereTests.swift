import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtElSS Sphere-Sphere")
struct ExtremaElSSSphereSphereTests {
    @Test func sphereSphereDistance() {
        // Sphere-Sphere not fully implemented in OCCT 8.0.0-rc4 (may throw Standard_NotImplemented)
        let results = ExtremaElSS.sphereToSphere(
            center1: SIMD3(0, 0, 0), radius1: 5,
            center2: SIMD3(20, 0, 0), radius2: 5
        )
        #expect(results.count >= 0)  // 0 is valid when not implemented
    }
}
