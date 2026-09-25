import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-shapefix/probe.mm (transcript.txt beside it).
// Before #766 both were nested in `if let` on the box. Kernel: Perform() reports nothing done, the
// result is the valid 1000 solid, FAIL is clear.
@Suite("v0.115.0 - ShapeFixer Builder")
struct ShapeFixerBuilderTests {
    @Test func basicFixer() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let fixer = ShapeFixer(shape: box)
        fixer.setPrecision(1e-7)
        fixer.setMaxTolerance(1.0)
        fixer.setMinTolerance(1e-10)
        #expect(fixer.perform() == false)
        let r = try #require(fixer.shape)
        #expect(r.isValid)
        #expect(r.shapeType == .solid)
        #expect(abs((r.volume ?? 0) - 1000) < 1e-9)
    }

    @Test func fixerStatus() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let fixer = ShapeFixer(shape: box)
        _ = fixer.perform()
        #expect(!fixer.status(3))  // 3 = FAIL
        #expect(fixer.shape != nil)
    }
}
