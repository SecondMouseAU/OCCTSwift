import Testing

@testable import OCCTSwift

// #1020: `Edge.split(at:vertex:)` accepted a parameter outside the edge's own range and returned
// two edges anyway, extrapolated off the underlying unbounded curve.
// `ShapeFix_SplitTool::SplitEdge` checks only for a parameter AT either end, so nothing rejected
// one beyond them: on a line trimmed to [-5, 5], parameter 6 came back as halves of length 11 and
// 1, and parameter 100 as 105 and 95, against an original length of 10. The bridge now derives the
// admissible range from the edge.
@Suite("Edge.split is bounded by the edge's own range (#1020)")
struct Issue1020SplitEdgeRangeTests {

    // A line trimmed to [-5, 5]. Parameter 0 is its midpoint, five units from either vertex.
    private func straddlingEdge() -> Edge? {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
            let shape = Shape.edgeFromCurve(line, u1: -5, u2: 5)
        else { return nil }
        return shape.edges().first
    }

    // The defect. Each of these returned a pair of extrapolated edges before the guard.
    @Test("Splitting outside the edge's range is refused", arguments: [-6.0, 6.0, 100.0, -1000.0])
    func splitOutsideRangeIsRefused(param: Double) {
        guard let edge = straddlingEdge() else {
            #expect(Bool(false), "Failed to build the straddling edge")
            return
        }
        #expect(edge.split(at: param, vertex: SIMD3(param, 0, 0)) == nil)
    }

    // Passes before and after: `ShapeFix_SplitTool` already refused a split at either vertex, via
    // the parameter range `BRep_Tool::CurveOnPlane` recovers by projecting the edge onto the
    // context face. Kept because the new guard subsumes that check, so a future change to either
    // one has somewhere to fail.
    @Test("Splitting at either vertex is refused", arguments: [-5.0, 5.0])
    func splitAtVertexIsRefused(param: Double) {
        guard let edge = straddlingEdge() else {
            #expect(Bool(false), "Failed to build the straddling edge")
            return
        }
        #expect(edge.split(at: param, vertex: SIMD3(param, 0, 0)) == nil)
    }

    // Also passes before and after, and the reason it is here is that a first attempt at this
    // issue predicted it would fail. The prediction was that a standalone edge has no pcurve on
    // the throwaway context face, leaving the kernel's endpoint range at (0, 0) and refusing any
    // split near parameter 0. `BRep_Tool::CurveOnSurface` falls through to `CurveOnPlane`, which
    // projects the edge onto the plane and returns its real range, so the midpoint of an edge
    // parameterised across zero splits correctly. Pinned so nobody re-derives the wrong theory.
    @Test("An edge whose range straddles zero splits at zero")
    func splitAtZeroOnStraddlingEdge() {
        guard let edge = straddlingEdge() else {
            #expect(Bool(false), "Failed to build the straddling edge")
            return
        }
        guard let (e1, e2) = edge.split(at: 0.0, vertex: SIMD3(0, 0, 0)) else {
            #expect(Bool(false), "Splitting at the midpoint should succeed")
            return
        }
        #expect(abs(e1.length - 5.0) < 1e-9)
        #expect(abs(e2.length - 5.0) < 1e-9)
    }

    // An ordinary interior split, so a guard that refused everything would not pass this suite.
    @Test("An ordinary interior split still works")
    func interiorSplitStillWorks() {
        guard let edge = straddlingEdge() else {
            #expect(Bool(false), "Failed to build the straddling edge")
            return
        }
        guard let (e1, e2) = edge.split(at: 2.0, vertex: SIMD3(2, 0, 0)) else {
            #expect(Bool(false), "Splitting at an interior parameter should succeed")
            return
        }
        #expect(abs(e1.length - 7.0) < 1e-9)
        #expect(abs(e2.length - 3.0) < 1e-9)
    }
}
