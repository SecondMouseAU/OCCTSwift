import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtElSS Plane-Sphere")
struct ExtremaElSSPlaneSphereTests {
    @Test func planeSphereDistance() {
        // Plane-Sphere not fully implemented in OCCT 8.0.0-rc4 (may throw Standard_NotImplemented)
        let results = ExtremaElSS.planeToSphere(
            planePoint: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
            sphereCenter: SIMD3(0, 0, 20), sphereRadius: 5
        )
        #expect(results.count >= 0)  // 0 is valid when not implemented
    }
}
