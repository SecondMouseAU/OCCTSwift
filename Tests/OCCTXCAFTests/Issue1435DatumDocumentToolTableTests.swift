import Foundation
import Testing

@testable import OCCTSwift

// #1435: a reintroduction of #1051. `occtDocumentDatumObjectAt`, `OCCTDocumentGetDatumCount` and
// `OCCTDocumentCreateDatum` used `XCAFDoc_DimTolTool::Set(doc->doc->Main())`, which attaches the
// DimTolTool attribute directly on Main() (label 0:1), instead of
// `XCAFDoc_DocumentTool::DimTolTool(doc->doc->Main())`, which is `Set(DGTsLabel(Main()))` —
// `Main().FindChild(4)` (label 0:1:4), a DIFFERENT label. `STEPCAFControl_Reader`/`Writer`,
// `XCAFDoc_Editor::RescaleGeometry` and `XCAFDimTolObjects_Tool` all read the 0:1:4 table, so a
// datum written through the 0:1 table is structurally invisible to every real consumer even though
// it round-trips fine through this bridge's own create/read pair.
//
// #1051 fixed exactly this in `c9f837ec`/PR #1112 (2026-08-24); the very next day merge commit
// `ce6fa9b9` (PR #1130) resolved a conflict on the same file by silently keeping a long-running
// branch's stale, pre-fix copy, and no test caught it, because every existing datum test
// (`DocumentGDTTests`, `Issue1030DatumLookupGuardTests`, `GDTToleranceDatumAccessorTests`,
// `GDTUnifiedReadTests`) only round-trips create→read through the bridge's OWN datum functions,
// which stay self-consistent whether they agree with the real table or not.
//
// This suite is deliberately independent of that: it walks the real OCAF label tree through the
// generic `AssemblyNode` label API (`OCCTDocumentGetMainLabel`/`OCCTDocumentLabelFindChild`/
// `OCCTDocumentLabelNbChildren`, none of them GD&T-specific, none reachable from any of the three
// functions above), the same way `XCAFDoc_DocumentTool::DimTolTool` itself resolves
// `DocLabel(Main()).FindChild(4, true)`. A future merge-conflict revert of the three GD&T-specific
// functions cannot silently revert this check along with them.
@Suite("Datum lands on the real DocumentTool 0:1:4 table, not Main() itself (#1435)")
struct Issue1435DatumDocumentToolTableTests {

    @Test("A created datum is a real child of Main().FindChild(4), the DimTolTool label")
    func datumIsUnderDocumentToolLabel() {
        guard let doc = Document.create() else {
            Issue.record("document creation failed")
            return
        }
        guard let index = doc.createDatum(name: "A") else {
            Issue.record("createDatum failed")
            return
        }
        #expect(index == 0)

        guard let main = doc.mainLabel else {
            Issue.record("mainLabel nil")
            return
        }

        // create: false is deliberate. Nothing else touches tag 4 under Main() at document
        // creation (ShapeTool/ColorTool/VisMaterialTool live at tags 1/2/10), so this label only
        // exists at all if something actually called XCAFDoc_DocumentTool::DimTolTool. If the
        // datum instead landed directly on Main() (the #1435 regression), tag 4 is never created
        // and this comes back nil.
        let dgts = main.findChild(tag: 4, create: false)
        #expect(
            dgts != nil,
            Comment(
                rawValue: "XCAFDoc_DocumentTool's 0:1:4 label was never created; the datum was "
                    + "written somewhere else (Main() itself, the #1435 regression of #1051)")
        )
        guard let dgts else { return }

        #expect(
            dgts.childCount == 1,
            "expected the one datum this test created as a child of the real DimTolTool label")

        // The bridge's own count must agree with the real table. Both being self-consistently
        // wrong (both reading Main() itself) is exactly the #1435/#1051 shape, and the dgts.childCount
        // check above is what tells the two apart from an assertion that only re-asks the bridge.
        #expect(doc.datumCount == 1)
    }

    @Test("doc.datumCount agrees with a direct count of Main().FindChild(4)'s children")
    func datumCountAgreesWithRealTable() {
        guard let doc = Document.create() else {
            Issue.record("document creation failed")
            return
        }
        for name in ["A", "B", "C"] {
            guard doc.createDatum(name: name) != nil else {
                Issue.record("createDatum(\(name)) failed")
                return
            }
        }

        guard let main = doc.mainLabel, let dgts = main.findChild(tag: 4, create: false) else {
            Issue.record("DimTolTool label (Main().FindChild(4)) not found")
            return
        }
        #expect(dgts.childCount == 3)
        #expect(doc.datumCount == 3)
    }
}
