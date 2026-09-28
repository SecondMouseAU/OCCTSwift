import Foundation
import Testing

@testable import OCCTSwift

// MARK: - OCAF Format Registration Tests (v0.57.0)

@Suite("OCAF Format Registration")
struct OCAFFormatRegistrationTests {

    /// The six formats `defineAllFormats()` registers, in report order.
    ///
    /// Measured through the bridge and confirmed against the kernel in
    /// `Scripts/repro/766-xcaf-ocaf-saveload-evidence/` ("reading=6 writing=6").
    static let allFormats = [
        "BinOcaf", "BinLOcaf", "XmlOcaf", "XmlLOcaf", "BinXCAF", "XmlXCAF",
    ]

    @Test("Register all format drivers")
    func registerFormats() {
        let doc = Document.create()!
        // Nothing is registered until defineAllFormats runs, so the assertion
        // below is about that call and not about an application that arrives
        // pre-populated.
        #expect(doc.readingFormats.isEmpty)
        doc.defineAllFormats()
        let formats = doc.readingFormats
        // Exactly six, named. `>= 4` passed on five of the six drivers
        // registering, which is the failure this test is for.
        #expect(formats == Self.allFormats)
    }

    @Test("Reading and writing formats")
    func readWriteFormats() {
        let doc = Document.create()!
        doc.defineAllFormats()
        let reading = doc.readingFormats
        let writing = doc.writingFormats
        // Every one of the six drivers registers for both directions.
        #expect(reading == Self.allFormats)
        #expect(writing == Self.allFormats)
    }
}
