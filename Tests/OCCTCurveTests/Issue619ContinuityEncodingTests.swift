import Testing
import simd
@testable import OCCTSwift

/// #619: `Curve3D.continuityOrder`, `Curve2D.continuityOrder` and `Surface.surfaceContinuityOrder`
/// changed what their numbers *mean* without changing their type or their name.
///
/// #485 was right to make them report the real `GeomAbs_Shape` ordinal, the hand-invented
/// `{C0=0, C1=1, C2=2, C3=3, CN=99, G1=-2, G2=-3}` scheme matched nothing, not even its own doc
/// comment. What it left behind was a caller-visible hazard with only a *warning* attached: every
/// `continuityOrder >= n` threshold and every `== 99` analytic fast path kept compiling and
/// quietly meant something else. #619 retires the spelling outright, so those call sites become
/// compile errors carrying the migration in the diagnostic.
///
/// This suite pins the half a test can reach: the encoding itself against known geometry, and the
/// two idioms that changed answer. The source break is pinned by the `@available(*, unavailable)`
/// attribute on the three properties, a test cannot call them, which is the point.
@Suite("Measured continuity encoding after the retirement (#619)")
struct Issue619ContinuityEncodingTests {

    /// A cubic BSpline whose interior knot multiplicity sets its measured continuity:
    /// mult 1 -> C2, mult 2 -> C1, mult 3 (== degree) -> C0.
    static func bspline(interiorMultiplicity multiplicity: Int32) -> Curve3D? {
        let poleCount = 4 + Int(multiplicity)
        let poles = (1...poleCount).map { i in
            SIMD3<Double>(Double(i), Double(i % 2) * 2.0, 0)
        }
        return Curve3D.bspline(poles: poles,
                               knots: [0.0, 0.5, 1.0],
                               multiplicities: [4, multiplicity, 4],
                               degree: 3)
    }

    // MARK: - The encoding, against geometry whose class is known by construction

    @Test("An analytic curve reports CN as ordinal 6, the old encoding's 99 is unreachable")
    func analyticCurveReportsCN() {
        // The `continuityOrder == 99` fast path was the issue's second failure: not a wrong
        // answer but silently dead code, because nothing can produce 99 any more.
        var checked = 0
        for curve in [Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)),
                      Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10)]
                        .compactMap({ $0 }) {
            #expect(curve.continuityClass == .cN)
            #expect(curve.continuity == 6)
            #expect(curve.continuity != 99)
            checked += 1
        }
        #expect(checked == 2, "both analytic fixtures must build, or this passes vacuously")
    }

    @Test("The sibling raw-ordinal accessors use the same encoding, so CN is 6 there too")
    func siblingAccessorsUseTheSameOrdinal() {
        // `bezierContinuity` is a separate `(int32_t)Continuity()` cast on a different OCCT
        // class, and several reference pages documented it as `4 = CN`, the same wrong table
        // that let `continuity` and `continuityOrder` disagree. A Bezier is CN by construction.
        guard let bezier = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(2, 0, 0)])
        else {
            Issue.record("could not build the Bezier fixture")
            return
        }
        #expect(bezier.bezierContinuity == 6)
        #expect(bezier.bezierContinuity != 4)
        #expect(bezier.continuityClass == .cN)
    }

    @Test("A C1 spline reports C1 as ordinal 2, not 1")
    func c1SplineReportsOrdinalTwo() {
        // A doubled interior knot on a cubic drops it from C2 to C1. Under the old encoding this
        // curve answered 1; it answers 2 now. That single shift is the whole defect: the number
        // a C1 curve reports is the number a C2 curve used to report.
        guard let c1 = Self.bspline(interiorMultiplicity: 2) else {
            Issue.record("could not build the C1 BSpline fixture")
            return
        }
        #expect(c1.continuityClass == .c1)
        #expect(c1.continuity == 2)

        // ... and the C2 curve, which used to be the one answering 2, now answers 4.
        guard let c2 = Self.bspline(interiorMultiplicity: 1) else {
            Issue.record("could not build the C2 BSpline fixture")
            return
        }
        #expect(c2.continuityClass == .c2)
        #expect(c2.continuity == 4)
    }

    // MARK: - The failure scenario the issue described

    @Test("A raw threshold of 2 now admits a merely-C1 curve; satisfies(.c2) still refuses it")
    func rawThresholdAdmitsC1WhereSatisfiesRefuses() {
        guard let c1 = Self.bspline(interiorMultiplicity: 2) else {
            Issue.record("could not build the C1 BSpline fixture")
            return
        }

        // `if curve.continuityOrder >= 2 { useAsC2Spline() }`, the issue's exact line. Under the
        // old encoding this was false for a C1 curve (it answered 1). Under the new one the same
        // comparison is true, and the C1 curve is fed to a path that assumes C2. Asserting the
        // trap is *live* is what makes this a regression test rather than a restatement.
        #expect(c1.continuity >= 2)

        // The question that line meant to ask. It is false, as it always should have been.
        #expect(!c1.continuityClass.satisfies(.c2))
        #expect(c1.continuityClass.satisfies(.c1))

        // A genuine C2 curve passes both, so the trap is specifically about the C1 case rather
        // than the floor being unreachable.
        if let c2 = Self.bspline(interiorMultiplicity: 1) {
            #expect(c2.continuity >= 2)
            #expect(c2.continuityClass.satisfies(.c2))
        }
    }

    @Test("The two vocabularies' constants do not line up, which is why the raw form drifted")
    func requestAndResultConstantsDiffer() {
        // `continuityOrder >= ParametricContinuity.c2.rawValue` was a natural way to write the
        // check and was always comparing a result ordinal against a request order. They differ
        // for every class above C0, so no constant carried over correctly.
        #expect(ContinuityClass.c1.rawValue != ParametricContinuity.c1.rawValue)   // 2 vs 1
        #expect(ContinuityClass.c2.rawValue != ParametricContinuity.c2.rawValue)   // 4 vs 2
        #expect(ContinuityClass.c3.rawValue != ParametricContinuity.c3.rawValue)   // 5 vs 3
        #expect(ContinuityClass.c0.rawValue == ParametricContinuity.c0.rawValue)   // 0, the only match

        // `satisfies(_:)` is the bridge between them and takes the request vocabulary by type,
        // so the mismatched constant cannot be written at all (#485, #623).
        #expect(ContinuityClass.c2.satisfies(.c2))
        #expect(!ContinuityClass.c1.satisfies(.c2))
    }

    @Test("Every measured class round-trips through the raw ordinal")
    func measuredClassRoundTripsThroughOrdinal() {
        // Whatever the bridge reports, the two public spellings must name the same thing. If the
        // ordinal were restored to the old scheme, `ContinuityClass(rawValue:)` would fail to
        // decode 99/-2/-3 and fall back to `.c0`, breaking this.
        var checked = 0
        for curve in [Self.bspline(interiorMultiplicity: 1),
                      Self.bspline(interiorMultiplicity: 2),
                      Self.bspline(interiorMultiplicity: 3),
                      Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0))].compactMap({ $0 }) {
            #expect(curve.continuity == Int(curve.continuityClass.rawValue))
            #expect(ContinuityClass(rawValue: Int32(curve.continuity)) != nil)
            #expect(curve.continuity >= 0 && curve.continuity <= 6)
            checked += 1
        }
        #expect(checked == 4, "every fixture must build, or this passes vacuously")
    }
}
