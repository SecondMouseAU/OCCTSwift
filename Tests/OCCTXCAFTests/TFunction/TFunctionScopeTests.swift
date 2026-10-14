import Foundation
import Testing

@testable import OCCTSwift

@Suite("TFunction Scope Tests")
struct TFunctionScopeTests {

    @Test func setFunctionScope() throws {
        let doc = try #require(Document.create())
        doc.openTransaction()
        let ok = doc.setFunctionScope()
        let node = try #require(doc.createLabel())
        // The scope starts out empty.
        let hasBefore = doc.functionScopeHas(labelId: node.labelId)
        doc.commitTransaction()
        #expect(ok)
        #expect(!hasBefore)
    }

    @Test func addAndHasFunction() throws {
        let doc = try #require(Document.create())
        doc.openTransaction()
        doc.setFunctionScope()
        let node = try #require(doc.createLabel())
        let added = doc.functionScopeAdd(labelId: node.labelId)
        #expect(added)
        #expect(doc.functionScopeHas(labelId: node.labelId))
        doc.commitTransaction()
    }

    @Test func removeFunction() throws {
        let doc = try #require(Document.create())
        doc.openTransaction()
        doc.setFunctionScope()
        let node = try #require(doc.createLabel())
        doc.functionScopeAdd(labelId: node.labelId)
        let removed = doc.functionScopeRemove(labelId: node.labelId)
        #expect(removed)
        #expect(!doc.functionScopeHas(labelId: node.labelId))
        doc.commitTransaction()
    }

    @Test func removeAllFunctions() throws {
        let doc = try #require(Document.create())
        doc.openTransaction()
        doc.setFunctionScope()
        let l1 = try #require(doc.createLabel())
        let l2 = try #require(doc.createLabel())
        doc.functionScopeAdd(labelId: l1.labelId)
        doc.functionScopeAdd(labelId: l2.labelId)
        #expect(doc.functionScopeCount == 2)
        doc.functionScopeRemoveAll()
        #expect(doc.functionScopeCount == 0)
        doc.commitTransaction()
    }

    @Test func freeID() throws {
        let doc = try #require(Document.create())
        doc.openTransaction()
        doc.setFunctionScope()
        let freeId = doc.functionScopeFreeID
        #expect(freeId >= 1)
        let node = try #require(doc.createLabel())
        doc.functionScopeAdd(labelId: node.labelId)
        let freeId2 = doc.functionScopeFreeID
        #expect(freeId2 > freeId)
        doc.commitTransaction()
    }
}
