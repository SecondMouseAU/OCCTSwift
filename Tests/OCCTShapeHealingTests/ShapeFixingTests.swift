import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-shapefix/probe.mm (transcript.txt beside it).
// Before #766 these force-unwrapped inside `#expect`.
@Suite("Shape Fixing Tests")
struct ShapeFixingTests {
    @Test("Fix healthy shape returns shape")
    func fixHealthyShape() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let fixed = try #require(box.fixed(tolerance: 0.001))
        #expect(fixed.isValid)
        #expect(fixed.shapeType == .solid)
        #expect(abs((fixed.volume ?? 0) - 1000) < 1e-9)
    }

    @Test("Fix with selective modes")
    func fixWithSelectiveModes() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let fixed = try #require(
            box.fixed(tolerance: 0.001, fixSolid: false, fixShell: true, fixFace: true, fixWire: true))
        #expect(fixed.isValid)
        #expect(abs((fixed.volume ?? 0) - 1000) < 1e-9)
    }

    @Test("Existing heal function still works")
    func existingHealStillWorks() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let healed = try #require(box.healed())
        #expect(healed.isValid)
        #expect(abs((healed.volume ?? 0) - 1000) < 1e-9)
    }
}
