import Foundation
import Testing

@testable import OCCTSwift

// MARK: - v0.96.0 Tests

@Suite("XCAFDoc AssemblyItemRef Tests")
struct XCAFDocAssemblyItemRefTests {

    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setAssemblyItemRef(labelId: node.labelId, itemPath: "/0:1:1:1")
        doc.commitTransaction()
        let path = doc.assemblyItemRefPath(labelId: node.labelId)
        #expect(path != nil)
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
