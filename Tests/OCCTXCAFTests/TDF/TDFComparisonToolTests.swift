import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDF ComparisonTool Tests")
struct TDFComparisonToolTests {

    @Test func isSelfContained() throws {
        let doc = try #require(Document.create())
        doc.openTransaction()
        let node = try #require(doc.createLabel())
        node.setInteger(1)
        doc.commitTransaction()
        let result = doc.isSelfContained(labelId: node.labelId)
        #expect(result == true)
    }

    /// A label whose reference points outside its own subtree is not self-contained.
    ///
    /// `Document.isSelfContained(labelId:)` used to call `TDF_ComparisonTool::IsSelfContained` on a
    /// data set the bridge filled with the label and its own descendants, which cannot answer false,
    /// and OCCT 8.1 deleted that class. It asks `TDF_Tool::IsSelfContained`, which follows the
    /// label's `TDF_Reference` attributes: `referrer` points at `target`, a sibling outside it.
    @Test func aReferenceToASiblingIsNotSelfContained() throws {
        let doc = try #require(Document.create())
        doc.openTransaction()
        let parent = try #require(doc.createLabel())
        let referrer = try #require(doc.createLabel(parent: parent))
        let target = try #require(doc.createLabel(parent: parent))
        referrer.setInteger(1)
        target.setInteger(2)
        #expect(referrer.setReference(to: target))
        doc.commitTransaction()
        #expect(doc.isSelfContained(labelId: referrer.labelId) == false)
        // The target holds no reference, and the parent contains both ends of the one there is.
        #expect(doc.isSelfContained(labelId: target.labelId) == true)
        #expect(doc.isSelfContained(labelId: parent.labelId) == true)
    }
}
