import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder AppendShape")
struct BRepGraphBuilderAppendShapeTests {
    // Face counts pinned to the kernel probe (Scripts/repro/766-brepgraph-builder-mutation):
    // the box's 6 faces plus the sphere's 1, or the cylinder's 3. `> origFaces` accepted an
    // append that duplicated or dropped faces (#1986).
    @Test func appendFlattenedShape() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let origFaces = graph.faceCount
        #expect(origFaces == 6)
        let sphere = try #require(Shape.sphere(radius: 5))
        graph.appendFlattenedShape(sphere)
        #expect(graph.faceCount == origFaces + 1)
    }

    @Test func appendFullShape() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let origFaces = graph.faceCount
        #expect(origFaces == 6)
        let cylinder = try #require(Shape.cylinder(radius: 3, height: 8))
        graph.appendFullShape(cylinder)
        #expect(graph.faceCount == origFaces + 3)
    }
}
