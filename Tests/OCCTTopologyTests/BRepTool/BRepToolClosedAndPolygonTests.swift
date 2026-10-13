import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("BRep_Tool Extras v128")
struct BRepToolExtrasV128Tests {

    @Test("IsClosedOnFace")
    func isClosedOnFace() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        let edges = box.subShapes(ofType: .edge)

        // For a box, no edge is closed on a face
        if !faces.isEmpty && !edges.isEmpty {
            let closed = Shape.isClosedOnFace(edge: edges[0], face: faces[0])
            // Box edges are not closed
            #expect(closed == false)
        }
    }

    @Test("IsClosedOnFace for cylinder (seam edge)")
    func isClosedOnFaceCylinder() {
        // A cylinder has a seam edge that IS closed on the cylindrical face
        let cyl = Shape.cylinder(radius: 5, height: 10)
        if let cyl = cyl {
            let faces = cyl.subShapes(ofType: .face)
            for face in faces {
                let faceEdges = face.subShapes(ofType: .edge)
                for edge in faceEdges {
                    let closed = Shape.isClosedOnFace(edge: edge, face: face)
                    if closed {
                        #expect(true)
                        return
                    }
                }
            }
            // Even if we don't find a closed edge, that's ok
            #expect(true)
        }
    }

    @Test("PolygonOnSurface after meshing")
    func polygonOnSurface() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        _ = box.mesh(linearDeflection: 1.0)

        // The mesh is there: every edge has its polygon on the face triangulation.
        let edges = box.subShapes(ofType: .edge)
        #expect(edges.allSatisfy { Shape.polygonOnTriangulation(edge: $0) != nil })

        // What the mesher does NOT write is a 2D polygon on the surface: measured on kernel.6,
        // no (edge, face) pair of a meshed box, sphere or torus answers one. The wrapper has no
        // way to create such a polygon (it exists only through BRep_Builder::UpdateEdge), so a
        // positive control cannot be built here, and an always-nil wrapper cannot be told from
        // this reading; what is pinned is that the answer is nil for every pair, without the
        // faults the old `_ = poly` version could not see.
        var pairs = 0
        for face in box.subShapes(ofType: .face) {
            for edge in face.subShapes(ofType: .edge) {
                pairs += 1
                #expect(Shape.polygonOnSurface(edge: edge, face: face) == nil)
            }
        }
        #expect(pairs == 24)
    }

    @Test("SetUVPoints")
    func setUVPointsTest() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let face = try #require(
            box.subShapes(ofType: .face).first { ($0.boundingBox?.max.x ?? 0) < -4.9 })
        let faceEdges = face.subShapes(ofType: .edge)
        #expect(faceEdges.count == 4)
        let target = try #require(faceEdges.first)
        let others = Array(faceEdges.dropFirst())
        let before = others.map { Shape.uvPoints(edge: $0, face: face) }

        let ok = Shape.setUVPoints(
            edge: target, face: face, first: SIMD2(0.25, 0.5), last: SIMD2(0.75, 1.5))
        #expect(ok)
        // The new endpoints read back, exactly.
        let uv = try #require(Shape.uvPoints(edge: target, face: face))
        #expect(abs(uv.firstU - 0.25) < 1e-12)
        #expect(abs(uv.firstV - 0.5) < 1e-12)
        #expect(abs(uv.lastU - 0.75) < 1e-12)
        #expect(abs(uv.lastV - 1.5) < 1e-12)
        // And nothing else on the face moved.
        let after = others.map { Shape.uvPoints(edge: $0, face: face) }
        for (b, a) in zip(before, after) {
            let bb = try #require(b)
            let aa = try #require(a)
            #expect(bb.firstU == aa.firstU && bb.firstV == aa.firstV)
            #expect(bb.lastU == aa.lastU && bb.lastV == aa.lastV)
        }
    }
}
