import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: five of these asserted `count >= 1` and the sixth `radius > 0`, so a solver returning
// the wrong circles, or fewer of them, passed. Each now pins the solution set GccAna_Circ2d3Tan
// returns for the same input (Scripts/repro/766-geom2d-gccana-circ3tan-lines/).
//
// Two kinds of number are pinned and they are not the same claim. Where the answer follows from
// the geometry (a circumcircle, the circles between two lines, a triangle's incircle and
// excircles) it is derived in the comment and does not depend on the kernel. The radii of the
// eight circles tangent to three equal circles, of the four through a point and tangent to two,
// and of the two through two points and tangent to one are the committed probe's measurement and
// are kept as that. Every solution is also held to the geometry it has to satisfy, tangent to
// each input and through each point, which is true of a solution whatever number it came back as,
// and it is what makes a radius or a centre handed to the wrong input visible: with equal radii
// the eight circles are the same set whichever circle got which radius.
@Suite("GccAna Circ2d3Tan Tests")
struct GccAnaCirc2d3TanTests {
    private typealias Solution = Shape.Circle2DSolution
    private typealias Disc = (center: SIMD2<Double>, radius: Double)
    private typealias Line = (point: SIMD2<Double>, direction: SIMD2<Double>)

    private func radii(_ s: [Solution]) -> [Double] { s.map(\.radius).sorted() }

    private func close(_ a: [Double], _ b: [Double]) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { abs($0 - $1) < 1e-9 }
    }

    private func center(_ s: Solution) -> SIMD2<Double> { SIMD2(s.centerX, s.centerY) }

    /// How far a solution is from touching a circle: the centres are `r + rho` apart when the
    /// circles are outside each other and `|r - rho|` apart when one holds the other.
    private func tangencyError(_ s: Solution, _ c: Disc) -> Double {
        let d = simd_distance(center(s), c.center)
        return min(abs(d - (s.radius + c.radius)), abs(d - abs(s.radius - c.radius)))
    }

    /// How far a solution is from touching a line: its centre is `r` from the line.
    private func lineError(_ s: Solution, _ line: Line) -> Double {
        let normal = SIMD2(-line.direction.y, line.direction.x) / simd_length(line.direction)
        return abs(abs(simd_dot(center(s) - line.point, normal)) - s.radius)
    }

    /// How far a solution is from passing through a point.
    private func pointError(_ s: Solution, _ p: SIMD2<Double>) -> Double {
        abs(simd_distance(center(s), p) - s.radius)
    }

    @Test func threePoints() throws {
        // The circumcircle of (0, 0), (10, 0), (5, 5): the centre is on x = 5, and
        // 25 + y^2 = (5 - y)^2 gives y = 0, so the radius is 5.
        let solutions = Shape.circleThrough3Points(
            p1: SIMD2(0, 0), p2: SIMD2(10, 0), p3: SIMD2(5, 5))
        try #require(solutions.count == 1)
        #expect(abs(solutions[0].centerX - 5) < 1e-9)
        #expect(abs(solutions[0].centerY) < 1e-9)
        #expect(abs(solutions[0].radius - 5) < 1e-9)
    }

    @Test func threeLines() throws {
        // Between x = 0 and x = 10, tangent to y = 0: centres (5, +-5), radius 5.
        let solutions = Shape.circleTangent3Lines(
            l1Point: SIMD2(0, 0), l1Dir: SIMD2(1, 0),
            l2Point: SIMD2(0, 0), l2Dir: SIMD2(0, 1),
            l3Point: SIMD2(10, 0), l3Dir: SIMD2(0, 1))
        #expect(close(radii(solutions), [5, 5]))
        #expect(
            solutions.allSatisfy { abs($0.centerX - 5) < 1e-9 && abs(abs($0.centerY) - 5) < 1e-9 })
        let lines: [Line] = [
            (SIMD2<Double>(0, 0), SIMD2<Double>(1, 0)), (SIMD2<Double>(0, 0), SIMD2<Double>(0, 1)),
            (SIMD2<Double>(10, 0), SIMD2<Double>(0, 1)),
        ]
        for s in solutions {
            for l in lines { #expect(lineError(s, l) < 1e-9) }
        }
    }

    @Test func threeLinesOfATriangle() throws {
        // Lines forming a triangle that is not symmetric in x and y: the legs on the axes and the
        // hypotenuse through (3, 0) and (0, 4). It is a 3-4-5 triangle with area 6 and semi-perimeter
        // 6, so the incircle has radius 6 / 6 = 1 and the three excircles 6 / (6 - 5) = 6,
        // 6 / (6 - 4) = 3 and 6 / (6 - 3) = 2. The centres sit at (+-r, +-r), and the distance to
        // 4x + 3y = 12 being r picks (1, 1) and (6, 6) in the first quadrant, (-3, 3) and (2, -2).
        let solutions = Shape.circleTangent3Lines(
            l1Point: SIMD2(0, 0), l1Dir: SIMD2(1, 0),
            l2Point: SIMD2(0, 0), l2Dir: SIMD2(0, 1),
            l3Point: SIMD2(3, 0), l3Dir: SIMD2(-3, 4))
        let byRadius = solutions.sorted { $0.radius < $1.radius }
        try #require(byRadius.count == 4)
        let want: [(radius: Double, x: Double, y: Double)] = [
            (1, 1, 1), (2, 2, -2), (3, -3, 3), (6, 6, 6),
        ]
        for (got, expected) in zip(byRadius, want) {
            #expect(abs(got.radius - expected.radius) < 1e-9)
            #expect(simd_distance(center(got), SIMD2(expected.x, expected.y)) < 1e-9)
        }
        let lines: [Line] = [
            (SIMD2<Double>(0, 0), SIMD2<Double>(1, 0)), (SIMD2<Double>(0, 0), SIMD2<Double>(0, 1)),
            (SIMD2<Double>(3, 0), SIMD2<Double>(-3, 4)),
        ]
        for s in solutions {
            for l in lines { #expect(lineError(s, l) < 1e-9) }
        }
    }

    @Test func threeCircles() throws {
        let discs: [Disc] = [
            (SIMD2<Double>(0, 0), 3), (SIMD2<Double>(10, 0), 3), (SIMD2<Double>(5, 8), 3),
        ]
        let solutions = Shape.circleTangent3Circles(
            c1Center: SIMD2(0, 0), c1Radius: 3.0,
            c2Center: SIMD2(10, 0), c2Radius: 3.0,
            c3Center: SIMD2(5, 8), c3Radius: 3.0)
        // All eight Apollonius circles. The centres form a triangle with sides 10, sqrt 89 and
        // sqrt 89 and area 40, so its circumradius is 10 * 89 / (4 * 40) = 5.5625: the circle
        // outside all three is 5.5625 - 3 = 2.5625 and the one around all three is
        // 5.5625 + 3 = 8.5625. The other six are the probe's measurement.
        #expect(
            close(
                radii(solutions),
                [
                    2.5625, 4.89285714286, 5.04622471437, 5.04622471437, 8.5625, 8.70705074691,
                    8.70705074691, 10.25,
                ]))
        for s in solutions {
            for d in discs { #expect(tangencyError(s, d) < 1e-9) }
        }
    }

    @Test func threeCirclesOfDifferentRadii() throws {
        // Three different radii, so a radius or a centre handed to the wrong circle changes the
        // answer. Disjoint circles have all eight tangent circles, and each must touch all three
        // of THESE circles.
        let discs: [Disc] = [
            (SIMD2<Double>(0, 0), 2), (SIMD2<Double>(10, 0), 3), (SIMD2<Double>(4, 9), 1),
        ]
        let solutions = Shape.circleTangent3Circles(
            c1Center: SIMD2(0, 0), c1Radius: 2.0,
            c2Center: SIMD2(10, 0), c2Radius: 3.0,
            c3Center: SIMD2(4, 9), c3Radius: 1.0)
        try #require(solutions.count == 8)
        for s in solutions {
            for d in discs { #expect(tangencyError(s, d) < 1e-9) }
        }
    }

    @Test func twoCirclesPoint() throws {
        let discs: [Disc] = [(SIMD2<Double>(0, 0), 3), (SIMD2<Double>(10, 0), 3)]
        let point = SIMD2<Double>(5, 15)
        let solutions = Shape.circleTangent2CirclesPoint(
            c1Center: SIMD2(0, 0), c1Radius: 3.0,
            c2Center: SIMD2(10, 0), c2Radius: 3.0,
            point: point)
        // The probe's measurement, four circles; the point is outside both circles.
        #expect(
            close(radii(solutions), [6.69444444444, 10.0416666667, 10.0416666667, 10.0416666667]))
        for s in solutions {
            #expect(pointError(s, point) < 1e-9)
            for d in discs { #expect(tangencyError(s, d) < 1e-9) }
        }
    }

    @Test func twoCirclesPointOfDifferentRadii() throws {
        // As above with unequal radii, so each circle's radius has to reach its own circle.
        let discs: [Disc] = [(SIMD2<Double>(0, 0), 2), (SIMD2<Double>(10, 0), 3)]
        let point = SIMD2<Double>(4, 12)
        let solutions = Shape.circleTangent2CirclesPoint(
            c1Center: SIMD2(0, 0), c1Radius: 2.0,
            c2Center: SIMD2(10, 0), c2Radius: 3.0,
            point: point)
        try #require(solutions.count == 4)
        for s in solutions {
            #expect(pointError(s, point) < 1e-9)
            for d in discs { #expect(tangencyError(s, d) < 1e-9) }
        }
    }

    @Test func circleAndTwoPoints() throws {
        let disc: Disc = (SIMD2<Double>(0, 0), 3)
        let points = [SIMD2<Double>(5, 5), SIMD2<Double>(10, 10)]
        let solutions = Shape.circleTangentCircle2Points(
            circleCenter: SIMD2(0, 0), circleRadius: 3.0,
            p1: SIMD2(5, 5), p2: SIMD2(10, 10))
        // The probe's measurement, 91 / 6 twice: the two circles are mirror images in y = x.
        #expect(close(radii(solutions), [15.1666666667, 15.1666666667]))
        for s in solutions {
            #expect(tangencyError(s, disc) < 1e-9)
            for p in points { #expect(pointError(s, p) < 1e-9) }
        }
    }

    @Test func circleAndTwoPointsOffTheDiagonal() throws {
        // A circle off the origin and both points outside it, with nothing symmetric about
        // y = x, so a swapped coordinate or a swapped point is not the same answer: two
        // solutions, each through both points and tangent to the circle.
        let disc: Disc = (SIMD2<Double>(1, 2), 3)
        let points = [SIMD2<Double>(5, 1), SIMD2<Double>(9, 4)]
        let solutions = Shape.circleTangentCircle2Points(
            circleCenter: SIMD2(1, 2), circleRadius: 3.0,
            p1: SIMD2(5, 1), p2: SIMD2(9, 4))
        try #require(solutions.count == 2)
        for s in solutions {
            #expect(tangencyError(s, disc) < 1e-9)
            for p in points { #expect(pointError(s, p) < 1e-9) }
        }
    }

    @Test func twoLinesPoint() throws {
        let solutions = Shape.circleTangent2LinesPoint(
            l1Point: SIMD2(0, 0), l1Dir: SIMD2(1, 0),
            l2Point: SIMD2(0, 0), l2Dir: SIMD2(0, 1),
            point: SIMD2(5, 5))
        // Centres on y = x with radius equal to the coordinate, and (5 - r)^2 * 2 = r^2 gives
        // r^2 - 20 r + 50 = 0, so r = 10 -+ sqrt 50: 2.9289 and 17.0711.
        let root = 50.0.squareRoot()
        #expect(close(radii(solutions), [10 - root, 10 + root]))
        #expect(
            solutions.allSatisfy {
                abs($0.centerX - $0.radius) < 1e-9 && abs($0.centerY - $0.radius) < 1e-9
            })
        let lines: [Line] = [
            (SIMD2<Double>(0, 0), SIMD2<Double>(1, 0)), (SIMD2<Double>(0, 0), SIMD2<Double>(0, 1)),
        ]
        for s in solutions {
            #expect(pointError(s, SIMD2(5, 5)) < 1e-9)
            for l in lines { #expect(lineError(s, l) < 1e-9) }
        }
    }

    @Test func twoLinesPointOffTheDiagonal() throws {
        // The line y = 0 and the line x = 3, with the point (5, 4), where swapping x and y is
        // not the same problem. Tangent to both means a centre at (3 + r, r), (3 - r, r),
        // (3 + r, -r) or (3 - r, -r), and passing through (5, 4) leaves
        // r^2 - 12 r + 20 = 0 for the first, so r = 2 and r = 10: centres (5, 2) and (13, 10).
        // The other three have no real root or only negative ones.
        let solutions = Shape.circleTangent2LinesPoint(
            l1Point: SIMD2(0, 0), l1Dir: SIMD2(1, 0),
            l2Point: SIMD2(3, 0), l2Dir: SIMD2(0, 1),
            point: SIMD2(5, 4))
        let byRadius = solutions.sorted { $0.radius < $1.radius }
        try #require(byRadius.count == 2)
        #expect(abs(byRadius[0].radius - 2) < 1e-9)
        #expect(simd_distance(center(byRadius[0]), SIMD2(5, 2)) < 1e-9)
        #expect(abs(byRadius[1].radius - 10) < 1e-9)
        #expect(simd_distance(center(byRadius[1]), SIMD2(13, 10)) < 1e-9)
    }
}
