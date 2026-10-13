import Testing

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

    // Face 0 of the cube is the plane x = -5, with outward normal -x. A positive distance moves
    // it out along the normal and a negative one in, so -1 puts it at x = -4. The face keeps
    // its 10 x 10 extent.
    @Test("Negative offset")
    func negativeOffset() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        let face = try #require(faces.first)
        let result = try #require(face.offsetFace(distance: -1.0))
        #expect(result.shapeType == .face)
        #expect(abs((result.surfaceArea ?? -1) - 100.0) < 1e-6)
        let bounds = try #require(result.boundingBox)
        #expect(abs(bounds.min.x + 4.0) < 1e-5 && abs(bounds.max.x + 4.0) < 1e-5)
        #expect(abs(bounds.min.y + 5.0) < 1e-5 && abs(bounds.max.y - 5.0) < 1e-5)
        #expect(abs(bounds.min.z + 5.0) < 1e-5 && abs(bounds.max.z - 5.0) < 1e-5)
        // And the positive one is the mirror: x = -7 for +2.
        let outward = try #require(face.offsetFace(distance: 2.0))
        let outBounds = try #require(outward.boundingBox)
        #expect(abs(outBounds.min.x + 7.0) < 1e-5 && abs(outBounds.max.x + 7.0) < 1e-5)
    }
}
