import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntAna LineSphere Tests")
struct IntAnaLineSphereTests {

    @Test func lineThroughSphere() {
        let r = IntAna.lineSphere(
            lineOrigin: SIMD3(-10, 0, 0), lineDir: SIMD3(1, 0, 0),
            sphereCenter: SIMD3(0, 0, 0), sphereAxis: SIMD3(0, 0, 1), radius: 5)
        #expect(r.points.count == 2)
    }

    @Test func lineMissesSphere() {
        let r = IntAna.lineSphere(
            lineOrigin: SIMD3(0, 100, 0), lineDir: SIMD3(1, 0, 0),
            sphereCenter: SIMD3(0, 0, 0), sphereAxis: SIMD3(0, 0, 1), radius: 5)
        #expect(r.points.count == 0)
    }
}
