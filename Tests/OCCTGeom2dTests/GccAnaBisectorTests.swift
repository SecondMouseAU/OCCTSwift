import Foundation
import Testing
import simd

@testable import OCCTSwift

// ============================================================================
// MARK: - v0.53.0: 2D Geometry Completions Tests
// ============================================================================

// #1979: these asserted `count >= 1`, a type, or an either-axis direction inside `if let`, so a
// bisector in the wrong place passed. Each now pins what the GccAna solver returns for the same
// input (Scripts/repro/766-geom2d-gccana-bisector-circ/).
@Suite("GccAna Bisectors") struct GccAnaBisectorTests {

    @Test("Perpendicular bisector of two points")
    func pointBisector() throws {
        let line = try #require(GccAnaBisector.ofPoints(SIMD2(0, 0), SIMD2(10, 0)))
        // Through the midpoint (5, 0), perpendicular to the segment: direction (0, 1).
        #expect(simd_distance(line.point, SIMD2(5, 0)) < 1e-12)
        #expect(simd_distance(line.direction, SIMD2(0, 1)) < 1e-12)
    }

    @Test("Angle bisectors of two lines")
    func lineBisectors() throws {
        let results = GccAnaBisector.ofLines(
            line1Point: SIMD2(0, 0), line1Dir: SIMD2(1, 0),
            line2Point: SIMD2(0, 0), line2Dir: SIMD2(0, 1))
        try #require(results.count == 2)
        // y = x and y = -x through the origin.
        let r = 0.5.squareRoot()
        #expect(results.allSatisfy { simd_length($0.point) < 1e-12 })
        #expect(simd_distance(results[0].direction, SIMD2(r, r)) < 1e-12)
        #expect(simd_distance(results[1].direction, SIMD2(-r, r)) < 1e-12)
    }

    @Test("Bisector between line and point")
    func linePointBisector() throws {
        let sol = try #require(
            GccAnaBisector.ofLineAndPoint(
                linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0),
                point: SIMD2(5, 5)))
        // The parabola with focus (5, 5) and directrix y = 0: vertex (5, 2.5), focal 2.5.
        #expect(sol.type == .parabola)
        #expect(simd_distance(sol.position, SIMD2(5, 2.5)) < 1e-12)
        #expect(abs(sol.secondary.x - 2.5) < 1e-12)
    }

    @Test("Bisectors between two circles")
    func circleBisectors() {
        let results = GccAnaBisector.ofCircles(
            center1: SIMD2(0, 0), radius1: 5,
            center2: SIMD2(15, 0), radius2: 3)
        // Four hyperbola branches centred at (7.5, 0): semi-axes 1 and 4 on the major side.
        #expect(results.count == 4)
        #expect(results.allSatisfy { $0.type == .hyperbola })
        #expect(results.allSatisfy { simd_distance($0.position, SIMD2(7.5, 0)) < 1e-9 })
        #expect(results.map(\.secondary.x).sorted() == [1, 1, 4, 4])
    }

    @Test("Bisectors between circle and line")
    func circleLineBisectors() {
        let results = GccAnaBisector.ofCircleAndLine(
            center: SIMD2(0, 0), radius: 5,
            linePoint: SIMD2(0, 10), lineDir: SIMD2(1, 0))
        // Two parabolas, vertices (0, 7.5) and (0, 2.5), focal distances 7.5 and 2.5.
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.type == .parabola })
        let vertexY = results.map(\.position.y).sorted()
        #expect(vertexY.count == 2 && abs(vertexY[0] - 2.5) < 1e-9 && abs(vertexY[1] - 7.5) < 1e-9)
    }

    @Test("Bisectors between circle and point")
    func circlePointBisectors() {
        let results = GccAnaBisector.ofCircleAndPoint(
            center: SIMD2(0, 0), radius: 5,
            point: SIMD2(10, 0))
        // Two hyperbola branches centred at (5, 0), semi-axes (2.5, 4.3301).
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.type == .hyperbola })
        #expect(results.allSatisfy { simd_distance($0.position, SIMD2(5, 0)) < 1e-9 })
        #expect(results.allSatisfy { simd_distance($0.secondary, SIMD2(2.5, 4.33012701892)) < 1e-9 })
    }
}
