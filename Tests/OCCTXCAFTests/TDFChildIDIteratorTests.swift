import Foundation
import Testing

@testable import OCCTSwift

// MARK: - v0.90.0 Tests

@Suite("TDF ChildIDIterator Tests")
struct TDFChildIDIteratorTests {

    @Test func countByGUID() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let parent = doc.createLabel() else { return }
        guard let c1 = doc.createLabel(parent: parent),
            let c2 = doc.createLabel(parent: parent),
            let c3 = doc.createLabel(parent: parent)
        else { return }
        // Set Name on 2 children, leave c3 without Name
        c1.setName("Child1")
        c2.setName("Child2")
        c3.setInteger(99)
        doc.commitTransaction()

        // TDataStd_Name GUID (OCCT 8.0.0-rc4)
        let nameGUID = "2a96b608-ec8b-11d0-bee7-080009dc3333"
        let count = doc.childIDCount(labelId: parent.labelId, guid: nameGUID)
        #expect(count == 2)
    }

    @Test func emptyResult() {
        guard let doc = Document.create() else { return }
        guard let parent = doc.createLabel() else { return }
        let count = doc.childIDCount(
            labelId: parent.labelId, guid: "99999999-9999-9999-9999-999999999999")
        #expect(count == 0)
    }
}
