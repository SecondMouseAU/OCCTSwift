import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDF AttributeIterator Tests")
struct TDFAttributeIteratorTests {

    @Test func attributeCount() throws {
        let doc = try #require(Document.create())
        doc.openTransaction()
        let node = try #require(doc.createLabel())
        #expect(doc.attributeCount(labelId: node.labelId) == 0)
        node.setInteger(42)
        #expect(doc.attributeCount(labelId: node.labelId) == 1)
        node.setReal(3.14)
        #expect(doc.attributeCount(labelId: node.labelId) == 2)
        node.setName("Test")
        doc.commitTransaction()

        // One attribute per setter, so exactly three.
        #expect(doc.attributeCount(labelId: node.labelId) == 3)
    }

    @Test func emptyLabel() throws {
        let doc = try #require(Document.create())
        let node = try #require(doc.createLabel())
        #expect(doc.attributeCount(labelId: node.labelId) == 0)
        // And the count moves when an attribute arrives, so the zero is a measurement.
        node.setInteger(1)
        #expect(doc.attributeCount(labelId: node.labelId) == 1)
    }

    @Test func dataSetIsEmpty() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        let empty = doc.dataSetIsEmpty(labelId: node.labelId)
        #expect(!empty)
    }
}
