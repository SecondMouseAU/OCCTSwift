import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDoc_NotesTool Tests")
struct XCAFDocNotesToolTests {
    @Test func createAndCountNotes() throws {
        let doc = try #require(Document.create())
        #expect(doc.notesToolNoteCount == 0)
        let note = doc.notesToolCreateComment(
            userName: "User", timeStamp: "2026-03-14",
            comment: "Comment 1")
        #expect(note != nil)
        #expect(doc.notesToolNoteCount == 1)
    }

    @Test func createBalloon() throws {
        let doc = try #require(Document.create())
        let note = doc.notesToolCreateBalloon(
            userName: "User", timeStamp: "2026-03-14",
            comment: "Balloon")
        #expect(note != nil)
        #expect(doc.notesToolNoteCount == 1)
    }

    @Test func createBinData() throws {
        let doc = try #require(Document.create())
        let data: [UInt8] = [1, 2, 3, 4]
        let note = doc.notesToolCreateBinData(
            userName: "User", timeStamp: "2026-03-14",
            title: "data.bin",
            mimeType: "application/octet-stream",
            data: data)
        #expect(note != nil)
        #expect(doc.notesToolNoteCount == 1)
    }

    @Test func deleteAllNotes() throws {
        let doc = try #require(Document.create())
        doc.notesToolCreateComment(userName: "U", timeStamp: "T", comment: "C1")
        doc.notesToolCreateBalloon(userName: "U", timeStamp: "T", comment: "C2")
        doc.notesToolCreateBinData(
            userName: "U", timeStamp: "T", title: "t",
            mimeType: "m", data: [0])
        #expect(doc.notesToolNoteCount == 3)
        let deleted = doc.notesToolDeleteAllNotes()
        #expect(deleted == 3)
        #expect(doc.notesToolNoteCount == 0)
    }

    @Test func orphanNotes() throws {
        let doc = try #require(Document.create())
        let first = try #require(
            doc.notesToolCreateComment(userName: "U", timeStamp: "T", comment: "orphan"))
        _ = try #require(
            doc.notesToolCreateBalloon(userName: "U", timeStamp: "T", comment: "balloon"))
        // Neither note is attached to an item, so both are orphans.
        #expect(doc.notesToolNoteCount == 2)
        #expect(doc.notesToolOrphanNoteCount == 2)

        // Deleting one takes it out of both counts and leaves the other an orphan.
        #expect(doc.notesToolDeleteNote(first))
        #expect(doc.notesToolNoteCount == 1)
        #expect(doc.notesToolOrphanNoteCount == 1)

        // Deleting orphans reports how many it removed, and removes the last note.
        #expect(doc.notesToolDeleteOrphanNotes() == 1)
        #expect(doc.notesToolNoteCount == 0)
        #expect(doc.notesToolOrphanNoteCount == 0)
    }
}
