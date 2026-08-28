import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Shape Fixing Tests")
struct ShapeFixingTests {

    @Test("Fix healthy shape returns shape")
    func fixHealthyShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let fixed = box.fixed(tolerance: 0.001)

        #expect(fixed != nil)
        #expect(fixed!.isValid)
    }

    @Test("Fix with selective modes")
    func fixWithSelectiveModes() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        // Fix only wires and faces, not solids
        let fixed = box.fixed(
            tolerance: 0.001, fixSolid: false, fixShell: true, fixFace: true, fixWire: true)

        #expect(fixed != nil)
        #expect(fixed!.isValid)
    }

    @Test("Existing heal function still works")
    func existingHealStillWorks() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        // The healed() function should still work
        let healed = box.healed()!

        #expect(healed.isValid)
    }
}
