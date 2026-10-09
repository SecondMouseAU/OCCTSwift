import Foundation
import Testing
import simd

@testable import OCCTSwift

/// One point against its expected value, with a message that names the site.
private func expectPoint(
    _ got: SIMD3<Double>, _ want: SIMD3<Double>, _ what: String, tolerance: Double = 1e-9,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(
        simd_distance(got, want) < tolerance, "\(what): got \(got), want \(want)",
        sourceLocation: sourceLocation)
}

/// Composite Simpson's rule: the second route to an arc length, independent of the kernel.
private func simpson(
    _ f: (Double) -> Double, _ a: Double, _ b: Double, steps: Int = 4000
) -> Double {
    let h = (b - a) / Double(steps)
    var sum = f(a) + f(b)
    for i in 1..<steps { sum += f(a + Double(i) * h) * (i % 2 == 1 ? 4 : 2) }
    return sum * h / 3
}

/// The arc of `ellipse(a, b)` about the origin in the XY plane, at parameter `u`.
private func ellipsePoint(_ a: Double, _ b: Double, _ u: Double, at c: SIMD3<Double> = .zero)
    -> SIMD3<Double>
{
    c + SIMD3(a * Foundation.cos(u), b * Foundation.sin(u), 0)
}

/// The branch of `hyperbola(a, b)` about the origin in the XY plane, at parameter `u`.
private func hyperbolaPoint(_ a: Double, _ b: Double, _ u: Double, at c: SIMD3<Double> = .zero)
    -> SIMD3<Double>
{
    c + SIMD3(a * Foundation.cosh(u), b * Foundation.sinh(u), 0)
}

/// `y^2 = 4 f x` traced as `(u^2 / 4f, u)`, the parametrisation `gp_Parab` documents.
private func parabolaPoint(_ f: Double, _ u: Double, at c: SIMD3<Double> = .zero) -> SIMD3<Double> {
    c + SIMD3(u * u / (4 * f), u, 0)
}

/// #554: the 3D counterparts of #514.
///
/// Every bridge site that builds a 3D conic from a
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
    /// A centre off the origin, so a site that drops the centre cannot pass.
    private static let offCenter = SIMD3<Double>(1, 2, 3)

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

    @Test func arcOfEllipseAcceptsValidRadii() throws {
        // The arc is the ellipse (5 cos u, 3 sin u, 0) over [0, pi]: start (5,0,0), the top of the
        // minor axis (0,3,0) at pi/2, end (-5,0,0). Every one of those is a different wrong
        // answer for a swapped radius pair, a halved end angle or a shifted start.
        let arc = try #require(
            Curve3D.arcOfEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 3,
                startAngle: 0, endAngle: .pi))
        #expect(abs(arc.domain.lowerBound) < 1e-12)
        #expect(abs(arc.domain.upperBound - .pi) < 1e-12)
        expectPoint(arc.startPoint, SIMD3(5, 0, 0), "start")
        expectPoint(arc.point(at: .pi / 2), SIMD3(0, 3, 0), "minor-axis apex")
        expectPoint(arc.point(at: .pi / 4), ellipsePoint(5, 3, .pi / 4), "an interior point")
        expectPoint(arc.endPoint, SIMD3(-5, 0, 0), "end")

        // Equal radii are a circle, which gp_Elips documents as valid.
        let circle = try #require(
            Curve3D.arcOfEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 4, minorRadius: 4,
                startAngle: 0, endAngle: .pi))
        expectPoint(circle.startPoint, SIMD3(4, 0, 0), "circle start")
        expectPoint(circle.point(at: .pi / 2), SIMD3(0, 4, 0), "circle apex")
        expectPoint(circle.endPoint, SIMD3(-4, 0, 0), "circle end")

        // A centre off the origin is carried through, and the normal fixes which way the
        // parameter runs: gp_Ax2 turns a -Z normal into an X axis of -X, so the same angles
        // start on the other side.
        let moved = try #require(
            Curve3D.arcOfEllipse(
                center: Self.offCenter, normal: Self.normal,
                majorRadius: 5, minorRadius: 3,
                startAngle: 0, endAngle: .pi))
        expectPoint(moved.startPoint, Self.offCenter + SIMD3(5, 0, 0), "moved start")
        expectPoint(moved.point(at: .pi / 2), Self.offCenter + SIMD3(0, 3, 0), "moved apex")
        let flipped = try #require(
            Curve3D.arcOfEllipse(
                center: Self.offCenter, normal: -Self.normal,
                majorRadius: 5, minorRadius: 3,
                startAngle: 0, endAngle: .pi))
        expectPoint(flipped.startPoint, Self.offCenter + SIMD3(-5, 0, 0), "flipped-normal start")
        expectPoint(flipped.point(at: .pi / 2), Self.offCenter + SIMD3(0, 3, 0), "flipped apex")
    }

    /// `counterclockwise: false` is the opposite orientation of the same arc.
    ///
    /// `GC_MakeArcOfEllipse.hxx` says the orientation is the ellipse's when `theSense` is true
    /// and the opposite when it is false, so the points do not move: the arc starts where the
    /// forward one ended and ends where it started.
    @Test func arcOfEllipseSenseReversesTheSameArc() throws {
        let forward = try #require(
            Curve3D.arcOfEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 3,
                startAngle: 0, endAngle: .pi))
        let backward = try #require(
            Curve3D.arcOfEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 3,
                startAngle: 0, endAngle: .pi, counterclockwise: false))
        expectPoint(backward.startPoint, forward.endPoint, "reversed start is the forward end")
        expectPoint(backward.endPoint, forward.startPoint, "reversed end is the forward start")
        let middle = (backward.domain.lowerBound + backward.domain.upperBound) / 2
        expectPoint(backward.point(at: middle), SIMD3(0, 3, 0), "the same apex")
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

    @Test func arcOfEllipseThroughPointsAcceptsValidRadiiAndIsNotNaN() throws {
        // The control that pins the NaN above to the radius and not to the two-point form:
        // the identical call on a healthy ellipse produces the exact parameter range [0, pi]
        // (the points are the parameter-0 and parameter-pi points of (5 cos u, 3 sin u)).
        let arc = try #require(
            Curve3D.arcOfEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 3,
                from: SIMD3(5, 0, 0), to: SIMD3(-5, 0, 0)))
        #expect(arc.firstParameter.isFinite)
        #expect(arc.lastParameter.isFinite)
        #expect(abs(arc.firstParameter) < 1e-12)
        #expect(abs(arc.lastParameter - .pi) < 1e-12)
        expectPoint(arc.startPoint, SIMD3(5, 0, 0), "start")
        expectPoint(arc.point(at: .pi / 2), SIMD3(0, 3, 0), "the upper half, not the lower")
        expectPoint(arc.endPoint, SIMD3(-5, 0, 0), "end")

        // The endpoints are not interchangeable: from (-5,0,0) to (5,0,0) counterclockwise runs
        // pi -> 2pi, through the bottom of the minor axis.
        let lower = try #require(
            Curve3D.arcOfEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 3,
                from: SIMD3(-5, 0, 0), to: SIMD3(5, 0, 0)))
        #expect(abs(lower.firstParameter - .pi) < 1e-12)
        #expect(abs(lower.lastParameter - 2 * .pi) < 1e-12)
        expectPoint(lower.point(at: 1.5 * .pi), SIMD3(0, -3, 0), "the lower half")

        // Same orientation rule as the angular form: sense false is the same arc reversed.
        let reversed = try #require(
            Curve3D.arcOfEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 3,
                from: SIMD3(5, 0, 0), to: SIMD3(-5, 0, 0), counterclockwise: false))
        expectPoint(reversed.startPoint, SIMD3(-5, 0, 0), "reversed start")
        expectPoint(reversed.endPoint, SIMD3(5, 0, 0), "reversed end")
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

    @Test func arcOfHyperbolaAcceptsMinorLargerThanMajor() throws {
        // A hyperbola puts no ordering on its radii; copying the ellipse rule would reject this.
        // (3 cosh u, 5 sinh u) over [0, 1]: it starts on the major axis at (3,0,0), and a swapped
        // pair would start at (5,0,0).
        let arc = try #require(
            Curve3D.arcOfHyperbola(
                center: Self.center, direction: Self.normal,
                majorRadius: 3, minorRadius: 5,
                alpha1: 0, alpha2: 1))
        #expect(abs(arc.domain.lowerBound) < 1e-12)
        #expect(abs(arc.domain.upperBound - 1) < 1e-12)
        expectPoint(arc.startPoint, hyperbolaPoint(3, 5, 0), "start")
        expectPoint(arc.point(at: 0.5), hyperbolaPoint(3, 5, 0.5), "interior")
        expectPoint(arc.endPoint, hyperbolaPoint(3, 5, 1), "end")

        // The same radii the usual way round, off the origin, so a dropped centre or a
        // reversed parameter range shows.
        let moved = try #require(
            Curve3D.arcOfHyperbola(
                center: Self.offCenter, direction: Self.normal,
                majorRadius: 5, minorRadius: 3,
                alpha1: 0.25, alpha2: 1))
        #expect(abs(moved.domain.lowerBound - 0.25) < 1e-12)
        #expect(abs(moved.domain.upperBound - 1) < 1e-12)
        expectPoint(moved.startPoint, hyperbolaPoint(5, 3, 0.25, at: Self.offCenter), "moved start")
        expectPoint(moved.endPoint, hyperbolaPoint(5, 3, 1, at: Self.offCenter), "moved end")

        // A -Z direction turns the branch's Y axis over: the same parameters, mirrored in Y
        // about the centre once the X axis has been re-derived.
        let flipped = try #require(
            Curve3D.arcOfHyperbola(
                center: Self.center, direction: -Self.normal,
                majorRadius: 5, minorRadius: 3,
                alpha1: 0, alpha2: 1))
        expectPoint(flipped.startPoint, SIMD3(-5, 0, 0), "flipped-normal start")
    }

    @Test func arcOfParabolaRejectsZeroFocalDistance() {
        // Measured before the guard: focal 0 gave a live arc that is a straight line along the
        // parabola's own axis of symmetry, which is what gp_Parab documents zero to mean.
        #expect(
            Curve3D.arcOfParabola(
                center: Self.center, direction: Self.normal,
                focalDistance: 0, alpha1: 0, alpha2: 1) == nil)
    }

    @Test func arcOfParabolaAcceptsPositiveFocalDistance() throws {
        // (u^2 / 8, u) for focal distance 2: the end of [0, 1] is (1/8, 1), where a doubled or
        // halved focal distance gives (1/16, 1) or (1/4, 1).
        let arc = try #require(
            Curve3D.arcOfParabola(
                center: Self.center, direction: Self.normal,
                focalDistance: 2, alpha1: 0, alpha2: 1))
        #expect(abs(arc.domain.lowerBound) < 1e-12)
        #expect(abs(arc.domain.upperBound - 1) < 1e-12)
        expectPoint(arc.startPoint, parabolaPoint(2, 0), "vertex")
        expectPoint(arc.point(at: 0.5), parabolaPoint(2, 0.5), "interior")
        expectPoint(arc.endPoint, parabolaPoint(2, 1), "end")

        // Off the origin, with a trimmed start.
        let moved = try #require(
            Curve3D.arcOfParabola(
                center: Self.offCenter, direction: Self.normal,
                focalDistance: 2, alpha1: 0.5, alpha2: 1))
        expectPoint(moved.startPoint, parabolaPoint(2, 0.5, at: Self.offCenter), "moved start")
        expectPoint(moved.endPoint, parabolaPoint(2, 1, at: Self.offCenter), "moved end")

        // sense false is the same arc reversed (the parameter range is negated, as it is for the
        // hyperbola): it starts where the forward arc ends.
        let reversed = try #require(
            Curve3D.arcOfParabola(
                center: Self.center, direction: Self.normal,
                focalDistance: 2, alpha1: 0, alpha2: 1, sense: false))
        expectPoint(reversed.startPoint, arc.endPoint, "reversed start")
        expectPoint(reversed.endPoint, arc.startPoint, "reversed end")

        // A -Z direction re-derives the X axis as -X, so the parabola opens the other way.
        let flipped = try #require(
            Curve3D.arcOfParabola(
                center: Self.center, direction: -Self.normal,
                focalDistance: 2, alpha1: 0, alpha2: 1))
        expectPoint(flipped.endPoint, SIMD3(-0.125, 1, 0), "flipped-normal end")
    }

    @Test func arcOfHyperbolaAndParabolaSenseReversesTheSameArc() throws {
        let h = try #require(
            Curve3D.arcOfHyperbola(
                center: Self.center, direction: Self.normal,
                majorRadius: 3, minorRadius: 5,
                alpha1: 0, alpha2: 1, sense: false))
        expectPoint(h.startPoint, hyperbolaPoint(3, 5, 1), "hyperbola reversed start")
        expectPoint(h.endPoint, hyperbolaPoint(3, 5, 0), "hyperbola reversed end")
    }

    // MARK: - GC_MakeEllipse / GC_MakeHyperbola (Curve3D.gc*)

    @Test func gcEllipseRejectsZeroRadii() throws {
        #expect(
            Curve3D.gcEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 0, minorRadius: 0) == nil)
        #expect(
            Curve3D.gcEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 0) == nil)
        // The negative and inverted cases the guard sits beside: measured, both refused.
        #expect(
            Curve3D.gcEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: -3) == nil)
        #expect(
            Curve3D.gcEllipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 3, minorRadius: 5) == nil)
        let e = try #require(
            Curve3D.gcEllipse(
                center: Self.offCenter, normal: Self.normal,
                majorRadius: 5, minorRadius: 3))
        expectPoint(e.point(at: 0), Self.offCenter + SIMD3(5, 0, 0), "major vertex")
        expectPoint(e.point(at: .pi / 2), Self.offCenter + SIMD3(0, 3, 0), "minor vertex")
        expectPoint(e.point(at: .pi), Self.offCenter + SIMD3(-5, 0, 0), "opposite major vertex")
    }

    @Test func gcEllipseFromFullAxisRejectsZeroRadii() throws {
        #expect(
            Curve3D.gcEllipse(
                center: Self.center, normal: Self.normal, xDirection: Self.xDir,
                majorRadius: 0, minorRadius: 0) == nil)
        #expect(
            Curve3D.gcEllipse(
                center: Self.center, normal: Self.normal, xDirection: Self.xDir,
                majorRadius: 5, minorRadius: 0) == nil)
        let e = try #require(
            Curve3D.gcEllipse(
                center: Self.center, normal: Self.normal, xDirection: Self.xDir,
                majorRadius: 5, minorRadius: 3))
        expectPoint(e.point(at: 0), SIMD3(5, 0, 0), "major vertex")
        expectPoint(e.point(at: .pi / 2), SIMD3(0, 3, 0), "minor vertex")
        // The X direction is what this overload adds: pointing it along Y puts the major axis
        // there, about an off-origin centre.
        let turned = try #require(
            Curve3D.gcEllipse(
                center: Self.offCenter, normal: Self.normal, xDirection: SIMD3(0, 1, 0),
                majorRadius: 5, minorRadius: 3))
        expectPoint(turned.point(at: 0), Self.offCenter + SIMD3(0, 5, 0), "major vertex along Y")
        expectPoint(turned.point(at: .pi / 2), Self.offCenter + SIMD3(-3, 0, 0), "minor vertex")
    }

    @Test func gcHyperbolaRejectsZeroRadii() throws {
        #expect(
            Curve3D.gcHyperbola(
                center: Self.center, normal: Self.normal,
                majorRadius: 0, minorRadius: 0) == nil)
        #expect(
            Curve3D.gcHyperbola(
                center: Self.center, normal: Self.normal,
                majorRadius: 0, minorRadius: 5) == nil)
        let h = try #require(
            Curve3D.gcHyperbola(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 3))
        expectPoint(h.point(at: 0), SIMD3(5, 0, 0), "vertex")
        expectPoint(h.point(at: 1), hyperbolaPoint(5, 3, 1), "interior")
        // No ordering between the radii, and an off-origin centre is carried through.
        let wide = try #require(
            Curve3D.gcHyperbola(
                center: Self.offCenter, normal: Self.normal,
                majorRadius: 3, minorRadius: 5))
        expectPoint(wide.point(at: 0), hyperbolaPoint(3, 5, 0, at: Self.offCenter), "vertex")
        expectPoint(wide.point(at: 1), hyperbolaPoint(3, 5, 1, at: Self.offCenter), "interior")
    }

    /// Control for the two three-point forms, which are deliberately *not* guarded: they take no
    /// dimension at all, and OCCT's own `GC_Make*` status already rejects a degenerate triple.
    ///
    /// If that ever stops being true, this test is where it shows up.
    @Test func gcThreePointFormsRejectDegeneratePointTriplesWithoutABridgeGuard() throws {
        let origin = SIMD3<Double>(0, 0, 0)
        #expect(Curve3D.gcEllipse(s1: origin, s2: origin, center: origin) == nil)
        // S2 on the major axis leaves no minor radius to derive.
        #expect(Curve3D.gcEllipse(s1: SIMD3(5, 0, 0), s2: SIMD3(2, 0, 0), center: origin) == nil)
        #expect(Curve3D.gcHyperbola(s1: origin, s2: origin, center: origin) == nil)
        // ... and the healthy triple still builds, with S1 on the major axis and S2 on the minor.
        let e = try #require(
            Curve3D.gcEllipse(s1: SIMD3(5, 0, 0), s2: SIMD3(0, 3, 0), center: origin))
        expectPoint(e.point(at: 0), SIMD3(5, 0, 0), "S1 is the major vertex")
        expectPoint(e.point(at: .pi / 2), SIMD3(0, 3, 0), "S2 is the minor vertex")

        // Off the origin, so a centre the bridge dropped is not the answer: S1 is the major vertex,
        // the minor radius is S2's distance from the major axis (measured 5 and 3), and the third
        // argument is where the curve is centred.
        let c = SIMD3<Double>(1, 2, 3)
        let shifted = try #require(
            Curve3D.gcEllipse(s1: SIMD3(6, 2, 3), s2: SIMD3(1, 5, 3), center: c))
        #expect(abs(shifted.ellipseProperties.majorRadius - 5) < 1e-9)
        #expect(abs(shifted.ellipseProperties.minorRadius - 3) < 1e-9)
        expectPoint(shifted.point(at: 0), SIMD3(6, 2, 3), "shifted: S1 is the major vertex")
        expectPoint(shifted.point(at: .pi / 2), SIMD3(1, 5, 3), "shifted: S2 is the minor vertex")
        expectPoint(shifted.point(at: .pi), SIMD3(-4, 2, 3), "shifted: the far major vertex")

        // The hyperbola takes the same three points the same way. S2 only sets the minor radius,
        // through its distance from the axis, so moving it along the axis changes nothing.
        let hyp = try #require(
            Curve3D.gcHyperbola(s1: SIMD3(6, 2, 3), s2: SIMD3(1, 5, 3), center: c))
        #expect(abs(hyp.hyperbolaProperties.majorRadius - 5) < 1e-9)
        #expect(abs(hyp.hyperbolaProperties.minorRadius - 3) < 1e-9)
        expectPoint(hyp.point(at: 0), SIMD3(6, 2, 3), "hyperbola: S1 is the vertex")
        expectPoint(hyp.point(at: 1), hyperbolaPoint(5, 3, 1, at: c), "hyperbola: interior")
        let slid = try #require(
            Curve3D.gcHyperbola(s1: SIMD3(6, 2, 3), s2: SIMD3(3, 5, 3), center: c))
        expectPoint(
            slid.point(at: 1), hyperbolaPoint(5, 3, 1, at: c), "hyperbola: S2 slid along the axis")
    }

    // MARK: - BRepBuilderAPI_MakeEdge (Shape.edgeFrom*)

    /// The one edge of a shape a factory built, with its curve type.
    private func theEdge(_ shape: Shape?, _ what: String) throws -> Edge {
        let built = try #require(shape, "\(what) returned nil")
        let edges = built.edges(where: { _ in true })
        #expect(edges.count == 1, "\(what): one edge")
        return try #require(edges.first, "\(what): no edge")
    }

    @Test func edgeFromEllipseRejectsZeroRadii() throws {
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
        // The perimeter of (5 cos u, 3 sin u), integrated here rather than read from the kernel,
        // and the extreme points of the loop. A swapped pair has the same perimeter, so the
        // quarter-turn point is what tells the axes apart.
        let edge = try theEdge(
            Shape.edgeFromEllipse(
                center: Self.offCenter, normal: Self.normal,
                majorRadius: 5, minorRadius: 3), "edgeFromEllipse")
        #expect(edge.curveType == .ellipse)
        let perimeter = simpson(
            { u in hypot(5 * Foundation.sin(u), 3 * Foundation.cos(u)) }, 0, 2 * .pi)
        #expect(abs(edge.length - perimeter) < 1e-6, "perimeter \(edge.length) vs \(perimeter)")
        if let bounds = edge.parameterBounds {
            #expect(abs(bounds.first) < 1e-12)
            #expect(abs(bounds.last - 2 * .pi) < 1e-12)
            if let apex = edge.point(at: .pi / 2) {
                expectPoint(apex, Self.offCenter + SIMD3(0, 3, 0), "minor-axis apex")
            } else {
                Issue.record("no point at pi/2")
            }
        } else {
            Issue.record("the ellipse edge has no parameter bounds")
        }
        expectPoint(
            edge.endpoints.start, Self.offCenter + SIMD3(5, 0, 0), "start on the major axis")
    }

    @Test func edgeFromEllipseArcRejectsZeroRadii() throws {
        #expect(
            Shape.edgeFromEllipseArc(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 0, u1: 0, u2: .pi) == nil)
        // Half the perimeter of (5 cos u, 3 sin u): the arc from the major vertex to the
        // opposite one through (0, 3, 0).
        let edge = try theEdge(
            Shape.edgeFromEllipseArc(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 3, u1: 0, u2: .pi), "edgeFromEllipseArc")
        #expect(edge.curveType == .ellipse)
        let half = simpson({ u in hypot(5 * Foundation.sin(u), 3 * Foundation.cos(u)) }, 0, .pi)
        #expect(abs(edge.length - half) < 1e-6, "half perimeter \(edge.length) vs \(half)")
        expectPoint(edge.endpoints.start, SIMD3(5, 0, 0), "start")
        expectPoint(edge.endpoints.end, SIMD3(-5, 0, 0), "end")
        if let apex = edge.point(at: .pi / 2) {
            expectPoint(apex, SIMD3(0, 3, 0), "apex")
        } else {
            Issue.record("no point at pi/2")
        }
        // A quarter arc pins both parameter bounds apart: u1 = 0.5, u2 = 1.25.
        let quarter = try theEdge(
            Shape.edgeFromEllipseArc(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 3, u1: 0.5, u2: 1.25), "trimmed arc")
        expectPoint(quarter.endpoints.start, ellipsePoint(5, 3, 0.5), "trimmed start")
        expectPoint(quarter.endpoints.end, ellipsePoint(5, 3, 1.25), "trimmed end")
    }

    @Test func edgeFromHyperbolaArcRejectsZeroRadii() throws {
        #expect(
            Shape.edgeFromHyperbolaArc(
                center: Self.center, normal: Self.normal,
                majorRadius: 0, minorRadius: 0, u1: 0, u2: 1) == nil)
        #expect(
            Shape.edgeFromHyperbolaArc(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 0, u1: 0, u2: 1) == nil)
        let edge = try theEdge(
            Shape.edgeFromHyperbolaArc(
                center: Self.offCenter, normal: Self.normal,
                majorRadius: 5, minorRadius: 3, u1: 0.25, u2: 1), "edgeFromHyperbolaArc")
        #expect(edge.curveType == .hyperbola)
        let length = simpson(
            { u in hypot(5 * Foundation.sinh(u), 3 * Foundation.cosh(u)) }, 0.25, 1)
        #expect(abs(edge.length - length) < 1e-6, "arc length \(edge.length) vs \(length)")
        expectPoint(
            edge.endpoints.start, hyperbolaPoint(5, 3, 0.25, at: Self.offCenter), "start")
        expectPoint(edge.endpoints.end, hyperbolaPoint(5, 3, 1, at: Self.offCenter), "end")
        // No ordering between the radii: minor above major builds, with its own end point.
        let wide = try theEdge(
            Shape.edgeFromHyperbolaArc(
                center: Self.center, normal: Self.normal,
                majorRadius: 3, minorRadius: 5, u1: 0, u2: 1), "minor above major")
        expectPoint(wide.endpoints.start, SIMD3(3, 0, 0), "wide start")
        expectPoint(wide.endpoints.end, hyperbolaPoint(3, 5, 1), "wide end")
    }

    @Test func edgeFromParabolaArcRejectsZeroFocalLength() throws {
        #expect(
            Shape.edgeFromParabolaArc(
                center: Self.center, normal: Self.normal,
                focalLength: 0, u1: 0, u2: 1) == nil)
        let edge = try theEdge(
            Shape.edgeFromParabolaArc(
                center: Self.offCenter, normal: Self.normal,
                focalLength: 2, u1: 0, u2: 1), "edgeFromParabolaArc")
        #expect(edge.curveType == .parabola)
        // Arc length of (u^2/8, u): the integral of sqrt((u/4)^2 + 1).
        let length = simpson({ u in (u * u / 16 + 1).squareRoot() }, 0, 1)
        #expect(abs(edge.length - length) < 1e-6, "arc length \(edge.length) vs \(length)")
        expectPoint(edge.endpoints.start, parabolaPoint(2, 0, at: Self.offCenter), "start")
        expectPoint(edge.endpoints.end, parabolaPoint(2, 1, at: Self.offCenter), "end")
    }

    // MARK: - Extrema_ExtElC / Extrema_ExtPElC

    /// The results sorted by squared distance, since the order a solver reports them in is not
    /// something the call promises.
    private func bySquareDistance(_ results: [ExtremaResult]) -> [ExtremaResult] {
        results.sorted { $0.squareDistance < $1.squareDistance }
    }

    /// These are solver inputs, which #553 excluded from the 2D pass on the grounds that a
    /// degenerate conic can still be a meaningful question.
    ///
    /// Measured here, it is not: OCCT does
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
        // The healthy ellipse still answers, with the near and far extremum. From (10, 0, 0) to
        // (5 cos u, 3 sin u) the squared distance is (10 - 5 cos u)^2 + 9 sin^2 u, whose
        // derivative is sin u (50 - 7 cos u): the only critical points are u = 0 (squared
        // distance 25) and u = pi (225).
        let found = bySquareDistance(
            ExtremaPointCurve.pointToEllipse(
                point: SIMD3(10, 0, 0),
                center: Self.center, normal: Self.normal,
                xDir: Self.xDir,
                majorRadius: 5, minorRadius: 3))
        #expect(found.count == 2)
        if found.count == 2 {
            #expect(abs(found[0].squareDistance - 25) < 1e-9)
            #expect(abs(found[1].squareDistance - 225) < 1e-9)
            #expect(found.allSatisfy { !$0.isParallel })
            // point1 is the query point, point2 the point on the ellipse.
            expectPoint(found[0].point1 ?? .zero, SIMD3(10, 0, 0), "near: query point")
            expectPoint(found[0].point2 ?? .zero, SIMD3(5, 0, 0), "near: on the ellipse")
            expectPoint(found[1].point1 ?? .zero, SIMD3(10, 0, 0), "far: query point")
            expectPoint(found[1].point2 ?? .zero, SIMD3(-5, 0, 0), "far: on the ellipse")
        }
    }

    @Test func pointToParabolaRejectsZeroFocalDistance() {
        #expect(
            ExtremaPointCurve.pointToParabola(
                point: SIMD3(10, 0, 0),
                center: Self.center, normal: Self.normal,
                xDir: Self.xDir, focal: 0
            ).isEmpty)
        // Focal 2 is y^2 = 8x, traced (u^2/8, u). The squared distance from (10, 0, 0) is
        // (10 - u^2/8)^2 + u^2, with derivative u (u^2/16 - 3): u = 0 (squared distance 100,
        // at the vertex) and u = +-sqrt 48 (squared distance 64, at (6, +-sqrt 48)).
        let found = bySquareDistance(
            ExtremaPointCurve.pointToParabola(
                point: SIMD3(10, 0, 0),
                center: Self.center, normal: Self.normal,
                xDir: Self.xDir, focal: 2))
        #expect(found.count == 3)
        if found.count == 3 {
            #expect(abs(found[0].squareDistance - 64) < 1e-9)
            #expect(abs(found[1].squareDistance - 64) < 1e-9)
            #expect(abs(found[2].squareDistance - 100) < 1e-9)
            expectPoint(found[2].point2 ?? .zero, SIMD3(0, 0, 0), "vertex")
            let onCurve = found[0...1].compactMap { $0.point2 }.sorted { $0.y < $1.y }
            #expect(onCurve.count == 2)
            if onCurve.count == 2 {
                expectPoint(onCurve[0], SIMD3(6, -48.0.squareRoot(), 0), "lower extremum")
                expectPoint(onCurve[1], SIMD3(6, 48.0.squareRoot(), 0), "upper extremum")
            }
            #expect(found.allSatisfy { !$0.isParallel })
            #expect(found.allSatisfy { ($0.point1 ?? .zero) == SIMD3(10, 0, 0) })
        }
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
        // The line is (t, 0, 10 + t), in the plane y = 0 at 45 degrees; the ellipse is
        // (5 cos u, 3 sin u, 0). The squared distance from the ellipse point to the line is
        // (5 cos u + 10)^2 / 2 + 9 sin^2 u, with derivative sin u (-7 cos u - 50): the critical
        // points are u = 0 (squared distance 112.5, line foot (-2.5, 0, 7.5)) and u = pi
        // (12.5, line foot (-7.5, 0, 2.5)).
        let found = bySquareDistance(
            ExtremaElC.lineToEllipse(
                linePoint: linePoint, lineDir: lineDir,
                center: Self.center, normal: Self.normal, xDir: Self.xDir,
                majorRadius: 5, minorRadius: 3))
        #expect(found.count == 2)
        if found.count == 2 {
            #expect(abs(found[0].squareDistance - 12.5) < 1e-9)
            #expect(abs(found[1].squareDistance - 112.5) < 1e-9)
            #expect(found.allSatisfy { !$0.isParallel })
            // point1 is on the line, point2 on the ellipse.
            expectPoint(found[0].point1 ?? .zero, SIMD3(-7.5, 0, 2.5), "near: on the line")
            expectPoint(found[0].point2 ?? .zero, SIMD3(-5, 0, 0), "near: on the ellipse")
            expectPoint(found[1].point1 ?? .zero, SIMD3(-2.5, 0, 7.5), "far: on the line")
            expectPoint(found[1].point2 ?? .zero, SIMD3(5, 0, 0), "far: on the ellipse")
        }
    }

    // MARK: - Geom_* setters, which degrade a healthy curve in place

    @Test func ellipseSetMinorRadiusRejectsZero() throws {
        let e = try #require(
            Curve3D.ellipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 3))
        // Measured before the guard: accepted, leaving a live Geom_Ellipse with minorRadius 0
        // that evaluates onto its own major axis.
        #expect(e.ellipseProperties.setMinorRadius(0) == false)
        // A refusal changes nothing: neither radius, and not the geometry.
        #expect(e.ellipseProperties.minorRadius == 3)
        #expect(e.ellipseProperties.majorRadius == 5)
        expectPoint(e.point(at: .pi / 2), SIMD3(0, 3, 0), "after the refused zero")
        #expect(e.ellipseProperties.setMinorRadius(-1) == false)
        #expect(e.ellipseProperties.minorRadius == 3)
        // An accepted one changes the minor radius and the curve, and only the minor radius.
        #expect(e.ellipseProperties.setMinorRadius(2) == true)
        #expect(e.ellipseProperties.minorRadius == 2)
        #expect(e.ellipseProperties.majorRadius == 5)
        expectPoint(e.point(at: .pi / 2), SIMD3(0, 2, 0), "after the accepted 2")
        expectPoint(e.point(at: 0), SIMD3(5, 0, 0), "the major vertex does not move")
    }

    @Test func ellipseSetMajorRadiusKeepsThePairValid() throws {
        let e = try #require(
            Curve3D.ellipse(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 3))
        // Below the current minor radius, which Geom_Ellipse's own hand-written throw already
        // rejected. Kept as a control on the new pairwise check.
        #expect(e.ellipseProperties.setMajorRadius(1) == false)
        #expect(e.ellipseProperties.setMajorRadius(0) == false)
        #expect(e.ellipseProperties.majorRadius == 5)
        #expect(e.ellipseProperties.minorRadius == 3)
        expectPoint(e.point(at: 0), SIMD3(5, 0, 0), "after the refusals")
        #expect(e.ellipseProperties.setMajorRadius(9) == true)
        #expect(e.ellipseProperties.majorRadius == 9)
        #expect(e.ellipseProperties.minorRadius == 3)
        expectPoint(e.point(at: 0), SIMD3(9, 0, 0), "after the accepted 9")
        expectPoint(e.point(at: .pi / 2), SIMD3(0, 3, 0), "the minor vertex does not move")
        // The boundary of the pair rule: a major equal to the minor is a circle, and measured
        // accepted, so a check written as `<=` would refuse it.
        #expect(e.ellipseProperties.setMajorRadius(3) == true)
        #expect(e.ellipseProperties.majorRadius == 3)
    }

    @Test func hyperbolaSettersRejectZero() throws {
        let h = try #require(
            Curve3D.hyperbola(
                center: Self.center, normal: Self.normal,
                majorRadius: 5, minorRadius: 3))
        #expect(h.hyperbolaProperties.setMajorRadius(0) == false)
        #expect(h.hyperbolaProperties.setMinorRadius(0) == false)
        #expect(h.hyperbolaProperties.setMajorRadius(-1) == false)
        #expect(h.hyperbolaProperties.setMinorRadius(-1) == false)
        #expect(h.hyperbolaProperties.majorRadius == 5)
        #expect(h.hyperbolaProperties.minorRadius == 3)
        expectPoint(h.point(at: 1), hyperbolaPoint(5, 3, 1), "after the refusals")
        // No ordering constraint, so a minor above the major is still accepted.
        #expect(h.hyperbolaProperties.setMinorRadius(8) == true)
        #expect(h.hyperbolaProperties.minorRadius == 8)
        #expect(h.hyperbolaProperties.majorRadius == 5)
        expectPoint(h.point(at: 1), hyperbolaPoint(5, 8, 1), "after the accepted minor 8")
        // The major setter accepts a positive value too, and moves only the major radius.
        #expect(h.hyperbolaProperties.setMajorRadius(2) == true)
        #expect(h.hyperbolaProperties.majorRadius == 2)
        #expect(h.hyperbolaProperties.minorRadius == 8)
        expectPoint(h.point(at: 0), SIMD3(2, 0, 0), "after the accepted major 2")
    }

    @Test func parabolaSetFocalRejectsZero() throws {
        let p = try #require(
            Curve3D.parabola(center: Self.center, normal: Self.normal, focal: 2))
        #expect(p.parabolaProperties.setFocal(0) == false)
        #expect(p.parabolaProperties.setFocal(-1) == false)
        #expect(p.parabolaProperties.focal == 2)
        expectPoint(p.point(at: 1), parabolaPoint(2, 1), "after the refusals")
        #expect(p.parabolaProperties.setFocal(6) == true)
        #expect(p.parabolaProperties.focal == 6)
        expectPoint(p.point(at: 1), parabolaPoint(6, 1), "after the accepted 6")
    }

    @Test func circleSetRadiusRejectsZero() throws {
        let c = try #require(Curve3D.circle(center: Self.center, normal: Self.normal, radius: 5))
        #expect(c.circleProperties.setRadius(0) == false)
        #expect(c.circleProperties.setRadius(-1) == false)
        #expect(c.circleProperties.radius == 5)
        expectPoint(c.point(at: 0), SIMD3(5, 0, 0), "after the refusals")
        #expect(c.circleProperties.setRadius(7) == true)
        #expect(c.circleProperties.radius == 7)
        expectPoint(c.point(at: 0), SIMD3(7, 0, 0), "after the accepted 7")
    }

    // MARK: - The two families deliberately left alone

    /// `BndLib` and `ElCLib` take the same dimensions and are deliberately not guarded: both are
    /// pure queries that return the *correct* answer for the degenerate curve, and both are
    /// `void` bridge functions with nowhere to report a rejection.
    ///
    /// Pinned so the exclusion is a
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
