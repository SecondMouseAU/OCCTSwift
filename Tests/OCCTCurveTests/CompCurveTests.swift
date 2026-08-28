import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("CompCurve Tests")
struct CompCurveTests {

    @Test func concatenate3DCurves() {
        let seg1 = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(1, 0, 0))
        let seg2 = Curve3D.segment(from: SIMD3(1, 0, 0), to: SIMD3(2, 1, 0))
        if let s1 = seg1, let s2 = seg2 {
            let combined = Curve3D.concatenate([s1, s2], tolerance: 1e-3)
            #expect(combined != nil)
        }
    }

    @Test func concatenate2DCurves() {
        let seg1 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(1, 0))
        let seg2 = Curve2D.segment(from: SIMD2(1, 0), to: SIMD2(2, 1))
        if let s1 = seg1, let s2 = seg2 {
            let combined = Curve2D.concatenate([s1, s2], tolerance: 1e-3)
            #expect(combined != nil)
        }
    }
}
