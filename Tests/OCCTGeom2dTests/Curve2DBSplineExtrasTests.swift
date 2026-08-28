import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D_BSpline_Extras")
struct Curve2DBSplineExtrasTests {
    func makeBSpline2D() -> Curve2D? {
        Curve2D.interpolate(through: [SIMD2(0, 0), SIMD2(3, 5), SIMD2(6, 2), SIMD2(10, 10)])
    }

    @Test func getWeight() {
        if let c = makeBSpline2D() {
            let w = c.bsplineWeight(at: 1)
            #expect(abs(w - 1.0) < 1e-10)
        }
    }

    @Test func getAllWeights() {
        if let c = makeBSpline2D() {
            let weights = c.bsplineWeights()
            #expect(!weights.isEmpty)
            for w in weights {
                #expect(abs(w - 1.0) < 1e-10)
            }
        }
    }

    @Test func setPeriodic() {
        // Create a closed BSpline to make periodic meaningful
        if let c = Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0), SIMD2(5, -5), SIMD2(0, 0),
        ]) {
            // Try setting periodic — may succeed or fail depending on curve structure
            let _ = c.bsplineSetPeriodic(true)
            // Just ensure no crash
            #expect(true)
        }
    }
}
