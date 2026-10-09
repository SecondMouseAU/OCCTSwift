import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-shapefix/probe.mm (transcript.txt beside it).
// Before #766 both asserted only inside `if let`, and the merge test only `isValid`.
@Suite("ShapeFix FixSmallSolid Tests")
struct ShapeFixSmallSolidTests {
    @Test("Remove small solids by volume")
    func removeSmallSolids() throws {
        let big = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let tiny = try #require(Shape.box(width: 0.01, height: 0.01, depth: 0.01))
        let movedTiny = try #require(tiny.translated(by: SIMD3(20, 0, 0)))
        let compound = try #require(Shape.compound([big, movedTiny]))
        #expect(compound.solids.count == 2)
        // Kernel: the 1e-6 box goes, the 1000 one stays.
        let result = try #require(compound.removeSmallSolids(volumeThreshold: 1.0))
        #expect(result.solids.count == 1)
        #expect(abs((result.volume ?? 0) - 1000) < 1e-6)
    }

    @Test("Merge small solids")
    func mergeSmallSolids() throws {
        // Kernel: at width factor 1.0 the thin slab is not merged; both solids remain, 1001 total.
        let big = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let tiny = try #require(Shape.box(origin: SIMD3(10, 0, 0), width: 0.01, height: 10, depth: 10))
        let compound = try #require(Shape.compound([big, tiny]))
        #expect(compound.solids.count == 2)
        let result = try #require(compound.mergeSmallSolids(widthFactorThreshold: 1.0))
        #expect(result.isValid)
        #expect(result.solids.count == 2)
        #expect(abs((result.volume ?? 0) - 1001) < 1e-6)
    }
}
