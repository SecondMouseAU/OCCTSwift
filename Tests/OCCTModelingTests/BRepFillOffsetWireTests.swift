import Testing
import simd

@testable import OCCTSwift

@Suite("BRepFill OffsetWire Tests")
struct BRepFillOffsetWireTests {
    @Test("Offset planar wire outward")
    func offsetOutward() {
        // Create a face from a rectangle
        let wire = Wire.rectangle(width: 20, height: 20)!
        if let shape = Shape.fromWire(wire) {
            let faces = shape.faces()
            if !faces.isEmpty {
                let result = Shape.offsetWire(face: faces[0], offset: 3.0)
                #expect(result != nil)
            }
        }
    }

    @Test("Offset planar wire inward")
    func offsetInward() {
        let wire = Wire.rectangle(width: 20, height: 20)!
        if let shape = Shape.fromWire(wire) {
            let faces = shape.faces()
            if !faces.isEmpty {
                let result = Shape.offsetWire(face: faces[0], offset: -3.0)
                #expect(result != nil)
            }
        }
    }
}
