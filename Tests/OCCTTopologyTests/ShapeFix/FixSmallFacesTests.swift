import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Fix Small Faces")
struct FixSmallFacesTests {
    @Test("Fix small faces on clean shape")
    func fixCleanShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let fixed = box.fixingSmallFaces()
        #expect(fixed != nil)
        #expect(fixed!.isValid)
    }
}
