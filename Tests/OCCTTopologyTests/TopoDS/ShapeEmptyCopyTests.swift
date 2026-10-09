import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.114.0 - Shape Empty Copy")
struct ShapeEmptyCopyTests {

    @Test func emptyCopyOfCompound() {
        if let compound = Shape.builderMakeCompound() {
            if let box = Shape.box(width: 10, height: 10, depth: 10) {
                compound.builderAdd(box)
                let copy = compound.emptyCopied()
                #expect(copy != nil)
                if let c = copy {
                    // Empty copy should have no children
                    #expect(c.contentsExtended().nbSolids == 0)
                }
            }
        }
    }
}
