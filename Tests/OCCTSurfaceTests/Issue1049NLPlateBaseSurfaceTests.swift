import Testing

@testable import OCCTSwift

// #1049: `NLPlate_NLPlate::Evaluate` returns the absolute deformed point, not a displacement, so
// `nlPlateDeformed` and `nlPlateDeformedG1` adding the input surface to it put every result at
// twice its distance from the origin. #1046: all five entry points then fitted the samples onto
// [0, 1] x [0, 1], so the (u, v) the constraints were written in addressed nothing on the output.
//
// Every fixture here sits at x = 100 rather than on the origin. The three shipped
// `NLPlateDeformationTests` fixtures are planes through the origin asserting `!= nil`, `isFinite`
// and `uMax > uMin`, and none of them can see either defect: the base of a plane through the
// origin is (u, v, 0), which is only zero at uv (0,0), so doubling stretches the patch by two
// rather than translating it, and no shipped test asserted a coordinate at all.
//
// Measured before and after in Scripts/repro/1049-nlplate-double-base.
@Suite("NLPlate keeps the input surface's position and parametrisation (#1049, #1046)")
struct Issue1049NLPlateBaseSurfaceTests {

    /// The plane through (100, 0, 0) with normal +Z, whose own parametrisation the tests below
    /// depend on and therefore measure rather than assume.
    private func offOriginPlane() -> Surface? {
        Surface.plane(origin: SIMD3(100, 0, 0), normal: SIMD3(0, 0, 1))
    }

    /// The working domain the bridge derives for a constraint at uv (0,0) on an unbounded
    /// surface: the constraint span, zero wide, padded by the fixed 10 in each direction.
    private static let workingDomain = (uMin: -10.0, uMax: 10.0, vMin: -10.0, vMax: 10.0)

    private func sampleGrid(_ body: (Double, Double) -> Void) {
        for i in 0...8 {
            for j in 0...8 {
                let u = Self.workingDomain.uMin + 20.0 * Double(i) / 8.0
                let v = Self.workingDomain.vMin + 20.0 * Double(j) / 8.0
                body(u, v)
            }
        }
    }

    // The fixture has to mean its own name before anything downstream can. Geom_Plane's own
    // parametrisation for this axis placement is (100 + u, v, 0), and every expected value below
    // is written in terms of it.
    @Test("The fixture plane is parametrised as (100 + u, v, 0)")
    func fixtureParametrisationIsWhatTheTestsAssume() {
        guard let plane = offOriginPlane() else {
            Issue.record("plane fixture failed")
            return
        }
        let origin = plane.point(atU: 0, v: 0)
        #expect(abs(origin.x - 100) < 1e-9)
        #expect(abs(origin.y) < 1e-9)
        #expect(abs(origin.z) < 1e-9)

        let offset = plane.point(atU: 3, v: 4)
        #expect(abs(offset.x - 103) < 1e-9)
        #expect(abs(offset.y - 4) < 1e-9)
        #expect(abs(offset.z) < 1e-9)
    }

    /// The largest distance between a deformed surface and the input plane, walked over the
    /// working domain at the same (u, v) on both.
    private func deviationFromInput(_ deformed: Surface, _ input: Surface) -> Double {
        var worst = 0.0
        sampleGrid { u, v in
            let d = deformed.point(atU: u, v: v) - input.point(atU: u, v: v)
            worst = max(worst, (d.x * d.x + d.y * d.y + d.z * d.z).squareRoot())
        }
        return worst
    }

    // The closed-form case. A G0 constraint asks for `target`, and NLPlate_NLPlate::Iterate loads
    // `G0Target() - Evaluate(uv)` as the plate's pinpoint load, so a target that is already the
    // base surface's own point there gives a zero load, a plate that is identically zero, and a
    // deformed surface equal to the input.
    //
    // `deviationFromInput` compares the two at the same numeric (u, v), which is the property a
    // caller has. Measured 2.85e-14 for all five after the fix. Against origin/main G0 and G1
    // report 110.4536101718726, exactly |base(10, 10)| = sqrt(110^2 + 10^2), the base surface
    // counted a second time at a corner of the working domain. G2, G3 and the incremental solver
    // report only 7.83e-06 on this same metric, because their hardcoded [0, 1] sampling happened to
    // put the fit's own parameter and the working parameter on the same numbers over [0, 1] and a
    // plane extrapolates linearly outside them. `theOutputCarriesTheWorkingDomain` is what pins
    // those three; this test is not carrying them on 7.83e-06.
    //
    // The repro's own table reports 14.1421356237 for those three instead. That is a different
    // metric, walking both domains end to end in step rather than at the same (u, v), and the two
    // are deliberately not mixed.
    @Test("An identity constraint returns the input surface, G0")
    func identityConstraintIsANoOpG0() {
        guard let plane = offOriginPlane() else {
            Issue.record("plane fixture failed")
            return
        }
        guard
            let deformed = plane.nlPlateDeformed(
                constraints: [(uv: SIMD2(0, 0), target: SIMD3(100, 0, 0))],
                resolutionOrder: 4, tolerance: 1e-3)
        else {
            Issue.record("G0 identity deformation failed")
            return
        }
        #expect(deviationFromInput(deformed, plane) < 1e-9)
    }

    @Test("An identity constraint returns the input surface, G1")
    func identityConstraintIsANoOpG1() {
        guard let plane = offOriginPlane() else {
            Issue.record("plane fixture failed")
            return
        }
        guard
            let deformed = plane.nlPlateDeformedG1(
                constraints: [
                    (
                        uv: SIMD2(0, 0), target: SIMD3(100, 0, 0),
                        tangentU: SIMD3(1, 0, 0), tangentV: SIMD3(0, 1, 0)
                    )
                ],
                resolutionOrder: 4, tolerance: 1e-3)
        else {
            Issue.record("G1 identity deformation failed")
            return
        }
        #expect(deviationFromInput(deformed, plane) < 1e-9)
    }

    @Test("An identity constraint returns the input surface, G2")
    func identityConstraintIsANoOpG2() {
        guard let plane = offOriginPlane() else {
            Issue.record("plane fixture failed")
            return
        }
        guard
            let deformed = plane.nlPlateDeformedG2(
                constraints: [
                    (
                        uv: SIMD2(0, 0), target: SIMD3(100, 0, 0),
                        tangentU: SIMD3(1, 0, 0), tangentV: SIMD3(0, 1, 0),
                        curvatureUU: .zero, curvatureUV: .zero, curvatureVV: .zero
                    )
                ],
                tolerance: 1e-3)
        else {
            Issue.record("G2 identity deformation failed")
            return
        }
        #expect(deviationFromInput(deformed, plane) < 1e-9)
    }

    @Test("An identity constraint returns the input surface, G3")
    func identityConstraintIsANoOpG3() {
        guard let plane = offOriginPlane() else {
            Issue.record("plane fixture failed")
            return
        }
        guard
            let deformed = plane.nlPlateDeformedG3(
                constraints: [
                    (
                        uv: SIMD2(0, 0), target: SIMD3(100, 0, 0),
                        tangentU: SIMD3(1, 0, 0), tangentV: SIMD3(0, 1, 0),
                        curvatureUU: .zero, curvatureUV: .zero, curvatureVV: .zero,
                        d3UUU: .zero, d3UUV: .zero, d3UVV: .zero, d3VVV: .zero
                    )
                ],
                tolerance: 1e-3)
        else {
            Issue.record("G3 identity deformation failed")
            return
        }
        #expect(deviationFromInput(deformed, plane) < 1e-9)
    }

    @Test("An identity constraint returns the input surface, incremental")
    func identityConstraintIsANoOpIncremental() {
        guard let plane = offOriginPlane() else {
            Issue.record("plane fixture failed")
            return
        }
        guard
            let deformed = plane.nlPlateDeformedIncremental(
                constraints: [(uv: SIMD2(0, 0), target: SIMD3(100, 0, 0))])
        else {
            Issue.record("incremental identity deformation failed")
            return
        }
        #expect(deviationFromInput(deformed, plane) < 1e-9)
    }

    // The identity tests above are no-ops by construction, so on their own they would also pass
    // for a function that ignored its constraints entirely. This one asks for a real deformation
    // and checks two things the doubling cannot both satisfy: the deformed surface still carries
    // the base plane's own x and y, because a target differing from the base only in z gives a
    // pinpoint load with no x or y component, and the surface has actually moved in z.
    //
    // Measured: worst |x - (100 + u)| and |y - v| is 2.84e-14 and max |z| is exactly 5. Against
    // origin/main the same two are 470.0000073 and 5.0000001.
    @Test("A pure-Z constraint moves z and leaves x and y alone")
    func pureZConstraintLeavesXAndYAlone() {
        guard let plane = offOriginPlane() else {
            Issue.record("plane fixture failed")
            return
        }
        guard
            let deformed = plane.nlPlateDeformed(
                constraints: [(uv: SIMD2(0, 0), target: SIMD3(100, 0, 5))],
                resolutionOrder: 4, tolerance: 1e-3)
        else {
            Issue.record("G0 deformation failed")
            return
        }

        var worstInPlane = 0.0
        var maxAbsZ = 0.0
        sampleGrid { u, v in
            let p = deformed.point(atU: u, v: v)
            worstInPlane = max(worstInPlane, max(abs(p.x - (100 + u)), abs(p.y - v)))
            maxAbsZ = max(maxAbsZ, abs(p.z))
        }
        #expect(worstInPlane < 1e-9)
        #expect(maxAbsZ > 4.0)
    }

    // #1046. The constraint is written in the input surface's (u, v), so that same (u, v) has to
    // address the same place on the result. Against origin/main the output was on [0, 1] x [0, 1]
    // and this evaluated to (180, -20, 5), a corner of the doubled patch.
    @Test("The constrained point is where the caller asked for it")
    func theConstrainedPointIsAtTheCallersOwnUV() {
        guard let plane = offOriginPlane() else {
            Issue.record("plane fixture failed")
            return
        }
        guard
            let deformed = plane.nlPlateDeformed(
                constraints: [(uv: SIMD2(0, 0), target: SIMD3(100, 0, 5))],
                resolutionOrder: 4, tolerance: 1e-3)
        else {
            Issue.record("G0 deformation failed")
            return
        }
        let p = deformed.point(atU: 0, v: 0)
        #expect(abs(p.x - 100) < 1e-6)
        #expect(abs(p.y) < 1e-6)
        #expect(abs(p.z - 5) < 1e-6)
    }

    private func expectWorkingDomain(_ deformed: Surface, _ label: String) {
        let domain = deformed.domain
        #expect(abs(domain.uMin - Self.workingDomain.uMin) < 1e-9, "\(label) uMin")
        #expect(abs(domain.uMax - Self.workingDomain.uMax) < 1e-9, "\(label) uMax")
        #expect(abs(domain.vMin - Self.workingDomain.vMin) < 1e-9, "\(label) vMin")
        #expect(abs(domain.vMax - Self.workingDomain.vMax) < 1e-9, "\(label) vMax")
    }

    // #1046, on all five entry points, because they were wrong in two different ways and this is
    // the property they share. The returned domain is the working domain the samples were taken
    // over, not [0, 1]. For an unbounded input that is the constraint span padded by 10 in each
    // direction. G2, G3 and the incremental solver additionally sampled a hardcoded
    // [0, 1] x [0, 1] rather than the working domain, so for them this pins the sampling too.
    @Test("The output carries the working domain, not [0, 1]")
    func theOutputCarriesTheWorkingDomain() {
        guard let plane = offOriginPlane() else {
            Issue.record("plane fixture failed")
            return
        }
        let target = SIMD3<Double>(100, 0, 5)

        if let g0 = plane.nlPlateDeformed(
            constraints: [(uv: SIMD2(0, 0), target: target)],
            resolutionOrder: 4, tolerance: 1e-3)
        {
            expectWorkingDomain(g0, "G0")
        } else {
            Issue.record("G0 deformation failed")
        }

        if let g1 = plane.nlPlateDeformedG1(
            constraints: [
                (
                    uv: SIMD2(0, 0), target: target,
                    tangentU: SIMD3(1, 0, 0), tangentV: SIMD3(0, 1, 0)
                )
            ],
            resolutionOrder: 4, tolerance: 1e-3)
        {
            expectWorkingDomain(g1, "G1")
        } else {
            Issue.record("G1 deformation failed")
        }

        if let g2 = plane.nlPlateDeformedG2(
            constraints: [
                (
                    uv: SIMD2(0, 0), target: target,
                    tangentU: SIMD3(1, 0, 0), tangentV: SIMD3(0, 1, 0),
                    curvatureUU: .zero, curvatureUV: .zero, curvatureVV: .zero
                )
            ],
            tolerance: 1e-3)
        {
            expectWorkingDomain(g2, "G2")
        } else {
            Issue.record("G2 deformation failed")
        }

        if let g3 = plane.nlPlateDeformedG3(
            constraints: [
                (
                    uv: SIMD2(0, 0), target: target,
                    tangentU: SIMD3(1, 0, 0), tangentV: SIMD3(0, 1, 0),
                    curvatureUU: .zero, curvatureUV: .zero, curvatureVV: .zero,
                    d3UUU: .zero, d3UUV: .zero, d3UVV: .zero, d3VVV: .zero
                )
            ],
            tolerance: 1e-3)
        {
            expectWorkingDomain(g3, "G3")
        } else {
            Issue.record("G3 deformation failed")
        }

        if let incremental = plane.nlPlateDeformedIncremental(
            constraints: [(uv: SIMD2(0, 0), target: target)])
        {
            expectWorkingDomain(incremental, "incremental")
        } else {
            Issue.record("incremental deformation failed")
        }
    }

    // #1046, the half a plane cannot show. A cylinder bounds its own u at [0, 2pi] and leaves
    // only v unbounded, so only v is derived from the constraints. Against origin/main both
    // directions were replaced and the output was on [0, 1] x [0, 1], putting the caller's own
    // u = pi/2 outside the domain of the surface it had just been handed.
    @Test("A bounded direction keeps the input surface's own range")
    func aBoundedDirectionIsNotDerivedFromTheConstraints() {
        guard
            let cylinder = Surface.cylinder(
                origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 10)
        else {
            Issue.record("cylinder fixture failed")
            return
        }
        let quarterTurn = Double.pi / 2
        guard
            let deformed = cylinder.nlPlateDeformed(
                constraints: [(uv: SIMD2(quarterTurn, 0), target: SIMD3(0, 12, 0))],
                resolutionOrder: 4, tolerance: 1e-3)
        else {
            Issue.record("cylinder deformation failed")
            return
        }
        let domain = deformed.domain
        #expect(abs(domain.uMin) < 1e-9)
        #expect(abs(domain.uMax - 2 * Double.pi) < 1e-9)
        #expect(domain.vMin <= 0 && domain.vMax >= 0)
        // The parameter the constraint was written at is addressable on the result.
        #expect(quarterTurn >= domain.uMin && quarterTurn <= domain.uMax)
    }
}
