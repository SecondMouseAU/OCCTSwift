import Testing
import simd
@testable import OCCTSwift

/// #619, the surface half. `Surface.surfaceContinuityOrder` changed from the hand-invented
/// `{C0=0, C1=1, C2=2, C3=3, CN=99, G1=-2, G2=-3}` encoding to the real `GeomAbs_Shape` ordinal
/// under an unchanged `Int` signature, and is retired as of #619. These pin the encoding the
/// surviving spellings report, and the threshold that changed answer.
@Suite("Surface measured continuity encoding after the retirement (#619)")
struct Issue619SurfaceContinuityEncodingTests {

    /// A bicubic BSpline surface whose interior U knot multiplicity drives the measured
    /// continuity: mult 1 -> C2, mult 2 -> C1, mult 3 (== degree) -> C0.
    static func bsplineSurface(interiorMultiplicityU multiplicity: Int32) -> Surface? {
        let uCount = 4 + Int(multiplicity)
        let poles: [[SIMD3<Double>]] = (1...uCount).map { i in
            (1...4).map { j in
                SIMD3<Double>(Double(i), Double(j), Double((i + j) % 2))
            }
        }
        return Surface.bspline(poles: poles,
                               knotsU: [0.0, 0.5, 1.0], multiplicitiesU: [4, multiplicity, 4],
                               knotsV: [0.0, 1.0], multiplicitiesV: [4, 4],
                               degreeU: 3, degreeV: 3)
    }

    @Test("An analytic surface reports CN as ordinal 6, the old encoding's 99 is unreachable")
    func analyticSurfaceReportsCN() {
        var checked = 0
        for surface in [Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)),
                        Surface.sphere(center: .zero, radius: 5)].compactMap({ $0 }) {
            #expect(surface.continuityClass == .cN)
            #expect(surface.continuity == 6)
            #expect(surface.continuity != 99)
            checked += 1
        }
        #expect(checked == 2, "both analytic fixtures must build, or this passes vacuously")
    }

    @Test("A C1 surface reports C1 as ordinal 2, not 1")
    func c1SurfaceReportsOrdinalTwo() {
        guard let c1 = Self.bsplineSurface(interiorMultiplicityU: 2),
              let c2 = Self.bsplineSurface(interiorMultiplicityU: 1) else {
            Issue.record("could not build the BSpline surface fixtures")
            return
        }
        #expect(c1.continuityClass == .c1)
        #expect(c1.continuity == 2)
        #expect(c2.continuityClass == .c2)
        #expect(c2.continuity == 4)
    }

    @Test("The sibling bezierContinuity accessor uses the same encoding, so CN is 6 there too")
    func bezierContinuityUsesTheSameOrdinal() {
        // A separate `(int32_t)Continuity()` cast on `Geom_BezierSurface`, documented as
        // `4 = CN` on its reference page, the same wrong table this issue is about.
        let poles: [[SIMD3<Double>]] = (0..<3).map { i in
            (0..<3).map { j in SIMD3<Double>(Double(i), Double(j), Double((i + j) % 2)) }
        }
        guard let bezier = Surface.bezier(poles: poles) else {
            Issue.record("could not build the Bezier surface fixture")
            return
        }
        #expect(bezier.bezierContinuity == 6)
        #expect(bezier.bezierContinuity != 4)
        #expect(bezier.continuityClass == .cN)
    }

    @Test("A raw threshold of 2 now admits a merely-C1 surface; satisfies(.c2) still refuses it")
    func rawThresholdAdmitsC1WhereSatisfiesRefuses() {
        guard let c1 = Self.bsplineSurface(interiorMultiplicityU: 2) else {
            Issue.record("could not build the C1 BSpline surface fixture")
            return
        }
        #expect(c1.continuity >= 2)                       // the trap, still live
        #expect(!c1.continuityClass.satisfies(.c2))       // the question it meant to ask
        #expect(c1.continuityClass.satisfies(.c1))
    }
}
