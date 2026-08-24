import Testing
import simd

@testable import OCCTSwift

/// #480: `LawFunction.knotSplitting`/`knotSplitParameters` took a raw `Int` documented as
/// "0=C0, 1=C1, 2=C2" and defaulted to 2. `Law_BSplineKnotSplitting` runs the same algorithm as
/// the curve and surface analyzers (a knot splits only when `degree - multiplicity <
/// ContinuityRange`), so on a cubic law with simple interior knots every value the doc offered
/// returned just the two end knots. `ParametricContinuity` makes `.c3`, the order that actually
/// reports them, spellable.
@Suite("Law knot-splitting continuity range (#480)")
struct Issue480LawKnotSplitContinuityTests {

    /// A BSpline law of the given degree with `interiorKnots` interior knots at multiplicity 1,
    /// except knot `bumpAt` (1-based), which gets `bumpMult`.
    private func bsplineLaw(
        degree: Int, interiorKnots: Int,
        bumpAt: Int = 0, bumpMult: Int = 1
    ) -> LawFunction? {
        var knots: [Double] = [0]
        var mults: [Int32] = [Int32(degree + 1)]
        for i in 1...interiorKnots {
            knots.append(Double(i))
            mults.append(Int32(i == bumpAt ? bumpMult : 1))
        }
        knots.append(Double(interiorKnots + 1))
        mults.append(Int32(degree + 1))

        let nPoles = Int(mults.reduce(0, +)) - degree - 1
        let poles = (0..<nPoles).map { Double($0 % 4) * 1.5 }
        return LawFunction.bspline(
            poles: poles, knots: knots, multiplicities: mults, degree: degree)
    }

    @Test("A cubic law with simple interior knots reports interior splits only at .c3")
    func cubicSimpleKnotsNeedC3() throws {
        let law = try #require(bsplineLaw(degree: 3, interiorKnots: 4))

        for continuity: ParametricContinuity in [.c0, .c1, .c2] {
            #expect(
                law.knotSplitParameters(continuityOrder: continuity) == [0, 5],
                "params at \(continuity)")
            #expect(
                law.knotSplitting(continuityOrder: continuity).count == 2,
                "indices at \(continuity)")
        }

        #expect(law.knotSplitParameters(continuityOrder: .c3) == [0, 1, 2, 3, 4, 5])
        #expect(law.knotSplitting(continuityOrder: .c3).count == 6)
    }

    @Test("The .c1 default reports a real kink")
    func defaultFindsGenuineKink() throws {
        // Multiplicity 3 on a cubic leaves continuity 0 at that knot.
        let law = try #require(bsplineLaw(degree: 3, interiorKnots: 4, bumpAt: 2, bumpMult: 3))
        #expect(law.knotSplitParameters() == [0, 2, 5])
        #expect(law.knotSplitParameters(continuityOrder: .c0) == [0, 5])
    }

    @Test("Indices and parameters describe the same splits")
    func indicesAndParametersAgree() throws {
        let law = try #require(bsplineLaw(degree: 3, interiorKnots: 4))
        // Same analyzer, so the two spellings must always agree on how many splits there are.
        for continuity in ParametricContinuity.allCases {
            #expect(
                law.knotSplitting(continuityOrder: continuity).count
                    == law.knotSplitParameters(continuityOrder: continuity).count,
                "at \(continuity)")
        }
    }
}
