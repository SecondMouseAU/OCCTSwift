import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

/// #1476: `OCCTCurve3DCurveType` (`Sources/OCCTBridge/src/OCCTBridge_Curve3D_Adaptor.mm`)
/// returned `7` (`GeomAbs_OffsetCurve`) on a null/invalid handle, labeled `// OtherCurve` in the
/// comment. `GeomAbs_CurveType` is a 9-value enum (`Line=0` ... `OffsetCurve=7`, `OtherCurve=8`),
/// so the fallback silently reported a specific, real, wrong curve type instead of "other/unknown".
/// `Edge.swift`'s `CurveType` enum already had the correct mapping (`offsetCurve = 7`, `other = 8`),
/// so the wrong constant reached a real, differently-labeled Swift case, not just a comment
/// mismatch.
///
/// The null-handle guard (`!curve || curve->curve.IsNull()`) is the exact pattern CLAUDE.md's
/// bridge conventions require, so it's reachable, not idle code -- but `Curve3D`'s public API
/// gives no way to construct a wrapper around a null handle. `Curve3DExtrasV112Tests.curveType()`
/// only checked `line`/`circle`, and no test exercised the fallback at all. This test follows the
/// #1424 `unsafeBitCast` precedent (`Tests/OCCTAnalysisTests/Issue1424BndLibFaceNullGuardTests.swift`)
/// to synthesize a genuinely-null `OCCTCurve3DRef` and call the bridge function directly, since the
/// parameter is `_Nonnull` and Swift refuses to pass `nil` literally.
@Suite("Issue #1476: OCCTCurve3DCurveType OtherCurve fallback")
struct Issue1476CurveTypeOtherCurveFallbackTests {

    @Test("a null OCCTCurve3DRef returns GeomAbs_OtherCurve (8), not GeomAbs_OffsetCurve (7)")
    func nullHandleReturnsOtherCurveNotOffsetCurve() {
        let nullCurve: OCCTCurve3DRef = unsafeBitCast(UInt(0), to: OCCTCurve3DRef.self)
        let type = OCCTCurve3DCurveType(nullCurve)
        #expect(type == 8)
        #expect(type != 7)
    }

    @Test("an ordinary line's curve type is unaffected (Line = 0)")
    func ordinaryLineUnaffected() throws {
        let line = try #require(Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)))
        #expect(line.curveType == 0)
    }
}
