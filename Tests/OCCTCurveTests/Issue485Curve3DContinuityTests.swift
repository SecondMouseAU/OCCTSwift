import Testing
import simd
@testable import OCCTSwift

/// #485: `Curve3D.continuity` and `Curve3D.continuityOrder` wrapped the same
/// `Geom_Curve::Continuity()` call through two incompatible numeric encodings — the real
/// `GeomAbs_Shape` ordinal, and a hand-written switch producing `{C0=0, C1=1, C2=2, C3=3,
/// CN=99, G1=-2, G2=-3}`. C0 was the only class the two agreed on.
///
/// No pre-existing test caught it: every one asserted `>= 0` against a line or a plain BSpline,
/// which is satisfied by both encodings. These pin the real ordinals, prove the two properties
/// now agree, and cover the G1 class no earlier test could reach.
@Suite("Curve3D measured continuity (#485)")
struct Issue485Curve3DContinuityTests {

    // MARK: - Fixtures

    /// A cubic BSpline whose interior knot carries `multiplicity`, which is what drives its
    /// measured continuity: mult 1 -> C2, mult 2 -> C1, mult 3 (== degree) -> C0.
    static func bspline(interiorMultiplicity multiplicity: Int32) -> Curve3D? {
        let poleCount = 4 + Int(multiplicity)
        let poles = (1...poleCount).map { i in
            SIMD3<Double>(Double(i), Double(i % 2) * 2.0, 0)
        }
        return Curve3D.bspline(poles: poles,
                               knots: [0.0, 0.5, 1.0],
                               multiplicities: [4, multiplicity, 4],
                               degree: 3)
    }

    /// A curve that genuinely measures G1 — the class the issue noted was untested anywhere.
    ///
    /// Recipe: a cubic BSpline with its interior knot at full multiplicity is only C0, but if
    /// the three poles around that knot are collinear with unequal spacing, the tangent
    /// *direction* is continuous while its magnitude jumps, so `Geom_BSplineCurve::IsG1` is
    /// true. `Geom_OffsetCurve` checks exactly that when its basis is C0 and latches
    /// `GeomAbs_G1`, which is the only route to a G1 result in the Geom hierarchy: BSplines
    /// themselves only ever report C0...C3 or CN.
    static func offsetOfG1Basis() -> Curve3D? {
        let poles: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(1, 1, 0),
            SIMD3(2, 0, 0),
            SIMD3(3, 0, 0),   // knot pole; poles 3-4-5 collinear along +x ...
            SIMD3(5, 0, 0),   // ... but unequally spaced, so C1 fails and only G1 holds
            SIMD3(6, 1, 0),
            SIMD3(7, 0, 0)
        ]
        guard let basis = Curve3D.bspline(poles: poles,
                                          knots: [0.0, 0.5, 1.0],
                                          multiplicities: [4, 3, 4],
                                          degree: 3) else { return nil }
        return Curve3D.offset(basis: basis, offset: 1.0, dirX: 0, dirY: 0, dirZ: 1)
    }

    // MARK: - The real ordinals

    @Test("Knot multiplicity drives the measured class, at GeomAbs_Shape's own ordinals")
    func knotMultiplicityDrivesMeasuredClass() {
        // The ordinals are the point: C1 is 2 and C2 is 4, not 1 and 2. The old hand-mapped
        // encoding reported 1 and 2 here, which is what made a threshold check misfire.
        if let c2 = Self.bspline(interiorMultiplicity: 1) {
            #expect(c2.continuityClass == .c2)
            #expect(c2.continuity == 4)
        }
        if let c1 = Self.bspline(interiorMultiplicity: 2) {
            #expect(c1.continuityClass == .c1)
            #expect(c1.continuity == 2)
        }
        if let c0 = Self.bspline(interiorMultiplicity: 3) {
            #expect(c0.continuityClass == .c0)
            #expect(c0.continuity == 0)
        }
    }

    @Test("Analytic curves report CN as ordinal 6, not 99")
    func analyticCurvesReportCN() {
        // 99 was the old encoding's CN. Nothing should produce it now.
        if let line = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)) {
            #expect(line.continuityClass == .cN)
            #expect(line.continuity == 6)
        }
        if let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10) {
            #expect(circle.continuityClass == .cN)
            #expect(circle.continuity == 6)
        }
    }

    @Test("A G1-only curve is reachable and reports ordinal 1")
    func g1CurveReportsOrdinalOne() {
        guard let g1 = Self.offsetOfG1Basis() else {
            Issue.record("could not build the G1 offset-curve fixture")
            return
        }
        // The class the old encoding reported as -2.
        #expect(g1.continuityClass == .g1)
        #expect(g1.continuity == 1)
        #expect(g1.continuity > 0)
    }

    // MARK: - The divergence itself

    @Test("continuity and continuityOrder agree on the same curve, in every class")
    @available(*, deprecated, message: "continuityOrder is deprecated; this is the regression guard")
    func bothPropertiesAgree() {
        // This is the comparison no pre-existing test made. Before the fix it failed for every
        // fixture below except the C0 one.
        var checked = 0
        for curve in [Self.bspline(interiorMultiplicity: 1),
                      Self.bspline(interiorMultiplicity: 2),
                      Self.bspline(interiorMultiplicity: 3),
                      Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)),
                      Self.offsetOfG1Basis()].compactMap({ $0 }) {
            #expect(curve.continuity == curve.continuityOrder)
            #expect(curve.continuityOrder == Int(curve.continuityClass.rawValue))
            checked += 1
        }
        #expect(checked == 5, "every fixture should build; the G1 one is the fragile member")
    }

    @Test("The retired encoding's sentinel values never appear")
    @available(*, deprecated, message: "continuityOrder is deprecated; this is the regression guard")
    func retiredSentinelValuesAreGone() {
        for curve in [Self.bspline(interiorMultiplicity: 1),
                      Self.bspline(interiorMultiplicity: 2),
                      Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)),
                      Self.offsetOfG1Basis()].compactMap({ $0 }) {
            #expect(curve.continuityOrder != 99)     // was CN
            #expect(curve.continuityOrder != -2)     // was G1
            #expect(curve.continuityOrder != -3)     // was G2
            #expect(curve.continuityOrder >= 0 && curve.continuityOrder <= 6)
        }
    }
}
