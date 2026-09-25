import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: both counted solutions (and checked radii the caller supplied) without checking where the
// circles are. Centres from GccAna_Circ2d2TanRad (Scripts/repro/766-geom2d-gccana-bisector-circ/).
@Suite("GccAna Circ2d2TanRad Tests")
struct GccAnaCirc2d2TanRadTests {
    @Test("circles through two points with radius")
    func pointsWithRadius() {
        let results = circlesThroughPointsWithRadius(SIMD2(0, 0), SIMD2(2, 0), radius: 2.0)
        #expect(results.count == 2)
        for r in results {
            #expect(abs(r.radius - 2.0) < 1e-6)
            // Centres (1, +-sqrt 3).
            #expect(abs(r.center.x - 1) < 1e-9)
            #expect(abs(abs(r.center.y) - 3.0.squareRoot()) < 1e-9)
        }
    }

    @Test("circles tangent to two perpendicular lines")
    func tangentToLines() {
        let results = circlesTangentToLines(
            SIMD2(0, 0), SIMD2(1, 0),
            SIMD2(0, 0), SIMD2(0, 1),
            radius: 5.0)
        #expect(results.count == 4)
        // One in each quadrant: centres (+-5, +-5).
        #expect(results.allSatisfy { abs(abs($0.center.x) - 5) < 1e-9 && abs(abs($0.center.y) - 5) < 1e-9 })
        #expect(Set(results.map { [$0.center.x.sign, $0.center.y.sign] }).count == 4)
    }
}
