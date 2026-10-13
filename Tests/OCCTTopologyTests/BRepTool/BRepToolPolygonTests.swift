import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("v0.127.0, BRep_Tool Polygon Queries")
struct BRepToolPolygonTests {

    @Test("Polygon3D from meshed edge")
    func polygon3D() throws {
        // A free edge is the one that carries a 3D polygon: a circle of radius 5 meshed at 0.1.
        let circle = try #require(
            Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5))
        let edge = try #require(Shape.edgeFromCurve(circle))
        #expect(Shape.polygon3D(edge: edge) == nil)  // not meshed yet
        _ = edge.mesh(linearDeflection: 0.1)
        let points = try #require(Shape.polygon3D(edge: edge))
        #expect(points.count >= 8)
        // Every node is on the circle, in its plane, and the closed edge closes the polygon.
        #expect(points.allSatisfy { abs(vectorLength($0) - 5) < 1e-9 && abs($0.z) < 1e-9 })
        #expect(vectorLength(points[0] - points[points.count - 1]) < 1e-9)
        // The chords stay within the deflection: a chord midpoint is within 0.1 of the circle.
        for (a, b) in zip(points, points.dropFirst()) {
            #expect(5 - vectorLength((a + b) / 2) <= 0.1 + 1e-9)
        }

        // A box edge is not free: its polygon lives on the face triangulation instead.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        _ = box.mesh(linearDeflection: 0.1)
        #expect(box.subShapes(ofType: .edge).allSatisfy { Shape.polygon3D(edge: $0) == nil })
    }

    @Test("PolygonOnTriangulation from meshed edge")
    func polygonOnTriangulation() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        #expect(edges.count == 12)
        // Nothing before meshing.
        #expect(edges.allSatisfy { Shape.polygonOnTriangulation(edge: $0) == nil })

        _ = box.mesh(linearDeflection: 0.1)
        for edge in edges {
            // A straight box edge is the two end nodes of the face triangulation, 1-based, and
            // a face triangulation of a box face has four nodes.
            let indices = try #require(Shape.polygonOnTriangulation(edge: edge))
            #expect(indices.count == 2)
            #expect(indices.allSatisfy { (1...4).contains($0) })
            #expect(indices[0] != indices[1])
        }
    }

    @Test("CurveOnPlane returns 2D curve for edge on plane")
    func curveOnPlane() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let plane = try #require(Surface.plane(origin: SIMD3(0, 0, -5), normal: SIMD3(0, 0, 1)))
        // The four edges of the z = -5 face lie in the plane: their 2D curves run between the
        // vertices' (x, y), in some order.
        let bottom = box.subShapes(ofType: .edge).filter { edge in
            edge.vertices().allSatisfy { abs($0.z + 5) < 1e-6 }
        }
        #expect(bottom.count == 4)
        for edge in bottom {
            let result = try #require(Shape.curveOnPlane(edge: edge, surface: plane))
            #expect(abs(result.last - result.first - 10) < 1e-9)
            let p0 = result.curve.point(at: result.first)
            let p1 = result.curve.point(at: result.last)
            let ends = edge.vertices().map { SIMD2($0.x, $0.y) }
            #expect(ends.count == 2)
            let straight = vectorLength(p0 - ends[0]) < 1e-9 && vectorLength(p1 - ends[1]) < 1e-9
            let flipped = vectorLength(p0 - ends[1]) < 1e-9 && vectorLength(p1 - ends[0]) < 1e-9
            #expect(straight || flipped)
        }
        // A vertical edge projects onto a point of the plane: its 2D curve does not move.
        let vertical = try #require(
            box.subShapes(ofType: .edge).first { edge in
                let v = edge.vertices()
                return v.count == 2 && abs(v[0].x - v[1].x) < 1e-6 && abs(v[0].y - v[1].y) < 1e-6
            })
        let result = try #require(Shape.curveOnPlane(edge: vertical, surface: plane))
        let p0 = result.curve.point(at: result.first)
        let p1 = result.curve.point(at: result.last)
        #expect(vectorLength(p0 - p1) < 1e-9)
    }
}
