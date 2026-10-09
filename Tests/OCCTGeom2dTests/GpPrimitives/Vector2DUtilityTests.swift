import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Vector2D Utilities")
struct Vector2DUtilityTests {
    @Test func angle() {
        let a = Shape.vector2DAngle(a: SIMD2(1, 0), b: SIMD2(0, 1))
        #expect(abs(a - .pi / 2) < 1e-10)
    }

    @Test func cross() {
        let c = Shape.vector2DCross(a: SIMD2(1, 0), b: SIMD2(0, 1))
        #expect(abs(c - 1.0) < 1e-10)
    }

    @Test func dot() {
        let d = Shape.vector2DDot(a: SIMD2(3, 4), b: SIMD2(1, 0))
        #expect(abs(d - 3.0) < 1e-10)
    }

    @Test func magnitude() {
        let m = Shape.vector2DMagnitude(SIMD2(3, 4))
        #expect(abs(m - 5.0) < 1e-10)
    }

    @Test func normalize() {
        let n = Shape.vector2DNormalized(SIMD2(3, 4))
        #expect(abs(n.x - 0.6) < 1e-10)
        #expect(abs(n.y - 0.8) < 1e-10)
    }
}
