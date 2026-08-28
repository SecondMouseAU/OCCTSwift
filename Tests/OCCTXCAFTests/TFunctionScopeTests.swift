import Foundation
import Testing

@testable import OCCTSwift

@Suite("TFunction Scope Tests")
struct TFunctionScopeTests {

    @Test func setFunctionScope() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        let ok = doc.setFunctionScope()
        doc.commitTransaction()
        #expect(ok)
    }

    @Test func addAndHasFunction() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        doc.setFunctionScope()
        guard let node = doc.createLabel() else { return }
        let added = doc.functionScopeAdd(labelId: node.labelId)
        #expect(added)
        #expect(doc.functionScopeHas(labelId: node.labelId))
        doc.commitTransaction()
    }

    @Test func removeFunction() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        doc.setFunctionScope()
        guard let node = doc.createLabel() else { return }
        doc.functionScopeAdd(labelId: node.labelId)
        let removed = doc.functionScopeRemove(labelId: node.labelId)
        #expect(removed)
        #expect(!doc.functionScopeHas(labelId: node.labelId))
        doc.commitTransaction()
    }

    @Test func removeAllFunctions() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        doc.setFunctionScope()
        guard let l1 = doc.createLabel(), let l2 = doc.createLabel() else { return }
        doc.functionScopeAdd(labelId: l1.labelId)
        doc.functionScopeAdd(labelId: l2.labelId)
        #expect(doc.functionScopeCount == 2)
        doc.functionScopeRemoveAll()
        #expect(doc.functionScopeCount == 0)
        doc.commitTransaction()
    }

    @Test func freeID() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        doc.setFunctionScope()
        let freeId = doc.functionScopeFreeID
        #expect(freeId >= 1)
        guard let node = doc.createLabel() else { return }
        doc.functionScopeAdd(labelId: node.labelId)
        let freeId2 = doc.functionScopeFreeID
        #expect(freeId2 > freeId)
        doc.commitTransaction()
    }
}
