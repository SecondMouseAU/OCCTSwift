import Foundation
import Testing
import simd

@testable import OCCTSwift

// Values pinned to the kernel probe (Scripts/repro/766-brepgraph-build-coedge). The range
// and bounds checks these replaced (`>= 0 && < edgeCount`, `first < last`, "any coedge has a
// pcurve", and a sphere test with no assertion at all) passed an off-by-one or a seam query
// that never answered (#1986).
@Suite("BRepGraph CoEdge Queries")
struct BRepGraphCoEdgeQueryTests {
    @Test func coedgeEdge() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.coedgeEdge(0) == 0)
    }

    @Test func coedgeFace() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.coedgeFace(0) == 0)
    }

    @Test func coedgeSeamPairNilForBox() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // Box edges are not seam edges, so no coedge has a seam pair.
        #expect(graph.coedgeCount == 24)
        for i in 0..<graph.coedgeCount {
            #expect(graph.coedgeSeamPair(i) == nil)
        }
    }

    @Test func coedgeSeamPairForSphere() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        let graph = try #require(BRepGraph(shape: sphere))
        // Four coedges: the seam edge 1 is used twice (coedges 1 and 3), which pair with each
        // other; the pole coedges 0 and 2 have no pair.
        #expect(graph.coedgeCount == 4)
        #expect(graph.coedgeSeamPair(0) == nil)
        #expect(graph.coedgeSeamPair(1) == 3)
        #expect(graph.coedgeSeamPair(2) == nil)
        #expect(graph.coedgeSeamPair(3) == 1)
    }

    @Test func coedgeHasPCurve() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // Every box coedge carries a pcurve.
        #expect(graph.coedgeCount == 24)
        for i in 0..<graph.coedgeCount {
            #expect(graph.coedgeHasPCurve(i))
        }
    }

    @Test func coedgeRange() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.coedgeHasPCurve(0))
        let range = graph.coedgeRange(0)
        #expect(range.first == 0)
        #expect(range.last == 10)
    }
}
