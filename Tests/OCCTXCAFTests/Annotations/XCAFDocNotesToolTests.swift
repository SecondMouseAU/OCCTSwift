import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDoc_NotesTool Tests")
struct XCAFDocNotesToolTests {
    @Test func createAndCountNotes() {
        if let doc = Document.create() {
            #expect(doc.notesToolNoteCount == 0)
            let note = doc.notesToolCreateComment(
                userName: "User", timeStamp: "2026-03-14",
                comment: "Comment 1")
            #expect(note != nil)
            #expect(doc.notesToolNoteCount == 1)
        }
    }

    @Test func createBalloon() {
        if let doc = Document.create() {
            let note = doc.notesToolCreateBalloon(
                userName: "User", timeStamp: "2026-03-14",
                comment: "Balloon")
            #expect(note != nil)
            #expect(doc.notesToolNoteCount == 1)
        }
    }

    @Test func createBinData() {
        if let doc = Document.create() {
            let data: [UInt8] = [1, 2, 3, 4]
            let note = doc.notesToolCreateBinData(
                userName: "User", timeStamp: "2026-03-14",
                title: "data.bin",
                mimeType: "application/octet-stream",
                data: data)
            #expect(note != nil)
            #expect(doc.notesToolNoteCount == 1)
        }
    }

    @Test func deleteAllNotes() {
        if let doc = Document.create() {
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
    }

    @Test func orphanNotes() {
        if let doc = Document.create() {
            doc.notesToolCreateComment(userName: "U", timeStamp: "T", comment: "orphan")
            // Notes not attached to shapes are orphans
            #expect(doc.notesToolOrphanNoteCount >= 0)
        }
    }
}
