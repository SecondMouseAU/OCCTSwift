import Foundation
import Testing

@testable import OCCTSwift

@Suite("GeomEval, 3D Sine Wave Curve")
struct GeomEvalSineWaveTests {

    @Test func sineWaveD0AtZero() {
        let p = GeomEval.sineWaveD0(amplitude: 2.0, omega: 3.0, phase: 0.0, u: 0.0)
        #expect(abs(p.x) < 1e-10)
        #expect(abs(p.y) < 1e-10)
    }

    @Test func sineWaveD0AtPiOver2() {
        // At t=pi/(2*omega): sin(omega*t) = sin(pi/2) = 1
        let omega = 3.0
        let t = .pi / (2.0 * omega)
        let p = GeomEval.sineWaveD0(amplitude: 2.0, omega: omega, phase: 0.0, u: t)
        #expect(abs(p.x - t) < 1e-10)
        #expect(abs(p.y - 2.0) < 1e-6)  // A*sin(pi/2) = A
    }

    @Test func sineWaveD1() {
        let r = GeomEval.sineWaveD1(amplitude: 2.0, omega: 3.0, phase: 0.0, u: 0.0)
        // d1 at t=0: dx/dt = 1, dy/dt = A*omega*cos(0) = A*omega
        #expect(abs(r.d1.x - 1.0) < 1e-10)
        #expect(abs(r.d1.y - 6.0) < 1e-6)  // 2*3 = 6
    }

    @Test func sineWaveCurveCreate() {
        let curve = Curve3D.sineWave(amplitude: 1.0, omega: 2.0)
        #expect(curve != nil)
    }

    @Test func sineWaveWithPhase() {
        let p = GeomEval.sineWaveD0(amplitude: 1.0, omega: 1.0, phase: .pi / 2.0, u: 0.0)
        #expect(abs(p.y - 1.0) < 1e-6)  // sin(pi/2) = 1
    }
}
