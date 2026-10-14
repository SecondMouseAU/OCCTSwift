import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDataStd AsciiString Attribute")
struct TDataStdAsciiStringTests {

    @Test("Set and get ASCII string")
    func setGetAsciiString() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let ok = label.setAsciiString("hello")
        #expect(ok)
        #expect(label.asciiString == "hello")
    }

    @Test("Change ASCII string")
    func changeAsciiString() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        label.setAsciiString("hello")
        label.setAsciiString("world")
        #expect(label.asciiString == "world")
    }
}
