import Foundation
import Testing

@testable import OCCTSwift

// MARK: - #2876: the gap between two parallel surfaces is real, and now reachable

/// `Surface.minDistance(to:uvBounds1:uvBounds2:)` wraps
/// `GeomAPI_ExtremaSurfaceSurface::LowerDistance()` and reads nothing else.
///
/// That is the whole design. `LowerDistance()` is `sqrt(myExtSS.SquareDistance(myIndex))`, so it
/// reads `Extrema_ExtSS::mySqDist`, which the analytic parallel branch does populate, while
/// `NearestPoints()` and `LowerDistanceParameters()` read `myPOnS1`/`myPOnS2`, which it leaves
/// empty (#2840). `Surface.extrema(to:)` reads all three and therefore has to refuse a parallel
/// pair; this reads one and does not.
///
/// Measured in `Scripts/repro/2876/probe.mm` against a kernel without carried patch `0044`, which
/// is the pinned state: two `Geom_Plane`s 5 apart give `IsParallel()` true, `NbExtrema()` 1 and
/// `LowerDistance()` exactly 5, over a trimmed UV square and over the planes' own natural domain
/// alike, while `NearestPoints()` on the same object exits 139.
///
/// Reporting a distance with no points is OCCT's own behaviour: `GeometryTest_APICommands.cxx:631`,
/// the `extrema` Draw command, branches on `IsParallel()` and prints
/// `Infinite number of extremas, distance = ...` from `LowerDistance()` alone.
///
/// The three outcomes these tests have to keep apart, which is what #2876 asked for:
///
///   - a distance reported with no points, which is the parallel case,
///   - nothing reported at all, which is `nil`, and
///   - a fabricated zero, which is what an unmeasured value would look like.
@Suite("Surface.minDistance reports the gap extrema cannot (#2876)")
struct Issue2876ParallelSurfaceDistanceTests {

    private static let gap = 5.0
    private static let square = (uMin: -10.0, uMax: 10.0, vMin: -10.0, vMax: 10.0)

    private static func parallelPlanes() throws -> (Surface, Surface) {
        (
            try #require(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))),
            try #require(Surface.plane(origin: SIMD3(0, 0, gap), normal: SIMD3(0, 0, 1)))
        )
    }

    // MARK: - Distance reported, points absent

    @Test("Parallel planes report their gap, over explicit finite UV bounds")
    func parallelPlanesFiniteBounds() throws {
        let (a, b) = try Self.parallelPlanes()
        let d = try #require(a.minDistance(to: b, uvBounds1: Self.square, uvBounds2: Self.square))
        #expect(abs(d - Self.gap) < 1e-7)
    }

    @Test("Parallel planes report their gap over their own natural domain")
    func parallelPlanesNaturalDomain() throws {
        // The nil-bounds path, which substitutes each plane's own domain. A Geom_Plane's is
        // +/-2e100, and the parallel verdict and the distance are the same there.
        let (a, b) = try Self.parallelPlanes()
        let d = try #require(a.minDistance(to: b))
        #expect(abs(d - Self.gap) < 1e-7)
    }

    @Test("The same pair through extrema(to:) still refuses")
    func extremaStillRefusesTheSamePair() throws {
        // The pair that makes this issue's point, in one test: the same two surfaces, over the same
        // bounds, answered by one entry point and refused by the other. If this ever stops being
        // nil the guard #2840 put in has gone, and that is a SIGSEGV rather than a red assertion.
        let (a, b) = try Self.parallelPlanes()
        #expect(a.extrema(to: b) == nil)
        #expect(a.minDistance(to: b) != nil)
    }

    @Test("Reversed argument order reports the same gap")
    func reversedOrder() throws {
        let (a, b) = try Self.parallelPlanes()
        let forward = try #require(a.minDistance(to: b))
        let reverse = try #require(b.minDistance(to: a))
        #expect(abs(forward - reverse) < 1e-9)
    }

    @Test("A different gap gives a different number")
    func theNumberTracksTheGeometry() throws {
        // Against a hardcoded constant, or a value copied from the wrong place. Three separations
        // built the same way, each read back. A wrapper returning any fixed number passes exactly
        // one of these.
        let base = try #require(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)))
        for expected in [0.25, 5.0, 137.5] {
            let other = try #require(
                Surface.plane(origin: SIMD3(0, 0, expected), normal: SIMD3(0, 0, 1)))
            let d = try #require(base.minDistance(to: other))
            #expect(abs(d - expected) < 1e-7, "gap \(expected) read back as \(d)")
        }
    }

    @Test("Coaxial cylinders are everywhere equidistant and are NOT the parallel case")
    func coaxialCylindersAreNotTheParallelCase() throws {
        // Written first as a second parallel construction, on the assumption that two coaxial
        // cylinders reach the same branch as two parallel planes. Measured, they do not, and the
        // assumption is worth keeping as a test because it is the obvious one to make.
        //
        // `IsParallel()` is NOT the predicate "the two surfaces are everywhere equidistant". In
        // this kernel the surface-surface parallel case is exactly two parallel planes:
        // `Extrema_ExtSS::Perform` reaches `myExtElSS` only in its `Plane` x `Plane` arm
        // (`Extrema_ExtSS.cxx:120-127`) and every other pair goes to `Extrema_GenExtSS`, which
        // leaves `myIsPar` false; and `Extrema_ExtElSS` sets `myIsPar = true` in its
        // `gp_Pln`/`gp_Pln` overload alone, every other overload assigning false. So coaxial
        // cylinders and concentric spheres both come back with a discrete point pair.
        //
        // Measured as modes 8 and 9 of `Scripts/repro/2876/probe.mm`: r3 and r8, coaxial
        // cylinders and concentric spheres alike, give `IsParallel() == false`, `NbExtrema() == 2`
        // and `LowerDistance() == 4.9999999999999991` with a real pair behind it. This is the same
        // narrowness #636 records for `Extrema_ExtCC`, one class over.
        let inner = try #require(
            Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 3))
        let outer = try #require(
            Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 8))
        let bounds = (uMin: 0.0, uMax: 2.0 * Double.pi, vMin: -10.0, vMax: 10.0)
        let d = try #require(inner.minDistance(to: outer, uvBounds1: bounds, uvBounds2: bounds))
        #expect(abs(d - 5.0) < 1e-6, "coaxial cylinders r3 and r8 measured \(d)")
        // ...and because they are not the parallel case, extrema answers for them too, with the
        // same number. A future change that widened the refusal to "looks equidistant" would fail
        // here rather than quietly costing callers their point pair.
        let pair = try #require(
            inner.extrema(to: outer, uvBounds1: bounds, uvBounds2: bounds))
        #expect(pair.distance == d)
    }

    // MARK: - Not a fabricated zero

    @Test("Coincident planes report a measured zero")
    func coincidentPlanesAreARealZero() throws {
        // Zero is a legitimate answer here, so it cannot be used as the failure sentinel and a
        // wrapper must not refuse it. Measured as mode 5 of the probe: IsParallel true,
        // NbExtrema 1, LowerDistance 0.
        let a = try #require(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)))
        let b = try #require(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)))
        let d = try #require(a.minDistance(to: b))
        #expect(d == 0.0)
    }

    // MARK: - Nothing reported

    @Test("Crossing planes report nothing, which is not a zero")
    func crossingPlanesReportNothing() throws {
        // Two perpendicular planes intersect, so there is no extremum: NbExtrema() is 0 and
        // LowerDistance() itself raises Standard_OutOfRange out of NCollection_Sequence::Value
        // with myIndex == 0 (probe mode 4). The bridge tests the count first and answers -1, which
        // is nil here. Without this case a wrapper that returned 0.0 for "no answer" would pass
        // every other test in this suite.
        let a = try #require(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)))
        let b = try #require(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(1, 0, 0)))
        #expect(a.minDistance(to: b) == nil)
    }

    // MARK: - The non-parallel path is unchanged

    @Test("Separated spheres agree with extrema(to:) to the last digit")
    func nonParallelAgreesWithExtrema() throws {
        // The control that makes every case above evidence about the parallel branch. Both entry
        // points run the same GeomAPI_ExtremaSurfaceSurface over the same default bounds, so on a
        // non-parallel pair they must not merely be close, they must be equal.
        let s1 = try #require(Surface.sphere(center: SIMD3(0, 0, 0), radius: 3))
        let s2 = try #require(Surface.sphere(center: SIMD3(20, 0, 0), radius: 5))
        let viaExtrema = try #require(s1.extrema(to: s2)).distance
        let viaMinDistance = try #require(s1.minDistance(to: s2))
        #expect(viaMinDistance == viaExtrema)
        #expect(abs(viaMinDistance - 12.0) < 0.5)

        // ...and over explicit bounds too, which is the half that has teeth. Agreement over the
        // defaults alone would still hold if this method quietly ignored its uvBounds, because a
        // sphere's default bounds are its whole domain. Over a trimmed box the two entry points
        // agree only if they are genuinely the same computation.
        let sliver = (uMin: 2.0, uMax: 3.0, vMin: 0.5, vMax: 1.0)
        let boundedExtrema = try #require(
            s1.extrema(to: s2, uvBounds1: sliver, uvBounds2: sliver)
        ).distance
        let boundedMinDistance = try #require(
            s1.minDistance(to: s2, uvBounds1: sliver, uvBounds2: sliver))
        #expect(boundedMinDistance == boundedExtrema)
        #expect(boundedMinDistance != viaMinDistance)
    }

    @Test("Explicit UV bounds change the answer, so they are not ignored")
    func boundsAreHonoured() throws {
        // A sphere pair restricted to a sliver of UV must measure something different from the
        // same pair over its full domain. A wrapper that dropped the bounds on the floor would
        // return the same number twice.
        let s1 = try #require(Surface.sphere(center: SIMD3(0, 0, 0), radius: 3))
        let s2 = try #require(Surface.sphere(center: SIMD3(20, 0, 0), radius: 5))
        let full = try #require(s1.minDistance(to: s2))
        let sliver = (uMin: 2.0, uMax: 3.0, vMin: 0.5, vMax: 1.0)
        let trimmed = try #require(
            s1.minDistance(to: s2, uvBounds1: sliver, uvBounds2: sliver))
        #expect(trimmed > full + 1.0, "full \(full) vs trimmed \(trimmed)")
    }

    // MARK: - The family this completes

    @Test("Curve-curve and curve-surface already answered, and still do")
    func theOtherTwoMembersOfTheFamily() throws {
        // #2876 asked whether the shape should be chosen once for Curve3D as well. It already was:
        // both Curve3D.minDistance overloads read LowerDistance() alone and have always been
        // correct on parallel input, which is why neither needed changing. Pinned here so that a
        // future guard added to either one is caught by a red assertion rather than by nobody.
        let l1 = try #require(Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)))
        let l2 = try #require(Curve3D.line(through: SIMD3(0, 5, 0), direction: SIMD3(1, 0, 0)))
        let curveCurve = try #require(l1.minDistance(to: l2))
        #expect(abs(curveCurve - 5.0) < 1e-7)
        // ...and the point-pair entry point still refuses that same pair, as #636 requires.
        #expect(l1.extrema(with: l2).isEmpty)

        let plane = try #require(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)))
        let above = try #require(Curve3D.line(through: SIMD3(0, 0, 5), direction: SIMD3(1, 0, 0)))
        let curveSurface = try #require(above.minDistance(to: plane))
        #expect(abs(curveSurface - 5.0) < 1e-7)
    }
}
