import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TDF Reference Tests (v0.54.0)

@Suite("TDF Reference")
struct TDFReferenceTests {

    @Test("Set and get reference")
    func setGetReference() {
        let doc = Document.create()!
        let source = doc.createLabel()!
        let target = doc.createLabel()!
        let refLabel = doc.createLabel()!

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
    func noReference() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        #expect(label.referencedLabel == nil, "Fresh label should have no reference")
    }
}
