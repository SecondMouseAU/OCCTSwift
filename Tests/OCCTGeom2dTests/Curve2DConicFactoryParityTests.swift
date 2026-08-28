import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #487: Curve2D's two ellipse/hyperbola/parabola factory families

/// The three remaining `Curve2D` conic types exist twice over, exactly as the circle did before
/// #411 and as the four 3D conics did before #399: a direct family building a `Geom2d_*` object
/// from a `gp_Ax22d`, and a `*FromCenterDir` family routing through OCCT's `gce_Make*2d`
/// algorithms. The two are geometrically identical, but only the direct family carried a dimension
/// precondition, so the gce family returned live degenerate curves for input its sibling rejected.
///
/// The preconditions have to live in the bridge rather than be left to OCCT. Measured against the
/// pinned xcframework, `gce_MakeHypr2d(ax, 0, 0, true)` and `gce_MakeParab2d(ax, 0)` both report
/// `gce_Done`, as do the corresponding `Geom2d_Hyperbola`/`Geom2d_Parabola` constructors: OCCT
/// accepts these through every route. `gce_MakeElips2d(ax, 5, -3)` goes further and yields an
/// ellipse reporting `MinorRadius() == -3`, because its own two checks do not cover that input and
/// `gp_Elips2d`'s check, which does, is compiled out of the Release-built kernel by OCCT's
/// `No_Exception`. So there is no OCCT-side contract to inherit here, only one to impose.
@Suite("Curve2D conic factories agree (#487)")
struct Curve2DConicFactoryParityTests {

    private static let center = SIMD2<Double>(3, -4)
    private static let xDir = SIMD2<Double>(1, 0)

    @Test("Ellipse: both families reject zero, negative and inverted radii")
    func ellipseDegenerateRadiiParity() {
        let rejected: [(Double, Double)] = [(0, 0), (8, 0), (0, 4), (8, -4), (-8, 4), (4, 8)]
        for (major, minor) in rejected {
            #expect(
                Curve2D.ellipse(
                    center: Self.center,
                    majorRadius: major, minorRadius: minor) == nil)
            #expect(
                Curve2D.ellipseFromCenterDir(
                    center: Self.center, direction: Self.xDir,
                    majorRadius: major, minorRadius: minor) == nil)
        }
    }

    @Test("Hyperbola: both families reject a zero or negative radius")
    func hyperbolaDegenerateRadiiParity() {
        let rejected: [(Double, Double)] = [(0, 0), (6, 0), (0, 3), (6, -3), (-6, 3)]
        for (major, minor) in rejected {
            #expect(
                Curve2D.hyperbola(
                    center: Self.center,
                    majorRadius: major, minorRadius: minor) == nil)
            #expect(
                Curve2D.hyperbolaFromCenterDir(
                    center: Self.center, direction: Self.xDir,
                    majorRadius: major, minorRadius: minor) == nil)
        }
    }

    @Test("Parabola: both families reject zero and negative focal length")
    func parabolaDegenerateFocalParity() {
        for focal in [0.0, -1.0, -3.0] {
            #expect(
                Curve2D.parabola(
                    focus: Self.center, direction: Self.xDir,
                    focalLength: focal) == nil)
            #expect(
                Curve2D.parabolaFromCenterDir(
                    center: Self.center, direction: Self.xDir,
                    focal: focal) == nil)
        }
    }

    @Test("Hyperbola: a minor radius larger than the major is accepted by both families")
    func hyperbolaMinorLargerThanMajorAcceptedByBoth() {
        // A hyperbola puts no ordering on its radii, unlike an ellipse. Pinned so the shared
        // precondition is not tightened into the ellipse's rule by a later pass.
        #expect(Curve2D.hyperbola(center: Self.center, majorRadius: 3, minorRadius: 6) != nil)
        #expect(
            Curve2D.hyperbolaFromCenterDir(
                center: Self.center, direction: Self.xDir,
                majorRadius: 3, minorRadius: 6) != nil)
    }

    @Test("Ellipse: equal radii are accepted by both families")
    func ellipseEqualRadiiAcceptedByBoth() {
        // gp_Elips2d documents MajorRadius == MinorRadius as valid, so the shared precondition
        // must reject only minor > major, not minor >= major.
        #expect(Curve2D.ellipse(center: Self.center, majorRadius: 5, minorRadius: 5) != nil)
        #expect(
            Curve2D.ellipseFromCenterDir(
                center: Self.center, direction: Self.xDir,
                majorRadius: 5, minorRadius: 5) != nil)
    }

    @Test("Valid ellipse radii still build the identical curve in both families")
    func validEllipseProducesMatchingGeometry() {
        let direct = Curve2D.ellipse(center: Self.center, majorRadius: 8, minorRadius: 4)
        let gce = Curve2D.ellipseFromCenterDir(
            center: Self.center, direction: Self.xDir,
            majorRadius: 8, minorRadius: 4)
        #expect(direct != nil)
        #expect(gce != nil)
        guard let a = direct, let b = gce else { return }

        #expect(a.isClosed == b.isClosed)
        #expect(a.isPeriodic == b.isPeriodic)
        for t in stride(from: 0.0, to: 2 * .pi, by: .pi / 6) {
            let pa = a.point(at: t)
            let pb = b.point(at: t)
            #expect(abs(pa.x - pb.x) < 1e-9)
            #expect(abs(pa.y - pb.y) < 1e-9)
        }
    }

    @Test("Valid hyperbola radii still build the identical curve in both families")
    func validHyperbolaProducesMatchingGeometry() {
        let direct = Curve2D.hyperbola(center: Self.center, majorRadius: 6, minorRadius: 3)
        let gce = Curve2D.hyperbolaFromCenterDir(
            center: Self.center, direction: Self.xDir,
            majorRadius: 6, minorRadius: 3)
        #expect(direct != nil)
        #expect(gce != nil)
        guard let a = direct, let b = gce else { return }

        for t in stride(from: -1.0, through: 1.0, by: 0.25) {
            let pa = a.point(at: t)
            let pb = b.point(at: t)
            #expect(abs(pa.x - pb.x) < 1e-9)
            #expect(abs(pa.y - pb.y) < 1e-9)
        }
    }

    @Test("Valid focal length still builds the identical parabola in both families")
    func validParabolaProducesMatchingGeometry() {
        // The two factories locate the curve from different points: parabolaFromCenterDir takes
        // the vertex (gce_MakeParab2d's MirrorAxis location), parabola takes the focus and steps
        // back along the axis to reach it. Same curve once the focus is placed accordingly.
        let focal = 3.0
        let vertex = Self.center
        let focus = vertex + Self.xDir * focal
        let direct = Curve2D.parabola(focus: focus, direction: Self.xDir, focalLength: focal)
        let gce = Curve2D.parabolaFromCenterDir(center: vertex, direction: Self.xDir, focal: focal)
        #expect(direct != nil)
        #expect(gce != nil)
        guard let a = direct, let b = gce else { return }

        for t in stride(from: -2.0, through: 2.0, by: 0.5) {
            let pa = a.point(at: t)
            let pb = b.point(at: t)
            #expect(abs(pa.x - pb.x) < 1e-9)
            #expect(abs(pa.y - pb.y) < 1e-9)
        }
    }
}
