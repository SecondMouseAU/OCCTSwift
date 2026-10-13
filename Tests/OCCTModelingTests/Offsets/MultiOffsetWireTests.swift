import Testing

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

    // An outward offset of d on a 10 x 10 rectangle with the arc join is four 10 mm edges and
    // four quarter arcs of radius d, so 40 + 2 pi d: 46.28... at 1 and 52.56... at 2.
    @Test("Outward offset from face")
    func outwardOffset() throws {
        let rectangle = try #require(Wire.rectangle(width: 10, height: 10))
        let face = try #require(Shape.face(from: rectangle))
        let wires = face.multiOffsetWires(offsets: [1.0, 2.0])
        #expect(wires.count == 2)
        for (wire, distance) in zip(wires, [1.0, 2.0]) {
            let length = try #require(wire.length)
            #expect(abs(length - (40.0 + 2.0 * Double.pi * distance)) < 1e-6)
        }
    }

    @Test("Empty offsets returns empty array")
    func emptyOffsets() throws {
        let rectangle = try #require(Wire.rectangle(width: 10, height: 10))
        let face = try #require(Shape.face(from: rectangle))
        // The control: the same face gives one wire for one offset, so the empty answer is the
        // empty request and not a face that offsets to nothing.
        #expect(face.multiOffsetWires(offsets: [1.0]).count == 1)
        let wires = face.multiOffsetWires(offsets: [])
        #expect(wires.isEmpty)
    }
}
