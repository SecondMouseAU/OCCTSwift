import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: each test asserted `!= nil` and, inside `if let`, only that the shape is an edge. Each
// now also pins the edge's vertices.
@Suite("BRepBuilderAPI MakeEdge2d")
struct MakeEdge2dTests {
    @Test("Edge 2D from points")
    func edge2dFromPoints() throws {
        let edge = try #require(Shape.edge2d(from: SIMD2(0, 0), to: SIMD2(10, 5)))
        // 2D edges lack a 3D curve, so BRepCheck_Analyzer reports them invalid; check the topology.
        #expect(edge.shapeType == .edge)
        expectEdge2dVertices(edge, [SIMD3(0, 0, 0), SIMD3(10, 5, 0)], "points")
    }

    @Test("Edge 2D from circle arc")
    func edge2dFromCircle() throws {
        let edge = try #require(
            Shape.edge2dFromCircle(
                center: SIMD2(0, 0),
                direction: SIMD2(1, 0),
                radius: 5,
                p1: 0, p2: .pi
            ))
        #expect(edge.shapeType == .edge)
        expectEdge2dVertices(edge, [SIMD3(5, 0, 0), SIMD3(-5, 0, 0)], "circle arc")
    }

    @Test("Edge 2D from line")
    func edge2dFromLine() throws {
        let edge = try #require(
            Shape.edge2dFromLine(
                origin: SIMD2(0, 0),
                direction: SIMD2(1, 1),
                p1: 0, p2: 10
            ))
        #expect(edge.shapeType == .edge)
        let r = 10 / 2.0.squareRoot()
        expectEdge2dVertices(edge, [SIMD3(0, 0, 0), SIMD3(r, r, 0)], "line")
    }
}

/// #1979: the vertices BRepLib_MakeEdge2d gives each fixture, count and position
/// (Scripts/repro/766-geom2d-makeedge2d/). Order-insensitive: each wanted point must be a vertex.
func expectEdge2dVertices(_ edge: Shape, _ want: [SIMD3<Double>], _ label: String) {
    let got = edge.vertices()
    #expect(got.count == want.count, "\(label): \(got.count) vertices")
    for w in want {
        #expect(got.contains { simd_distance($0, w) < 1e-9 }, "\(label): no vertex at \(w)")
    }
}
