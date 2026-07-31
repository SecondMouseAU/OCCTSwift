import Testing
import simd
@testable import OCCTSwift

/// #481: `LawFunction.knotSplitting` read into a fixed 100-entry buffer and returned however
/// many the bridge had written, so a law with more than 100 splits silently reported exactly
/// 100. Its sibling `knotSplitParameters` (same `Law_BSplineKnotSplitting` analyzer, same
/// law, added alongside it in #403) reads the true count and retries at that size, so the
/// two disagreed on how many splits the law has. Same defect and same fix as
/// `Curve3D.continuityBreaks` (#398) and `Surface.knotSplitting` (#403).
@Suite("LawFunction knot splitting truncation (#481)")
struct Issue481LawKnotSplittingTruncationTests {

    /// Degree-3 BSpline law whose every interior knot has multiplicity 3, so continuity there
    /// is 3-3=0 and every knot is a split at C1 or above. `knotCount` knots in, `knotCount`
    /// splits out, which is the cheapest way to push past the old 100-entry buffer.
    private func lawWithSplits(knotCount: Int) -> LawFunction? {
        let degree = 3
        let knots = (0..<knotCount).map { Double($0) }
        var mults = [Int32](repeating: 3, count: knotCount)
        mults[0] = Int32(degree + 1)
        mults[knotCount - 1] = Int32(degree + 1)
        // Non-periodic BSpline: nbPoles == sum(multiplicities) - degree - 1.
        let poleCount = Int(mults.reduce(0, +)) - degree - 1
        let poles = (0..<poleCount).map { Double($0 % 7) }
        return LawFunction.bspline(poles: poles, knots: knots, multiplicities: mults, degree: degree)
    }

    @Test("Index and parameter forms agree past the old 100-entry buffer")
    func indexAndParameterCountsAgreeWhenLarge() {
        guard let law = lawWithSplits(knotCount: 150) else {
            Issue.record("could not build the test law")
            return
        }
        let indices = law.knotSplitting(continuityOrder: .c2)
        let params = law.knotSplitParameters(continuityOrder: .c2)

        // The property the truncation broke: both wrap the same analyzer over the same law.
        #expect(indices.count == params.count)
        // And the law really does have more splits than the old fixed buffer could hold,
        // so the agreement above is not vacuous.
        #expect(indices.count > 100)
        #expect(indices.count == 150)
    }

    @Test("Indices stay ascending and unique across the retry boundary")
    func indicesAreAscendingBeyondTheBuffer() {
        guard let law = lawWithSplits(knotCount: 150) else {
            Issue.record("could not build the test law")
            return
        }
        let indices = law.knotSplitting(continuityOrder: .c2)
        // A retry that re-read into a fresh buffer but kept a stale count, or that returned
        // the first pass's contents, would show up as a repeat or a drop here.
        #expect(zip(indices, indices.dropFirst()).allSatisfy { $0 < $1 })
        // Every knot of this law is a split, so the indices run 1...knotCount: the last one
        // is the law's last knot, not wherever the first pass happened to stop.
        #expect(indices.first == 1)
        #expect(indices.last == 150)
    }

    @Test("Indices below the buffer size are unchanged")
    func smallLawIsUnaffected() {
        guard let law = lawWithSplits(knotCount: 12) else {
            Issue.record("could not build the test law")
            return
        }
        let indices = law.knotSplitting(continuityOrder: .c2)
        let params = law.knotSplitParameters(continuityOrder: .c2)
        #expect(indices.count == 12)
        #expect(indices.count == params.count)
    }

    @Test("Non-BSpline-based law still returns empty, not a crash")
    func nonBSplineLawReturnsEmptyIndices() {
        guard let law = LawFunction.linear(from: 0, to: 1) else {
            Issue.record("could not build the test law")
            return
        }
        #expect(law.knotSplitting(continuityOrder: .c1).isEmpty)
    }
}
