import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDimTolObjects_Tool Tests")
struct DimTolToolTests {
    @Test func emptyDocumentCounts() throws {
        let doc = try #require(Document.create())
        #expect(doc.dimTolToolDimensionCount == 0)
        #expect(doc.dimTolToolToleranceCount == 0)
    }
}
