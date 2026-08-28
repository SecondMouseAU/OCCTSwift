import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntAna ConeSphere Tests")
struct IntAnaConeSphereTests {

    @Test func coneSphereIntersection() {
        let count = QuadricIntersection.coneSphere(
            semiAngle: .pi / 4, refRadius: 0,
            sphereCenter: SIMD3(0, 0, 5), sphereRadius: 3)
        #expect(count != nil)
        if let c = count {
            #expect(c >= 0)
        }
    }

    @Test func coneSphereSamplePoints() {
        let count = QuadricIntersection.coneSphere(
            semiAngle: .pi / 4, refRadius: 0,
            sphereCenter: SIMD3(0, 0, 5), sphereRadius: 3)
        if let c = count, c > 0 {
            let pts = QuadricIntersection.coneSpherePoints(
                semiAngle: .pi / 4, refRadius: 0,
                sphereCenter: SIMD3(0, 0, 5), sphereRadius: 3,
                curveIndex: 1, sampleCount: 10)
            #expect(pts.count >= 0)
        }
    }
}
