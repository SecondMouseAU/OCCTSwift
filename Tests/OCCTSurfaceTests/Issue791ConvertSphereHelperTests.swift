import Testing
import Foundation
@testable import OCCTSwift

/// #791 (the #784 duplication rescan): `OCCTConvertSphereToBSplineSurface` reimplemented the
/// pole/weight/knot-array-building sequence that `buildSurfaceFromElementary` already provides
/// and that its siblings (`OCCTConvertCylinderToBSplineSurface`, `OCCTConvertConeToBSplineSurface`,
/// `OCCTConvertTorusToBSplineSurface`) already call. `Convert_SphereToBSplineSurface` genuinely
/// inherits `Convert_ElementarySurfaceToBSplineSurface` publicly, and every accessor
/// `buildSurfaceFromElementary` calls (`NbUPoles`/`NbVPoles`/`Pole`/`Weight`/`UKnot`/`VKnot`/
/// `UMultiplicity`/`VMultiplicity`/`UDegree`/`VDegree`/`IsUPeriodic`/`IsVPeriodic`) is declared on
/// that base class, confirmed by reading the bundled
/// `Convert_SphereToBSplineSurface.hxx`/`Convert_ElementarySurfaceToBSplineSurface.hxx` headers
/// directly, not assumed from the issue body. `occt-refman` carries the same fact and was
/// unreachable only because this session's `context` connection had dropped, not because the
/// package is missing; `okf/policies/context-first.md` puts refman first and the headers second. So the fix is a
/// drop-in call: `return buildSurfaceFromElementary(conv);`.
///
/// These tests prove the consolidation changed nothing observable, two ways:
///
/// 1. **Exact baseline equality.** `expectedPoles`/`expectedUKnots`/`expectedVKnots` below are a
///    verbatim capture of `Surface.fromSphere`'s output from the UNMODIFIED, pre-#791 inline
///    implementation (captured by a throwaway test run before the `.mm` edit landed, per
///    `okf/policies/measure-dont-assume.md`, not reconstructed after the fact). Every pole,
///    weight and knot is the OCCT converter's own computed value, entirely independent of which
///    C++ function copies it into the output arrays, so exact `==` is the right comparison, not a
///    tolerance: a real regression here would not be a rounding difference, it would be a
///    transcription bug (wrong loop bound, swapped U/V, wrong accessor).
/// 2. **An implementation-independent geometric invariant.** Every sampled point on the returned
///    BSpline surface must sit at exactly `radius` from the sphere's own center, true by the
///    definition of a sphere, regardless of pole/knot layout. This is the same contract
///    `buildSurfaceFromElementary`'s three existing callers (Cylinder/Cone/Torus) already rely on
///    for their own analytic shape, so Sphere passing it through the now-shared helper is measured
///    agreement with those siblings' contract, not just with its own prior self.
@Suite("Issue791 Sphere BSpline helper consolidation")
struct Issue791SphereBSplineHelperTests {

    struct PoleBaseline {
        let i: Int
        let j: Int
        let point: SIMD3<Double>
        let weight: Double
    }

    // Captured verbatim from the pre-#791 inline implementation of
    // OCCTConvertSphereToBSplineSurface(origin: (0,0,0), axis: (0,0,1), radius: 5).
    static let unitOriginPoles: [PoleBaseline] = [
        PoleBaseline(i: 1, j: 1, point: SIMD3(3.061616997868383e-16, 0.0, -5.0), weight: 1.0),
        PoleBaseline(i: 1, j: 2, point: SIMD3(5.0, 0.0, -4.999999999999999), weight: 0.7071067811865476),
        PoleBaseline(i: 1, j: 3, point: SIMD3(5.0, 0.0, 0.0), weight: 1.0),
        PoleBaseline(i: 1, j: 4, point: SIMD3(5.0, 0.0, 4.999999999999999), weight: 0.7071067811865476),
        PoleBaseline(i: 1, j: 5, point: SIMD3(3.061616997868383e-16, 0.0, 5.0), weight: 1.0),
        PoleBaseline(i: 2, j: 1, point: SIMD3(3.061616997868383e-16, 5.302876193624534e-16, -5.0), weight: 0.5),
        PoleBaseline(i: 2, j: 2, point: SIMD3(5.0, 8.660254037844384, -4.999999999999999), weight: 0.3535533905932738),
        PoleBaseline(i: 2, j: 3, point: SIMD3(5.0, 8.660254037844384, 0.0), weight: 0.5),
        PoleBaseline(i: 2, j: 4, point: SIMD3(5.0, 8.660254037844384, 4.999999999999999), weight: 0.3535533905932738),
        PoleBaseline(i: 2, j: 5, point: SIMD3(3.061616997868383e-16, 5.302876193624534e-16, 5.0), weight: 0.5),
        PoleBaseline(i: 3, j: 1, point: SIMD3(-1.530808498934191e-16, 2.6514380968122674e-16, -5.0), weight: 1.0),
        PoleBaseline(i: 3, j: 2, point: SIMD3(-2.499999999999999, 4.330127018922194, -4.999999999999999), weight: 0.7071067811865476),
        PoleBaseline(i: 3, j: 3, point: SIMD3(-2.499999999999999, 4.330127018922194, 0.0), weight: 1.0),
        PoleBaseline(i: 3, j: 4, point: SIMD3(-2.499999999999999, 4.330127018922194, 4.999999999999999), weight: 0.7071067811865476),
        PoleBaseline(i: 3, j: 5, point: SIMD3(-1.530808498934191e-16, 2.6514380968122674e-16, 5.0), weight: 1.0),
        PoleBaseline(i: 4, j: 1, point: SIMD3(-6.123233995736765e-16, 7.498798913309287e-32, -5.0), weight: 0.5),
        PoleBaseline(i: 4, j: 2, point: SIMD3(-9.999999999999998, 1.224646799147353e-15, -4.999999999999999), weight: 0.3535533905932738),
        PoleBaseline(i: 4, j: 3, point: SIMD3(-9.999999999999998, 1.224646799147353e-15, 0.0), weight: 0.5),
        PoleBaseline(i: 4, j: 4, point: SIMD3(-9.999999999999998, 1.224646799147353e-15, 4.999999999999999), weight: 0.3535533905932738),
        PoleBaseline(i: 4, j: 5, point: SIMD3(-6.123233995736765e-16, 7.498798913309287e-32, 5.0), weight: 0.5),
        PoleBaseline(i: 5, j: 1, point: SIMD3(-1.530808498934193e-16, -2.6514380968122664e-16, -5.0), weight: 1.0),
        PoleBaseline(i: 5, j: 2, point: SIMD3(-2.500000000000002, -4.330127018922192, -4.999999999999999), weight: 0.7071067811865476),
        PoleBaseline(i: 5, j: 3, point: SIMD3(-2.500000000000002, -4.330127018922192, 0.0), weight: 1.0),
        PoleBaseline(i: 5, j: 4, point: SIMD3(-2.500000000000002, -4.330127018922192, 4.999999999999999), weight: 0.7071067811865476),
        PoleBaseline(i: 5, j: 5, point: SIMD3(-1.530808498934193e-16, -2.6514380968122664e-16, 5.0), weight: 1.0),
        PoleBaseline(i: 6, j: 1, point: SIMD3(3.0616169978683787e-16, -5.302876193624536e-16, -5.0), weight: 0.5),
        PoleBaseline(i: 6, j: 2, point: SIMD3(4.999999999999992, -8.660254037844389, -4.999999999999999), weight: 0.3535533905932738),
        PoleBaseline(i: 6, j: 3, point: SIMD3(4.999999999999992, -8.660254037844389, 0.0), weight: 0.5),
        PoleBaseline(i: 6, j: 4, point: SIMD3(4.999999999999992, -8.660254037844389, 4.999999999999999), weight: 0.3535533905932738),
        PoleBaseline(i: 6, j: 5, point: SIMD3(3.0616169978683787e-16, -5.302876193624536e-16, 5.0), weight: 0.5),
    ]
    static let unitOriginUKnots: [Double] = [0.0, 2.0943951023931953, 4.1887902047863905, 6.283185307179586]
    static let unitOriginVKnots: [Double] = [-1.5707963267948966, 0.0, 1.5707963267948966]

    // Captured verbatim from the pre-#791 inline implementation of
    // OCCTConvertSphereToBSplineSurface(origin: (3,-2,7), axis: (1,1,1), radius: 2.5).
    static let offsetTiltedPoles: [PoleBaseline] = [
        PoleBaseline(i: 1, j: 1, point: SIMD3(1.5566243270259355, -3.4433756729740645, 5.5566243270259355), weight: 1.0),
        PoleBaseline(i: 1, j: 2, point: SIMD3(3.3243912799923043, -3.4433756729740645, 3.7888573740595666), weight: 0.7071067811865476),
        PoleBaseline(i: 1, j: 3, point: SIMD3(4.767766952966369, -2.0, 5.232233047033631), weight: 1.0),
        PoleBaseline(i: 1, j: 4, point: SIMD3(6.211142625940433, -0.5566243270259357, 6.675608720007696), weight: 0.7071067811865476),
        PoleBaseline(i: 1, j: 5, point: SIMD3(4.4433756729740645, -0.5566243270259355, 8.443375672974064), weight: 1.0),
        PoleBaseline(i: 2, j: 1, point: SIMD3(1.5566243270259355, -3.4433756729740645, 5.5566243270259355), weight: 0.5),
        PoleBaseline(i: 2, j: 2, point: SIMD3(1.5566243270259361, 0.09215823295867231, 2.0210904210931986), weight: 0.3535533905932738),
        PoleBaseline(i: 2, j: 3, point: SIMD3(3.0000000000000004, 1.5355339059327369, 3.4644660940672627), weight: 0.5),
        PoleBaseline(i: 2, j: 4, point: SIMD3(4.4433756729740645, 2.9789095789068014, 4.907841767041328), weight: 0.3535533905932738),
        PoleBaseline(i: 2, j: 5, point: SIMD3(4.4433756729740645, -0.5566243270259352, 8.443375672974064), weight: 0.5),
        PoleBaseline(i: 3, j: 1, point: SIMD3(1.5566243270259352, -3.4433756729740645, 5.5566243270259355), weight: 1.0),
        PoleBaseline(i: 3, j: 2, point: SIMD3(-0.21114262594043343, -1.675608720007695, 5.5566243270259355), weight: 0.7071067811865476),
        PoleBaseline(i: 3, j: 3, point: SIMD3(1.2322330470336311, -0.23223304703363068, 6.999999999999999), weight: 1.0),
        PoleBaseline(i: 3, j: 4, point: SIMD3(2.6756087200076957, 1.2111426259404339, 8.443375672974064), weight: 0.7071067811865476),
        PoleBaseline(i: 3, j: 5, point: SIMD3(4.4433756729740645, -0.5566243270259352, 8.443375672974064), weight: 1.0),
        PoleBaseline(i: 4, j: 1, point: SIMD3(1.5566243270259352, -3.4433756729740645, 5.5566243270259355), weight: 0.5),
        PoleBaseline(i: 4, j: 2, point: SIMD3(-1.9789095789068014, -3.4433756729740637, 9.092158232958672), weight: 0.3535533905932738),
        PoleBaseline(i: 4, j: 3, point: SIMD3(-0.5355339059327373, -1.9999999999999996, 10.535533905932738), weight: 0.5),
        PoleBaseline(i: 4, j: 4, point: SIMD3(0.9078417670413272, -0.5566243270259352, 11.978909578906801), weight: 0.3535533905932738),
        PoleBaseline(i: 4, j: 5, point: SIMD3(4.4433756729740645, -0.5566243270259355, 8.443375672974065), weight: 0.5),
        PoleBaseline(i: 5, j: 1, point: SIMD3(1.5566243270259355, -3.4433756729740645, 5.5566243270259355), weight: 1.0),
        PoleBaseline(i: 5, j: 2, point: SIMD3(1.5566243270259346, -5.2111426259404325, 7.324391279992305), weight: 0.7071067811865476),
        PoleBaseline(i: 5, j: 3, point: SIMD3(2.999999999999999, -3.7677669529663684, 8.767766952966369), weight: 1.0),
        PoleBaseline(i: 5, j: 4, point: SIMD3(4.443375672974064, -2.3243912799923043, 10.211142625940434), weight: 0.7071067811865476),
        PoleBaseline(i: 5, j: 5, point: SIMD3(4.4433756729740645, -0.5566243270259355, 8.443375672974065), weight: 1.0),
        PoleBaseline(i: 6, j: 1, point: SIMD3(1.5566243270259357, -3.4433756729740645, 5.5566243270259355), weight: 0.5),
        PoleBaseline(i: 6, j: 2, point: SIMD3(5.0921582329586705, -6.978909578906803, 5.556624327025939), weight: 0.3535533905932738),
        PoleBaseline(i: 6, j: 3, point: SIMD3(6.535533905932736, -5.5355339059327395, 7.0000000000000036), weight: 0.5),
        PoleBaseline(i: 6, j: 4, point: SIMD3(7.9789095789068, -4.092158232958674, 8.443375672974067), weight: 0.3535533905932738),
        PoleBaseline(i: 6, j: 5, point: SIMD3(4.4433756729740645, -0.5566243270259357, 8.443375672974064), weight: 0.5),
    ]
    static let offsetTiltedUKnots: [Double] = [0.0, 2.0943951023931953, 4.1887902047863905, 6.283185307179586]
    static let offsetTiltedVKnots: [Double] = [-1.5707963267948966, 0.0, 1.5707963267948966]

    @Test func unitOriginMatchesPriorBaseline() throws {
        let s = try #require(Surface.fromSphere(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5))
        assertMatchesBaseline(s, poles: Self.unitOriginPoles, uKnots: Self.unitOriginUKnots, vKnots: Self.unitOriginVKnots)
    }

    @Test func offsetTiltedMatchesPriorBaseline() throws {
        let s = try #require(Surface.fromSphere(origin: SIMD3(3, -2, 7), axis: SIMD3(1, 1, 1), radius: 2.5))
        assertMatchesBaseline(s, poles: Self.offsetTiltedPoles, uKnots: Self.offsetTiltedUKnots, vKnots: Self.offsetTiltedVKnots)
    }

    private func assertMatchesBaseline(_ s: Surface, poles: [PoleBaseline], uKnots: [Double], vKnots: [Double]) {
        let bs = s.bsplineSurface
        #expect(bs.nbUPoles == 6)
        #expect(bs.nbVPoles == 5)
        #expect(bs.uDegree == 2)
        #expect(bs.vDegree == 2)
        #expect(s.isUPeriodic == true)
        #expect(s.isVPeriodic == false)
        #expect(bs.isURational == true)
        #expect(bs.isVRational == true)
        for baseline in poles {
            let p = bs.pole(uIndex: baseline.i, vIndex: baseline.j)
            let w = s.bsplineWeight(uIndex: baseline.i, vIndex: baseline.j)
            #expect(p == baseline.point, "pole(\(baseline.i),\(baseline.j))")
            #expect(w == baseline.weight, "weight(\(baseline.i),\(baseline.j))")
        }
        #expect(s.bsplineUKnots() == uKnots)
        #expect(s.bsplineVKnots() == vKnots)
    }

    // MARK: - Implementation-independent geometric invariant

    /// Every point the returned BSpline surface evaluates to must sit at exactly `radius` from the
    /// sphere's own center, regardless of how the pole/knot arrays were built. This is the same
    /// contract `buildSurfaceFromElementary`'s other three callers (Cylinder/Cone/Torus) already
    /// rely on for their own shape, so Sphere satisfying it through the shared helper is measured
    /// agreement with those siblings, not merely with its own prior implementation.
    @Test func convertedSphereStaysOnTheAnalyticSphere() throws {
        let cases: [(origin: SIMD3<Double>, axis: SIMD3<Double>, radius: Double)] = [
            (SIMD3(0, 0, 0), SIMD3(0, 0, 1), 5),
            (SIMD3(3, -2, 7), SIMD3(1, 1, 1), 2.5),
            (SIMD3(-4, 10, -1), SIMD3(0, 1, 0), 9.75),
        ]
        for c in cases {
            let s = try #require(Surface.fromSphere(origin: c.origin, axis: c.axis, radius: c.radius))
            let bounds = s.parameterBounds
            let uSamples = stride(from: bounds.uMin, through: bounds.uMax, by: (bounds.uMax - bounds.uMin) / 8)
            let vSamples = stride(from: bounds.vMin, through: bounds.vMax, by: (bounds.vMax - bounds.vMin) / 8)
            for u in uSamples {
                for v in vSamples {
                    let p = s.evalD0(u: u, v: v)
                    let d = p - c.origin
                    let dist = (d.x * d.x + d.y * d.y + d.z * d.z).squareRoot()
                    #expect(abs(dist - c.radius) < 1e-6, "u=\(u) v=\(v) dist=\(dist)")
                }
            }
        }
    }
}
