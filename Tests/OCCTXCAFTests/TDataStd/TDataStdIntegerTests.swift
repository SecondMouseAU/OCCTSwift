import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TDataStd Scalar Attribute Tests (v0.55.0)

@Suite("TDataStd Integer Attribute")
struct TDataStdIntegerTests {

    @Test("Set and get integer")
    func setGetInteger() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let ok = label.setInteger(42)
        #expect(ok)
        #expect(label.integer == 42)
    }

    @Test("Change integer value")
    func changeInteger() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        label.setInteger(42)
        label.setInteger(99)
        #expect(label.integer == 99)
    }

    @Test("No integer on fresh label")
    func noInteger() throws {
        let doc = try #require(Document.create())
        let parent = try #require(doc.createLabel())
        let label = try #require(doc.createLabel(parent: parent))
        #expect(label.integer == nil)
    }
}
