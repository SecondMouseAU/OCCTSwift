import Foundation
import OCCTBridge
import Testing
import simd

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
    func fusedConnectivity() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let sphere = Shape.sphere(radius: 7)!
        let fused = box.union(sphere)
        #expect(fused != nil)
        if let fused {
            let connected = fused.connectedEdges
            #expect(connected != nil)
        }
    }

    @Test("Cylinder edge connectivity")
    func cylinderConnectivity() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let connected = cyl.connectedEdges
        #expect(connected != nil)
        if let connected {
            let faceCount = connected.subShapeCount(ofType: ShapeType.face)
            #expect(faceCount >= 3)  // top, bottom, lateral
        }
    }
}
