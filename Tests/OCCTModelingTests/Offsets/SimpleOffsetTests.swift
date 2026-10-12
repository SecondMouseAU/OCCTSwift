import Testing

@testable import OCCTSwift

@Suite("Simple Offset")
struct SimpleOffsetTests {
    @Test("Simple offset of face")
    func offsetFace() throws {
        // SimpleOffset works on shells/faces, not solids
        let rect = try #require(Wire.rectangle(width: 10, height: 10))
        let face = try #require(Shape.face(from: rect))
        let offset = try #require(face.simpleOffset(by: 1.0))
        #expect(offset.isValid)
        // Measured on kernel.6: the face and its translate joined by four walls, so 100 + 100
        // + 4 * 10 * 1 = 240 of area over six faces, spanning z in [0, 1]. At distance 3 the
        // walls are 3 high: 200 + 120 = 320.
        #expect(offset.faces().count == 6)
        #expect(abs((offset.surfaceArea ?? -1) - 240.0) < 1e-6)
        let bounds = try #require(offset.boundingBox)
        #expect(abs(bounds.min.z) < 1e-5 && abs(bounds.max.z - 1.0) < 1e-5)

        let farther = try #require(face.simpleOffset(by: 3.0))
        #expect(abs((farther.surfaceArea ?? -1) - 320.0) < 1e-6)
        let fartherBounds = try #require(farther.boundingBox)
        #expect(abs(fartherBounds.max.z - 3.0) < 1e-5)
    }
}
