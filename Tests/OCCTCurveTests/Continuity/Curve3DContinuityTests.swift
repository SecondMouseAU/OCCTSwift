import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to Geom_Curve::Continuity (Scripts/repro/766-curve-conic-continuity/transcript.txt). The
// earlier versions asserted `c >= 0` inside `if let`, which every GeomAbs_Shape value satisfies,
// so a wrong continuity passed (#766).
@Suite("Curve3D Continuity Tests")
struct Curve3DContinuityTests {
    @Test func lineContinuity() {
        guard let line = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)) else {
            Issue.record("line not built")
            return
        }
        // Lines have infinite continuity (CN = 6 in GeomAbs_Shape)
        #expect(line.continuity == 6)
    }

    @Test func bsplineContinuity() {
        guard
            let bsp = Curve3D.interpolate(points: [
                SIMD3(0, 0, 0), SIMD3(1, 1, 0),
                SIMD3(2, 0, 0), SIMD3(3, 1, 0),
            ])
        else {
            Issue.record("interpolated BSpline not built")
            return
        }
        // A cubic interpolant with simple interior knots is C2 (GeomAbs_C2 = 4).
        #expect(bsp.continuity == 4)
    }
}
