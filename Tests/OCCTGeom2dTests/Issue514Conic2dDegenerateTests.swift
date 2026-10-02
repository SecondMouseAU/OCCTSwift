import Foundation
import Testing
import simd

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

    @Test func ellipseArcAcceptsValidRadii() throws {
        // #1979: `!= nil` only. Each arc now pins the endpoints Convert_EllipseToBSplineCurve
        // gives (Scripts/repro/766-geom2d-conic-degenerate/).
        let e = try #require(
            Curve2D.fromEllipseArc(
                centerX: 0, centerY: 0,
                majorRadius: 5, minorRadius: 3, u1: 0, u2: .pi))
        #expect(simd_distance(e.startPoint, SIMD2(5, 0)) < 1e-9)
        #expect(simd_distance(e.endPoint, SIMD2(-5, 0)) < 1e-9)
        // Equal radii are a circle, which gp_Elips2d documents as valid.
        let c = try #require(
            Curve2D.fromEllipseArc(
                centerX: 0, centerY: 0,
                majorRadius: 4, minorRadius: 4, u1: 0, u2: .pi))
        #expect(simd_distance(c.startPoint, SIMD2(4, 0)) < 1e-9)
        #expect(simd_distance(c.endPoint, SIMD2(-4, 0)) < 1e-9)
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

    @Test func hyperbolaArcAcceptsMinorLargerThanMajor() throws {
        // A hyperbola puts no ordering on its radii: minor > major is an ordinary hyperbola.
        // Copying the ellipse rule here would reject it.
        let h = try #require(
            Curve2D.fromHyperbolaArc(
                centerX: 0, centerY: 0,
                majorRadius: 3, minorRadius: 5, u1: 0, u2: 1))
        // #1979: `!= nil` only. The arc runs (3, 0) to (3 cosh 1, 5 sinh 1).
        #expect(simd_distance(h.startPoint, SIMD2(3, 0)) < 1e-9)
        #expect(simd_distance(h.endPoint, SIMD2(4.62924190445, 5.87600596822)) < 1e-9)
    }

    @Test func parabolaArcRejectsZeroFocal() {
        // Worst of the nine: measured, focal 0 produced a 3-pole degree-2 BSpline whose poles
        // are NaN, so every downstream evaluation of it is NaN too.
        #expect(Curve2D.fromParabolaArc(centerX: 0, centerY: 0, focal: 0, u1: 0, u2: 1) == nil)
    }

    @Test func parabolaArcAcceptsPositiveFocal() throws {
        // #1979: `!= nil` only. The arc runs (0, 0) to (u^2 / 4f, u) = (0.125, 1).
        let p = try #require(Curve2D.fromParabolaArc(centerX: 0, centerY: 0, focal: 2, u1: 0, u2: 1))
        #expect(simd_distance(p.startPoint, SIMD2(0, 0)) < 1e-9)
        #expect(simd_distance(p.endPoint, SIMD2(0.125, 1)) < 1e-9)
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
    @Test func conicCoefficientOrderIsOCCTs() throws {
        let c = try #require(Conic2D.circle(center: SIMD2(0, 0), direction: SIMD2(1, 0), radius: 5))
        // x² + y² - 25 = 0
        #expect(abs(c.a - 1) < 1e-9)
        #expect(abs(c.b - 1) < 1e-9)  // y², not xy
        #expect(abs(c.c) < 1e-9)  // xy, not y²
        #expect(abs(c.f + 25) < 1e-9)

        let e = try #require(
            Conic2D.ellipse(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                majorRadius: 5, minorRadius: 3))
        // x²/25 + y²/9 - 1 = 0
        #expect(abs(e.a - 1.0 / 25.0) < 1e-9)
        #expect(abs(e.b - 1.0 / 9.0) < 1e-9)
        #expect(abs(e.c) < 1e-9)
        #expect(abs(e.f + 1) < 1e-9)
    }

    @Test func conicLineIsUnchangedForValidInput() throws {
        // #1979: asserted only that some coefficient was non-zero. IntAna2d_Conic of the x-axis
        // is 2E·y = 0 with E = -1 and every other coefficient 0.
        let l = try #require(Conic2D.line(point: SIMD2(0, 0), direction: SIMD2(1, 0)))
        // A five-term `abs(...) + ...` inside `#expect` exceeds the type-checker's time budget on the
        // CI toolchain (Xcode 26.3), though newer compilers accept it, so sum over an array instead.
        let otherCoefficients: [Double] = [l.a, l.b, l.c, l.d, l.f]
        let coefficientSum: Double = otherCoefficients.reduce(0) { $0 + abs($1) }
        #expect(coefficientSum < 1e-12)
        #expect(abs(l.e + 1) < 1e-12)
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
