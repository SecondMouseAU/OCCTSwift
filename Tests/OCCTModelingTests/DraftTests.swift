import Testing
import simd

@testable import OCCTSwift

@Suite("Draft from Shape")
struct DraftTests {
    @Test("Draft a circle wire")
    func draftCircle() {
        let circle = Wire.circle(radius: 5)!
        let wireShape = Shape.fromWire(circle)!
        let drafted = wireShape.draft(direction: SIMD3(0, 0, 1), angle: 0.1, length: 10)
        #expect(drafted != nil)
        if let drafted {
            #expect(drafted.isValid)
        }
    }
}
