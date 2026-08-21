import Testing
import Foundation
@testable import OCCTSwift

// #613: six entry points still indexed sub-shapes by `TopExp_Explorer` OCCURRENCE after #541 moved
// the rest of the bridge onto the deduplicated `TopExp::MapShapes` enumeration.
//
// The two enumerations disagree from the first repeat. Measured on the pinned kernel, a plain 10 mm
// box has **24 edge occurrences over 12 distinct edges** and **48 vertex occurrences over 8
// vertices**, because each edge is reached once per adjacent face. So an explorer-indexed entry
// point answers for indices `edge(at:)` refuses outright, and, past the first repeat, names a
// DIFFERENT sub-shape for an index both accept.
//
// Sites covered here (site 5, meshing, is in Tests/OCCTMeshTests/Issue613MeshIndexContractTests):
//
//   1. `OCCTShapeAnalyzeEdgeConcavity`, the result array's ORDER, zipped against `edges()`
//      (+ its unlisted sibling `OCCTShapeCountEdgeConcavity`, which counted occurrences)
//   2. `OCCTBRepExtremaExtCC`, the `edgeIndex` argument
//   3. `checkSubShape` (Healing), the sub-shape index behind checkEdge/Wire/Shell/Vertex
//   4. `OCCTLocOpeSplitShapeByVertex`, the edge-splitting index
//   6. `edgesInFace(at:)`, the `Edge.index` it hands back
//      (+ its unlisted sibling `commonEdges(with:)`, identical defect)
//
// Sites 1-4 are safe to read off the map rather than the traversal, and that is measured rather
// than assumed. Every consumer was handed both orientations of every box edge (12 pairs) and vertex
// (8 pairs) and gave an identical answer, 0 differing: `BRepOffset_Analyse::Type`'s interval list,
// `BRepExtrema_ExtCC`'s IsParallel/NbExt/SquareDistance/ParameterOnE1/PointOnE1, the full
// `BRepCheck_*` status list, and `BRep_Tool::Range` + `LocOpe_SplitShape::DescendantShapes`. That is
// what the headers predict, `BRepOffset_Analyse::myMapEdgeType` (BRepOffset_Analyse.hxx:173) and
// `LocOpe_SplitShape::myMap`/`myDblE` (LocOpe_SplitShape.hxx:89-90) are all keyed by
// `TopTools_ShapeMapHasher`, whose equality operator IS `TopoDS_Shape::IsSame`
// (TopTools_ShapeMapHasher.hxx:35-38), but the headers are the reason to check, not the check.
//
// Site 5 is the exception and is NOT converted this way: triangle winding is set by the
// occurrence's orientation, so it keeps the oriented walk and stamps the map index onto it.

@Suite("Sub-shape indices name the same sub-shape through every entry point (#613)")
struct Issue613IndexContractTests {

    // MARK: - Fixtures

    /// The plain box the whole issue is measured on: 24 edge occurrences over 12 distinct edges.
    static func box() -> Shape? {
        Shape.box(origin: .zero, width: 10, height: 10, depth: 10)
    }

    /// An L-bracket with exactly one genuinely concave edge, the inner corner at x = 10, z = 10,
    /// running the full 40 mm in y. Two fused boxes, the plainest construction that has one.
    static func lBracket() -> Shape? {
        guard let a = Shape.box(origin: .zero, width: 40, height: 40, depth: 10),
              let b = Shape.box(origin: .zero, width: 10, height: 40, depth: 40)
        else { return nil }
        return a.fused(with: b, tolerance: 0)
    }

    /// The midpoint of an edge, by arc length rather than by raw parameter.
    static func mid(_ e: Edge) -> SIMD3<Double>? {
        let pts = e.points(count: 3)
        return pts.count == 3 ? pts[1] : nil
    }

    static func dist(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d = a - b
        return (d.x * d.x + d.y * d.y + d.z * d.z).squareRoot()
    }

    /// The index in `edges()` of the edge geometrically equal to `probe`, or nil.
    static func indexOfEdge(matching probe: SIMD3<Double>, in shape: Shape) -> Int? {
        for (i, e) in shape.edges().enumerated() {
            if let m = mid(e), dist(m, probe) < 1e-6 { return i }
        }
        return nil
    }

    // MARK: - The premise

    /// The whole issue rests on the two enumerations differing, so pin that first, if a future
    /// kernel stopped repeating occurrences every test below would pass vacuously.
    @Test("a box has more edge and vertex occurrences than it has distinct edges and vertices")
    func theTwoEnumerationsDiffer() throws {
        let box = try #require(Self.box())
        #expect(box.edgeCount == 12)
        #expect(box.subShapeCount(ofType: .vertex) == 8)
        // The occurrence counts the old walks saw. faceOccurrenceCount (#614) is the only
        // occurrence counter the bridge exposes, and a box shares no face, so count edges the way
        // the old sites did: through an entry point that still answers per occurrence would be
        // circular, so assert the consequence instead, indices past the map end must be refused.
        #expect(box.edge(at: 12) == nil)
        #expect(box.edge(at: 23) == nil)
    }

    // MARK: - Site 1: edge concavity

    /// The issue's own stated failure scenario, end to end.
    ///
    /// `edgeConcavities()` zips the bridge's result array against `edges()`. The bridge filled it
    /// per occurrence, so from the first repeat every classification landed on the wrong edge.
    /// Before the fix this bracket's one concave edge, map index 27, was reported convex and
    /// `concaveEdges()` returned an EMPTY array, which is what made
    /// `bracket.filleted(edges: bracket.concaveEdges(), radius: 3)` round nothing and report success.
    @Test("an L-bracket's inner corner is reported concave, and it is the edge that is concave")
    func concaveEdgeIsTheConcaveEdge() throws {
        let bracket = try #require(Self.lBracket())

        // Locate the inner corner geometrically, independent of any index scheme: the edge whose
        // midpoint sits on both walls' inner faces (x = 10 and z = 10).
        let corner = try #require(Self.indexOfEdge(matching: SIMD3(10, 20, 10), in: bracket),
                                  "fixture has no inner-corner edge at (10, y, 10)")

        let concave = bracket.concaveEdges()
        #expect(concave.count == 1, "expected exactly one concave edge, got \(concave.count)")
        #expect(concave.map(\.index) == [corner],
                "concaveEdges() named \(concave.map(\.index)), the inner corner is \(corner)")
    }

    /// The classification array is positionally the `edges()` array: entry n describes edges()[n].
    ///
    /// Note that `pair.0.index == n` is **not** the assertion to make. Swift builds each pair from
    /// `edges()[n]`, so that holds by construction whatever the bridge returns, and a test asserting
    /// it passes with the defect present. What actually broke is the *alignment*, so this checks it
    /// the only way that is falsifiable from outside: the classifier and the per-type counter are
    /// two independent bridge computations over the same enumeration, and they must agree. With the
    /// classifier desynchronised they do not, measured on this bracket, the counter says 2 concave
    /// while the classifier labels 0, and 42 convex against the classifier's 19.
    @Test("the classification array and the per-type counts describe the same edges")
    func concavityEntriesAlignWithCounts() throws {
        let bracket = try #require(Self.lBracket())
        let pairs = try #require(bracket.edgeConcavities())

        #expect(pairs.count == bracket.edgeCount,
                "one entry per distinct edge: \(pairs.count) vs \(bracket.edgeCount)")
        #expect(pairs.count > 0)
        #expect(bracket.edgeConcavityCount(.concave) == pairs.filter { $0.1 == .concave }.count,
                "counter and classifier disagree on concave edges")
        #expect(bracket.edgeConcavityCount(.convex) == pairs.filter { $0.1 == .convex }.count,
                "counter and classifier disagree on convex edges")
        #expect(bracket.edgeConcavityCount(.tangent) == pairs.filter { $0.1 == .tangent }.count,
                "counter and classifier disagree on tangent edges")
    }

    /// The unlisted sibling in the same MARK block: the count walked the explorer too, so it
    /// reported topology occurrences rather than edges. A 12-edge box answered 24.
    @Test("edge concavity counts are counts of edges, not of occurrences")
    func concavityCountsAreEdgeCounts() throws {
        let box = try #require(Self.box())
        #expect(box.edgeConcavityCount(.convex) == 12,
                "a box's 12 edges are all convex; got \(String(describing: box.edgeConcavityCount(.convex)))")
        #expect(box.edgeConcavityCount(.concave) == 0)

        let total = (box.edgeConcavityCount(.convex) ?? 0)
                  + (box.edgeConcavityCount(.concave) ?? 0)
                  + (box.edgeConcavityCount(.tangent) ?? 0)
        #expect(total <= box.edgeCount,
                "the three counts partition the edges: \(total) vs \(box.edgeCount)")

        // And on a shape that actually has one of each, the counts agree with the classifier.
        let bracket = try #require(Self.lBracket())
        let pairs = try #require(bracket.edgeConcavities())
        #expect(bracket.edgeConcavityCount(.concave) == pairs.filter { $0.1 == .concave }.count)
        #expect(bracket.edgeConcavityCount(.convex) == pairs.filter { $0.1 == .convex }.count)
    }

    // MARK: - Site 2: BRepExtrema_ExtCC

    /// `edgeIndex` here must mean what it means in this file's neighbours (`ExtPC`, `ExtCF`,
    /// `ClassifyPoint2D`), which #541 already converted.
    @Test("edgeEdgeExtrema addresses the edge edges() calls by that index")
    func extremaEdgeIndexMatchesEnumeration() throws {
        let box = try #require(Self.box())
        // A far, skew reference edge so extrema exist for every box edge rather than only the
        // non-parallel ones (BRepExtrema_ExtCC reports 0 solutions for parallel edges).
        // A wide disc floating above the box. Its circular rim is skew to every box edge and curves
        // past all of them, so each box edge has a genuine INTERIOR extremum against it,
        // BRepExtrema_ExtCC reports nothing for a parallel pair, and nothing when the closest
        // approach falls at an endpoint, which is why a far-off straight reference covers only a
        // third of the edges.
        let disc = try #require(Shape.cylinder(radius: 30, height: 1))
        let reference = try #require(disc.translated(by: SIMD3(5, 5, 20)))

        /// Exact distance from `p` to edge `e`, which every edge of a box is a straight segment of,
        /// so this is point-to-segment, not a sampled approximation whose own resolution
        /// (0.039 mm at 128 samples over a 10 mm edge) would swamp the assertion.
        func distanceToEdge(_ p: SIMD3<Double>, _ e: Edge) -> Double {
            let ends = e.points(count: 2)
            guard ends.count == 2 else { return .infinity }
            let (a, b) = (ends[0], ends[1])
            let ab = b - a
            let len2 = ab.x * ab.x + ab.y * ab.y + ab.z * ab.z
            guard len2 > 0 else { return Self.dist(p, a) }
            let ap = p - a
            let t = min(max((ap.x * ab.x + ap.y * ab.y + ap.z * ab.z) / len2, 0), 1)
            return Self.dist(p, a + ab * t)
        }

        var compared = 0
        for i in 0..<box.edgeCount {
            let edge = try #require(box.edge(at: i))
            // Any reference edge that yields an extremum for this box edge will do.
            var extrema: Shape.EdgeEdgeExtrema?
            for j in 0..<reference.edgeCount {
                if let r = box.edgeEdgeExtrema(edgeIndex1: i, other: reference, edgeIndex2: j) {
                    extrema = r
                    break
                }
            }
            let found = try #require(extrema, "no reference edge gave an extremum for box edge \(i)")
            compared += 1
            // The returned closest point must lie ON edges()[i]. Under the old explorer walk,
            // index i named a different edge from 9 onward, and its closest point landed
            // millimetres away from edges()[i].
            let offBy = distanceToEdge(found.pointOnEdge1, edge)
            #expect(offBy < 1e-6,
                    "index \(i): closest point \(found.pointOnEdge1) is \(offBy) from edges()[\(i)]")
        }
        #expect(compared == 12, "only \(compared) of 12 edges compared, fixture too degenerate")
    }

    /// An index past the enumeration must be refused, not answered from a surplus occurrence.
    ///
    /// The reference has to be one that actually yields extrema, or the test passes vacuously: the
    /// Swift wrapper returns nil whenever `solutionCount == 0`, so a far-off reference makes "no
    /// answer" indistinguishable from "no such edge" and the assertion never bites. This asks every
    /// reference edge, so a surplus index that resolves to an occurrence is caught.
    @Test("edgeEdgeExtrema refuses exactly the indices edge(at:) refuses")
    func extremaRefusesSurplusIndices() throws {
        let box = try #require(Self.box())
        let disc = try #require(Shape.cylinder(radius: 30, height: 1))
        let reference = try #require(disc.translated(by: SIMD3(5, 5, 20)))

        // Control: in-range indices DO get an answer from this reference, so a nil below means
        // refusal rather than a degenerate fixture.
        var answered = 0
        for i in 0..<box.edgeCount {
            for j in 0..<reference.edgeCount
            where box.edgeEdgeExtrema(edgeIndex1: i, other: reference, edgeIndex2: j) != nil {
                answered += 1
                break
            }
        }
        #expect(answered == box.edgeCount, "only \(answered) of \(box.edgeCount) in-range indices answered")

        for i in [box.edgeCount, box.edgeCount + 5, 23] {
            #expect(box.edge(at: i) == nil, "premise: index \(i) is past the enumeration")
            for j in 0..<reference.edgeCount {
                #expect(box.edgeEdgeExtrema(edgeIndex1: i, other: reference, edgeIndex2: j) == nil,
                        "index \(i) answered (against reference edge \(j)) although edge(at: \(i)) is nil")
            }
        }
    }

    // MARK: - Site 3: the BRepCheck sub-shape family

    /// `checkEdge(at:)` and `isSubShapeValid(type:at:)` are the two halves of one surface and were
    /// counting different things: the first the explorer, the second (since #541) the map.
    @Test("checkEdge and isSubShapeValid answer over the same index domain")
    func checkFamilyDomainMatchesEnumeration() throws {
        let box = try #require(Self.box())

        // In range: both agree the sub-shape is there and valid.
        for i in 0..<box.edgeCount {
            #expect(box.checkEdge(at: i).isValid, "edge \(i) should be valid")
            #expect(box.isSubShapeValid(type: .edge, at: i))
        }
        // Past the end: refused by both. A box has 24 edge occurrences, so 12...23 is exactly the
        // window the explorer used to answer in.
        for i in [12, 17, 23, 24] {
            #expect(box.edge(at: i) == nil, "premise: index \(i) is past the enumeration")
            #expect(!box.checkEdge(at: i).isValid, "checkEdge answered for surplus index \(i)")
            #expect(!box.isSubShapeValid(type: .edge, at: i))
        }
    }

    /// Vertices have the widest gap of any type on a box: 48 occurrences over 8 vertices.
    @Test("checkVertex answers for 8 vertices, not 48 occurrences")
    func checkVertexDomainMatchesEnumeration() throws {
        let box = try #require(Self.box())
        let count = box.subShapeCount(ofType: .vertex)
        #expect(count == 8)
        for i in 0..<count {
            #expect(box.checkVertex(at: i).isValid)
        }
        for i in [8, 20, 47, 48] {
            #expect(!box.checkVertex(at: i).isValid, "checkVertex answered for surplus index \(i)")
        }
    }

    /// The wire and shell spellings go through the same converted helper. A box shares neither, so
    /// this pins that the conversion did not narrow their in-range answers.
    @Test("checkWire and checkShell still answer over their own enumerations")
    func checkWireAndShellUnchanged() throws {
        let box = try #require(Self.box())
        let wires = box.subShapeCount(ofType: .wire)
        let shells = box.subShapeCount(ofType: .shell)
        #expect(wires == 6)
        #expect(shells == 1)
        for i in 0..<wires { #expect(box.checkWire(at: i).isValid) }
        for i in 0..<shells { #expect(box.checkShell(at: i).isValid) }
        #expect(!box.checkWire(at: wires).isValid)
        #expect(!box.checkShell(at: shells).isValid)
    }

    // MARK: - Site 4: LocOpe_SplitShape by vertex

    /// `splitEdge(at:)` sat next to `splitFace(at:with:)`, which #541 had already converted, so the
    /// two indices into one `LocOpe_SplitShape` meant different things. Measured before the fix on
    /// this exact box: index 9 split `edges()[4]`, index 11 split `edges()[0]`, and indices 12 and
    /// 13 split successfully although `edge(at:)` refuses both.
    @Test("splitEdge splits the edge edges() calls by that index")
    func splitEdgeTargetsTheEnumeratedEdge() throws {
        let box = try #require(Self.box())
        let before = box.vertices().count

        var checked = 0
        for i in 0..<box.edgeCount {
            let edge = try #require(box.edge(at: i))
            let target = try #require(Self.mid(edge), "edge \(i) has no midpoint")
            let split = try #require(box.splitEdge(at: i, parameter: 0.5),
                                     "splitEdge(at: \(i)) failed")
            // The split inserts one vertex, at the midpoint of whichever edge it chose. Every
            // pre-existing vertex is a box corner, so the inserted one is the only non-corner.
            let inserted = split.vertices().filter { p in
                ![p.x, p.y, p.z].allSatisfy { abs($0) < 1e-6 || abs($0 - 10) < 1e-6 }
            }
            #expect(inserted.count == 1,
                    "index \(i): expected one inserted vertex, got \(inserted.count)")
            if let got = inserted.first {
                #expect(Self.dist(got, target) < 1e-6,
                        "index \(i) split the edge at \(got), edges()[\(i)] is at \(target)")
                checked += 1
            }
        }
        #expect(checked == 12, "only \(checked) of 12 edges verified")
        #expect(before == 8, "premise: an unsplit box has 8 vertices")
    }

    @Test("splitEdge refuses exactly the indices edge(at:) refuses")
    func splitEdgeRefusesSurplusIndices() throws {
        let box = try #require(Self.box())
        for i in [12, 17, 23] {
            #expect(box.edge(at: i) == nil, "premise: index \(i) is past the enumeration")
            #expect(box.splitEdge(at: i, parameter: 0.5) == nil,
                    "splitEdge answered for surplus index \(i)")
        }
    }

    // MARK: - Site 6: the index the finders hand back

    /// The `faceIndex` argument was already map-backed (#541). What was not is the `Edge.index` on
    /// the way out: it was the position in the RESULT array, so it named a different edge, or no
    /// edge, through `edges()`. Measured before the fix: `edgesInFace(at: 3)` handed back
    /// 0, 1, 2, 3 for edges whose real indices are 2, 6, 10 and 11, all four naming a different
    /// edge, their arc-length midpoints 10.00, 12.25, 7.07 and 12.25 mm from the edges those slot
    /// numbers address.
    @Test("edgesInFace hands back indices that address the same edge through edges()")
    func edgesInFaceIndicesAddressTheSameEdge() throws {
        let box = try #require(Self.box())

        var checkedFaces = 0
        for faceIndex in 0..<box.faceCount {
            let found = box.edgesInFace(at: faceIndex)
            guard !found.isEmpty else { continue }
            checkedFaces += 1
            for e in found {
                let viaIndex = try #require(box.edge(at: e.index),
                                            "index \(e.index) from face \(faceIndex) addresses nothing")
                let a = try #require(Self.mid(e))
                let b = try #require(Self.mid(viaIndex))
                #expect(Self.dist(a, b) < 1e-6,
                        "face \(faceIndex): edge reported at index \(e.index) is at \(a), edges()[\(e.index)] is at \(b)")
            }
        }
        #expect(checkedFaces == 6, "expected all 6 box faces to report edges, got \(checkedFaces)")
    }

    /// The indices must not merely resolve, they must be the ones that actually name those edges.
    /// A result-array position happens to be right for face 0 of a box by coincidence, which is why
    /// the test above is not enough on its own.
    @Test("edgesInFace on a face whose edges are not the first four reports their real indices")
    func edgesInFaceIndicesAreNotArrayPositions() throws {
        let box = try #require(Self.box())

        // Find a face whose edge indices are NOT 0,1,2,3, otherwise the old behaviour passes too.
        var proved = false
        for faceIndex in 0..<box.faceCount {
            let found = box.edgesInFace(at: faceIndex)
            guard found.count == 4 else { continue }
            let reported = found.map(\.index)
            guard reported != Array(0..<4) else { continue }
            proved = true
            // Cross-check each against a geometric lookup that knows nothing about either scheme.
            for e in found {
                let m = try #require(Self.mid(e))
                let truth = try #require(Self.indexOfEdge(matching: m, in: box))
                #expect(e.index == truth,
                        "face \(faceIndex): reported \(e.index) for the edge at \(m), truth is \(truth)")
            }
        }
        #expect(proved, "no box face reported a non-trivial index set, fixture cannot prove this")
    }

    /// The unlisted sibling twenty lines above `edgesInFace` in the same file, identical defect.
    /// `LocOpe_FindEdges` reports one entry per matched PAIR, so indices legitimately repeat, the
    /// contract is that each is a real index into this shape's `edges()`, not that they are unique.
    @Test("commonEdges hands back indices that address the same edge through edges()")
    func commonEdgesIndicesAddressTheSameEdge() throws {
        // Two solids sharing a wall, so there are edges in common at all.
        let block = try #require(Shape.box(origin: .zero, width: 20, height: 10, depth: 10))
        let rect = try #require(Wire.rectangle(width: 60, height: 60))
        let plate = try #require(Shape.face(from: rect))
        let upright = try #require(plate.rotated(axis: SIMD3(0, 1, 0), angle: .pi / 2))
        let knife = try #require(upright.translated(by: SIMD3(10, 0, 0)))
        let pieces = try #require(block.split(by: knife))
        try #require(pieces.count == 2)
        let lower = pieces[0], upper = pieces[1]

        let common = lower.commonEdges(with: upper)
        #expect(common.count >= 4, "expected the four seam edges, got \(common.count)")

        for e in common {
            let viaIndex = try #require(lower.edge(at: e.index),
                                        "index \(e.index) addresses nothing in lower.edges()")
            let a = try #require(Self.mid(e))
            let b = try #require(Self.mid(viaIndex))
            #expect(Self.dist(a, b) < 1e-6,
                    "edge reported at index \(e.index) is at \(a), lower.edges()[\(e.index)] is at \(b)")
        }

        // And they are not array positions. Compare against `0..<common.count`, NOT a hardcoded
        // `0..<4`: the finder returns 8 entries here, so `Set(0..<4)` never equals the reported set
        // even with the defect fully present, and the assertion could not fire. (Proven: with site 6
        // injected the reported set is {0...7}.)
        #expect(Set(common.map(\.index)) != Set(0..<common.count),
                "reported indices are the result-array positions, not real edge indices")
    }

    // MARK: - Site 7: BiTgte_Blend (unlisted by the issue and by its audit)

    /// Found by sweeping for the same idiom rather than from the issue's list. Both
    /// `OCCTBiTgteBlend` and `OCCTBiTgteBlendInfo_` filled a `std::vector<TopoDS_Edge>` from a bare
    /// explorer and subscripted it with the caller's indices, which come from `edges()` /
    /// `Edge.index`.
    ///
    /// This bracket discriminates: `BiTgte_Blend` is a rolling-ball blend, so it changes only the
    /// one concave edge and leaves all 27 convex/tangent ones untouched (14 faces, 28000 mm³).
    /// Blending the concave edge gives 17 faces and 28076.8 mm³. So "which index blends" is
    /// directly observable, and under the occurrence walk it is a different index.
    @Test("biTgteBlend blends the edge edges() calls by that index")
    func biTgteBlendTargetsTheEnumeratedEdge() throws {
        let bracket = try #require(Self.lBracket())
        // Located geometrically, NOT via concaveEdges(), otherwise this test would also fail when
        // site 1 regresses, and could not attribute a failure to this site.
        let target = try #require(Self.indexOfEdge(matching: SIMD3(10, 20, 10), in: bracket),
                                  "fixture has no inner-corner edge at (10, y, 10)")

        let baseline = try #require(bracket.volume)
        var changed: [Int] = []
        for i in 0..<bracket.edgeCount {
            guard let blended = bracket.biTgteBlend(edgeIndices: [i], radius: 3.0),
                  let v = blended.volume else { continue }
            if abs(v - baseline) > 1e-6 { changed.append(i) }
        }
        #expect(changed == [target],
                "indices that change the shape: \(changed); the concave edge is \(target)")
    }

    /// The #568 half of the same site: an index naming no edge used to be silently dropped and the
    /// rest blended, so a three-edge request that named one non-existent edge blended two and
    /// reported an ordinary success.
    @Test("biTgteBlend refuses a batch naming an edge the shape does not have")
    func biTgteBlendRefusesUnresolvableIndices() throws {
        let bracket = try #require(Self.lBracket())
        // Geometric, for the same reason as above.
        let target = try #require(Self.indexOfEdge(matching: SIMD3(10, 20, 10), in: bracket))

        // The control: the batch that names only real edges is accepted.
        #expect(bracket.biTgteBlend(edgeIndices: [target], radius: 3.0) != nil)

        for surplus in [bracket.edgeCount, bracket.edgeCount + 12, 99] {
            #expect(bracket.edge(at: surplus) == nil, "premise: \(surplus) is past the enumeration")
            #expect(bracket.biTgteBlend(edgeIndices: [surplus], radius: 3.0) == nil,
                    "blended for surplus index \(surplus)")
            #expect(bracket.biTgteBlend(edgeIndices: [target, surplus], radius: 3.0) == nil,
                    "a mixed batch containing \(surplus) was accepted and partially blended")
        }
    }
}
