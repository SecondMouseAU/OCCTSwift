import Foundation
import Testing

@testable import OCCTSwift

// MARK: - OCAF Format Registration Tests (v0.57.0)

@Suite("OCAF Format Registration")
struct OCAFFormatRegistrationTests {

    @Test("Register all format drivers")
    func registerFormats() {
        let doc = Document.create()!
        doc.defineAllFormats()
        let formats = doc.readingFormats
        #expect(formats.count >= 4)
    }

    @Test("Reading and writing formats")
    func readWriteFormats() {
        let doc = Document.create()!
        doc.defineAllFormats()
        let reading = doc.readingFormats
        let writing = doc.writingFormats
        #expect(!reading.isEmpty)
        #expect(!writing.isEmpty)
    }
}
