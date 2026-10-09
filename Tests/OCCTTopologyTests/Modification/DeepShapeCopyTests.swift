import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - Deep Shape Copy Tests (v0.38.0)

@Suite("Deep Shape Copy")
struct DeepShapeCopyTests {

    @Test("Copy preserves geometry")
    func copyPreservesGeometry() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let boxCopy = box.copy()
        #expect(boxCopy != nil)
        #expect(abs(boxCopy!.volume! - box.volume!) < 0.001)
        #expect(boxCopy!.faces().count == box.faces().count)
    }

    @Test("Copy is independent")
    func copyIsIndependent() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let boxCopy = box.copy()
        #expect(boxCopy != nil)
        // Translate the copy, original should be unaffected
        let translated = boxCopy!.translated(by: SIMD3(100, 0, 0))
        #expect(translated != nil)
        // Both should still have the same volume
        #expect(abs(box.volume! - 150.0) < 0.001)
    }

    @Test("Copy without geometry sharing")
    func copyWithGeometry() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let copy = cyl.copy(copyGeometry: true, copyMesh: false)
        #expect(copy != nil)
        #expect(abs(copy!.volume! - cyl.volume!) < 0.1)
    }
}
