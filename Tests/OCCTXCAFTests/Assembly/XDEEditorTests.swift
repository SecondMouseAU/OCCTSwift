import Foundation
import Testing

@testable import OCCTSwift

// #766: both tests discarded the result of the operation under test with `_ =` and finished with
// `#expect(Bool(true))  // no crash = success`, so each was a crash check and nothing else.
// Measured, both operations have a specific, checkable effect; see
// `Scripts/repro/766-xcaf-weak-assertions/probe-output.txt`.

@Suite("XDE Editor")
struct XDEEditorTests {
    @Test("EditorExpand turns a compound label into a two-child assembly")
    func editorExpand() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let sphere = try #require(Shape.sphere(radius: 5))
        let compound = try #require(Shape.compound([box, sphere]))

        let labelId = doc.addShape(compound, makeAssembly: false)
        #expect(labelId == 0)
        #expect(doc.shapeCount == 1)
        let before = try #require(doc.node(at: labelId))
        #expect(!before.isAssembly)
        #expect(before.children.isEmpty)

        #expect(doc.editorExpand(labelId: labelId, recursively: false))

        let after = try #require(doc.node(at: labelId))
        #expect(after.isAssembly, "expansion is what makes the compound an assembly")
        #expect(after.children.count == 2, "one child per member of the compound")
        // The two members, by volume: box 10 x 20 x 30, sphere r = 5.
        // Through `first`/`last`, not by index: `#expect` does not short-circuit, so an
        // empty array here would be a fatal subscript rather than a reported failure.
        let volumes = after.children.compactMap { $0.shape?.volume }.sorted()
        #expect(volumes.count == 2)
        #expect(abs(try #require(volumes.first) - 523.598_775_598_299) < 1e-9)
        #expect(abs(try #require(volumes.last) - 6000.0) < 1e-9)
        #expect(doc.shapeCount == 3, "the compound plus its two members")
        #expect(doc.freeShapeCount == 1, "the members are components, not free shapes")

        // Already expanded: OCCT refuses the second call, so a wrapper that always returns true
        // fails here.
        #expect(!doc.editorExpand(labelId: labelId, recursively: false))
    }

    @Test("EditorExpand refuses a label that is not an expandable compound")
    func editorExpandRefusals() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 1, height: 1, depth: 1))
        let labelId = doc.addShape(box, makeAssembly: false)
        #expect(
            !doc.editorExpand(labelId: labelId, recursively: false),
            "a solid has nothing to expand")
        #expect(!doc.editorExpand(labelId: 9999, recursively: false), "no such label")
    }

    @Test("RescaleGeometry scales the stored shape by the factor cubed in volume")
    func rescaleGeometry() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let labelId = doc.addShape(box)
        let before = try #require(doc.node(at: labelId)?.shape?.volume)
        #expect(abs(before - 6000.0) < 1e-9)

        #expect(doc.rescaleGeometry(labelId: labelId, scaleFactor: 2.0, forceIfNotRoot: true))
        let scaled = try #require(doc.node(at: labelId)?.shape?.volume)
        // 2^3 x 6000. The old test discarded this result entirely.
        #expect(abs(scaled - 48000.0) < 1e-6)

        #expect(doc.rescaleGeometry(labelId: labelId, scaleFactor: 0.5, forceIfNotRoot: true))
        let restored = try #require(doc.node(at: labelId)?.shape?.volume)
        #expect(abs(restored - 6000.0) < 1e-6)
    }

    @Test("RescaleGeometry refuses a zero factor and an unknown label")
    func rescaleGeometryRefusals() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let labelId = doc.addShape(box)

        #expect(!doc.rescaleGeometry(labelId: labelId, scaleFactor: 0.0, forceIfNotRoot: true))
        // A refusal has to leave the shape alone, which no assertion in the old test checked.
        let unchanged = try #require(doc.node(at: labelId)?.shape?.volume)
        #expect(abs(unchanged - 6000.0) < 1e-9)

        #expect(!doc.rescaleGeometry(labelId: 9999, scaleFactor: 2.0, forceIfNotRoot: true))
    }
}
