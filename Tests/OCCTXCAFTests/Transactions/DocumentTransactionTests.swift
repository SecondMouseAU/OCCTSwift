import Foundation
import Testing

@testable import OCCTSwift

// MARK: - Document Transaction Tests (v0.54.0)

@Suite("Document Transactions")
struct DocumentTransactionTests {

    @Test("Open and commit transaction")
    func openCommit() throws {
        let doc = try #require(Document.create())
        doc.setUndoLimit(10)

        #expect(!doc.hasOpenTransaction)
        doc.openTransaction()
        #expect(doc.hasOpenTransaction)

        let label = try #require(doc.createLabel())
        label.setName("InTransaction")

        let ok = doc.commitTransaction()
        #expect(ok, "Commit should succeed")
        #expect(!doc.hasOpenTransaction)
    }

    @Test("Open and abort transaction")
    func openAbort() throws {
        let doc = try #require(Document.create())
        doc.setUndoLimit(10)

        doc.openTransaction()
        #expect(doc.hasOpenTransaction)

        let label = try #require(doc.createLabel())
        label.setName("WillBeAborted")

        doc.abortTransaction()
        #expect(!doc.hasOpenTransaction)
    }

    @Test("Has open transaction")
    func hasOpenTransaction() throws {
        let doc = try #require(Document.create())
        doc.setUndoLimit(10)
        #expect(!doc.hasOpenTransaction, "No transaction initially")

        doc.openTransaction()
        #expect(doc.hasOpenTransaction, "Transaction should be open")

        doc.commitTransaction()
        #expect(!doc.hasOpenTransaction, "No transaction after commit")
    }
}
