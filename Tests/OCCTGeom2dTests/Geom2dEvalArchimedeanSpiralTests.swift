import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2dEval — Archimedean Spiral")
struct Geom2dEvalArchimedeanSpiralTests {

    @Test func spiralD0AtZero() {
        let p = Geom2dEval.archimedeanSpiralD0(initialRadius: 0.0, growthRate: 1.0, u: 0.0)
        #expect(abs(p.x) < 1e-10)
        #expect(abs(p.y) < 1e-10)
    }

    @Test func spiralD0AtTwoPi() {
        // At t=2*pi: r = 0 + 1*2*pi, x = r*cos(2pi) = 2pi
        let p = Geom2dEval.archimedeanSpiralD0(initialRadius: 0.0, growthRate: 1.0, u: 2.0 * .pi)
        #expect(abs(p.x - 2.0 * .pi) < 1e-6)
        #expect(abs(p.y) < 1e-6)
    }

    @Test func spiralD1() {
        let r = Geom2dEval.archimedeanSpiralD1(initialRadius: 1.0, growthRate: 0.5, u: 0.0)
        // At t=0 with a=1, b=0.5: point = (1, 0)
        #expect(abs(r.point.x - 1.0) < 1e-10)
        // d1: check it returns non-zero derivative
        let speed = sqrt(r.d1.x * r.d1.x + r.d1.y * r.d1.y)
        #expect(speed > 0)
    }

    @Test func spiralWithInitialRadius() {
        let p = Geom2dEval.archimedeanSpiralD0(initialRadius: 2.0, growthRate: 1.0, u: 0.0)
        #expect(abs(p.x - 2.0) < 1e-10)  // (a+b*0)*cos(0) = a
    }
}
