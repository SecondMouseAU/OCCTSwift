import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.115.0 - GeomConvert Utilities")
struct GeomConvertUtilTests {

    @Test func curveSplitAndJoin() {
        let pts = [SIMD3(0.0, 0.0, 0.0), SIMD3(5.0, 5.0, 0.0), SIMD3(10.0, 0.0, 0.0)]
        if let curve = Curve3D.fit(points: pts) {
            let segs = curve.splitAtContinuity()
            if segs.count >= 1 {
                let rejoined = Curve3D.concatenateG1(curves: segs)
                #expect(rejoined != nil)
            }
        }
    }
}
