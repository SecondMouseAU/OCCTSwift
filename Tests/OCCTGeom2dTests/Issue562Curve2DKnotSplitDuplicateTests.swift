import Testing
import simd

@testable import OCCTSwift

/// #562: `Geom2dConvert_BSplineCurveKnotSplitting` was wrapped twice, by
/// `Curve2D.splitIndicesAtDiscontinuities` and by the v0.105.0
/// `bsplineKnotSplits`/`bsplineKnotSplitValues` pair. The issue called the second pair strictly
/// weaker; it was not. It sized its buffer from the analyzer's own count, where the canonical
/// call read a fixed 256 entries and took whatever came back, so on a curve with more splits than
/// that the *duplicate* was the only one telling the truth. Collapsing onto the canonical spelling
/// without fixing that would have regressed it, so the truncation is fixed here and guarded below.
@Suite("Curve2D knot-splitting duplicates (#562)")
struct Issue562Curve2DKnotSplitDuplicateTests {

    /// A degree-`d` 2D BSpline whose every interior knot has multiplicity `d`: continuity there is
    /// `d - d = 0`, so every knot is a split at C1 or above. `interiorKnots` knots in gives
    /// `interiorKnots + 2` splits out (#481's fixture, in 2D).
    private func denselyKinkedCurve(degree: Int, interiorKnots: Int) -> Curve2D? {
        var knots: [Double] = [0]
        var mults: [Int32] = [Int32(degree + 1)]
        for i in 1...interiorKnots {
            knots.append(Double(i))
            mults.append(Int32(degree))
        }
        knots.append(Double(interiorKnots + 1))
        mults.append(Int32(degree + 1))

        let nPoles = Int(mults.reduce(0, +)) - degree - 1
        let poles = (0..<nPoles).map { SIMD2<Double>(Double($0), Double($0 % 3)) }
        return Curve2D.bspline(poles: poles, knots: knots, multiplicities: mults, degree: degree)
    }

    /// The regression the deduplication had to clear first. 300 interior knots at multiplicity 3
    /// on a cubic is 302 splits, against a 256-entry first pass.
    ///
    /// `last == 302` is the assertion that proves the retry re-read the full set: under truncation
    /// the indices are `1...256`, so `last == count` would hold either way (#481).
    @Test("A curve with more splits than the first-pass buffer reports all of them")
    func moreSplitsThanTheFirstPassBuffer() throws {
        let curve = try #require(denselyKinkedCurve(degree: 3, interiorKnots: 300))
        let indices = try #require(curve.splitIndicesAtDiscontinuities(continuity: .c1))
        #expect(indices.count == 302)
        #expect(indices.last == 302)
        #expect(indices.first == 1)
    }

    /// The count is exact at the boundary too, where an off-by-one in the retry would show up.
    @Test("The retry boundary is exact at 255, 256 and 257 splits")
    func retryBoundaryIsExact() throws {
        for splits in [255, 256, 257] {
            let curve = try #require(denselyKinkedCurve(degree: 3, interiorKnots: splits - 2))
            let indices = curve.splitIndicesAtDiscontinuities(continuity: .c1)
            #expect(indices?.count == splits, "at \(splits) splits")
            #expect(indices?.last == splits, "last index at \(splits) splits")
        }
    }
}
