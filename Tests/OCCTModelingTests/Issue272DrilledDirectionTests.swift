import Testing
import simd

@testable import OCCTSwift

/// Issue #272: `Shape.drilled(at:direction:radius:depth:)` ignored its `direction` argument, the
/// C++ bridge (`OCCTShapeDrillHole`) built the cutting cylinder via `OCCTShapeCreateCylinderAt`,
/// which hardcodes the cylinder axis to +Z (`gp_Dir(0, 0, 1)`). So drilling along any non-Z
/// direction repositioned the cylinder's base along the requested direction but still bored up +Z,
/// cutting the wrong axis (and, for a base point pushed outside the shape, removing nothing at all).
///
/// Fix: build the cylinder with `OCCTShapeCreateCylinderOriented(pos, direction, r, depth)`, whose
/// `gp_Ax2(origin, direction)` orients the bore along the requested (normalized) direction.
///
/// These tests are DISCRIMINATING against the old hardcoded-Z behaviour: they drill a block that is
/// much wider in X than in Z along +X, and assert the removed material actually runs the full X
/// extent (and that a point on the +X bore axis is now outside the solid). Under the old bug the +X
/// bore cylinder landed entirely outside the block, so ~zero volume was removed and the axis point
/// stayed inside, both assertions below would fail.
@Suite("Issue #272, drilled honours a non-Z direction")
struct Issue272DrilledDirectionTests {

    // Block centered at origin: X[-30,30] (60 wide), Y[-10,10] (20), Z[-6,6] (12 thick).
    // X extent (60) >> Z extent (12), so an X-bore and a Z-bore remove very different volumes.
    private func makeBlock() -> Shape { Shape.box(width: 60, height: 20, depth: 12)! }
    private let radius = 3.0

    /// Drilling +X through the wide axis removes material along X, proving the bore follows the
    /// requested direction rather than +Z. Under the old bug this removed ~nothing.
    @Test("Drilling +X bores along X (not Z): removes the full X-extent of material")
    func drillsAlongXNotZ() {
        let block = makeBlock()
        let original = block.volume ?? 0

        // Enter from just outside the -X face, bore along +X, through-hole (depth 0).
        guard
            let drilledX = block.drilled(
                at: SIMD3(-31, 0, 0),
                direction: SIMD3(1, 0, 0),
                radius: radius, depth: 0)
        else {
            Issue.record("drilled(+X) returned nil")
            return
        }
        #expect(drilledX.isValid)

        let removed = original - (drilledX.volume ?? 0)
        // A bore running the full 60mm X extent removes π·r²·60. The old +Z-hardcoded bore landed
        // outside the block and removed ~0, so this assertion fails against the bug.
        let expectedXBore = Double.pi * radius * radius * 60.0
        #expect(abs(removed - expectedXBore) < 5.0)

        // The block centre lies on the +X bore axis (Y=0, Z=0): after an X through-hole it must be
        // OUTSIDE the solid. Under the old +Z bore it stayed inside.
        #expect(drilledX.classify(point: SIMD3(0, 0, 0)) == .outside)
        // A point off the bore axis but still in the block (Y=8) stays inside, the solid survived.
        #expect(drilledX.classify(point: SIMD3(0, 8, 0)) == .inside)
    }

    /// Direct comparison: drilling the SAME block along +X vs +Z removes very different amounts of
    /// material (X extent 60 vs Z extent 12). With the old hardcoded-Z bridge both directions bored
    /// up Z, so this discrimination was impossible.
    @Test("Drilling +X vs +Z on the same block removes different material")
    func xAndZBoresDiffer() {
        let original = makeBlock().volume ?? 0

        guard
            let drilledX = makeBlock().drilled(
                at: SIMD3(-31, 0, 0),
                direction: SIMD3(1, 0, 0),
                radius: radius, depth: 0),
            let drilledZ = makeBlock().drilled(
                at: SIMD3(0, 0, 7),
                direction: SIMD3(0, 0, -1),
                radius: radius, depth: 0)
        else {
            Issue.record("drill setup failed")
            return
        }

        let removedX = original - (drilledX.volume ?? 0)
        let removedZ = original - (drilledZ.volume ?? 0)

        // Z bore removes π·r²·12 (thin axis); X bore removes π·r²·60 (wide axis).
        #expect(abs(removedZ - Double.pi * radius * radius * 12.0) < 5.0)
        #expect(abs(removedX - Double.pi * radius * radius * 60.0) < 5.0)
        // The X bore must remove strictly (and substantially) more than the Z bore.
        #expect(removedX > removedZ + 100.0)
    }
}
