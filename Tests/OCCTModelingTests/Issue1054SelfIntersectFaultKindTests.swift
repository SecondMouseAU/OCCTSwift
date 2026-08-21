import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1054: isSelfIntersecting(timeout:) reported every BOPAlgo_ArgumentAnalyzer fault as a
// self-intersection, including the two that are not one. BOPAlgo_BadType (an argument
// Boolean Operations cannot use) and BOPAlgo_OperationAborted (the analysis gave up) are
// recorded exactly the way a real BOPAlgo_SelfIntersect is, and HasFaulty() cannot tell
// them apart. See docs/reference/Shape-Features.md and
// Scripts/repro/1054-selfintersect-fault-kinds/ for the measurements.
@Suite("Issue #1054, self-intersection fault kinds")
struct Issue1054SelfIntersectFaultKind {

    /// An argument the analyzer rejects outright is indeterminate.
    ///
    /// An emptied solid carries no geometry anywhere below it, so
    /// `BOPTools_AlgoTools3D::IsEmptyShape` is true and `TestTypes()` records `BOPAlgo_BadType`
    /// for it before the self-interference pass runs at all. No timeout is involved, which is
    /// what makes this case deterministic. `Shape.compound([])` is the other obvious spelling
    /// and is not available: `OCCTShapeCreateCompound` refuses `count < 1` and returns `nil`.
    @Test("an argument the analyzer rejects is indeterminate, not self-intersecting")
    func rejectedArgumentIsIndeterminate() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10), let empty = box.emptied
        else {
            #expect(Bool(false), "a box and its emptied copy should both build")
            return
        }
        // Unbounded, so no watchdog can be blamed for the answer.
        #expect(empty.isSelfIntersecting(timeout: 0) == nil)
    }

    /// A null shape is the analyzer's *other* `BOPAlgo_BadType` branch, and it also changed.
    ///
    /// `TestTypes` catches `myShape1.IsNull() && myShape2.IsNull()` before it ever consults
    /// `BOPTools_AlgoTools3D::IsEmptyShape`, so `nullified`'s result reaches `BadType` by a
    /// different route than `emptied`'s and used to answer `true` for the same wrong reason.
    /// Pinned separately because one fixture does not cover the other's branch.
    @Test("a null shape is indeterminate too, by the analyzer's other BadType branch")
    func nullShapeIsIndeterminate() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10), let null = box.nullified
        else {
            #expect(Bool(false), "a box and its nullified copy should both build")
            return
        }
        #expect(null.isNull)
        #expect(null.isSelfIntersecting(timeout: 0) == nil)
    }

    /// The rejected fixture keeps meaning its name.
    ///
    /// If `emptied` ever stopped dropping the sub-shapes, the test above would pass for the
    /// wrong reason. `BOPTools_AlgoTools3D::IsEmptyShape` is "nothing anywhere below this shape
    /// carries geometry", which is not `TopoDS_Shape::IsNull()`, so the properties are pinned
    /// rather than the null flag. The box it was copied from is the control, and it is
    /// analysable.
    @Test("the rejected-argument fixture has no content and its source solid does")
    func fixtureIsDistinguishable() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10), let empty = box.emptied
        else {
            #expect(Bool(false))
            return
        }
        #expect(empty.shapeType == .solid)
        #expect(!empty.isNull)
        #expect(empty.faceCount == 0)
        #expect(empty.edgeCount == 0)
        #expect(empty.vertexCount == 0)
        #expect(box.faceCount == 6)
        #expect(box.isSelfIntersecting(timeout: 0) == false)
    }

    /// A completed analysis still reports a genuine self-intersection.
    ///
    /// Reading the statuses instead of `HasFaulty()` must not cost the positive answer the
    /// check exists for.
    @Test("a genuine self-intersection is still reported")
    func genuineSelfIntersectionSurvives() {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
            let b = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10),
            let compound = Shape.compound([a, b])
        else {
            #expect(Bool(false))
            return
        }
        #expect(compound.isSelfIntersecting(timeout: 0) == true)
    }

    /// A clean solid never comes back `true`, whatever the watchdog does to the analysis.
    ///
    /// `BOPAlgo_CheckerSI::CheckFaceSelfIntersection` clears `BOPDS_DS::Interferences()` on
    /// entry, and the `PostTreat` that follows re-adds only pairs passing its own per-type
    /// gates, which for a valid solid's face adjacency is none. An analysis interrupted before
    /// that `Clear()` is read against the pave filler's own raw map instead, so a clean box has
    /// real `BOPAlgo_SelfIntersect` results recorded against it.
    ///
    /// The `wrong` assertion is one-sided: with the watchdog read first, a clean box can only
    /// answer `false` or `nil`, so timing alone can never fail it, and only the defect can.
    ///
    /// The assertion beside it is what stops a green run from being vacuous, and "at least one
    /// `nil` and at least one `false`" is not enough for that. A span far larger than the real
    /// runtime brackets trivially, with the few `nil`s coming from the shortest timeouts, which
    /// abort before the analysis has recorded anything at all. The regime this test exists for is
    /// the *tail*, where the analysis is nearly done and the interference map still holds the
    /// adjacency pairs a completed run would have cleared. So the sweep converges the span on the
    /// measured runtime from both directions, and then requires a **tenth of the steps on each
    /// side**, which can only hold when the transition sits well inside the sweep rather than at
    /// an edge.
    ///
    /// Converging both ways is the load-bearing part. A warm-up `isSelfIntersecting(timeout: 0)`
    /// can over-measure steady state badly (cold process, loaded runner), and a loop that only
    /// ever widens drives that error the wrong way, monotonically.
    @Test("a clean solid never reports self-intersection at any timeout")
    func cleanSolidNeverReportsSelfIntersection() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            #expect(Bool(false))
            return
        }
        // The minimum of several runs, not one warm-up: the first analysis in a process pays
        // costs the other 200 will not, and the minimum is the estimator least disturbed by that.
        var runtime = Double.greatestFiniteMagnitude
        for _ in 0..<5 {
            let started = Date()
            #expect(box.isSelfIntersecting(timeout: 0) == false)
            runtime = Swift.min(runtime, Date().timeIntervalSince(started))
        }
        runtime = max(runtime, 0.0002)

        let steps = 200
        let flank = steps / 10
        var wrong = 0
        var interrupted = 0
        var completed = 0
        var span = runtime * 1.2
        for _ in 0..<12 {
            wrong = 0
            interrupted = 0
            completed = 0
            for step in 1...steps {
                let timeout = span * Double(step) / Double(steps)
                switch box.isSelfIntersecting(timeout: timeout) {
                case .some(true): wrong += 1
                case .none: interrupted += 1
                case .some(false): completed += 1
                }
            }
            if wrong > 0 || (interrupted >= flank && completed >= flank) { break }
            // Every step completed means even the shortest timeout outlasted the analysis, so
            // the span is too large; every step aborted means the longest did not, so it is too
            // small. Anything in between is a transition too close to an edge, and halving
            // brings it inward.
            let allCompleted = completed >= steps - flank
            let allInterrupted = interrupted >= steps - flank
            span = allInterrupted && !allCompleted ? span * 2 : span / 2
        }

        #expect(
            wrong == 0,
            "a clean box reported self-intersection at \(wrong) of \(steps) timeouts spanning \(span)s"
        )
        #expect(
            interrupted >= flank && completed >= flank,
            "the \(steps)-timeout sweep over \(span)s put only \(interrupted) interrupted and \(completed) completed either side of the transition, fewer than \(flank) on a side, so it never sampled the tail this test exists for (box runtime \(runtime)s)"
        )
    }
}
