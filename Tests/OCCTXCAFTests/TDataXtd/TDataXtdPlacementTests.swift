import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDataXtd Placement Tests")
struct TDataXtdPlacementTests {

    @Test func setAndHas() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setPlacement(labelId: node.labelId)
        doc.commitTransaction()
        #expect(doc.hasPlacement(labelId: node.labelId))
    }

    @Test func noPlacement() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        #expect(!doc.hasPlacement(labelId: node.labelId))
    }
}
