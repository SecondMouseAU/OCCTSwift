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

    @Test("a forced mesh failure fails the call sites' crest check instead of passing it")
    func documentsThePreFixSilentPass() {
        // The removed `Issue257MultiStartTests.meshCrestRadius` returned `-1` on `Shape.mesh`
        // failure, and its three call sites compared that with `<=` against a positive nominal
        // radius, which `-1` always satisfies. This test used to assert exactly that arithmetic,
        // `#expect(-1.0 <= 5.0 * 1.005)`, which no change to any code could turn red (#1990).
        // It now runs the crest check the way the call sites do today, through the shared helper
        // with a mesher that fails, and requires the check NOT to pass. Put the sentinel back in
        // `meshMaxRadialExtent` and the `<=` passes again, which fails this test.
        guard let s = Shape.cylinder(radius: 5, height: 10) else {
            Issue.record("cylinder build failed")
            return
        }
        let crestCheckPassed: Bool
        if let crest = meshMaxRadialExtent(s, deflection: 0.03, mesher: { _, _ in nil }) {
            crestCheckPassed = crest <= 5.0 * 1.005
        } else {
            crestCheckPassed = false
        }
        #expect(!crestCheckPassed, "a failed mesh must not satisfy the crest-radius check")
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
