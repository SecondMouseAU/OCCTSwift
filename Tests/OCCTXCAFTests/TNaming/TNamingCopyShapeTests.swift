import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TNaming CopyShape Tests (v0.56.0)

@Suite("TNaming CopyShape")
struct TNamingCopyShapeTests {

    @Test("Deep copy a box shape")
    func deepCopyBox() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        if let copy = box.deepCopy() {
            #expect(copy.isValid)
            #expect(copy !== box)
        }
    }

    @Test("Deep copy a sphere shape")
    func deepCopySphere() {
        let sphere = Shape.sphere(radius: 5.0)!
        if let copy = sphere.deepCopy() {
            #expect(copy.isValid)
        }
    }
}
