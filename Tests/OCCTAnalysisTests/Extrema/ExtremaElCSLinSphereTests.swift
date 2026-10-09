import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtElCS Line-Sphere")
struct ExtremaElCSLinSphereTests {
    @Test func lineSphereDistance() {
        let results = ExtremaElCS.lineToSphere(
            linePoint: SIMD3(0, 0, 20), lineDir: SIMD3(1, 0, 0),
            sphereCenter: SIMD3(0, 0, 0), sphereRadius: 5
        )
        #expect(results.count > 0)
    }
}
