import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - Generic Sub-Shape Extraction (fixes #36)

@Suite("Generic Sub-Shape Extraction")
struct GenericSubShapeExtractionTests {
    @Test("Box has 6 faces")
    func boxFaceCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.subShapeCount(ofType: .face) == 6)
    }

    @Test("Box has 12 edges")
    func boxEdgeCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.subShapeCount(ofType: .edge) == 12)
    }

    @Test("Box has 8 vertices")
    func boxVertexCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.subShapeCount(ofType: .vertex) == 8)
    }

    @Test("Extract face by index")
    func extractFaceByIndex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let face = box.subShape(type: .face, index: 0)
        #expect(face != nil)
        #expect(face!.shapeType == .face)
    }

    @Test("Extract all faces")
    func extractAllFaces() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        for face in faces {
            #expect(face.shapeType == .face)
        }
    }

    @Test("Out of range index returns nil")
    func outOfRangeReturnsNil() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.subShape(type: .face, index: 99) == nil)
        #expect(box.subShape(type: .face, index: -1) == nil)
    }

    @Test("Issue #36: Remove a face from filleted box via surgery")
    func removeFaceFromFilletedBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let filleted = box.filleted(radius: 1.0)!

        let faceCount = filleted.subShapeCount(ofType: .face)
        #expect(faceCount > 6)  // Filleted box has more faces

        // Extract a face and remove it
        let face0 = filleted.subShape(type: .face, index: 0)!
        let result = filleted.removingSubShapes([face0])
        #expect(result != nil)
        if let result {
            let newFaceCount = result.subShapeCount(ofType: .face)
            #expect(newFaceCount == faceCount - 1)
        }
    }

    @Test("Extract edge sub-shapes")
    func extractEdges() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let edges = cyl.subShapes(ofType: .edge)
        #expect(edges.count > 0)
        for edge in edges {
            #expect(edge.shapeType == .edge)
        }
    }
}
