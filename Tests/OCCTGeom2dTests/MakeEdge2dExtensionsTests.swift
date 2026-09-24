import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: every test asserted `nbChildren >= 0`, which no shape can fail, inside `if let`s that
// also let a nil edge pass. Each now requires the edge and pins its vertices (the helper lives in
// MakeEdge2dTests.swift).
@Suite("BRepLib_MakeEdge2d Extensions Tests")
struct MakeEdge2dExtensionsTests {

    @Test func edge2dFullCircle() throws {
        let e = try #require(Shape.edge2dFullCircle(center: SIMD2(0, 0), direction: SIMD2(1, 0), radius: 5))
        expectEdge2dVertices(e, [SIMD3(5, 0, 0)], "full circle")
    }

    @Test func edge2dEllipse() throws {
        let e = try #require(
            Shape.edge2dEllipse(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                majorRadius: 10, minorRadius: 5))
        expectEdge2dVertices(e, [SIMD3(10, 0, 0)], "full ellipse")
    }

    @Test func edge2dEllipseArc() throws {
        let e = try #require(
            Shape.edge2dEllipseArc(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                majorRadius: 10, minorRadius: 5,
                u1: 0, u2: .pi))
        expectEdge2dVertices(e, [SIMD3(10, 0, 0), SIMD3(-10, 0, 0)], "ellipse arc")
    }

    @Test func edge2dFromCurve() throws {
        let line = try #require(Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 1)))
        let e = try #require(Shape.edge2dFromCurve(line, u1: 0, u2: 10))
        let r = 10 / 2.0.squareRoot()
        expectEdge2dVertices(e, [SIMD3(0, 0, 0), SIMD3(r, r, 0)], "line [0, 10]")
    }

    @Test func edge2dFromCurveFullRange() throws {
        let circle = try #require(Curve2D.circle(center: SIMD2(0, 0), radius: 5))
        let e = try #require(Shape.edge2dFromCurve(circle))
        expectEdge2dVertices(e, [SIMD3(5, 0, 0)], "circle full range")
    }
}
