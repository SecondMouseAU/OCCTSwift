import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #914 review, third pass: auto-centermark position agrees with the drawing's own
// projected geometry, not just with perpendicularBasis(to:) in isolation
//
// perpendicularBasis(to:) now backs both `addAutoCentermarks`/`addAutoCentrelines` (via
// `projectPointToPlane`/`projectAxisToPlane`) AND, independently, `Drawing.project`'s own 2D
// frame, `OCCTDrawingCreate` (`OCCTBridge_Modeling.mm`) builds a `gp_Ax2(gp_Pnt(0,0,0),
// viewDir)`-based `HLRAlgo_Projector`, which is exactly the basis `perpendicularBasis(to:)`
// computes. The existing `Issue881PerpendicularBasisTests` suites pin the helper against
// hard-coded `gp_Ax2` constants, which proves the helper matches `gp_Ax2` but not that
// `addAutoCentermarks`'s *output* lands in the same frame `Drawing.project` actually built, a
// future change to only one of the two would go untested (#914 review, third pass, finding 2).
//
// This closes that gap directly: build an off-axis cylinder (base circle centred away from the
// world origin, so a coordinate mixup can't hide behind a degenerate all-zero case), project it,
// and compare `addAutoCentermarks`'s computed centre against the *actual* OCCT-projected circle's
// centre, read from `drawing.visibleEdges`'s own bounding box, not recomputed via
// `perpendicularBasis(to:)` a second time (recomputing the expected value with the same function
// under test would just be `Issue881PerpendicularBasisTests` again, one call removed). The
// cylinder's axis is set to the view direction, so both its circular faces are viewed face-on
// (not edge-on) and project as full, undistorted circles whose bounding-box center is exactly
// their true 2D center.
//
// Proven per okf/policies/prove-the-test-fails.md: temporarily reverted `perpendicularBasis(to:)`
// to the pre-#881 `cross(worldUp, direction)` construction and re-ran, `addAutoCentermarks`
// computed `(10.0, 5.0)`, while `visibleEdges`'s bounding-box center (real OCCT output, untouched
// by the revert) stayed at `(5.0, -10.0)`, a live mismatch, exactly the CHANGELOG's #881 entry's
// worked example. Restored, both agree.
@Suite(
    "#914 review, third pass: auto-centermark position matches the drawing's own projected frame")
struct AutoCentermarkFrameAgreementTests {
    @Test(
        "centermark for an off-axis cylinder matches the projected circle's own bounding-box center"
    )
    func centermarkMatchesProjectedGeometry() {
        // Base circle centred at (0, 10, 5), axis along the view direction (1, 0, 0), so the
        // circular face is viewed face-on, and the circle's world-space offset from the origin
        // means a right/up or sign transposition can't coincidentally still land on the mark.
        guard
            let cyl = Shape.cylinder(
                at: SIMD3(0, 10, 5), direction: SIMD3(1, 0, 0), radius: 5, height: 10),
            let drawing = Drawing.project(cyl, direction: SIMD3(1, 0, 0)),
            let visibleBounds = drawing.visibleEdges?.boundingBox
        else {
            Issue.record("setup failed")
            return
        }

        let projectedCentre = SIMD2(
            (visibleBounds.min.x + visibleBounds.max.x) / 2,
            (visibleBounds.min.y + visibleBounds.max.y) / 2)

        let result = drawing.addAutoCentermarks(from: cyl, viewDirection: SIMD3(1, 0, 0))
        #expect(!result.added.isEmpty, "expected at least one centermark")
        for annotation in result.added {
            guard case .centermark(let mark) = annotation else {
                Issue.record("expected a .centermark annotation, got \(annotation)")
                continue
            }
            let message =
                "centermark at \(mark.centre) does not match the drawing's own projected circle "
                + "center at \(projectedCentre)"
            #expect(simd_length(mark.centre - projectedCentre) < 1e-6, "\(message)")
        }
    }
}
