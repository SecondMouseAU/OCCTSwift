import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #1229: DXFError/PDFError's dead `.drawingEmpty` case removed
//
// `DXFError` and `PDFError` each declared a `.drawingEmpty` case, identical to each other in
// both name and `errorDescription` text, that neither writer's `write(to:)` ever threw --
// `grep -rn "drawingEmpty" Sources/ Tests/` found only the two declarations themselves.
// `SVGError` never grew the case in the first place, because SVG has a real fallback for
// empty content (`SVGWriter.computedViewBox()` defaults to a 100x100 canvas); DXF/PDF have no
// such fallback logic *and* no working error path, so the case read as an abandoned
// half-implementation. All three writers already agreed at runtime (silent success on empty
// content, `PDFWriterTests.emptyPDF` / `SVGWriterTests.emptySVG` already pinned that for two
// of the three); the divergence was only in the public API surface. Removed the dead case
// from both enums to match `SVGError`'s shape rather than wiring up a throw that would have
// broken those two already-passing tests -- see the PR's "SemVer impact" for why removing a
// public enum case is still called a MAJOR change even though nothing in this repo ever threw
// it.
@Suite("#1229 DXF/PDF error-enum dead .drawingEmpty case removed")
struct Issue1229DrawingEmptyRemovedTests {
    @Test("DXFWriter, PDFWriter and SVGWriter all succeed (no throw) on empty content")
    func allThreeWritersAgreeOnEmptyContent() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        let dxfURL = dir.appendingPathComponent("1229_parity_\(UUID()).dxf")
        let pdfURL = dir.appendingPathComponent("1229_parity_\(UUID()).pdf")
        let svgURL = dir.appendingPathComponent("1229_parity_\(UUID()).svg")
        defer {
            try? FileManager.default.removeItem(at: dxfURL)
            try? FileManager.default.removeItem(at: pdfURL)
            try? FileManager.default.removeItem(at: svgURL)
        }
        // None of these three throws: prior to the fix this was already true for PDF/SVG and
        // (undocumented but also true) for DXF; the fix's job was to make the *type*, not the
        // runtime behavior, agree across all three.
        try DXFWriter().write(to: dxfURL)
        try PDFWriter().write(to: pdfURL)
        try SVGWriter().write(to: svgURL)
    }

    /// `DXFError`/`PDFError` now declare exactly one case, matching `SVGError`. This isn't
    /// directly observable at runtime (there's no value of the removed case left to construct),
    /// so it's pinned the way the rest of this file pins a case list: an exhaustive `switch`
    /// with no `default:`, which fails to *compile* the moment either enum grows an
    /// unhandled case again. `errorDescription`'s own implementation is exactly this switch
    /// already; duplicating it here as a second, test-local switch means a future case added to
    /// only one of the two copies (the enum's own `errorDescription` and this test) is caught
    /// either way, rather than this test silently tracking whatever the source does.
    @Test("DXFError and PDFError have exactly one case each: .writeFailed")
    func onlyWriteFailedCaseRemains() {
        func describe(_ e: DXFError) -> String {
            switch e {
            case .writeFailed(let msg): return msg
            }
        }
        func describe(_ e: PDFError) -> String {
            switch e {
            case .writeFailed(let msg): return msg
            }
        }
        #expect(describe(DXFError.writeFailed("x")) == "x")
        #expect(describe(PDFError.writeFailed("y")) == "y")
    }
}
