import Foundation
import Testing

@testable import OCCTSwift

// MARK: - Document Undo/Redo Tests (v0.54.0)

@Suite("Document Undo/Redo")
struct DocumentUndoRedoTests {

    @Test("Set and get undo limit")
    func undoLimit() {
        let doc = Document.create()!
        doc.setUndoLimit(10)
        #expect(doc.undoLimit == 10)
    }

    @Test("Available undos after commit")
    func availableUndos() {
        let doc = Document.create()!
        doc.setUndoLimit(10)
        #expect(doc.availableUndos == 0)
        #expect(doc.availableRedos == 0)

        doc.openTransaction()
        let label = doc.createLabel()!
        label.setName("T1")
        doc.commitTransaction()

        #expect(doc.availableUndos == 1)
    }

    @Test("Undo restores state")
    func undoRestores() {
        let doc = Document.create()!
        doc.setUndoLimit(10)

        doc.openTransaction()
        let label = doc.createLabel()!
        label.setName("Box")
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            doc.recordNaming(on: label, evolution: .primitive, newShape: box)
        }
        doc.commitTransaction()

        #expect(doc.availableUndos == 1)

        doc.openTransaction()
        let label2 = doc.createLabel()!
        label2.setName("Cylinder")
        doc.commitTransaction()

        #expect(doc.availableUndos == 2)

        // Undo
        let ok = doc.undo()
        #expect(ok, "Undo should succeed")
        #expect(doc.availableUndos == 1)
        #expect(doc.availableRedos == 1)
    }

    @Test("Redo after undo")
    func redoAfterUndo() {
        let doc = Document.create()!
        doc.setUndoLimit(10)

        doc.openTransaction()
        doc.createLabel()!.setName("T1")
        doc.commitTransaction()

        doc.openTransaction()
        doc.createLabel()!.setName("T2")
        doc.commitTransaction()

        #expect(doc.availableUndos == 2)

        doc.undo()
        #expect(doc.availableRedos == 1)

        let ok = doc.redo()
        #expect(ok, "Redo should succeed")
        #expect(doc.availableUndos == 2)
        #expect(doc.availableRedos == 0)
    }

    @Test("Undo with nothing returns false")
    func undoNothing() {
        let doc = Document.create()!
        doc.setUndoLimit(10)
        let result = doc.undo()
        #expect(!result, "Undo with nothing should return false")
    }

    @Test("Multiple undos and redos")
    func multipleUndoRedo() {
        let doc = Document.create()!
        doc.setUndoLimit(10)

        for i in 0..<3 {
            doc.openTransaction()
            doc.createLabel()!.setName("Label\(i)")
            doc.commitTransaction()
        }

        #expect(doc.availableUndos == 3)

        doc.undo()
        doc.undo()
        doc.undo()
        #expect(doc.availableUndos == 0)
        #expect(doc.availableRedos == 3)

        doc.redo()
        doc.redo()
        #expect(doc.availableUndos == 2)
        #expect(doc.availableRedos == 1)
    }

    @Test("Abort does not create undo")
    func abortNoUndo() {
        let doc = Document.create()!
        doc.setUndoLimit(10)

        doc.openTransaction()
        doc.createLabel()!.setName("T1")
        doc.commitTransaction()

        doc.openTransaction()
        doc.createLabel()!.setName("Aborted")
        doc.abortTransaction()

        #expect(doc.availableUndos == 1, "Aborted transaction should not create undo")
    }
}
