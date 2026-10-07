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
    private func lawWithInteriorBreak() throws -> LawFunction {
        try #require(
            LawFunction.bspline(
                poles: [1.0, 3.0, 2.0, 5.0, 4.0, 6.0],
                knots: [0.0, 0.5, 1.0],
                multiplicities: [4, 2, 4],
                degree: 3),
            "could not build the test law")
    }

    @Test("Parameter count matches the sibling index method")
    func countMatchesIndexMethod() throws {
        let law = try lawWithInteriorBreak()
        let indices = law.knotSplitting(continuityOrder: .c2)
        let params = law.knotSplitParameters(continuityOrder: .c2)
        // Same underlying Law_BSplineKnotSplitting analyzer -- must agree on how many
        // splits there are, even though one returns indices and the other parameters.
        #expect(indices.count == params.count)
        // Exactly three: the two end knots and the multiplicity-2 knot between them, which are
        // positions 1, 2 and 3 of the law's own knot table.
        #expect(params.count == 3)
        #expect(indices == [1, 2, 3])
    }

    @Test("Parameters are ascending and bracketed by the law's own bounds")
    func parametersMatchBounds() throws {
        let law = try lawWithInteriorBreak()
        let params = law.knotSplitParameters(continuityOrder: .c2)
        let bounds = law.bounds
        #expect(abs(bounds.lowerBound - 0) < 1e-12)
        #expect(abs(bounds.upperBound - 1) < 1e-12)

        // The values themselves, not only their shape: the knots are 0, 0.5 and 1, so a result
        // that is ascending and inside the bounds but not these is still wrong.
        #expect(params.count == 3)
        if params.count == 3 {
            #expect(abs(params[0] - bounds.lowerBound) < 1e-9)
            #expect(abs(params[1] - 0.5) < 1e-9)
            #expect(abs(params[2] - bounds.upperBound) < 1e-9)
        }
        #expect(zip(params, params.dropFirst()).allSatisfy { $0 < $1 })
        #expect(params.allSatisfy { bounds.contains($0) })
    }

    @Test("Interior break at the multiplicity-2 knot is reported")
    func interiorBreakReported() throws {
        let law = try lawWithInteriorBreak()
        // Degree 3, multiplicity 2 at the interior knot => continuity there is 3-2=1, so
        // asking for C2 must surface it as a break, in addition to the two end knots.
        let params = law.knotSplitParameters(continuityOrder: .c2)
        #expect(params.contains { abs($0 - 0.5) < 1e-9 })
        // The order is a threshold, and 1 is not below 1: at C1 the knot is no break, so only the
        // end knots come back, and the same at C0. At C3 it is a break again.
        #expect(law.knotSplitParameters(continuityOrder: .c1) == [0, 1])
        #expect(law.knotSplitParameters(continuityOrder: .c0) == [0, 1])
        #expect(law.knotSplitParameters(continuityOrder: .c3) == [0, 0.5, 1])
        #expect(law.knotSplitting(continuityOrder: .c1) == [1, 3])
        #expect(law.knotSplitting(continuityOrder: .c3) == [1, 2, 3])
    }

    @Test("Non-BSpline-based law returns empty, not a crash")
    func nonBSplineLawReturnsEmpty() throws {
        let law = try #require(LawFunction.linear(from: 0, to: 1), "could not build the test law")
        #expect(law.knotSplitParameters(continuityOrder: .c1).isEmpty)
        // The control that makes empty mean "not readable": a readable law answers at the same
        // order.
        let readable = try lawWithInteriorBreak()
        #expect(!readable.knotSplitParameters(continuityOrder: .c1).isEmpty)
    }
}
