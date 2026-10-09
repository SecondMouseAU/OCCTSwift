import Testing
import simd

@testable import OCCTSwift

@Suite("v0.114.0 - Offset Wire/Face")
struct OffsetWireFaceTests {

    @Test func offsetWire() {
        if let rect = Wire.rectangle(width: 10, height: 10),
            let wireShape = Shape.fromWire(rect)
        {
            let offset = wireShape.offsetWireOnPlane(distance: 2.0)
            #expect(offset != nil)
        }
    }

    @Test func offsetWireIntersection() {
        if let rect = Wire.rectangle(width: 10, height: 10),
            let wireShape = Shape.fromWire(rect)
        {
            let offset = wireShape.offsetWireOnPlane(distance: 1.0, joinType: .intersection)
            #expect(offset != nil)
        }
    }

    @Test func offsetFace() {
        if let rect = Wire.rectangle(width: 20, height: 20),
            let face = Shape.face(from: rect)
        {
            let offset = face.offsetFace(distance: 2.0)
            #expect(offset != nil)
        }
    }
}
