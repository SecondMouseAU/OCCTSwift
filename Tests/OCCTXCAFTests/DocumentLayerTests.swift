import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Document Layers")
struct DocumentLayerTests {
    // #2413: `layerCount` used to read a layer tool attached to `Main()`, which enumerates the
    // XCAF tool labels (Shapes, Colors, Layers, D&GTs, Materials, Views, Clipping Planes, Notes,
    // VisMaterials) rather than the layer table at `0:1:3` that `OCCTDocumentSetLayer` writes to.
    // This test used to read "XCAF documents come with built-in layers" and assert
    // `layerCount > 0`, which passed only because of that defect: a fresh XCAF document has no
    // layers at all. Measured in Scripts/repro/2413-layer-tool-on-main/transcript.txt.
    @Test("A fresh document has no layers, and no tool label is listed as one")
    func freshDocumentHasNoLayers() throws {
        let doc = try #require(Document.create())
        #expect(doc.layerCount == 0)
        #expect(doc.layerNames.isEmpty)
        // Named individually, because the count alone would also pass if the list were some other
        // wrong set of the same size.
        let toolLabelNames = [
            "Shapes", "Colors", "Layers", "D&GTs", "Materials", "Views", "Clipping Planes",
            "Notes", "VisMaterials",
        ]
        for name in toolLabelNames {
            #expect(!doc.layerNames.contains(name), "tool label \"\(name)\" listed as a layer")
        }
    }

    @Test("A layer written through the bridge is the one that reads back")
    func writtenLayerReadsBack() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        OCCTDocumentSetLayer(doc.handle, label.labelId, "Sheet Metal")
        #expect(doc.layerCount == 1)
        #expect(doc.layerNames == ["Sheet Metal"])
        #expect(doc.layerName(at: 0) == "Sheet Metal")
    }

    @Test("Two layers both read back, and nothing else does")
    func twoLayersReadBack() throws {
        let doc = try #require(Document.create())
        let a = try #require(doc.createLabel())
        let b = try #require(doc.createLabel())
        OCCTDocumentSetLayer(doc.handle, a.labelId, "Inner")
        OCCTDocumentSetLayer(doc.handle, b.labelId, "Outer")
        #expect(doc.layerCount == 2)
        #expect(Set(doc.layerNames) == ["Inner", "Outer"])
    }

    @Test("Layer name out of range returns nil")
    func outOfRange() throws {
        let doc = try #require(Document.create())
        #expect(doc.layerName(at: 999) == nil)
        #expect(doc.layerName(at: -1) == nil)
    }
}
