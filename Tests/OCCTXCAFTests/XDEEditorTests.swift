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
                // The result was discarded and `#expect(Bool(true))` could not fail (#766).
                // XCAFDoc_Editor::Expand turns the two-body compound into a two-component assembly.
                #expect(doc.editorExpand(labelId: labelId, recursively: false))
                #expect(doc.componentCount(assemblyLabelId: labelId) == 2)
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
            // The result was discarded and `#expect(Bool(true))` could not fail (#766). With
            // forceIfNotRoot the kernel rescales the free shape's label and reports it.
            #expect(doc.rescaleGeometry(labelId: labelId, scaleFactor: 2.0, forceIfNotRoot: true))
        }
    }
}
