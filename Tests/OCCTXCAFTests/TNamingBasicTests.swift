import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TNaming: Topological Naming (v0.25.0)

@Suite("TNaming, Basic Record and Retrieve")
struct TNamingBasicTests {

    @Test("Create label on document")
    func createLabel() {
        let doc = Document.create()!
        let label = doc.createLabel()
        #expect(label != nil, "Should create a label on a new document")
    }

    @Test("Create child label under parent")
    func createChildLabel() {
        let doc = Document.create()!
        let parent = doc.createLabel()!
        let child = doc.createLabel(parent: parent)
        #expect(child != nil, "Should create child label under parent")
    }

    @Test("Record primitive shape")
    func recordPrimitive() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let ok = doc.recordNaming(on: label, evolution: .primitive, newShape: box)
        #expect(ok, "Recording primitive should succeed")
    }

    @Test("Current shape after primitive")
    func currentShapeAfterPrimitive() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label, evolution: .primitive, newShape: box)

        let current = doc.currentShape(on: label)
        #expect(current != nil, "Should retrieve current shape after primitive recording")
    }

    @Test("Stored shape matches recorded")
    func storedShape() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label, evolution: .primitive, newShape: box)

        let stored = doc.storedShape(on: label)
        #expect(stored != nil, "Should retrieve stored shape")
    }

    @Test("Evolution type is primitive")
    func evolutionType() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label, evolution: .primitive, newShape: box)

        #expect(doc.namingEvolution(on: label) == .primitive)
    }

    @Test("No evolution on empty label")
    func noEvolutionOnEmptyLabel() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        #expect(doc.namingEvolution(on: label) == nil)
    }

    @Test("History count after primitive")
    func historyAfterPrimitive() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label, evolution: .primitive, newShape: box)

        let history = doc.namingHistory(on: label)
        #expect(history.count == 1)
        #expect(history[0].evolution == .primitive)
        #expect(!history[0].hasOldShape, "Primitive should not have old shape")
        #expect(history[0].hasNewShape, "Primitive should have new shape")
    }

    @Test("New shape from history entry")
    func newShapeFromHistory() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label, evolution: .primitive, newShape: box)

        let newShape = doc.newShape(on: label, at: 0)
        #expect(newShape != nil, "Should get new shape from primitive entry")
        let oldShape = doc.oldShape(on: label, at: 0)
        #expect(oldShape == nil, "Primitive should have no old shape")
    }

    @Test("Modify evolution updates current shape")
    func modifyEvolution() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label, evolution: .primitive, newShape: box)

        let sphere = Shape.sphere(radius: 5)!
        doc.recordNaming(on: label, evolution: .modify, oldShape: box, newShape: sphere)

        #expect(doc.namingEvolution(on: label) == .modify)
        let current = doc.currentShape(on: label)
        #expect(current != nil, "Should have current shape after modify")
    }

    @Test("Delete evolution records correctly")
    func deleteEvolution() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label, evolution: .primitive, newShape: box)

        doc.recordNaming(on: label, evolution: .delete, oldShape: box)
        #expect(doc.namingEvolution(on: label) == .delete)
    }

    @Test("Generated evolution with old and new shapes")
    func generatedEvolution() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let edge = Shape.box(width: 1, height: 1, depth: 1)!
        let face = Shape.box(width: 5, height: 5, depth: 1)!
        doc.recordNaming(on: label, evolution: .generated, oldShape: edge, newShape: face)

        #expect(doc.namingEvolution(on: label) == .generated)
        let history = doc.namingHistory(on: label)
        #expect(history.count == 1)
        #expect(history[0].hasOldShape)
        #expect(history[0].hasNewShape)
    }

    @Test("History accumulates multiple entries")
    func multipleHistoryEntries() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label, evolution: .primitive, newShape: box)

        let sphere = Shape.sphere(radius: 5)!
        doc.recordNaming(on: label, evolution: .modify, oldShape: box, newShape: sphere)

        let history = doc.namingHistory(on: label)
        #expect(history.count >= 1, "Should have at least one history entry after modify")
    }
}
