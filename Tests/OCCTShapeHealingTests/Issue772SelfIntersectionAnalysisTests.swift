import Testing
import Foundation
import simd
@testable import OCCTSwift

/// #772: `ShapeAnalysisResult.selfIntersectionCount` was always 0 and never computed (#763),
/// leaving `Shape.analyze(tolerance:)` reporting nothing about self-intersection at all.
///
/// Measured before choosing (okf/policies/measure-dont-assume.md,
/// `Scripts/repro/772-analyze-self-intersection/`): the real self-intersection check
/// (`BOPAlgo_ArgumentAnalyzer`'s self-interference test, #319) costs 1x-3x the rest of
/// `analyze()`'s scan on ordinary shapes, including a real 662-face mesh-sewn import, but
/// ~3000x-4000x on the #319 pathological artifact (a few ms vs 30s at a 30s timeout). That gap is
/// why the check is opt-in (`selfIntersectionTimeout: nil` by default) rather than always-on.
///
/// `ShapeAnalysisResult.hasSelfIntersection` is `Bool?`, not the `Int?` the issue's option 3
/// sketch suggested: `isSelfIntersecting` itself only ever answers yes/no/indeterminate
/// (`BOPAlgo_ArgumentAnalyzer` runs with `StopOnFirstFaulty`), never a count, so an `Int?` here
/// would fabricate a precision the check does not provide, the same class of problem #763 was
/// removing.
///
/// Per #771 (a gate that never flips is the same defect as an always-nil optional): this suite's
/// `nonNilTimeoutOnCleanShapePopulatesFalse` and
/// `nonNilTimeoutOnSelfIntersectingShapePopulatesTrue` are the reachable-and-populated proof that
/// `hasSelfIntersection` actually flips, on both outcomes, not just the default `nil`.
///
/// Review round 2 found two more defects, both fixed here rather than merely documented:
/// (1) the first version forwarded to `isSelfIntersecting(hardTimeout:)`, measured (this suite's
/// harness, not this file) to be no cheaper on ordinary shapes; `analyze()` now forwards to
/// `timeout:` instead. The other half of that finding, that `hardTimeout:` returned a **worse**
/// answer on the #319 pathological artifact, is **withdrawn (#1054)**: the conclusive `true`
/// `timeout:` gave there was `BOPAlgo_OperationAborted`, the fault OCCT records when the watchdog
/// stops the analysis, which `HasFaulty()` could not tell from a self-interference. Both
/// mechanisms now answer `nil` on that artifact at a 30s bound. See
/// `Shape+Analysis.swift`'s "Why `timeout:`, not `hardTimeout:`" for what the choice still rests
/// on. (2) the two parameters that gated the check
/// (`checkSelfIntersection: Bool`, `hardTimeout: Double`) let a caller supply a timeout while
/// forgetting the boolean, compiling and silently discarding it; they are now one
/// `selfIntersectionTimeout: Double?`, where supplying a value *is* opting in, so that mistake is
/// unrepresentable. `timeoutAloneCannotBeSuppliedWithoutOptingIn` below is the compile-time proof.
@Suite("Issue 772: analyze() self-intersection is opt-in and representable")
struct Issue772SelfIntersectionAnalysis {

    /// Two boxes offset so their faces genuinely interfere, in one compound: the same fast,
    /// deterministic self-intersecting fixture `Issue208SelfIntersection`/
    /// `Issue319HardBoundedSelfIntersection` already use, so this suite reuses a construction the
    /// self-intersection check is already known to resolve quickly and conclusively for, rather
    /// than the #319 pathological artifact (which takes ~30s and belongs in the timing harness,
    /// not the test suite).
    func overlappingCompound() -> Shape {
        let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10)!
        let b = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10)!
        return Shape.compound([a, b])!
    }

    @Test("default analyze() does not check self-intersection: hasSelfIntersection is nil")
    func defaultDoesNotCheck() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let analysis = try #require(box.analyze(tolerance: 0.001))
        #expect(analysis.hasSelfIntersection == nil)

        // Also true for a shape that WOULD be flagged if checked: the default must stay cheap
        // and silent, not quietly run the expensive pass.
        let overlapping = try #require(overlappingCompound().analyze(tolerance: 0.001))
        #expect(overlapping.hasSelfIntersection == nil)
    }

    @Test("a non-nil selfIntersectionTimeout on a clean shape populates false")
    func nonNilTimeoutOnCleanShapePopulatesFalse() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let analysis = try #require(box.analyze(tolerance: 0.001, selfIntersectionTimeout: 30))
        #expect(analysis.hasSelfIntersection == false)
    }

    @Test("a non-nil selfIntersectionTimeout on a self-intersecting shape populates true")
    func nonNilTimeoutOnSelfIntersectingShapePopulatesTrue() throws {
        let overlapping = overlappingCompound()
        let analysis = try #require(overlapping.analyze(tolerance: 0.001, selfIntersectionTimeout: 30))
        #expect(analysis.hasSelfIntersection == true)
    }

    @Test("totalProblems includes self-intersection only when it was actually checked and found")
    func totalProblemsReflectsOnlyWhatWasChecked() throws {
        let overlapping = overlappingCompound()

        let unchecked = try #require(overlapping.analyze(tolerance: 0.001))
        let checked = try #require(overlapping.analyze(tolerance: 0.001, selfIntersectionTimeout: 30))

        // Same shape, same tolerance: the two analyses can only differ by the self-intersection
        // contribution, since `selfIntersectionTimeout` is the only input that changed.
        #expect(checked.totalProblems == unchecked.totalProblems + 1)
        // The cheap topology scan alone has no way to see a global 3D overlap between two
        // otherwise-valid closed solids, so only the checked analysis can mark this unhealthy.
        #expect(checked.isHealthy == false)
    }

    /// Review round 2, finding 3: `analyze(tolerance:checkSelfIntersection:hardTimeout:)` let a
    /// caller pass `hardTimeout: 5` while forgetting `checkSelfIntersection: true`, which compiled
    /// and ran, silently discarding the timeout and returning `hasSelfIntersection == nil`,
    /// indistinguishable from the ordinary default-off case. There is no longer a separate
    /// boolean to forget: `selfIntersectionTimeout: Double?` makes "supply a timeout but do not
    /// opt in" a state that cannot be constructed at all, so this test is a compile-time argument
    /// as much as a runtime one. The commented-out line is what the old API allowed; it does not
    /// exist as a spelling on the new one (there is no `hardTimeout:` label on `analyze` at all).
    @Test("supplying a timeout IS opting in; there is no separate flag left to forget")
    func timeoutAloneCannotBeSuppliedWithoutOptingIn() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Old, no-longer-expressible footgun: box.analyze(tolerance: 0.001, hardTimeout: 5)
        // would compile, run, and silently return hasSelfIntersection == nil.
        let analysis = try #require(box.analyze(tolerance: 0.001, selfIntersectionTimeout: 5))
        #expect(analysis.hasSelfIntersection == false)
    }
}
