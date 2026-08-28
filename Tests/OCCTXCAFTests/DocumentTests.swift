import Foundation
import Testing

@testable import OCCTSwift

@Suite("Document Tests")
struct DocumentTests {

    @Test("Create empty document")
    func createEmptyDocument() {
        let doc = Document.create()
        #expect(doc != nil)
        if let doc = doc {
            #expect(doc.rootNodes.isEmpty)
        }
    }

    // Note: Loading tests require test STEP files with assemblies
    // These would be added with actual test fixtures
}
