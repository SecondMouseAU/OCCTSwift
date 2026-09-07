import Testing
import simd

@testable import OCCTSwift

/// #1399, geometry family: which `LawFunction` factories the knot-splitting pair can read.
///
/// `OCCTLawBSplineKnotSplitting` and `OCCTLawBSplineKnotSplitParams` both start with
/// `Handle(Law_BSpFunc)::DownCast(wrapper->law)` and return `-1` when it is null, which the Swift
/// wrappers turn into an empty array. The docs said only "Only works on BSpline-based law
/// functions", which does not say which factories qualify, and the answer is not the one the
/// name suggests: `Law_Interpol` and `Law_S` both derive from `Law_BSpFunc` in the pinned
/// headers (`Law_Interpol.hxx:29`, `Law_S.hxx:26`), so `interpolate(points:)` and `sCurve` are
/// readable too, while `Law_Constant`, `Law_Linear` and `Law_Composite` derive from
/// `Law_Function` directly and are not.
///
/// The measurement, not the inheritance graph, is what this asserts: a readable law reports at
/// least its two end knots at every continuity order, and an unreadable one reports nothing, so
/// an empty array is the whole "not a BSpline-based law" signal a caller gets.
@Suite("Law knot-splitting factory reach (#1399)")
struct Issue1399LawKnotSplitFactoryReachTests {

    /// One list walked by a single test rather than `@Test(arguments:)`: a `(String, ...)` tuple
    /// element pairing a reference-counted member with a builtin vector corrupts the Swift task
    /// allocator in debug builds (#1057, swiftlang/swift#91639). Keeping the cases in a local
    /// array sidesteps the shape entirely and is not a style choice.
    private func readableLaws() -> [(String, LawFunction)] {
        var cases: [(String, LawFunction)] = []
        if let l = LawFunction.sCurve(from: 0, to: 1, parameterRange: 0...1) {
            cases.append(("sCurve", l))
        }
        if let l = LawFunction.interpolate(points: [(0, 0), (0.5, 2), (1, 1)]) {
            cases.append(("interpolate(points:)", l))
        }
        if let l = LawFunction.interpolated(values: [0, 2, 1, 3]) {
            cases.append(("interpolated(values:)", l))
        }
        if let l = LawFunction.bspline(
            poles: [0, 1, 2, 1, 0, 1], knots: [0, 1, 2, 3], multiplicities: [4, 1, 1, 4],
            degree: 3)
        {
            cases.append(("bspline", l))
        }
        return cases
    }

    private func unreadableLaws() -> [(String, LawFunction)] {
        var cases: [(String, LawFunction)] = []
        if let l = LawFunction.constant(2.0, from: 0, to: 1) { cases.append(("constant", l)) }
        if let l = LawFunction.linear(from: 0, to: 1, parameterRange: 0...1) {
            cases.append(("linear", l))
        }
        if let a = LawFunction.constant(1.0, from: 0, to: 1),
            let b = LawFunction.constant(2.0, from: 1, to: 2),
            let l = LawFunction.composite(laws: [a, b], range: 0...2)
        {
            cases.append(("composite", l))
        }
        return cases
    }

    @Test("Every Law_BSpFunc-derived factory reports its end knots at every continuity order")
    func bsplineBackedLawsAreReadable() throws {
        let cases = readableLaws()
        #expect(cases.count == 4, "all four factories built")
        for (name, law) in cases {
            for order: ParametricContinuity in [.c0, .c1, .c2, .c3] {
                let indices = law.knotSplitting(continuityOrder: order)
                let params = law.knotSplitParameters(continuityOrder: order)
                #expect(indices.count >= 2, "\(name) indices at \(order)")
                #expect(params.count == indices.count, "\(name) pair agrees at \(order)")
            }
        }
    }

    @Test("A law that is not Law_BSpFunc-derived reports nothing, and that is the only signal")
    func nonBSplineLawsReportNothing() throws {
        let cases = unreadableLaws()
        #expect(cases.count == 3, "all three factories built")
        for (name, law) in cases {
            for order: ParametricContinuity in [.c0, .c1, .c2, .c3] {
                #expect(law.knotSplitting(continuityOrder: order).isEmpty, "\(name) at \(order)")
                #expect(
                    law.knotSplitParameters(continuityOrder: order).isEmpty, "\(name) at \(order)")
            }
        }
    }
}
