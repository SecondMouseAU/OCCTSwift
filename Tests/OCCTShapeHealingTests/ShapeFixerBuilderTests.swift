import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.115.0 - ShapeFixer Builder")
struct ShapeFixerBuilderTests {

    @Test func basicFixer() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let fixer = ShapeFixer(shape: box)
            fixer.setPrecision(1e-7)
            fixer.setMaxTolerance(1.0)
            fixer.setMinTolerance(1e-10)
            let _ = fixer.perform()
            let result = fixer.shape
            #expect(result != nil)
            if let r = result {
                #expect(r.isValid)
            }
        }
    }

    @Test func fixerStatus() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let fixer = ShapeFixer(shape: box)
            let _ = fixer.perform()
            // After performing on a valid box, should not be in FAIL state
            let hasFailed = fixer.status(3)  // 3=FAIL
            #expect(!hasFailed)
            let result = fixer.shape
            #expect(result != nil)
        }
    }
}
