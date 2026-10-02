import Foundation
import Testing
import simd

@testable import OCCTSwift

// Lifted from #2320 on `v5.0.0-766-execution`, re-measured against `main`'s kernel.
//
// Values pinned to the kernel probe (`Scripts/repro/766-brepgraph-edge-def-geometry/`). Where a
// box answers the same for every edge (not degenerated, has a curve, not a seam), the sphere's
// degenerate pole edges and its seam are added, so an answer that never varies fails.
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
        // The sphere's two pole edges are degenerate and its seam is not.
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
        // A box edge of length 10 is parameterised by arc length. `first < last` held for any
        // non-empty range.
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

    // `OCCTBRepGraphEdgeMaxContinuity` returns 0 unconditionally and says so: the kernel's
    // regularity layer (`BRepGraph_LayerRegularity`) is absent from the pinned libOCCT, so
    // nothing is computed, and ``BRepGraph/edgeMaxContinuity(_:)``'s own documentation states
    // the constant. `>= 0` held for every Int32; this pins the documented value, so a real
    // implementation has to update this test knowingly. `Shape.maxContinuity` is the measured
    // path.
    @Test func edgeMaxContinuity() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.edgeMaxContinuity(0) == 0)
    }

    @Test func edgeNotClosedOnFace() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // Box edge 0 belongs to faces 0 and 2 and is a seam on neither.
        #expect(graph.faces(of: 0) == [0, 2])
        for faceIdx in graph.faces(of: 0) {
            #expect(!graph.isEdgeClosedOnFace(edgeIndex: 0, faceIndex: faceIdx))
        }
        // The sphere's seam edge 1 IS closed on its only face, which is what makes the negative
        // answers above mean something.
        let sphere = try #require(Shape.sphere(radius: 5))
        let sg = try #require(BRepGraph(shape: sphere))
        #expect(sg.isEdgeClosedOnFace(edgeIndex: 1, faceIndex: 0))
        #expect(!sg.isEdgeClosedOnFace(edgeIndex: 0, faceIndex: 0))
    }
}
