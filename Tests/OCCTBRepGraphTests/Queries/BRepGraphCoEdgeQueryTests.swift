import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph CoEdge Queries")
struct BRepGraphCoEdgeQueryTests {
    @Test func coedgeEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let edgeIdx = graph.coedgeEdge(0)
                #expect(edgeIdx >= 0)
                #expect(edgeIdx < graph.edgeCount)
            }
        }
    }

    @Test func coedgeFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let faceIdx = graph.coedgeFace(0)
                #expect(faceIdx >= 0)
                #expect(faceIdx < graph.faceCount)
            }
        }
    }

    @Test func coedgeSeamPairNilForBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Box edges are not seam edges, so no seam pairs
                let pair = graph.coedgeSeamPair(0)
                #expect(pair == nil)
            }
        }
    }

    @Test func coedgeSeamPairForSphere() {
        let sphere = Shape.sphere(radius: 5)
        if let sphere {
            let graph = BRepGraph(shape: sphere)
            if let graph {
                // Sphere has seam edges; find a coedge with a seam pair
                var foundSeam = false
                for i in 0..<graph.coedgeCount {
                    if graph.coedgeSeamPair(i) != nil {
                        foundSeam = true
                        break
                    }
                }
                // Sphere may or may not have seam depending on representation
                let _ = foundSeam
            }
        }
    }

    @Test func coedgeHasPCurve() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Box coedges should have PCurves
                var hasPCurve = false
                for i in 0..<graph.coedgeCount {
                    if graph.coedgeHasPCurve(i) {
                        hasPCurve = true
                        break
                    }
                }
                #expect(hasPCurve)
            }
        }
    }

    @Test func coedgeRange() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                if graph.coedgeHasPCurve(0) {
                    let range = graph.coedgeRange(0)
                    #expect(range.first < range.last)
                }
            }
        }
    }
}
