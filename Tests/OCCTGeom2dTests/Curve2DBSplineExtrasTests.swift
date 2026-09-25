import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: these nested their assertions in `if let c`, so a nil curve passed; `getAllWeights`
// passed an empty array, and `setPeriodic` asserted `#expect(true)`. Values from
// Geom2d_BSplineCurve for the same curves (Scripts/repro/766-geom2d-bisector-bbox-weights/).
@Suite("Curve2D_BSpline_Extras")
struct Curve2DBSplineExtrasTests {
    func makeBSpline2D() throws -> Curve2D {
        try #require(
            Curve2D.interpolate(through: [SIMD2(0, 0), SIMD2(3, 5), SIMD2(6, 2), SIMD2(10, 10)]))
    }

    @Test func getWeight() throws {
        let c = try makeBSpline2D()
        let w = c.bsplineWeight(at: 1)
        #expect(abs(w - 1.0) < 1e-10)
    }

    @Test func getAllWeights() throws {
        // A non-rational interpolant: six poles, every weight 1.
        let c = try makeBSpline2D()
        let weights = c.bsplineWeights()
        #expect(weights.count == 6)
        for w in weights {
            #expect(abs(w - 1.0) < 1e-10)
        }
    }

    @Test func setPeriodic() throws {
        // Create a closed BSpline to make periodic meaningful. The interpolant through a closed
        // point list is closed but not periodic, with 7 poles; SetPeriodic makes it periodic
        // with 6.
        let c = try #require(
            Curve2D.interpolate(through: [
                SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0), SIMD2(5, -5), SIMD2(0, 0),
            ]))
        #expect(!c.isPeriodic)
        #expect(c.bsplineSetPeriodic(true))
        #expect(c.isPeriodic)
        #expect(c.bspline.poleCount == 6)
    }
}
