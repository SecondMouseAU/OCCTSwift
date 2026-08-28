import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeFix Solid Tests")
struct ShapeFixSolidTests {
    @Test func fixSolid() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let fixed = box.fixSolid() {
                #expect(fixed.isValid)
            }
        }
    }

    @Test func solidFromShellFixed() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let result = box.solidFromShellFixed()
            #expect(result != nil)
        }
    }
}
