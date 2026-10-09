import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDF ComparisonTool Tests")
struct TDFComparisonToolTests {

    @Test func isSelfContained() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        if let node = doc.createLabel() {
            node.setInteger(1)
            doc.commitTransaction()
            let result = doc.isSelfContained(labelId: node.labelId)
            #expect(result == true)
        }
    }
}
