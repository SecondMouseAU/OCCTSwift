import Foundation
import Testing

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
/// `NCollection_Sequence`.
///
/// Which check fails, precisely, because it is not the obvious one. `Extrema_ExtCC::Points()` does
/// carry `if (N < 1 || N > NbExt()) throw Standard_OutOfRange();`, and that is a RAW throw, not a
/// `_Raise_if` macro, so `No_Exception` does not remove it. It simply asks the wrong question:
/// `NbExt()` counts `mySqDist`, and the index is about to be used against `mypoints`. The check
/// that would have caught it is one level down, in `NCollection_Sequence::Value(const int)`, and
/// that one IS a `Standard_OutOfRange_Raise_if` macro, which this project's
/// `BUILD_RELEASE_DISABLE_EXCEPTIONS=ON` build compiles to nothing. So the out-of-range read is
/// undefined behaviour: measured (via a standalone ground-truth binary linked directly against
/// `libOCCT-macos.a`) to be a genuine SIGSEGV, not a C++ exception. A `catch (...)` around the call
/// cannot help: an OS signal never reaches it.
///
/// That distinction is the whole basis of the kernel fix in #743 / patch `0024`: the repair is not
/// to restore an exception, it is to make `Points()` bound against the container it actually
/// indexes.
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

    /// The two crashing shapes, defined once. `minDistanceUnaffectedByTheGuard` below exercises the
    /// same geometry as the two tests above it, and the point of that test is that it is the same
    /// geometry, so the fixtures are shared rather than copied. Copies drift: tighten one and the
    /// test asserting the contrast silently starts contrasting something else.
    ///
    /// Both pairs are 5.0 apart, which every distance assertion here depends on.
    private static let parallelOffset = 5.0

    private static func unboundedParallelLines() throws -> (Curve3D, Curve3D) {
        (
            try #require(Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))),
            try #require(
                Curve3D.line(through: SIMD3(0, parallelOffset, 0), direction: SIMD3(1, 0, 0)))
        )
    }

    /// Bounded, and their projected ranges OVERLAP, which is the condition that makes
    /// `Extrema_ExtCC` report a solution it never stored. Disjoint ranges are a different case:
    /// `IsParallel()` returns false for those and the endpoint solution is real, so they are not a
    /// fixture for this bug. See the suite's own note and PR #730's verification comment.
    private static func overlappingParallelSegments() throws -> (Curve3D, Curve3D) {
        (
            try #require(Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))),
            try #require(
                Curve3D.segment(from: SIMD3(0, parallelOffset, 0), to: SIMD3(10, parallelOffset, 0))
            )
        )
    }

    @Test("Two unbounded parallel lines: extrema is empty, not a crash")
    func parallelUnboundedLinesReturnEmpty() throws {
        let (a, b) = try Self.unboundedParallelLines()

        #expect(a.extrema(with: b).isEmpty)
        #expect(a.extrema(with: b, maxCount: 1).isEmpty)
        #expect(a.extrema(with: b, maxCount: 20).isEmpty)  // the reported default capacity
    }

    @Test("Two bounded parallel segments with overlapping projected ranges: extrema is empty")
    func parallelBoundedSegmentsReturnEmpty() throws {
        let (a, b) = try Self.overlappingParallelSegments()

        #expect(a.extrema(with: b).isEmpty)
    }

    /// `minDistance(to:)` (`OCCTCurve3DMinDistanceToCurve`) shares the same
    /// `GeomAPI_ExtremaCurveCurve` construction but only ever calls `LowerDistance()`, which reads
    /// `mySqDist`, which is populated correctly in every parallel branch. It never touches the empty
    /// `mypoints` sequence, so it needs no guard and must keep reporting the real distance.
    @Test("minDistance(to:) keeps reporting the true offset for the same parallel pairs")
    func minDistanceUnaffectedByTheGuard() throws {
        let (a, b) = try Self.unboundedParallelLines()
        let d = try #require(a.minDistance(to: b))
        #expect(abs(d - Self.parallelOffset) < 1e-9)

        let (s1, s2) = try Self.overlappingParallelSegments()
        let sd = try #require(s1.minDistance(to: s2))
        #expect(abs(sd - Self.parallelOffset) < 1e-9)
    }

    /// The case PR #730's review argued was silently regressed by the guard, measured and kept as a
    /// regression lock. Two parallel segments whose projected ranges are DISJOINT have one real
    /// nearest-endpoint solution, and `IsParallel()` returns false for them, so the guard never
    /// fires and that solution is still returned. If a future change widens the guard to test
    /// tangent direction rather than trusting `IsParallel()`, this goes red.
    @Test("Parallel segments with disjoint ranges keep their real endpoint solution")
    func disjointParallelSegmentsStillReportTheirEndpointSolution() throws {
        let a = try #require(Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)))
        let b = try #require(Curve3D.segment(from: SIMD3(20, 5, 0), to: SIMD3(30, 5, 0)))

        #expect(!a.extrema(with: b).isEmpty)
        let d = try #require(a.minDistance(to: b))
        #expect(abs(d - hypot(10.0, 5.0)) < 1e-6)  // (10,0,0) to (20,5,0)
    }

    @Test("Non-parallel curves are unaffected: extrema still reports real solutions")
    func nonParallelCurvesStillReportSolutions() throws {
        let a = try #require(Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)))
        let b = try #require(Curve3D.line(through: SIMD3(5, -5, 1), direction: SIMD3(0, 1, 0)))
        let result = a.extrema(with: b)
        #expect(!result.isEmpty)
    }
}

/// Compiles and runs the doc snippet on `Curve3D.extrema(with:maxCount:)` verbatim. A doc snippet
/// that does not compile is the documentation equivalent of a pinned value nobody measured (#726),
/// and this one asserts specific numbers.
@Suite("The extrema doc snippet is runnable and its printed values are true (#636)")
struct Issue636ExtremaDocSnippetTests {
    @Test("the snippet's API calls resolve and its stated values hold")
    func snippetHolds() throws {
        let a = try #require(Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)))
        let b = try #require(Curve3D.line(through: SIMD3(0, 5, 0), direction: SIMD3(1, 0, 0)))

        let pairs = a.extrema(with: b)
        #expect(pairs.isEmpty)

        let info = a.extremaCC(other: b)
        #expect(info.isParallel)
        #expect(abs((a.minDistance(to: b) ?? 0) - 5.0) < 1e-9)
    }
}
