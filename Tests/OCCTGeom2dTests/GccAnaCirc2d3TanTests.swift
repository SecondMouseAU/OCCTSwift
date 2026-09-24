import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: five of these asserted `count >= 1` and the sixth `radius > 0`, so a solver returning
// the wrong circles, or fewer of them, passed. Each now pins the solution set GccAna_Circ2d3Tan
// returns for the same input (Scripts/repro/766-geom2d-gccana-circ3tan-lines/).
@Suite("GccAna Circ2d3Tan Tests")
struct GccAnaCirc2d3TanTests {
    private func radii(_ s: [Shape.Circle2DSolution]) -> [Double] { s.map(\.radius).sorted() }
    private func close(_ a: [Double], _ b: [Double]) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { abs($0 - $1) < 1e-6 }
    }

    @Test func threePoints() throws {
        let solutions = Shape.circleThrough3Points(
            p1: SIMD2(0, 0), p2: SIMD2(10, 0), p3: SIMD2(5, 5))
        try #require(solutions.count == 1)
        #expect(abs(solutions[0].centerX - 5) < 1e-9)
        #expect(abs(solutions[0].centerY) < 1e-9)
        #expect(abs(solutions[0].radius - 5) < 1e-9)
    }

    @Test func threeLines() {
        // Between x = 0 and x = 10, tangent to y = 0: centres (5, +-5), radius 5.
        let solutions = Shape.circleTangent3Lines(
            l1Point: SIMD2(0, 0), l1Dir: SIMD2(1, 0),
            l2Point: SIMD2(0, 0), l2Dir: SIMD2(0, 1),
            l3Point: SIMD2(10, 0), l3Dir: SIMD2(0, 1))
        #expect(close(radii(solutions), [5, 5]))
        #expect(solutions.allSatisfy { abs($0.centerX - 5) < 1e-9 && abs(abs($0.centerY) - 5) < 1e-9 })
    }

    @Test func threeCircles() {
        let solutions = Shape.circleTangent3Circles(
            c1Center: SIMD2(0, 0), c1Radius: 3.0,
            c2Center: SIMD2(10, 0), c2Radius: 3.0,
            c3Center: SIMD2(5, 8), c3Radius: 3.0)
        // All eight Apollonius circles.
        #expect(
            close(
                radii(solutions),
                [2.5625, 4.89285714286, 5.04622471437, 5.04622471437, 8.5625, 8.70705074691,
                 8.70705074691, 10.25]))
    }

    @Test func twoCirclesPoint() {
        let solutions = Shape.circleTangent2CirclesPoint(
            c1Center: SIMD2(0, 0), c1Radius: 3.0,
            c2Center: SIMD2(10, 0), c2Radius: 3.0,
            point: SIMD2(5, 15))
        #expect(close(radii(solutions), [6.69444444444, 10.0416666667, 10.0416666667, 10.0416666667]))
    }

    @Test func circleAndTwoPoints() {
        let solutions = Shape.circleTangentCircle2Points(
            circleCenter: SIMD2(0, 0), circleRadius: 3.0,
            p1: SIMD2(5, 5), p2: SIMD2(10, 10))
        #expect(close(radii(solutions), [15.1666666667, 15.1666666667]))
    }

    @Test func twoLinesPoint() {
        let solutions = Shape.circleTangent2LinesPoint(
            l1Point: SIMD2(0, 0), l1Dir: SIMD2(1, 0),
            l2Point: SIMD2(0, 0), l2Dir: SIMD2(0, 1),
            point: SIMD2(5, 5))
        // Centres on y = x with radius equal to the coordinate: 5 -+ sqrt(50) ... i.e. 2.9289, 17.0711.
        #expect(close(radii(solutions), [2.92893218813, 17.0710678119]))
        #expect(solutions.allSatisfy { abs($0.centerX - $0.radius) < 1e-9 && abs($0.centerY - $0.radius) < 1e-9 })
    }
}
