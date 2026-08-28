import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Edge Geometry")
struct BRepGraphEdgeGeometryTests {
    @Test func edgeTolerance() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let tol = graph.edgeTolerance(0)
                #expect(tol > 0)
            }
        }
    }

    @Test func edgeNotDegenerated() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.edgeCount {
                    #expect(!graph.isEdgeDegenerated(i))
                }
            }
        }
    }

    @Test func edgeSameParameter() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.edgeCount {
                    #expect(graph.isEdgeSameParameter(i))
                }
            }
        }
    }

    @Test func edgeSameRange() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.edgeCount {
                    #expect(graph.isEdgeSameRange(i))
                }
            }
        }
    }

    @Test func edgeRange() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let range = graph.edgeRange(0)
                #expect(range.first < range.last)
            }
        }
    }

    @Test func edgeHasCurve() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.edgeCount {
                    #expect(graph.edgeHasCurve(i))
                }
            }
        }
    }

    @Test func edgeMaxContinuity() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let cont = graph.edgeMaxContinuity(0)
                #expect(cont >= 0)
            }
        }
    }

    @Test func edgeNotClosedOnFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Box edges are not seam edges
                let faces = graph.faces(of: 0)
                if let faceIdx = faces.first {
                    #expect(!graph.isEdgeClosedOnFace(edgeIndex: 0, faceIndex: faceIdx))
                }
            }
        }
    }
}
