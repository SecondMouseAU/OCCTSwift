import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDimTolObjects_Tool Tests")
struct DimTolToolTests {
    @Test func emptyDocumentCounts() {
        if let doc = Document.create() {
            #expect(doc.dimTolToolDimensionCount == 0)
            #expect(doc.dimTolToolToleranceCount == 0)
        }
    }
}
