import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D_Bezier_Properties")
struct Curve2DBezierTests {
    func makeBezier2D() -> Curve2D? {
        // Create a 2D line segment (which is a Bezier of degree 1)
        Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 10))
    }

    @Test func degreeAndPoleCount() {
        if let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 0)]) {
            let bp = c.bezierProperties
            #expect(bp.degree == 2)
            #expect(bp.poleCount == 3)
        }
    }

    @Test func getPole() {
        if let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 0)]) {
            let bp = c.bezierProperties
            let p = bp.pole(at: 1)
            #expect(abs(p.x) < 1e-10)
            #expect(abs(p.y) < 1e-10)
        }
    }

    @Test func setPole() {
        if let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 0)]) {
            let bp = c.bezierProperties
            let ok = bp.setPole(at: 2, point: SIMD2(3, 7))
            #expect(ok)
            let p = bp.pole(at: 2)
            #expect(abs(p.x - 3.0) < 1e-10)
            #expect(abs(p.y - 7.0) < 1e-10)
        }
    }

    @Test func isRational() {
        if let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 0)]) {
            let bp = c.bezierProperties
            #expect(!bp.isRational)
        }
    }

    @Test func resolution() {
        if let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 0)]) {
            let bp = c.bezierProperties
            let r = bp.resolution(tolerance: 0.1)
            #expect(r > 0)
        }
    }
}
