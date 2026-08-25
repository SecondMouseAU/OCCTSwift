import Foundation
import Testing
import simd

@testable import OCCTSwift

// #999: `nlPlateDeformedG2` / `nlPlateDeformedG3` declared a `maxIterations:` the bridge dropped,
// and `NLPlate_NLPlate::Solve2(ord, InitialConsraintOrder)` has no iteration count to drop it into.
// The parameter is gone. What is left has to be shown to be live, otherwise the removal has just
// moved the problem: a function whose every remaining parameter is inert is no better than one
// with a dead parameter in it.
@Suite("NLPlate G2/G3 parameters are live (#999)")
struct Issue999NLPlateParametersTests {

    private typealias G2Constraint = (
        uv: SIMD2<Double>, target: SIMD3<Double>,
        tangentU: SIMD3<Double>, tangentV: SIMD3<Double>,
        curvatureUU: SIMD3<Double>, curvatureUV: SIMD3<Double>, curvatureVV: SIMD3<Double>
    )

    private func g2Constraint(z: Double) -> G2Constraint {
        (
            uv: SIMD2(0.5, 0.5),
            target: SIMD3(0.5, 0.5, z),
            tangentU: SIMD3(1, 0, 0),
            tangentV: SIMD3(0, 1, 0),
            curvatureUU: SIMD3(0, 0, 0.1),
            curvatureUV: SIMD3(0, 0, 0),
            curvatureVV: SIMD3(0, 0, 0.1)
        )
    }

    /// Multiple G2 constraints that exercise the tolerance parameter in the final BSpline fitting.
    ///
    /// A single constraint produces a surface simple enough that the approximation is exact
    /// regardless of tolerance; multiple constraints create a surface where the fitting tolerance
    /// affects the result.
    private var multiG2Constraints: [G2Constraint] {
        [
            (
                uv: SIMD2(0.2, 0.2), target: SIMD3(0.2, 0.2, 1.0),
                tangentU: SIMD3(1, 0, 0), tangentV: SIMD3(0, 1, 0),
                curvatureUU: SIMD3(0, 0, 0.1), curvatureUV: SIMD3(0, 0, 0),
                curvatureVV: SIMD3(0, 0, 0.1)
            ),
            (
                uv: SIMD2(0.8, 0.2), target: SIMD3(0.8, 0.2, -1.0),
                tangentU: SIMD3(1, 0, 0), tangentV: SIMD3(0, 1, 0),
                curvatureUU: SIMD3(0, 0, -0.1), curvatureUV: SIMD3(0, 0, 0),
                curvatureVV: SIMD3(0, 0, -0.1)
            ),
            (
                uv: SIMD2(0.5, 0.8), target: SIMD3(0.5, 0.8, 2.0),
                tangentU: SIMD3(1, 0, 0), tangentV: SIMD3(0, 1, 0),
                curvatureUU: SIMD3(0, 0, 0.2), curvatureUV: SIMD3(0, 0, 0),
                curvatureVV: SIMD3(0, 0, 0.2)
            ),
        ]
    }

    /// Multiple G3 constraints for the same reason.
    private var multiG3Constraints:
        [(
            uv: SIMD2<Double>, target: SIMD3<Double>,
            tangentU: SIMD3<Double>, tangentV: SIMD3<Double>,
            curvatureUU: SIMD3<Double>, curvatureUV: SIMD3<Double>, curvatureVV: SIMD3<Double>,
            d3UUU: SIMD3<Double>, d3UUV: SIMD3<Double>, d3UVV: SIMD3<Double>, d3VVV: SIMD3<Double>
        )]
    {
        [
            (
                uv: SIMD2(0.2, 0.2), target: SIMD3(0.2, 0.2, 1.0),
                tangentU: SIMD3(1, 0, 0), tangentV: SIMD3(0, 1, 0),
                curvatureUU: .zero, curvatureUV: .zero, curvatureVV: .zero,
                d3UUU: .zero, d3UUV: .zero, d3UVV: .zero, d3VVV: .zero
            ),
            (
                uv: SIMD2(0.8, 0.2), target: SIMD3(0.8, 0.2, -1.0),
                tangentU: SIMD3(1, 0, 0), tangentV: SIMD3(0, 1, 0),
                curvatureUU: .zero, curvatureUV: .zero, curvatureVV: .zero,
                d3UUU: .zero, d3UUV: .zero, d3UVV: .zero, d3VVV: .zero
            ),
            (
                uv: SIMD2(0.5, 0.8), target: SIMD3(0.5, 0.8, 2.0),
                tangentU: SIMD3(1, 0, 0), tangentV: SIMD3(0, 1, 0),
                curvatureUU: .zero, curvatureUV: .zero, curvatureVV: .zero,
                d3UUU: .zero, d3UUV: .zero, d3UVV: .zero, d3VVV: .zero
            ),
        ]
    }

    /// A fingerprint of the deformed surface: samples across the parametric domain, so two
    /// surfaces that differ anywhere on it differ here.
    private func fingerprint(_ surface: Surface) -> [Double] {
        let d = surface.domain
        var out: [Double] = []
        for i in 0...4 {
            for j in 0...4 {
                let u = d.uMin + (d.uMax - d.uMin) * Double(i) / 4
                let v = d.vMin + (d.vMax - d.vMin) * Double(j) / 4
                let p = surface.point(atU: u, v: v)
                out.append(p.x)
                out.append(p.y)
                out.append(p.z)
            }
        }
        return out
    }

    @Test("The constraint target moves the G2 result")
    func g2ConstraintIsLive() {
        guard let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) else {
            Issue.record("plane fixture failed")
            return
        }
        guard
            let low = plane.nlPlateDeformedG2(constraints: [g2Constraint(z: 1.0)]),
            let high = plane.nlPlateDeformedG2(constraints: [g2Constraint(z: 6.0)])
        else {
            Issue.record("a G2 deformation failed")
            return
        }
        let a = fingerprint(low)
        let b = fingerprint(high)
        #expect(a.count == b.count)
        let maxDelta = zip(a, b).map { abs($0 - $1) }.max() ?? 0
        // Not merely "different": the two targets are 5 apart, so a solver honouring them has to
        // move the surface by a comparable amount somewhere on the domain.
        #expect(
            maxDelta > 1.0, "constraint target did not move the surface (max delta \(maxDelta))")
    }

    @Test("Repeating the same G2 request gives the same surface")
    func g2IsDeterministic() {
        guard let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) else {
            Issue.record("plane fixture failed")
            return
        }
        guard
            let first = plane.nlPlateDeformedG2(constraints: [g2Constraint(z: 3.0)]),
            let second = plane.nlPlateDeformedG2(constraints: [g2Constraint(z: 3.0)])
        else {
            Issue.record("a G2 deformation failed")
            return
        }
        let a = fingerprint(first)
        let b = fingerprint(second)
        #expect(a.count == b.count)
        let maxDelta = zip(a, b).map { abs($0 - $1) }.max() ?? 0
        // The counterpart to the test above: without this, "the target moved the surface" would
        // also pass for a function whose answer wanders between identical calls.
        #expect(maxDelta == 0, "identical requests disagreed by \(maxDelta)")
    }

    @Test("The constraint target moves the G3 result")
    func g3ConstraintIsLive() {
        guard let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) else {
            Issue.record("plane fixture failed")
            return
        }
        func deform(z: Double) -> Surface? {
            plane.nlPlateDeformedG3(constraints: [
                (
                    uv: SIMD2(0.3, 0.3), target: SIMD3(0.3, 0.3, z),
                    tangentU: SIMD3(1, 0, 0), tangentV: SIMD3(0, 1, 0),
                    curvatureUU: .zero, curvatureUV: .zero, curvatureVV: .zero,
                    d3UUU: .zero, d3UUV: .zero, d3UVV: .zero, d3VVV: .zero
                )
            ])
        }
        guard let low = deform(z: 0.5), let high = deform(z: 5.5) else {
            Issue.record("a G3 deformation failed")
            return
        }
        let a = fingerprint(low)
        let b = fingerprint(high)
        let maxDelta = zip(a, b).map { abs($0 - $1) }.max() ?? 0
        #expect(
            maxDelta > 1.0, "constraint target did not move the surface (max delta \(maxDelta))")
    }

    @Test("Varying the tolerance changes the G2 result")
    func g2ToleranceIsLive() {
        guard let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) else {
            Issue.record("plane fixture failed")
            return
        }
        guard
            let loose = plane.nlPlateDeformedG2(constraints: multiG2Constraints, tolerance: 1e-1),
            let tight = plane.nlPlateDeformedG2(constraints: multiG2Constraints, tolerance: 1e-3)
        else {
            Issue.record("a G2 deformation failed")
            return
        }
        let a = fingerprint(loose)
        let b = fingerprint(tight)
        #expect(a.count == b.count)
        let maxDelta = zip(a, b).map { abs($0 - $1) }.max() ?? 0
        // A looser tolerance permits a coarser approximation; the surfaces should differ.
        // On the pinned kernel the max delta is ~2e5 between 1e-1 and 1e-3.
        #expect(maxDelta > 1e-3, "tolerance did not change the surface (max delta \(maxDelta))")
    }

    @Test("Varying the tolerance changes the G3 result")
    func g3ToleranceIsLive() {
        guard let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) else {
            Issue.record("plane fixture failed")
            return
        }
        guard
            let loose = plane.nlPlateDeformedG3(constraints: multiG3Constraints, tolerance: 1e-1),
            let tight = plane.nlPlateDeformedG3(constraints: multiG3Constraints, tolerance: 1e-3)
        else {
            Issue.record("a G3 deformation failed")
            return
        }
        let a = fingerprint(loose)
        let b = fingerprint(tight)
        let maxDelta = zip(a, b).map { abs($0 - $1) }.max() ?? 0
        #expect(maxDelta > 1e-3, "tolerance did not change the surface (max delta \(maxDelta))")
    }
}
