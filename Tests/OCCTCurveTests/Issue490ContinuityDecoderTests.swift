import Testing

@testable import OCCTSwift

// #490, curve/analysis half: the two remaining continuity vocabularies, and the domain each one
// actually has. Both were previously decoded by per-call-site copies with three different
// out-of-range answers.

@Suite("Issue #490: continuity vocabulary domains (curves)")
struct Issue490CurveContinuityTests {

    // Interpolating six points gives a multi-span cubic BSpline: C2 at its interior knots, so C3
    // is the first criterion that finds anything to split.
    private func multiSpanCurve() -> Curve3D? {
        Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(3, 1, 1),
            SIMD3(5, 3, 0), SIMD3(7, 0, 2), SIMD3(9, 2, 1),
        ])
    }

    // MARK: - Parametric continuity: the approximators stop at C2

    @Test("the approximator family accepts C0/C1/C2 and fails above")
    func approximationDomain() throws {
        let curve = try #require(multiSpanCurve())

        // Measured: AdvApprox throws Standard_ConstructionError for anything but C0/C1/C2, which
        // the bridge's catch(...) turns into nil. The decoder does not paper over that by
        // substituting C2, asking for more than the operation supports fails the call.
        #expect(curve.approximated(tolerance: 1e-3, continuity: 0) != nil)
        #expect(curve.approximated(tolerance: 1e-3, continuity: 1) != nil)
        #expect(curve.approximated(tolerance: 1e-3, continuity: 2) != nil)
        #expect(curve.approximated(tolerance: 1e-3, continuity: 3) == nil)

        // Same limit through the typed entry point onto the same OCCT class.
        #expect(curve.approxWithDetails(tolerance: 1e-3, continuity: .c2).curve != nil)
        #expect(curve.approxWithDetails(tolerance: 1e-3, continuity: .c3).curve == nil)

        // The saturating rule is visible here: an out-of-range request asks for CN, which this
        // operation cannot deliver, so it fails rather than quietly approximating at C2, which is
        // what the retired local copy did, while its neighbours floored the same input to CN or C1.
        #expect(curve.approximated(tolerance: 1e-3, continuity: 99) == nil)
    }

    @Test("the points-to-BSpline family takes the whole ladder without failing")
    func pointFittingDomain() {
        let points = [
            SIMD3<Double>(0, 0, 0), SIMD3(1, 2, 0), SIMD3(3, 1, 1),
            SIMD3(5, 3, 0), SIMD3(7, 0, 2), SIMD3(9, 2, 1),
        ]

        // The other consumer of the same vocabulary treats the request as an upper bound it will
        // try to meet, so every value succeeds. Worth pinning: it is the reason one decoder can
        // serve both families without either needing a private fallback.
        for continuity in 0...3 {
            #expect(
                Curve3D.approximate(points: points, continuity: continuity) != nil,
                "continuity \(continuity) should still fit a curve")
        }
    }

    // MARK: - Parametric continuity: the split family takes the whole ladder including CN

    @Test("the split criterion walks the whole parametric ladder")
    func splitCriterionLadder() throws {
        let curve = try #require(multiSpanCurve())

        // A cubic interpolated curve is C2 at its interior knots, so nothing below C3 splits it.
        #expect(curve.splitByContinuity(criterion: 2).count == 1)
        let atC3 = curve.splitByContinuity(criterion: 3).count
        #expect(atC3 > 1)

        // 4 is CN, the top of the same ladder, which is what criterion 4 has always documented,
        // and now what every out-of-range value decodes to, in every entry point.
        #expect(curve.splitByContinuity(criterion: 4).count >= atC3)
        #expect(curve.splitByContinuity(criterion: 99).count >= atC3)
    }

    // MARK: - Analysis order: a GeomAbs_Shape ordinal, ceilinged at C2

    @Test("the analysis order saturates at C2, the strictest question LocalAnalysis can answer")
    func analysisOrderSaturates() throws {
        guard let c1 = Curve3D.fit(points: [SIMD3(0, 0, 0), SIMD3(2.5, 0.5, 0), SIMD3(5, 0, 0)]),
            let c2 = Curve3D.fit(points: [SIMD3(5, 0, 0), SIMD3(5.5, 2.5, 0), SIMD3(5, 5, 0)])
        else { return }

        let atC2 = try #require(
            c1.continuityWith(
                c2, u1: c1.domain.upperBound,
                u2: c2.domain.lowerBound, order: .c2))
        // LocalAnalysis_CurveContinuity implements no predicate above C2/G2: asking for C3 or CN
        // leaves every predicate reporting true, i.e. the analysis becomes meaningless. So the
        // shared decoder reads anything above 4 as 4 instead of passing it through.
        let beyond = try #require(
            c1.continuityWith(
                c2, u1: c1.domain.upperBound,
                u2: c2.domain.lowerBound, order: .cN))
        #expect(atC2.order == beyond.order)
        #expect(atC2.measured == beyond.measured)
        #expect(atC2.flags == beyond.flags)

        // The effective order comes back in the same ordinal vocabulary the request went in as.
        #expect(atC2.order == .c2)
    }

    @Test("each analysis order below the ceiling asks a different question")
    func analysisOrderIsObservable() throws {
        guard let c1 = Curve3D.fit(points: [SIMD3(0, 0, 0), SIMD3(2.5, 0.5, 0), SIMD3(5, 0, 0)]),
            let c2 = Curve3D.fit(points: [SIMD3(5, 0, 0), SIMD3(5.5, 2.5, 0), SIMD3(5, 5, 0)])
        else { return }

        // The order is echoed back verbatim, so what makes each one a *different question* is the
        // set of classes it measures, see Issue495CurveAnalysisOrderTests for that half.
        for order in [ContinuityClass.c0, .g1, .c1, .g2, .c2] {
            let analysis = try #require(
                c1.continuityWith(
                    c2, u1: c1.domain.upperBound,
                    u2: c2.domain.lowerBound, order: order))
            #expect(
                analysis.order == order,
                "order \(order) should be reported back in the same encoding")
            #expect(
                analysis.measured.contains(order),
                "the requested class is always among the measured ones")
        }
    }
}
