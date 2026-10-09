import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Direction2D Utilities")
struct Direction2DUtilityTests {
    @Test func normalize() {
        let d = Shape.direction2DNormalized(SIMD2(3, 4))
        let mag = sqrt(d.x * d.x + d.y * d.y)
        #expect(abs(mag - 1.0) < 1e-10)
    }

    @Test func angle() {
        let a = Shape.direction2DAngle(a: SIMD2(1, 0), b: SIMD2(0, 1))
        #expect(abs(a - .pi / 2) < 1e-10)
    }

    @Test func cross() {
        let c = Shape.direction2DCross(a: SIMD2(1, 0), b: SIMD2(0, 1))
        #expect(abs(c - 1.0) < 1e-10)
    }
}
