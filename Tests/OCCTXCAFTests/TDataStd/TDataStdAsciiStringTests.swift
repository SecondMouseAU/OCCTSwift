import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDataStd AsciiString Attribute")
struct TDataStdAsciiStringTests {

    @Test("Set and get ASCII string")
    func setGetAsciiString() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let ok = label.setAsciiString("hello")
        #expect(ok)
        #expect(label.asciiString == "hello")
    }

    @Test("Change ASCII string")
    func changeAsciiString() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        label.setAsciiString("hello")
        label.setAsciiString("world")
        #expect(label.asciiString == "world")
    }
}
