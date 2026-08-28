import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.35.0. OCCT Test Suite Audit Round 4

@Suite("Multi-Offset Wire")
struct MultiOffsetWireTests {
    @Test("Multiple inward offsets from face")
    func multipleInwardOffsets() {
        // Create a planar face from a rectangle
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        let wires = face.multiOffsetWires(offsets: [-1.0, -2.0, -3.0])
        #expect(wires.count >= 3)
        // Each inward offset should produce a smaller contour
        if wires.count >= 3 {
            let l0 = wires[0].length
            let l1 = wires[1].length
            let l2 = wires[2].length
            if let l0, let l1, let l2 {
                #expect(l0 > l1)
                #expect(l1 > l2)
            }
        }
    }

    @Test("Outward offset from face")
    func outwardOffset() {
        let face = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!
        let wires = face.multiOffsetWires(offsets: [1.0, 2.0])
        #expect(wires.count >= 2)
    }

    @Test("Empty offsets returns empty array")
    func emptyOffsets() {
        let face = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!
        let wires = face.multiOffsetWires(offsets: [])
        #expect(wires.isEmpty)
    }
}
