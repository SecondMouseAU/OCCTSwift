import Testing
import simd

@testable import OCCTSwift

@Suite("BRepOffset Offset Face")
struct BRepOffsetOffsetFaceTests {
    @Test("Offset box face")
    func offsetBoxFace() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let faces = box.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        let result = faces[0].offsetFace(distance: 2.0)
        #expect(result != nil)
        if let result = result {
            #expect(result.shapeType == .face)
        }
    }

    @Test("Negative offset")
    func negativeOffset() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let faces = box.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        let result = faces[0].offsetFace(distance: -1.0)
        #expect(result != nil)
    }
}
