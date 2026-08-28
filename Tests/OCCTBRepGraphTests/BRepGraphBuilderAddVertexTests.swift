import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - BRepGraph Builder (v0.135.0)

@Suite("BRepGraph Builder AddVertex")
struct BRepGraphBuilderAddVertexTests {
    @Test func addVertexToGraph() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let origVertexCount = graph.vertexCount
                if let vidx = graph.addVertex(x: 5.0, y: 5.0, z: 5.0, tolerance: 1e-7) {
                    #expect(vidx >= 0)
                    #expect(graph.vertexCount == origVertexCount + 1)
                    let pt = graph.vertexPoint(vidx)
                    #expect(abs(pt.x - 5.0) < 1e-6)
                    #expect(abs(pt.y - 5.0) < 1e-6)
                    #expect(abs(pt.z - 5.0) < 1e-6)
                    #expect(abs(graph.vertexTolerance(vidx) - 1e-7) < 1e-10)
                }
            }
        }
    }

    @Test func addMultipleVertices() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let orig = graph.vertexCount
                let v1 = graph.addVertex(x: 0, y: 0, z: 0, tolerance: 0.01)
                let v2 = graph.addVertex(x: 1, y: 2, z: 3, tolerance: 0.02)
                #expect(v1 != nil)
                #expect(v2 != nil)
                #expect(graph.vertexCount == orig + 2)
            }
        }
    }
}
