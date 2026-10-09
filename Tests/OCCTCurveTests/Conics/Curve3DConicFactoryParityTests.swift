import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #399: direct vs gce_Make* conic factory families

/// The four `Curve3D` conic factories exist twice: a direct family that builds `Geom_*` objects
/// straight from a `gp_Ax2`, and a `*FromCenterNormal` family that routes through OCCT's
/// `gce_Make*` algorithms. The two are geometrically identical (`gce_Make*` builds the same
/// `gp_Ax2(center, normal)` frame), but the `gce_Make*` algorithms only reject strictly-negative
/// dimensions, so the gce family used to return a degenerate zero-radius/zero-focal curve where
/// the direct family returned `nil`. Both families now share one set of preconditions.

@Suite("Curve3D conic factory families agree (#399)")
struct Curve3DConicFactoryParityTests {

    private static let center = SIMD3<Double>(1, 2, 3)
    private static let normal = SIMD3<Double>(0, 0, 1)

    @Test("Circle: both families reject zero and negative radius")
    func circleDegenerateRadiusParity() {
        for radius in [0.0, -1.0] {
            #expect(Curve3D.circle(center: Self.center, normal: Self.normal, radius: radius) == nil)
            #expect(
                Curve3D.circleFromCenterNormal(
                    center: Self.center, normal: Self.normal,
                    radius: radius) == nil)
        }
    }

    @Test("Ellipse: both families reject zero radii and inverted radii")
    func ellipseDegenerateRadiiParity() {
        let rejected: [(Double, Double)] = [(10, 0), (0, 0), (5, 10), (10, -1)]
        for (major, minor) in rejected {
            #expect(
                Curve3D.ellipse(
                    center: Self.center, normal: Self.normal,
                    majorRadius: major, minorRadius: minor) == nil)
            #expect(
                Curve3D.ellipseFromCenterNormal(
                    center: Self.center, normal: Self.normal,
                    majorRadius: major, minorRadius: minor) == nil)
        }
    }

    @Test("Hyperbola: both families reject a zero or negative radius")
    func hyperbolaDegenerateRadiiParity() {
        let rejected: [(Double, Double)] = [(0, 3), (8, 0), (0, 0), (-8, 3)]
        for (major, minor) in rejected {
            #expect(
                Curve3D.hyperbola(
                    center: Self.center, normal: Self.normal,
                    majorRadius: major, minorRadius: minor) == nil)
            #expect(
                Curve3D.hyperbolaFromCenterNormal(
                    center: Self.center, normal: Self.normal,
                    majorRadius: major,
                    minorRadius: minor) == nil)
        }
    }

    @Test("Parabola: both families reject zero and negative focal length")
    func parabolaDegenerateFocalParity() {
        for focal in [0.0, -1.0] {
            #expect(Curve3D.parabola(center: Self.center, normal: Self.normal, focal: focal) == nil)
            #expect(
                Curve3D.parabolaFromCenterNormal(
                    center: Self.center, normal: Self.normal,
                    focal: focal) == nil)
        }
    }

    @Test("Valid inputs still build the identical curve in both families")
    func validInputsProduceMatchingGeometry() {
        // Circle
        let c1 = Curve3D.circle(center: Self.center, normal: Self.normal, radius: 7)
        let c2 = Curve3D.circleFromCenterNormal(center: Self.center, normal: Self.normal, radius: 7)
        #expect(c1 != nil)
        #expect(c2 != nil)
        if let a = c1, let b = c2 {
            for t in stride(from: 0.0, to: 2 * .pi, by: .pi / 4) {
                let pa = a.point(at: t)
                let pb = b.point(at: t)
                #expect(simd_distance(pa, pb) < 1e-9)
            }
        }

        // Ellipse
        let e1 = Curve3D.ellipse(
            center: Self.center, normal: Self.normal,
            majorRadius: 10, minorRadius: 5)
        let e2 = Curve3D.ellipseFromCenterNormal(
            center: Self.center, normal: Self.normal,
            majorRadius: 10, minorRadius: 5)
        #expect(e1 != nil)
        #expect(e2 != nil)
        if let a = e1, let b = e2 {
            for t in stride(from: 0.0, to: 2 * .pi, by: .pi / 4) {
                #expect(simd_distance(a.point(at: t), b.point(at: t)) < 1e-9)
            }
        }

        // Hyperbola
        let h1 = Curve3D.hyperbola(
            center: Self.center, normal: Self.normal,
            majorRadius: 8, minorRadius: 3)
        let h2 = Curve3D.hyperbolaFromCenterNormal(
            center: Self.center, normal: Self.normal,
            majorRadius: 8, minorRadius: 3)
        #expect(h1 != nil)
        #expect(h2 != nil)
        if let a = h1, let b = h2 {
            for t in stride(from: -1.0, through: 1.0, by: 0.25) {
                #expect(simd_distance(a.point(at: t), b.point(at: t)) < 1e-9)
            }
        }

        // Parabola
        let p1 = Curve3D.parabola(center: Self.center, normal: Self.normal, focal: 4)
        let p2 = Curve3D.parabolaFromCenterNormal(
            center: Self.center, normal: Self.normal, focal: 4)
        #expect(p1 != nil)
        #expect(p2 != nil)
        if let a = p1, let b = p2 {
            for t in stride(from: -2.0, through: 2.0, by: 0.5) {
                #expect(simd_distance(a.point(at: t), b.point(at: t)) < 1e-9)
            }
        }
    }
}
