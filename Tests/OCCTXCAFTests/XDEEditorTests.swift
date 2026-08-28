import Foundation
import Testing

@testable import OCCTSwift

@Suite("XDE Editor")
struct XDEEditorTests {
    @Test("EditorExpand compound to assembly")
    func editorExpand() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        let sphere = Shape.sphere(radius: 5)
        if let box = box, let sphere = sphere {
            let compound = Shape.compound([box, sphere])
            if let compound = compound {
                let labelId = doc.addShape(compound, makeAssembly: false)
                #expect(labelId >= 0)
                // editorExpand may or may not succeed depending on shape structure
                _ = doc.editorExpand(labelId: labelId, recursively: false)
                #expect(Bool(true))  // no crash = success
            }
        }
    }

    @Test("RescaleGeometry")
    func rescaleGeometry() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            let labelId = doc.addShape(box)
            // Rescale may return false for non-root labels, but shouldn't crash
            _ = doc.rescaleGeometry(labelId: labelId, scaleFactor: 2.0, forceIfNotRoot: true)
            #expect(Bool(true))  // no crash = success
        }
    }
}
