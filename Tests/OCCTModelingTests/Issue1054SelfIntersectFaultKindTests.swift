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
        #expect(empty.isSelfIntersecting(timeout: 0) != true)
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
    /// `BOPAlgo_CheckerSI::PostTreat` is what discards the adjacency interferences a valid
    /// solid has and it runs last, so an analysis cut short between the face-face pass and
    /// `PostTreat` has real `BOPAlgo_SelfIntersect` results recorded and no reason yet to
    /// drop them.
    ///
    /// The sweep is scaled to the machine (the box's own uninterrupted runtime), because the
    /// window it is hunting for is the tail of that runtime. The assertion is one-sided: with
    /// the watchdog read first, a clean box can only answer `false` or `nil`, so this can
    /// never fail on timing alone.
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
        for step in 1...steps {
            let timeout = uninterrupted * 1.2 * Double(step) / Double(steps)
            if box.isSelfIntersecting(timeout: timeout) == true { wrong += 1 }
        }
        #expect(
            wrong == 0,
            "a clean box reported self-intersection at \(wrong) of \(steps) timeouts spanning its own \(uninterrupted)s runtime"
        )
    }
}
