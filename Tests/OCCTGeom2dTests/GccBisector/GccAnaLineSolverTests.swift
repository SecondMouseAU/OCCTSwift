import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GccAna Line Solvers") struct GccAnaLineSolverTests {
    @Test("Line through point parallel to reference")
    func lineParallel() {
        let results = Curve2DGcc.lineParallelThrough(
            point: SIMD2(5, 5),
            parallelTo: SIMD2(0, 0), lineDir: SIMD2(1, 0))
        #expect(results.count >= 1)
        if let line = results.first {
            #expect(abs(line.direction.x - 1.0) < 0.01 || abs(line.direction.x + 1.0) < 0.01)
        }
    }

    @Test("Lines tangent to circle parallel to reference")
    func lineTangentParallel() {
        let results = Curve2DGcc.linesTangentParallel(
            circleCenter: SIMD2(0, 0), circleRadius: 5,
            parallelTo: SIMD2(0, 0), lineDir: SIMD2(1, 0))
        #expect(results.count == 2)
    }

    @Test("Line through point perpendicular to reference")
    func linePerpendicular() {
        let results = Curve2DGcc.linePerpendicularThrough(
            point: SIMD2(5, 5),
            perpendicularTo: SIMD2(0, 0), lineDir: SIMD2(1, 0))
        #expect(results.count >= 1)
        if let line = results.first {
            // perpendicular to horizontal → vertical direction
            #expect(abs(line.direction.y) > 0.9)
        }
    }

    @Test("Lines tangent to circle perpendicular to reference")
    func lineTangentPerpendicular() {
        let results = Curve2DGcc.linesTangentPerpendicular(
            circleCenter: SIMD2(0, 0), circleRadius: 5,
            perpendicularTo: SIMD2(0, 0), lineDir: SIMD2(1, 0))
        #expect(results.count == 2)
    }

    @Test("Line through point at angle to reference")
    func lineAtAngle() {
        let results = Curve2DGcc.lineAtAngleThrough(
            point: SIMD2(5, 5),
            referenceLine: SIMD2(0, 0), lineDir: SIMD2(1, 0),
            angle: .pi / 4)
        #expect(results.count >= 1)
    }

    @Test("Lines tangent to curve at angle (Geom2dGcc)")
    func lineTangentAtAngle() {
        let circle = Curve2D.circle(center: SIMD2(0, 0), radius: 5)
        if let circle {
            let results = Curve2DGcc.linesTangentAtAngle(
                circle,
                referenceLine: SIMD2(0, 0), lineDir: SIMD2(1, 0),
                angle: .pi / 4)
            #expect(results.count >= 1)
        }
    }
}
