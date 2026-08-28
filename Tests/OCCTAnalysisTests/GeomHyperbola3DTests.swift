import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom_Hyperbola Properties")
struct GeomHyperbola3DTests {
    @Test func hyperbolaRadii() {
        if let h = Curve3D.hyperbola(
            center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 5, minorRadius: 3)
        {
            #expect(abs(h.hyperbolaProperties.majorRadius - 5) < 1e-6)
            #expect(abs(h.hyperbolaProperties.minorRadius - 3) < 1e-6)
        }
    }

    @Test func hyperbolaSetRadii() {
        if let h = Curve3D.hyperbola(
            center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 5, minorRadius: 3)
        {
            #expect(h.hyperbolaProperties.setMajorRadius(8))
            #expect(abs(h.hyperbolaProperties.majorRadius - 8) < 1e-6)
            #expect(h.hyperbolaProperties.setMinorRadius(4))
            #expect(abs(h.hyperbolaProperties.minorRadius - 4) < 1e-6)
        }
    }

    @Test func hyperbolaEccentricity() {
        if let h = Curve3D.hyperbola(
            center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 5, minorRadius: 3)
        {
            #expect(h.hyperbolaProperties.eccentricity > 1)
        }
    }

    @Test func hyperbolaFocal() {
        if let h = Curve3D.hyperbola(
            center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 5, minorRadius: 3)
        {
            #expect(h.hyperbolaProperties.focal > 0)
        }
    }

    @Test func hyperbolaFocus1() {
        if let h = Curve3D.hyperbola(
            center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 5, minorRadius: 3)
        {
            let f = h.hyperbolaProperties.focus1
            #expect(f.x > 0)  // Focus is along positive X
        }
    }

    @Test func hyperbolaAsymptote1() {
        if let h = Curve3D.hyperbola(
            center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 5, minorRadius: 3)
        {
            let a = h.hyperbolaProperties.asymptote1
            // The asymptote passes through the hyperbola's own center, with direction
            // normalize(majorRadius, minorRadius, 0) in the local frame (Y = (B/A)*X).
            #expect(abs(a.position.x) < 1e-6)
            #expect(abs(a.position.y) < 1e-6)
            #expect(abs(a.position.z) < 1e-6)
            let expected = simd_normalize(SIMD3<Double>(5, 3, 0))
            #expect(abs(a.direction.x - expected.x) < 1e-6)
            #expect(abs(a.direction.y - expected.y) < 1e-6)
            #expect(abs(a.direction.z) < 1e-6)
        }
    }
}
