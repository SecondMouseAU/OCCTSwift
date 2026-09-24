import Foundation
import Testing
import simd

@testable import OCCTSwift

// The earlier reverseCurve discarded both start points ("verified by no crash"), copyCurve
// compared the copy with its source only at u = 0 inside `if let`, and copiedCurveIndependent
// checked only `isClosed` (#766). Geom_Curve::Reverse and Copy on the same curves
// (Scripts/repro/766-curve-extras-interp/transcript.txt) give the values pinned here.
@Suite("Curve3D Extras v0.109")
struct Curve3DExtrasTests {
    @Test func reverseCurve() {
        guard let c = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)) else {
            Issue.record("segment not built")
            return
        }
        #expect(c.reverse())
        // In place: the direction flips, so the start is now (10, 0, 0).
        #expect(simd_distance(c.startPoint, SIMD3(10, 0, 0)) < 1e-12)
        #expect(simd_distance(c.endPoint, SIMD3(0, 0, 0)) < 1e-12)
    }

    @Test func copyCurve() {
        guard let c = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
            let copy = c.copy()
        else {
            Issue.record("line or its copy not built")
            return
        }
        for u in [-5.0, 0, 3, 7] {
            #expect(simd_distance(c.point(at: u), copy.point(at: u)) < 1e-12)
        }
    }

    @Test func copiedCurveIndependent() {
        guard let c = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)),
            let copy = c.copy()
        else {
            Issue.record("segment or its copy not built")
            return
        }
        #expect(copy.startPoint == c.startPoint)
        // Reversing the original leaves the copy as it was.
        #expect(c.reverse())
        #expect(simd_distance(copy.startPoint, SIMD3(0, 0, 0)) < 1e-12)
        #expect(simd_distance(c.startPoint, SIMD3(10, 0, 0)) < 1e-12)
    }
}
