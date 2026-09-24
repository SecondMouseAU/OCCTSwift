import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2dEval — Archimedean Spiral")
struct Geom2dEvalArchimedeanSpiralTests {

    @Test func spiralD0AtZero() throws {
        let p = try #require(
            Geom2dEval.archimedeanSpiralD0(initialRadius: 0.0, growthRate: 1.0, u: 0.0))
        #expect(abs(p.x) < 1e-10)
        #expect(abs(p.y) < 1e-10)
    }

    @Test func spiralD0AtTwoPi() throws {
        // At t=2*pi: r = 0 + 1*2*pi, x = r*cos(2pi) = 2pi
        let p = try #require(
            Geom2dEval.archimedeanSpiralD0(initialRadius: 0.0, growthRate: 1.0, u: 2.0 * .pi))
        #expect(abs(p.x - 2.0 * .pi) < 1e-6)
        #expect(abs(p.y) < 1e-6)
    }

    @Test func spiralD1() throws {
        let r = try #require(
            Geom2dEval.archimedeanSpiralD1(initialRadius: 1.0, growthRate: 0.5, u: 0.0))
        // At t=0 with a=1, b=0.5: point = (1, 0)
        #expect(abs(r.point.x - 1.0) < 1e-10)
        // #1979: `speed > 0` passed any derivative. D1 at u = 0 is (b, a) = (0.5, 1)
        // (Geom2dEval_ArchimedeanSpiralCurve; Scripts/repro/766-geom2d-gtrsf-circle-ellipse-spiral/).
        #expect(simd_distance(r.d1, SIMD2(0.5, 1)) < 1e-12)
    }

    @Test func spiralWithInitialRadius() throws {
        let p = try #require(
            Geom2dEval.archimedeanSpiralD0(initialRadius: 2.0, growthRate: 1.0, u: 0.0))
        #expect(abs(p.x - 2.0) < 1e-10)  // (a+b*0)*cos(0) = a
    }
}
