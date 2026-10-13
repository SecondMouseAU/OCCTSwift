import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("v0.115.0 - Shape Queries")
struct ShapeQueryTests {

    @Test func obbVolume() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let vol = box.obbVolume
            #expect(vol > 0)
            // OBB should be close to 10*10*10 = 1000 but may differ due to centering
            #expect(vol > 500)
        }
    }

    @Test func maxTolerances() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // BRepPrimAPI builds every sub-shape at Precision::Confusion(), 1e-7.
        #expect(abs(box.maxEdgeTolerance - 1e-7) < 1e-12)
        #expect(abs(box.maxFaceTolerance - 1e-7) < 1e-12)
        #expect(abs(box.maxVertexTolerance - 1e-7) < 1e-12)
        // The edge query reads edges only: an edge's own tolerance is what it reports.
        let edge = try #require(box.subShapes(ofType: .edge).first)
        #expect(abs(edge.maxEdgeTolerance - 1e-7) < 1e-12)
    }

    @Test func freeEdges() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // A solid box should not have free edges
            #expect(!box.hasFreeEdges)
        }
    }

    @Test func freeEdgesOnOpenShell() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)

        // Five of the six faces: the four edges round the missing face are free.
        let open = try #require(Shape.builderMakeCompound())
        for face in faces.prefix(5) { open.builderAdd(face) }
        #expect(open.hasFreeEdges)

        // All six: every edge is shared by two faces, nothing is free. Same call, so the
        // answer follows the topology, not the entry point.
        let closed = try #require(Shape.builderMakeCompound())
        for face in faces { closed.builderAdd(face) }
        #expect(!closed.hasFreeEdges)
    }

    @Test func boundingDiagonal() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let diag = box.boundingDiagonal
            // For a 10x10x10 box centered at origin, diagonal = sqrt(100+100+100) ~ 17.3
            #expect(diag > 15)
            #expect(diag < 20)
        }
    }

    @Test func centroid() {
        if let box = Shape.box(width: 10, height: 10, depth: 10), let c = box.centroid {
            // Box centered at origin
            #expect(abs(c.x) < 1)
            #expect(abs(c.y) < 1)
            #expect(abs(c.z) < 1)
        }
    }

    @Test func totalEdgeLength() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // One term per edge occurrence: each of the 12 edges is reached from two faces, so
        // 24 x 10 (the doc comment's "a box reads twice the sum of its 12 distinct edges").
        #expect(abs(box.totalEdgeLength - 240) < 1e-9)
        // A wire has no sharing: the perimeter once.
        let rect = try #require(Wire.rectangle(width: 10, height: 5))
        let wire = try #require(Shape.fromWire(rect))
        #expect(abs(wire.totalEdgeLength - 30) < 1e-9)
    }
}
