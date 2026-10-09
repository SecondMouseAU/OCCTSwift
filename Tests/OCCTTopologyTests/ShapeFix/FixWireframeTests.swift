import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Fix Wireframe")
struct FixWireframeTests {
    @Test("Fix wireframe on valid shape")
    func fixValidShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let fixed = box.fixedWireframe()
        #expect(fixed != nil)
        #expect(fixed!.isValid)
    }
}
