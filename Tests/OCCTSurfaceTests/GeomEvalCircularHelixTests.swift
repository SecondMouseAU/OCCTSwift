import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.130.0 Tests

@Suite("GeomEval, Circular Helix Curve")
struct GeomEvalCircularHelixTests {

    @Test func helixD0AtZero() {
        let p = GeomEval.circularHelixD0(radius: 5.0, pitch: 10.0, u: 0.0)
        #expect(abs(p.x - 5.0) < 1e-10)
        #expect(abs(p.y) < 1e-10)
        #expect(abs(p.z) < 1e-10)
    }

    @Test func helixD0AtPi() {
        let p = GeomEval.circularHelixD0(radius: 5.0, pitch: 10.0, u: .pi)
        #expect(abs(p.x - (-5.0)) < 1e-6)
        #expect(abs(p.z - 5.0) < 1e-6)  // half turn = pitch/2
    }

    @Test func helixD1() {
        let r = GeomEval.circularHelixD1(radius: 5.0, pitch: 10.0, u: 0.0)
        #expect(abs(r.point.x - 5.0) < 1e-10)
        // d1 at t=0: dx/dt = -R*sin(0) = 0, dy/dt = R*cos(0) = R
        #expect(abs(r.d1.x) < 1e-10)
        #expect(abs(r.d1.y - 5.0) < 1e-10)
    }

    @Test func helixD2() {
        let r = GeomEval.circularHelixD2(radius: 5.0, pitch: 10.0, u: 0.0)
        #expect(abs(r.point.x - 5.0) < 1e-10)
        // d2 at t=0: d2x/dt2 = -R*cos(0) = -R
        #expect(abs(r.d2.x - (-5.0)) < 1e-10)
    }

    @Test func helixCurveCreate() {
        let curve = Curve3D.circularHelix(radius: 3.0, pitch: 6.0)
        #expect(curve != nil)
    }

    @Test func helixCurveMinDistance() {
        // Verify the helix curve object works with extrema queries
        if let curve = Curve3D.circularHelix(radius: 5.0, pitch: 10.0) {
            if let d = curve.minimumDistance(from: SIMD3(10, 0, 0)) {
                #expect(d > 0)
            }
        }
    }
}
