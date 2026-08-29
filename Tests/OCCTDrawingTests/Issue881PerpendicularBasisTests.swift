import Foundation
import Testing
import simd

@testable import OCCTSwift

// #881: `projectPointToPlane`/`projectAxisToPlane` used to derive their perpendicular-to-
// `viewDirection` basis the same way as `Placement.init` (Convention A: `worldUp = (0,0,1)`
// unconditionally, falling back to `(0,1,0)` only below a 1e-9 cross-product-magnitude
// threshold). That convention disagreed with the other two call sites, and its doc comment's
// claim to follow "the OCCTSwift HLR convention" was never verified against the `gp_Ax2` OCCT's
// own `HLRAlgo_Projector` actually uses. Both functions now share `perpendicularBasis(to:)`,
// which matches `gp_Ax2` exactly.
//
// Projecting the canonical basis vectors themselves onto the basis `projectPointToPlane` actually
// uses is a direct probe of that basis without reaching into the function's internals: if the
// bases agree, `right` projects to `(1, 0)` and `up` projects to `(0, 1)`.
@Suite("perpendicularBasis unification: Drawing projection (#881)")
struct Issue881DrawingPerpendicularBasisTests {

    @Test("projectPointToPlane's basis matches OCCT's gp_Ax2 canonical basis")
    func projectPointToPlaneMatchesGpAx2() {
        let projectedRight = projectPointToPlane(
            PerpendicularBasisGroundTruth.expectedRight, viewDirection: PerpendicularBasisGroundTruth.nearDegenerate)
        let projectedUp = projectPointToPlane(PerpendicularBasisGroundTruth.expectedUp, viewDirection: PerpendicularBasisGroundTruth.nearDegenerate)
        #expect(abs(projectedRight.x - 1.0) < 1e-9)
        #expect(abs(projectedRight.y) < 1e-9)
        #expect(abs(projectedUp.x) < 1e-9)
        #expect(abs(projectedUp.y - 1.0) < 1e-9)
    }

    @Test("projectAxisToPlane's basis matches OCCT's gp_Ax2 canonical basis")
    func projectAxisToPlaneMatchesGpAx2() {
        // An axis through the origin along `expectedRight`, wide-open bounds so clipping never
        // trims it: it should land exactly on the 2D X axis if the basis matches canonical.
        let bounds = (min: SIMD2<Double>(-100, -100), max: SIMD2<Double>(100, 100))
        guard
            let (p1, p2) = projectAxisToPlane(
                origin: .zero, direction: PerpendicularBasisGroundTruth.expectedRight,
                viewDirection: PerpendicularBasisGroundTruth.nearDegenerate,
                bounds: bounds, overshoot: 0)
        else {
            Issue.record("axis unexpectedly collapsed to a point")
            return
        }
        #expect(abs(p1.y) < 1e-9)
        #expect(abs(p2.y) < 1e-9)
    }
}
