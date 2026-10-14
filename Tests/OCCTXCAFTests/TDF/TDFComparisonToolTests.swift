import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDF ComparisonTool Tests")
struct TDFComparisonToolTests {

    @Test func isSelfContained() throws {
        let doc = try #require(Document.create())
        doc.openTransaction()
        let node = try #require(doc.createLabel())
        node.setInteger(1)
        doc.commitTransaction()
        let result = doc.isSelfContained(labelId: node.labelId)
        #expect(result == true)
    }
}
