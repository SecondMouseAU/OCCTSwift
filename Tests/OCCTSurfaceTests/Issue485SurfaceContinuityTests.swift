import Testing
import simd

@testable import OCCTSwift

/// #485, the surface half plus the shared vocabulary. `Surface.continuity` (raw
/// `GeomAbs_Shape` ordinal) and `Surface.surfaceContinuityOrder` (a hand-written switch
/// producing `CN=99, G1=-2, G2=-3`) reported the same `Geom_Surface::Continuity()` call
/// through two encodings that agreed only on C0.
///
/// #398/PR#436 fixed exactly this defect class for `Surface.Continuity` but never extended the
/// census to the `Curve3D`/`Curve2D` siblings or to this second `*Continuity` bridge family,
/// so the three now share one result vocabulary: `ContinuityClass`.
@Suite("Surface measured continuity (#485)")
struct Issue485SurfaceContinuityTests {

    /// A bicubic BSpline surface whose interior U knot carries `multiplicity`, driving the
    /// measured continuity down: mult 1 -> C2, mult 2 -> C1, mult 3 (== degree) -> C0.
    static func bsplineSurface(interiorMultiplicityU multiplicity: Int32) -> Surface? {
        let uCount = 4 + Int(multiplicity)
        let poles: [[SIMD3<Double>]] = (1...uCount).map { i in
            (1...4).map { j in
                SIMD3<Double>(Double(i), Double(j), Double((i + j) % 2))
            }
        }
        return Surface.bspline(
            poles: poles,
            knotsU: [0.0, 0.5, 1.0], multiplicitiesU: [4, multiplicity, 4],
            knotsV: [0.0, 1.0], multiplicitiesV: [4, 4],
            degreeU: 3, degreeV: 3)
    }

    // MARK: - The shared result vocabulary

    @Test("ContinuityClass mirrors the real GeomAbs_Shape ordinals")
    func continuityClassMirrorsGeomAbsShape() {
        // GeomAbs_Shape's declared order interleaves the geometric classes with the parametric
        // ones. This is the whole reason the hand-written switch was wrong.
        #expect(ContinuityClass.c0.rawValue == 0)
        #expect(ContinuityClass.g1.rawValue == 1)
        #expect(ContinuityClass.c1.rawValue == 2)
        #expect(ContinuityClass.g2.rawValue == 3)
        #expect(ContinuityClass.c2.rawValue == 4)
        #expect(ContinuityClass.c3.rawValue == 5)
        #expect(ContinuityClass.cN.rawValue == 6)
        #expect(ContinuityClass.allCases.count == 7)
    }

    @Test("ContinuityClass orders by increasing smoothness")
    func continuityClassOrdersBySmoothness() {
        // Monotonic in smoothness is a property of GeomAbs_Shape worth pinning, not assuming:
        // it is what lets "at least this smooth" be answered by comparison. The pairwise
        // comparisons below are that property; the literal pins iteration order to it too, so
        // `allCases` stays usable as an ascending sequence.
        #expect(ContinuityClass.allCases == [.c0, .g1, .c1, .g2, .c2, .c3, .cN])
        #expect(ContinuityClass.c0 < .g1)
        #expect(ContinuityClass.g1 < .c1)
        #expect(ContinuityClass.c1 < .g2)
        #expect(ContinuityClass.g2 < .c2)
        #expect(ContinuityClass.c2 < .c3)
        #expect(ContinuityClass.c3 < .cN)
    }

    @Test("satisfies() answers a parametric floor without raw-value comparison")
    func satisfiesAnswersParametricFloor() {
        // The idiom this replaces, `continuityOrder >= ParametricContinuity.c2.rawValue`,
        // compared two different encodings. c2 is 4 here and 2 there.
        #expect(ContinuityClass.c2.satisfies(.c2))
        #expect(ContinuityClass.c2.satisfies(.c1))
        #expect(!ContinuityClass.c1.satisfies(.c2))
        #expect(ContinuityClass.cN.satisfies(.c3))
        #expect(ContinuityClass.c0.satisfies(.c0))

        // A geometric class is not a parametric guarantee *above* order zero, however smooth it
        // looks: G1 constrains tangent direction, not the derivative vector. The old encoding
        // made these negative, so `>= 1` threshold checks read them as "worse than C1",
        // accidentally the right answer, by the wrong mechanism, and wrong for `>= -2`.
        //
        // At order zero it *is* a guarantee: G1 entails G0 entails positional continuity, which
        // is what C0 is. This suite originally asserted the opposite; see #623 and
        // `Issue623ContinuityFloorTests` for why that was wrong and for the matrix that pins it.
        #expect(ContinuityClass.g1.satisfies(.c0))
        #expect(!ContinuityClass.g1.satisfies(.c1))
        #expect(!ContinuityClass.g2.satisfies(.c1))
        #expect(ContinuityClass.g1.derivativeOrder == nil)
        #expect(ContinuityClass.g2.derivativeOrder == nil)
        #expect(!ContinuityClass.g1.isParametric)
        #expect(ContinuityClass.c1.isParametric)
        #expect(ContinuityClass.c2.derivativeOrder == 2)
        #expect(ContinuityClass.cN.derivativeOrder == Int.max)
    }

    // MARK: - Measured surfaces

    @Test("Knot multiplicity drives the measured class, at GeomAbs_Shape's own ordinals")
    func knotMultiplicityDrivesMeasuredClass() {
        if let c2 = Self.bsplineSurface(interiorMultiplicityU: 1) {
            #expect(c2.continuityClass == .c2)
            #expect(c2.continuity == 4)  // the old encoding said 2
        }
        if let c1 = Self.bsplineSurface(interiorMultiplicityU: 2) {
            #expect(c1.continuityClass == .c1)
            #expect(c1.continuity == 2)  // the old encoding said 1
        }
        if let c0 = Self.bsplineSurface(interiorMultiplicityU: 3) {
            #expect(c0.continuityClass == .c0)
            #expect(c0.continuity == 0)
        }
    }

    @Test("Analytic surfaces report CN as ordinal 6, not 99")
    func analyticSurfacesReportCN() {
        if let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) {
            #expect(plane.continuityClass == .cN)
            #expect(plane.continuity == 6)
            #expect(plane.continuityClass.satisfies(.c3))
        }
        if let sphere = Surface.sphere(center: .zero, radius: 5) {
            #expect(sphere.continuityClass == .cN)
            #expect(sphere.continuity == 6)
        }
    }

    // Originally compared `continuity` against `surfaceContinuityOrder`, silencing the
    // deprecation warning on the test function. `surfaceContinuityOrder` is unavailable as of
    // #619; the substance moved onto the two properties that survive.
    @Test("continuity and continuityClass agree on the same surface, in every class")
    func bothPropertiesAgree() {
        var checked = 0
        for surface in [
            Self.bsplineSurface(interiorMultiplicityU: 1),
            Self.bsplineSurface(interiorMultiplicityU: 2),
            Self.bsplineSurface(interiorMultiplicityU: 3),
            Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)),
        ].compactMap({ $0 }) {
            #expect(surface.continuity == Int(surface.continuityClass.rawValue))
            #expect(surface.continuity != 99)
            #expect(surface.continuity >= 0 && surface.continuity <= 6)
            checked += 1
        }
        #expect(checked == 4)
    }

    // MARK: - Source compatibility

    @Test("The result vocabulary stays distinct from the two request vocabularies")
    func resultVocabularyStaysDistinct() {
        // #398's load-bearing property: a measured class must never silently substitute for a
        // requested order. They agree numerically at 0/1/2, which is why the types matter.
        #expect(ObjectIdentifier(ContinuityClass.self) != ObjectIdentifier(SurfaceContinuity.self))
        #expect(
            ObjectIdentifier(ContinuityClass.self) != ObjectIdentifier(ParametricContinuity.self))
        #expect(ContinuityClass.c1.rawValue != ParametricContinuity.c1.rawValue)
    }
}
