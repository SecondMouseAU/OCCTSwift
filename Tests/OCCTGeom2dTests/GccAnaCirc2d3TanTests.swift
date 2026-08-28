import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GccAna Circ2d3Tan Tests")
struct GccAnaCirc2d3TanTests {
    @Test func threePoints() {
        let solutions = Shape.circleThrough3Points(
            p1: SIMD2(0, 0), p2: SIMD2(10, 0), p3: SIMD2(5, 5))
        #expect(solutions.count == 1)
        if let sol = solutions.first {
            #expect(sol.radius > 0)
        }
    }

    @Test func threeLines() {
        let solutions = Shape.circleTangent3Lines(
            l1Point: SIMD2(0, 0), l1Dir: SIMD2(1, 0),
            l2Point: SIMD2(0, 0), l2Dir: SIMD2(0, 1),
            l3Point: SIMD2(10, 0), l3Dir: SIMD2(0, 1))
        #expect(solutions.count >= 1)
    }

    @Test func threeCircles() {
        let solutions = Shape.circleTangent3Circles(
            c1Center: SIMD2(0, 0), c1Radius: 3.0,
            c2Center: SIMD2(10, 0), c2Radius: 3.0,
            c3Center: SIMD2(5, 8), c3Radius: 3.0)
        #expect(solutions.count >= 1)
    }

    @Test func twoCirclesPoint() {
        let solutions = Shape.circleTangent2CirclesPoint(
            c1Center: SIMD2(0, 0), c1Radius: 3.0,
            c2Center: SIMD2(10, 0), c2Radius: 3.0,
            point: SIMD2(5, 15))
        #expect(solutions.count >= 1)
    }

    @Test func circleAndTwoPoints() {
        let solutions = Shape.circleTangentCircle2Points(
            circleCenter: SIMD2(0, 0), circleRadius: 3.0,
            p1: SIMD2(5, 5), p2: SIMD2(10, 10))
        #expect(solutions.count >= 1)
    }

    @Test func twoLinesPoint() {
        let solutions = Shape.circleTangent2LinesPoint(
            l1Point: SIMD2(0, 0), l1Dir: SIMD2(1, 0),
            l2Point: SIMD2(0, 0), l2Dir: SIMD2(0, 1),
            point: SIMD2(5, 5))
        #expect(solutions.count >= 1)
    }
}
