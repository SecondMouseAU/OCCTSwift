import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// MARK: - Deep Shape Copy Tests (v0.38.0)

@Suite("Deep Shape Copy")
struct DeepShapeCopyTests {

    @Test("Copy preserves geometry")
    func copyPreservesGeometry() throws {
        let box = try #require(Shape.box(width: 10, height: 5, depth: 3))
        let boxCopy = box.copy()
        #expect(boxCopy != nil)
        #expect(try abs(#require(boxCopy?.volume) - #require(box.volume)) < 0.001)
        #expect(try #require(boxCopy).faces().count == box.faces().count)
    }

    @Test("Copy is independent")
    func copyIsIndependent() throws {
        let box = try #require(Shape.box(width: 10, height: 5, depth: 3))
        let boxCopy = box.copy()
        #expect(boxCopy != nil)
        // Translate the copy, original should be unaffected
        let translated = try #require(boxCopy).translated(by: SIMD3(100, 0, 0))
        #expect(translated != nil)
        // Both should still have the same volume
        #expect(try abs(#require(box.volume) - 150.0) < 0.001)
    }

    @Test("Copy without geometry sharing")
    func copyWithGeometry() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let copy = cyl.copy(copyGeometry: true, copyMesh: false)
        #expect(copy != nil)
        #expect(try abs(#require(copy?.volume) - #require(cyl.volume)) < 0.1)
    }
}
