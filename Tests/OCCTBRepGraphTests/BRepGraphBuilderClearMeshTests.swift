import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder ClearMesh")
struct BRepGraphBuilderClearMeshTests {
    @Test func clearFaceMesh() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // Mesh the shape first
            let _ = box.mesh(linearDeflection: 0.1)
            if let graph = BRepGraph(shape: box) {
                if graph.faceCount > 0 {
                    // Should not crash
                    graph.clearFaceMesh(faceIndex: 0)
                }
            }
        }
    }

    @Test func clearEdgePolygon3D() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let _ = box.mesh(linearDeflection: 0.1)
            if let graph = BRepGraph(shape: box) {
                if graph.edgeCount > 0 {
                    // Should not crash
                    graph.clearEdgePolygon3D(edgeIndex: 0)
                }
            }
        }
    }
}
