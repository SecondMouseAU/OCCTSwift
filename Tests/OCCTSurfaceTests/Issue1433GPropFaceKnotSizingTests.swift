import Testing
import simd

@testable import OCCTSwift

/// #1433: `OCCTBRepGPropFaceVKnots`/`OCCTBRepGPropFaceBoundaryIntegration` sized their scratch
/// `NCollection_Array1<double>` to `SVIntSubs()`/`LIntSubs()` — the subinterval count, `N-1` — but
/// `BRepGProp_Face::VKnots()`/`LKnots()` always write `N` knots for every fixed surface/curve type
/// (`Libraries/occt-src/.../BRepGProp_Face.cxx`). The undersized array overran by one `double` on
/// the OCCT side (an unguarded heap-buffer overflow under `Scripts/build-occt.sh`'s
/// `BUILD_RELEASE_DISABLE_EXCEPTIONS=ON` release build, where `NCollection_Array1`'s bounds check
/// compiles to nothing), and — independent of whether that particular write corrupts anything else
/// on the heap — the last knot was always silently dropped on read-back regardless, since the
/// bridge's own copy loop is bounded by the array's own (undersized) `Upper()`.
@Suite("Issue #1433, BRepGProp_Face knot-array sizing")
struct Issue1433GPropFaceKnotSizingTests {

    // A 10×10 planar face on z=0, the same fixture Issue266FaceAnalysisFollowupTests uses.
    private func planarFace() -> Shape? {
        guard let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)),
            let outer = Wire.polygon3D(
                [
                    SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0),
                ], closed: true)
        else { return nil }
        return Shape.face(from: plane, outer: outer, innerWires: [])
    }

    @Test("V-direction integration knots are not truncated on a planar face")
    func vKnotsNotTruncated() {
        guard let face = planarFace() else {
            Issue.record("setup")
            return
        }
        let knots = face.faceIntegrationKnotsV()
        // Before the fix this was exactly 1: BRepGProp_Face::VKnots() writes Knots(1) then
        // Knots(2), but the scratch array only held 1 element, so Knots(2) landed one `double`
        // past the allocation and was never visible to the read-back loop (bounded by the
        // array's own, undersized Upper()). The fix sizes the array to match what VKnots() always
        // writes, so both knots now come back.
        #expect(knots.count == 2)
        if knots.count == 2 {
            #expect(knots[0] < knots[1])
        }
    }

    @Test("Boundary integration knots are not truncated on a straight face edge")
    func boundaryKnotsNotTruncated() {
        guard let face = planarFace() else {
            Issue.record("setup")
            return
        }
        guard let bi = face.faceBoundaryIntegration(edgeIndex: 0) else {
            Issue.record("boundaryIntegration nil")
            return
        }
        // `subs` (the subinterval count LIntSubs() reports) is untouched by this fix, only the
        // knot array's sizing was; a straight edge has exactly 1 subinterval delimited by 2 knots.
        #expect(bi.subs == 1)
        #expect(bi.knots.count == 2)
        if bi.knots.count == 2 {
            #expect(bi.knots[0] < bi.knots[1])
        }
    }

    @Test("V knots and boundary knots agree with their own already-correct subinterval counts")
    func knotCountMatchesSubIntervalCountPlusOne() {
        guard let face = planarFace() else {
            Issue.record("setup")
            return
        }
        guard let si = face.faceSurfaceIntegration() else {
            Issue.record("surfaceIntegration nil")
            return
        }
        // N knots always delimit N-1 subintervals; SVIntSubs() (surfaced as `si.vSubs`) was
        // already correct before this fix, only the knot *array* was undersized.
        #expect(face.faceIntegrationKnotsV().count == si.vSubs + 1)
    }
}
