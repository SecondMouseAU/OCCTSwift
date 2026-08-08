import Testing
import Foundation
@testable import OCCTSwift

/// #791 (the #784 duplication rescan): `OCCTConvertCircleToBSpline2D` reimplemented the
/// pole/weight/knot-array-building sequence that `buildCurve2DFromConic` already provides and
/// that its siblings (`OCCTConvertEllipseToBSpline2D`, `OCCTConvertHyperbolaToBSpline2D`,
/// `OCCTConvertParabolaToBSpline2D`) already call. `Convert_CircleToBSplineCurve` genuinely
/// inherits `Convert_ConicToBSplineCurve` publicly, and every accessor `buildCurve2DFromConic`
/// calls (`NbPoles`/`NbKnots`/`Degree`/`Pole`/`Weight`/`Knot`/`Multiplicity`) is declared on that
/// base class, confirmed by reading the bundled
/// `Convert_CircleToBSplineCurve.hxx`/`Convert_ConicToBSplineCurve.hxx` headers directly (the OCCT
/// refman is not indexed in `context` for this repo; `okf/policies/context-first.md` names the
/// bundled headers as the fallback), not assumed from the issue body. So the fix is a drop-in
/// call: `return buildCurve2DFromConic(conv);`.
///
/// These tests prove the consolidation changed nothing observable, two ways:
///
/// 1. **Exact baseline equality.** `fullCircleOriginPoles`/`offsetArcPoles` below are a verbatim
///    capture of `Curve2D.fromCircleArc`'s output from the UNMODIFIED, pre-#791 inline
///    implementation (captured by a throwaway test run before the `.mm` edit landed, per
///    `okf/policies/measure-dont-assume.md`, not reconstructed after the fact). Every pole and
///    weight is the OCCT converter's own computed value, independent of which C++ function copies
///    it into the output arrays, so exact `==` is the right comparison: a regression here would be
///    a transcription bug (wrong loop bound, wrong accessor), not a rounding difference.
/// 2. **An implementation-independent geometric invariant.** Every sampled point on the returned
///    BSpline curve must sit at exactly `radius` from the circle's own center, true by the
///    definition of a circle, regardless of pole/knot layout. This is the same contract
///    `buildCurve2DFromConic`'s three existing callers (Ellipse/Hyperbola/Parabola) already rely
///    on for their own conic, so Circle satisfying it through the now-shared helper is measured
///    agreement with those siblings' contract, not just with its own prior self.
@Suite("Issue791 Circle 2D BSpline helper consolidation")
struct Issue791CircleBSplineHelperTests {

    struct PoleBaseline {
        let index: Int
        let point: SIMD2<Double>
        let weight: Double
    }

    // Captured verbatim from the pre-#791 inline implementation of
    // OCCTConvertCircleToBSpline2D(center: (0,0), radius: 5, u1: 0, u2: 2*pi).
    static let fullCircleOriginPoles: [PoleBaseline] = [
        PoleBaseline(index: 1, point: SIMD2(5.0, 0.0), weight: 1.0),
        PoleBaseline(index: 2, point: SIMD2(5.0, 8.660254037844384), weight: 0.5000000000000001),
        PoleBaseline(index: 3, point: SIMD2(-2.499999999999999, 4.330127018922194), weight: 1.0),
        PoleBaseline(index: 4, point: SIMD2(-9.999999999999998, 1.224646799147353e-15), weight: 0.5000000000000001),
        PoleBaseline(index: 5, point: SIMD2(-2.500000000000002, -4.330127018922192), weight: 1.0),
        PoleBaseline(index: 6, point: SIMD2(4.999999999999992, -8.660254037844389), weight: 0.5000000000000001),
        PoleBaseline(index: 7, point: SIMD2(5.0, -1.2246467991473533e-15), weight: 1.0),
    ]

    // Captured verbatim from the pre-#791 inline implementation of
    // OCCTConvertCircleToBSpline2D(center: (3,-2), radius: 7, u1: 0.5, u2: 4.0).
    static let offsetArcPoles: [PoleBaseline] = [
        PoleBaseline(index: 1, point: SIMD2(9.14307793323261, 1.355978770229421), weight: 1.0),
        PoleBaseline(index: 2, point: SIMD2(5.124556366508612, 8.711833157554384), weight: 0.6409968581633251),
        PoleBaseline(index: 3, point: SIMD2(-1.3972153590591736, 3.4465123782154485), weight: 1.0),
        PoleBaseline(index: 4, point: SIMD2(-7.918987084626961, -1.8188084011234853), weight: 0.6409968581633251),
        PoleBaseline(index: 5, point: SIMD2(-1.5755053460452837, -7.297617467155498), weight: 1.0),
    ]

    @Test func fullCircleOriginMatchesPriorBaseline() throws {
        let c = try #require(Curve2D.fromCircleArc(centerX: 0, centerY: 0, radius: 5, u1: 0, u2: 2 * .pi))
        assertMatchesBaseline(c, poles: Self.fullCircleOriginPoles)
    }

    @Test func offsetArcMatchesPriorBaseline() throws {
        let c = try #require(Curve2D.fromCircleArc(centerX: 3, centerY: -2, radius: 7, u1: 0.5, u2: 4.0))
        assertMatchesBaseline(c, poles: Self.offsetArcPoles)
    }

    private func assertMatchesBaseline(_ c: Curve2D, poles: [PoleBaseline]) {
        let bs = c.bspline
        #expect(bs.poleCount == poles.count)
        #expect(bs.degree == 2)
        #expect(bs.isRational == true)
        #expect(c.isPeriodic == false)
        for baseline in poles {
            let p = bs.pole(at: baseline.index)
            let w = c.bsplineWeight(at: baseline.index)
            #expect(p == baseline.point, "pole(\(baseline.index))")
            #expect(w == baseline.weight, "weight(\(baseline.index))")
        }
    }

    // MARK: - Implementation-independent geometric invariant

    /// Every point the returned BSpline curve evaluates to must sit at exactly `radius` from the
    /// circle's own center, regardless of how the pole/knot arrays were built. This is the same
    /// contract `buildCurve2DFromConic`'s other three callers (Ellipse/Hyperbola/Parabola) already
    /// rely on for their own conic, so Circle satisfying it through the shared helper is measured
    /// agreement with those siblings, not merely with its own prior implementation.
    @Test func convertedCircleStaysOnTheAnalyticCircle() throws {
        let cases: [(cx: Double, cy: Double, radius: Double, u1: Double, u2: Double)] = [
            (0, 0, 5, 0, 2 * .pi),
            (3, -2, 7, 0.5, 4.0),
            (-6, 11, 2.25, -1.0, 1.0),
        ]
        for c in cases {
            let curve = try #require(Curve2D.fromCircleArc(centerX: c.cx, centerY: c.cy, radius: c.radius, u1: c.u1, u2: c.u2))
            let domain = curve.domain
            let samples = stride(from: domain.lowerBound, through: domain.upperBound, by: (domain.upperBound - domain.lowerBound) / 16)
            for u in samples {
                let p = curve.evalD0(at: u)
                let dx = p.x - c.cx
                let dy = p.y - c.cy
                let dist = (dx * dx + dy * dy).squareRoot()
                #expect(abs(dist - c.radius) < 1e-6, "u=\(u) dist=\(dist)")
            }
        }
    }
}
