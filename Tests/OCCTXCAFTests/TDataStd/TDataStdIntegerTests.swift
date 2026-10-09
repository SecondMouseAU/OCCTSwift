import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TDataStd Scalar Attribute Tests (v0.55.0)

@Suite("TDataStd Integer Attribute")
struct TDataStdIntegerTests {

    @Test("Set and get integer")
    func setGetInteger() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let ok = label.setInteger(42)
        #expect(ok)
        #expect(label.integer == 42)
    }

    @Test("Change integer value")
    func changeInteger() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        label.setInteger(42)
        label.setInteger(99)
        #expect(label.integer == 99)
    }

    @Test("No integer on fresh label")
    func noInteger() {
        let doc = Document.create()!
        let parent = doc.createLabel()!
        let label = doc.createLabel(parent: parent)!
        #expect(label.integer == nil)
    }
}
