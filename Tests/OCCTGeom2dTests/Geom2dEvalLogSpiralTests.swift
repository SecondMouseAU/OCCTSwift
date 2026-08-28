import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2dEval — Logarithmic Spiral")
struct Geom2dEvalLogSpiralTests {

    @Test func logSpiralD0AtZero() {
        let p = Geom2dEval.logarithmicSpiralD0(scale: 1.0, growthExponent: 0.2, u: 0.0)
        // At t=0: a*exp(0)*cos(0) = a = 1
        #expect(abs(p.x - 1.0) < 1e-10)
        #expect(abs(p.y) < 1e-10)
    }

    @Test func logSpiralGrows() {
        let p1 = Geom2dEval.logarithmicSpiralD0(scale: 1.0, growthExponent: 0.2, u: 0.0)
        let p2 = Geom2dEval.logarithmicSpiralD0(scale: 1.0, growthExponent: 0.2, u: 10.0)
        let r1 = sqrt(p1.x * p1.x + p1.y * p1.y)
        let r2 = sqrt(p2.x * p2.x + p2.y * p2.y)
        #expect(r2 > r1)  // spiral grows
    }

    @Test func logSpiralD1() {
        let r = Geom2dEval.logarithmicSpiralD1(scale: 1.0, growthExponent: 0.2, u: 1.0)
        let speed = sqrt(r.d1.x * r.d1.x + r.d1.y * r.d1.y)
        #expect(speed > 0)
    }
}
