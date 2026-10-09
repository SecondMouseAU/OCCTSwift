import Testing
import simd

@testable import OCCTSwift

// MARK: - Wire Join and Offset Tests

@Suite("Wire, Join and Offset")
struct WireJoinOffsetTests {
    @Test("Join two wires")
    func joinWires() {
        let line1 = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let line2 = Wire.line(from: SIMD3(10, 0, 0), to: SIMD3(10, 10, 0))!
        let joined = Wire.join([line1, line2])
        #expect(joined != nil)
    }

    @Test("Offset wire")
    func offsetWire() {
        let rect = Wire.rectangle(width: 10, height: 10)!
        let offset = rect.offset(by: 2.0)
        #expect(offset != nil)
    }
}
