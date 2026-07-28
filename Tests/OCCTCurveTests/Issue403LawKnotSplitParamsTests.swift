import Testing
import simd
@testable import OCCTSwift

/// #403: `LawFunction.knotSplitting` only ever returned raw knot-table indices, which the
/// public API otherwise exposes no way to interpret (there is no accessor for a law's own
/// knot vector). `knotSplitParameters` adds the actual parameter-value form -- the same
/// conversion `Curve3D.continuityBreaks` already does for curves -- as an additive sibling
/// method, so the pre-existing `knotSplitting` signature is untouched.
@Suite("LawFunction knot splitting parameters (#403)")
struct Issue403LawKnotSplitParamsTests {

    /// Degree-3 BSpline law with an interior knot (0.5) of multiplicity 2, so it is only
    /// C1 there -- a genuine continuity break at C2, distinct from the two end knots.
    private func lawWithInteriorBreak() -> LawFunction? {
        LawFunction.bspline(
            poles: [1.0, 3.0, 2.0, 5.0, 4.0, 6.0],
            knots: [0.0, 0.5, 1.0],
            multiplicities: [4, 2, 4],
            degree: 3)
    }

    @Test("Parameter count matches the sibling index method")
    func countMatchesIndexMethod() {
        guard let law = lawWithInteriorBreak() else {
            Issue.record("could not build the test law")
            return
        }
        let indices = law.knotSplitting(continuityOrder: 2)
        let params = law.knotSplitParameters(continuityOrder: 2)
        // Same underlying Law_BSplineKnotSplitting analyzer -- must agree on how many
        // splits there are, even though one returns indices and the other parameters.
        #expect(indices.count == params.count)
        #expect(params.count >= 2)
    }

    @Test("Parameters are ascending and bracketed by the law's own bounds")
    func parametersMatchBounds() {
        guard let law = lawWithInteriorBreak() else {
            Issue.record("could not build the test law")
            return
        }
        let params = law.knotSplitParameters(continuityOrder: 2)
        let bounds = law.bounds

        if let first = params.first, let last = params.last {
            #expect(abs(first - bounds.lowerBound) < 1e-9)
            #expect(abs(last - bounds.upperBound) < 1e-9)
        }
        #expect(zip(params, params.dropFirst()).allSatisfy { $0 < $1 })
        #expect(params.allSatisfy { bounds.contains($0) })
    }

    @Test("Interior break at the multiplicity-2 knot is reported")
    func interiorBreakReported() {
        guard let law = lawWithInteriorBreak() else {
            Issue.record("could not build the test law")
            return
        }
        // Degree 3, multiplicity 2 at the interior knot => continuity there is 3-2=1, so
        // asking for C2 must surface it as a break, in addition to the two end knots.
        let params = law.knotSplitParameters(continuityOrder: 2)
        #expect(params.contains { abs($0 - 0.5) < 1e-9 })
    }

    @Test("Non-BSpline-based law returns empty, not a crash")
    func nonBSplineLawReturnsEmpty() {
        guard let law = LawFunction.linear(from: 0, to: 1) else {
            Issue.record("could not build the test law")
            return
        }
        #expect(law.knotSplitParameters(continuityOrder: 1).isEmpty)
    }
}
