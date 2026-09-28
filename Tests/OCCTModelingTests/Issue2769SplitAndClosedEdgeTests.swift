import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #2769: `Shape.splitByAngle(_:)` and `Shape.dividedClosedEdges(splitPoints:)` reported "there was
/// nothing to split" as a failure.
///
/// Both bridge functions gated on `ShapeUpgrade_ShapeDivide::Perform()` returning true. That is not
/// OCCT's failure signal: `ShapeProcess_OperLibrary.cxx`, OCCT's own shape-processing library, tests
/// `if (!tool.Perform() && tool.Status(ShapeExtend_FAIL))` at all five of its family call sites, so
/// `false` on its own means "nothing was done" with `Result()` holding the valid input shape.
///
/// Each test pairs the no-op input with a control the same operation genuinely acts on, so a bridge
/// that returned its input unconditionally would fail rather than pass. Measured in
/// `Scripts/repro/2765-convert-to-bezier-perform/`.
@Suite("Issue #2769: nothing to split is not a failure (angle and closed-edge splitting)")
struct Issue2769SplitAndClosedEdgeTests {

    @Test("splitByAngle on an all-planar box returns the box, and still splits a cylinder")
    func splitByAngleReturnsTheInputWhenNoSurfaceSpansTheAngle() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))

        // A box has no surface with an angular span at all, so there is nothing to split at any
        // angle. Before #2769 this was nil.
        let unchanged = try #require(box.splitByAngle(90))
        #expect(unchanged.subShapes(ofType: .face).count == 6)
        #expect(unchanged.isSame(as: box), "Result() is the input shape, not a rebuild of it")
        #expect(abs(try #require(unchanged.volume) - 6000.0) < 1e-6)

        // Control: a full cylinder's lateral face spans 360 degrees.
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        #expect(cyl.subShapes(ofType: .face).count == 3)
        let split = try #require(cyl.splitByAngle(90))
        #expect(split.subShapes(ofType: .face).count == 6, "2 caps plus 4 quarter walls")
        #expect(!split.isSame(as: cyl))
    }

    @Test("dividedClosedEdges on a box returns the box, and still splits a cylinder")
    func dividedClosedEdgesReturnsTheInputWhenNoEdgeIsClosed() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))

        // Every edge of a box is a bounded line between two distinct vertices. Before #2769 this
        // was nil.
        let unchanged = try #require(box.dividedClosedEdges(splitPoints: 1))
        #expect(unchanged.subShapes(ofType: .edge).count == 12)
        #expect(unchanged.isSame(as: box))

        // Control: a cylinder's two rim circles are closed edges.
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        #expect(cyl.subShapes(ofType: .edge).count == 3)
        let split = try #require(cyl.dividedClosedEdges(splitPoints: 1))
        #expect(split.subShapes(ofType: .edge).count == 5, "each rim circle becomes two arcs")
        #expect(!split.isSame(as: cyl))
    }
}
