import Foundation
import Testing

@testable import OCCTSwift

// MARK: - OCAF Document Metadata Tests (v0.57.0)

@Suite("OCAF Document Metadata")
struct OCAFDocumentMetadataTests {

    @Test("Document storage format")
    func storageFormat() {
        let doc = Document.create(format: "BinOcaf")!
        #expect(doc.storageFormat == "BinOcaf")
    }

    @Test("Change storage format")
    func changeFormat() {
        let doc = Document.create(format: "BinOcaf")!
        #expect(doc.setStorageFormat("XmlOcaf"))
        #expect(doc.storageFormat == "XmlOcaf")
    }

    @Test("Document not saved initially")
    func notSavedInitially() {
        let doc = Document.create(format: "BinOcaf")!
        #expect(!doc.isSaved)
    }

    @Test("Document count")
    func documentCount() {
        let doc = Document.create(format: "BinOcaf")!
        #expect(doc.documentCount >= 1)
    }

    @Test("Create with XCAF format")
    func createXCAF() {
        let doc = Document.create(format: "BinXCAF")
        #expect(doc != nil)
        if let doc = doc {
            #expect(doc.storageFormat == "BinXCAF")
        }
    }
}
