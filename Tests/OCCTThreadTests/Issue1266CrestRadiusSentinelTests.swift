import Testing
import simd

@testable import OCCTSwift

/// #1266: the crest-radius measurement (`sqrt(x² + y²)` over a shape's meshed vertices) was
/// reimplemented four times across this target. One copy
/// (`Issue257MultiStartTests.meshCrestRadius`, since removed) returned a `-1` sentinel on
/// `Shape.mesh` failure, and every one of its three call sites compared the result with `<=`
/// against a positive nominal radius, e.g. `meshCrestRadius(s) <= 5.0 * 1.005`. `-1 <= 5.025` is
/// trivially true, so a genuine measurement failure silently reported success instead of being
/// caught. `meshMaxRadialExtent` (`OCCTThreadTests.swift`) now replaces all four copies and
/// returns `nil` on failure.
///
/// A genuine `Shape.mesh` failure can't safely be forced from the public API: a `nullified` shape
/// still meshes to a valid, empty `Mesh` rather than failing (`BRepMesh_IncrementalMesh` copes
/// with a null `TopoDS_Shape`, per CLAUDE.md's Known OCCT Bugs #1035 audit), and a non-positive or
/// NaN `linearDeflection` was observed to hang rather than fail cleanly when probed directly.
/// `meshMaxRadialExtent`'s `mesher` parameter is a test-only seam for exactly this: production
/// callers never pass it, so this test substitutes an always-fails provider to prove the fixed
/// nil-handling actually catches the failure, without needing a hazardous real mesh failure.
@Suite("Issue #1266, mesh crest-radius measurement is deduplicated and its sentinel fixed")
struct Issue1266CrestRadiusSentinelTests {

    @Test("a forced mesh failure is reported as nil, not a sentinel a caller could silently pass")
    func forcedMeshFailureReturnsNilNotSentinel() {
        guard let s = Shape.cylinder(radius: 5, height: 10) else {
            Issue.record("cylinder build failed")
            return
        }
        let crest = meshMaxRadialExtent(s, deflection: 0.03, mesher: { _, _ in nil })
        #expect(crest == nil, "a failed measurement must report absence, not a sentinel value")
    }

    @Test("the pre-#1266 -1 sentinel would have silently passed the exact assertion every call site used")
    func documentsThePreFixSilentPass() {
        // Not a bug in current code: this is the pre-fix arithmetic, kept as a permanent record of
        // why `-1` was a silent-pass bug rather than a safe fallback. `-1` is the value the removed
        // `Issue257MultiStartTests.meshCrestRadius` returned on `Shape.mesh` failure, compared with
        // `<=` against any positive nominal radius at every one of its three call sites.
        let preFixSentinelOnFailure = -1.0
        #expect(preFixSentinelOnFailure <= 5.0 * 1.005)
    }

    @Test("real geometry still measures a sensible crest radius through the shared helper")
    func realMeshingStillWorks() {
        guard let s = Shape.cylinder(radius: 5, height: 10) else {
            Issue.record("cylinder build failed")
            return
        }
        guard let crest = meshMaxRadialExtent(s, deflection: 0.05) else {
            Issue.record("mesh failed on an ordinary cylinder")
            return
        }
        #expect(crest > 0)
        #expect(crest <= 5.0 * 1.01)
    }
}
