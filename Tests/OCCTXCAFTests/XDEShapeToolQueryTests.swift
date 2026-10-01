import Foundation
import Testing

@testable import OCCTSwift

// MARK: - v0.60.0 XDE/XCAF Full Coverage Tests

// #766: these tests used to assert `labelId >= 0`, `shapeCount > 0` and `foundId >= 0` inside an
// `if let box = box`, so a document that lost the shape, a `findShape` that returned the wrong
// label, and a `searchShape` that behaved identically to `findShape` all passed. The values pinned
// below were measured against the kernel; see
// `Scripts/repro/766-xcaf-weak-assertions/probe-output.txt`.

@Suite("XDE ShapeTool Queries")
struct XDEShapeToolQueryTests {
    @Test("AddShape raises both counts by exactly one and returns the new label")
    func addShapeAndCount() throws {
        let doc = try #require(Document.create())
        #expect(doc.shapeCount == 0)
        #expect(doc.freeShapeCount == 0)

        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let labelId = doc.addShape(box)
        #expect(labelId == 0, "the first shape added to a fresh document takes label 0")
        #expect(doc.shapeCount == 1)
        #expect(doc.freeShapeCount == 1)
        // The label the call returned is the label the document now holds the shape under.
        #expect(doc.findShape(box) == labelId)
    }

    @Test("Adding one top-level shape leaves exactly one free shape")
    func freeShapeCount() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        doc.addShape(box)
        #expect(doc.freeShapeCount == 1)

        // A second independent top-level shape is a second free shape, so a `freeShapeCount` stuck
        // at the value 1 fails here rather than reading as correct.
        let sphere = try #require(Shape.sphere(radius: 5))
        doc.addShape(sphere)
        #expect(doc.freeShapeCount == 2)
        #expect(doc.shapeCount == 2)
    }

    /// `FindShape` looks only at the top-level shape labels; `SearchShape` descends into
    /// sub-shapes.
    ///
    /// Measured on a box added to a fresh document: `findShape(aFace)` is -1 while
    /// `searchShape(aFace)` resolves to a sub-shape label. A `searchShape` wired to `FindShape`
    /// (or the reverse) was invisible to the old `>= 0` assertions.
    @Test("FindShape is top-level only, SearchShape descends into sub-shapes")
    func findAndSearch() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let addedId = doc.addShape(box)

        #expect(doc.findShape(box) == addedId)
        #expect(doc.searchShape(box) == addedId)

        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        let face = try #require(faces.first)
        #expect(doc.findShape(face) == -1, "a face is not a top-level shape label")
        let searched = doc.searchShape(face)
        #expect(searched != -1, "SearchShape descends, so it resolves the face")
        #expect(searched != addedId, "and it resolves it to its own sub-shape label")

        // A shape the document never saw is refused by both.
        let stranger = try #require(Shape.sphere(radius: 3))
        #expect(doc.findShape(stranger) == -1)
        #expect(doc.searchShape(stranger) == -1)
    }

    @Test("RemoveShape takes the shape out of the document, not just reports success")
    func newAndRemove() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let labelId = doc.addShape(box)
        #expect(doc.shapeCount == 1)

        #expect(doc.removeShape(labelId: labelId))
        // The counts and the lookup are what prove the removal happened; the Bool alone does not.
        #expect(doc.shapeCount == 0)
        #expect(doc.freeShapeCount == 0)
        #expect(doc.findShape(box) == -1)
    }

    @Test("IsTopLevel, IsComponent, IsCompound on node")
    func labelQueries() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let labelId = doc.addShape(box)
        let roots = doc.rootNodes
        #expect(roots.count == 1)
        let root = try #require(roots.first)
        #expect(root.labelId == labelId)
        #expect(root.isTopLevel)
        #expect(!root.isComponent)
        #expect(!root.isAssembly, "a single solid added on its own is not an assembly")
    }
}
