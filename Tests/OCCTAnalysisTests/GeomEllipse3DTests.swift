import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom_Ellipse Properties")
struct GeomEllipse3DTests {
    @Test func ellipseRadii() {
        if let e = Curve3D.ellipse(
            center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 5)
        {
            #expect(abs(e.ellipseProperties.majorRadius - 10) < 1e-6)
            #expect(abs(e.ellipseProperties.minorRadius - 5) < 1e-6)
        }
    }

    @Test func ellipseSetRadii() {
        if let e = Curve3D.ellipse(
            center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 5)
        {
            #expect(e.ellipseProperties.setMajorRadius(20))
            #expect(abs(e.ellipseProperties.majorRadius - 20) < 1e-6)
            #expect(e.ellipseProperties.setMinorRadius(8))
            #expect(abs(e.ellipseProperties.minorRadius - 8) < 1e-6)
        }
    }

    @Test func ellipseEccentricity() {
        if let e = Curve3D.ellipse(
            center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 5)
        {
            let ecc = e.ellipseProperties.eccentricity
            #expect(ecc > 0 && ecc < 1)
        }
    }

    @Test func ellipseFocal() {
        if let e = Curve3D.ellipse(
            center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 5)
        {
            #expect(e.ellipseProperties.focal > 0)
        }
    }

    @Test func ellipseFoci() {
        if let e = Curve3D.ellipse(
            center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 5)
        {
            let f1 = e.ellipseProperties.focus1
            let f2 = e.ellipseProperties.focus2
            // Foci should be symmetric about center
            #expect(abs(f1.x + f2.x) < 1e-6)
        }
    }

    @Test func ellipseParameter() {
        if let e = Curve3D.ellipse(
            center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 5)
        {
            #expect(e.ellipseProperties.parameter > 0)
        }
    }

    @Test func ellipseDirectrix1() {
        if let e = Curve3D.ellipse(
            center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 5)
        {
            let d = e.ellipseProperties.directrix1
            // Directrix1 is the line normal to the XAxis, at distance majorRadius/eccentricity
            // from the center, on the positive side of the XAxis; its own direction is the
            // ellipse's YAxis (occt-refman Geom_Ellipse::Directrix1).
            let expectedX = e.ellipseProperties.majorRadius / e.ellipseProperties.eccentricity
            #expect(abs(d.position.x - expectedX) < 1e-6)
            #expect(abs(d.position.y) < 1e-6)
            #expect(abs(d.position.z) < 1e-6)
            #expect(abs(d.direction.x) < 1e-6)
            #expect(abs(d.direction.y - 1) < 1e-6)
            #expect(abs(d.direction.z) < 1e-6)
        }
    }
}
