import Testing
import simd

@testable import OCCTSwift

@Suite("Boolean Pre-Validation")
struct BooleanCheckTests {
    @Test("Valid box passes boolean check")
    func validBoxCheck() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.isValidForBoolean)
    }

    @Test("Two boxes valid for boolean together")
    func twoBoxesValid() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.sphere(radius: 5)!
        #expect(box1.isValidForBoolean(with: box2))
    }

    @Test("Cylinder valid for boolean")
    func cylinderValid() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        #expect(cyl.isValidForBoolean)
    }
}
