import Testing
import simd

@testable import OCCTSwift

// MARK: - #405: the curvature entry points share one tolerance

/// `curvatures(u:v:)` computes exactly what `gaussianCurvature(atU:v:)` and
/// `meanCurvature(atU:v:)` compute, from the same `GeomLProp_SLProps`, but it used to construct
/// that with a hardcoded `1e-6` resolution while the other two used `Precision::Confusion()`
/// (`1e-7`). Since that argument is what `IsCurvatureDefined()` tests tangent vectors against for
/// nullity, the two APIs could disagree about whether curvature is defined at all for the same
/// surface at the same (u, v). They now share one construction.
@Suite("Surface curvature entry points agree (#405)")
struct SurfaceCurvatureParityTests {

    /// A cone with `radius: 0` at the origin: its apex is at `v = 0`, and the tangent magnitude
    /// falls off linearly with `v`, so it sweeps through the resolution threshold smoothly.
    private static func apexCone() -> Surface {
        Surface.cone(origin: .zero, axis: SIMD3(0, 0, 1), radius: 0, semiAngle: .pi / 6)!
    }

    private func expectAgreement(
        _ surface: Surface, u: Double, v: Double,
        _ comment: Comment? = nil
    ) {
        // #595: agreement is now on definedness too, not only on the value -- which is what this
        // suite's own doc comment always claimed and could not assert while all three returned 0.
        let pair = surface.curvatures(u: u, v: v)
        #expect(pair?.gaussian == surface.gaussianCurvature(atU: u, v: v), comment)
        #expect(pair?.mean == surface.meanCurvature(atU: u, v: v), comment)
    }

    @Test("Well-conditioned points agree across all three entry points")
    func wellConditionedPointsAgree() {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
        let cylinder = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 3)!
        let cone = Self.apexCone()

        for (u, v) in [(0.0, 0.0), (Double.pi / 3, 0.4), (1.2, -0.8)] {
            expectAgreement(sphere, u: u, v: v)
            expectAgreement(plane, u: u, v: v)
            expectAgreement(cylinder, u: u, v: v)
        }
        for v in [10.0, 1.0, 0.01] {
            expectAgreement(cone, u: 0, v: v)
        }
    }

    /// The regression proper. On this cone the two resolutions put the "curvature is defined"
    /// threshold a decade apart: `Precision::Confusion()` gives up below v ≈ 2e-7, the old
    /// hardcoded `1e-6` gave up below v ≈ 2e-6. At v = 1e-6, inside that window,
    /// `curvatures(u:v:)` returned (0, 0) for a point where `meanCurvature(atU:v:)` returned
    /// -866025.4.
    @Test("Inside the old tolerance window the two entry points no longer disagree")
    func toleranceWindowAgrees() {
        let cone = Self.apexCone()
        for v in [2e-6, 1e-6, 5e-7, 3e-7] {
            expectAgreement(cone, u: 0, v: v, "cone v=\(v)")
        }

        // v = 1e-6 specifically: curvature IS defined at Precision::Confusion(), and both
        // entry points must now report the same non-zero mean curvature.
        let pair = cone.curvatures(u: 0, v: 1e-6)
        #expect((pair?.mean ?? 0) < -1e5)
        #expect(pair?.mean == cone.meanCurvature(atU: 0, v: 1e-6))
    }

    @Test("Genuinely undefined points return nil from all three entry points")
    func undefinedPointsAgree() {
        let cone = Self.apexCone()
        // #595: was `== 0` on all four, which a plane also satisfies with the curvature defined.
        let pair = cone.curvatures(u: 0, v: 0)  // exactly at the apex
        #expect(pair == nil)
        #expect(cone.gaussianCurvature(atU: 0, v: 0) == nil)
        #expect(cone.meanCurvature(atU: 0, v: 0) == nil)

        // Sphere pole: curvature (unlike the normal) is undefined there for both.
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        expectAgreement(sphere, u: 0, v: .pi / 2)
        expectAgreement(sphere, u: 0, v: -.pi / 2)
    }

    @Test("Domain-boundary evaluation agrees on a BSpline patch")
    func bsplineBoundsAgree() {
        let poles: [[SIMD3<Double>]] = (0..<4).map { i in
            (0..<4).map { j in SIMD3(Double(i), Double(j), Double(i * j) * 0.3) }
        }
        guard let bezier = Surface.bezier(poles: poles) else { return }
        let dom = bezier.domain
        for (u, v) in [(dom.uMin, dom.vMin), (dom.uMax, dom.vMax), (dom.uMin, dom.vMax)] {
            expectAgreement(bezier, u: u, v: v)
        }
    }
}
