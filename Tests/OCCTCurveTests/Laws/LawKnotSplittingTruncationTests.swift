import Testing

@testable import OCCTSwift

/// #481: `LawFunction.knotSplitting` read into a fixed 100-entry buffer and returned however
/// many the bridge had written, so a law with more than 100 splits silently reported exactly
/// 100.
///
/// Its sibling `knotSplitParameters` (same `Law_BSplineKnotSplitting` analyzer, same
/// law, added alongside it in #403) reads the true count and retries at that size, so the
/// two disagreed on how many splits the law has. Same defect and same fix as
/// `Curve3D.continuityBreaks` (#398) and `Surface.knotSplitting` (#403).
@Suite("LawFunction knot splitting truncation (#481)")
struct Issue481LawKnotSplittingTruncationTests {

    /// Degree-3 BSpline law whose every interior knot has multiplicity 3, so continuity there
    /// is 3-3=0 and every knot is a split at C1 or above. `knotCount` knots in, `knotCount`
    /// splits out, which is the cheapest way to push past the old 100-entry buffer.
    private func lawWithSplits(knotCount: Int) throws -> LawFunction {
        let degree = 3
        let knots = (0..<knotCount).map { Double($0) }
        var mults = [Int32](repeating: 3, count: knotCount)
        mults[0] = Int32(degree + 1)
        mults[knotCount - 1] = Int32(degree + 1)
        // Non-periodic BSpline: nbPoles == sum(multiplicities) - degree - 1.
        let poleCount = Int(mults.reduce(0, +)) - degree - 1
        let poles = (0..<poleCount).map { Double($0 % 7) }
        return try #require(
            LawFunction.bspline(
                poles: poles, knots: knots, multiplicities: mults, degree: degree),
            "could not build the test law")
    }

    @Test("Index and parameter forms agree past the old 100-entry buffer")
    func indexAndParameterCountsAgreeWhenLarge() throws {
        let law = try lawWithSplits(knotCount: 150)
        let indices = law.knotSplitting(continuityOrder: .c2)
        let params = law.knotSplitParameters(continuityOrder: .c2)

        // The property the truncation broke: both wrap the same analyzer over the same law.
        #expect(indices.count == params.count)
        // And the law really does have more splits than the old fixed buffer could hold,
        // so the agreement above is not vacuous.
        #expect(indices.count > 100)
        #expect(indices.count == 150)
        // The agreement is element by element, not just in count: the knots sit at 0, 1, ...,
        // 149 and split `i` (the 1-based position in the law's own knot table) is the knot
        // `i - 1`, so the parameter of every index is known without asking the kernel.
        #expect(indices == Array(1...150))
        #expect(params == (0..<150).map(Double.init))
    }

    @Test("Indices stay ascending and unique across the retry boundary")
    func indicesAreAscendingBeyondTheBuffer() throws {
        let law = try lawWithSplits(knotCount: 150)
        let indices = law.knotSplitting(continuityOrder: .c2)
        // A retry that re-read into a fresh buffer but kept a stale count, or that returned
        // the first pass's contents, would show up as a repeat or a drop here.
        #expect(zip(indices, indices.dropFirst()).allSatisfy { $0 < $1 })
        // Every knot of this law is a split, so the indices run 1...knotCount: the last one
        // is the law's last knot, not wherever the first pass happened to stop.
        #expect(indices.first == 1)
        #expect(indices.last == 150)
        // Exactly the run 1...150, through the buffer boundary at 100 and one either side. The
        // count is required before the slice below indexes into it: a result that is short would
        // otherwise end the whole run with a trap instead of a failure.
        #expect(indices == Array(1...150))
        try #require(indices.count == 150, "indices.count \(indices.count)")
        #expect(Array(indices[98...101]) == [99, 100, 101, 102])
        // The same holds for the parameter form, which has its own retry loop.
        let params = law.knotSplitParameters(continuityOrder: .c2)
        #expect(zip(params, params.dropFirst()).allSatisfy { $0 < $1 })
        #expect(params.first == 0)
        #expect(params.last == 149)
        try #require(params.count == 150, "params.count \(params.count)")
        #expect(Array(params[98...101]) == [98, 99, 100, 101])
    }

    @Test("A law exactly at, and one either side of, the old buffer size")
    func countsAroundTheBufferBoundary() throws {
        // The retry is taken when the count exceeds 100: 100 fits the first read, 101 is the
        // first count that needs the second, and 99 is the control below both.
        for knotCount in [99, 100, 101] {
            let law = try lawWithSplits(knotCount: knotCount)
            let indices = law.knotSplitting(continuityOrder: .c2)
            let params = law.knotSplitParameters(continuityOrder: .c2)
            #expect(indices == Array(1...knotCount), "indices for \(knotCount) knots")
            #expect(params == (0..<knotCount).map(Double.init), "params for \(knotCount) knots")
        }
    }

    @Test("Indices below the buffer size are unchanged")
    func smallLawIsUnaffected() throws {
        let law = try lawWithSplits(knotCount: 12)
        let indices = law.knotSplitting(continuityOrder: .c2)
        let params = law.knotSplitParameters(continuityOrder: .c2)
        #expect(indices.count == 12)
        #expect(indices.count == params.count)
        #expect(indices == Array(1...12))
        #expect(params == (0..<12).map(Double.init))
        // The order is a derivative order that saturates at the degree: at C0 only the two end
        // knots split, because every interior knot has multiplicity 3 and so continuity 0, which
        // is not below 0.
        #expect(law.knotSplitting(continuityOrder: .c0) == [1, 12])
        #expect(law.knotSplitParameters(continuityOrder: .c0) == [0, 11])
    }

    @Test("Non-BSpline-based law still returns empty, not a crash")
    func nonBSplineLawReturnsEmptyIndices() throws {
        let law = try #require(
            LawFunction.linear(from: 0, to: 1), "could not build the test law")
        #expect(law.knotSplitting(continuityOrder: .c1).isEmpty)
        // The control that makes the empty answer mean "not readable": a readable law of the
        // same shape of call answers, at the same order.
        let readable = try lawWithSplits(knotCount: 12)
        #expect(!readable.knotSplitting(continuityOrder: .c1).isEmpty)
    }
}
