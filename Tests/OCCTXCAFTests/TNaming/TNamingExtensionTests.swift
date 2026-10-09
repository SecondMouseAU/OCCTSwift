import Foundation
import Testing

@testable import OCCTSwift

// MARK: - v0.88.0: TNaming Extensions, IntPackedMap, NoteBook, UAttribute, ChildNodeIterator

// #766: `namingFindLabel`, `namingValidUntil`, `sameShapeCount` and `sameShapeLabels` were each
// asserted with `!= nil` or `>= n` behind a `guard let ... else { return }`. All four now pin the
// value and its refusal case, measured; see
// `Scripts/repro/766-xcaf-weak-assertions/probe-output.txt`.

@Suite("TNaming Extensions Tests")
struct TNamingExtensionTests {

    @Test func namingIsEmpty() throws {
        let doc = try #require(Document.create())
        let node = try #require(doc.createLabel())
        // No naming recorded yet, should be empty
        #expect(doc.namingIsEmpty(on: node))
    }

    @Test func namingIsEmptyAfterRecord() throws {
        let doc = try #require(Document.create())
        let node = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        #expect(doc.recordNaming(on: node, evolution: .primitive, newShape: box))
        #expect(!doc.namingIsEmpty(on: node))
    }

    @Test func namingVersion() throws {
        let doc = try #require(Document.create())
        let node = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        #expect(doc.recordNaming(on: node, evolution: .primitive, newShape: box))
        #expect(doc.namingVersion(on: node) == 0)
        doc.setNamingVersion(on: node, version: 42)
        #expect(doc.namingVersion(on: node) == 42)
    }

    @Test func namingOriginalShape() throws {
        let doc = try #require(Document.create())
        let node = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        // Primitive has no old shape, original should be nil
        #expect(doc.recordNaming(on: node, evolution: .primitive, newShape: box))
        #expect(doc.namingOriginalShape(on: node) == nil)
    }

    @Test func namingOriginalShapeFromModify() throws {
        let doc = try #require(Document.create())
        let node1 = try #require(doc.createLabel())
        let node2 = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let sphere = try #require(Shape.sphere(radius: 5))
        #expect(doc.recordNaming(on: node1, evolution: .primitive, newShape: box))
        #expect(doc.recordNaming(on: node2, evolution: .modify, oldShape: box, newShape: sphere))
        let original = try #require(doc.namingOriginalShape(on: node2))
        // The original of a modify is the OLD shape, which `!= nil` could not tell from the new.
        #expect(original.isSame(as: box))
        #expect(!original.isSame(as: sphere))
    }

    @Test func namingHasLabel() throws {
        let doc = try #require(Document.create())
        let node = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        #expect(doc.recordNaming(on: node, evolution: .primitive, newShape: box))
        #expect(doc.namingHasLabel(shape: box))
        let unseen = try #require(Shape.sphere(radius: 2))
        #expect(!doc.namingHasLabel(shape: unseen))
    }

    @Test func namingFindLabel() throws {
        let doc = try #require(Document.create())
        let node = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        #expect(doc.recordNaming(on: node, evolution: .primitive, newShape: box))
        let found = try #require(doc.namingFindLabel(shape: box))
        // The label it finds has to be the one the shape was recorded on.
        #expect(found.labelId == node.labelId)
        // A shape with no naming entry is refused, so a lookup that always answers with the
        // first label fails here.
        let unseen = try #require(Shape.sphere(radius: 2))
        #expect(doc.namingFindLabel(shape: unseen) == nil)
    }

    @Test func namingValidUntil() throws {
        let doc = try #require(Document.create())
        let node = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        #expect(doc.recordNaming(on: node, evolution: .primitive, newShape: box))
        // Measured: a shape recorded outside any committed transaction is valid until
        // transaction 0, and a shape the framework never saw answers -1.
        #expect(doc.namingValidUntil(shape: box) == 0)
        let unseen = try #require(Shape.sphere(radius: 2))
        #expect(doc.namingValidUntil(shape: unseen) == -1)
    }

    @Test func sameShapeCount() throws {
        let doc = try #require(Document.create())
        let node1 = try #require(doc.createLabel())
        let node2 = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let unseen = try #require(Shape.sphere(radius: 2))
        #expect(doc.sameShapeCount(shape: box) == 0)

        #expect(doc.recordNaming(on: node1, evolution: .primitive, newShape: box))
        #expect(doc.sameShapeCount(shape: box) == 1)
        #expect(doc.recordNaming(on: node2, evolution: .primitive, newShape: box))
        #expect(doc.sameShapeCount(shape: box) == 2)
        #expect(doc.sameShapeCount(shape: unseen) == 0)
    }

    /// Four TNaming lookups took the process down on a document with no naming.
    ///
    /// #766: `sameShapeCount`, `sameShapeLabels`, `namingFindLabel` and `namingValidUntil` all
    /// crashed when the document root carried no `TNaming_UsedShapes` attribute, which is the
    /// state of every document before the first `TNaming_Builder` runs. Two causes.
    /// `TNaming_SameShapeIterator`'s `TDF_Label` constructor leaves its raw `myNode` pointer
    /// uninitialised in that case (`TNaming_NamedShape.cxx:1358`) and `More()` reads it, which
    /// is an upstream defect. `TNaming_Tool::Label` and `TNaming_Tool::ValidUntil` guard the
    /// same case with an out-of-line `Standard_NoSuchObject_Raise_if`, which is compiled out of
    /// the kernel we link, so they dereference the null handle instead
    /// (`okf/policies/occt-validation-is-compiled-out.md`). No `catch (...)` saw either, and no
    /// test reached the state, because every existing test recorded naming first. All four
    /// bridge functions now take the `TNaming_Tool::HasLabel` guard.
    @Test func sameShapeQueriesOnADocumentWithNoNaming() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        #expect(doc.sameShapeCount(shape: box) == 0)
        #expect(doc.sameShapeLabels(shape: box).isEmpty)
        #expect(!doc.namingHasLabel(shape: box))
        #expect(doc.namingFindLabel(shape: box) == nil)
        #expect(doc.namingValidUntil(shape: box) == -1)
    }

    @Test func sameShapeLabels() throws {
        let doc = try #require(Document.create())
        let node1 = try #require(doc.createLabel())
        let node2 = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        #expect(doc.recordNaming(on: node1, evolution: .primitive, newShape: box))
        #expect(doc.recordNaming(on: node2, evolution: .primitive, newShape: box))

        let labels = doc.sameShapeLabels(shape: box).map(\.labelId)
        // The identities, not just the arity: `labels.count >= 2` passed for any two labels.
        #expect(labels.count == 2)
        #expect(Set(labels) == Set([node1.labelId, node2.labelId]))

        let unseen = try #require(Shape.sphere(radius: 2))
        #expect(doc.sameShapeLabels(shape: unseen).isEmpty)
    }
}
