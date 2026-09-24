import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to GeomConvert_CompCurveToBSplineCurve / Geom2dConvert_CompCurveToBSplineCurve on the
// same two segments (Scripts/repro/766-curve-comp-conic-deflection/transcript.txt): a degree-1
// BSpline from the first segment's start to the second's end, over [0, 1 + sqrt(2)]. The earlier
// versions checked only `!= nil` inside `if let`, so a bridge that dropped the second curve
// passed (#766).
@Suite("CompCurve Tests")
struct CompCurveTests {
    @Test func concatenate3DCurves() {
        guard let s1 = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(1, 0, 0)),
            let s2 = Curve3D.segment(from: SIMD3(1, 0, 0), to: SIMD3(2, 1, 0))
        else {
            Issue.record("segments not built")
            return
        }
        guard let combined = Curve3D.concatenate([s1, s2], tolerance: 1e-3) else {
            Issue.record("concatenation failed")
            return
        }
        #expect(simd_distance(combined.startPoint, SIMD3(0, 0, 0)) < 1e-12)
        #expect(simd_distance(combined.endPoint, SIMD3(2, 1, 0)) < 1e-12)
        #expect(abs(combined.domain.upperBound - (1 + 2.0.squareRoot())) < 1e-12)
    }

    @Test func concatenate2DCurves() {
        guard let s1 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(1, 0)),
            let s2 = Curve2D.segment(from: SIMD2(1, 0), to: SIMD2(2, 1))
        else {
            Issue.record("segments not built")
            return
        }
        guard let combined = Curve2D.concatenate([s1, s2], tolerance: 1e-3) else {
            Issue.record("concatenation failed")
            return
        }
        #expect(simd_distance(combined.startPoint, SIMD2(0, 0)) < 1e-12)
        #expect(simd_distance(combined.endPoint, SIMD2(2, 1)) < 1e-12)
        #expect(abs(combined.domain.upperBound - (1 + 2.0.squareRoot())) < 1e-12)
    }
}
