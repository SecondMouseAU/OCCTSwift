import Testing
@testable import OCCTSwift

// #495, surface side. Same defect and same fix as the curve analyser, see
// Tests/OCCTCurveTests/Issue495AnalysisOrderTests.swift for the mechanism.
//
// Two wrinkles specific to LocalAnalysis_SurfaceContinuity, both measured against the pinned
// kernel and pinned here so they are not rediscovered:
//
//   * Its predicates all gate on IsC0(), so when C0 itself fails the spurious trues were masked
//     by accident. They were not masked when C0 held, which is the ordinary case for two patches
//     that meet, which is when a caller is actually asking.
//   * The `.c2` branch needs a non-zero *second* derivative in both U and V on both surfaces, or
//     it reports NullSecondDerivative and the whole analysis is not done. A plane has none in
//     either direction and a cylinder has none along its axis, so the `.c2` default answers nil
//     for both. A sphere is curved in both directions and is the fixture that reaches C2.

@Suite("Issue #495: surface analysis order selects what is measured")
struct Issue495SurfaceAnalysisOrderTests {

    private func identicalSpheres() -> (Surface, Surface)? {
        guard let s1 = Surface.sphere(center: .zero, radius: 5),
              let s2 = Surface.sphere(center: .zero, radius: 5) else { return nil }
        return (s1, s2)
    }

    private func perpendicularPlanes() -> (Surface, Surface)? {
        guard let s1 = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)),
              let s2 = Surface.plane(origin: .zero, normal: SIMD3(0, 1, 0)) else { return nil }
        return (s1, s2)
    }

    private func analyse(_ pair: (Surface, Surface), _ order: ContinuityClass,
                         at uv: (Double, Double) = (0.5, 0.5)) -> Surface.ContinuityAnalysis? {
        pair.0.continuityWith(pair.1, u1: uv.0, v1: uv.1, u2: uv.0, v2: uv.1, order: order)
    }

    @Test("each order measures exactly its own branch")
    func measuredSetPerOrder() throws {
        let pair = try #require(identicalSpheres())
        let expected: [ContinuityClass: Set<ContinuityClass>] = [
            .c0: [.c0],
            .g1: [.c0, .g1],
            .c1: [.c0, .c1],
            .g2: [.c0, .g1, .g2],
            .c2: [.c0, .c1, .c2],
        ]
        for (order, want) in expected {
            let a = try #require(analyse(pair, order), "order \(order) should analyse")
            #expect(a.measured == want, "order \(order) measured \(a.measured)")
            #expect(a.measured.count < 5, "no order covers all five classes")
        }
    }

    @Test("two planes at right angles do not report continuity they were never asked for")
    func unmeasuredClassesReportNil() throws {
        let pair = try #require(perpendicularPlanes())

        // The two planes touch at the origin, so C0 holds and the IsC0() gate lets the spurious
        // trues through: at order .c0 this used to report isG1/isC1/isG2/isC2 all true for a
        // 90-degree crease.
        let atC0 = try #require(analyse(pair, .c0, at: (0, 0)))
        #expect(atC0.holds(.c0) == true)
        #expect(atC0.holds(.g1) == nil)
        #expect(atC0.holds(.c2) == nil)
        #expect(atC0.isG2 == nil)
        #expect(atC0.g1Angle == -1, "an unmeasured G1 used to answer 0.0 radians")

        // Measured, and correctly false.
        let atG1 = try #require(analyse(pair, .g1, at: (0, 0)))
        #expect(atG1.holds(.g1) == false)
        #expect(atG1.holds(.c1) == nil, "order .g1 never computes C1")
    }

    @Test("the default order does not measure tangency")
    func defaultOrderDoesNotMeasureG1() throws {
        let pair = try #require(identicalSpheres())
        let atDefault = try #require(analyse(pair, .c2))
        #expect(atDefault.measured == [.c0, .c1, .c2])
        #expect(atDefault.holds(.g1) == nil)

        let atG1 = try #require(analyse(pair, .g1))
        #expect(atG1.holds(.g1) == true, "identical spheres are tangent-continuous when asked")
    }

    @Test("order reports the request after saturation")
    func orderReportsTheEffectiveRequest() throws {
        let pair = try #require(identicalSpheres())
        let atG2 = try #require(analyse(pair, .g2))
        #expect(atG2.order == .g2)
        let beyond = try #require(analyse(pair, .cN))
        #expect(beyond.order == .c2)
        #expect(beyond.measured == [.c0, .c1, .c2])
    }

    @Test("the flags bitmask never claims a bit outside the measured set")
    func flagsStayInsideMeasured() throws {
        let pair = try #require(identicalSpheres())
        for order in [ContinuityClass.c0, .g1, .c1, .g2, .c2] {
            guard let a = analyse(pair, order) else { continue }
            var measuredMask = 0
            for c in a.measured { measuredMask |= c.analysisFlagBit }
            #expect(a.flags & ~measuredMask == 0,
                    "order \(order) set flags \(a.flags) outside measured \(a.measured)")
        }
    }

    @Test("the .c2 default cannot analyse a surface with no second derivative")
    func c2NeedsCurvatureInBothDirections() throws {
        // Not a regression, an OCCT precondition (LocalAnalysis_NullSecondDerivative) that the
        // default order walks straight into for the two most common elementary surfaces. Ask for
        // .c1 or .g1 on planar or ruled geometry.
        let planes = try #require(perpendicularPlanes())
        #expect(analyse(planes, .c2, at: (0, 0)) == nil, "a plane has no second derivative")
        #expect(analyse(planes, .c1, at: (0, 0)) != nil, "C1 only needs the first derivative")

        let cyl = try #require(Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5))
        let cyl2 = try #require(Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5))
        #expect(cyl.continuityWith(cyl2, u1: 0.5, v1: 1, u2: 0.5, v2: 1, order: .c2) == nil,
                "a cylinder is straight along its axis, so D2V is null")
        #expect(cyl.continuityWith(cyl2, u1: 0.5, v1: 1, u2: 0.5, v2: 1, order: .g2) != nil)
    }
}
