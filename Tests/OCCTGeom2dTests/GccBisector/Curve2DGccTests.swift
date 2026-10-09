import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Curve2D Gcc Tests

@Suite("Curve2D Gcc Tests")
struct Curve2DGccTests {

    @Test("Circle through three points")
    func circleThroughThreePoints() {
        let results = Curve2DGcc.circleThroughThreePoints(
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(5, 5),
            tolerance: 1e-6
        )
        // Unique circle through 3 non-collinear points
        #expect(results.count == 1)
        if let first = results.first {
            #expect(first.radius > 0)
        }
    }

    @Test("Circles through two points with radius")
    func circlesTwoPointsRadius() {
        let results = Curve2DGcc.circlesThroughTwoPoints(
            SIMD2(0, 0), SIMD2(6, 0),
            radius: 5, tolerance: 1e-6
        )
        // Two circles pass through 2 points at given radius (if radius > half-distance)
        #expect(results.count == 2)
        for r in results {
            #expect(abs(r.radius - 5) < 1e-6)
        }
    }

    @Test("Circle tangent to curve with center")
    func circleTanCen() {
        let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0))!
        let results = Curve2DGcc.circlesTangentWithCenter(
            line, .unqualified,
            center: SIMD2(5, 3), tolerance: 1e-6
        )
        #expect(results.count >= 1)
        if let first = results.first {
            // Circle centered at (5,3) tangent to X-axis should have radius 3
            #expect(abs(first.radius - 3) < 1e-4)
        }
    }

    @Test("Lines tangent to circle through point")
    func linesTangentToPoint() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let results = Curve2DGcc.linesTangentToPoint(
            circle, .outside,
            point: SIMD2(10, 0), tolerance: 1e-6
        )
        // Two tangent lines from external point to circle
        #expect(results.count >= 1)
    }

    @Test("Circles tangent to curve and point with radius")
    func circleTanPtRad() {
        let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0))!
        let results = Curve2DGcc.circlesTangentToPointWithRadius(
            line, .unqualified,
            point: SIMD2(5, 5), radius: 5, tolerance: 1e-6
        )
        #expect(results.count >= 1)
    }
}
