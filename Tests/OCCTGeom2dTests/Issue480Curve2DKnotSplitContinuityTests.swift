import Testing
import simd
@testable import OCCTSwift

/// #480: the 2D sibling of the knot-splitting family.
/// `Curve2D.splitIndicesAtDiscontinuities` and the `bsplineKnotSplits`/`bsplineKnotSplitValues`
/// pair all drive `Geom2dConvert_BSplineCurveKnotSplitting`, which runs the identical algorithm
/// to its 3D, surface and law counterparts: a knot splits only when
/// `degree - multiplicity < ContinuityRange`. All three took a raw `Int` documented as starting
/// at C0 and stopping at C2, the range that does nothing on ordinary cubic geometry.
@Suite("Curve2D knot-splitting continuity range (#480)")
struct Issue480Curve2DKnotSplitContinuityTests {

    /// A 2D BSpline of the given degree with `interiorKnots` interior knots at multiplicity 1,
    /// except knot `bumpAt` (1-based), which gets `bumpMult`.
    private func bsplineCurve(degree: Int, interiorKnots: Int,
                              bumpAt: Int = 0, bumpMult: Int = 1) -> Curve2D? {
        var knots: [Double] = [0]
        var mults: [Int32] = [Int32(degree + 1)]
        for i in 1...interiorKnots {
            knots.append(Double(i))
            mults.append(Int32(i == bumpAt ? bumpMult : 1))
        }
        knots.append(Double(interiorKnots + 1))
        mults.append(Int32(degree + 1))

        let nPoles = Int(mults.reduce(0, +)) - degree - 1
        let poles = (0..<nPoles).map { SIMD2<Double>(Double($0), Double($0 % 3)) }
        return Curve2D.bspline(poles: poles, knots: knots, multiplicities: mults, degree: degree)
    }

    @Test("A cubic 2D BSpline with simple interior knots reports interior splits only at .c3")
    func cubicSimpleKnotsNeedC3() throws {
        let curve = try #require(bsplineCurve(degree: 3, interiorKnots: 4))

        for continuity: ParametricContinuity in [.c0, .c1, .c2] {
            #expect(curve.splitIndicesAtDiscontinuities(continuity: continuity) == [1, 6],
                    "indices at \(continuity)")
        }

        // Knot indices are 1-based into the curve's own knot table, which here is 0...5.
        let atC3 = try #require(curve.splitIndicesAtDiscontinuities(continuity: .c3))
        #expect(atC3 == [1, 2, 3, 4, 5, 6])
        #expect(atC3.map { curve.bsplineKnot(index: $0) } == [0, 1, 2, 3, 4, 5])
    }

    @Test("The .c1 default reports a real kink")
    func defaultFindsGenuineKink() throws {
        let curve = try #require(bsplineCurve(degree: 3, interiorKnots: 4, bumpAt: 2, bumpMult: 3))
        let defaulted = try #require(curve.splitIndicesAtDiscontinuities())
        #expect(defaulted.map { curve.bsplineKnot(index: $0) } == [0, 2, 5])
        #expect(curve.splitIndicesAtDiscontinuities(continuity: .c0) == [1, 6])
    }

    /// #562 forwarded the v0.105 spellings onto `splitIndicesAtDiscontinuities`, which is exactly
    /// what makes "the two agree" stop being evidence: one implementation cannot disagree with
    /// itself. The expectations here are the literal knot indices of the fixture instead, so a
    /// defect that moved both spellings together would still be caught.
    @Test("The deprecated v0.105 count/values spellings still report the fixture's own knots")
    @available(*, deprecated, message: "exercises the deprecated v0.105 spellings on purpose")
    func alternateSpellingsAgree() throws {
        let curve = try #require(bsplineCurve(degree: 3, interiorKnots: 4))
        // Knot table is 0...5, so 1-based indices run 1...6, and a cubic with simple interior
        // knots is already C2 there: only .c3 reaches past the two bracketing knots.
        for continuity: ParametricContinuity in [.c0, .c1, .c2] {
            #expect(curve.bsplineKnotSplits(continuity: continuity) == 2, "count at \(continuity)")
            #expect(curve.bsplineKnotSplitValues(continuity: continuity) == [1, 6],
                    "values at \(continuity)")
        }
        #expect(curve.bsplineKnotSplits(continuity: .c3) == 6)
        #expect(curve.bsplineKnotSplitValues(continuity: .c3) == [1, 2, 3, 4, 5, 6])
    }
}
