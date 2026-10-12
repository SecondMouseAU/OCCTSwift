import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TFunction Logbook Tests (v0.56.0)

@Suite("TFunction Logbook")
struct TFunctionLogbookTests {

    @Test("Create logbook and mark labels")
    func logbookBasic() {
        let doc = Document.create()!
        let logLabel = doc.createLabel()!
        let target1 = doc.createLabel()!
        let target2 = doc.createLabel()!

        #expect(logLabel.setLogbook())
        #expect(logLabel.logbookIsEmpty)

        #expect(logLabel.logbookSetTouched(target1))
        #expect(!logLabel.logbookIsEmpty)
        #expect(logLabel.logbookIsModified(target1))
        #expect(!logLabel.logbookIsModified(target2))
    }

    @Test("Logbook impacted and clear")
    func logbookImpactedAndClear() throws {
        let doc = try #require(Document.create())
        let logLabel = try #require(doc.createLabel())
        let target = try #require(doc.createLabel())

        #expect(logLabel.setLogbook())
        #expect(logLabel.logbookIsEmpty)
        #expect(!logLabel.logbookIsModified(target))
        #expect(logLabel.logbookSetImpacted(target))
        // An impacted label is on the logbook and counts as modified.
        #expect(!logLabel.logbookIsEmpty)
        #expect(logLabel.logbookIsModified(target))

        #expect(logLabel.logbookClear())
        #expect(logLabel.logbookIsEmpty)
        #expect(!logLabel.logbookIsModified(target))
    }
}
