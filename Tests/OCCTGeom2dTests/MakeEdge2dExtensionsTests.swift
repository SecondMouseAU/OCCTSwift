import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: every test asserted `nbChildren >= 0`, which no shape can fail, inside `if let`s that
// also let a nil edge pass. Each now requires the edge and pins its vertices, which the probe
// (Scripts/repro/766-geom2d-makeedge2d/) reads the way `Shape.vertices()` does.
//
// A vertex says where a curve starts and stops and nothing about its other radius, so the conics
// also pin the edge's box, which BRepBndLib builds from the curve itself, and the circle and the
// line pin the edge's length. A 2D edge has no 3D curve, but it reports a box and a length. An
// ellipse cannot pin its length: `Edge.length` integrates a whole ellipse with one fixed rule and
// reads 48.5059 for the 10 x 5 ellipse whose perimeter is 48.4422 (#3044), so no test here pins it.
//
// Every one of these builders reaches `BRepLib::Plane()`, whose first call is not thread-safe
// (#3039). A vertex that is wrong on a fresh process, or a signal in one of these tests, is that
// race and not the test.
@Suite("BRepLib_MakeEdge2d Extensions Tests")
struct MakeEdge2dExtensionsTests {

    /// The tolerance BRepLib_MakeEdge2d gives its edge, `Precision::Confusion()`.
    ///
    /// The box of an edge carries it in every direction, so a curve's own extent is padded by it.
    private let edgeTolerance = 1e-7

    @Test func edge2dFullCircle() throws {
        let e = try #require(
            Shape.edge2dFullCircle(center: SIMD2(0, 0), direction: SIMD2(1, 0), radius: 5))
        expectVertices(e, [SIMD3(5, 0, 0)], "full circle")
        try expectBox(e, x: -5...5, y: -5...5, "full circle")
        try expectLength(e, 10 * .pi, "full circle")
    }

    @Test func edge2dEllipse() throws {
        let e = try #require(
            Shape.edge2dEllipse(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                majorRadius: 10, minorRadius: 5))
        expectVertices(e, [SIMD3(10, 0, 0)], "full ellipse")
        // The only place the minor radius shows: the box is 20 wide and 10 high.
        try expectBox(e, x: -10...10, y: -5...5, "full ellipse")
    }

    @Test func edge2dEllipseArc() throws {
        let e = try #require(
            Shape.edge2dEllipseArc(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                majorRadius: 10, minorRadius: 5,
                u1: 0, u2: .pi))
        expectVertices(e, [SIMD3(10, 0, 0), SIMD3(-10, 0, 0)], "ellipse arc")
        // The upper half of the ellipse, which reaches the minor vertex (0, 5) between its ends.
        try expectBox(e, x: -10...10, y: 0...5, "ellipse arc")

        // A quarter, from the major vertex to the minor vertex (a cos u, b sin u at u = pi/2).
        let quarter = try #require(
            Shape.edge2dEllipseArc(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                majorRadius: 10, minorRadius: 5,
                u1: 0, u2: .pi / 2))
        expectVertices(quarter, [SIMD3(10, 0, 0), SIMD3(0, 5, 0)], "ellipse quarter arc")
        try expectBox(quarter, x: 0...10, y: 0...5, "ellipse quarter arc")
    }

    @Test func edge2dFromCurve() throws {
        let line = try #require(Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 1)))
        let e = try #require(Shape.edge2dFromCurve(line, u1: 0, u2: 10))
        let r = 10 / 2.0.squareRoot()
        expectVertices(e, [SIMD3(0, 0, 0), SIMD3(r, r, 0)], "line [0, 10]")
        // The direction is a unit vector, so the parameter is the arc length.
        try expectLength(e, 10, "line [0, 10]")

        // A line through (1, 2), with a negative start: the parameter runs from -3 to 4 along
        // the unit direction (1, 1) / sqrt 2, so the ends are (1, 2) + t * (1, 1) / sqrt 2.
        let offset = try #require(Curve2D.line(through: SIMD2(1, 2), direction: SIMD2(1, 1)))
        let f = try #require(Shape.edge2dFromCurve(offset, u1: -3, u2: 4))
        let root = 2.0.squareRoot()
        expectVertices(
            f,
            [SIMD3(1 - 3 / root, 2 - 3 / root, 0), SIMD3(1 + 4 / root, 2 + 4 / root, 0)],
            "line [-3, 4] through (1, 2)")
        try expectLength(f, 7, "line [-3, 4] through (1, 2)")
    }

    @Test func edge2dFromCurveFullRange() throws {
        let circle = try #require(Curve2D.circle(center: SIMD2(0, 0), radius: 5))
        let e = try #require(Shape.edge2dFromCurve(circle))
        // A full circle is one closed edge, so one vertex, not two at the same point.
        expectVertices(e, [SIMD3(5, 0, 0)], "circle full range")
        try expectBox(e, x: -5...5, y: -5...5, "circle full range")
        try expectLength(e, 10 * .pi, "circle full range")

        // Off the origin, so a centre dropped on the way is not the same circle.
        let moved = try #require(Curve2D.circle(center: SIMD2(2, 3), radius: 5))
        let g = try #require(Shape.edge2dFromCurve(moved))
        expectVertices(g, [SIMD3(7, 3, 0)], "circle (2, 3) full range")
        try expectBox(g, x: -3...7, y: -2...8, "circle (2, 3) full range")
    }

    @Test func edge2dPlacementFollowsCenterAndDirection() throws {
        // Centre (2, 3) with the local x axis along +y, where every fixture above has its centre
        // at the origin and its x axis along +x and so cannot tell either from a default. The
        // local y axis is the x axis turned a quarter turn anticlockwise, here (-1, 0).
        let center = SIMD2<Double>(2, 3)
        let up = SIMD2<Double>(0, 1)

        // A circle starts on the local x axis: centre + 5 * (0, 1) = (2, 8).
        let circle = try #require(Shape.edge2dFullCircle(center: center, direction: up, radius: 5))
        expectVertices(circle, [SIMD3(2, 8, 0)], "circle at (2, 3) along +y")
        try expectBox(circle, x: -3...7, y: -2...8, "circle at (2, 3) along +y")

        // The ellipse's major axis (10) is along +y and its minor (5) along x.
        let ellipse = try #require(
            Shape.edge2dEllipse(center: center, direction: up, majorRadius: 10, minorRadius: 5))
        expectVertices(ellipse, [SIMD3(2, 13, 0)], "ellipse at (2, 3) along +y")
        try expectBox(ellipse, x: -3...7, y: -7...13, "ellipse at (2, 3) along +y")

        // The quarter arc runs from the major vertex (2, 13) to the minor vertex on the local y
        // axis side, centre + 5 * (-1, 0) = (-3, 3).
        let arc = try #require(
            Shape.edge2dEllipseArc(
                center: center, direction: up, majorRadius: 10, minorRadius: 5,
                u1: 0, u2: .pi / 2))
        expectVertices(arc, [SIMD3(2, 13, 0), SIMD3(-3, 3, 0)], "ellipse quarter arc at (2, 3)")
        try expectBox(arc, x: -3...2, y: 3...13, "ellipse quarter arc at (2, 3)")
    }

    /// The vertices BRepLib_MakeEdge2d gives each fixture, count and position.
    ///
    /// Order-insensitive: each wanted point must be a vertex. The probe that reads them the same
    /// way is Scripts/repro/766-geom2d-makeedge2d/.
    private func expectVertices(_ edge: Shape, _ want: [SIMD3<Double>], _ label: String) {
        let got = edge.vertices()
        #expect(got.count == want.count, "\(label): \(got.count) vertices")
        for w in want {
            #expect(got.contains { simd_distance($0, w) < 1e-9 }, "\(label): no vertex at \(w)")
        }
    }

    /// The edge's box in x and y, padded by the edge tolerance, and flat in z at 0 (also padded).
    private func expectBox(
        _ edge: Shape, x: ClosedRange<Double>, y: ClosedRange<Double>, _ label: String
    ) throws {
        let b = try #require(edge.bounds, "\(label): no box")
        #expect(abs(b.min.x - (x.lowerBound - edgeTolerance)) < 1e-9, "\(label): min x \(b.min.x)")
        #expect(abs(b.max.x - (x.upperBound + edgeTolerance)) < 1e-9, "\(label): max x \(b.max.x)")
        #expect(abs(b.min.y - (y.lowerBound - edgeTolerance)) < 1e-9, "\(label): min y \(b.min.y)")
        #expect(abs(b.max.y - (y.upperBound + edgeTolerance)) < 1e-9, "\(label): max y \(b.max.y)")
        #expect(abs(b.min.z + edgeTolerance) < 1e-9, "\(label): min z \(b.min.z)")
        #expect(abs(b.max.z - edgeTolerance) < 1e-9, "\(label): max z \(b.max.z)")
    }

    /// The length of the shape's one edge.
    private func expectLength(_ shape: Shape, _ want: Double, _ label: String) throws {
        let edge = try #require(shape.edges().first, "\(label): no edge")
        #expect(abs(edge.length - want) < 1e-9, "\(label): length \(edge.length)")
    }
}
