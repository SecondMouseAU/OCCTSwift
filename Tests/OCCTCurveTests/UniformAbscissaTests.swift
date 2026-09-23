import Foundation
import Testing
import simd

@testable import OCCTSwift

// Parameters pinned to GCPnts_UniformAbscissa on the pinned kernel
// (Scripts/repro/766-curve-final-sampling/transcript.txt). The box's first edge in
// TopExp::MapShapes order runs (-5,-5,-5) to (-5,-5,5) over u in [0, 10].
@Suite("GCPnts_UniformAbscissa Tests")
struct UniformAbscissaTests {

    private func firstBoxEdge() -> Shape? {
        Shape.box(width: 10, height: 10, depth: 10)?.subShapes(ofType: .edge).first
    }

    private func expectParams(_ params: [Double]?, _ expected: [Double]) {
        guard let params else {
            Issue.record("uniformAbscissa returned nil")
            return
        }
        #expect(params.count == expected.count)
        for (p, e) in zip(params, expected) {
            #expect(abs(p - e) < 1e-9)
        }
    }

    @Test func uniformByCount() {
        guard let edge = firstBoxEdge() else {
            Issue.record("box edge was nil")
            return
        }
        expectParams(edge.uniformAbscissa(pointCount: 5), [0, 2.5, 5, 7.5, 10])
    }

    @Test func uniformByDistance() {
        guard let edge = firstBoxEdge() else {
            Issue.record("box edge was nil")
            return
        }
        // Steps of 3 along a length-10 edge, with the end appended.
        expectParams(edge.uniformAbscissa(distance: 3.0), [0, 3, 6, 9, 10])
    }

    @Test func uniformByCountRange() {
        guard let edge = firstBoxEdge() else {
            Issue.record("box edge was nil")
            return
        }
        expectParams(edge.uniformAbscissa(pointCount: 3, u1: 0, u2: 1), [0, 0.5, 1])
    }
}
