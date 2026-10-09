import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-shapefix/probe.mm (transcript.txt beside it).
// Before #766 both were nested in `if let` and asserted only validity or non-nil.
@Suite("ShapeFix Solid Tests")
struct ShapeFixSolidTests {
    @Test func fixSolid() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let fixed = try #require(box.fixSolid())
        #expect(fixed.isValid)
        #expect(fixed.shapeType == .solid)
        #expect(abs((fixed.volume ?? 0) - 1000) < 1e-9)
    }

    @Test func solidFromShellFixed() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let result = try #require(box.solidFromShellFixed())
        #expect(result.shapeType == .solid)
        #expect(abs((result.volume ?? 0) - 1000) < 1e-9)
    }
}
