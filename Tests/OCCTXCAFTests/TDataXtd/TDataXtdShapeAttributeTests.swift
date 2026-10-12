import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TDataXtd Shape Attribute Tests (v0.56.0)

@Suite("TDataXtd Shape Attribute")
struct TDataXtdShapeAttributeTests {

    @Test("Set and get shape attribute on label")
    func setGetShape() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))

        #expect(label.setShapeAttribute(box))
        #expect(label.hasShapeAttribute)
        // What was stored is what comes back: the same solid, with the same extent.
        let retrieved = try #require(label.shapeAttribute())
        #expect(retrieved.isValid)
        #expect(retrieved.shapeType == .solid)
        #expect(abs((retrieved.volume ?? 0) - 6000) < 1e-6)
        let bounds = try #require(retrieved.bounds)
        #expect(vectorDistance(bounds.min, SIMD3(-5, -10, -15)) < 1e-5)
        #expect(vectorDistance(bounds.max, SIMD3(5, 10, 15)) < 1e-5)
    }

    @Test("Label without shape attribute")
    func noShapeAttribute() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        #expect(!label.hasShapeAttribute)
        #expect(label.shapeAttribute() == nil)
    }
}
