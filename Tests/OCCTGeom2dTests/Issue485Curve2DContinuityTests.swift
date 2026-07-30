import Testing
import simd
@testable import OCCTSwift

/// #485, the 2D half: `Curve2D.continuity` (raw `GeomAbs_Shape` ordinal) and
/// `Curve2D.continuityOrder` (a hand-written switch producing `CN=99, G1=-2, G2=-3`) reported
/// the same `Geom2d_Curve::Continuity()` call through two encodings that agreed only on C0.
@Suite("Curve2D measured continuity (#485)")
struct Issue485Curve2DContinuityTests {

    /// Cubic BSpline whose interior knot multiplicity sets its measured continuity:
    /// mult 1 -> C2, mult 2 -> C1, mult 3 (== degree) -> C0.
    static func bspline(interiorMultiplicity multiplicity: Int32) -> Curve2D? {
        let poleCount = 4 + Int(multiplicity)
        let poles = (1...poleCount).map { i in
            SIMD2<Double>(Double(i), Double(i % 2) * 2.0)
        }
        return Curve2D.bspline(poles: poles,
                               knots: [0.0, 0.5, 1.0],
                               multiplicities: [4, multiplicity, 4],
                               degree: 3)
    }

    /// A genuinely G1 2D curve: offset of a C0-but-tangent-continuous basis. See the 3D
    /// sibling's `offsetOfG1Basis()` for why this is the only route to a G1 measurement.
    static func offsetOfG1Basis() -> Curve2D? {
        let poles: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0),
            SIMD2(3, 0),   // knot pole; 3-4-5 collinear along +x, unequally spaced
            SIMD2(5, 0),
            SIMD2(6, 1), SIMD2(7, 0)
        ]
        guard let basis = Curve2D.bspline(poles: poles,
                                          knots: [0.0, 0.5, 1.0],
                                          multiplicities: [4, 3, 4],
                                          degree: 3) else { return nil }
        return basis.offset(by: 1.0)
    }

    @Test("Knot multiplicity drives the measured class, at GeomAbs_Shape's own ordinals")
    func knotMultiplicityDrivesMeasuredClass() {
        if let c2 = Self.bspline(interiorMultiplicity: 1) {
            #expect(c2.continuityClass == .c2)
            #expect(c2.continuity == 4)          // the old encoding said 2
        }
        if let c1 = Self.bspline(interiorMultiplicity: 2) {
            #expect(c1.continuityClass == .c1)
            #expect(c1.continuity == 2)          // the old encoding said 1
        }
        if let c0 = Self.bspline(interiorMultiplicity: 3) {
            #expect(c0.continuityClass == .c0)
            #expect(c0.continuity == 0)
        }
    }

    @Test("Analytic 2D curves report CN as ordinal 6, not 99")
    func analyticCurvesReportCN() {
        if let segment = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)) {
            #expect(segment.continuityClass == .cN)
            #expect(segment.continuity == 6)
        }
    }

    @Test("A G1-only 2D curve is reachable and reports ordinal 1")
    func g1CurveReportsOrdinalOne() {
        guard let g1 = Self.offsetOfG1Basis() else {
            Issue.record("could not build the G1 offset-curve fixture")
            return
        }
        #expect(g1.continuityClass == .g1)
        #expect(g1.continuity == 1)      // the old encoding said -2
    }

    @Test("continuity and continuityOrder agree on the same curve, in every class")
    @available(*, deprecated, message: "continuityOrder is deprecated; this is the regression guard")
    func bothPropertiesAgree() {
        var checked = 0
        for curve in [Self.bspline(interiorMultiplicity: 1),
                      Self.bspline(interiorMultiplicity: 2),
                      Self.bspline(interiorMultiplicity: 3),
                      Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)),
                      Self.offsetOfG1Basis()].compactMap({ $0 }) {
            #expect(curve.continuity == curve.continuityOrder)
            #expect(curve.continuityOrder == Int(curve.continuityClass.rawValue))
            #expect(curve.continuityOrder != 99)
            #expect(curve.continuityOrder != -2)
            checked += 1
        }
        #expect(checked == 5)
    }
}
