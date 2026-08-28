import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill_AppSurf")
struct GeomFillAppSurfTests {
    @Test("approximate surface from sections")
    func approximateSurface() {
        guard let c1 = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
            let c2 = Curve3D.circle(center: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3)
        else {
            Issue.record("failed to build probe curves")
            return
        }
        guard let result = Surface.appSurf(curves: [c1, c2]) else {
            Issue.record("appSurf(curves:) unexpectedly returned nil for 2 valid curves")
            return
        }
        #expect(result.isDone)
        #expect(result.uDegree > 0)
        #expect(result.vDegree > 0)
        #expect(result.nbUPoles > 0)
        #expect(result.nbVPoles > 0)
    }

    // #644: GeomFill_AppSurf's approximation solver SIGSEGVs (uncatchably) when driven with fewer
    // than 2 sections -- confirmed 0 and 1 both crash, measured from a separate process (an
    // in-process @Test cannot assert a SIGSEGV without killing the whole suite), see
    // Scripts/repro/644-710-geomfill-appsurf-null-arity/README.md for the exit-code table. These
    // two tests assert the documented, fixed contract only: `appSurf(curves:)` rejects an
    // under-sized request instead of crashing.
    @Test("rejects a single curve (#644)")
    func rejectsSingleCurve() {
        guard let c1 = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5)
        else {
            Issue.record("failed to build probe curve")
            return
        }
        #expect(Surface.appSurf(curves: [c1]) == nil)
    }

    @Test("rejects an empty curve list (#644)")
    func rejectsEmptyCurveList() {
        #expect(Surface.appSurf(curves: []) == nil)
    }

    // Regression: the arity guard must not reject the case it exists to let through. Also
    // exercises OCCTGeomFillAppSurf's per-curve null-handle guard (#710) on its ordinary,
    // non-null path, since every element here is a real, valid Curve3D. `Issue.record`, not a
    // decorative `if let`, so a regression that makes either guard over-reject fails loudly.
    @Test("still accepts two curves after the arity guard (#644 regression)")
    func acceptsTwoCurvesRegression() {
        guard let c1 = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
            let c2 = Curve3D.circle(center: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3)
        else {
            Issue.record("failed to build probe curves")
            return
        }
        guard let result = Surface.appSurf(curves: [c1, c2]) else {
            Issue.record("appSurf(curves:) unexpectedly returned nil for 2 valid curves")
            return
        }
        #expect(result.isDone)
    }
}
