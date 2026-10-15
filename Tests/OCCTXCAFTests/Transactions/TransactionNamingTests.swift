import Foundation
import Testing

@testable import OCCTSwift

/// #970: `openNamedTransaction(_:)` took a name and dropped it, and `transactionNumber` encoded
/// `HasOpenCommand()` as 1 or 0 instead of reading OCCT's own counter.
///
/// See `Scripts/repro/970-transaction-api/` for the measurements these pin.
@Suite("Transaction naming and numbering (#970)")
struct Issue970TransactionAPITests {

    /// The name reaches OCCT: it is recorded on the `TDF_Delta` the commit produces, which is
    /// where OCCT keeps a caller-supplied transaction name.
    ///
    /// Before #970 the delta came back
    /// unnamed however the transaction was opened.
    @Test func namedTransactionNamesTheCommittedDelta() throws {
        let doc = try #require(Document.create())
        doc.setUndoLimit(10)
        doc.openNamedTransaction("add part")
        let node = try #require(doc.createLabel())
        node.setInteger(42)
        let delta = try #require(doc.commitWithDelta())
        #expect(delta.name == "add part")
        #expect(delta.attributeDeltaCount >= 1)
    }

    /// The name belongs to one transaction.
    ///
    /// A later unnamed transaction is not given it.
    @Test func aPendingNameDoesNotReachTheNextTransaction() throws {
        let doc = try #require(Document.create())
        doc.setUndoLimit(10)
        doc.openNamedTransaction("first")
        let node1 = try #require(doc.createLabel())
        node1.setInteger(1)
        #expect(doc.commitTransaction())
        doc.openTransaction()
        let node2 = try #require(doc.createLabel())
        node2.setInteger(2)
        let delta = try #require(doc.commitWithDelta())
        #expect(delta.name == "")
    }

    /// An `openTransaction()` with no name of its own supersedes a name still pending.
    ///
    /// The second
    /// open is refused by OCCT because one is already running, so this is the same transaction
    /// committing without the name it was opened with.
    @Test func anUnnamedOpenSupersedesAPendingName() throws {
        let doc = try #require(Document.create())
        doc.setUndoLimit(10)
        doc.openNamedTransaction("first")
        doc.openTransaction()
        let node = try #require(doc.createLabel())
        node.setInteger(1)
        let delta = try #require(doc.commitWithDelta())
        #expect(delta.name == "")
    }

    /// A named open that OCCT refuses, because one is already running, reports 0 and leaves the
    /// running transaction's own name in place.
    @Test func aRefusedNamedOpenLeavesTheRunningNameAlone() throws {
        let doc = try #require(Document.create())
        doc.setUndoLimit(10)
        #expect(doc.openNamedTransaction("first") == 1)
        #expect(doc.openNamedTransaction("second") == 0)
        let node = try #require(doc.createLabel())
        node.setInteger(1)
        let delta = try #require(doc.commitWithDelta())
        #expect(delta.name == "first")
    }

    /// Aborting discards the name along with the transaction it belonged to.
    @Test func abortDiscardsThePendingName() throws {
        let doc = try #require(Document.create())
        doc.setUndoLimit(10)
        doc.openNamedTransaction("abandoned")
        let node1 = try #require(doc.createLabel())
        node1.setInteger(1)
        doc.abortTransaction()
        doc.openTransaction()
        let node2 = try #require(doc.createLabel())
        node2.setInteger(2)
        let delta = try #require(doc.commitWithDelta())
        #expect(delta.name == "")
    }

    /// Committing for a delta hands one back and leaves the caller's undo limit alone.
    ///
    /// Both were
    /// lost to a `SetUndoLimit(100)` that committed the transaction before the commit ran.
    @Test func commitWithDeltaReturnsADeltaAndKeepsTheUndoLimit() throws {
        let doc = try #require(Document.create())
        doc.setUndoLimit(10)
        doc.openTransaction()
        let node3 = try #require(doc.createLabel())
        node3.setInteger(3)
        _ = try #require(doc.commitWithDelta())
        #expect(doc.undoLimit == 10)
        #expect(doc.availableUndos == 1)
    }

    /// `transactionNumber` is the number of the open transaction, and 0 when none is open.
    @Test func transactionNumberTracksTheOpenTransaction() throws {
        let doc = try #require(Document.create())
        doc.setUndoLimit(10)
        #expect(doc.transactionNumber == 0)
        #expect(!doc.hasOpenTransaction)
        doc.openTransaction()
        #expect(doc.transactionNumber == 1)
        #expect(doc.hasOpenTransaction)
        doc.commitTransaction()
        #expect(doc.transactionNumber == 0)
        #expect(!doc.hasOpenTransaction)
    }

    /// A document holds at most one transaction, so opens do not stack and a single commit
    /// closes whatever is open.
    ///
    /// This is why the number is never greater than 1.
    @Test func repeatedOpensDoNotStack() throws {
        let doc = try #require(Document.create())
        doc.setUndoLimit(10)
        doc.openTransaction()
        doc.openTransaction()
        #expect(doc.transactionNumber == 1)
        doc.commitTransaction()
        #expect(doc.transactionNumber == 0)
    }

    /// Undo is disabled until `setUndoLimit(_:)` is called, and with it disabled nothing opens.
    @Test func withoutAnUndoLimitNothingOpens() throws {
        let doc = try #require(Document.create())
        #expect(doc.undoLimit == 0)
        doc.openTransaction()
        #expect(doc.transactionNumber == 0)
        #expect(!doc.hasOpenTransaction)
    }

    /// `openNamedTransaction` reports the number of the transaction it opened, and 0 when it
    /// opened none.
    ///
    /// The name is not retained in that case: there is no transaction to carry it.
    @Test func openNamedTransactionReportsTheNumberItOpened() throws {
        let doc = try #require(Document.create())
        #expect(doc.openNamedTransaction("no undo limit") == 0)
        doc.setUndoLimit(10)
        #expect(doc.openNamedTransaction("with undo limit") == 1)
        doc.abortTransaction()
        #expect(doc.transactionNumber == 0)
    }
}
