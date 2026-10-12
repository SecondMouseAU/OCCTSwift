import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Sub-Shape Replacement")
struct ReShapeTests {
    @Test("Replace sub-shape")
    func replaceSubShape() throws {
        let box1 = try #require(Shape.box(width: 5, height: 5, depth: 5))
        let box2 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let other = try #require(Shape.box(origin: SIMD3(50, 0, 0), width: 4, height: 4, depth: 4))

        // Replacing a part of a compound swaps that solid and keeps the other: volumes 1000
        // (the replacement) and 64 (the untouched 4-cube).
        let compound = try #require(Shape.compound([box1, other]))
        let swapped = try #require(compound.replacingSubShape(box1, with: box2))
        #expect(swapped.shapeType == .compound)
        let volumes = try swapped.solids.map { try #require($0.volume) }.sorted()
        #expect(volumes.count == 2)
        if volumes.count == 2 {
            #expect(abs(volumes[0] - 64) < 1e-9)
            #expect(abs(volumes[1] - 1000) < 1e-9)
        }
        // The input compound still holds the 5-cube (125) and the 4-cube.
        let original = try compound.solids.map { try #require($0.volume) }.sorted()
        #expect(original.count == 2)
        if original.count == 2 {
            #expect(abs(original[0] - 64) < 1e-9)
            #expect(abs(original[1] - 125) < 1e-9)
        }

        // Replacing the whole shape returns the replacement.
        let whole = try #require(box1.replacingSubShape(box1, with: box2))
        #expect(abs(try #require(whole.volume) - 1000) < 1e-9)
    }
}
