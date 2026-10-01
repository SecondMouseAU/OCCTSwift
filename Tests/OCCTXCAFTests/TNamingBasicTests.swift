import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TNaming: Topological Naming (v0.25.0)

// #766: six of these tests pinned nothing but `!= nil` or a Bool, so a label created in the wrong
// place, a stored shape that was not the one recorded, and a history that silently held the wrong
// number of entries all passed. The values below were measured; see
// `Scripts/repro/766-xcaf-weak-assertions/probe-output.txt`.

@Suite("TNaming, Basic Record and Retrieve")
struct TNamingBasicTests {

    /// Volume of `Shape.box(width: 10, height: 10, depth: 10)`, measured.
    private static let box10Volume = 999.999_999_999_999_8
    /// Volume of `Shape.sphere(radius: 5)`, measured.
    private static let sphereR5Volume = 523.598_775_598_299

    @Test("Create label on document")
    func createLabel() throws {
        let doc = try #require(Document.create())
        let main = try #require(doc.mainLabel)
        let label = try #require(doc.createLabel())
        // Measured: `createLabel()` with no parent appends a child of the main label, so the new
        // label sits one level below main. `label != nil` said nothing about where it landed.
        #expect(label.father?.labelId == main.labelId)
        #expect(label.depth == main.depth + 1)
        #expect(!label.isNull)
        #expect(!label.isRoot)

        // A second call makes a distinct sibling rather than handing back the same label.
        let sibling = try #require(doc.createLabel())
        #expect(sibling.labelId != label.labelId)
        #expect(sibling.tag == label.tag + 1)
        #expect(sibling.father?.labelId == main.labelId)
    }

    @Test("Create child label under parent")
    func createChildLabel() throws {
        let doc = try #require(Document.create())
        let parent = try #require(doc.createLabel())
        let child = try #require(doc.createLabel(parent: parent))
        // The parent argument has to be honoured: a `createLabel(parent:)` that ignored it and
        // appended under main passed the old `child != nil`.
        #expect(child.father?.labelId == parent.labelId)
        #expect(child.depth == parent.depth + 1)
        #expect(child.tag == 1, "the first child of a label takes tag 1")

        let second = try #require(doc.createLabel(parent: parent))
        #expect(second.father?.labelId == parent.labelId)
        #expect(second.tag == 2)
    }

    @Test("Record primitive shape")
    func recordPrimitive() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(doc.namingIsEmpty(on: label))

        #expect(doc.recordNaming(on: label, evolution: .primitive, newShape: box))
        // The Bool alone does not say anything was written; these do.
        #expect(!doc.namingIsEmpty(on: label))
        #expect(doc.namingEvolution(on: label) == .primitive)
        #expect(try #require(doc.storedShape(on: label)).isSame(as: box))
    }

    @Test("Current shape after primitive")
    func currentShapeAfterPrimitive() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(doc.recordNaming(on: label, evolution: .primitive, newShape: box))

        let current = try #require(doc.currentShape(on: label))
        #expect(current.isSame(as: box))
        #expect(current.shapeType == .solid)
        let volume = try #require(current.volume)
        #expect(abs(volume - Self.box10Volume) < 1e-9)
    }

    @Test("Stored shape matches recorded")
    func storedShape() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(doc.recordNaming(on: label, evolution: .primitive, newShape: box))

        let stored = try #require(doc.storedShape(on: label))
        // "matches recorded" is the claim in the test's own name, and `stored != nil` never
        // checked it.
        #expect(stored.isSame(as: box))
        #expect(stored.shapeType == .solid)
        let volume = try #require(stored.volume)
        #expect(abs(volume - Self.box10Volume) < 1e-9)
    }

    @Test("Evolution type is primitive")
    func evolutionType() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(doc.recordNaming(on: label, evolution: .primitive, newShape: box))

        #expect(doc.namingEvolution(on: label) == .primitive)
    }

    @Test("No evolution on empty label")
    func noEvolutionOnEmptyLabel() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        #expect(doc.namingEvolution(on: label) == nil)
    }

    @Test("History count after primitive")
    func historyAfterPrimitive() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(doc.recordNaming(on: label, evolution: .primitive, newShape: box))

        let history = doc.namingHistory(on: label)
        #expect(history.count == 1)
        #expect(history[0].evolution == .primitive)
        #expect(!history[0].hasOldShape, "Primitive should not have old shape")
        #expect(history[0].hasNewShape, "Primitive should have new shape")
    }

    @Test("New shape from history entry")
    func newShapeFromHistory() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(doc.recordNaming(on: label, evolution: .primitive, newShape: box))

        let newShape = try #require(doc.newShape(on: label, at: 0))
        #expect(newShape.isSame(as: box))
        #expect(doc.oldShape(on: label, at: 0) == nil, "Primitive should have no old shape")
    }

    @Test("Modify evolution updates current shape")
    func modifyEvolution() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(doc.recordNaming(on: label, evolution: .primitive, newShape: box))

        let sphere = try #require(Shape.sphere(radius: 5))
        #expect(doc.recordNaming(on: label, evolution: .modify, oldShape: box, newShape: sphere))

        #expect(doc.namingEvolution(on: label) == .modify)
        let current = try #require(doc.currentShape(on: label))
        // "updates" is the claim: the current shape has to be the NEW one.
        #expect(current.isSame(as: sphere))
        #expect(!current.isSame(as: box))
        let volume = try #require(current.volume)
        #expect(abs(volume - Self.sphereR5Volume) < 1e-9)
    }

    @Test("Delete evolution records correctly")
    func deleteEvolution() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(doc.recordNaming(on: label, evolution: .primitive, newShape: box))

        #expect(doc.recordNaming(on: label, evolution: .delete, oldShape: box))
        #expect(doc.namingEvolution(on: label) == .delete)
    }

    @Test("Generated evolution with old and new shapes")
    func generatedEvolution() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let edge = try #require(Shape.box(width: 1, height: 1, depth: 1))
        let face = try #require(Shape.box(width: 5, height: 5, depth: 1))
        #expect(doc.recordNaming(on: label, evolution: .generated, oldShape: edge, newShape: face))

        #expect(doc.namingEvolution(on: label) == .generated)
        let history = doc.namingHistory(on: label)
        #expect(history.count == 1)
        #expect(history[0].hasOldShape)
        #expect(history[0].hasNewShape)
    }

    /// A second `recordNaming` on the same label REPLACES the first: the bridge opens a fresh
    /// `TNaming_Builder(label)` per call (`OCCTBridge_Document_Functions.mm`), and a builder
    /// rebuilds the label's single `TNaming_NamedShape` rather than appending to it.
    ///
    /// So the
    /// history holds one entry, the modify, not two. The test this replaces was called "History
    /// accumulates multiple entries" and asserted `history.count >= 1`, which is true of the
    /// behaviour its own name denied. Measured; see
    /// `Scripts/repro/766-xcaf-weak-assertions/probe-output.txt`.
    @Test("A second record on one label replaces the history rather than appending")
    func secondRecordReplacesHistory() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(doc.recordNaming(on: label, evolution: .primitive, newShape: box))
        #expect(doc.namingHistory(on: label).count == 1)

        let sphere = try #require(Shape.sphere(radius: 5))
        #expect(doc.recordNaming(on: label, evolution: .modify, oldShape: box, newShape: sphere))

        let history = doc.namingHistory(on: label)
        #expect(history.count == 1)
        #expect(history[0].evolution == .modify)
        #expect(history[0].hasOldShape)
        #expect(history[0].hasNewShape)
        #expect(try #require(doc.oldShape(on: label, at: 0)).isSame(as: box))
        #expect(try #require(doc.newShape(on: label, at: 0)).isSame(as: sphere))
    }
}
