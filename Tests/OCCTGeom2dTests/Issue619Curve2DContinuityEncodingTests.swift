import Testing
import simd
@testable import OCCTSwift

/// #619, the 2D half. `Curve2D.continuityOrder` changed from the hand-invented
/// `{C0=0, C1=1, C2=2, C3=3, CN=99, G1=-2, G2=-3}` encoding to the real `GeomAbs_Shape` ordinal
/// under an unchanged `Int` signature, and is retired as of #619. These pin the encoding the
/// surviving spellings report, and the threshold that changed answer.
@Suite("Curve2D measured continuity encoding after the retirement (#619)")
struct Issue619Curve2DContinuityEncodingTests {

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

    @Test("An analytic 2D curve reports CN as ordinal 6 — the old encoding's 99 is unreachable")
    func analyticCurveReportsCN() {
        guard let segment = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)) else {
            Issue.record("could not build the segment fixture")
            return
        }
        #expect(segment.continuityClass == .cN)
        #expect(segment.continuity == 6)
        #expect(segment.continuity != 99)
    }

    @Test("A C1 pcurve reports C1 as ordinal 2, not 1")
    func c1SplineReportsOrdinalTwo() {
        if let c1 = Self.bspline(interiorMultiplicity: 2) {
            #expect(c1.continuityClass == .c1)
            #expect(c1.continuity == 2)
        }
        if let c2 = Self.bspline(interiorMultiplicity: 1) {
            #expect(c2.continuityClass == .c2)
            #expect(c2.continuity == 4)
        }
    }

    @Test("A raw threshold of 2 now admits a merely-C1 pcurve; satisfies(.c2) still refuses it")
    func rawThresholdAdmitsC1WhereSatisfiesRefuses() {
        guard let c1 = Self.bspline(interiorMultiplicity: 2) else {
            Issue.record("could not build the C1 BSpline fixture")
            return
        }
        #expect(c1.continuity >= 2)                       // the trap, still live
        #expect(!c1.continuityClass.satisfies(.c2))       // the question it meant to ask
        #expect(c1.continuityClass.satisfies(.c1))
    }
}
