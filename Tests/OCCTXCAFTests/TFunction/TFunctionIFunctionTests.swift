import Foundation
import Testing

@testable import OCCTSwift

@Suite("TFunction IFunction Tests")
struct TFunctionIFunctionTests {

    @Test func newFunction() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        let ok = doc.newFunction(
            labelId: node.labelId, guid: "12345678-1234-1234-1234-123456789abc")
        doc.commitTransaction()
        #expect(ok)
    }

    @Test func deleteFunction() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.newFunction(labelId: node.labelId, guid: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
        let deleted = doc.deleteFunction(labelId: node.labelId)
        doc.commitTransaction()
        #expect(deleted)
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
