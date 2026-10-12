import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Edge Connect Tests")
struct EdgeConnectTests {

    @Test("Box edge connectivity")
    func boxConnectivity() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
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
        // vertices are already shared it leaves the shape invalid (#3354, twin of #3252). The
        // receiver and the result are the same TShape, so both read invalid.
        withKnownIssue("#3354: connectedEdges edits the receiver and leaves it invalid") {
            #expect(connected.isValid)
            #expect(fused.isValid)
        }
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

        withKnownIssue("#3354: connectedEdges edits the receiver and leaves it invalid") {
            #expect(connected.isValid)
        }
    }
}
