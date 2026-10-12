import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Fix Small Faces")
struct FixSmallFacesTests {
    @Test("Fix small faces on clean shape")
    func fixCleanShape() throws {
        // A clean box is returned whole: valid, six faces, twelve edges, volume 1000.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let fixed = try #require(box.fixingSmallFaces())
        #expect(fixed.isValid)
        #expect(fixed.faceCount == 6)
        #expect(fixed.edgeCount == 12)
        #expect(abs(try #require(fixed.volume) - 1000) < 1e-6)

        // Control: a box with a 0.0005-thick plate on its top face has ten faces, and at
        // tolerance 1e-3 the four sliver walls are removed, leaving six.
        let plate = try #require(
            Shape.box(origin: SIMD3(-5, -5, 5), width: 10, height: 10, depth: 0.0005))
        let withPlate = try #require(box.union(plate))
        #expect(withPlate.faceCount == 10)
        let cleaned = try #require(withPlate.fixingSmallFaces(tolerance: 1e-3))
        #expect(cleaned.isValid)
        #expect(cleaned.faceCount == 6)
    }
}
