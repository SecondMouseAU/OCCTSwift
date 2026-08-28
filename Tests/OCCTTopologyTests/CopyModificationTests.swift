import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepTools_CopyModification")
struct CopyModificationTests {
    @Test("deep copy shape")
    func deepCopy() {
        if let box = Shape.box(width: 10, height: 20, depth: 30) {
            if let copy = Shape.deepCopy(box) {
                #expect(copy.isValid)
                if let v = copy.volume {
                    #expect(abs(v - 6000) < 1.0)
                }
            }
        }
    }

    @Test("copy without mesh")
    func copyWithoutMesh() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let copy = Shape.deepCopy(box, copyGeometry: true, copyMesh: false) {
                #expect(copy.isValid)
            }
        }
    }
}
