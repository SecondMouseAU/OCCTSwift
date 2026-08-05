import Testing
import Foundation
@testable import OCCTSwift

// #638: `Shape.edges()` has the identical `TopExp::MapShapes`/`IsSame` collapse #614 fixed for
// `faces()`: 24 edge occurrences over 12 distinct edges on a plain box. #614 was a defect because
// `Face.normal(atU:v:)` reverses on `TopAbs_REVERSED`, so a face's stored orientation changes the
// answer it returns. This issue's own text refuses the analogy and asks for the equivalent
// question to be answered for edges before assuming it is the same bug.
//
// The consumer audit (Cluster A's census, #664, `Scripts/repro/cluster-a-subshape-enumeration/`)
// found none: `Edge` exposes no `.orientation` accessor, and a bridge-wide grep for
// `.Orientation() ==` finds 14 sites, 13 face-related (already #614's territory) and one
// (`occtSampleWirePoints`) that reads orientation fresh off a wire traversal, never from an edge
// `Shape.edges()` produced. The decision is: document the collapse, add no `orientedEdges()`,
// change no behaviour.
//
// These tests pin both halves of that decision so a future change cannot silently invalidate it.
//  1. The dedup mechanism itself: `edges()`/`edgeCount` must stay the IsSame-keyed enumeration,
//     not drift to a per-occurrence walk.
//  2. The reason the collapse is safe: every geometric accessor on `Edge` must keep reading the
//     underlying curve independently of the edge's own `TopAbs_Orientation`, verified directly by
//     constructing the identical edge with both orientations and comparing every accessor.

@Suite("edges() keeps its orientation collapse, and nothing reads the lost side (#638)")
struct Issue638EdgeOrientationContractTests {

    // MARK: - 1. The dedup mechanism does not regress

    /// The headline measurement from the issue and the census: 24 occurrences, 12 distinct, on a
    /// plain box. `contents.edges` is the independent, already-documented (#541) occurrence
    /// oracle: it does not go through `edges()`/`edgeCount` at all, so it is not circular.
    @Test("a plain box: 12 distinct edges, 24 occurrences")
    func plainBoxEdgeCollapse() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        #expect(box.edgeCount == 12)
        #expect(box.edges().count == 12)
        #expect(box.subShapeCount(ofType: .edge) == 12)
        #expect(box.contents.edges == 24)
    }

    /// The same collapse on a shape that genuinely shares an edge across two solids: #614's own
    /// fixture, reused rather than re-derived. `edges()` must stay at the dedup count (20), not
    /// drift toward the per-occurrence count.
    @Test("a split-box compound: edges() stays on the dedup count")
    func splitCompoundEdgeCollapse() {
        guard let compound = Issue614FaceOrientationTests.splitBoxCompound() else {
            Issue.record("could not build the split-box compound")
            return
        }

        #expect(compound.edgeCount == 20)
        #expect(compound.edges().count == 20)
        #expect(compound.subShapeCount(ofType: .edge) == 20)
        // Every edge of the shared wall (4 of them) is walked from both owning solids: the
        // occurrence count is strictly greater than the distinct count.
        #expect(compound.contents.edges > compound.edgeCount)
    }

    /// Every edge handed out by `edges()` is addressable through `edge(at:)` at its own position,
    /// the same indexing guarantee `faces()`/`faceCount` carry (#541), stated here for edges so a
    /// future change cannot quietly break it while this suite is green.
    @Test("every entry in edges() is addressable by its own index")
    func edgesAreAddressableByIndex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.edges()
        #expect(edges.count == box.edgeCount)
        for (i, edge) in edges.enumerated() {
            #expect(edge.index == i)
            #expect(box.edge(at: i) != nil)
        }
    }

    // MARK: - 2. Edge's accessors do not depend on the collapsed-away orientation

    /// Build the identical edge with both `TopAbs_Orientation`s and compare every geometric
    /// accessor `Edge` exposes. If any of these ever starts reading orientation (e.g. an
    /// orientation-aware `BRepAdaptor_Curve` replacing today's `BRep_Tool::Curve`), this is the
    /// test that catches it. The pair below is guaranteed opposite by construction
    /// (`Shape.reversed`), not by hoping a fixture's topology happens to produce two orientations.
    @Test("Edge's per-instance accessors do not depend on TopAbs_Orientation")
    func edgeAccessorsAreOrientationIndependent() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let forwardShape = box.subShapes(ofType: .edge).first,
              let reversedShape = forwardShape.reversed,
              let forwardEdge = Edge(forwardShape),
              let reversedEdge = Edge(reversedShape)
        else {
            Issue.record("could not build a forward/reversed edge pair")
            return
        }

        // The construction really did flip the flag; otherwise every comparison below would pass
        // vacuously by comparing an edge against itself in all but name.
        #expect(forwardShape.orientation != reversedShape.orientation)

        #expect(forwardEdge.length == reversedEdge.length)
        #expect(forwardEdge.isLine == reversedEdge.isLine)
        #expect(forwardEdge.isCircle == reversedEdge.isCircle)
        #expect(forwardEdge.curveType == reversedEdge.curveType)

        let fBounds = forwardEdge.parameterBounds
        let rBounds = reversedEdge.parameterBounds
        #expect(fBounds != nil && rBounds != nil)
        if let fBounds, let rBounds {
            #expect(fBounds.first == rBounds.first)
            #expect(fBounds.last == rBounds.last)
        }

        // Sample several parameters across the edge's own range, not just the midpoint.
        if let bounds = fBounds {
            for t in [0.0, 0.25, 0.5, 0.75, 1.0] {
                let param = bounds.first + t * (bounds.last - bounds.first)
                let fp = forwardEdge.point(at: param)
                let rp = reversedEdge.point(at: param)
                #expect(fp != nil && rp != nil)
                if let fp, let rp {
                    #expect(fp == rp, "point(at: \(param)) diverged: \(fp) vs \(rp)")
                }

                let ft = forwardEdge.tangent(at: param)
                let rt = reversedEdge.tangent(at: param)
                #expect(ft != nil && rt != nil)
                if let ft, let rt {
                    #expect(ft == rt, "tangent(at: \(param)) diverged: \(ft) vs \(rt)")
                }

                let fc = forwardEdge.curvature(at: param)
                let rc = reversedEdge.curvature(at: param)
                #expect(fc == rc, "curvature(at: \(param)) diverged: \(String(describing: fc)) vs \(String(describing: rc))")
            }
        }

        // endpoints/bounds/points(count:) are whole-edge queries; still must agree.
        #expect(forwardEdge.endpoints.start == reversedEdge.endpoints.start)
        #expect(forwardEdge.endpoints.end == reversedEdge.endpoints.end)
        #expect(forwardEdge.bounds.min == reversedEdge.bounds.min)
        #expect(forwardEdge.bounds.max == reversedEdge.bounds.max)
    }

    /// Same comparison, on a circular edge rather than a straight one, so the claim isn't
    /// accidentally true only for lines (whose tangent direction some implementations special-case).
    @Test("Edge's accessors are orientation-independent on a circular edge too")
    func edgeAccessorsAreOrientationIndependentOnACircle() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        guard let circleShape = cyl.subShapes(ofType: .edge).first(where: { shape in
            guard let e = Edge(shape) else { return false }
            return e.isCircle
        }) else {
            Issue.record("no circular edge found on the cylinder")
            return
        }
        guard let reversedShape = circleShape.reversed,
              let forwardEdge = Edge(circleShape),
              let reversedEdge = Edge(reversedShape)
        else {
            Issue.record("could not build a forward/reversed circular edge pair")
            return
        }

        #expect(circleShape.orientation != reversedShape.orientation)
        #expect(forwardEdge.length == reversedEdge.length)

        guard let bounds = forwardEdge.parameterBounds else {
            Issue.record("circular edge reported no parameter bounds")
            return
        }
        for t in [0.0, 0.3, 0.6, 1.0] {
            let param = bounds.first + t * (bounds.last - bounds.first)
            #expect(forwardEdge.point(at: param) == reversedEdge.point(at: param))
            #expect(forwardEdge.tangent(at: param) == reversedEdge.tangent(at: param))
        }
    }

    /// `adjacentFaces(in:)` is a relationship lookup, not a curve evaluation, but it takes the
    /// edge's own handle. Pin that it too resolves the same pair of faces regardless of which
    /// orientation the caller's `Edge` happens to carry.
    @Test("adjacentFaces(in:) does not depend on the edge's own orientation")
    func adjacentFacesIsOrientationIndependent() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let forwardShape = box.subShapes(ofType: .edge).first,
              let reversedShape = forwardShape.reversed,
              let forwardEdge = Edge(forwardShape),
              let reversedEdge = Edge(reversedShape)
        else {
            Issue.record("could not build a forward/reversed edge pair")
            return
        }

        guard let (f1, f2) = forwardEdge.adjacentFaces(in: box),
              let (r1, r2) = reversedEdge.adjacentFaces(in: box)
        else {
            Issue.record("edge reported no adjacent faces")
            return
        }
        // Same physical pair of faces either way (order may or may not be preserved, so compare
        // as sets of index; every face here carries a valid index from box.faces()).
        let forwardIndices = Set([f1, f2].compactMap { $0?.index })
        let reversedIndices = Set([r1, r2].compactMap { $0?.index })
        #expect(!forwardIndices.isEmpty)
        #expect(forwardIndices == reversedIndices)
    }
}
