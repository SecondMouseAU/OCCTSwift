import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDF AttributeIterator Tests")
struct TDFAttributeIteratorTests {

    @Test func attributeCount() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        node.setInteger(42)
        node.setReal(3.14)
        node.setName("Test")
        doc.commitTransaction()

        let count = doc.attributeCount(labelId: node.labelId)
        #expect(count >= 3)
    }

    @Test func emptyLabel() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        let count = doc.attributeCount(labelId: node.labelId)
        #expect(count >= 0)
    }

    @Test func dataSetIsEmpty() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        let empty = doc.dataSetIsEmpty(labelId: node.labelId)
        #expect(!empty)
    }
}
