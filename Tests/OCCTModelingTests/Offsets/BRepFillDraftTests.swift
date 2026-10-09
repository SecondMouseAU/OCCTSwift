import Testing
import simd

@testable import OCCTSwift

@Suite("BRepFill Draft Tests")
struct BRepFillDraftTests {
    @Test("Draft surface from rectangular wire")
    func draftFromRect() {
        let wire = Wire.rectangle(width: 10, height: 10)!
        let result = Shape.draft(
            wire: wire,
            direction: SIMD3(0, 0, 1),
            angle: 0.1,
            length: 20)
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
        }
    }
}
