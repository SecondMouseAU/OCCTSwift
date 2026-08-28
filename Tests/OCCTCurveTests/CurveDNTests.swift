import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.114.0 - Curve DN")
struct CurveDNTests {

    @Test func curve3dFirstDerivative() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            let d1 = line.dn(at: 0, order: 1)
            // First derivative of a line is its direction
            #expect(abs(d1.x) > 0.5)
        }
    }

    @Test func curve3dSecondDerivative() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            let d2 = line.dn(at: 0, order: 2)
            // Second derivative of a line is zero
            #expect(abs(d2.x) < 1e-10)
            #expect(abs(d2.y) < 1e-10)
            #expect(abs(d2.z) < 1e-10)
        }
    }

    @Test func curve2dFirstDerivative() {
        if let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 1)) {
            let d1 = line.dn(at: 0, order: 1)
            #expect(abs(d1.x) > 0.1)
            #expect(abs(d1.y) > 0.1)
        }
    }

    @Test func surfaceDN() {
        if let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5) {
            // du at (0, pi/4)
            let du = sphere.dn(u: 0, v: Double.pi / 4.0, nu: 1, nv: 0)
            // Should be non-zero (tangent in U direction)
            let mag = sqrt(du.x * du.x + du.y * du.y + du.z * du.z)
            #expect(mag > 0.1)
        }
    }
}
