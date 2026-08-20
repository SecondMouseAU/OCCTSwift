import Foundation
import Testing

@testable import OCCTSwift

/// #970: `openNamedTransaction(_:)` took a name and dropped it, and `transactionNumber` encoded
/// `HasOpenCommand()` as 1 or 0 instead of reading OCCT's own counter.
/// See `Scripts/repro/970-transaction-api/` for the measurements these pin.
@Suite("Transaction naming and numbering (#970)")
struct Issue970TransactionAPITests {

    /// The name reaches OCCT: it is recorded on the `TDF_Delta` the commit produces, which is
    /// where OCCT keeps a caller-supplied transaction name. Before #970 the delta came back
    /// unnamed however the transaction was opened.
    @Test func namedTransactionNamesTheCommittedDelta() {
        guard let doc = Document.create() else { return }
        doc.setUndoLimit(10)
        doc.openNamedTransaction("add part")
        if let node = doc.createLabel() { node.setInteger(42) }
        let delta = doc.commitWithDelta()
        #expect(delta != nil)
        if let delta {
            #expect(delta.name == "add part")
            #expect(delta.attributeDeltaCount >= 1)
        }
    }

    /// The name belongs to one transaction. A later unnamed transaction is not given it.
    @Test func aPendingNameDoesNotReachTheNextTransaction() {
        guard let doc = Document.create() else { return }
        doc.setUndoLimit(10)
        doc.openNamedTransaction("first")
        if let node = doc.createLabel() { node.setInteger(1) }
        #expect(doc.commitTransaction())
        doc.openTransaction()
        if let node = doc.createLabel() { node.setInteger(2) }
        let delta = doc.commitWithDelta()
        #expect(delta != nil)
        if let delta { #expect(delta.name == "") }
    }

    /// An `openTransaction()` with no name of its own supersedes a name still pending. The second
    /// open is refused by OCCT because one is already running, so this is the same transaction
    /// committing without the name it was opened with.
    @Test func anUnnamedOpenSupersedesAPendingName() {
        guard let doc = Document.create() else { return }
        doc.setUndoLimit(10)
        doc.openNamedTransaction("first")
        doc.openTransaction()
        if let node = doc.createLabel() { node.setInteger(1) }
        let delta = doc.commitWithDelta()
        #expect(delta != nil)
        if let delta { #expect(delta.name == "") }
    }

    /// A named open that OCCT refuses, because one is already running, reports 0 and leaves the
    /// running transaction's own name in place.
    @Test func aRefusedNamedOpenLeavesTheRunningNameAlone() {
        guard let doc = Document.create() else { return }
        doc.setUndoLimit(10)
        #expect(doc.openNamedTransaction("first") == 1)
        #expect(doc.openNamedTransaction("second") == 0)
        if let node = doc.createLabel() { node.setInteger(1) }
        let delta = doc.commitWithDelta()
        #expect(delta != nil)
        if let delta { #expect(delta.name == "first") }
    }

    /// Aborting discards the name along with the transaction it belonged to.
    @Test func abortDiscardsThePendingName() {
        guard let doc = Document.create() else { return }
        doc.setUndoLimit(10)
        doc.openNamedTransaction("abandoned")
        if let node = doc.createLabel() { node.setInteger(1) }
        doc.abortTransaction()
        doc.openTransaction()
        if let node = doc.createLabel() { node.setInteger(2) }
        let delta = doc.commitWithDelta()
        #expect(delta != nil)
        if let delta { #expect(delta.name == "") }
    }

    /// Committing for a delta hands one back and leaves the caller's undo limit alone. Both were
    /// lost to a `SetUndoLimit(100)` that committed the transaction before the commit ran.
    @Test func commitWithDeltaReturnsADeltaAndKeepsTheUndoLimit() {
        guard let doc = Document.create() else { return }
        doc.setUndoLimit(10)
        doc.openTransaction()
        if let node = doc.createLabel() { node.setInteger(3) }
        let delta = doc.commitWithDelta()
        #expect(delta != nil)
        #expect(doc.undoLimit == 10)
        #expect(doc.availableUndos == 1)
    }

    /// `transactionNumber` is the number of the open transaction, and 0 when none is open.
    @Test func transactionNumberTracksTheOpenTransaction() {
        guard let doc = Document.create() else { return }
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
    /// closes whatever is open. This is why the number is never greater than 1.
    @Test func repeatedOpensDoNotStack() {
        guard let doc = Document.create() else { return }
        doc.setUndoLimit(10)
        doc.openTransaction()
        doc.openTransaction()
        #expect(doc.transactionNumber == 1)
        doc.commitTransaction()
        #expect(doc.transactionNumber == 0)
    }

    /// Undo is disabled until `setUndoLimit(_:)` is called, and with it disabled nothing opens.
    @Test func withoutAnUndoLimitNothingOpens() {
        guard let doc = Document.create() else { return }
        #expect(doc.undoLimit == 0)
        doc.openTransaction()
        #expect(doc.transactionNumber == 0)
        #expect(!doc.hasOpenTransaction)
    }

    /// `openNamedTransaction` reports the number of the transaction it opened, and 0 when it
    /// opened none. The name is not retained in that case: there is no transaction to carry it.
    @Test func openNamedTransactionReportsTheNumberItOpened() {
        guard let doc = Document.create() else { return }
        #expect(doc.openNamedTransaction("no undo limit") == 0)
        doc.setUndoLimit(10)
        #expect(doc.openNamedTransaction("with undo limit") == 1)
        doc.abortTransaction()
        #expect(doc.transactionNumber == 0)
    }
}
