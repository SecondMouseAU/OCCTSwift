import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDocStd_XLink Tests")
struct XLinkTests {
    @Test func setXLink() {
        if let doc = Document.create() {
            let ok = doc.setXLink(at: 1)
            #expect(ok)
        }
    }

    @Test func documentEntry() {
        if let doc = Document.create() {
            doc.setXLink(at: 1)
            doc.setXLinkDocumentEntry("/doc/path", at: 1)
            let entry = doc.xLinkDocumentEntry(at: 1)
            #expect(entry == "/doc/path")
        }
    }

    @Test func labelEntry() {
        if let doc = Document.create() {
            doc.setXLink(at: 1)
            doc.setXLinkLabelEntry("0:1:2", at: 1)
            let entry = doc.xLinkLabelEntry(at: 1)
            #expect(entry == "0:1:2")
        }
    }
}
