import Testing

@testable import OCCTSwift

@Suite("NoteBook Tests")
struct NoteBookTests {

    @Test func createNoteBook() {
        guard let doc = Document.create() else { return }
        #expect(doc.setNoteBook(tag: 200))
        #expect(doc.noteBookExists(tag: 200))
    }

    @Test func appendReal() throws {
        let doc = try #require(Document.create())
        #expect(doc.setNoteBook(tag: 201))
        // Entries are appended under successive tags, starting at 1.
        #expect(doc.noteBookAppendReal(tag: 201, value: 3.14) == 1)
        #expect(doc.noteBookAppendReal(tag: 201, value: 2.71) == 2)
    }

    @Test func appendInteger() throws {
        let doc = try #require(Document.create())
        #expect(doc.setNoteBook(tag: 202))
        #expect(doc.noteBookAppendInteger(tag: 202, value: 42) == 1)
        #expect(doc.noteBookAppendInteger(tag: 202, value: 43) == 2)
    }

    @Test func multipleAppends() {
        guard let doc = Document.create() else { return }
        doc.setNoteBook(tag: 203)
        let r1 = doc.noteBookAppendReal(tag: 203, value: 1.0)
        let r2 = doc.noteBookAppendReal(tag: 203, value: 2.0)
        let i1 = doc.noteBookAppendInteger(tag: 203, value: 10)
        #expect(r1 != nil)
        #expect(r2 != nil)
        #expect(i1 != nil)
        // Each append creates a new child, so tags should be different
        if let r1, let r2 { #expect(r1 != r2) }
    }
}
