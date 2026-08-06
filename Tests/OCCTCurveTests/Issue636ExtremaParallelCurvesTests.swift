import Testing
import Foundation
@testable import OCCTSwift

// MARK: - #636: Curve3D.extrema SIGSEGVs on parallel curves at every capacity

/// `Curve3D.extrema(with:maxCount:)` (`OCCTCurve3DExtrema` in `OCCTBridge_Curve3D.mm`) wraps
/// `GeomAPI_ExtremaCurveCurve`, which in turn wraps `Extrema_ExtCC`: the same class
/// `BRepExtrema_ExtCC`'s documented parallel-curve crash (see `CLAUDE.md`'s Known OCCT Bugs) traces
/// back to, one layer down.
///
/// On parallel curves, `Extrema_ExtCC::PrepareParallelResult` reports exactly one "extremum" by
/// appending a distance to its private `mySqDist` sequence, but several of its branches (an
/// unbounded pair, or a bounded pair whose projected ranges overlap, where there is no single
/// discrete closest point when a whole span is equidistant) never append the matching pair to
/// `mypoints`. `NbExtrema()` reports 1 (`mySqDist.Length()`), so `Points()` indexes an empty
/// `NCollection_Sequence`. This project's OCCT is built with `BUILD_RELEASE_DISABLE_EXCEPTIONS=ON`
/// (`No_Exception`), so the bounds check that would normally throw `Standard_OutOfRange` compiles
/// to nothing, and the out-of-range access is undefined behaviour: measured (via a standalone
/// ground-truth binary linked directly against `libOCCT-macos.a`) to be a genuine SIGSEGV, not a
/// C++ exception. A `catch (...)` around the call cannot help: an OS signal never reaches it.
///
/// Both fixtures below reproduced the crash before the fix (confirmed via the same standalone
/// ground-truth binary, `GeomAPI_ExtremaCurveCurve` constructed directly): two unbounded parallel
/// `Geom_Line`s (`Curve3D.line(through:direction:)`), and two *bounded* parallel segments with
/// overlapping projected ranges (`Curve3D.segment(from:to:)`, `GC_MakeSegment` over `Geom_Line`,
/// the same fixture shape `Issue622AllocationBoundsTests` deliberately avoided making parallel,
/// per its own comment). The fix (`OCCTCurve3DExtrema`) queries `IsParallel()` and returns empty
/// before touching any solution, mirroring the guard already in place for the sibling
/// `Extrema_ExtCC`/`Extrema_ExtCS` entry points in the same file.
@Suite("Curve3D.extrema returns empty, not SIGSEGV, on parallel curves (#636)")
struct Issue636ExtremaParallelCurvesTests {

    @Test("Two unbounded parallel lines: extrema is empty, not a crash")
    func parallelUnboundedLinesReturnEmpty() throws {
        let a = try #require(Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)))
        let b = try #require(Curve3D.line(through: SIMD3(0, 5, 0), direction: SIMD3(1, 0, 0)))

        #expect(a.extrema(with: b).isEmpty)
        #expect(a.extrema(with: b, maxCount: 1).isEmpty)
        #expect(a.extrema(with: b, maxCount: 20).isEmpty) // the reported default capacity
    }

    @Test("Two bounded parallel segments with overlapping projected ranges: extrema is empty")
    func parallelBoundedSegmentsReturnEmpty() throws {
        let a = try #require(Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)))
        let b = try #require(Curve3D.segment(from: SIMD3(0, 5, 0), to: SIMD3(10, 5, 0)))

        #expect(a.extrema(with: b).isEmpty)
    }

    /// `minDistance(to:)` (`OCCTCurve3DMinDistanceToCurve`) shares the same
    /// `GeomAPI_ExtremaCurveCurve` construction but only ever calls `LowerDistance()`, which reads
    /// `mySqDist`, which is populated correctly in every parallel branch. It never touches the empty
    /// `mypoints` sequence, so it needs no guard and must keep reporting the real distance.
    @Test("minDistance(to:) keeps reporting the true offset for the same parallel pairs")
    func minDistanceUnaffectedByTheGuard() throws {
        let a = try #require(Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)))
        let b = try #require(Curve3D.line(through: SIMD3(0, 5, 0), direction: SIMD3(1, 0, 0)))
        let d = try #require(a.minDistance(to: b))
        #expect(abs(d - 5.0) < 1e-9)

        let s1 = try #require(Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)))
        let s2 = try #require(Curve3D.segment(from: SIMD3(0, 5, 0), to: SIMD3(10, 5, 0)))
        let sd = try #require(s1.minDistance(to: s2))
        #expect(abs(sd - 5.0) < 1e-9)
    }

    @Test("Non-parallel curves are unaffected: extrema still reports real solutions")
    func nonParallelCurvesStillReportSolutions() throws {
        let a = try #require(Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)))
        let b = try #require(Curve3D.line(through: SIMD3(5, -5, 1), direction: SIMD3(0, 1, 0)))
        let result = a.extrema(with: b)
        #expect(!result.isEmpty)
    }
}
