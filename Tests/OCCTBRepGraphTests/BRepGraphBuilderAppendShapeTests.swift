import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder AppendShape")
struct BRepGraphBuilderAppendShapeTests {
    @Test func appendFlattenedShape() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let origFaces = graph.faceCount
                if let sphere = Shape.sphere(radius: 5) {
                    graph.appendFlattenedShape(sphere)
                    #expect(graph.faceCount > origFaces)
                }
            }
        }
    }

    @Test func appendFullShape() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let origFaces = graph.faceCount
                if let cylinder = Shape.cylinder(radius: 3, height: 8) {
                    graph.appendFullShape(cylinder)
                    #expect(graph.faceCount > origFaces)
                }
            }
        }
    }
}
