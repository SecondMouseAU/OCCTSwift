import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2dEval — Logarithmic Spiral")
struct Geom2dEvalLogSpiralTests {

    @Test func logSpiralD0AtZero() throws {
        let p = try #require(Geom2dEval.logarithmicSpiralD0(scale: 1.0, growthExponent: 0.2, u: 0.0))
        // At t=0: a*exp(0)*cos(0) = a = 1
        #expect(abs(p.x - 1.0) < 1e-10)
        #expect(abs(p.y) < 1e-10)
    }

    @Test func logSpiralGrows() throws {
        let p1 = try #require(
            Geom2dEval.logarithmicSpiralD0(scale: 1.0, growthExponent: 0.2, u: 0.0))
        let p2 = try #require(
            Geom2dEval.logarithmicSpiralD0(scale: 1.0, growthExponent: 0.2, u: 10.0))
        let r1 = sqrt(p1.x * p1.x + p1.y * p1.y)
        let r2 = sqrt(p2.x * p2.x + p2.y * p2.y)
        #expect(r2 > r1)  // spiral grows
        // #1979: growth alone passed a wrong spiral. a e^(b u) (cos u, sin u) at u = 10.
        #expect(simd_distance(p2, SIMD2(-6.19994659936, -4.01980250736)) < 1e-9)
    }

    @Test func logSpiralD1() throws {
        let r = try #require(Geom2dEval.logarithmicSpiralD1(scale: 1.0, growthExponent: 0.2, u: 1.0))
        // #1979: `speed > 0` passed any derivative (Geom2dEval_LogarithmicSpiralCurve,
        // Scripts/repro/766-geom2d-eval-involute-logspiral/).
        #expect(simd_distance(r.point, SIMD2(0.659926726628, 1.02777498176)) < 1e-9)
        #expect(simd_distance(r.d1, SIMD2(-0.895789636431, 0.865481722979)) < 1e-9)
    }
}
