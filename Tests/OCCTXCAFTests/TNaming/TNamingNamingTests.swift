import Foundation
import Testing

@testable import OCCTSwift

@Suite("TNaming Naming Tests")
struct TNamingNamingTests {

    @Test func insertNaming() throws {
        let doc = try #require(Document.create())
        doc.openTransaction()
        let node = try #require(doc.createLabel())
        #expect(doc.attributeCount(labelId: node.labelId) == 0)
        let ok = doc.insertNaming(labelId: node.labelId)
        doc.commitTransaction()
        #expect(ok)
        // The naming attribute is on the label now.
        #expect(doc.attributeCount(labelId: node.labelId) == 1)
    }

    @Test func namingIsDefined() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.insertNaming(labelId: node.labelId)
        doc.commitTransaction()
        // Newly inserted naming is not yet defined (no Name() called)
        #expect(!doc.namingIsDefined(labelId: node.labelId))
    }
}
