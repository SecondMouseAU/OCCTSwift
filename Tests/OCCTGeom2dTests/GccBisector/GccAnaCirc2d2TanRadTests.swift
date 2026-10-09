import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GccAna Circ2d2TanRad Tests")
struct GccAnaCirc2d2TanRadTests {
    @Test("circles through two points with radius")
    func pointsWithRadius() {
        let results = circlesThroughPointsWithRadius(SIMD2(0, 0), SIMD2(2, 0), radius: 2.0)
        #expect(results.count == 2)
        for r in results {
            #expect(abs(r.radius - 2.0) < 1e-6)
        }
    }

    @Test("circles tangent to two perpendicular lines")
    func tangentToLines() {
        let results = circlesTangentToLines(
            SIMD2(0, 0), SIMD2(1, 0),
            SIMD2(0, 0), SIMD2(0, 1),
            radius: 5.0)
        #expect(results.count == 4)
    }
}
