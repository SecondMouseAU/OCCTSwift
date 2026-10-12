import Foundation
import Testing

@testable import OCCTSwift

// MARK: - Document Modified Labels Tests (v0.54.0)

@Suite("Document Modified Labels")
struct DocumentModifiedTests {

    @Test("Set and check modified")
    func setAndCheckModified() throws {
        let doc = try #require(Document.create())
        doc.setUndoLimit(10)

        doc.openTransaction()
        let label = try #require(doc.createLabel())
        let other = try #require(doc.createLabel())
        label.setName("Part1")
        other.setName("Part2")
        doc.commitTransaction()

        #expect(!doc.isModified(label))
        doc.setModified(label)
        #expect(doc.isModified(label), "Label should be marked as modified")
        // Marking one label does not mark its neighbour.
        #expect(!doc.isModified(other))
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
