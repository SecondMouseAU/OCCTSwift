import Foundation
import Testing
import simd

@testable import OCCTSwift

// Values pinned to the kernel probe (Scripts/repro/766-brepgraph-edge-def-geometry). Where a
// box answers the same for every edge (not degenerated, has a curve, not a seam), the sphere's
// degenerate pole edges and seam are added so an answer that never varies fails (#1986).
@Suite("BRepGraph Edge Geometry")
struct BRepGraphEdgeGeometryTests {
    @Test func edgeTolerance() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // BRepPrimAPI_MakeBox edges carry Precision::Confusion(); `> 0` accepted any value.
        #expect(graph.edgeTolerance(0) == 1e-7)
    }

    @Test func edgeNotDegenerated() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.edgeCount == 12)
        for i in 0..<graph.edgeCount {
            #expect(!graph.isEdgeDegenerated(i))
        }
        let sphere = try #require(Shape.sphere(radius: 5))
        let sg = try #require(BRepGraph(shape: sphere))
        #expect((0..<sg.edgeCount).map { sg.isEdgeDegenerated($0) } == [true, false, true])
    }

    @Test func edgeSameParameter() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.edgeCount == 12)
        for i in 0..<graph.edgeCount {
            #expect(graph.isEdgeSameParameter(i))
        }
    }

    @Test func edgeSameRange() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.edgeCount == 12)
        for i in 0..<graph.edgeCount {
            #expect(graph.isEdgeSameRange(i))
        }
    }

    @Test func edgeRange() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let range = graph.edgeRange(0)
        #expect(range.first == 0)
        #expect(range.last == 10)
    }

    @Test func edgeHasCurve() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.edgeCount == 12)
        for i in 0..<graph.edgeCount {
            #expect(graph.edgeHasCurve(i))
        }
        // A degenerate pole edge has no 3D curve.
        let sphere = try #require(Shape.sphere(radius: 5))
        let sg = try #require(BRepGraph(shape: sphere))
        #expect((0..<sg.edgeCount).map { sg.edgeHasCurve($0) } == [false, true, false])
    }

    // OCCTBRepGraphEdgeMaxContinuity returns 0 unconditionally: the kernel's regularity layer
    // (BRepGraph_LayerRegularity) is absent from the pinned libOCCT, so nothing is computed.
    // `>= 0` held for every Int32; this pins the documented constant, so a change to it (or a
    // real implementation) has to update this test knowingly. Shape.maxContinuity is the
    // measured path.
    @Test func edgeMaxContinuity() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.edgeMaxContinuity(0) == 0)
    }

    @Test func edgeNotClosedOnFace() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // Box edges are not seam edges
        #expect(graph.faces(of: 0) == [0, 2])
        for faceIdx in graph.faces(of: 0) {
            #expect(!graph.isEdgeClosedOnFace(edgeIndex: 0, faceIndex: faceIdx))
        }
        // The sphere's seam edge 1 is closed on its only face.
        let sphere = try #require(Shape.sphere(radius: 5))
        let sg = try #require(BRepGraph(shape: sphere))
        #expect(sg.isEdgeClosedOnFace(edgeIndex: 1, faceIndex: 0))
        #expect(!sg.isEdgeClosedOnFace(edgeIndex: 0, faceIndex: 0))
    }
}
