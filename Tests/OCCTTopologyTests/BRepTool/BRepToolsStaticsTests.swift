import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

/// A box whose every edge record carries tolerance 0.5 (vertices and faces stay at 1e-7), written
/// through the BREP text: an edge record reads `tolerance sameParameter sameRange degenerated`.
private func boxWithLooseEdges() -> Shape? {
    guard let box = Shape.box(width: 10, height: 10, depth: 10), let brep = box.toBREPString()
    else { return nil }
    let edited = brep.replacingOccurrences(of: "Ed\n 1e-07 1 1 0", with: "Ed\n 0.5 1 1 0")
    guard edited != brep else { return nil }
    return Shape.fromBREPString(edited)
}

@Suite("v0.122.0, BRepTools Statics")
struct BRepToolsStaticsTests {
    @Test("Clean triangulation")
    func cleanTriangulation() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        func meshed() -> Int {
            edges.filter { Shape.polygonOnTriangulation(edge: $0) != nil }.count
        }

        #expect(meshed() == 0)
        _ = box.mesh(linearDeflection: 0.5)
        #expect(meshed() == 12)
        // Clean removes the triangulation, which the edge polygons ride on.
        box.cleanTriangulation()
        #expect(meshed() == 0)
        // And the shape meshes again afterwards.
        let mesh = try #require(box.mesh(linearDeflection: 0.5))
        #expect(mesh.triangleCount == 12)
        #expect(meshed() == 12)
    }

    @Test("Remove internals")
    func removeInternals() throws {
        // A solid and a vertex carried INTERNAL, side by side in a compound.
        let compound = try #require(Shape.builderMakeCompound())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        compound.builderAdd(box)
        let vertex = try #require(Shape.makeVertex(at: .zero))
        let internalVertex = try #require(vertex.oriented(2))
        compound.builderAdd(internalVertex)
        #expect(compound.nbChildren == 2)
        #expect(compound.subShapes(ofType: .vertex).count == 9)

        compound.removeInternals()
        // The internal vertex is gone; the box and its eight corners stay.
        #expect(compound.nbChildren == 1)
        #expect(compound.subShapes(ofType: .vertex).count == 8)
        #expect(compound.subShapes(ofType: .solid).count == 1)
        #expect(compound.isValid)
        #expect(abs((compound.volume ?? 0) - 1000) < 1e-6)
    }

    @Test("Detect closedness of cylindrical face")
    func detectClosedness() throws {
        let cylinder = try #require(Shape.cylinder(radius: 5, height: 10))
        let faces = cylinder.subShapes(ofType: .face)
        #expect(faces.count == 3)
        // The lateral face (area 100 pi) wraps round in U; the two caps are open both ways.
        var lateral = 0
        for face in faces {
            let area = try #require(face.surfaceArea)
            let closed = face.detectClosedness()
            if abs(area - 100 * Double.pi) < 1e-6 {
                lateral += 1
                #expect(closed.isClosedU)
                #expect(!closed.isClosedV)
            } else {
                #expect(!closed.isClosedU)
                #expect(!closed.isClosedV)
            }
        }
        #expect(lateral == 1)

        // A sphere's one face is closed in U (longitude), not in V; a box face in neither.
        let sphere = try #require(Shape.sphere(radius: 5))
        let sphereFace = try #require(sphere.subShapes(ofType: .face).first)
        #expect(sphereFace.detectClosedness().isClosedU)
        #expect(!sphereFace.detectClosedness().isClosedV)
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let boxFace = try #require(box.subShapes(ofType: .face).first)
        #expect(!boxFace.detectClosedness().isClosedU)
        #expect(!boxFace.detectClosedness().isClosedV)
    }

    @Test("Evaluate and update tolerance")
    func evalAndUpdateTol() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let face = try #require(
            box.subShapes(ofType: .face).first { ($0.boundingBox?.max.x ?? 0) < -4.9 })
        let faceEdges = face.subShapes(ofType: .edge)
        #expect(faceEdges.count == 4)
        // An edge on the face: its pcurve and 3D curve agree, so the tolerance stays at 1e-7.
        for edge in faceEdges {
            #expect(abs(Shape.evalAndUpdateTolerance(edge: edge, face: face) - 1e-7) < 1e-12)
            #expect(abs(edge.edgeTolerance - 1e-7) < 1e-12)
        }

        // An edge of the far face (x = +5), taken against this face: the face's plane is 10 away
        // from it, so that is the deviation the call measures and writes onto the edge.
        let far = try #require(
            box.subShapes(ofType: .edge).first { edge in
                !faceEdges.contains { $0.isPartner(with: edge) }
                    && edge.vertices().allSatisfy { $0.x > 4.9 }
            })
        #expect(abs(Shape.evalAndUpdateTolerance(edge: far, face: face) - 10) < 1e-6)
        #expect(abs(far.edgeTolerance - 10) < 1e-6)
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
    func updateFaceUVPoints() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let face = try #require(
            box.subShapes(ofType: .face).first { ($0.boundingBox?.max.x ?? 0) < -4.9 })
        let edge = try #require(face.subShapes(ofType: .edge).first)
        let original = try #require(Shape.uvPoints(edge: edge, face: face))

        // Knock the stored UV points off the pcurve, then ask for them to be rebuilt from it.
        #expect(
            Shape.setUVPoints(
                edge: edge, face: face, first: SIMD2(0.25, 0.5), last: SIMD2(0.75, 1.5)))
        let moved = try #require(Shape.uvPoints(edge: edge, face: face))
        #expect(moved.firstU == 0.25 && moved.lastV == 1.5)

        face.updateFaceUVPoints()
        let restored = try #require(Shape.uvPoints(edge: edge, face: face))
        #expect(abs(restored.firstU - original.firstU) < 1e-12)
        #expect(abs(restored.firstV - original.firstV) < 1e-12)
        #expect(abs(restored.lastU - original.lastU) < 1e-12)
        #expect(abs(restored.lastV - original.lastV) < 1e-12)
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
    func compareEdges() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        #expect(edges.count == 12)
        #expect(Shape.compareEdges(edges[0], edges[0]))
        // Every other edge of the box differs from the first.
        for other in edges.dropFirst() {
            #expect(!Shape.compareEdges(edges[0], other))
        }
        // `BRepTools::Compare` is identity of the edge, not geometric equality: the same edge
        // of an independent copy is a different edge.
        let copy = try #require(box.deepCopy())
        let copied = copy.subShapes(ofType: .edge)
        #expect(copied.count == 12)
        #expect(copied.allSatisfy { !Shape.compareEdges(edges[0], $0) })
    }

    @Test("Is really closed")
    func isReallyClosed() throws {
        let cylinder = try #require(Shape.cylinder(radius: 5, height: 10))
        let faces = cylinder.subShapes(ofType: .face)
        let edges = cylinder.subShapes(ofType: .edge)
        #expect(faces.count == 3)
        #expect(edges.count == 3)
        // Only the seam, taken on the lateral face, is closed on it: it is the one edge with
        // both orientations on that face. The two circles and every cap pairing are not.
        var closedPairs = 0
        for face in faces {
            let area = try #require(face.surfaceArea)
            let lateral = abs(area - 100 * Double.pi) < 1e-6
            for edge in edges {
                let seam = abs(edge.totalEdgeLength - 10) < 1e-6
                let closed = Shape.isReallyClosed(edge: edge, face: face)
                if closed { closedPairs += 1 }
                #expect(closed == (lateral && seam))
            }
        }
        #expect(closedPairs == 1)
    }

    @Test("Update topology")
    func updateTopology() throws {
        // An edge at 0.5 and a vertex at 1e-7: BRepTools::Update refreshes bounding data and
        // leaves tolerances alone, unlike BRepLib::UpdateTolerances which raises the vertex.
        let shape = try #require(boxWithLooseEdges())
        #expect(abs(shape.maxEdgeTolerance - 0.5) < 1e-12)
        #expect(abs(shape.maxVertexTolerance - 1e-7) < 1e-12)

        shape.updateTopology()
        #expect(shape.isValid)
        #expect(abs(shape.maxEdgeTolerance - 0.5) < 1e-12)
        #expect(abs(shape.maxVertexTolerance - 1e-7) < 1e-12)
        #expect(shape.subShapes(ofType: .edge).count == 12)
        #expect(shape.subShapes(ofType: .face).count == 6)
        #expect(abs((shape.volume ?? 0) - 1000) < 1e-6)
    }
}
