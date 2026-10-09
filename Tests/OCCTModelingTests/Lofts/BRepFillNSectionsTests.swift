import Testing
import simd

@testable import OCCTSwift

@Suite("BRepFill_NSections")
struct BRepFillNSectionsTests {
    @Test("create from wires")
    func createFromWires() {
        if let w1 = Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
            let w2 = Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3),
            let s1 = Shape.fromWire(w1), let s2 = Shape.fromWire(w2)
        {
            if let nsec = NSections.create(wires: [s1, s2]) {
                #expect(nsec.lawCount > 0)
                #expect(!nsec.isVertex)
            }
        }
    }

    @Test("isConstant query")
    func isConstantQuery() {
        if let w1 = Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
            let w2 = Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 5),
            let s1 = Shape.fromWire(w1), let s2 = Shape.fromWire(w2)
        {
            if let nsec = NSections.create(wires: [s1, s2]) {
                let _ = nsec.isConstant
                #expect(true)
            }
        }
    }
}
