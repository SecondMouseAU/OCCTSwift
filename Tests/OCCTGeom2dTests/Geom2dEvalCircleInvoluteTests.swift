import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2dEval — Circle Involute")
struct Geom2dEvalCircleInvoluteTests {

    @Test func involuteD0AtZero() {
        let p = Geom2dEval.circleInvoluteD0(radius: 2.0, u: 0.0)
        // C(0) = R*(cos(0)+0*sin(0), sin(0)-0*cos(0)) = (R, 0)
        #expect(abs(p.x - 2.0) < 1e-10)
        #expect(abs(p.y) < 1e-10)
    }

    @Test func involuteGrows() {
        let p1 = Geom2dEval.circleInvoluteD0(radius: 2.0, u: 1.0)
        let p2 = Geom2dEval.circleInvoluteD0(radius: 2.0, u: 5.0)
        let r1 = sqrt(p1.x * p1.x + p1.y * p1.y)
        let r2 = sqrt(p2.x * p2.x + p2.y * p2.y)
        #expect(r2 > r1)
    }

    @Test func involuteD1() {
        let r = Geom2dEval.circleInvoluteD1(radius: 2.0, u: 1.0)
        let speed = sqrt(r.d1.x * r.d1.x + r.d1.y * r.d1.y)
        #expect(speed > 0)  // |D1(t)| = R*t, at t=1 = 2
    }
}
