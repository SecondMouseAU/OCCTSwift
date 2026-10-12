import Foundation
import Testing

@testable import OCCTSwift

// MARK: - v0.89.0 Tests

@Suite("TDF Transaction Named Tests")
struct TDFTransactionNamedTests {

    @Test func openNamedTransaction() throws {
        let doc = try #require(Document.create())
        doc.setUndoLimit(10)
        #expect(doc.transactionNumber == 0)
        let txnNum = doc.openNamedTransaction("TestTxn")
        // The first transaction on a document is number 1, and it is the one that is open.
        #expect(txnNum == 1)
        #expect(doc.transactionNumber == 1)
        doc.commitTransaction()
        #expect(doc.transactionNumber == 0)
    }

    @Test func transactionNumber() {
        guard let doc = Document.create() else { return }
        doc.setUndoLimit(10)
        let before = doc.transactionNumber
        #expect(before == 0)
        doc.openNamedTransaction("CountTxn")
        let during = doc.transactionNumber
        #expect(during == 1)
        doc.commitTransaction()
        let after = doc.transactionNumber
        #expect(after == 0)
    }

    @Test func commitWithDelta() throws {
        let doc = try #require(Document.create())
        doc.setUndoLimit(10)
        doc.openTransaction()
        let node = try #require(doc.createLabel())
        node.setInteger(42)
        let delta = try #require(doc.commitWithDelta())
        #expect(!delta.isEmpty)
        // Measured on the pinned kernel: one attribute set on a new label is two attribute
        // deltas, and the transaction ran from time 0 to 1.
        #expect(delta.attributeDeltaCount == 2)
        #expect(delta.beginTime == 0)
        #expect(delta.endTime == 1)

        // The count follows the work done: three attributes on another new label is four.
        doc.openTransaction()
        let other = try #require(doc.createLabel())
        other.setInteger(1)
        other.setReal(2.0)
        other.setName("x")
        let second = try #require(doc.commitWithDelta())
        #expect(second.attributeDeltaCount == 4)
    }

    @Test func deltaName() {
        guard let doc = Document.create() else { return }
        doc.setUndoLimit(10)
        doc.openTransaction()
        if let node = doc.createLabel() {
            node.setInteger(99)
        }
        let delta = doc.commitWithDelta()
        #expect(delta != nil)
        if let delta {
            delta.setName("MyDelta")
            #expect(delta.name == "MyDelta")
        }
    }
}
