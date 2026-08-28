import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeFix Tolerance Tests")
struct ShapeFixToleranceTests {
    @Test("Set tolerance on box")
    func setTolerance() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        box.setTolerance(1e-5)
        #expect(box.isValid)
    }

    @Test("Limit tolerance on box")
    func limitTolerance() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        _ = box.limitTolerance(min: 1e-7, max: 1e-3)
        #expect(box.isValid)
    }
}
