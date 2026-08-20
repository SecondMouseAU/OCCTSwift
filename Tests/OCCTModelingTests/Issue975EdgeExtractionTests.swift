import Testing

@testable import OCCTSwift

/// #975: `OCCTChFi2dFilletAlgo` and `OCCTChFi2dAnaFillet` each carried a byte-identical copy of a
/// 24-line "first edge of this shape" block, and so did `OCCTBRepExtremaExtCCEdges`
/// (`OCCTBridge_Topology.mm`) and `OCCTWireMakeWireFromEdges` (`OCCTBridge_Modeling.mm`). All four
/// now call `occtEdgeAt(shape, 0)`, the helper `OCCTBRepExtremaExtCC` (forty lines above one of
/// those copies, in the same file) had already been converted to by #613.
///
/// The two ChFi2d entry points are the only two of the four reachable from Swift: nothing in
/// `Sources/OCCTSwift` calls `OCCTBRepExtremaExtCCEdges` or `OCCTWireMakeWireFromEdges`. The
/// C++ probe in `Scripts/repro/975-first-edge-idiom/` is what covers those two.
///
/// What was untested here is the branch that made the block long enough to copy: passing a shape
/// that is not itself an edge. Nothing asserted that the container branch and the bare-edge branch
/// pick the same edge, or that a multi-edge container yields its *first* edge rather than some
/// other one.
@Suite("ChFi2d edge extraction: one first-edge answer (#975)")
struct Issue975EdgeExtraction {

    /// An open polyline of three segments with three distinct lengths, so which pair of segments a
    /// fillet was handed is readable off the trimmed lengths alone:
    ///
    ///   A (0,0) -> (10,0)      10 long
    ///   B (10,0) -> (10,20)    20 long
    ///   C (10,20) -> (-30,20)  40 long
    ///
    /// Every corner is a right angle, so a radius-2 fillet trims 2 from each of its two edges and
    /// leaves a quarter-circle arc of length pi. Filleting A+B gives (8, 18); B+C gives (18, 38).
    private func polyline() -> Wire? {
        Wire.polygon(
            [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 20), SIMD2(-30, 20)],
            closed: false)
    }

    private func lengths(_ r: Shape.AnaFilletResult) -> (arc: Double, e1: Double, e2: Double) {
        (r.fillet.edgeArcLength, r.edge1.edgeArcLength, r.edge2.edgeArcLength)
    }

    private func lengths(_ r: Shape.FilletAlgoResult) -> (arc: Double, e1: Double, e2: Double) {
        (r.fillet.edgeArcLength, r.edge1.edgeArcLength, r.edge2.edgeArcLength)
    }

    /// The three segments, each wrapped bare and as a single-edge wire.
    private func segments() -> (bare: [Shape], wires: [Shape])? {
        guard let w = polyline() else { return nil }
        let edges = w.edges()
        guard edges.count == 3 else { return nil }
        var bare: [Shape] = []
        var wires: [Shape] = []
        for e in edges {
            guard let b = Shape.fromEdge(e),
                let wire = Wire.wireFromEdges([e]),
                let ws = Shape.fromWire(wire)
            else { return nil }
            bare.append(b)
            wires.append(ws)
        }
        // The fixture means what its name says only if the three segments really are 10/20/40.
        guard abs(bare[0].edgeArcLength - 10) < 1e-9,
            abs(bare[1].edgeArcLength - 20) < 1e-9,
            abs(bare[2].edgeArcLength - 40) < 1e-9
        else { return nil }
        return (bare, wires)
    }

    // MARK: - The bare-edge branch and the container branch pick the same edge

    @Test("anaFillet: a one-edge wire fillets exactly as that bare edge does")
    func anaFilletAgreesBetweenBareEdgeAndWire() {
        guard let s = segments() else {
            Issue.record("the 10/20/40 polyline fixture should build")
            return
        }
        guard let fromBare = Shape.anaFillet(edge1: s.bare[0], edge2: s.bare[1], radius: 2.0),
            let fromWire = Shape.anaFillet(edge1: s.wires[0], edge2: s.wires[1], radius: 2.0)
        else {
            Issue.record("both spellings should fillet")
            return
        }
        // The operation did something, and did it to segments A and B: quarter-circle arc, and
        // 2 trimmed off each of a 10 and a 20.
        let bare = lengths(fromBare)
        #expect(abs(bare.arc - .pi) < 1e-6)
        #expect(abs(bare.e1 - 8) < 1e-6)
        #expect(abs(bare.e2 - 18) < 1e-6)

        let wire = lengths(fromWire)
        #expect(abs(bare.arc - wire.arc) < 1e-9)
        #expect(abs(bare.e1 - wire.e1) < 1e-9)
        #expect(abs(bare.e2 - wire.e2) < 1e-9)
    }

    @Test("filletAlgo: a one-edge wire fillets exactly as that bare edge does")
    func filletAlgoAgreesBetweenBareEdgeAndWire() {
        guard let s = segments() else {
            Issue.record("the 10/20/40 polyline fixture should build")
            return
        }
        guard let fromBare = Shape.filletAlgo(edge1: s.bare[0], edge2: s.bare[1], radius: 2.0),
            let fromWire = Shape.filletAlgo(edge1: s.wires[0], edge2: s.wires[1], radius: 2.0)
        else {
            Issue.record("both spellings should fillet")
            return
        }
        let bare = lengths(fromBare)
        #expect(abs(bare.arc - .pi) < 1e-6)
        #expect(abs(bare.e1 - 8) < 1e-6)
        #expect(abs(bare.e2 - 18) < 1e-6)

        let wire = lengths(fromWire)
        #expect(fromBare.resultCount == fromWire.resultCount)
        #expect(abs(bare.arc - wire.arc) < 1e-9)
        #expect(abs(bare.e1 - wire.e1) < 1e-9)
        #expect(abs(bare.e2 - wire.e2) < 1e-9)
    }

    // MARK: - A multi-edge container yields its FIRST edge, not some other one

    /// `edge1` is the whole three-segment wire (first edge A, 10 long) and `edge2` is a two-edge
    /// wire holding B then C (first edge B, 20 long). Reading index 0 from each gives A+B and the
    /// trimmed lengths (8, 18); reading index 1 would give B+C, a corner that fillets perfectly
    /// well and reports (18, 38), so this fixture separates the two answers rather than merely
    /// failing on one of them.
    private func nestedContainers() -> (whole: Shape, tail: Shape)? {
        guard let w = polyline() else { return nil }
        let edges = w.edges()
        guard edges.count == 3,
            let whole = Shape.fromWire(w),
            let tailWire = Wire.wireFromEdges([edges[1], edges[2]]),
            let tail = Shape.fromWire(tailWire)
        else { return nil }
        return (whole, tail)
    }

    @Test("anaFillet: a multi-edge wire passed whole reads its first edge")
    func anaFilletReadsTheFirstEdgeOfAMultiEdgeShape() {
        guard let c = nestedContainers() else {
            Issue.record("the nested-container fixture should build")
            return
        }
        guard let r = Shape.anaFillet(edge1: c.whole, edge2: c.tail, radius: 2.0) else {
            Issue.record("anaFillet should succeed on the A+B corner")
            return
        }
        let l = lengths(r)
        #expect(abs(l.arc - .pi) < 1e-6)
        #expect(abs(l.e1 - 8) < 1e-6)  // segment A trimmed, not B (which would be 18)
        #expect(abs(l.e2 - 18) < 1e-6)  // segment B trimmed, not C (which would be 38)
    }

    @Test("filletAlgo: a multi-edge wire passed whole reads its first edge")
    func filletAlgoReadsTheFirstEdgeOfAMultiEdgeShape() {
        guard let c = nestedContainers() else {
            Issue.record("the nested-container fixture should build")
            return
        }
        guard let r = Shape.filletAlgo(edge1: c.whole, edge2: c.tail, radius: 2.0) else {
            Issue.record("filletAlgo should succeed on the A+B corner")
            return
        }
        let l = lengths(r)
        #expect(abs(l.arc - .pi) < 1e-6)
        #expect(abs(l.e1 - 8) < 1e-6)
        #expect(abs(l.e2 - 18) < 1e-6)
    }

    // MARK: - The two ChFi2d entry points agree on which edge they were handed

    @Test("anaFillet and filletAlgo trim the same containers to the same lengths")
    func bothChFi2dEntryPointsReadTheSameEdges() {
        guard let c = nestedContainers() else {
            Issue.record("the nested-container fixture should build")
            return
        }
        guard let ana = Shape.anaFillet(edge1: c.whole, edge2: c.tail, radius: 2.0),
            let algo = Shape.filletAlgo(edge1: c.whole, edge2: c.tail, radius: 2.0)
        else {
            Issue.record("both entry points should fillet the same pair")
            return
        }
        // Different OCCT algorithms (ChFi2d_AnaFilletAlgo vs ChFi2d_FilletAlgo), so this compares
        // to a tolerance rather than bit for bit; what it pins is that both were handed the same
        // two edges out of the same two containers.
        let a = lengths(ana)
        let b = lengths(algo)
        #expect(abs(a.arc - b.arc) < 1e-6)
        #expect(abs(a.e1 - b.e1) < 1e-6)
        #expect(abs(a.e2 - b.e2) < 1e-6)
    }
}
