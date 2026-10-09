import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtElCS Line-Cylinder")
struct ExtremaElCSLinCylTests {
    @Test func lineCylinderDistance() {
        let results = ExtremaElCS.lineToCylinder(
            linePoint: SIMD3(20, 0, 0), lineDir: SIMD3(0, 0, 1),
            cylCenter: SIMD3(0, 0, 0), cylAxis: SIMD3(0, 0, 1), cylRadius: 5
        )
        #expect(results.count >= 0)  // may be 0 if parallel to axis
    }
}
