import Foundation
import Testing

@testable import OCCTSwift

@Suite("v0.126.0, XCAFDoc_ColorTool completions")
struct ColorToolCompletionsTests {
    @Test("AddColor and FindColor")
    func addAndFindColor() {
        guard let doc = Document.create() else { return }
        let tag = doc.colorToolAddColor(r: 1.0, g: 0.0, b: 0.0)
        #expect(tag >= 0)
        let found = doc.colorToolFindColor(r: 1.0, g: 0.0, b: 0.0)
        #expect(found == tag)
    }

    @Test("GetColorCount increases after AddColor")
    func colorCount() {
        guard let doc = Document.create() else { return }
        let before = doc.colorToolColorCount
        let _ = doc.colorToolAddColor(r: 0.0, g: 1.0, b: 0.0)
        let after = doc.colorToolColorCount
        #expect(after == before + 1)
    }

    @Test("RemoveColor removes a color")
    func removeColor() {
        guard let doc = Document.create() else { return }
        let tag = doc.colorToolAddColor(r: 0.0, g: 0.0, b: 1.0)
        let before = doc.colorToolColorCount
        let ok = doc.colorToolRemoveColor(labelId: tag)
        #expect(ok)
        let after = doc.colorToolColorCount
        #expect(after == before - 1)
    }

    @Test("Visibility defaults to true")
    func visibility() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                // Default visibility is true
                #expect(doc.colorToolIsVisible(labelId: labelId))
                // Set invisible
                doc.colorToolSetVisibility(labelId: labelId, visible: false)
                #expect(!doc.colorToolIsVisible(labelId: labelId))
                // Set visible again
                doc.colorToolSetVisibility(labelId: labelId, visible: true)
                #expect(doc.colorToolIsVisible(labelId: labelId))
            }
        }
    }

    @Test("ColorByLayer defaults to false")
    func colorByLayer() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                #expect(!doc.colorToolIsColorByLayer(labelId: labelId))
                doc.colorToolSetColorByLayer(labelId: labelId, isByLayer: true)
                #expect(doc.colorToolIsColorByLayer(labelId: labelId))
            }
        }
    }
}
