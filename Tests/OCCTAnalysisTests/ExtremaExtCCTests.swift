import Foundation
import Testing
import simd

@testable import OCCTSwift

// #2941: both tests here sat inside an `if let` with no `else`, so a nil from `Curve3D.line` ran
// no assertion at all, `count >= 1` was true of every count the kernel can return, the distance
// check was gated on the same `count >= 1` that had just been asserted, and `parallelCurves`
// asserted two booleans and nothing else. Every value below is the kernel's own, from
// `Scripts/repro/766-extrema-extcc-pelc-pels/transcript.txt`.
@Suite("Extrema_ExtCC Tests")
struct ExtremaExtCCTests {
    @Test func curveCurveDistance() throws {
        // Two perpendicular lines at distance 5: the x axis, and the z-parallel line through
        // (0, 5, 0). Exactly one extremum, at the feet (0, 0, 0) and (0, 5, 0).
        let line1 = try #require(Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)))
        let line2 = try #require(Curve3D.line(through: SIMD3(0, 5, 0), direction: SIMD3(0, 0, 1)))

        let result = line1.extremaCC(range1: -10...10, other: line2, range2: -10...10)
        #expect(result.isDone)
        #expect(!result.isParallel, "perpendicular lines are not parallel")
        #expect(result.count == 1, "expected exactly one extremum, got \(result.count)")

        let pp = line1.extremaCCPoint(
            range1: -10...10, other: line2, range2: -10...10, index: 1)
        // Square distance, not distance: 5 apart is 25, exactly, for two analytic lines.
        #expect(abs(pp.squareDistance - 25.0) < 1e-9, "square distance \(pp.squareDistance) != 25")
        // The feet themselves, which nothing pinned before: a bridge that returned the right
        // distance between the wrong pair of points passed the old test.
        #expect(simd_distance(pp.point1, SIMD3(0, 0, 0)) < 1e-9, "foot on line1 is \(pp.point1)")
        #expect(simd_distance(pp.point2, SIMD3(0, 5, 0)) < 1e-9, "foot on line2 is \(pp.point2)")
        // The feet are at the lines' own parameter 0, both lines being unit-speed from their
        // through-point.
        #expect(abs(pp.param1) < 1e-9, "param1 \(pp.param1) != 0")
        #expect(abs(pp.param2) < 1e-9, "param2 \(pp.param2) != 0")
    }

    @Test func parallelCurves() throws {
        // Two lines along +x, 3 apart in y.
        let line1 = try #require(Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)))
        let line2 = try #require(Curve3D.line(through: SIMD3(0, 3, 0), direction: SIMD3(1, 0, 0)))
        let parallel = line1.extremaCC(range1: -10...10, other: line2, range2: -10...10)

        #expect(parallel.isDone)
        #expect(parallel.isParallel)
        // A parallel pair has no isolated extremum, and the bridge reports zero rather than
        // calling NbExt(). That is what OCCT's own callers do with the same object:
        // BRepExtrema_DistanceSS.cxx:948 is `Ext.IsDone() ? (Ext.IsParallel() ? 0 : Ext.NbExt())
        // : 0`, three times in that file, and AIS_Manipulator.cxx:531 rejects on IsParallel()
        // before it reads anything.
        #expect(parallel.count == 0, "a parallel pair reports no extrema, got \(parallel.count)")

        // #2941: the discriminating half. Two booleans on one fixture cannot tell a working
        // IsParallel from one wired to true, so the same construction is run on a pair that is
        // NOT parallel and the opposite answer is required. Inverting IsParallel in
        // OCCTExtremaExtCC now fails whichever way it is inverted.
        let crossing = try #require(Curve3D.line(through: SIMD3(0, 3, 0), direction: SIMD3(0, 1, 0)))
        let notParallel = line1.extremaCC(range1: -10...10, other: crossing, range2: -10...10)
        #expect(notParallel.isDone)
        #expect(!notParallel.isParallel, "a +x line and a +y line are not parallel")
        #expect(notParallel.count == 1, "expected one extremum, got \(notParallel.count)")

        // #2941 asked for the parallel pair's own square distance (9) to be pinned here. It is
        // deliberately not: Extrema_ExtCC::SquareDistance(1) does return 9 on this fixture, but
        // no OCCT caller reads it on a parallel pair. GeomAPI_ExtremaCurveCurve.cxx:297-320 takes
        // SquareDistance only in its `!IsParallel()` branch and projects a point or falls through
        // to TrimmedSquareDistances otherwise, and the three BRepExtrema_DistanceSS sites above
        // map parallel to zero extrema. Exposing it would be the bridge improving on the kernel,
        // which okf/policies/follow-occt-callers.md declines.
    }
}
