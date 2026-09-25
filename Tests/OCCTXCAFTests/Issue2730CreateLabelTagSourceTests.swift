import Foundation
import Testing

@testable import OCCTSwift

/// #2730: on a fresh XCAF document, `createLabel()`'s first two calls used to return the
/// existing `XCAFDoc_ShapeTool`/`XCAFDoc_ColorTool` labels (each already holding two attributes),
/// and the next two returned the tags `XCAFDoc_DocumentTool` later uses for its Layers and DGTs
/// labels. `TDF_Label::NewChild()` draws its tag from a `TDF_TagSource` attribute Main() does not
/// have on a fresh document, so it is created lazily starting at 1 and collides with whichever of
/// the nine fixed tags (1-5, 7-10; 6 is unused) `XCAFDoc_DocumentTool` reserves there.
///
/// `OCCTDocumentCreateLabel` now seeds that counter to 10 (the highest reserved tag,
/// `VisMaterialLabel`) before the first `NewChild()`, so every `createLabel()` call lands at tag
/// 11 or above, whatever order it runs in relative to a lazy `XCAFDoc_DocumentTool` accessor. See
/// `Scripts/repro/2730-createlabel-tagsource/probe.mm` for the measurements this pins, including
/// the reserved-tag set itself (measured, not read off the header comment) and the call-order and
/// reload robustness checks.
@Suite("Issue 2730: createLabel() on an XCAF document")
struct Issue2730CreateLabelTagSourceTests {

    /// The tags XCAFDoc_DocumentTool reserves under Main(), measured in the probe above. Tag 6
    /// (between MaterialsLabel and ViewsLabel) is genuinely unused by the pinned OCCT 8.0.1.
    private static let reservedTags: Set<Int32> = [1, 2, 3, 4, 5, 7, 8, 9, 10]

    @Test("The first createLabel() call on a fresh XCAF document is genuinely empty")
    func firstCallIsEmpty() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        #expect(!node.hasAttribute, "a genuinely new label carries no attributes")
        #expect(doc.attributeCount(labelId: node.labelId) == 0)
    }

    @Test("The first four createLabel() calls never land on a tag XCAFDoc_DocumentTool reserves")
    func doesNotReturnAToolLabel() {
        guard let doc = Document.create() else { return }
        for i in 1...4 {
            guard let node = doc.createLabel() else { continue }
            #expect(
                !Self.reservedTags.contains(node.tag),
                "call \(i) returned tag \(node.tag), a tag XCAFDoc_DocumentTool reserves")
            #expect(!node.hasAttribute, "call \(i) returned a label with pre-existing attributes")
        }
    }

    @Test("createLabel() adds a genuinely new child of Main, not an existing one")
    func addsANewChildOfMain() {
        // AssemblyNode.children walks XCAFDoc_ShapeTool's shape/assembly components, which Main
        // itself is not, so it always reads 0 there; .childCount is the raw
        // TDF_Label::NbChildren() this test needs.
        guard let doc = Document.create() else { return }
        guard let main = doc.mainLabel else { return }
        let before = main.childCount
        guard doc.createLabel() != nil else { return }
        #expect(main.childCount == before + 1, "createLabel() must add exactly one child of Main")
    }

    @Test("Four calls return four distinct labels, each adding a child")
    func fourCallsAreDistinctAndAdditive() {
        guard let doc = Document.create() else { return }
        guard let main = doc.mainLabel else { return }
        let before = main.childCount
        var tags = Set<Int32>()
        for _ in 1...4 {
            guard let node = doc.createLabel() else { continue }
            tags.insert(node.tag)
        }
        #expect(tags.count == 4, "all four createLabel() calls must return distinct labels")
        #expect(main.childCount == before + 4)
    }
}
