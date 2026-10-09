import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeFix FixSmallSolid Tests")
struct ShapeFixSmallSolidTests {
    @Test("Remove small solids by volume")
    func removeSmallSolids() throws {
        let big = Shape.box(width: 10, height: 10, depth: 10)!
        let tiny = Shape.box(width: 0.01, height: 0.01, depth: 0.01)!

        // Translate tiny box away from big box
        let movedTiny = tiny.translated(by: SIMD3(20, 0, 0))!
        let compound = Shape.compound([big, movedTiny])!

        let solidsBefore = compound.solids.count
        #expect(solidsBefore == 2)

        if let result = compound.removeSmallSolids(volumeThreshold: 1.0) {
            let solidsAfter = result.solids.count
            #expect(solidsAfter < solidsBefore)
        }
    }

    @Test("Merge small solids")
    func mergeSmallSolids() throws {
        let big = Shape.box(width: 10, height: 10, depth: 10)!
        let tiny = Shape.box(origin: SIMD3(10, 0, 0), width: 0.01, height: 10, depth: 10)!
        let compound = Shape.compound([big, tiny])!

        let solidsBefore = compound.solids.count
        #expect(solidsBefore == 2)

        if let result = compound.mergeSmallSolids(widthFactorThreshold: 1.0) {
            #expect(result.isValid)
        }
    }
}
