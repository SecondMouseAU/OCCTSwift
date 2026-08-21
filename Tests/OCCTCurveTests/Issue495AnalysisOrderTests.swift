import Testing
@testable import OCCTSwift

// #495: what LocalAnalysis_CurveContinuity actually measures, and what it only appears to.
//
// The analyser runs one branch of a switch on the order it was constructed with, and only that
// branch's quantities are computed. Every other predicate then compares a member still at its 0.0
// initialiser against a tolerance and returns true whatever the geometry does, so before this
// fix a sharp 90-degree corner analysed at order C0 reported isC2 == true, with c2Angle == 0.0 (a
// perfect match) to go with it. No order covers all five classes: not even the .c2 default, which
// never looks at G1 or G2, which is why `smoothJunctionIsG1` used to pass without measuring
// anything.
//
// ContinuityStatus() is a separate half of the same problem: it returns the order it was
// constructed with, verbatim. It was surfaced as `status` and documented as a result.

@Suite("Issue #495: analysis order selects what is measured")
struct Issue495CurveAnalysisOrderTests {

    /// Two arcs meeting at (5,0,0) at a sharp angle. Only C0 holds.
    private func sharpCorner() -> (Curve3D, Curve3D)? {
        guard let c1 = Curve3D.fit(points: [SIMD3(0, 0, 0), SIMD3(2.5, 0.5, 0), SIMD3(5, 0, 0)]),
              let c2 = Curve3D.fit(points: [SIMD3(5, 0, 0), SIMD3(5.5, 2.5, 0), SIMD3(5, 5, 0)])
        else { return nil }
        return (c1, c2)
    }

    /// Two arcs meeting smoothly at (5,0,0).
    private func smoothJunction() -> (Curve3D, Curve3D)? {
        guard let c1 = Curve3D.fit(points: [SIMD3(0, 0, 0), SIMD3(2.5, 1, 0), SIMD3(5, 0, 0)]),
              let c2 = Curve3D.fit(points: [SIMD3(5, 0, 0), SIMD3(7.5, -1, 0), SIMD3(10, 0, 0)])
        else { return nil }
        return (c1, c2)
    }

    private func analyse(_ pair: (Curve3D, Curve3D),
                         _ order: ContinuityClass) -> Curve3D.ContinuityAnalysis? {
        pair.0.continuityWith(pair.1, u1: pair.0.domain.upperBound,
                              u2: pair.1.domain.lowerBound, order: order)
    }

    @Test("each order measures exactly its own branch, and no order measures all five")
    func measuredSetPerOrder() throws {
        let pair = try #require(sharpCorner())
        let expected: [ContinuityClass: Set<ContinuityClass>] = [
            .c0: [.c0],
            .g1: [.c0, .g1],
            .c1: [.c0, .c1],
            .g2: [.c0, .g1, .g2],
            .c2: [.c0, .c1, .c2],
        ]
        for (order, want) in expected {
            let a = try #require(analyse(pair, order), "order \(order) should analyse")
            #expect(a.measured == want, "order \(order) measured \(a.measured)")
            #expect(a.measured.count < 5, "no order covers all five classes")
        }
    }

    @Test("a class the order never computed reports nil, not a false positive")
    func unmeasuredClassesReportNil() throws {
        let pair = try #require(sharpCorner())

        // The regression. At order .c0 the analyser computes the C0 distance and nothing else,
        // so IsG1()/IsC1()/IsG2()/IsC2() all answered true off their 0.0 initialisers.
        let atC0 = try #require(analyse(pair, .c0))
        #expect(atC0.holds(.c0) == true)
        #expect(atC0.holds(.g1) == nil)
        #expect(atC0.holds(.c1) == nil)
        #expect(atC0.holds(.g2) == nil)
        #expect(atC0.holds(.c2) == nil)
        #expect(atC0.isC2 == nil, "a sharp corner analysed at C0 used to report isC2 == true")

        // The parametric and geometric branches do not cover each other, in either direction.
        let atC1 = try #require(analyse(pair, .c1))
        #expect(atC1.holds(.c1) == false, "measured, and the corner is not C1")
        #expect(atC1.holds(.g1) == nil, "order .c1 never computes G1")

        let atG1 = try #require(analyse(pair, .g1))
        #expect(atG1.holds(.g1) == false, "measured, and the corner is not G1")
        #expect(atG1.holds(.c1) == nil, "order .g1 never computes C1")
    }

    @Test("the default order does not measure tangency")
    func defaultOrderDoesNotMeasureG1() throws {
        let pair = try #require(smoothJunction())
        let atDefault = try #require(analyse(pair, .c2))
        #expect(atDefault.measured == [.c0, .c1, .c2])
        #expect(atDefault.holds(.g1) == nil,
                "the .c2 default computes C0/C1/C2 only. G1 has to be asked for")

        // Ask for it and the same junction answers properly.
        let atG1 = try #require(analyse(pair, .g1))
        #expect(atG1.holds(.g1) == true)
        #expect(atG1.g1Angle >= 0)
    }

    @Test("metrics for an unmeasured class are withheld, not reported as a perfect match")
    func unmeasuredMetricsAreWithheld() throws {
        let pair = try #require(sharpCorner())
        let atC0 = try #require(analyse(pair, .c0))

        // These read straight off the uninitialised members before the fix: 0.0 radians of
        // deviation, i.e. an ideal junction, for a 90-degree corner nothing had looked at.
        #expect(atC0.g1Angle == -1)
        #expect(atC0.c1Angle == -1)
        #expect(atC0.c1Ratio == -1)
        #expect(atC0.c2Angle == -1)
        #expect(atC0.c2Ratio == -1)
        #expect(atC0.g2Angle == -1)
        #expect(atC0.g2CurvatureVariation == -1)

        // C0 itself is measured at every order, and this junction does meet.
        #expect(atC0.c0Value < 1e-6)
    }

    @Test("the flags bitmask never claims a bit outside the measured set")
    func flagsStayInsideMeasured() throws {
        let pair = try #require(smoothJunction())
        for order in [ContinuityClass.c0, .g1, .c1, .g2, .c2] {
            guard let a = analyse(pair, order) else { continue }
            var measuredMask = 0
            for c in a.measured { measuredMask |= c.analysisFlagBit }
            #expect(a.flags & ~measuredMask == 0,
                    "order \(order) set flags \(a.flags) outside measured \(a.measured)")
        }
    }

    @Test("order reports the request after saturation, not a measurement")
    func orderReportsTheEffectiveRequest() throws {
        let pair = try #require(sharpCorner())

        for order in [ContinuityClass.c0, .g1, .c1] {
            let a = try #require(analyse(pair, order))
            #expect(a.order == order, "\(order) is inside the analyser's vocabulary")
        }

        // C2 is the strictest question LocalAnalysis_* can answer, so .c3/.cN saturate to it,
        // and `order` is how a caller finds out that happened.
        for beyond in [ContinuityClass.c3, .cN] {
            let a = try #require(analyse(pair, beyond))
            #expect(a.order == .c2, "\(beyond) should saturate to .c2")
            #expect(a.measured == [.c0, .c1, .c2])
        }
    }
}
