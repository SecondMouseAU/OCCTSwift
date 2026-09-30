import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #2840: Surface.extrema(to:) faulted on parallel surfaces behind a count guard

/// `Surface.extrema(to:uvBounds1:uvBounds2:)` (`OCCTSurfaceExtrema`) wraps
/// `GeomAPI_ExtremaSurfaceSurface`, and until #2831 it read `NearestPoints()` and
/// `LowerDistanceParameters()` behind `NbExtrema() > 0`. That count is not the guard it looks like.
///
/// `Extrema_ExtSS::NbExt()` is `mySqDist.Length()`, and the analytic parallel branch
/// (`Extrema_ExtSS.cxx:226-234`) appends one entry to `mySqDist` and **nothing** to
/// `myPOnS1`/`myPOnS2`. `Extrema_ExtSS::Points` bounds only against `NbExt()`, so index 1 passes the
/// range test and then reads `myPOnS1.Value(1)` on an empty `NCollection_Sequence`. The check that
/// would have caught it is `NCollection_Sequence::Value`'s own `Standard_OutOfRange_Raise_if`, which
/// this build compiles out (`BUILD_RELEASE_DISABLE_EXCEPTIONS`), so the read is an OS fault and the
/// bridge's `catch (...)` never sees it (#345). It is #636's defect in a third Extrema class.
///
/// Measured before the fix by `Scripts/repro/2831/probe.mm` against the pinned kernel, two
/// `Geom_Plane`s 5 apart: `NbExtrema() == 1`, `IsParallel() == true`, `LowerDistance() == 5`
/// correctly, and `NearestPoints()` and `LowerDistanceParameters()` each exit 139.
///
/// The fix gates on `IsParallel()` before the read, so this returns `nil`. **Proving this test
/// fails does not produce a red assertion**: with the guard removed the test process dies on
/// SIGSEGV and the whole suite fails, which is what was observed and is recorded in the PR.
///
/// The refusal loses a real number, the constant gap between the two surfaces.
/// `SurfaceExtremaResult` has no shape for "a distance with no points", and giving it one is a
/// SemVer event, so that part is #2876's.
@Suite("Surface.extrema returns nil, not SIGSEGV, on parallel surfaces (#2840)")
struct Issue2840SurfaceExtremaParallelTests {

    /// The two planes every case here uses, 5 apart along their shared normal.
    private static let gap = 5.0

    private static func parallelPlanes() throws -> (Surface, Surface) {
        (
            try #require(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))),
            try #require(Surface.plane(origin: SIMD3(0, 0, gap), normal: SIMD3(0, 0, 1)))
        )
    }

    @Test("Explicit finite UV bounds")
    func finiteBounds() throws {
        let (a, b) = try Self.parallelPlanes()
        let bounds = (uMin: -10.0, uMax: 10.0, vMin: -10.0, vMax: 10.0)
        #expect(a.extrema(to: b, uvBounds1: bounds, uvBounds2: bounds) == nil)
    }

    @Test("Each plane's own natural domain, which is infinite")
    func naturalDomain() throws {
        let (a, b) = try Self.parallelPlanes()
        // A Geom_Plane's real domain is +/-2e100 in both directions, which is the fallback
        // `extrema(to:)` uses when uvBounds are nil. Measured: the parallel verdict is the same
        // there, so the nil-bounds path reaches the same read.
        #expect(a.extrema(to: b) == nil)
    }

    @Test("Reversed argument order refuses the same way")
    func reversedOrder() throws {
        let (a, b) = try Self.parallelPlanes()
        #expect(b.extrema(to: a) == nil)
    }

    @Test("The guard refuses only the parallel case")
    func nonParallelStillMeasured() throws {
        // The control, and it is load-bearing: `IsParallel()` returning true for everything, or the
        // guard being placed before the wrong read, would make every case above pass for the wrong
        // reason. Two separated spheres have genuine discrete extrema and must still report them.
        //
        // Two non-parallel PLANES would not do: measured, they give NbExtrema() == 0 (they
        // intersect, so there is no discrete extremum to report) and `extrema` correctly returns
        // nil for a reason that has nothing to do with this guard.
        let s1 = try #require(Surface.sphere(center: SIMD3(0, 0, 0), radius: 3))
        let s2 = try #require(Surface.sphere(center: SIMD3(20, 0, 0), radius: 5))
        let result = try #require(s1.extrema(to: s2))
        #expect(abs(result.distance - 12.0) < 0.5)
        #expect(abs(result.point1.x - 3.0) < 0.5)
        #expect(abs(result.point2.x - 15.0) < 0.5)
    }
}
