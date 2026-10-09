import Foundation
import Testing

@testable import OCCTSwift

@Suite("TNaming Naming Tests")
struct TNamingNamingTests {

    @Test func insertNaming() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        let ok = doc.insertNaming(labelId: node.labelId)
        doc.commitTransaction()
        #expect(ok)
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
