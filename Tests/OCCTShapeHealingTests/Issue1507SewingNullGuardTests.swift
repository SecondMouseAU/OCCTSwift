import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

/// #1507: `OCCTSewingNbMultipleEdges` and `OCCTSewingIsMultipleEdge`
/// (`Sources/OCCTBridge/src/OCCTBridge_Modeling_HealingSewing.mm`) dereferenced `sewing->sewing`
/// with no `if (!sewing)` guard, unlike every other one of that file's 20 non-`Release` functions
/// taking an `OCCTSewingRef`. `OCCTBridge_Modeling.h` declares `sewing` `_Nonnull` on both, so
/// `SewingBuilder`'s own `ref` is never nil, but a genuinely-null `OCCTSewingRef` still
/// type-checks as non-optional Swift, matching Issue #1424's `unsafeBitCast` precedent (and
/// Issue #900's) for constructing one at the ABI level. `SewingBuilder` always holds a non-null
/// `ref` for its whole lifetime (only ever built from a successful `OCCTSewingCreate`), so this
/// is hardening for the public C ABI (`docs/guides/consuming-from-objective-c.md`), not a gap
/// reachable through the public Swift API today; both tests below call the bridge functions
/// directly rather than through `SewingBuilder`.
@Suite("Issue #1507: OCCTSewing null guards")
struct Issue1507SewingNullGuardTests {

    @Test("a null OCCTSewingRef returns 0, not a crash")
    func nbMultipleEdgesNullRawPointerReturnsZero() {
        let nullSewing: OCCTSewingRef = unsafeBitCast(UInt(0), to: OCCTSewingRef.self)
        let count = OCCTSewingNbMultipleEdges(nullSewing)
        #expect(count == 0)
    }

    @Test("a null OCCTSewingRef returns false and nils the out-param, not a crash")
    func isMultipleEdgeNullRawPointerReturnsFalse() {
        let nullSewing: OCCTSewingRef = unsafeBitCast(UInt(0), to: OCCTSewingRef.self)
        var outEdge: OCCTShapeRef? = unsafeBitCast(UInt(1), to: OCCTShapeRef.self)
        let ok = OCCTSewingIsMultipleEdge(nullSewing, 1, &outEdge)
        #expect(ok == false)
        #expect(outEdge == nil)
    }

    @Test("an ordinary sewing's multiple-edge count is unaffected")
    func ordinarySewingUnaffected() throws {
        let sewing = try #require(SewingBuilder(tolerance: 1e-6))
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        for face in box.subShapes(ofType: .face) {
            sewing.add(face)
        }
        sewing.perform()
        #expect(sewing.nbFreeEdges >= 0)
    }
}
