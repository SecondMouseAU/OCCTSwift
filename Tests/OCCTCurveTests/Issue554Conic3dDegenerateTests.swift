import Foundation
import Testing

@testable import OCCTSwift

/// #554: the 3D counterparts of #514. Every bridge site that builds a 3D conic from a
/// caller-supplied dimension, or rewrites one on a live curve, and never checked it.
///
/// The gap is the same one #514 measured in 2D, and for the same reason. OCCT does reject the
/// obviously-bad values, by three separate mechanisms that survive this build to three different
/// degrees:
///
/// - `gp_Elips`/`gp_Hypr`/`gp_Parab` are `constexpr` in the header, so their
///   `Standard_ConstructionError_Raise_if` runs in a bridge translation unit and negatives and
///   inverted ellipse radii already raised.
/// - `GC_MakeEllipse`/`GC_MakeHyperbola` compile inside OCCT, where `No_Exception` deletes that
///   macro, but they carry their own status and report `!IsDone()` for the same inputs.
/// - `Geom_Ellipse`'s setters use a hand-written `if (...) throw`, which is not a macro and so
///   raises from inside OCCT's own translation unit too.
///
/// What all three let through is **zero**, which satisfies every check written
/// (`minor < 0 || major < minor` is false for `(0, 0)`). These tests pin zero at every site, and
/// keep the negative/ordering cases as controls so a future change that removes a guard on the
/// theory that "OCCT already checks" fails here first.
@Suite("Issue554 3D conic degenerate dimensions")
struct Issue554Conic3dDegenerateTests {

    private static let center = SIMD3<Double>(0, 0, 0)
    private static let normal = SIMD3<Double>(0, 0, 1)
    private static let xDir = SIMD3<Double>(1, 0, 0)

    // MARK: - GC_MakeArcOf* (Curve3D.arcOf*)

    @Test func arcOfEllipseRejectsZeroRadii() {
        // Measured before the guard: both reported IsDone() and produced a live trimmed curve.
        // (0, 0) evaluated to its own centre at every parameter; (5, 0) collapsed onto the
        // major axis, running 5,0,0 -> 0,0,0 over [0, pi].
        #expect(
            Curve3D.arcOfEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 0, minorRadius: 0,
                startAngle: 0, endAngle: .pi) == nil)
        #expect(
            Curve3D.arcOfEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 0,
                startAngle: 0, endAngle: .pi) == nil)
    }

    @Test func arcOfEllipseRejectsNegativeAndInvertedRadii() {
        #expect(
            Curve3D.arcOfEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: -3,
                startAngle: 0, endAngle: .pi) == nil)
        #expect(
            Curve3D.arcOfEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 3, minorRadius: 5,
                startAngle: 0, endAngle: .pi) == nil)
    }

    @Test func arcOfEllipseAcceptsValidRadii() {
        #expect(
            Curve3D.arcOfEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 3,
                startAngle: 0, endAngle: .pi) != nil)
        // Equal radii are a circle, which gp_Elips documents as valid.
        #expect(
            Curve3D.arcOfEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 4, minorRadius: 4,
                startAngle: 0, endAngle: .pi) != nil)
    }

    /// The sharpest case in the issue, and the reason `IsDone()` is not a sufficient guard.
    @Test func arcOfEllipseThroughPointsRejectsZeroMinorRadius() {
        // A zero minor radius makes the two-point form's ElCLib::Parameter inversion return NaN
        // for both bounds (0/0 in its atan2), and GC_MakeArcOfEllipse still reports IsDone().
        // Measured before the guard: a live Curve3D whose parameter range was [nan, nan] and
        // whose every evaluation was NaN.
        #expect(
            Curve3D.arcOfEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 0,
                from: SIMD3(5, 0, 0), to: SIMD3(-5, 0, 0)) == nil)
        #expect(
            Curve3D.arcOfEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 0, minorRadius: 0,
                from: SIMD3(1, 0, 0), to: SIMD3(0, 1, 0)) == nil)
    }

    @Test func arcOfEllipseThroughPointsAcceptsValidRadiiAndIsNotNaN() {
        // The control that pins the NaN above to the radius and not to the two-point form:
        // the identical call on a healthy ellipse produces a finite parameter range.
        let arc = Curve3D.arcOfEllipse(
            center: Self.center, normal: Self.normal,
            majorRadius: 5, minorRadius: 3,
            from: SIMD3(5, 0, 0), to: SIMD3(-5, 0, 0))
        #expect(arc != nil)
        if let arc {
            #expect(arc.firstParameter.isFinite)
            #expect(arc.lastParameter.isFinite)
        }
    }

    @Test func arcOfHyperbolaRejectsZeroRadii() {
        #expect(
            Curve3D.arcOfHyperbola(
                center: Self.center, direction: Self.normal,
                majorRadius: 0, minorRadius: 0,
                alpha1: 0, alpha2: 1) == nil)
        #expect(
            Curve3D.arcOfHyperbola(
                center: Self.center, direction: Self.normal,
                majorRadius: 5, minorRadius: 0,
                alpha1: 0, alpha2: 1) == nil)
        #expect(
            Curve3D.arcOfHyperbola(
                center: Self.center, direction: Self.normal,
                majorRadius: 0, minorRadius: 5,
                alpha1: 0, alpha2: 1) == nil)
    }

    @Test func arcOfHyperbolaAcceptsMinorLargerThanMajor() {
        // A hyperbola puts no ordering on its radii; copying the ellipse rule would reject this.
        #expect(
            Curve3D.arcOfHyperbola(
                center: Self.center, direction: Self.normal,
                majorRadius: 3, minorRadius: 5,
                alpha1: 0, alpha2: 1) != nil)
    }

    @Test func arcOfParabolaRejectsZeroFocalDistance() {
        // Measured before the guard: focal 0 gave a live arc that is a straight line along the
        // parabola's own axis of symmetry, which is what gp_Parab documents zero to mean.
        #expect(
            Curve3D.arcOfParabola(
                center: Self.center, direction: Self.normal,
                focalDistance: 0, alpha1: 0, alpha2: 1) == nil)
    }

    @Test func arcOfParabolaAcceptsPositiveFocalDistance() {
        #expect(
            Curve3D.arcOfParabola(
                center: Self.center, direction: Self.normal,
                focalDistance: 2, alpha1: 0, alpha2: 1) != nil)
    }

    // MARK: - GC_MakeEllipse / GC_MakeHyperbola (Curve3D.gc*)

    @Test func gcEllipseRejectsZeroRadii() {
        #expect(
            Curve3D.gcEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 0, minorRadius: 0) == nil)
        #expect(
            Curve3D.gcEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 0) == nil)
        #expect(
            Curve3D.gcEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 3) != nil)
    }

    @Test func gcEllipseFromFullAxisRejectsZeroRadii() {
        #expect(
            Curve3D.gcEllipse(
                center: Self.center, normal: Self.normal, xDirection: Self.xDir,
                majorRadius: 0, minorRadius: 0) == nil)
        #expect(
            Curve3D.gcEllipse(
                center: Self.center, normal: Self.normal, xDirection: Self.xDir,
                majorRadius: 5, minorRadius: 0) == nil)
        #expect(
            Curve3D.gcEllipse(
                center: Self.center, normal: Self.normal, xDirection: Self.xDir,
                majorRadius: 5, minorRadius: 3) != nil)
    }

    @Test func gcHyperbolaRejectsZeroRadii() {
        #expect(
            Curve3D.gcHyperbola(
                center: Self.center, normal: Self.normal,
                majorRadius: 0, minorRadius: 0) == nil)
        #expect(
            Curve3D.gcHyperbola(
                center: Self.center, normal: Self.normal,
                majorRadius: 0, minorRadius: 5) == nil)
        #expect(
            Curve3D.gcHyperbola(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 3) != nil)
    }

    /// Control for the two three-point forms, which are deliberately *not* guarded: they take no
    /// dimension at all, and OCCT's own `GC_Make*` status already rejects a degenerate triple.
    /// If that ever stops being true, this test is where it shows up.
    @Test func gcThreePointFormsRejectDegeneratePointTriplesWithoutABridgeGuard() {
        let origin = SIMD3<Double>(0, 0, 0)
        #expect(Curve3D.gcEllipse(s1: origin, s2: origin, center: origin) == nil)
        // S2 on the major axis leaves no minor radius to derive.
        #expect(Curve3D.gcEllipse(s1: SIMD3(5, 0, 0), s2: SIMD3(2, 0, 0), center: origin) == nil)
        #expect(Curve3D.gcHyperbola(s1: origin, s2: origin, center: origin) == nil)
        // ... and the healthy triple still builds.
        #expect(Curve3D.gcEllipse(s1: SIMD3(5, 0, 0), s2: SIMD3(0, 3, 0), center: origin) != nil)
    }

    // MARK: - BRepBuilderAPI_MakeEdge (Shape.edgeFrom*)

    @Test func edgeFromEllipseRejectsZeroRadii() {
        // BRepBuilderAPI_MakeEdge reported IsDone() for every degenerate conic below, so before
        // the guard each of these returned a live edge carrying a curve that is really a point.
        #expect(
            Shape.edgeFromEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 0, minorRadius: 0) == nil)
        #expect(
            Shape.edgeFromEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 0) == nil)
        #expect(
            Shape.edgeFromEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 3) != nil)
    }

    @Test func edgeFromEllipseArcRejectsZeroRadii() {
        #expect(
            Shape.edgeFromEllipseArc(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 0, u1: 0, u2: .pi) == nil)
        #expect(
            Shape.edgeFromEllipseArc(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 3, u1: 0, u2: .pi) != nil)
    }

    @Test func edgeFromHyperbolaArcRejectsZeroRadii() {
        #expect(
            Shape.edgeFromHyperbolaArc(
                center: Self.center, normal: Self.normal,
                majorRadius: 0, minorRadius: 0, u1: 0, u2: 1) == nil)
        #expect(
            Shape.edgeFromHyperbolaArc(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 0, u1: 0, u2: 1) == nil)
        #expect(
            Shape.edgeFromHyperbolaArc(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 3, u1: 0, u2: 1) != nil)
    }

    @Test func edgeFromParabolaArcRejectsZeroFocalLength() {
        #expect(
            Shape.edgeFromParabolaArc(
                center: Self.center, normal: Self.normal,
                focalLength: 0, u1: 0, u2: 1) == nil)
        #expect(
            Shape.edgeFromParabolaArc(
                center: Self.center, normal: Self.normal,
                focalLength: 2, u1: 0, u2: 1) != nil)
    }

    // MARK: - Extrema_ExtElC / Extrema_ExtPElC

    /// These are solver inputs, which #553 excluded from the 2D pass on the grounds that a
    /// degenerate conic can still be a meaningful question. Measured here, it is not: OCCT does
    /// not answer the degenerate question, it answers a different one.
    @Test func pointToEllipseRejectsZeroRadii() {
        // Measured before the guard: NbExt() == 0 against a (0, 0) ellipse, so the caller was
        // told "no extrema" rather than the one extremum at the centre.
        #expect(
            ExtremaPointCurve.pointToEllipse(
                point: SIMD3(10, 0, 0),
                center: Self.center, normal: Self.normal,
                xDir: Self.xDir,
                majorRadius: 0, minorRadius: 0
            ).isEmpty)
        #expect(
            ExtremaPointCurve.pointToEllipse(
                point: SIMD3(10, 0, 0),
                center: Self.center, normal: Self.normal,
                xDir: Self.xDir,
                majorRadius: 5, minorRadius: 0
            ).isEmpty)
        // The healthy ellipse still answers, with the near and far extremum.
        #expect(
            ExtremaPointCurve.pointToEllipse(
                point: SIMD3(10, 0, 0),
                center: Self.center, normal: Self.normal,
                xDir: Self.xDir,
                majorRadius: 5, minorRadius: 3
            ).count == 2)
    }

    @Test func pointToParabolaRejectsZeroFocalDistance() {
        #expect(
            ExtremaPointCurve.pointToParabola(
                point: SIMD3(10, 0, 0),
                center: Self.center, normal: Self.normal,
                xDir: Self.xDir, focal: 0
            ).isEmpty)
        #expect(
            !ExtremaPointCurve.pointToParabola(
                point: SIMD3(10, 0, 0),
                center: Self.center, normal: Self.normal,
                xDir: Self.xDir, focal: 2
            ).isEmpty)
    }

    @Test func lineToEllipseRejectsZeroRadii() {
        let linePoint = SIMD3<Double>(0, 0, 10)
        let lineDir = SIMD3<Double>(1, 0, 1)
        #expect(
            ExtremaElC.lineToEllipse(
                linePoint: linePoint, lineDir: lineDir,
                center: Self.center, normal: Self.normal, xDir: Self.xDir,
                majorRadius: 0, minorRadius: 0
            ).isEmpty)
        #expect(
            ExtremaElC.lineToEllipse(
                linePoint: linePoint, lineDir: lineDir,
                center: Self.center, normal: Self.normal, xDir: Self.xDir,
                majorRadius: 5, minorRadius: 0
            ).isEmpty)
        #expect(
            !ExtremaElC.lineToEllipse(
                linePoint: linePoint, lineDir: lineDir,
                center: Self.center, normal: Self.normal, xDir: Self.xDir,
                majorRadius: 5, minorRadius: 3
            ).isEmpty)
    }

    // MARK: - Geom_* setters, which degrade a healthy curve in place

    @Test func ellipseSetMinorRadiusRejectsZero() {
        let e = Curve3D.ellipse(
            center: Self.center, normal: Self.normal,
            majorRadius: 5, minorRadius: 3)
        #expect(e != nil)
        guard let e else { return }
        // Measured before the guard: accepted, leaving a live Geom_Ellipse with minorRadius 0
        // that evaluates onto its own major axis.
        #expect(e.ellipseProperties.setMinorRadius(0) == false)
        #expect(e.ellipseProperties.minorRadius == 3)
        #expect(e.ellipseProperties.setMinorRadius(2) == true)
        #expect(e.ellipseProperties.minorRadius == 2)
    }

    @Test func ellipseSetMajorRadiusKeepsThePairValid() {
        let e = Curve3D.ellipse(
            center: Self.center, normal: Self.normal,
            majorRadius: 5, minorRadius: 3)
        #expect(e != nil)
        guard let e else { return }
        // Below the current minor radius, which Geom_Ellipse's own hand-written throw already
        // rejected. Kept as a control on the new pairwise check.
        #expect(e.ellipseProperties.setMajorRadius(1) == false)
        #expect(e.ellipseProperties.setMajorRadius(0) == false)
        #expect(e.ellipseProperties.majorRadius == 5)
        #expect(e.ellipseProperties.setMajorRadius(9) == true)
        #expect(e.ellipseProperties.majorRadius == 9)
    }

    @Test func hyperbolaSettersRejectZero() {
        let h = Curve3D.hyperbola(
            center: Self.center, normal: Self.normal,
            majorRadius: 5, minorRadius: 3)
        #expect(h != nil)
        guard let h else { return }
        #expect(h.hyperbolaProperties.setMajorRadius(0) == false)
        #expect(h.hyperbolaProperties.setMinorRadius(0) == false)
        #expect(h.hyperbolaProperties.majorRadius == 5)
        #expect(h.hyperbolaProperties.minorRadius == 3)
        // No ordering constraint, so a minor above the major is still accepted.
        #expect(h.hyperbolaProperties.setMinorRadius(8) == true)
        #expect(h.hyperbolaProperties.minorRadius == 8)
    }

    @Test func parabolaSetFocalRejectsZero() {
        let p = Curve3D.parabola(center: Self.center, normal: Self.normal, focal: 2)
        #expect(p != nil)
        guard let p else { return }
        #expect(p.parabolaProperties.setFocal(0) == false)
        #expect(p.parabolaProperties.focal == 2)
        #expect(p.parabolaProperties.setFocal(6) == true)
        #expect(p.parabolaProperties.focal == 6)
    }

    @Test func circleSetRadiusRejectsZero() {
        let c = Curve3D.circle(center: Self.center, normal: Self.normal, radius: 5)
        #expect(c != nil)
        guard let c else { return }
        #expect(c.circleProperties.setRadius(0) == false)
        #expect(c.circleProperties.radius == 5)
        #expect(c.circleProperties.setRadius(7) == true)
        #expect(c.circleProperties.radius == 7)
    }

    // MARK: - The two families deliberately left alone

    /// `BndLib` and `ElCLib` take the same dimensions and are deliberately not guarded: both are
    /// pure queries that return the *correct* answer for the degenerate curve, and both are
    /// `void` bridge functions with nowhere to report a rejection. Pinned so the exclusion is a
    /// recorded decision rather than an oversight, and so a later pass that adds a guard here has
    /// to change a test that says why it should not.
    @Test func degenerateEllipseStillEvaluatesAndBoundsCorrectly() {
        // ElCLib evaluates the collapsed ellipse exactly as gp_Elips defines it: a point on the
        // major axis at 5*cos(1).
        let p = ElCLib.valueOnEllipse(
            u: 1, center: Self.center, normal: Self.normal,
            majorRadius: 5, minorRadius: 0)
        #expect(abs(p.x - 5 * Foundation.cos(1.0)) < 1e-9)
        #expect(abs(p.y) < 1e-12)

        // BndLib returns the true box of the segment the collapsed ellipse traces.
        let b = BndLib.ellipse(
            center: Self.center, normal: Self.normal, xDirection: Self.xDir,
            majorRadius: 5, minorRadius: 0)
        #expect(abs(b.min.x - -5) < 1e-6)
        #expect(abs(b.max.x - 5) < 1e-6)
        #expect(abs(b.max.y) < 1e-6)
    }
}
