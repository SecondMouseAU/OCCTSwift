import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// MARK: - Audit Fix Tests

@Suite("Shape.fromFace conversion") struct ShapeFromFaceTests {
    @Test("Shape.fromFace converts face to shape")
    func faceToShape() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.faces()
        #expect(faces.count == 6)
        let face = try #require(faces.first)
        let shape = try #require(Shape.fromFace(face))
        #expect(shape.isValid)
        #expect(shape.shapeType == .face)
        // One 10 x 10 face with its four edges, not the whole box.
        #expect(shape.faces().count == 1)
        #expect(shape.edges().count == 4)
        #expect(abs((shape.surfaceArea ?? 0) - 100) < 1e-6)
    }
}
