import Foundation
import Testing
import simd

@testable import OCCTSwift

// Values pinned to the kernel probe (Scripts/repro/766-brepgraph-edge-wires-explorer-face).
// Two of these tests asserted nothing ("just check it returns a bool") and one accepted any
// positive tolerance (#1986).
@Suite("BRepGraph Face Geometry")
struct BRepGraphFaceGeometryTests {
    @Test func faceTolerance() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.faceTolerance(0) == 1e-7)
    }

    @Test func faceHasSurface() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.faceCount == 6)
        for i in 0..<graph.faceCount {
            #expect(graph.faceHasSurface(i))
        }
    }

    // The 8.0.1 kernel always materialises a bounding wire, so no face of a box, or even of a
    // sphere, reports natural restriction (NbWires == 0 is false for both).
    @Test func faceNaturalRestriction() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(!graph.isFaceNaturalRestriction(0))
        let sphere = try #require(Shape.sphere(radius: 5))
        let sg = try #require(BRepGraph(shape: sphere))
        #expect(!sg.isFaceNaturalRestriction(0))
    }

    // An unmeshed box has no triangulation; after `mesh` it has one on face 0.
    @Test func faceHasTriangulation() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(!graph.faceHasTriangulation(0))
        let meshed = try #require(Shape.box(width: 10, height: 10, depth: 10))
        _ = meshed.mesh(linearDeflection: 0.1)
        let mg = try #require(BRepGraph(shape: meshed))
        #expect(mg.faceHasTriangulation(0))
    }
}
