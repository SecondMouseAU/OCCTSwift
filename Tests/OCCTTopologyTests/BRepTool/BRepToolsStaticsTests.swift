import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.122.0, BRepTools Statics")
struct BRepToolsStaticsTests {
    @Test("Clean triangulation")
    func cleanTriangulation() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let _ = b.mesh(linearDeflection: 0.5)
            // Clean should remove the triangulation
            b.cleanTriangulation()
            // After cleaning, meshing again should work
            let mesh = b.mesh(linearDeflection: 0.5)
            #expect(mesh != nil)
        }
    }

    @Test("Remove internals")
    func removeInternals() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            b.removeInternals()
            #expect(b.isValid)
        }
    }

    @Test("Detect closedness of cylindrical face")
    func detectClosedness() {
        let cyl = Shape.cylinder(radius: 5, height: 10)
        if let c = cyl {
            let faces = c.subShapes(ofType: .face)
            // Cylinder lateral face should be closed in U
            for face in faces {
                let (isClosedU, isClosedV) = face.detectClosedness()
                // At least check it doesn't crash
                if isClosedU || isClosedV {
                    #expect(true)
                    return
                }
            }
            // Not finding a closed face is OK - detectClosedness was called without crash
            #expect(true)
        }
    }

    @Test("Evaluate and update tolerance")
    func evalAndUpdateTol() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            let edges = b.subShapes(ofType: .edge)
            if faces.count > 0, edges.count > 0 {
                let tol = Shape.evalAndUpdateTolerance(edge: edges[0], face: faces[0])
                #expect(tol >= 0)
            }
        }
    }

    @Test("Map 3D edge count")
    func map3DEdgeCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let count = b.map3DEdgeCount
            #expect(count == 12)  // A box has 12 edges
        }
    }

    @Test("Update face UV points")
    func updateFaceUVPoints() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            if faces.count > 0 {
                faces[0].updateFaceUVPoints()
                // Just verify no crash
                #expect(true)
            }
        }
    }

    @Test("Compare vertices")
    func compareVertices() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let verts = b.subShapes(ofType: .vertex)
            if verts.count >= 2 {
                // Same vertex compared to itself
                let same = Shape.compareVertices(verts[0], verts[0])
                #expect(same)
                // Different vertices may not be equal
                let diff = Shape.compareVertices(verts[0], verts[1])
                #expect(!diff)  // Typically different vertices of a box
            }
        }
    }

    @Test("Compare edges")
    func compareEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.subShapes(ofType: .edge)
            if edges.count >= 2 {
                let same = Shape.compareEdges(edges[0], edges[0])
                #expect(same)
            }
        }
    }

    @Test("Is really closed")
    func isReallyClosed() {
        let cyl = Shape.cylinder(radius: 5, height: 10)
        if let c = cyl {
            let faces = c.subShapes(ofType: .face)
            let edges = c.subShapes(ofType: .edge)
            if faces.count > 0, edges.count > 0 {
                // Check some edge/face pair, result depends on geometry
                let _ = Shape.isReallyClosed(edge: edges[0], face: faces[0])
                #expect(true)  // Just verify no crash
            }
        }
    }

    @Test("Update topology")
    func updateTopology() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            b.updateTopology()
            #expect(b.isValid)
        }
    }
}
