import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

/// #1511 Finding 2: `OCCTCurve2DCurveType` (`Sources/OCCTBridge/src/OCCTBridge_Geom2d_Adaptor.mm`)
/// returned `7` (`GeomAbs_OffsetCurve`, a real, different curve type) on a null/invalid handle or
/// any caught exception -- the same off-by-one #1476 fixed for the 3D sibling
/// `OCCTCurve3DCurveType`. `GeomAbs_CurveType` is a 9-value enum (`Line=0` ... `OffsetCurve=7`,
/// `OtherCurve=8`), so the fallback silently reported a specific, wrong curve type instead of
/// "other/unknown".
///
/// Reachability is low, as the issue itself notes: `Curve2D`'s `curve` parameter is `_Nonnull`
/// with no "nullified" concept, so this fallback is close to unreachable dead code through the
/// public Swift API today. Follows the #1424/#1476 `unsafeBitCast` precedent
/// (`Tests/OCCTAnalysisTests/Issue1424BndLibFaceNullGuardTests.swift`,
/// `Tests/OCCTCurveTests/Issue1476CurveTypeOtherCurveFallbackTests.swift`) to synthesize a
/// genuinely-null `OCCTCurve2DRef` and call the bridge function directly, since the parameter is
/// `_Nonnull` and Swift refuses to pass `nil` literally.
@Suite("Issue #1511 Finding 2: OCCTCurve2DCurveType OtherCurve fallback")
struct Issue1511Curve2DCurveTypeOtherCurveFallbackTests {

    @Test("a null OCCTCurve2DRef returns GeomAbs_OtherCurve (8), not GeomAbs_OffsetCurve (7)")
    func nullHandleReturnsOtherCurveNotOffsetCurve() {
        let nullCurve: OCCTCurve2DRef = unsafeBitCast(UInt(0), to: OCCTCurve2DRef.self)
        let type = OCCTCurve2DCurveType(nullCurve)
        #expect(type == 8)
        #expect(type != 7)
    }

    @Test("an ordinary line's curve type is unaffected (Line = 0)")
    func ordinaryLineUnaffected() throws {
        let line = try #require(Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)))
        #expect(line.curveType == 0)
    }
}
