import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - BRepGraph Tests (v0.129.0)

@Suite("BRepGraph Build")
struct BRepGraphBuildTests {
    @Test func buildFromBox() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box {
            let graph = BRepGraph(shape: box)
            #expect(graph != nil)
            if let graph {
                #expect(graph.faceCount == 6)
                #expect(graph.edgeCount == 12)
                #expect(graph.vertexCount == 8)
                #expect(graph.shellCount == 1)
                #expect(graph.solidCount == 1)
                #expect(graph.wireCount == 6)
                #expect(graph.compoundCount == 0)
                #expect(graph.nodeCount > 0)
            }
        }
    }

    @Test func buildParallel() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box {
            let graph = BRepGraph(shape: box, parallel: true)
            #expect(graph != nil)
            if let graph {
                #expect(graph.faceCount == 6)
            }
        }
    }

    @Test func buildFromSphere() {
        let sphere = Shape.sphere(radius: 5)
        if let sphere {
            let graph = BRepGraph(shape: sphere)
            if let graph {
                #expect(graph.faceCount > 0)
                #expect(graph.edgeCount >= 0)
                #expect(graph.nodeCount > 0)
            }
        }
    }

    @Test func buildFromComplex() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        let cyl = Shape.cylinder(radius: 5, height: 30)
        if let box, let cyl {
            let fused = box + cyl
            if let fused {
                let graph = BRepGraph(shape: fused)
                if let graph {
                    #expect(graph.faceCount > 6)
                    #expect(graph.isValid)
                }
            }
        }
    }
}
