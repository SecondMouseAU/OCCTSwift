import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-shapefix/probe.mm (transcript.txt beside it).
// Before #766 both asserted only `isValid`, which the untouched box also is.
@Suite("ShapeFix Tolerance Tests")
struct ShapeFixToleranceTests {
    @Test("Set tolerance on box")
    func setTolerance() throws {
        // Kernel: SetTolerance(1e-5) sets every sub-shape to 1e-5 (max and min).
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        box.setTolerance(1e-5)
        #expect(box.isValid)
        #expect(abs(box.toleranceValue(mode: .maximum) - 1e-5) < 1e-15)
        #expect(abs(box.toleranceValue(mode: .minimum) - 1e-5) < 1e-15)
    }

    @Test("Limit tolerance on box")
    func limitTolerance() throws {
        // Kernel: the box is already inside [1e-7, 1e-3], so nothing changes (false), max 1e-7.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.limitTolerance(min: 1e-7, max: 1e-3) == false)
        #expect(box.isValid)
        #expect(abs(box.toleranceValue(mode: .maximum) - 1e-7) < 1e-15)
    }
}
