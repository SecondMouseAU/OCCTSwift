import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeUpgrade SplitCurve Tests")
struct ShapeUpgradeSplitCurveTests {
    @Test("split smooth 3D curve")
    func splitSmooth3D() {
        if let bsp = Curve3D.bspline(
            poles: [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(3, 1, 0), SIMD3(4, 0, 0)],
            knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3)
        {
            let segments = bsp.splitByContinuity(criterion: 2)
            #expect(segments.count >= 1)
        }
    }

    @Test("split smooth 2D curve")
    func splitSmooth2D() {
        if let bsp = Curve2D.bspline(
            poles: [SIMD2(0, 0), SIMD2(1, 2), SIMD2(3, 1), SIMD2(4, 0)],
            knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3)
        {
            let segments = bsp.splitByContinuity(criterion: 2)
            #expect(segments.count >= 1)
        }
    }

    @Test("convert 2D curve to Bezier")
    func convertToBezier() {
        if let bsp = Curve2D.bspline(
            poles: [SIMD2(0, 0), SIMD2(1, 2), SIMD2(3, 1), SIMD2(4, 0)],
            knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3)
        {
            let segments = bsp.convertToBezierSegments()
            #expect(segments.count >= 1)
        }
    }
}
