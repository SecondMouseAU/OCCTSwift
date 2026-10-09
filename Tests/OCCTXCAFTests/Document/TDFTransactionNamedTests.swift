import Foundation
import Testing

@testable import OCCTSwift

// MARK: - v0.89.0 Tests

@Suite("TDF Transaction Named Tests")
struct TDFTransactionNamedTests {

    @Test func openNamedTransaction() {
        guard let doc = Document.create() else { return }
        doc.setUndoLimit(10)
        let txnNum = doc.openNamedTransaction("TestTxn")
        #expect(txnNum >= 1)
        doc.commitTransaction()
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

    @Test func commitWithDelta() {
        guard let doc = Document.create() else { return }
        doc.setUndoLimit(10)
        doc.openTransaction()
        if let node = doc.createLabel() {
            node.setInteger(42)
        }
        let delta = doc.commitWithDelta()
        #expect(delta != nil)
        if let delta {
            #expect(!delta.isEmpty)
            #expect(delta.attributeDeltaCount >= 1)
            #expect(delta.beginTime >= 0)
            #expect(delta.endTime >= delta.beginTime)
        }
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
