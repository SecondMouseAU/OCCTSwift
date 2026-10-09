import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeCustom DirectModification")
struct ShapeCustomDirectModificationTests {
    @Test("Direct modification orients normals")
    func directModification() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let result = box.directModification()
        #expect(result != nil)
        if let result = result { #expect(result.isValid) }
    }
}
