import Foundation
import Testing

@testable import OCCTSwift

@Suite("ChildNodeIterator Tests")
struct ChildNodeIteratorTests {

    @Test func noTreeNode() throws {
        let doc = try #require(Document.create())
        // No tree node set, count should be 0
        #expect(doc.childNodeCount(tag: 400) == 0)
    }
}
