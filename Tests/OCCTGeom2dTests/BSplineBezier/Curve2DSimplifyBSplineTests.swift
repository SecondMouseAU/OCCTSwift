import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D SimplifyBSpline Tests")
struct Curve2DSimplifyBSplineTests {
    @Test("Simplify a BSpline curve")
    func simplify() throws {
        // Interpolate through more points than needed
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(2, 0.1), SIMD2(4, 0), SIMD2(6, 0.1),
            SIMD2(8, 0), SIMD2(10, 0),
        ]
        // #1979: this discarded the result (`_ = simplified`, "either way is valid") inside
        // `if let`, so it could not fail. ShapeCustom_Curve2d::SimplifyBSpline2d at 0.2 does
        // simplify this curve, from 8 poles and 6 knots to 6 and 4, keeping the end point
        // (Scripts/repro/766-geom2d-projection-simplify-transform/).
        let curve = try #require(Curve2D.interpolate(through: pts))
        #expect(curve.bspline.poleCount == 8)
        #expect(curve.simplifyBSpline(tolerance: 0.2))
        #expect(curve.bspline.poleCount == 6)
        #expect(curve.bspline.knotCount == 4)
        #expect(simd_distance(curve.endPoint, SIMD2(10, 0)) < 1e-9)
    }
}
