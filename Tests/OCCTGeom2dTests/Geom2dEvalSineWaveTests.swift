import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2dEval — 2D Sine Wave")
struct Geom2dEvalSineWaveTests {

    @Test func sineWave2DD0AtZero() {
        let p = Geom2dEval.sineWaveD0(amplitude: 1.5, omega: 2.0, phase: 0.0, u: 0.0)
        #expect(abs(p.x) < 1e-10)
        #expect(abs(p.y) < 1e-10)
    }

    @Test func sineWave2DD0Peak() {
        let omega = 2.0
        let t = Double.pi / (2.0 * omega)
        let p = Geom2dEval.sineWaveD0(amplitude: 1.5, omega: omega, phase: 0.0, u: t)
        #expect(abs(p.y - 1.5) < 1e-6)  // A*sin(pi/2) = A
    }

    @Test func sineWave2DD1() {
        let r = Geom2dEval.sineWaveD1(amplitude: 1.5, omega: 2.0, phase: 0.0, u: 0.0)
        #expect(abs(r.d1.x - 1.0) < 1e-10)  // dx/dt = 1
        #expect(abs(r.d1.y - 3.0) < 1e-6)  // A*omega*cos(0) = 1.5*2 = 3
    }
}
