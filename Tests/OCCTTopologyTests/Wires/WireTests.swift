import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Wire Tests")
struct WireTests {

    @Test("Create rectangle wire")
    func createRectangle() throws {
        // Centred on the origin: a closed loop of four edges, perimeter 30, spanning
        // x in [-5, 5] and y in [-2.5, 2.5].
        let rect = try #require(Wire.rectangle(width: 10, height: 5))
        #expect(rect.edges().count == 4)
        #expect(abs(try #require(rect.length) - 30) < 1e-9)
        #expect(try #require(rect.curveInfo).isClosed)
        let b = try #require(rect.bounds)
        #expect(abs(b.min.x + 5) < 1e-6)
        #expect(abs(b.max.x - 5) < 1e-6)
        #expect(abs(b.min.y + 2.5) < 1e-6)
        #expect(abs(b.max.y - 2.5) < 1e-6)
    }

    @Test("Create polygon wire")
    func createPolygon() throws {
        let polygon = try #require(
            Wire.polygon(
                [
                    SIMD2(0, 0),
                    SIMD2(10, 0),
                    SIMD2(10, 5),
                    SIMD2(0, 5),
                ], closed: true))
        // Four points closed: four edges, perimeter 30, corner at the origin, extent 10 x 5.
        #expect(polygon.edges().count == 4)
        #expect(abs(try #require(polygon.length) - 30) < 1e-9)
        #expect(try #require(polygon.curveInfo).isClosed)
        let b = try #require(polygon.bounds)
        #expect(abs(b.min.x) < 1e-6)
        #expect(abs(b.min.y) < 1e-6)
        #expect(abs(b.max.x - 10) < 1e-6)
        #expect(abs(b.max.y - 5) < 1e-6)

        // Open, the same points give three edges and length 25.
        let open = try #require(
            Wire.polygon([SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 5), SIMD2(0, 5)], closed: false))
        #expect(open.edges().count == 3)
        #expect(abs(try #require(open.length) - 25) < 1e-9)
    }

    @Test("Create arc wire")
    func createArc() throws {
        let arc = try #require(
            Wire.arc(
                center: .zero,
                radius: 50,
                startAngle: 0,
                endAngle: .pi / 2
            ))
        // A quarter of a radius-50 circle: length 25 pi, from (50,0,0) to (0,50,0), one
        // circular edge, midpoint on the diagonal at 50 cos 45.
        let edges = arc.edges()
        #expect(edges.count == 1)
        #expect(edges.first?.isCircle == true)
        #expect(abs(try #require(arc.length) - 25 * .pi) < 1e-9)
        let info = try #require(arc.curveInfo)
        #expect(!info.isClosed)
        #expect(vectorDistance(info.startPoint, SIMD3(50, 0, 0)) < 1e-9)
        #expect(vectorDistance(info.endPoint, SIMD3(0, 50, 0)) < 1e-9)
        let mid = try #require(arc.point(at: 0.5))
        let h = 50 / 2.0.squareRoot()
        #expect(vectorDistance(mid, SIMD3(h, h, 0)) < 1e-9)
    }

    @Test("Create line wire")
    func createLine() throws {
        let line = try #require(
            Wire.line(
                from: SIMD3(0, 0, 0),
                to: SIMD3(100, 0, 0)
            ))
        // One straight edge of length 100 from (0,0,0) to (100,0,0).
        let edges = line.edges()
        #expect(edges.count == 1)
        #expect(edges.first?.isLine == true)
        #expect(abs(try #require(line.length) - 100) < 1e-9)
        let info = try #require(line.curveInfo)
        #expect(vectorDistance(info.startPoint, SIMD3(0, 0, 0)) < 1e-9)
        #expect(vectorDistance(info.endPoint, SIMD3(100, 0, 0)) < 1e-9)
        #expect(!info.isClosed)
    }

    @Test("Create cubic B-spline")
    func createCubicBSpline() throws {
        let poles = [
            SIMD3<Double>(0, 0, 0),
            SIMD3<Double>(10, 5, 0),
            SIMD3<Double>(20, 0, 0),
            SIMD3<Double>(30, 5, 0),
            SIMD3<Double>(40, 0, 0),
        ]
        let curve = try #require(Wire.cubicBSpline(poles: poles))
        // A clamped cubic: it starts at the first pole and ends at the last, and by symmetry
        // of the poles passes through (20, 2.5) at the middle; the quarter points are
        // (11.875, 3.125) and (28.125, 3.125). Measured on kernel.6; length 41.0984433.
        let info = try #require(curve.curveInfo)
        #expect(vectorDistance(info.startPoint, SIMD3(0, 0, 0)) < 1e-9)
        #expect(vectorDistance(info.endPoint, SIMD3(40, 0, 0)) < 1e-9)
        #expect(!info.isClosed)
        #expect(vectorDistance(try #require(curve.point(at: 0.5)), SIMD3(20, 2.5, 0)) < 1e-9)
        #expect(vectorDistance(try #require(curve.point(at: 0.25)), SIMD3(11.875, 3.125, 0)) < 1e-9)
        #expect(vectorDistance(try #require(curve.point(at: 0.75)), SIMD3(28.125, 3.125, 0)) < 1e-9)
        #expect(abs(info.length - 41.098443341681) < 1e-6)
    }

    @Test("Create NURBS with uniform knots")
    func createNURBSUniform() throws {
        let poles = [
            SIMD3<Double>(0, 0, 0),
            SIMD3<Double>(10, 10, 0),
            SIMD3<Double>(20, 0, 0),
            SIMD3<Double>(30, 10, 0),
        ]
        let curve = try #require(Wire.nurbsUniform(poles: poles, degree: 2))
        // Degree 2 over four poles, clamped: from (0,0,0) to (30,10,0), through (15,5,0) at
        // the middle, (8.75, 6.25, 0) and (21.25, 3.75, 0) at the quarter points.
        let info = try #require(curve.curveInfo)
        #expect(vectorDistance(info.startPoint, SIMD3(0, 0, 0)) < 1e-9)
        #expect(vectorDistance(info.endPoint, SIMD3(30, 10, 0)) < 1e-9)
        #expect(vectorDistance(try #require(curve.point(at: 0.5)), SIMD3(15, 5, 0)) < 1e-9)
        #expect(vectorDistance(try #require(curve.point(at: 0.25)), SIMD3(8.75, 6.25, 0)) < 1e-9)
        #expect(vectorDistance(try #require(curve.point(at: 0.75)), SIMD3(21.25, 3.75, 0)) < 1e-9)
        #expect(abs(info.length - 35.194886709563) < 1e-6)
    }

    @Test("Create weighted NURBS (rational curve)")
    func createWeightedNURBS() throws {
        // Quadratic rational B-spline can represent exact conic sections
        let poles = [
            SIMD3<Double>(0, 0, 0),
            SIMD3<Double>(10, 10, 0),
            SIMD3<Double>(20, 0, 0),
        ]
        let weights = [1.0, 0.707, 1.0]  // sqrt(2)/2 for 90-degree arc
        let curve = try #require(Wire.nurbsUniform(poles: poles, weights: weights, degree: 2))
        // The weight on the middle pole pulls the curve toward it: the midpoint is
        // (10, 10 w / (1 + w)) = (10, 4.14177), which the unweighted curve (the control below)
        // puts at (10, 5). A weight that is ignored reads 5.
        let w = 0.707
        let mid = try #require(curve.point(at: 0.5))
        #expect(vectorDistance(mid, SIMD3(10, 10 * w / (1 + w), 0)) < 1e-9)
        let info = try #require(curve.curveInfo)
        #expect(vectorDistance(info.startPoint, SIMD3(0, 0, 0)) < 1e-9)
        #expect(vectorDistance(info.endPoint, SIMD3(20, 0, 0)) < 1e-9)

        let plain = try #require(Wire.nurbsUniform(poles: poles, degree: 2))
        #expect(vectorDistance(try #require(plain.point(at: 0.5)), SIMD3(10, 5, 0)) < 1e-9)
    }

    @Test("Create full NURBS with explicit knots")
    func createFullNURBS() throws {
        // Cubic curve with 5 control points
        let poles = [
            SIMD3<Double>(0, 0, 0),
            SIMD3<Double>(5, 10, 0),
            SIMD3<Double>(15, 10, 0),
            SIMD3<Double>(20, 5, 0),
            SIMD3<Double>(25, 0, 0),
        ]
        // Clamped uniform knots for degree 3 with 5 poles
        // Total knots = poles + degree + 1 = 9
        // Distinct knots with multiplicities: [0,0,0,0, 0.5, 1,1,1,1]
        let knots: [Double] = [0.0, 0.5, 1.0]
        let mults: [Int32] = [4, 1, 4]

        let curve = try #require(
            Wire.nurbs(
                poles: poles,
                knots: knots,
                multiplicities: mults,
                degree: 3
            ))
        // Clamped at both ends (first and last pole), with the interior knot at 0.5:
        // (7.34375, 8.59375) at a quarter, (13.75, 8.75) at the middle, (18.90625, 5.78125)
        // at three quarters. Exact in binary, so held to 1e-9.
        let info = try #require(curve.curveInfo)
        #expect(vectorDistance(info.startPoint, SIMD3(0, 0, 0)) < 1e-9)
        #expect(vectorDistance(info.endPoint, SIMD3(25, 0, 0)) < 1e-9)
        #expect(
            vectorDistance(try #require(curve.point(at: 0.25)), SIMD3(7.34375, 8.59375, 0)) < 1e-9)
        #expect(vectorDistance(try #require(curve.point(at: 0.5)), SIMD3(13.75, 8.75, 0)) < 1e-9)
        #expect(
            vectorDistance(try #require(curve.point(at: 0.75)), SIMD3(18.90625, 5.78125, 0)) < 1e-9)
        #expect(abs(info.length - 32.472242586177) < 1e-6)
    }

    @Test("NURBS validation - too few poles")
    func nurbsTooFewPoles() {
        let poles = [SIMD3<Double>(0, 0, 0), SIMD3<Double>(10, 0, 0)]
        // Cubic needs at least 4 poles
        let curve = Wire.cubicBSpline(poles: poles)
        #expect(curve == nil)
    }

    @Test("Sweep profile along NURBS path")
    func sweepAlongNURBS() throws {
        // The profile's plane must be perpendicular to the path at its start. The path leaves
        // the origin along +x, so the circle's normal is +x. (The earlier fixture used the
        // default z normal, which lies in the plane of the path: that "sweep" is a flat
        // ribbon of area 334.4 and not a pipe, and `isValid` could not tell the two apart.)
        let profile = try #require(Wire.circle(origin: .zero, normal: SIMD3(1, 0, 0), radius: 1))
        let pathPoles = [
            SIMD3<Double>(0, 0, 0),
            SIMD3<Double>(20, 0, 0),
            SIMD3<Double>(40, 10, 0),
            SIMD3<Double>(60, 20, 0),
            SIMD3<Double>(80, 20, 0),
        ]
        let path = try #require(Wire.cubicBSpline(poles: pathPoles))
        let swept = try #require(Shape.sweep(profile: profile, along: path))
        #expect(swept.isValid)

        // The pipe wall: one face, area 2 pi r L over the path length 83.4215 (the open tube
        // has no end caps, so it is a shell and has no volume).
        let length = try #require(path.length)
        #expect(abs(length - 83.42149560750335) < 1e-6)
        #expect(swept.shapeType == .shell)
        #expect(swept.faceCount == 1)
        #expect(abs(try #require(swept.surfaceArea) - 2 * .pi * 1 * length) < 1e-3)
    }

    @Test("Polygon with too few points returns nil")
    func polygonTooFewPoints() {
        let polygon = Wire.polygon([SIMD2(0, 0)], closed: true)
        #expect(polygon == nil)
    }

    @Test("Line with same start and end returns nil")
    func lineDegenerate() {
        let line = Wire.line(from: .zero, to: .zero)
        #expect(line == nil)
    }

    @Test("Arc with zero radius returns nil")
    func arcZeroRadius() {
        let arc = Wire.arc(center: .zero, radius: 0, startAngle: 0, endAngle: .pi)
        #expect(arc == nil)
    }

    @Test("Rectangle with zero dimension returns nil")
    func rectangleZeroDimension() {
        let rect = Wire.rectangle(width: 0, height: 5)
        #expect(rect == nil)
    }
}
