import Foundation
import Testing

@testable import OCCTSwift

// MARK: - Document Main Label Tests (v0.54.0)

@Suite("Document Main Label")
struct DocumentMainLabelTests {

    @Test("Get main label")
    func getMainLabel() {
        let doc = Document.create()!
        let main = doc.mainLabel
        #expect(main != nil, "Should get main label")
        if let main = main {
            #expect(main.tag == 1, "Main label tag should be 1")
            #expect(main.depth == 1, "Main label depth should be 1")
            #expect(!main.isRoot, "Main label is not the root")
        }
    }
}
