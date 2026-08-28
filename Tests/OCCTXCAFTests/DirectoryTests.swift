import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDataStd_Directory Tests")
struct DirectoryTests {
    @Test func createDirectory() {
        if let doc = Document.create() {
            let ok = doc.createDirectory(at: 100)
            #expect(ok)
        }
    }

    @Test func findDirectory() {
        if let doc = Document.create() {
            doc.createDirectory(at: 100)
            #expect(doc.hasDirectory(at: 100))
        }
    }

    @Test func addSubDirectory() {
        if let doc = Document.create() {
            doc.createDirectory(at: 100)
            let childTag = doc.addSubDirectory(under: 100)
            #expect(childTag != nil)
        }
    }

    @Test func makeObjectLabel() {
        if let doc = Document.create() {
            doc.createDirectory(at: 100)
            let objTag = doc.makeObjectLabel(under: 100)
            #expect(objTag != nil)
        }
    }
}
