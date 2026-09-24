import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2dEval — Circle Involute")
struct Geom2dEvalCircleInvoluteTests {

    @Test func involuteD0AtZero() throws {
        let p = try #require(Geom2dEval.circleInvoluteD0(radius: 2.0, u: 0.0))
        // C(0) = R*(cos(0)+0*sin(0), sin(0)-0*cos(0)) = (R, 0)
        #expect(abs(p.x - 2.0) < 1e-10)
        #expect(abs(p.y) < 1e-10)
    }

    @Test func involuteGrows() throws {
        let p1 = try #require(Geom2dEval.circleInvoluteD0(radius: 2.0, u: 1.0))
        let p2 = try #require(Geom2dEval.circleInvoluteD0(radius: 2.0, u: 5.0))
        let r1 = sqrt(p1.x * p1.x + p1.y * p1.y)
        let r2 = sqrt(p2.x * p2.x + p2.y * p2.y)
        #expect(r2 > r1)
        // #1979: `r2 > r1` passed any growing curve. Pinned to Geom2dEval_CircleInvoluteCurve.
        #expect(simd_distance(p1, SIMD2(2.76354658135, 0.60233735788)) < 1e-9)
        #expect(simd_distance(p2, SIMD2(-9.0219183757, -4.75447040396)) < 1e-9)
    }

    @Test func involuteD1() throws {
        let r = try #require(Geom2dEval.circleInvoluteD1(radius: 2.0, u: 1.0))
        let speed = sqrt(r.d1.x * r.d1.x + r.d1.y * r.d1.y)
        #expect(abs(speed - 2) < 1e-9)  // |D1(t)| = R*t, at t=1 = 2 (#1979: was `speed > 0`)
        #expect(simd_distance(r.d1, SIMD2(1.08060461174, 1.68294196962)) < 1e-9)
    }
}
