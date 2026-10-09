import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDoc_NoteComment Tests")
struct XCAFDocNoteCommentTests {
    @Test func setAndGet() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let label = doc.createLabel(parent: main) {
                #expect(
                    label.setNoteComment(
                        userName: "TestUser", timeStamp: "2026-03-14",
                        comment: "This is a comment"))
                #expect(label.noteCommentText == "This is a comment")
                #expect(label.noteUserName == "TestUser")
            }
        }
    }
}
