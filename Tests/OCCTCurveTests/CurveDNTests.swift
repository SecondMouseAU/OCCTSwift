import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to Geom_Curve / Geom2d_Curve / Geom_Surface::DN on the same inputs
// (Scripts/repro/766-curve-dn-interp-bounded/transcript.txt). The earlier versions sat inside
// `if let` and checked magnitudes only (`|d1.x| > 0.5`, `|du| > 0.1`), so a derivative pointing
// the wrong way passed (#766).
@Suite("v0.114.0 - Curve DN")
struct CurveDNTests {
    @Test func curve3dFirstDerivative() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) else {
            Issue.record("line not built")
            return
        }
        // First derivative of a line is its unit direction.
        #expect(line.dn(at: 0, order: 1) == SIMD3(1, 0, 0))
    }

    @Test func curve3dSecondDerivative() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) else {
            Issue.record("line not built")
            return
        }
        // Second derivative of a line is zero
        #expect(line.dn(at: 0, order: 2) == SIMD3(0, 0, 0))
    }

    @Test func curve2dFirstDerivative() {
        guard let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 1)) else {
            Issue.record("2D line not built")
            return
        }
        let d1 = line.dn(at: 0, order: 1)
        #expect(simd_distance(d1, SIMD2(1, 1) / 2.0.squareRoot()) < 1e-15)
    }

    @Test func surfaceDN() {
        guard let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5) else {
            Issue.record("sphere not built")
            return
        }
        // dP/du at (0, pi/4) on the r = 5 sphere: (0, 5 cos(pi/4), 0).
        let du = sphere.dn(u: 0, v: Double.pi / 4.0, nu: 1, nv: 0)
        #expect(simd_distance(du, SIMD3(0, 3.5355339059327378, 0)) < 1e-12)
    }
}
