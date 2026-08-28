import Foundation
import Testing

@testable import OCCTSwift

@Suite("ChildNodeIterator Tests")
struct ChildNodeIteratorTests {

    @Test func noTreeNode() {
        guard let doc = Document.create() else { return }
        // No tree node set, count should be 0
        #expect(doc.childNodeCount(tag: 400) == 0)
    }
}
