import Foundation
import Testing

@testable import OCCTSwift

@Suite("TFunction IFunction Tests")
struct TFunctionIFunctionTests {

    @Test func newFunction() throws {
        let doc = try #require(Document.create())
        doc.openTransaction()
        let node = try #require(doc.createLabel())
        #expect(doc.functionExecStatus(labelId: node.labelId) == nil)
        let ok = doc.newFunction(
            labelId: node.labelId, guid: "12345678-1234-1234-1234-123456789abc")
        doc.commitTransaction()
        #expect(ok)
        // A new function has not been executed, and its definition is not yet right.
        #expect(doc.functionExecStatus(labelId: node.labelId) == .wrongDefinition)
    }

    @Test func deleteFunction() throws {
        let doc = try #require(Document.create())
        doc.openTransaction()
        let node = try #require(doc.createLabel())
        #expect(
            doc.newFunction(labelId: node.labelId, guid: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"))
        #expect(doc.functionExecStatus(labelId: node.labelId) == .wrongDefinition)
        let deleted = doc.deleteFunction(labelId: node.labelId)
        #expect(deleted)
        // Gone: it has no status, and there is nothing left to delete.
        #expect(doc.functionExecStatus(labelId: node.labelId) == nil)
        #expect(!doc.deleteFunction(labelId: node.labelId))
        doc.commitTransaction()
    }

    @Test func functionExecStatus() throws {
        let doc = try #require(Document.create())
        doc.openTransaction()
        let node = try #require(doc.createLabel())
        doc.newFunction(labelId: node.labelId, guid: "11111111-2222-3333-4444-555555555555")

        let before = try #require(doc.functionExecStatus(labelId: node.labelId))
        #expect(before == .wrongDefinition)

        doc.setFunctionExecStatus(labelId: node.labelId, status: .succeeded)
        let after = try #require(doc.functionExecStatus(labelId: node.labelId))
        #expect(after == .succeeded)
        doc.commitTransaction()
    }

    @Test func noFunction() throws {
        let doc = try #require(Document.create())
        let node = try #require(doc.createLabel())
        let status = doc.functionExecStatus(labelId: node.labelId)
        #expect(status == nil)
    }
}
