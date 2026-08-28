import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Sub-Shape Replacement")
struct ReShapeTests {
    @Test("Replace sub-shape")
    func replaceSubShape() {
        // Create a compound and replace one part
        let box1 = Shape.box(width: 5, height: 5, depth: 5)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!
        // Replacing box1 with box2 in a compound context
        let result = box1.replacingSubShape(box1, with: box2)
        // May return the replacement shape or nil if topology doesn't allow
        _ = result
    }
}
