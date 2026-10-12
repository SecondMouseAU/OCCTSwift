import Foundation
import Testing

@testable import OCCTSwift

// MARK: - v0.96.0 Tests

@Suite("XCAFDoc AssemblyItemRef Tests")
struct XCAFDocAssemblyItemRefTests {

    @Test func setAndGet() throws {
        let doc = try #require(Document.create())
        doc.openTransaction()
        let node = try #require(doc.createLabel())
        #expect(doc.assemblyItemRefPath(labelId: node.labelId) == nil)
        #expect(doc.setAssemblyItemRef(labelId: node.labelId, itemPath: "/0:1:1:1"))
        doc.commitTransaction()

        // The path reads back as the entry list, without the leading slash, and a plain
        // reference carries no sub-shape.
        #expect(doc.assemblyItemRefPath(labelId: node.labelId) == "0:1:1:1")
        #expect(!doc.assemblyItemRefHasExtra(labelId: node.labelId))
        #expect(doc.assemblyItemRefGetSubshape(labelId: node.labelId) == nil)
        // It points at a label that does not exist in this document.
        #expect(doc.assemblyItemRefIsOrphan(labelId: node.labelId))
    }

    @Test func subshapeIndex() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setAssemblyItemRef(labelId: node.labelId, itemPath: "/0:1:1:1")
        doc.assemblyItemRefSetSubshape(labelId: node.labelId, index: 3)
        doc.commitTransaction()
        #expect(doc.assemblyItemRefHasExtra(labelId: node.labelId))
        if let idx = doc.assemblyItemRefGetSubshape(labelId: node.labelId) {
            #expect(idx == 3)
        }
    }

    @Test func clearExtra() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setAssemblyItemRef(labelId: node.labelId, itemPath: "/0:1:1:1")
        doc.assemblyItemRefSetSubshape(labelId: node.labelId, index: 5)
        doc.assemblyItemRefClearExtra(labelId: node.labelId)
        doc.commitTransaction()
        #expect(!doc.assemblyItemRefHasExtra(labelId: node.labelId))
    }

    @Test func isOrphan() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setAssemblyItemRef(labelId: node.labelId, itemPath: "/99:99:99")
        doc.commitTransaction()
        #expect(doc.assemblyItemRefIsOrphan(labelId: node.labelId))
    }
}
