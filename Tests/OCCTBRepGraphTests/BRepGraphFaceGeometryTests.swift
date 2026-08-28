import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Face Geometry")
struct BRepGraphFaceGeometryTests {
    @Test func faceTolerance() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let tol = graph.faceTolerance(0)
                #expect(tol > 0)
            }
        }
    }

    @Test func faceHasSurface() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.faceCount {
                    #expect(graph.faceHasSurface(i))
                }
            }
        }
    }

    @Test func faceNaturalRestriction() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Just check it returns a bool without crashing
                let _ = graph.isFaceNaturalRestriction(0)
            }
        }
    }

    @Test func faceHasTriangulation() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Box may or may not have triangulation depending on meshing
                let _ = graph.faceHasTriangulation(0)
            }
        }
    }
}
