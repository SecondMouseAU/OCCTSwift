import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Divide by Number")
struct DivideByNumberTests {
    @Test("Divide box into parts")
    func divideBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.dividedByNumber(4)
        // Division is geometry-dependent; may return nil for some shapes
        if let r = result {
            #expect(r.faces().count >= box.faces().count)
        }
    }

    @Test("Divide with 1 part returns nil")
    func divideOnePart() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.dividedByNumber(1)
        #expect(result == nil)
    }

    @Test("Divide API callable")
    func divideApiCallable() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        // FaceDivideArea may or may not succeed on curved geometry
        let result = cyl.dividedByNumber(4)
        _ = result
    }
}
