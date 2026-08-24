import Foundation
import Testing

@testable import OCCTSwift

/// #514: the nine 2D conic construction sites that build a conic from caller-supplied
/// dimensions. Before this pass every one of them accepted a zero dimension and returned
/// something that reads as geometry and behaves as a point, a segment, or NaN.
///
/// The negative and ordering cases are covered too, because the issue's premise was that these
/// sites had "no precondition at all". They do: `gp_Elips2d`/`gp_Hypr2d`/`gp_Parab2d`'s own
/// `Standard_ConstructionError_Raise_if` is `constexpr` in the header, so unlike a call made from
/// inside OCCT (where `No_Exception` deletes it) it does run in a bridge translation unit. What it
/// never covered is zero, which is the whole of the real gap.
@Suite("Issue514 2D conic degenerate dimensions")
struct Issue514Conic2dDegenerateTests {

    // MARK: - Convert_*ToBSplineCurve (Curve2D.from*Arc)

    @Test func ellipseArcRejectsZeroRadii() {
        #expect(
            Curve2D.fromEllipseArc(
                centerX: 0, centerY: 0,
                majorRadius: 0, minorRadius: 0, u1: 0, u2: .pi) == nil)
        // Zero minor alone collapses the ellipse onto its own major axis: measured, the
        // conversion succeeded and produced a degree-2 BSpline running 5,0 -> 0,0 -> -5,0.
        #expect(
            Curve2D.fromEllipseArc(
                centerX: 0, centerY: 0,
                majorRadius: 5, minorRadius: 0, u1: 0, u2: .pi) == nil)
    }

    @Test func ellipseArcRejectsNegativeAndInvertedRadii() {
        #expect(
            Curve2D.fromEllipseArc(
                centerX: 0, centerY: 0,
                majorRadius: 5, minorRadius: -3, u1: 0, u2: .pi) == nil)
        #expect(
            Curve2D.fromEllipseArc(
                centerX: 0, centerY: 0,
                majorRadius: 3, minorRadius: 5, u1: 0, u2: .pi) == nil)
    }

    @Test func ellipseArcAcceptsValidRadii() {
        #expect(
            Curve2D.fromEllipseArc(
                centerX: 0, centerY: 0,
                majorRadius: 5, minorRadius: 3, u1: 0, u2: .pi) != nil)
        // Equal radii are a circle, which gp_Elips2d documents as valid.
        #expect(
            Curve2D.fromEllipseArc(
                centerX: 0, centerY: 0,
                majorRadius: 4, minorRadius: 4, u1: 0, u2: .pi) != nil)
    }

    @Test func hyperbolaArcRejectsZeroRadii() {
        #expect(
            Curve2D.fromHyperbolaArc(
                centerX: 0, centerY: 0,
                majorRadius: 0, minorRadius: 0, u1: 0, u2: 1) == nil)
        #expect(
            Curve2D.fromHyperbolaArc(
                centerX: 0, centerY: 0,
                majorRadius: 5, minorRadius: 0, u1: 0, u2: 1) == nil)
        #expect(
            Curve2D.fromHyperbolaArc(
                centerX: 0, centerY: 0,
                majorRadius: 0, minorRadius: 3, u1: 0, u2: 1) == nil)
    }

    @Test func hyperbolaArcAcceptsMinorLargerThanMajor() {
        // A hyperbola puts no ordering on its radii: minor > major is an ordinary hyperbola.
        // Copying the ellipse rule here would reject it.
        #expect(
            Curve2D.fromHyperbolaArc(
                centerX: 0, centerY: 0,
                majorRadius: 3, minorRadius: 5, u1: 0, u2: 1) != nil)
    }

    @Test func parabolaArcRejectsZeroFocal() {
        // Worst of the nine: measured, focal 0 produced a 3-pole degree-2 BSpline whose poles
        // are NaN, so every downstream evaluation of it is NaN too.
        #expect(Curve2D.fromParabolaArc(centerX: 0, centerY: 0, focal: 0, u1: 0, u2: 1) == nil)
    }

    @Test func parabolaArcAcceptsPositiveFocal() {
        #expect(Curve2D.fromParabolaArc(centerX: 0, centerY: 0, focal: 2, u1: 0, u2: 1) != nil)
    }

    @Test func circleArcRejectsZeroRadius() {
        #expect(Curve2D.fromCircleArc(centerX: 0, centerY: 0, radius: 0, u1: 0, u2: .pi) == nil)
        #expect(Curve2D.fromCircleArc(centerX: 0, centerY: 0, radius: 3, u1: 0, u2: .pi) != nil)
    }

    // MARK: - BRepLib_MakeEdge2d (Shape.edge2d*)

    @Test func edge2dEllipseRejectsZeroRadii() {
        // BRepLib_MakeEdge2d reports IsDone() for both of these. Measured: the first builds a
        // zero-length edge with both vertices at the centre, the second a doubled-back segment.
        #expect(
            Shape.edge2dEllipse(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                majorRadius: 0, minorRadius: 0) == nil)
        #expect(
            Shape.edge2dEllipse(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                majorRadius: 5, minorRadius: 0) == nil)
    }

    @Test func edge2dEllipseArcRejectsZeroRadii() {
        #expect(
            Shape.edge2dEllipseArc(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                majorRadius: 0, minorRadius: 0, u1: 0, u2: .pi) == nil)
        #expect(
            Shape.edge2dEllipseArc(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                majorRadius: 5, minorRadius: 0, u1: 0, u2: .pi) == nil)
    }

    @Test func edge2dFullCircleRejectsZeroRadius() {
        #expect(
            Shape.edge2dFullCircle(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                radius: 0) == nil)
    }

    @Test func edge2dConstructorsAcceptValidDimensions() {
        #expect(
            Shape.edge2dEllipse(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                majorRadius: 5, minorRadius: 3) != nil)
        #expect(
            Shape.edge2dEllipseArc(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                majorRadius: 5, minorRadius: 3, u1: 0, u2: .pi) != nil)
        #expect(
            Shape.edge2dFullCircle(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                radius: 5) != nil)
    }

    // MARK: - IntAna2d_Conic (Conic2D)

    @Test func conicEllipseRejectsZeroRadii() {
        // All six coefficients came back 0, which is the equation 0 = 0: satisfied by every
        // point in the plane, and indistinguishable from the value the catch block writes.
        #expect(
            Conic2D.ellipse(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                majorRadius: 0, minorRadius: 0) == nil)
        #expect(
            Conic2D.ellipse(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                majorRadius: 5, minorRadius: 0) == nil)
    }

    @Test func conicCircleRejectsZeroRadius() {
        #expect(Conic2D.circle(center: SIMD2(0, 0), direction: SIMD2(1, 0), radius: 0) == nil)
    }

    @Test func conicRejectsZeroDirection() {
        // gp_Dir2d(0, 0) throws; before the nil channel existed this returned the same all-zero
        // struct as a degenerate ellipse did.
        #expect(Conic2D.circle(center: SIMD2(0, 0), direction: SIMD2(0, 0), radius: 5) == nil)
        #expect(Conic2D.line(point: SIMD2(0, 0), direction: SIMD2(0, 0)) == nil)
        #expect(
            Conic2D.ellipse(
                center: SIMD2(0, 0), direction: SIMD2(0, 0),
                majorRadius: 5, minorRadius: 3) == nil)
    }

    /// The coefficient order is OCCT's: `A·x² + B·y² + 2C·xy + 2D·x + 2E·y + F = 0`. The Swift
    /// doc comment used to name a different equation (`A·x² + B·xy + C·y² + …`), which puts the
    /// xy term in `b` and the y² term in `c`, so a caller reading it built the wrong conic.
    @Test func conicCoefficientOrderIsOCCTs() {
        guard let c = Conic2D.circle(center: SIMD2(0, 0), direction: SIMD2(1, 0), radius: 5) else {
            Issue.record("circle conic should build")
            return
        }
        // x² + y² - 25 = 0
        #expect(abs(c.a - 1) < 1e-9)
        #expect(abs(c.b - 1) < 1e-9)  // y², not xy
        #expect(abs(c.c) < 1e-9)  // xy, not y²
        #expect(abs(c.f + 25) < 1e-9)

        guard
            let e = Conic2D.ellipse(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                majorRadius: 5, minorRadius: 3)
        else {
            Issue.record("ellipse conic should build")
            return
        }
        // x²/25 + y²/9 - 1 = 0
        #expect(abs(e.a - 1.0 / 25.0) < 1e-9)
        #expect(abs(e.b - 1.0 / 9.0) < 1e-9)
        #expect(abs(e.c) < 1e-9)
        #expect(abs(e.f + 1) < 1e-9)
    }

    @Test func conicLineIsUnchangedForValidInput() {
        guard let l = Conic2D.line(point: SIMD2(0, 0), direction: SIMD2(1, 0)) else {
            Issue.record("line conic should build")
            return
        }
        let magnitude = abs(l.a) + abs(l.b) + abs(l.c) + abs(l.d) + abs(l.e) + abs(l.f)
        #expect(magnitude > 0)
    }

    @Test func lineCircleIntersectionRejectsZeroRadius() {
        #expect(
            Conic2D.lineCircleIntersection(
                linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0),
                circleCenter: SIMD2(0, 0), circleDir: SIMD2(1, 0), radius: 0
            ).isEmpty)
        #expect(
            Conic2D.lineCircleIntersection(
                linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0),
                circleCenter: SIMD2(0, 0), circleDir: SIMD2(1, 0), radius: 5
            ).count == 2)
    }
}
