import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TDataXtd Shape Attribute Tests (v0.56.0)

@Suite("TDataXtd Shape Attribute")
struct TDataXtdShapeAttributeTests {

    @Test("Set and get shape attribute on label")
    func setGetShape() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 20, depth: 30)!

        #expect(label.setShapeAttribute(box))
        #expect(label.hasShapeAttribute)
        if let retrieved = label.shapeAttribute() {
            #expect(retrieved.isValid)
        }
    }

    @Test("Label without shape attribute")
    func noShapeAttribute() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        #expect(!label.hasShapeAttribute)
        #expect(label.shapeAttribute() == nil)
    }
}
