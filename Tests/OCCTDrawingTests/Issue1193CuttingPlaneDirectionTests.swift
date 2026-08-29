import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1193 (Pass 4b duplication audit, #386): `Drawing.addCuttingPlaneLine`'s trace/arrow direction
// blocks projected a 3D direction as `projectPointToPlane(direction, ...) -
// projectPointToPlane(.zero, ...)`, a roundabout point-difference idiom that only produced the
// right answer because `projectPointToPlane` has no translation term of its own; the correct,
// direct recipe (`projectAxisToPlane`'s `dir2`) sat four lines away in the same file
// (`DrawingAutoCenterlines.swift`). No existing test asserted the actual numeric
// `traceStart`/`traceEnd`/`arrowDirection` values `addCuttingPlaneLine` computes
// (`CuttingPlaneLineTests` in `OCCTCurveTests` only checks annotation identity, the degenerate-case
// `nil` return, and DXF entity *counts*), so a one-sided edit to either block, or a future semantic
// change to `projectPointToPlane`/`perpendicularBasis` (e.g. picking up a plane origin), would have
// gone uncaught.
//
// Fixed by extracting `projectDirectionToPlane(_:viewDirection:)`, a plain `simd_dot` against
// `perpendicularBasis(to:)`'s `(right, up)` with no point-difference detour, and routing both
// `addCuttingPlaneLine` blocks *and* `projectAxisToPlane`'s `dir2` through it, so there is one
// canonical "project a direction into the view plane" recipe instead of three.
//
// Ground truth: the same `nearDegenerate` viewDirection and OCCT `gp_Ax2`-verified
// `expectedRight`/`expectedUp` as `Issue881DrawingPerpendicularBasisTests`
// (`Issue881PerpendicularBasisTests.swift`), confirmed there to equal `perpendicularBasis(to:
// nearDegenerate)`'s own `(right, up)` exactly. Every expected value below is derived from those
// two constants with plain vector algebra (`cross`/`dot`, verified independently in Python before
// writing this file), never by calling `projectDirectionToPlane`, `projectPointToPlane`, or
// `perpendicularBasis` from the test itself, so this does not just re-run the code under test with
// different spelling.
@Suite("#1193: addCuttingPlaneLine direction projection")
struct Issue1193CuttingPlaneDirectionTests {

    @Test("projectDirectionToPlane matches OCCT's gp_Ax2 canonical basis")
    func projectDirectionToPlaneMatchesGpAx2() {
        // A direction, not a point: projecting the basis vectors themselves back through the same
        // basis must recover the canonical axes exactly, with no origin term to leak in.
        let projectedRight = projectDirectionToPlane(
            PerpendicularBasisGroundTruth.expectedRight, viewDirection: PerpendicularBasisGroundTruth.nearDegenerate)
        let projectedUp = projectDirectionToPlane(
            PerpendicularBasisGroundTruth.expectedUp, viewDirection: PerpendicularBasisGroundTruth.nearDegenerate)
        #expect(abs(projectedRight.x - 1.0) < 1e-9)
        #expect(abs(projectedRight.y) < 1e-9)
        #expect(abs(projectedUp.x) < 1e-9)
        #expect(abs(projectedUp.y - 1.0) < 1e-9)
    }

    @Test(
        "addCuttingPlaneLine's traceStart/traceEnd/arrowDirection match a hand-derived projection")
    func cuttingPlaneLineDirectionsMatchGroundTruth() {
        // cuttingPlaneNormal = expectedUp and viewDirection = nearDegenerate makes
        // traceDir3D = cross(normalize(cuttingPlaneNormal), normalize(viewDirection))
        //            = cross(expectedUp, nearDegenerate) == expectedRight
        // (the cyclic relation for the right-handed (right, up, view) triad `perpendicularBasis`
        // builds: view x right = up, so up x view = right; confirmed numerically to 1e-15 before
        // writing this test, independent of any OCCTSwift code). Projected onto (right, up) that is
        // exactly (1, 0), so with cuttingPlaneOrigin at the world origin (originInView == (0, 0))
        // and traceLength 60, the trace runs from (-30, 0) to (30, 0).
        //
        // sectionViewDirection = expectedUp makes arrowDir3D == expectedUp directly (no cross
        // product), projecting to exactly (0, 1).
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let drawing = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }

        let ann = drawing.addCuttingPlaneLine(
            label: "A",
            cuttingPlaneOrigin: .zero,
            cuttingPlaneNormal: PerpendicularBasisGroundTruth.expectedUp,
            sectionViewDirection: PerpendicularBasisGroundTruth.expectedUp,
            viewDirection: PerpendicularBasisGroundTruth.nearDegenerate,
            traceLength: 60)

        guard case .cuttingPlaneLine(let cpl)? = ann else {
            Issue.record("expected a .cuttingPlaneLine annotation, got \(String(describing: ann))")
            return
        }

        let expectedStart = SIMD2<Double>(-30, 0)
        let expectedEnd = SIMD2<Double>(30, 0)
        let expectedArrow = SIMD2<Double>(0, 1)

        #expect(
            simd_length(cpl.traceStart - expectedStart) < 1e-9,
            "traceStart \(cpl.traceStart) != expected \(expectedStart)")
        #expect(
            simd_length(cpl.traceEnd - expectedEnd) < 1e-9,
            "traceEnd \(cpl.traceEnd) != expected \(expectedEnd)")
        #expect(
            simd_length(cpl.arrowDirection - expectedArrow) < 1e-9,
            "arrowDirection \(cpl.arrowDirection) != expected \(expectedArrow)")
    }
}
