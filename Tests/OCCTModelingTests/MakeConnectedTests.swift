import Testing
import simd

@testable import OCCTSwift

@Suite("Make Connected")
struct MakeConnectedTests {
    @Test("Connect two adjacent boxes")
    func connectBoxes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(10, 0, 0))!
        let connected = Shape.makeConnected([box1, box2])
        #expect(connected != nil)
    }
}
