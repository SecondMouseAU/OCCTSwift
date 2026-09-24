import Foundation
import Testing

@testable import OCCTSwift

@Suite("TNaming, Select and Resolve")
struct TNamingSelectResolveTests {

    @Test("Select a shape within context")
    func selectSubShape() {
        let doc = Document.create()!
        let label1 = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label1, evolution: .primitive, newShape: box)

        // Use a face-shape as the selection within the box context
        let wire = Wire.rectangle(width: 10, height: 10)!
        let faceShape = Shape.face(from: wire)!

        let selectLabel = doc.createLabel()!
        let ok = doc.selectShape(faceShape, context: box, on: selectLabel)
        #expect(ok, "Should successfully select a shape within context")
    }

    @Test("Resolve returns a shape")
    func resolveShape() {
        let doc = Document.create()!
        let label1 = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label1, evolution: .primitive, newShape: box)

        // Select a real face of the recorded box and resolve it. The old version selected an
        // unrelated rectangle and asserted `Bool(true)` only when something came back, so it
        // passed whatever resolve returned, nil included (#766).
        guard let face = box.subShapes(ofType: .face).first else {
            Issue.record("box has no face")
            return
        }
        let selectLabel = doc.createLabel()!
        #expect(doc.selectShape(face, context: box, on: selectLabel))
        let resolved = doc.resolveShape(on: selectLabel)
        #expect(resolved != nil)
        #expect((resolved?.subShapes(ofType: .face).count ?? 0) >= 1)
    }

    @Test("Selected evolution type")
    func selectedEvolution() {
        let doc = Document.create()!
        let label1 = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label1, evolution: .primitive, newShape: box)

        let wire = Wire.rectangle(width: 10, height: 10)!
        let faceShape = Shape.face(from: wire)!

        let selectLabel = doc.createLabel()!
        doc.selectShape(faceShape, context: box, on: selectLabel)

        let evo = doc.namingEvolution(on: selectLabel)
        #expect(evo == .selected, "Selection label should have selected evolution")
    }
}
