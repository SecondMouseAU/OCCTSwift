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

    @Test func functionExecStatus() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.newFunction(labelId: node.labelId, guid: "11111111-2222-3333-4444-555555555555")

        if let status = doc.functionExecStatus(labelId: node.labelId) {
            #expect(status == .wrongDefinition)
        }

        doc.setFunctionExecStatus(labelId: node.labelId, status: .succeeded)
        if let status = doc.functionExecStatus(labelId: node.labelId) {
            #expect(status == .succeeded)
        }
        doc.commitTransaction()
    }

    @Test func noFunction() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        let status = doc.functionExecStatus(labelId: node.labelId)
        #expect(status == nil)
    }
}
