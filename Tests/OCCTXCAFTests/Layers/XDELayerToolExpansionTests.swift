import Foundation
import Testing

@testable import OCCTSwift

@Suite("XDE LayerTool Expansion")
struct XDELayerToolExpansionTests {
    @Test("SetLayer and IsLayerSet")
    func setAndCheck() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        doc.addShape(box)
        let roots = doc.rootNodes
        let node = try #require(roots.first)
        node.setLayer("Layer1")
        #expect(node.isLayerSet("Layer1"))
    }

    @Test("GetLayers returns layer names")
    func getLayers() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        doc.addShape(box)
        let roots = doc.rootNodes
        let node = try #require(roots.first)
        node.setLayer("TestLayer")
        let layers = node.layers
        #expect(layers.count == 1)
        if layers.count > 0 {
            #expect(layers[0] == "TestLayer")
        }
    }

    @Test("FindLayer and layer visibility")
    func findAndVisibility() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        doc.addShape(box)
        let roots = doc.rootNodes
        let node = try #require(roots.first)
        node.setLayer("VisLayer")
        let layerLabelId = doc.findLayer("VisLayer")
        #expect(layerLabelId >= 0)

        doc.setLayerVisibility(layerLabelId: layerLabelId, visible: false)
        #expect(!doc.layerVisibility(layerLabelId: layerLabelId))

        doc.setLayerVisibility(layerLabelId: layerLabelId, visible: true)
        #expect(doc.layerVisibility(layerLabelId: layerLabelId))
    }

    @Test("GetLayers past the 16 buffer cap reports the true count (#1563)")
    func getLayersBeyondBufferCap() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        doc.addShape(box)
        let roots = doc.rootNodes
        let node = try #require(roots.first)
        let extraCount = 16 + 3
        for i in 0..<extraCount {
            node.setLayer("Layer\(i)")
        }
        let layers = node.layers
        #expect(
            layers.count == extraCount,
            "Should report all \(extraCount) layers, not the 16-entry buffer cap")
    }
}
