import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDocStd_XLink Tests")
struct XLinkTests {
    @Test func setXLink() throws {
        let doc = try #require(Document.create())
        // Nothing is linked at label 1 until one is set.
        #expect(doc.xLinkDocumentEntry(at: 1) == nil)
        #expect(doc.xLinkLabelEntry(at: 1) == nil)

        #expect(doc.setXLink(at: 1))
        // A fresh link has empty entries, and they are there to be filled.
        #expect(doc.xLinkDocumentEntry(at: 1) == "")
        #expect(doc.xLinkLabelEntry(at: 1) == "")
    }

    @Test func documentEntry() throws {
        let doc = try #require(Document.create())
        doc.setXLink(at: 1)
        doc.setXLinkDocumentEntry("/doc/path", at: 1)
        let entry = doc.xLinkDocumentEntry(at: 1)
        #expect(entry == "/doc/path")
    }

    @Test func labelEntry() throws {
        let doc = try #require(Document.create())
        doc.setXLink(at: 1)
        doc.setXLinkLabelEntry("0:1:2", at: 1)
        let entry = doc.xLinkLabelEntry(at: 1)
        #expect(entry == "0:1:2")
    }
}
