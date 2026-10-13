import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Edge Connect Tests")
struct EdgeConnectTests {

    @Test("Box edge connectivity")
    func boxConnectivity() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let connected = box.connectedEdges
        // Box edges are already connected, should still succeed
        #expect(connected != nil)
        if let connected {
            let edgeCount = connected.subShapeCount(ofType: ShapeType.edge)
            #expect(edgeCount == 12)  // Box has 12 edges
        }
    }

    @Test("Fused shape edge connectivity")
    func fusedConnectivity() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let sphere = try #require(Shape.sphere(radius: 7))
        let fused = try #require(box.union(sphere))
        #expect(fused.isValid)
        // The fuse is 24 edges, 13 faces, volume 1477.522 (cube 1000 plus six spherical caps).
        #expect(fused.edgeCount == 24)
        #expect(fused.faceCount == 13)
        let before = try #require(fused.volume)
        #expect(abs(before - 1477.5220747684) < 1e-6)

        let connected = try #require(fused.connectedEdges)
        #expect(connected.subShapeCount(ofType: .edge) == 24)
        #expect(connected.subShapeCount(ofType: .face) == 13)
        #expect(abs(try #require(connected.volume) - before) < 1e-5)

        // ShapeFix_EdgeConnect rewrites the vertices it is given in place, and on a shape whose
        // vertices are already shared it leaves the shape invalid. connectedEdges works on a copy
        // and keeps the input when the result is worse (#3354, twin of #3252), so the receiver
        // is untouched and the result is valid.
        #expect(connected.isValid)
        #expect(fused.isValid)
    }

    @Test("Cylinder edge connectivity")
    func cylinderConnectivity() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        #expect(cyl.isValid)
        let connected = try #require(cyl.connectedEdges)
        // top, bottom, lateral; two rim circles and the seam; the volume is untouched (25 pi * 10)
        #expect(connected.subShapeCount(ofType: .face) == 3)
        #expect(connected.subShapeCount(ofType: .edge) == 3)
        #expect(abs(try #require(connected.volume) - 250 * .pi) < 1e-9)

        #expect(connected.isValid)
        #expect(cyl.isValid)
    }

    /// The receiver must never be edited.
    ///
    /// On a box the class rewrites two vertices to tolerance 8.66 when run on the caller's shape. Reading the vertex tolerances before and after is
    /// independent of `isValid`.
    @Test("connectedEdges leaves the receiver's vertices untouched")
    func receiverIsNotEdited() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let before = box.vertices().count
        let tolBefore = box.maxVertexTolerance
        #expect(box.isValid)
        let connected = try #require(box.connectedEdges)
        #expect(box.maxVertexTolerance == tolBefore)
        #expect(box.isValid)
        #expect(connected.isValid)
        #expect(box.vertices().count == before)
        #expect(connected.vertices().count == 8)
        #expect(abs(try #require(box.volume) - 1000) < 1e-9)
    }
}
