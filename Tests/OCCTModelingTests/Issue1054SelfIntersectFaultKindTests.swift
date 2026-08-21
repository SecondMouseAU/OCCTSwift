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
    /// The two witnesses either side of it are what stop a green run from being vacuous. A sweep
    /// where every step completed proves nothing, and so does one where every step was
    /// interrupted before the analysis recorded anything, so both outcomes have to appear:
    /// requiring a `nil` and a `false` brackets the point where the analysis starts completing,
    /// which is the regime the spurious results live next to. The bound is widened until that
    /// happens rather than derived from one warm-up timing, because a single first measurement
    /// (lazy kernel init, a transient) can be far enough off to put every step on one side.
    @Test("a clean solid never reports self-intersection at any timeout")
    func cleanSolidNeverReportsSelfIntersection() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            #expect(Bool(false))
            return
        }
        let started = Date()
        #expect(box.isSelfIntersecting(timeout: 0) == false)
        let uninterrupted = max(Date().timeIntervalSince(started), 0.0005)

        let steps = 200
        var wrong = 0
        var interrupted = 0
        var completed = 0
        var span = uninterrupted * 1.2
        // Widen until both outcomes appear. Each attempt doubles the span, so a warm-up that
        // under-measured the real runtime by any factor is corrected in a few rounds rather
        // than failing the run.
        for _ in 0..<8 {
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
            if wrong > 0 || (interrupted > 0 && completed > 0) { break }
            span *= 2
        }

        #expect(
            wrong == 0,
            "a clean box reported self-intersection at \(wrong) of \(steps) timeouts spanning \(span)s"
        )
        #expect(
            interrupted > 0 && completed > 0,
            "the \(steps)-timeout sweep over \(span)s did not bracket the completion point (\(interrupted) interrupted, \(completed) completed), so it never reached the regime this test exists for"
        )
    }
}
