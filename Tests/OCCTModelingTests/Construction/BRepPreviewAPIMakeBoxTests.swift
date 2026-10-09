import Testing
import simd

@testable import OCCTSwift

@Suite("BRepPreviewAPI MakeBox Tests")
struct BRepPreviewAPIMakeBoxTests {
    @Test("normal preview box")
    func normalBox() {
        let box = Shape.previewBox(width: 10, height: 20, depth: 30)
        #expect(box != nil)
    }

    @Test("degenerate face preview")
    func facePreview() {
        let face = Shape.previewBox(width: 10, height: 20, depth: 0)
        #expect(face != nil)
    }

    @Test("degenerate edge preview")
    func edgePreview() {
        let edge = Shape.previewBox(width: 10, height: 0, depth: 0)
        #expect(edge != nil)
    }

    @Test("degenerate vertex preview")
    func vertexPreview() {
        let vertex = Shape.previewBox(width: 0, height: 0, depth: 0)
        #expect(vertex != nil)
    }
}
