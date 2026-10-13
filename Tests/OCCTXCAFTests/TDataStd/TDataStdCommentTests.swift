import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDataStd Comment Attribute")
struct TDataStdCommentTests {

    @Test("Set and get comment")
    func setGetComment() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let ok = label.setComment("my comment")
        #expect(ok)
        #expect(label.comment == "my comment")
    }
}
