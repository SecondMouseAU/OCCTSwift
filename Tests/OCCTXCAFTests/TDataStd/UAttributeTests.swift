import Foundation
import Testing

@testable import OCCTSwift

@Suite("UAttribute Tests")
struct UAttributeTests {

    @Test func setAndHas() throws {
        let doc = try #require(Document.create())
        let guid = "12345678-1234-1234-1234-123456789012"
        #expect(doc.setUAttribute(tag: 300, guid: guid))
        #expect(doc.hasUAttribute(tag: 300, guid: guid))
    }

    @Test func differentGUID() throws {
        let doc = try #require(Document.create())
        let guid1 = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        let guid2 = "11111111-2222-3333-4444-555555555555"
        doc.setUAttribute(tag: 301, guid: guid1)
        #expect(doc.hasUAttribute(tag: 301, guid: guid1))
        #expect(!doc.hasUAttribute(tag: 301, guid: guid2))
    }

    @Test func getID() throws {
        let doc = try #require(Document.create())
        let guid = "ABCDEF01-2345-6789-ABCD-EF0123456789"
        doc.setUAttribute(tag: 302, guid: guid)
        let retrieved = doc.uAttributeID(tag: 302, guid: guid)
        let id = try #require(retrieved)
        // The GUID should contain the original hex digits (may differ in formatting)
        #expect(id.lowercased().contains("abcdef01"))
    }
}
