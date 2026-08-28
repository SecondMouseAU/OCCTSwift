import Testing
import simd

@testable import OCCTSwift

@Suite("BRepFill CompatibleWires Tests")
struct BRepFillCompatibleWiresTests {
    @Test("Make two wires compatible for lofting")
    func normalizeWires() {
        let w1 = Wire.rectangle(width: 10, height: 10)!
        let w2 = Wire.rectangle(width: 15, height: 15)!
        let result = Shape.compatibleWires([w1, w2])
        #expect(result != nil)
        if let r = result {
            #expect(r.count >= 2)
        }
    }
}
