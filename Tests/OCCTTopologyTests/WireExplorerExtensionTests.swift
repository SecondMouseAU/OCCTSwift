import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepTools_WireExplorer Extensions Tests")
struct WireExplorerExtensionTests {

    @Test func wireEdgeOrientations() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    let orientations = wire.wireEdgeOrientations(face: face)
                    #expect(orientations.count == 4)  // box face has 4 edges
                }
            }
        }
    }

    @Test func wireExplorerVertexPositions() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    let verts = wire.wireExplorerVertices(face: face)
                    #expect(verts.count == 4)
                }
            }
        }
    }

    @Test func wireOrientationsWithoutFace() {
        if let wire = Wire.rectangle(width: 10, height: 10),
            let ws = Shape.fromWire(wire)
        {
            let orientations = ws.wireEdgeOrientations()
            #expect(orientations.count == 4)
        }
    }
}
