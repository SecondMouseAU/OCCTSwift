import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntAna PlaneSphere Tests")
struct IntAnaPlaneSphereTests {

    @Test func planeSphereIntersection() {
        let r = IntAna.planeSphere(
            planeOrigin: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
            sphereCenter: SIMD3(0, 0, 0), sphereAxis: SIMD3(0, 0, 1),
            radius: 5.0)
        #expect(r.count >= 1)
    }
}
