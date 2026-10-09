import Testing
import simd

@testable import OCCTSwift

@Suite("Simple Offset")
struct SimpleOffsetTests {
    @Test("Simple offset of face")
    func offsetFace() {
        // SimpleOffset works on shells/faces, not solids
        let face = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!
        let offset = face.simpleOffset(by: 1.0)
        #expect(offset != nil)
        if let o = offset {
            #expect(o.isValid)
        }
    }
}
