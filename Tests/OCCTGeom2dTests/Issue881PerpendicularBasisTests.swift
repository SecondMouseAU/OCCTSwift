import Testing
import Foundation
import simd
@testable import OCCTSwift

// #881: `Shape.sectionPlaneBasis(normal:explicitU:)`'s auto-derive branch (no `explicitU`
// supplied) used a third, independently-inconsistent convention. Convention B's z-threshold
// `worldUp` switch, combined with Convention A's magnitude-based fallback and cross-product
// operand order, but a different fallback vector again ((1,0,0) instead of (0,1,0)). It now
// shares `perpendicularBasis(to:)`, matching `gp_Ax2` exactly, same as `Placement.init` and
// `projectPointToPlane`/`projectAxisToPlane`.
@Suite("perpendicularBasis unification: Section2D (#881)")
struct Issue881SectionPerpendicularBasisTests {
    private static let deg15 = 15.0 * Double.pi / 180.0
    private static let nearDegenerate = SIMD3<Double>(
        sin(deg15) * 0.6, sin(deg15) * 0.8, cos(deg15))

    // Ground truth: OCCT's own `gp_Ax2(gp_Pnt(0,0,0), gp_Dir(nearDegenerate))` constructor,
    // measured directly against the pinned xcframework (same fixture as the ConstructionEntity
    // and Drawing siblings of this test).
    private static let expectedU = SIMD3<Double>(
        0.0, 0.9777876596251666, -0.20959793101254465)
    private static let expectedV = SIMD3<Double>(
        -0.987868702146798, 0.03254876181607849, 0.1518420410263285)

    @Test("sectionPlaneBasis's auto-derived (u, v) matches OCCT's gp_Ax2 canonical basis")
    func autoDerivedBasisMatchesGpAx2() {
        let (u, v) = Shape.sectionPlaneBasis(normal: Self.nearDegenerate, explicitU: nil)
        #expect(simd_length(u - Self.expectedU) < 1e-9)
        #expect(simd_length(v - Self.expectedV) < 1e-9)
    }

    @Test("sectionPlaneBasis with an explicitU is unaffected by the unification")
    func explicitUBasisUnchanged() {
        // explicitU sidesteps perpendicularBasis(to:) entirely, the Gram-Schmidt
        // orthogonalisation against the supplied vector is untouched by #881.
        let explicit = SIMD3<Double>(1, 1, 0)
        let (u, v) = Shape.sectionPlaneBasis(normal: Self.nearDegenerate, explicitU: explicit)
        #expect(abs(simd_length(u) - 1.0) < 1e-9)
        #expect(abs(simd_dot(u, simd_normalize(Self.nearDegenerate))) < 1e-9)
        #expect(simd_length(v - simd_normalize(simd_cross(simd_normalize(Self.nearDegenerate), u))) < 1e-9)
    }
}
