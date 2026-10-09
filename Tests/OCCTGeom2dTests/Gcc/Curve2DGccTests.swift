import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Curve2D Gcc Tests

@Suite("Curve2D Gcc Tests")
struct Curve2DGccTests {

    @Test("Circle through three points")
    func circleThroughThreePoints() throws {
        let results = Curve2DGcc.circleThroughThreePoints(
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(5, 5),
            tolerance: 1e-6
        )
        // Unique circle through 3 non-collinear points
        // #1979: `radius > 0` passed any circle. Geom2dGcc_Circ2d3Tan gives the circumcircle,
        // centre (5, 0), radius 5 (Scripts/repro/766-geom2d-gcc-hatching/).
        try #require(results.count == 1)
        #expect(simd_distance(results[0].center, SIMD2(5, 0)) < 1e-9)
        #expect(abs(results[0].radius - 5) < 1e-9)
    }

    @Test("Circles through two points with radius")
    func circlesTwoPointsRadius() throws {
        let results = Curve2DGcc.circlesThroughTwoPoints(
            SIMD2(0, 0), SIMD2(6, 0),
            radius: 5, tolerance: 1e-6
        )
        // Two circles pass through 2 points at given radius (if radius > half-distance)
        for r in results {
            #expect(abs(r.radius - 5) < 1e-6)
        }
        // #1979: the radius alone passed circles in the wrong place. The centres are (3, 4) and
        // (3, -4), as Geom2dGcc_Circ2d2TanRad gives.
        let ys = results.map(\.center.y).sorted()
        try #require(ys.count == 2)
        #expect(abs(ys[0] + 4) < 1e-9)
        #expect(abs(ys[1] - 4) < 1e-9)
        #expect(results.allSatisfy { abs($0.center.x - 3) < 1e-9 })
    }

    @Test("Circle tangent to curve with center")
    func circleTanCen() throws {
        let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0))!
        let results = Curve2DGcc.circlesTangentWithCenter(
            line, .unqualified,
            center: SIMD2(5, 3), tolerance: 1e-6
        )
        // #1979: `count >= 1` inside `if let first`; Geom2dGcc_Circ2dTanCen gives exactly one.
        try #require(results.count == 1)
        // Circle centered at (5,3) tangent to X-axis should have radius 3
        #expect(abs(results[0].radius - 3) < 1e-9)
    }

    @Test("Lines tangent to circle through point")
    func linesTangentToPoint() throws {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let results = Curve2DGcc.linesTangentToPoint(
            circle, .outside,
            point: SIMD2(10, 0), tolerance: 1e-6
        )
        // #1979: `count >= 1` passed any line. Geometrically two lines from (10, 0) touch the
        // circle, but the `.outside` qualifier keeps only the one with the circle on its outside
        // side: Geom2dGcc_Lin2d2Tan returns one solution, touching at (2.5, 4.3301)
        // (Scripts/repro/766-geom2d-gcc-hatching/).
        try #require(results.count == 1)
        #expect(simd_distance(results[0].point, SIMD2(2.5, 4.33012701892)) < 1e-9)
        #expect(simd_distance(results[0].direction, SIMD2(0.866025403784, -0.5)) < 1e-9)
    }

    @Test("Circles tangent to curve and point with radius")
    func circleTanPtRad() throws {
        let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0))!
        let results = Curve2DGcc.circlesTangentToPointWithRadius(
            line, .unqualified,
            point: SIMD2(5, 5), radius: 5, tolerance: 1e-6
        )
        // #1979: `count >= 1` passed any circle. Radius 5, tangent to the x-axis and through
        // (5, 5): centres (0, 5) and (10, 5).
        let xs = results.map(\.center.x).sorted()
        try #require(xs.count == 2)
        #expect(abs(xs[0]) < 1e-9)
        #expect(abs(xs[1] - 10) < 1e-9)
        #expect(results.allSatisfy { abs($0.center.y - 5) < 1e-9 && abs($0.radius - 5) < 1e-9 })
    }
}
