import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDataXtd Placement Tests")
struct TDataXtdPlacementTests {

    @Test func setAndHas() throws {
        let doc = try #require(Document.create())
        doc.openTransaction()
        let node = try #require(doc.createLabel())
        doc.setPlacement(labelId: node.labelId)
        doc.commitTransaction()
        #expect(doc.hasPlacement(labelId: node.labelId))
    }

    @Test func noPlacement() throws {
        let doc = try #require(Document.create())
        let node = try #require(doc.createLabel())
        #expect(!doc.hasPlacement(labelId: node.labelId))
    }
}
