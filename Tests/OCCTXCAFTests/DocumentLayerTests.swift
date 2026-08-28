import Foundation
import Testing

@testable import OCCTSwift

@Suite("Document Layers")
struct DocumentLayerTests {
    @Test("Document has XCAF built-in layers")
    func builtInLayers() {
        let doc = Document.create()!
        // XCAF documents come with built-in tool labels
        #expect(doc.layerCount > 0)
        let names = doc.layerNames
        #expect(!names.isEmpty)
    }

    @Test("Layer name out of range returns nil")
    func outOfRange() {
        let doc = Document.create()!
        #expect(doc.layerName(at: 999) == nil)
        #expect(doc.layerName(at: -1) == nil)
    }
}
