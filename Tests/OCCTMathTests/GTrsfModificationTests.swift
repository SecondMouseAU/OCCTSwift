import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepTools_GTrsfModification")
struct GTrsfModificationTests {
    @Test("non-uniform scale")
    func nonUniformScale() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // First convert to NURBS for non-uniform scaling
            if let nurbs = box.convertedToNURBS() {
                // Scale X by 2
                if let result = Shape.gtrsfModification(
                    nurbs,
                    a11: 2, a12: 0, a13: 0, a14: 0,
                    a21: 0, a22: 1, a23: 0, a24: 0,
                    a31: 0, a32: 0, a33: 1, a34: 0)
                {
                    #expect(result.isValid)
                }
            }
        }
    }
}

