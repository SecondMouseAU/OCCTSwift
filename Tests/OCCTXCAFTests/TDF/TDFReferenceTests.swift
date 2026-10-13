import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TDF Reference Tests (v0.54.0)

@Suite("TDF Reference")
struct TDFReferenceTests {

    @Test("Set and get reference")
    func setGetReference() throws {
        let doc = try #require(Document.create())
        let source = try #require(doc.createLabel())
        let target = try #require(doc.createLabel())
        let refLabel = try #require(doc.createLabel())

        source.setName("Source")
        target.setName("Target")

        let ok = refLabel.setReference(to: target)
        #expect(ok, "Setting reference should succeed")

        if let referenced = refLabel.referencedLabel {
            #expect(referenced.labelId == target.labelId, "Reference should point to target")
        } else {
            Issue.record("Should have a referenced label")
        }
    }

    @Test("No reference on fresh label")
    func noReference() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        #expect(label.referencedLabel == nil, "Fresh label should have no reference")
    }
}
