import Foundation
import Testing

@testable import OCCTSwift

@Suite("Document Tests")
struct DocumentTests {

    @Test("Create empty document")
    func createEmptyDocument() throws {
        let doc = try #require(Document.create())
        #expect(doc.rootNodes.isEmpty)
        #expect(doc.shapeCount == 0)
        #expect(doc.freeShapeCount == 0)
        #expect(doc.allShapes().isEmpty)
        #expect(doc.lengthUnit == nil)
    }

    // Note: Loading tests require test STEP files with assemblies
    // These would be added with actual test fixtures

    // #817: Document.lengthUnit (XCAFDoc_LengthUnit) is wrapped and documented but had zero
    // test coverage anywhere in the suite before this. STEP carries an explicit unit in its
    // header, and STEPCAFControl_Reader records it on the document root via
    // XCAFDoc_LengthUnit::Set, so a round-tripped STEP document is real fixture, not a fabricated
    // one; the bridge exposes no setter (occtswift-wrapping-gaps.md's own read-only classes
    // pattern), so a STEP round-trip is the only way to produce a document with one set at all.
    @Test("Document.lengthUnit reads back the unit a round-tripped STEP document carries")
    func lengthUnitReadsBackFromSTEP() throws {
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else {
            Issue.record("box construction failed")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("issue817_lengthunit_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: url) }
        try box.writeSTEP(to: url)

        let doc = try Document.loadSTEP(from: url)
        let unit = try #require(doc.lengthUnit)
        // writeSTEP declares millimetres, which is 0.001 of a metre.
        #expect(unit.scale == 0.001)
        #expect(unit.name == "mm")
    }

    @Test("Document.lengthUnit is nil for a document with no length unit attribute")
    func lengthUnitNilOnFreshDocument() {
        guard let doc = Document.create() else {
            Issue.record("Document.create failed")
            return
        }
        #expect(doc.lengthUnit == nil)
    }
}
