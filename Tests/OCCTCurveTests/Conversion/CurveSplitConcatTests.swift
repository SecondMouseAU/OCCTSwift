import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.115.0 - Curve Split and Concatenate")
struct CurveSplitConcatTests {

    @Test func splitAtContinuity3D() {
        let points = [SIMD3(0.0, 0.0, 0.0), SIMD3(5.0, 5.0, 0.0), SIMD3(10.0, 0.0, 0.0)]
        guard let curve = Curve3D.fit(points: points) else {
            Issue.record("fitted curve not built")
            return
        }
        // A single C2 span has no C1 break: one piece, the curve itself
        // (GeomConvert::C0BSplineToArrayOfC1BSplineCurve, Scripts/repro/766-curve-join-length-split/).
        let segs = curve.splitAtContinuity()
        #expect(segs.count == 1)
        #expect(simd_distance(segs.first?.endPoint ?? .zero, SIMD3(10, 0, 0)) < 1e-9)
    }

    @Test func concatenateCurvesG1() {
        let pts1 = [SIMD3(0.0, 0.0, 0.0), SIMD3(5.0, 5.0, 0.0), SIMD3(10.0, 0.0, 0.0)]
        let pts2 = [SIMD3(10.0, 0.0, 0.0), SIMD3(15.0, -5.0, 0.0), SIMD3(20.0, 0.0, 0.0)]
        guard let c1 = Curve3D.fit(points: pts1), let c2 = Curve3D.fit(points: pts2) else {
            Issue.record("fitted curves not built")
            return
        }
        guard let joined = Curve3D.concatenateG1(curves: [c1, c2]) else {
            Issue.record("concatenateG1 returned nil")
            return
        }
        #expect(simd_distance(joined.startPoint, SIMD3(0, 0, 0)) < 1e-9)
        #expect(simd_distance(joined.endPoint, SIMD3(20, 0, 0)) < 1e-9)
    }

    @Test func concatenateG1RejectsDisconnectedCurve() {
        // Same shape as joinRejectsDisconnectedCurve (#1441), for the sibling
        // OCCTCurve3DConcatenateG1 entry point: a 4-unit gap is far past the default 1e-6
        // tolerance, so Add() must fail and concatenateG1 must return nil, not silently drop
        // the second curve.
        let c1 = Curve3D.segment(from: SIMD3(0.0, 0.0, 0.0), to: SIMD3(1.0, 0.0, 0.0))!
        let c2 = Curve3D.segment(from: SIMD3(5.0, 0.0, 0.0), to: SIMD3(6.0, 0.0, 0.0))!
        let joined = Curve3D.concatenateG1(curves: [c1, c2])
        #expect(joined == nil)
    }

    @Test func splitCurve2DAtContinuity() {
        let points = [SIMD2(0.0, 0.0), SIMD2(5.0, 5.0), SIMD2(10.0, 0.0)]
        guard let curve = Curve2D.fit(through: points) else {
            Issue.record("fitted 2D curve not built")
            return
        }
        let segs = curve.splitAtContinuity()
        #expect(segs.count == 1)
    }
}
