import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.115.0 - GeomConvert Utilities")
struct GeomConvertUtilTests {
    // The earlier version skipped everything when the split came back empty, and checked only
    // `rejoined != nil` (#766). The single C2 span splits into one piece
    // (GeomConvert::C0BSplineToArrayOfC1BSplineCurve), which rejoins to the same end points.
    @Test func curveSplitAndJoin() {
        let pts = [SIMD3(0.0, 0.0, 0.0), SIMD3(5.0, 5.0, 0.0), SIMD3(10.0, 0.0, 0.0)]
        guard let curve = Curve3D.fit(points: pts) else {
            Issue.record("fitted curve not built")
            return
        }
        let segs = curve.splitAtContinuity()
        #expect(segs.count == 1)
        guard let rejoined = Curve3D.concatenateG1(curves: segs) else {
            Issue.record("rejoin returned nil")
            return
        }
        #expect(simd_distance(rejoined.startPoint, SIMD3(0, 0, 0)) < 1e-9)
        #expect(simd_distance(rejoined.endPoint, SIMD3(10, 0, 0)) < 1e-9)
    }
}
