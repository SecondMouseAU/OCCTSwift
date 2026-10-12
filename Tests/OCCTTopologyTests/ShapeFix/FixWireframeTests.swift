import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Fix Wireframe")
struct FixWireframeTests {
    @Test("Fix wireframe on valid shape")
    func fixValidShape() throws {
        // A valid box is returned unchanged: six faces, twelve edges, volume 1000.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let fixed = try #require(box.fixedWireframe())
        #expect(fixed.isValid)
        #expect(fixed.faceCount == 6)
        #expect(fixed.edgeCount == 12)
        #expect(abs(try #require(fixed.volume) - 1000) < 1e-6)
        #expect(box.isValid)

        // Control: a face with a 1e-4 side is invalid as built (five edges), and at tolerance
        // 1e-3 the wireframe fix removes the side: four edges, valid.
        let polygon = try #require(
            Wire.polygon3D(
                [
                    SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(10.0001, 10, 0),
                    SIMD3(0, 10, 0),
                ], closed: true))
        let face = try #require(Shape.face(from: polygon))
        #expect(face.edgeCount == 5)
        #expect(!face.isValid)
        let healed = try #require(face.fixedWireframe(tolerance: 1e-3))
        #expect(healed.edgeCount == 4)
        #expect(healed.isValid)
    }
}
