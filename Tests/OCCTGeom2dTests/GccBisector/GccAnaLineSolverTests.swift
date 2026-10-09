import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: these asserted `count >= 1` and a direction to 0.01, or a count alone, so a line in the
// wrong place passed. Each now pins what the GccAna/Geom2dGcc line solver returns for the same
// input (Scripts/repro/766-geom2d-gccana-circ3tan-lines/).
@Suite("GccAna Line Solvers") struct GccAnaLineSolverTests {

    @Test("Line through point parallel to reference")
    func lineParallel() throws {
        let results = Curve2DGcc.lineParallelThrough(
            point: SIMD2(5, 5),
            parallelTo: SIMD2(0, 0), lineDir: SIMD2(1, 0))
        try #require(results.count == 1)
        #expect(simd_distance(results[0].point, SIMD2(5, 5)) < 1e-12)
        #expect(simd_distance(results[0].direction, SIMD2(1, 0)) < 1e-12)
    }

    @Test("Lines tangent to circle parallel to reference")
    func lineTangentParallel() {
        let results = Curve2DGcc.linesTangentParallel(
            circleCenter: SIMD2(0, 0), circleRadius: 5,
            parallelTo: SIMD2(0, 0), lineDir: SIMD2(1, 0))
        #expect(results.count == 2)
        // y = 5 and y = -5.
        #expect(results.map(\.point.y).sorted() == [-5, 5])
    }

    @Test("Line through point perpendicular to reference")
    func linePerpendicular() throws {
        let results = Curve2DGcc.linePerpendicularThrough(
            point: SIMD2(5, 5),
            perpendicularTo: SIMD2(0, 0), lineDir: SIMD2(1, 0))
        try #require(results.count == 1)
        // perpendicular to horizontal → vertical direction, through (5, 5)
        #expect(simd_distance(results[0].point, SIMD2(5, 5)) < 1e-12)
        #expect(abs(results[0].direction.x) < 1e-12)
        #expect(abs(abs(results[0].direction.y) - 1) < 1e-12)
    }

    @Test("Lines tangent to circle perpendicular to reference")
    func lineTangentPerpendicular() {
        let results = Curve2DGcc.linesTangentPerpendicular(
            circleCenter: SIMD2(0, 0), circleRadius: 5,
            perpendicularTo: SIMD2(0, 0), lineDir: SIMD2(1, 0))
        #expect(results.count == 2)
        // x = 5 and x = -5.
        #expect(results.map(\.point.x).sorted() == [-5, 5])
    }

    @Test("Line through point at angle to reference")
    func lineAtAngle() throws {
        let results = Curve2DGcc.lineAtAngleThrough(
            point: SIMD2(5, 5),
            referenceLine: SIMD2(0, 0), lineDir: SIMD2(1, 0),
            angle: .pi / 4)
        try #require(results.count == 1)
        let s = 0.5.squareRoot()
        #expect(simd_distance(results[0].point, SIMD2(5, 5)) < 1e-12)
        #expect(simd_distance(results[0].direction, SIMD2(s, s)) < 1e-12)
    }

    @Test("Lines tangent to curve at angle (Geom2dGcc)")
    func lineTangentAtAngle() throws {
        let circle = try #require(Curve2D.circle(center: SIMD2(0, 0), radius: 5))
        let results = Curve2DGcc.linesTangentAtAngle(
            circle,
            referenceLine: SIMD2(0, 0), lineDir: SIMD2(1, 0),
            angle: .pi / 4)
        // Two 45-degree tangents, touching at (+-3.5355, -+3.5355).
        try #require(results.count == 2)
        #expect(results.allSatisfy { abs(abs($0.point.x) - 3.53553390593) < 1e-6 && abs($0.point.x + $0.point.y) < 1e-6 })
    }
}
