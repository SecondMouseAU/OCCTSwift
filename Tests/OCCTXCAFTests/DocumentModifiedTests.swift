import Foundation
import Testing

@testable import OCCTSwift

// MARK: - Document Modified Labels Tests (v0.54.0)

@Suite("Document Modified Labels")
struct DocumentModifiedTests {

    @Test("Set and check modified")
    func setAndCheckModified() {
        let doc = Document.create()!
        doc.setUndoLimit(10)

        doc.openTransaction()
        let label = doc.createLabel()!
        label.setName("Part1")
        doc.commitTransaction()

        doc.setModified(label)
        #expect(doc.isModified(label), "Label should be marked as modified")
    }

    @Test("Clear modified")
    func clearModified() {
        let doc = Document.create()!
        doc.setUndoLimit(10)

        doc.openTransaction()
        let label = doc.createLabel()!
        label.setName("Part1")
        doc.commitTransaction()

        doc.setModified(label)
        #expect(doc.isModified(label))

        doc.clearModified()
        #expect(!doc.isModified(label), "Label should not be modified after clear")
    }
}
