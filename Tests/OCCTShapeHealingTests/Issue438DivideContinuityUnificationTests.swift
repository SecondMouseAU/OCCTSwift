import Testing
@testable import OCCTSwift

// #438: `Shape` exposed `ShapeUpgrade_ShapeDivideContinuity` twice. `divided(at:)` set the
// divider's boundary, pcurve AND surface criteria together (plus `SetSurfaceSegmentMode(true)`);
// `dividedByContinuity(criterion:tolerance:)` set only the boundary criterion, leaving
// pcurve/surface pinned at the class's own C1 constructor default no matter what continuity was
// requested. Measured (Scripts/repro/cluster-d-continuity) as a flat "4 faces" from
// `dividedByContinuity` across every criterion 0..6 on a fixture where `divided(at:)`'s own
// three-criteria behaviour varies (nil/4/4/25 faces at C0/C1/C2/C3) -- the surface criterion, not
// the boundary one, is what actually drives this fixture's split count.
//
// Fixed by widening `divided(at:)` to `divided(at:tolerance:)`, taking `ContinuityLevel` (the
// strict superset only `dividedByContinuity` used to reach) and a `tolerance` parameter, and
// deprecating `dividedByContinuity(criterion:tolerance:)` as a forward to it (removed at v2.0.0,
// #784). This pins the actual fix: the unified bridge call still varies with continuity, against
// numbers measured from the corrected implementation, not merely "the two agree", which would be
// true by construction once one forwarded to the other and would prove nothing about whether the
// fix itself is correct.
@Suite("Issue #438: divided(at:) and dividedByContinuity unified over one OCCT class")
struct Issue438DivideContinuityUnificationTests {

    // Same recipe as Scripts/repro/censuses/ClusterD.swift's own `knotVector`/`kinkedSurfaceShape`:
    // a cubic BSpline surface with a mult-3 interior knot in both U and V, genuinely C0 (not C1)
    // at that knot in both parametric directions. Neither a plain box nor a cylinder works here,
    // both this suite's own `AdvancedHealingTests.divideCylinder` and
    // `ShapeUpgradeDivideContinuityTests.divideBoxContinuity` tolerate nil, and measured, a planar
    // box has no interior surface knots to divide at, and a cylinder's single lateral face is one
    // smooth periodic surface with none either.
    private func kinkedSurfaceFace() -> Shape? {
        let degree = 3, interiorKnots = 4, bumpAt = 2, bumpMult = 3
        var knots: [Double] = [0]
        var mults: [Int32] = [Int32(degree + 1)]
        for i in 1...interiorKnots {
            knots.append(Double(i))
            mults.append(Int32(i == bumpAt ? bumpMult : 1))
        }
        knots.append(Double(interiorKnots + 1))
        mults.append(Int32(degree + 1))
        let poleCount = Int(mults.reduce(0, +)) - degree - 1

        guard let surface = Surface.bspline(
            poles: (0..<poleCount).map { u in
                (0..<poleCount).map { v in
                    SIMD3<Double>(Double(u), Double(v), Double((u + v) % 3) * 0.5)
                }
            },
            knotsU: knots, multiplicitiesU: mults,
            knotsV: knots, multiplicitiesV: mults,
            degreeU: degree, degreeV: degree) else { return nil }
        let bounds = surface.domain
        return Shape.face(from: surface, uRange: bounds.uMin...bounds.uMax, vRange: bounds.vMin...bounds.vMax)
    }

    // MARK: - The actual fix: all three criteria, not just the boundary one

    @Test("divided(at:tolerance:) varies with continuity because it sets all three criteria",
          arguments: [
            (Shape.ContinuityLevel.c0, nil as Int?),
            (.c1, 4), (.c2, 4), (.c3, 25), (.cn, 25),
            // G1/G2 are not recognised by ShapeUpgrade_Split*Continuity::SetCriterion, which
            // falls through to its own C1 default for them (read from Libraries/occt-src), so
            // they are expected to agree with .c1, not to add new behaviour of their own.
            (.g1, 4), (.g2, 4),
          ])
    func dividedVariesWithContinuity(level: Shape.ContinuityLevel, expectedFaces: Int?) throws {
        let face = try #require(kinkedSurfaceFace())
        let result = face.divided(at: level, tolerance: 1e-4)
        #expect(result?.faceCount == expectedFaces)
    }

    @Test("C3 produces a different result from C1, proving the surface criterion is observable")
    func dividedContinuityIsObservable() throws {
        let atC1 = try #require(kinkedSurfaceFace()?.divided(at: .c1, tolerance: 1e-4))
        let atC3 = try #require(kinkedSurfaceFace()?.divided(at: .c3, tolerance: 1e-4))
        #expect(atC1.faceCount != atC3.faceCount)
    }
}
