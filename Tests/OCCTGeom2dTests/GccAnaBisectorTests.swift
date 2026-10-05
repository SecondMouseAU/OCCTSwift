import Foundation
import Testing
import simd

@testable import OCCTSwift

// ============================================================================
// MARK: - v0.53.0: 2D Geometry Completions Tests
// ============================================================================

// #1979: these asserted `count >= 1`, a type, or an either-axis direction inside `if let`, so a
// bisector in the wrong place passed. Each now pins what the GccAna solver returns for the same
// input (Scripts/repro/766-geom2d-gccana-bisector-circ/), and every conic is derived from the
// equidistance it has to satisfy, so a number is checked against the geometry and not only
// against the last run. The fields mean what `BisecSolution` documents: a conic's `position` is
// its centre (a parabola's, its vertex), never a focus, and `secondary` is (major, minor) for a
// hyperbola and (focal distance, 0) for a parabola.
@Suite("GccAna Bisectors") struct GccAnaBisectorTests {

    @Test("Perpendicular bisector of two points")
    func pointBisector() throws {
        let line = try #require(GccAnaBisector.ofPoints(SIMD2(0, 0), SIMD2(10, 0)))
        // Through the midpoint (5, 0), perpendicular to the segment: direction (0, 1).
        #expect(simd_distance(line.point, SIMD2(5, 0)) < 1e-12)
        #expect(simd_distance(line.direction, SIMD2(0, 1)) < 1e-12)

        // A segment along neither axis, so a direction swapped or taken along the segment is not
        // mistaken for the answer. (1, 1) to (4, 5): the midpoint is (2.5, 3), the segment runs
        // (3, 4), and the bisector is that turned a quarter turn anticlockwise, (-4, 3) / 5.
        let slanted = try #require(GccAnaBisector.ofPoints(SIMD2(1, 1), SIMD2(4, 5)))
        #expect(simd_distance(slanted.point, SIMD2(2.5, 3)) < 1e-12)
        #expect(simd_distance(slanted.direction, SIMD2(-0.8, 0.6)) < 1e-12)
    }

    @Test("Angle bisectors of two lines")
    func lineBisectors() throws {
        let results = GccAnaBisector.ofLines(
            line1Point: SIMD2(0, 0), line1Dir: SIMD2(1, 0),
            line2Point: SIMD2(0, 0), line2Dir: SIMD2(0, 1))
        try #require(results.count == 2)
        // y = x and y = -x through the origin. The order and the sense of each direction are the
        // solver's own (measured): the bisector of the angle between the lines, then the one
        // across it.
        let r = 0.5.squareRoot()
        #expect(results.allSatisfy { simd_length($0.point) < 1e-12 })
        #expect(simd_distance(results[0].direction, SIMD2(r, r)) < 1e-12)
        #expect(simd_distance(results[1].direction, SIMD2(-r, r)) < 1e-12)

        // Lines at 0 and 60 degrees, which are not symmetric under swapping x and y: the angle
        // bisectors are at 30 and 120 degrees, (cos 30, sin 30) and (-sin 30, cos 30).
        let slanted = GccAnaBisector.ofLines(
            line1Point: SIMD2(0, 0), line1Dir: SIMD2(1, 0),
            line2Point: SIMD2(0, 0), line2Dir: SIMD2(0.5, 0.75.squareRoot()))
        try #require(slanted.count == 2)
        let s = 0.75.squareRoot()
        #expect(slanted.allSatisfy { simd_length($0.point) < 1e-12 })
        #expect(simd_distance(slanted[0].direction, SIMD2(s, 0.5)) < 1e-12)
        #expect(simd_distance(slanted[1].direction, SIMD2(-0.5, s)) < 1e-12)
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
        #expect(sol.secondary.y == 0)
    }

    @Test("Bisectors between two circles")
    func circleBisectors() throws {
        let results = GccAnaBisector.ofCircles(
            center1: SIMD2(0, 0), radius1: 5,
            center2: SIMD2(15, 0), radius2: 3)
        // Four hyperbola branches, all centred at (7.5, 0) with the two circle centres as foci, so
        // c = 7.5 and b = sqrt(c^2 - a^2). A point P equidistant from the circles has
        // |P - C1| - |P - C2| = +-(r1 - r2) = +-2 or +-(r1 + r2) = +-8, and 2a is that
        // difference: a = 1 and a = 4, two branches each.
        try #require(results.count == 4)
        #expect(results.allSatisfy { $0.type == .hyperbola })
        #expect(results.allSatisfy { simd_distance($0.position, SIMD2(7.5, 0)) < 1e-9 })
        let c = 7.5
        let byMajor = results.sorted { $0.secondary.x < $1.secondary.x }
        for (sol, a) in zip(byMajor, [1.0, 1.0, 4.0, 4.0]) {
            #expect(abs(sol.secondary.x - a) < 1e-12)
            #expect(abs(sol.secondary.y - (c * c - a * a).squareRoot()) < 1e-12)
        }
    }

    @Test("Bisectors between circle and line")
    func circleLineBisectors() throws {
        let results = GccAnaBisector.ofCircleAndLine(
            center: SIMD2(0, 0), radius: 5,
            linePoint: SIMD2(0, 10), lineDir: SIMD2(1, 0))
        // Two parabolas with the circle's centre as focus and a directrix 5 either side of the
        // line, y = 15 and y = 5: vertices (0, 7.5) and (0, 2.5), halfway from the focus to each
        // directrix, so focal distances 7.5 and 2.5. Each vertex goes with ITS focal distance.
        try #require(results.count == 2)
        #expect(results.allSatisfy { $0.type == .parabola })
        let byVertex = results.sorted { $0.position.y < $1.position.y }
        for (sol, vertexY) in zip(byVertex, [2.5, 7.5]) {
            #expect(abs(sol.position.x) < 1e-9)
            #expect(abs(sol.position.y - vertexY) < 1e-9)
            #expect(abs(sol.secondary.x - vertexY) < 1e-9)
            #expect(sol.secondary.y == 0)
        }
    }

    @Test("Bisectors between circle and point")
    func circlePointBisectors() throws {
        let results = GccAnaBisector.ofCircleAndPoint(
            center: SIMD2(0, 0), radius: 5,
            point: SIMD2(10, 0))
        // Two hyperbola branches centred at (5, 0), the foci being the circle's centre and the
        // point, so c = 5, and a = radius / 2 = 2.5, which gives b = sqrt(25 - 6.25).
        try #require(results.count == 2)
        #expect(results.allSatisfy { $0.type == .hyperbola })
        #expect(results.allSatisfy { simd_distance($0.position, SIMD2(5, 0)) < 1e-9 })
        let b = (25.0 - 6.25).squareRoot()
        #expect(results.allSatisfy { simd_distance($0.secondary, SIMD2(2.5, b)) < 1e-12 })
    }
}
