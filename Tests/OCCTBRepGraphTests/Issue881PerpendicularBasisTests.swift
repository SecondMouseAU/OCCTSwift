import Testing
import Foundation
import simd
@testable import OCCTSwift

// #881: `Placement.init(origin:normal:)` and the `.throughAxis` case body used to derive their
// perpendicular-to-a-direction basis two different, mutually-inconsistent ways, a different
// worldUp fallback threshold, and reversed cross-product operand order (which flips the sign of
// the result even when the worldUp choice happens to agree). Both now share `perpendicularBasis(
// to:)`, which matches OCCT's own `gp_Ax2(gp_Pnt, gp_Dir)` canonical algorithm (smallest-component
// selection, no threshold, no fallback branch) exactly, verified directly against the pinned
// xcframework's `gp_Ax2` for the fixture below.
//
// The fixture is deliberately non-axis-aligned in both X and Y (15° off the Z axis, split 0.6/0.8
// between X and Y) so every one of the old three conventions disagrees with the canonical answer
// here, the pre-existing test suite only ever passed axis-aligned normals, which is why none of
// this was caught (#881's own investigation).
@Suite("perpendicularBasis unification: ConstructionEntity (#881)")
struct Issue881ConstructionPerpendicularBasisTests {
    private static let deg15 = 15.0 * Double.pi / 180.0
    private static let nearDegenerate = SIMD3<Double>(
        sin(deg15) * 0.6, sin(deg15) * 0.8, cos(deg15))

    // Ground truth: OCCT's own `gp_Ax2(gp_Pnt(0,0,0), gp_Dir(nearDegenerate))` constructor
    // (`Libraries/occt-src/.../gp/gp_Ax2.cxx`), measured directly against the pinned xcframework.
    private static let expectedRight = SIMD3<Double>(
        0.0, 0.9777876596251666, -0.20959793101254465)
    private static let expectedUp = SIMD3<Double>(
        -0.987868702146798, 0.03254876181607849, 0.1518420410263285)

    @Test("Placement.init(origin:normal:) matches OCCT's gp_Ax2 canonical basis")
    func placementInitMatchesGpAx2() {
        let p = Placement(origin: .zero, normal: Self.nearDegenerate)
        #expect(simd_length(p.xAxis - Self.expectedRight) < 1e-9)
        #expect(simd_length(p.yAxis - Self.expectedUp) < 1e-9)
    }

    /// `.throughAxis` had zero test coverage before #881 (`grep -rn "\.throughAxis" Tests/`
    /// returned nothing). At `angleDeg: 0` the resolved plane's normal is exactly
    /// `perpendicularBasis(to:)`'s `up`, so this both adds first coverage of the case and pins
    /// the fix.
    @Test(".throughAxis at angle 0 matches the canonical perpendicular basis")
    func throughAxisMatchesCanonicalBasis() {
        guard let wire = Wire.polygon3D([.zero, Self.nearDegenerate * 10], closed: false),
              let shape = Shape.fromWire(wire),
              let graph = BRepGraph(shape: shape) else {
            Issue.record("setup failed")
            return
        }
        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: 0))
        let plane = ConstructionPlane.throughAxis(axis: edgeRef, angleDeg: 0)
        switch graph.resolve(plane) {
        case .success(let p):
            #expect(simd_length(p.zAxis - Self.expectedUp) < 1e-9)
        case .failure(let e):
            Issue.record("resolve failed: \(e)")
        }
    }

    /// Axis-aligned normals were NOT covered by the fixture above (15° off Z) or by any other
    /// test in this suite before this case, a real gap: this PR's own CHANGELOG entry originally
    /// (and wrongly) claimed axis-aligned input was unaffected by the #881 unification, and this
    /// exact gap is why nothing caught that the claim was false (#914 review, finding 1).
    ///
    /// Expected values measured directly against the pinned OCCT xcframework's real
    /// `gp_Ax2(gp_Pnt(0,0,0), gp_Dir(...))` constructor for all six world-axis directions (see
    /// `Scripts/repro/` convention; probe compiled and run against
    /// `Libraries/OCCT.xcframework/macos-arm64`, not derived from this file's own
    /// `perpendicularBasis(to:)` implementation, an independent ground truth, not a tautology).
    /// Confirms world ±Z is the only direction where the basis is unchanged from the pre-#881
    /// per-call-site `cross(worldUp, direction)` construction (its own degenerate-cross fallback
    /// branch already fired there); ±X and ±Y, the most common CAD section-plane normals, both
    /// genuinely change.
    @Test(
        "Placement.init(origin:normal:) matches OCCT's gp_Ax2 canonical basis for every world-axis-aligned normal, not just oblique ones",
        arguments: [
            (SIMD3<Double>(1, 0, 0), SIMD3<Double>(0, 0, 1), SIMD3<Double>(0, -1, 0)),
            (SIMD3<Double>(-1, 0, 0), SIMD3<Double>(0, 0, -1), SIMD3<Double>(0, -1, 0)),
            (SIMD3<Double>(0, 1, 0), SIMD3<Double>(0, 0, 1), SIMD3<Double>(1, 0, 0)),
            (SIMD3<Double>(0, -1, 0), SIMD3<Double>(0, 0, -1), SIMD3<Double>(1, 0, 0)),
            (SIMD3<Double>(0, 0, 1), SIMD3<Double>(1, 0, 0), SIMD3<Double>(0, 1, 0)),
            (SIMD3<Double>(0, 0, -1), SIMD3<Double>(-1, 0, 0), SIMD3<Double>(0, 1, 0)),
        ]
    )
    func placementInitMatchesGpAx2ForAxisAlignedNormals(
        _ fixture: (normal: SIMD3<Double>, expectedX: SIMD3<Double>, expectedY: SIMD3<Double>)
    ) {
        let p = Placement(origin: .zero, normal: fixture.normal)
        #expect(simd_length(p.xAxis - fixture.expectedX) < 1e-9)
        #expect(simd_length(p.yAxis - fixture.expectedY) < 1e-9)
    }
}
