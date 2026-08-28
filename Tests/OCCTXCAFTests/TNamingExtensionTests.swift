import Foundation
import Testing

@testable import OCCTSwift

// MARK: - v0.88.0: TNaming Extensions, IntPackedMap, NoteBook, UAttribute, ChildNodeIterator

@Suite("TNaming Extensions Tests")
struct TNamingExtensionTests {

    @Test func namingIsEmpty() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        // No naming recorded yet, should be empty
        #expect(doc.namingIsEmpty(on: node))
    }

    @Test func namingIsEmptyAfterRecord() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else { return }
        doc.recordNaming(on: node, evolution: .primitive, newShape: box)
        #expect(!doc.namingIsEmpty(on: node))
    }

    @Test func namingVersion() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else { return }
        doc.recordNaming(on: node, evolution: .primitive, newShape: box)
        #expect(doc.namingVersion(on: node) == 0)
        doc.setNamingVersion(on: node, version: 42)
        #expect(doc.namingVersion(on: node) == 42)
    }

    @Test func namingOriginalShape() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else { return }
        // Primitive has no old shape, original should be nil
        doc.recordNaming(on: node, evolution: .primitive, newShape: box)
        let original = doc.namingOriginalShape(on: node)
        #expect(original == nil)
    }

    @Test func namingOriginalShapeFromModify() {
        guard let doc = Document.create() else { return }
        guard let node1 = doc.createLabel() else { return }
        guard let node2 = doc.createLabel() else { return }
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else { return }
        guard let sphere = Shape.sphere(radius: 5) else { return }
        doc.recordNaming(on: node1, evolution: .primitive, newShape: box)
        doc.recordNaming(on: node2, evolution: .modify, oldShape: box, newShape: sphere)
        let original = doc.namingOriginalShape(on: node2)
        #expect(original != nil)
    }

    @Test func namingHasLabel() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else { return }
        doc.recordNaming(on: node, evolution: .primitive, newShape: box)
        #expect(doc.namingHasLabel(shape: box))
    }

    @Test func namingFindLabel() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else { return }
        doc.recordNaming(on: node, evolution: .primitive, newShape: box)
        let found = doc.namingFindLabel(shape: box)
        #expect(found != nil)
    }

    @Test func namingValidUntil() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else { return }
        doc.recordNaming(on: node, evolution: .primitive, newShape: box)
        let valid = doc.namingValidUntil(shape: box)
        #expect(valid >= 0)
    }

    @Test func sameShapeCount() {
        guard let doc = Document.create() else { return }
        guard let node1 = doc.createLabel() else { return }
        guard let node2 = doc.createLabel() else { return }
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else { return }
        doc.recordNaming(on: node1, evolution: .primitive, newShape: box)
        doc.recordNaming(on: node2, evolution: .primitive, newShape: box)
        let count = doc.sameShapeCount(shape: box)
        #expect(count >= 2)
    }

    @Test func sameShapeLabels() {
        guard let doc = Document.create() else { return }
        guard let node1 = doc.createLabel() else { return }
        guard let node2 = doc.createLabel() else { return }
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else { return }
        doc.recordNaming(on: node1, evolution: .primitive, newShape: box)
        doc.recordNaming(on: node2, evolution: .primitive, newShape: box)
        let labels = doc.sameShapeLabels(shape: box)
        #expect(labels.count >= 2)
    }
}
