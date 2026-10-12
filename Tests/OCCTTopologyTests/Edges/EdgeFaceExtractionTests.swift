import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Edge/Face Extraction Tests")
struct EdgeFaceExtractionTests {

    @Test func extractEdgeCurve3D() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                if let result = edge.extractEdgeCurve3D() {
                    #expect(result.last > result.first || result.last == result.first)
                }
            }
        }
    }

    @Test func edgeTolerance() throws {
        // BRepPrimAPI builds every box edge at Precision::Confusion (1e-7), so a getter that
        // returns any other positive number (a constant 1, a length, a vertex tolerance) fails.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        #expect(edges.count == 12)
        for edge in edges {
            #expect(abs(edge.edgeTolerance - 1e-7) < 1e-12)
        }
    }

    @Test func edgeIsDegenerated() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                #expect(!edge.isEdgeDegenerated)
            }
        }
    }

    @Test func extractFaceSurface() throws {
        // Each of the six faces carries a plane through the box wall: one axis component of the
        // unit normal is +-1 and the surface origin sits at +-5 along that axis. Together the
        // six planes cover the three axes twice, once at -5 and once at +5.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        var walls = Set<String>()
        for face in faces {
            let surface = try #require(face.extractFaceSurface())
            #expect(surface.isPlane)
            let origin = surface.point(atU: 0, v: 0)
            let normal = try #require(surface.normal(atU: 0, v: 0))
            #expect(abs(abs(normal.x) + abs(normal.y) + abs(normal.z) - 1) < 1e-12)
            let axis = abs(normal.x) > 0.5 ? 0 : (abs(normal.y) > 0.5 ? 1 : 2)
            let offset = origin[axis]
            #expect(abs(abs(offset) - 5) < 1e-9)
            walls.insert("\(axis):\(offset > 0 ? "+" : "-")")
        }
        #expect(walls.count == 6)

        // A cylinder's lateral face is a cylinder surface and its caps are planes.
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        var kinds: [Surface.SurfaceType] = []
        for face in cyl.subShapes(ofType: .face) {
            kinds.append(try #require(face.extractFaceSurface()).surfaceKind)
        }
        #expect(kinds.filter { $0 == .cylinder }.count == 1)
        #expect(kinds.filter { $0 == .plane }.count == 2)
    }

    @Test func faceTolerance() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        for face in faces {
            #expect(abs(face.faceTolerance - 1e-7) < 1e-12)
        }
    }

    @Test func faceWireCount() throws {
        // Every box face has exactly one boundary wire, and so does each face of a cylinder
        // (the lateral face's single wire holds the seam twice).
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        for face in box.subShapes(ofType: .face) {
            #expect(face.faceWireCount == 1)
        }
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        for face in cyl.subShapes(ofType: .face) {
            #expect(face.faceWireCount == 1)
        }

        // A square plate with a square hole has two: the outer boundary and the hole.
        let plate = try #require(Shape.box(origin: .zero, width: 20, height: 20, depth: 4))
        let hole = try #require(Shape.box(origin: SIMD3(8, 8, -1), width: 4, height: 4, depth: 6))
        let drilled = try #require(plate.subtracting(hole))
        let topFace = drilled.subShapes(ofType: .face).first { shape in
            guard let z = Face(shape)?.zLevel else { return false }
            return abs(z - 4) < 1e-9
        }
        let top = try #require(topFace)
        #expect(top.faceWireCount == 2)
    }

    @Test func vertexTolerance() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let vertices = box.subShapes(ofType: .vertex)
        #expect(vertices.count == 8)
        for vertex in vertices {
            #expect(abs(vertex.vertexTolerance - 1e-7) < 1e-12)
        }
    }

    @Test func vertexPoint() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let vertices = box.subShapes(ofType: .vertex)
            if let vertex = vertices.first {
                let pt = vertex.vertexPoint
                // A vertex of a 10x10x10 box centered at origin should have coords in [-5, 5]
                #expect(abs(pt.x) <= 6)
                #expect(abs(pt.y) <= 6)
                #expect(abs(pt.z) <= 6)
            }
        }
    }

    @Test func extractEdgePCurve() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        let edges = box.subShapes(ofType: .edge)
        // Edge 0 is the vertical edge from (-5,-5,-5) to (-5,-5,5). It bounds the faces at x = -5
        // (face 0) and y = -5 (face 2). On each, the pcurve spans [0, 10] and, lifted through
        // the face's own surface, lands on the edge's 3D endpoints.
        let edge = edges[0]
        let start = SIMD3<Double>(-5, -5, -5)
        let end = SIMD3<Double>(-5, -5, 5)
        for faceIndex in [0, 2] {
            let face = faces[faceIndex]
            let pcurve = try #require(edge.extractEdgePCurve(onFace: face))
            #expect(abs(pcurve.first - 0) < 1e-12)
            #expect(abs(pcurve.last - 10) < 1e-12)
            let surface = try #require(face.extractFaceSurface())
            let a = pcurve.curve.point(at: pcurve.first)
            let b = pcurve.curve.point(at: pcurve.last)
            #expect(vectorDistance(surface.point(atU: a.x, v: a.y), start) < 1e-9)
            #expect(vectorDistance(surface.point(atU: b.x, v: b.y), end) < 1e-9)
        }

        // A periodic case: the cylinder's rim circle on its lateral face runs once around,
        // u from 0 to 2 pi at v = 10 (the height).
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let lateralFace = cyl.subShapes(ofType: .face).first {
            $0.extractFaceSurface()?.isCylinder == true
        }
        let lateral = try #require(lateralFace)
        let rimShape = cyl.subShapes(ofType: .edge).first { shape in
            guard let v = shape.edgeVertices() else { return false }
            // The top rim is the one edge whose both ends are at z = 10.
            return abs(v.first.z - 10) < 1e-9 && abs(v.last.z - 10) < 1e-9
        }
        let rim = try #require(rimShape)
        let rimPCurve = try #require(rim.extractEdgePCurve(onFace: lateral))
        #expect(abs(rimPCurve.first - 0) < 1e-12)
        #expect(abs(rimPCurve.last - 2 * .pi) < 1e-12)
        let p0 = rimPCurve.curve.point(at: 0)
        let p1 = rimPCurve.curve.point(at: 2 * .pi)
        #expect(vectorDistance(p0, SIMD2(0, 10)) < 1e-9)
        #expect(vectorDistance(p1, SIMD2(2 * .pi, 10)) < 1e-9)
    }
}
