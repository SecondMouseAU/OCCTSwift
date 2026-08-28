import Testing
import simd

@testable import OCCTSwift

@Suite("BRepOffset SimpleOffset")
struct BRepOffsetSimpleOffsetTests {
    @Test("Simple offset on box")
    func simpleOffsetBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let result = box.simpleOffsetShape(distance: 1.0)
        #expect(result != nil)
        if let result = result {
            #expect(result.isValid)
        }
    }
}
