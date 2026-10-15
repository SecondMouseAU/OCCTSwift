import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TNaming CopyShape Tests (v0.56.0)

@Suite("TNaming CopyShape")
struct TNamingCopyShapeTests {

    @Test("Deep copy a box shape")
    func deepCopyBox() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let copy = try #require(box.deepCopy())
        #expect(copy.isValid)
        #expect(copy !== box)
    }

    @Test("Deep copy a sphere shape")
    func deepCopySphere() throws {
        let sphere = try #require(Shape.sphere(radius: 5.0))
        let copy = try #require(sphere.deepCopy())
        #expect(copy.isValid)
        // The copy is the same sphere: a solid of one face with 4/3 pi r^3 volume and the same
        // extent, and it is a separate shape rather than the original.
        #expect(copy.shapeType == .solid)
        #expect(copy.subShapes(ofType: .face).count == 1)
        #expect(abs((copy.volume ?? 0) - 4.0 / 3.0 * Double.pi * 125.0) < 1e-6)
        let bounds = try #require(copy.bounds)
        #expect(vectorDistance(bounds.min, SIMD3(-5, -5, -5)) < 1e-5)
        #expect(vectorDistance(bounds.max, SIMD3(5, 5, 5)) < 1e-5)
        #expect(copy !== sphere)
        #expect(!copy.isSame(as: sphere))
    }
}
