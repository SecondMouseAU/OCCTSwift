import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Periodic Shapes")
struct PeriodicTests {
    @Test("Make shape periodic in X")
    func periodicX() throws {
        let box = try #require(Shape.box(width: 5, height: 5, depth: 5))
        // A period that fits (10 over a 5-wide box) has nothing to cut: the solid comes back.
        let fits = try #require(box.makePeriodic(xPeriod: 10))
        #expect(fits.isValid)
        #expect(fits.subShapes(ofType: .solid).count == 1)
        #expect(fits.faces().count == 6)
        #expect(abs((fits.volume ?? 0) - 125) < 1e-6)

        // A period of 3 cuts the 5-wide box where the period boundaries cross it: three solids
        // with the same total volume, and more faces (16) for the cut planes.
        let cut = try #require(box.makePeriodic(xPeriod: 3))
        #expect(cut.isValid)
        #expect(cut.subShapes(ofType: .solid).count == 3)
        #expect(cut.faces().count == 16)
        #expect(abs((cut.volume ?? 0) - 125) < 1e-6)
        let bounds = try #require(cut.boundingBox)
        #expect(vectorLength(bounds.min - SIMD3(-2.5, -2.5, -2.5)) < 1e-5)
        #expect(vectorLength(bounds.max - SIMD3(2.5, 2.5, 2.5)) < 1e-5)
    }

    @Test("Repeat shape")
    func repeatShape() throws {
        let box = try #require(Shape.box(width: 5, height: 5, depth: 5))
        // xCount 3 gives the original plus three copies, 10 apart: four solids, 4 x 125.
        let repeated = try #require(box.repeated(xPeriod: 10, xCount: 3))
        #expect(repeated.isValid)
        #expect(repeated.subShapes(ofType: .solid).count == 4)
        #expect(repeated.faces().count == 24)
        #expect(abs((repeated.volume ?? 0) - 500) < 1e-6)
        let bounds = try #require(repeated.boundingBox)
        #expect(vectorLength(bounds.min - SIMD3(-2.5, -2.5, -2.5)) < 1e-5)
        #expect(vectorLength(bounds.max - SIMD3(32.5, 2.5, 2.5)) < 1e-5)

        // Two directions multiply: 4 x 3 solids, and the Y extent grows by 2 x 8.
        let grid = try #require(box.repeated(xPeriod: 10, xCount: 3, yPeriod: 8, yCount: 2))
        #expect(grid.subShapes(ofType: .solid).count == 12)
        #expect(abs((grid.volume ?? 0) - 1500) < 1e-6)
        let gridBounds = try #require(grid.boundingBox)
        #expect(vectorLength(gridBounds.max - SIMD3(32.5, 18.5, 2.5)) < 1e-5)
    }
}
