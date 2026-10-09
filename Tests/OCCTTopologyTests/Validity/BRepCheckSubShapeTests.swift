import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// #2904: all four tests here used to assert one boolean, `isValid == true`, on a primitive box
// that is valid by construction. A bridge that never ran `BRepCheck_*::Minimum()` and returned a
// hardcoded `true` passed every one of them, which is the defect #2734 actually found in the
// shared helper (`checkSubShape`, Sources/OCCTBridge/src/OCCTBridge_Healing_Fix.mm) and that this
// suite did not notice.
//
// Each test now pins three answers rather than one:
//
//   1. the valid control, with `errorCount == 0` and `firstError == nil`, not just `isValid`;
//   2. a sub-shape that is genuinely faulted in the way THIS checker detects, pinned to the
//      specific `BRepCheck_Status` the kernel reports for it;
//   3. an index that names no sub-shape of the type, which is a refusal rather than a fault:
//      `isValid == false` with `errorCount == 0` and `firstError == nil`. The two `false`s are
//      different answers and the triple distinguishes them (#613, #844).
//
// The faults in (2) are the ones `Minimum()` alone can raise, because `checkSubShape` calls only
// `Minimum()` and never `InContext()` (which raises an uncatchable SIGSEGV on some inputs in this
// build, #2746). What that leaves per type was measured in
// `Scripts/repro/2747-brepcheck-minimum-coverage/` and `Scripts/repro/2734-checksubshape-errorcount/`;
// the fixtures below and their answers were measured in `Scripts/repro/2904/`.
@Suite("BRepCheck SubShape Tests")
struct BRepCheckSubShapeTests {

    private func makeBox() throws -> Shape {
        try #require(Shape.box(width: 10, height: 10, depth: 10))
    }

    /// A box whose six planar faces have each been reparametrized to a Bezier surface.
    ///
    /// `ShapeUpgrade` converts surface geometry without re-deriving pcurve consistency, so every
    /// edge is left with `SameParameter` still true while `SameRange` has gone stale
    /// (`Scripts/repro/2732-bezier-master-flag/`), which is exactly the pair
    /// `BRepCheck_Edge::Minimum()` rejects: `if (!SameRange && SameParameter)`.
    ///
    /// The flag pair is asserted here, not assumed. It is what makes this a fixture rather than
    /// just a shape, and if a future `ShapeUpgrade` change repairs the flags the fixture stops
    /// meaning its name silently.
    private func edgeFlagPairBrokenBox() throws -> Shape {
        let converted = try #require(
            makeBox().convertSurfacesToBezier(
                planeMode: true, revolutionMode: false,
                extrusionMode: false, bsplineMode: false))
        let edges = converted.subShapes(ofType: .edge)
        #expect(edges.count == 12, "fixture should still be a box")
        for edge in edges {
            #expect(edge.edgeSameParameter, "fixture lost the SameParameter half of the pair")
            #expect(!edge.edgeSameRange, "fixture lost the stale SameRange half of the pair")
        }
        return converted
    }

    @Test("Check edge validity")
    func edgeValid() throws {
        let box = try makeBox()
        let valid = box.checkEdge(at: 0)
        #expect(valid.isValid, "a box edge is self-consistent")
        #expect(valid.errorCount == 0)
        #expect(valid.firstError == nil)

        let broken = try edgeFlagPairBrokenBox()
        let faulted = broken.checkEdge(at: 0)
        #expect(!faulted.isValid, "SameParameter without SameRange is invalid")
        #expect(faulted.errorCount == 1)
        #expect(faulted.firstError == .invalidSameParameterFlag)

        // An index past the last edge is a statement about the index, not about an edge.
        let refused = box.checkEdge(at: box.subShapes(ofType: .edge).count)
        #expect(!refused.isValid)
        #expect(refused.errorCount == 0, "a refusal is not a fault")
        #expect(refused.firstError == nil)
    }

    @Test("Check wire validity")
    func wireValid() throws {
        let box = try makeBox()
        let valid = box.checkWire(at: 0)
        #expect(valid.isValid, "a box face's wire is connected and non-empty")
        #expect(valid.errorCount == 0)
        #expect(valid.firstError == nil)

        // `BRepCheck_Wire::Minimum()` raises `EmptyWire` for nbedge == 0 before it reaches the
        // connectivity walk. `TopoDS_Builder::Add` is the only route to a wire with no edges;
        // `BRepBuilderAPI_MakeWire` refuses to build one.
        let empty = try #require(Shape.builderMakeWire())
        #expect(empty.subShapes(ofType: .edge).isEmpty, "fixture should carry no edge")
        let faulted = empty.checkWire(at: 0)
        #expect(!faulted.isValid)
        #expect(faulted.errorCount == 1)
        #expect(faulted.firstError == .emptyWire)

        let refused = box.checkWire(at: box.subShapes(ofType: .wire).count)
        #expect(!refused.isValid)
        #expect(refused.errorCount == 0, "a refusal is not a fault")
        #expect(refused.firstError == nil)
    }

    @Test("Check shell validity")
    func shellValid() throws {
        let box = try makeBox()
        let valid = box.checkShell(at: 0)
        #expect(valid.isValid, "a box's shell is connected")
        #expect(valid.errorCount == 0)
        #expect(valid.firstError == nil)

        let near = try #require(
            Shape.faceFromPlane(
                origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
                uRange: 0...1, vRange: 0...1))
        let far = try #require(
            Shape.faceFromPlane(
                origin: SIMD3(50, 50, 50), normal: SIMD3(0, 0, 1),
                uRange: 0...1, vRange: 0...1))

        // Two faces sharing no edge: `BRepCheck_Shell::Minimum()`'s `Propagate` reaches one of
        // the two, so nbface and the propagated count disagree and it raises `NotConnected`.
        let split = try #require(Shape.builderMakeShell())
        #expect(split.builderAdd(near))
        #expect(split.builderAdd(far))
        #expect(split.subShapes(ofType: .face).count == 2)
        let faulted = split.checkShell(at: 0)
        #expect(!faulted.isValid)
        #expect(faulted.errorCount == 1)
        #expect(faulted.firstError == .notConnected)

        // The same construction with one face is valid, which isolates disconnection as the
        // thing being measured rather than "a hand-built shell is rejected".
        let single = try #require(Shape.builderMakeShell())
        #expect(single.builderAdd(near))
        let singleResult = single.checkShell(at: 0)
        #expect(singleResult.isValid, "nbface < 2 never reaches the connectivity walk")
        #expect(singleResult.errorCount == 0)

        let refused = box.checkShell(at: box.subShapes(ofType: .shell).count)
        #expect(!refused.isValid)
        #expect(refused.errorCount == 0, "a refusal is not a fault")
        #expect(refused.firstError == nil)
    }

    /// `checkVertex(at:)` cannot report a fault, for any vertex.
    ///
    /// `BRepCheck_Vertex::Minimum()`'s entire body is `Append(BRepCheck_NoError)` with no
    /// condition (#2747), so there is no "invalid vertex" answer to measure and no fixture that
    /// could produce one. What this test pins instead is that documented invariant: a vertex
    /// placed absurdly and given a tolerance seven orders of magnitude past
    /// `Precision::Confusion()` still reads valid. The assertion fails if the bridge ever grows a
    /// vertex rule of its own, or starts calling `InContext()`, both of which would change the
    /// contract the doc comment on `Shape.checkVertex(at:)` states.
    ///
    /// The only `false` this entry point can produce is the index refusal, which is pinned below
    /// and is the one half of the two-answer requirement a vertex fixture can satisfy.
    @Test("Check vertex validity")
    func vertexValid() throws {
        let box = try makeBox()
        let valid = box.checkVertex(at: 0)
        #expect(valid.isValid)
        #expect(valid.errorCount == 0)
        #expect(valid.firstError == nil)

        let absurd = try #require(Shape.vertex(at: SIMD3(1e12, -1e12, 1e12)))
        #expect(absurd.fixTolerance(1e6))
        #expect(absurd.maxTolerance(type: 0) == 1e6, "fixture should carry the absurd tolerance")
        let stillValid = absurd.checkVertex(at: 0)
        #expect(stillValid.isValid, "Minimum() has no branch that could say otherwise")
        #expect(stillValid.errorCount == 0)
        #expect(stillValid.firstError == nil)

        let refused = box.checkVertex(at: box.subShapes(ofType: .vertex).count)
        #expect(!refused.isValid)
        #expect(refused.errorCount == 0, "a refusal is not a fault")
        #expect(refused.firstError == nil)
    }
}
