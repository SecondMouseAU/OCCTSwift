import Foundation
import Testing

@testable import OCCTSwift

// #766: every test here was `guard let doc = ... else { return }` wrapped around a `!= nil` or a
// `>= 1`, so a document that failed to build, an explorer that returned the wrong shape and a
// path ID that did not identify anything all read as a pass. The values below were measured; see
// `Scripts/repro/766-xcaf-weak-assertions/probe-output.txt`.

@Suite("XCAFPrs_DocumentExplorer Tests")
struct DocumentExplorerTests {

    /// Volume of `Shape.box(width: 10, height: 10, depth: 10)`, measured.
    private static let box10Volume = 999.999_999_999_999_8

    @Test func exploreDocumentWithShape() throws {
        let doc = try #require(Document.create())
        doc.defineAllFormats()
        #expect(doc.explorerNodeCount == 0, "nothing has been added yet")

        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        _ = doc.addShape(box)
        // One leaf shape, so exactly one node. `>= 1` passed for any number the walk produced.
        #expect(doc.explorerNodeCount == 1)

        let sphere = try #require(Shape.sphere(radius: 5))
        _ = doc.addShape(sphere)
        #expect(doc.explorerNodeCount == 2)
    }

    @Test func explorerShapeAtIndex() throws {
        let doc = try #require(Document.create())
        doc.defineAllFormats()
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        _ = doc.addShape(box)

        let shape = try #require(doc.explorerShape(at: 0))
        #expect(shape.isSame(as: box), "index 0 is the box that was added, not some other shape")
        #expect(shape.shapeType == .solid)
        let volume = try #require(shape.volume)
        #expect(abs(volume - Self.box10Volume) < 1e-9)
        // An index past the end is a refusal, not a silently reused node.
        #expect(doc.explorerShape(at: 1) == nil)
    }

    @Test func explorerPathId() throws {
        let doc = try #require(Document.create())
        doc.defineAllFormats()
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        _ = doc.addShape(box)

        // Measured: the single free shape of a fresh document sits at label 0:1:1:1, and
        // XCAFPrs renders the path with a trailing separator.
        #expect(doc.explorerPathId(at: 0) == "0:1:1:1.")
        #expect(doc.explorerPathId(at: 1) == nil)
    }

    @Test func findShapeFromPathId() throws {
        let doc = try #require(Document.create())
        doc.defineAllFormats()
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        _ = doc.addShape(box)

        let pathId = try #require(doc.explorerPathId(at: 0))
        let found = try #require(doc.explorerFindShape(pathId: pathId))
        // The round trip has to land back on the same shape, which `found != nil` never checked.
        #expect(found.isSame(as: box))
        let volume = try #require(found.volume)
        #expect(abs(volume - Self.box10Volume) < 1e-9)

        // A path that names nothing in this document is refused rather than answered with the
        // first node, which is what a lookup that ignores its argument would do.
        #expect(doc.explorerFindShape(pathId: "0:9:9:9") == nil)
    }
}
