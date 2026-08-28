import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Quaternion Interpolation")
struct QuaternionInterpolationTests {
    @Test func slerpMidpoint() {
        let q1 = SIMD4<Double>(0, 0, 0, 1)  // identity
        let q2 = SIMD4<Double>(0, 0, sin(.pi / 4), cos(.pi / 4))  // 90 deg about Z
        let mid = MathSolver.quaternionSlerp(from: q1, to: q2, t: 0.5)
        #expect(abs(mid.w) > 0.9)  // close to 45 deg
    }

    @Test func nlerpEndpoints() {
        let q1 = SIMD4<Double>(0, 0, 0, 1)
        let q2 = SIMD4<Double>(0, 0, sin(.pi / 4), cos(.pi / 4))
        let r0 = MathSolver.quaternionNlerp(from: q1, to: q2, t: 0.0)
        #expect(abs(r0.w - 1.0) < 0.1)
    }

    @Test func transformInterpolate() {
        let from = (translation: SIMD3<Double>(0, 0, 0), quaternion: SIMD4<Double>(0, 0, 0, 1))
        let to = (translation: SIMD3<Double>(10, 0, 0), quaternion: SIMD4<Double>(0, 0, 0, 1))
        let mid = MathSolver.transformInterpolate(from: from, to: to, t: 0.5)
        #expect(abs(mid.translation.x - 5.0) < 0.5)
    }
}

