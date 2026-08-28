import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom_Parabola Properties")
struct GeomParabola3DTests {
    @Test func parabolaFocal() {
        if let p = Curve3D.parabola(center: .zero, normal: SIMD3(0, 0, 1), focal: 3) {
            #expect(abs(p.parabolaProperties.focal - 3) < 1e-6)
        }
    }

    @Test func parabolaSetFocal() {
        if let p = Curve3D.parabola(center: .zero, normal: SIMD3(0, 0, 1), focal: 3) {
            #expect(p.parabolaProperties.setFocal(5))
            #expect(abs(p.parabolaProperties.focal - 5) < 1e-6)
        }
    }

    @Test func parabolaFocus() {
        if let p = Curve3D.parabola(center: .zero, normal: SIMD3(0, 0, 1), focal: 3) {
            let f = p.parabolaProperties.focus
            #expect(abs(f.x - 3) < 1e-6)
        }
    }

    @Test func parabolaEccentricity() {
        if let p = Curve3D.parabola(center: .zero, normal: SIMD3(0, 0, 1), focal: 3) {
            #expect(abs(p.parabolaProperties.eccentricity - 1.0) < 1e-6)
        }
    }

    @Test func parabolaParameter() {
        if let p = Curve3D.parabola(center: .zero, normal: SIMD3(0, 0, 1), focal: 3) {
            #expect(abs(p.parabolaProperties.parameter - 6.0) < 1e-6)
        }
    }

    @Test func parabolaDirectrix() {
        if let p = Curve3D.parabola(center: .zero, normal: SIMD3(0, 0, 1), focal: 3) {
            let d = p.parabolaProperties.directrix
            // The directrix sits at x = -focal on the parabola's own XAxis; its own direction
            // is the parabola's YAxis.
            #expect(abs(d.position.x - (-3)) < 1e-6)
            #expect(abs(d.position.y) < 1e-6)
            #expect(abs(d.position.z) < 1e-6)
            #expect(abs(d.direction.x) < 1e-6)
            #expect(abs(d.direction.y - 1) < 1e-6)
            #expect(abs(d.direction.z) < 1e-6)
        }
    }
}
