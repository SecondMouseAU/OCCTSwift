// #761 census: does AAG's hand-rolled pairwise face/edge adjacency
// (`OCCTFacesAreAdjacent`/`OCCTFaceGetSharedEdges`/`OCCTEdgeGetConvexity`, all
// `OCCTBridge_BRepGraph.mm`) answer the same question as `BRepGraph`'s own
// `adjacentFaces(of:)`/`sharedEdges(between:and:)`, built over a `BRepGraph_Tool`-backed graph?
//
// Method: build both an `AAG` and a `BRepGraph` from the same `Shape`, map each AAG face
// OCCURRENCE (`Shape.orientedFaces()`-indexed, #642) onto its `BRepGraph` face node via
// `BRepGraph.findNode(for:)`, then compare what each side reports for every occurrence pair.
// `findNode` is a `TopTools_ShapeMapHasher`-keyed lookup (`IsSame`: same TShape + Location,
// orientation ignored -- confirmed by reading `BRepGraphInc_Storage.hxx:1886` and
// `TopTools_ShapeMapHasher.hxx`), the SAME collapse rule `Shape.faces()` uses and #642 moved AAG
// away from for exactly this reason. So the headline structural fact this census exists to
// measure, not assume, is: does that collapse actually change an answer, or is it merely a
// different index space wrapping the same underlying fact?

import Foundation
import OCCTSwift
import simd

enum Issue761 {
    // MARK: - Fixtures private to this census

    /// Three solids, far enough apart that none of their faces touch. No shared face anywhere,
    /// so this is the control case: AAG occurrence indices and BRepGraph's dedup indices must be
    /// a straight bijection here if the two questions are ever the same question.
    static func threeDisjointBoxesCompound() -> Shape? {
        let boxes = (0..<3).compactMap {
            Shape.box(origin: SIMD3(Double($0) * 20, 0, 0), width: 10, height: 10, depth: 10)
        }
        guard boxes.count == 3 else { return nil }
        return Shape.compound(boxes)
    }

    /// A single 100mm box with 11 small notches cut across the top/front edge, so the remaining
    /// top face and front face share more than 10 separate boundary-edge segments -- the fixture
    /// #753's own doc comment predicted ("plausible after healing splits a boundary into
    /// segments") but never measured. Each notch is a small box straddling both the z=50 (top)
    /// and y=-50 (front) planes near x=x0, removing a bite from both faces and splitting their
    /// shared edge at that point.
    static func manySharedEdgesFixture() -> Shape? {
        guard var shape = Shape.box(width: 100, height: 100, depth: 100) else { return nil }
        let positions = stride(from: -45.0, through: 45.0, by: 9.0)
        for x0 in positions {
            guard let notch = Shape.box(origin: SIMD3(x0 - 3, -52, 48), width: 6, height: 4, depth: 4),
                  let cut = shape.subtracting(notch) else { return nil }
            shape = cut
        }
        return shape
    }

    /// A plate with a grid of through-holes -- the same shape of fixture #703's own performance
    /// measurement used (a 300x300x20mm plate, 256 holes), scaled down here to keep this census
    /// fast to run repeatedly. Big enough to separate an O(n) from an O(n^2) cost, small enough
    /// to build in well under a second.
    static func holedPlate(gridSize: Int) -> Shape? {
        guard let plate = Shape.box(origin: SIMD3(-75, -75, -10), width: 150, height: 150, depth: 20) else {
            return nil
        }
        var result = plate
        let spacing = 150.0 / Double(gridSize + 1)
        for ix in 1...gridSize {
            for iy in 1...gridSize {
                let x = -75 + Double(ix) * spacing
                let y = -75 + Double(iy) * spacing
                guard let hole = Shape.cylinder(at: SIMD3(x, y, -15), direction: SIMD3(0, 0, 1), radius: spacing * 0.2, height: 40),
                      let cut = result.subtracting(hole) else { continue }
                result = cut
            }
        }
        return result
    }

    // MARK: - Occurrence -> BRepGraph node mapping

    struct GraphMap {
        let graph: BRepGraph
        /// AAG occurrence index -> BRepGraph face-node index, or -1 if `findNode` missed.
        let nodeOf: [Int]
    }

    static func buildGraphMap(shape: Shape, occurrences: [Face]) -> GraphMap? {
        guard let graph = BRepGraph(shape: shape) else { return nil }
        var nodeOf = [Int](repeating: -1, count: occurrences.count)
        for (i, face) in occurrences.enumerated() {
            guard let faceShape = Shape.fromFace(face) else { continue }
            if let node = graph.findNode(for: faceShape), node.kind == .face {
                nodeOf[i] = node.index
            }
        }
        return GraphMap(graph: graph, nodeOf: nodeOf)
    }

    /// Mirrors `AAG.solidGroups(occurrenceCount:in:)` (private in `FeatureRecognition.swift`) so
    /// this census can classify pairs the same way `AAG.buildGraph()` does, without reaching into
    /// AAG's private state. Same derivation, re-measured here rather than assumed to still match:
    /// `Shape.solids`/`orientedFaces()` are both public, so nothing here needed a fork.
    static func solidGroups(occurrenceCount: Int, in shape: Shape) -> [Int]? {
        let bodies = shape.solids
        guard bodies.count > 1 else { return nil }
        let counts = bodies.map { $0.orientedFaces().count }
        guard counts.reduce(0, +) == occurrenceCount else { return nil }
        var groups = [Int](repeating: -1, count: occurrenceCount)
        var cursor = 0
        for (bodyIndex, count) in counts.enumerated() {
            for k in 0..<count { groups[cursor + k] = bodyIndex }
            cursor += count
        }
        return groups
    }

    // MARK: - Part 1: node/index-space comparison

    static func runNodeCountComparison() {
        print("--- Part 1: node counts (occurrence vs dedup) ---")
        print("fixture                     (columns: occurrences / distinct / BRepGraph.faceCount / BRepGraph.activeFaceCount)")
        let fixtures: [(String, Shape?)] = [
            ("plain box", SharedFixture.plainBox()),
            ("vertical split, order A", SharedFixture.splitBoxCompound(order: .asSplit)),
            ("vertical split, order B", SharedFixture.splitBoxCompound(order: .reversed)),
            ("horizontal split, order A", SharedFixture.horizontalSplitBoxCompound(order: .asSplit)),
            ("horizontal split, order B", SharedFixture.horizontalSplitBoxCompound(order: .reversed)),
            ("three disjoint boxes", threeDisjointBoxesCompound()),
        ]
        for (name, shapeOpt) in fixtures {
            guard let shape = shapeOpt else { print("\(name): FIXTURE FAILED"); continue }
            let occ = shape.orientedFaces()
            let distinct = Set(occ.map(\.index)).count
            let graph = BRepGraph(shape: shape)
            let brgFace = graph?.faceCount ?? -1
            let brgActive = graph?.activeFaceCount ?? -1
            print(row(name, occ.count, distinct, brgFace, brgActive))
        }
        print("")
    }

    private static func row(_ name: String, _ a: Int, _ b: Int, _ c: Int, _ d: Int) -> String {
        let paddedName = name.count >= 28 ? name : name + String(repeating: " ", count: 28 - name.count)
        func pad(_ v: Int) -> String {
            let s = String(v)
            return s.count >= 10 ? s : String(repeating: " ", count: 10 - s.count) + s
        }
        return "\(paddedName)\(pad(a))\(pad(b))\(pad(c))\(pad(d))"
    }

    // MARK: - Part 2: pairwise adjacency / sharedEdges agreement

    struct PairwiseResult {
        var sameSolidPairsCompared = 0
        var sameSolidAdjacencyDisagreements = 0
        var sameSolidCountDisagreements = 0
        var sameSolidCountDisagreementsCappedByTen = 0
        var crossSolidPairsTopologicallyReal = 0
        var crossSolidPairsTotal = 0
        var sharedFaceOccurrencePairs = 0
        var sharedFaceOccurrencePairsCollapseToSameNode = 0
    }

    static func runPairwiseComparison(name: String, shape: Shape) -> PairwiseResult {
        var result = PairwiseResult()
        let aag = shape.buildAAG()
        let occ = shape.orientedFaces()
        guard let map = buildGraphMap(shape: shape, occurrences: occ) else {
            print("\(name): could not build BRepGraph map")
            return result
        }
        let groups = solidGroups(occurrenceCount: occ.count, in: shape)

        for i in 0..<occ.count {
            for j in (i + 1)..<occ.count {
                if occ[i].index == occ[j].index {
                    // The two sides of one shared face. AAG never compares this pair (identity
                    // guard). Report separately whether BRepGraph's node model collapses them.
                    result.sharedFaceOccurrencePairs += 1
                    if map.nodeOf[i] >= 0, map.nodeOf[i] == map.nodeOf[j] {
                        result.sharedFaceOccurrencePairsCollapseToSameNode += 1
                    }
                    continue
                }
                guard map.nodeOf[i] >= 0, map.nodeOf[j] >= 0 else { continue }

                let sameSolid = groups == nil || groups![i] == groups![j]
                let aagEdge = aag.edge(between: i, and: j)
                let aagAdjacent = aagEdge != nil
                let graphShared = map.graph.sharedEdges(between: map.nodeOf[i], and: map.nodeOf[j])
                let graphAdjacent = !graphShared.isEmpty

                if sameSolid {
                    result.sameSolidPairsCompared += 1
                    if aagAdjacent != graphAdjacent {
                        result.sameSolidAdjacencyDisagreements += 1
                    } else if aagAdjacent, let e = aagEdge, e.sharedEdgeCount != graphShared.count {
                        result.sameSolidCountDisagreements += 1
                        if e.sharedEdgeCount == 10, graphShared.count > 10 {
                            result.sameSolidCountDisagreementsCappedByTen += 1
                        }
                    }
                } else {
                    result.crossSolidPairsTotal += 1
                    if graphAdjacent {
                        result.crossSolidPairsTopologicallyReal += 1
                        // AAG's own contract (#699): a cross-solid pair is never adjacent in
                        // buildGraph()'s output, full stop, regardless of what raw topology says.
                        if aagAdjacent {
                            print("  UNEXPECTED: AAG reports pair (\(i),\(j)) adjacent across solids")
                        }
                    }
                }
            }
        }

        print("\(name):")
        print("  same-solid pairs compared:                    \(result.sameSolidPairsCompared)")
        print("  same-solid adjacency disagreements:            \(result.sameSolidAdjacencyDisagreements)")
        print("  same-solid sharedEdgeCount disagreements:      \(result.sameSolidCountDisagreements)"
              + " (of which capped-at-10: \(result.sameSolidCountDisagreementsCappedByTen))")
        print("  cross-solid pairs total:                       \(result.crossSolidPairsTotal)")
        print("  cross-solid pairs BRepGraph calls real, AAG doesn't:  \(result.crossSolidPairsTopologicallyReal)")
        print("  shared-face occurrence pairs (both sides of one wall): \(result.sharedFaceOccurrencePairs)")
        print("  ...of which BRepGraph collapses to ONE node:   \(result.sharedFaceOccurrencePairsCollapseToSameNode)")
        return result
    }

    // MARK: - Part 3: the shared wall's compound-wide neighbor set (BRepGraph, unfiltered)

    static func runWallNeighborDemo(shape: Shape) {
        let occ = shape.orientedFaces()
        guard let map = buildGraphMap(shape: shape, occurrences: occ) else { return }
        let byDistinct = Dictionary(grouping: Array(occ.enumerated()), by: { $0.element.index })
        guard let wallGroup = byDistinct.first(where: { $0.value.count > 1 })?.value, wallGroup.count == 2 else {
            print("  (no shared wall found in this fixture)")
            return
        }
        let (i0, _) = wallGroup[0]
        let wallNode = map.nodeOf[i0]
        guard wallNode >= 0 else { print("  (wall face not found in BRepGraph)"); return }
        let neighbors = map.graph.adjacentFaces(of: wallNode)
        let groups = solidGroups(occurrenceCount: occ.count, in: shape)
        // Translate each BRepGraph neighbor index back to a representative occurrence, to report
        // which solid group it belongs to.
        var neighborGroups: [Int] = []
        for n in neighbors {
            if let occIdx = map.nodeOf.firstIndex(of: n), let g = groups {
                neighborGroups.append(g[occIdx])
            }
        }
        print("  BRepGraph.adjacentFaces(of: wallNode=\(wallNode)) = \(neighbors.count) faces, "
              + "spanning solid groups \(Set(neighborGroups).sorted())")
        print("  (AAG's own adjacency for EITHER wall occurrence only ever spans ONE group, by #699 construction)")
    }

    // MARK: - Part 4: the 10-cap

    static func runTenCapMeasurement() {
        print("--- Part 4: the 10-edge cap ---")
        guard let shape = manySharedEdgesFixture() else {
            print("  could not build the many-shared-edges fixture")
            return
        }
        let occ = shape.orientedFaces()
        print("  fixture face occurrences: \(occ.count)")
        // Identify the (largest) top face (z high, upward, horizontal) and front face (y low,
        // vertical, normal ~ -Y) by measurement, not by a hardcoded index -- the notch cuts add
        // several small new faces whose index position isn't predictable.
        let aag = shape.buildAAG()
        guard let topIdx = aag.nodes.indices.max(by: { a, b in
            let na = aag.nodes[a], nb = aag.nodes[b]
            let aScore = (na.isUpward && na.isHorizontal) ? area(occ[a]) : -1
            let bScore = (nb.isUpward && nb.isHorizontal) ? area(occ[b]) : -1
            return aScore < bScore
        }) else { print("  could not find a top face"); return }
        guard let frontIdx = aag.nodes.indices.max(by: { a, b in
            let na = aag.nodes[a], nb = aag.nodes[b]
            let aScore = (na.isVertical && (na.normal?.y ?? 0) < -0.9) ? area(occ[a]) : -1
            let bScore = (nb.isVertical && (nb.normal?.y ?? 0) < -0.9) ? area(occ[b]) : -1
            return aScore < bScore
        }) else { print("  could not find a front face"); return }

        print("  top face occurrence index \(topIdx), area \(area(occ[topIdx]))")
        print("  front face occurrence index \(frontIdx), area \(area(occ[frontIdx]))")

        let aagEdge = aag.edge(between: topIdx, and: frontIdx)
        print("  AAG.edge(between:).sharedEdgeCount = \(aagEdge?.sharedEdgeCount as Any)")

        guard let map = buildGraphMap(shape: shape, occurrences: occ),
              map.nodeOf[topIdx] >= 0, map.nodeOf[frontIdx] >= 0 else {
            print("  could not map top/front faces into BRepGraph")
            return
        }
        let graphShared = map.graph.sharedEdges(between: map.nodeOf[topIdx], and: map.nodeOf[frontIdx])
        print("  BRepGraph.sharedEdges(between:and:).count = \(graphShared.count)")
        if let e = aagEdge {
            if graphShared.count > e.sharedEdgeCount {
                print("  DEFECT PRESENT: AAG undercounts by \(graphShared.count - e.sharedEdgeCount) edge(s) (10-cap)")
            } else if e.sharedEdgeCount == graphShared.count, graphShared.count > 10 {
                print("  FIXED: AAG's sharedEdgeCount (\(e.sharedEdgeCount)) now agrees with BRepGraph"
                      + " past the old 10-cap threshold")
            } else {
                print("  fixture did not exceed 10 shared edges as built; see README for what was tried")
            }
        }
        print("")
    }

    private static func area(_ face: Face) -> Double { face.area() }

    // MARK: - Part 5: the enclosure test (#735/#753) vs BRepGraph's outerWire/faces(of:)

    static func runEnclosureComparison() {
        print("--- Part 5: PocketFeature.isOpen's enclosure test vs BRepGraph ---")
        guard let cylBox = Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20),
              let tool = Shape.cylinder(at: .zero, direction: SIMD3(0, 0, 1), radius: 4, height: 20),
              let cylCut = cylBox.subtracting(tool) else {
            print("  could not build the blind cylindrical-pocket fixture")
            return
        }
        runEnclosureCheck(name: "blind cylindrical pocket (1 floor edge)", shape: cylCut)

        guard let rectBox = Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20),
              let rectTool = Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15),
              let rectCut = rectBox.subtracting(rectTool) else {
            print("  could not build the rectangular-pocket fixture")
            return
        }
        runEnclosureCheck(name: "blind rectangular pocket (4 floor edges)", shape: rectCut)
        print("")
    }

    private static func runEnclosureCheck(name: String, shape: Shape) {
        print("  \(name):")
        let pockets = shape.detectPocketsAAG()
        guard let pocket = pockets.first else { print("    no pocket detected"); return }
        let occ = shape.orientedFaces()
        let floor = occ[pocket.floorFaceIndex]
        guard let outer = floor.outerWire else { print("    floor has no outer wire"); return }
        let floorEdges = outer.edges()
        print("    floor's own outer wire edge count (Face.outerWire?.edges().count): \(floorEdges.count)")

        guard let map = buildGraphMap(shape: shape, occurrences: occ), map.nodeOf[pocket.floorFaceIndex] >= 0 else {
            print("    could not map floor face into BRepGraph")
            return
        }
        let floorNode = map.nodeOf[pocket.floorFaceIndex]
        let wireNode = map.graph.outerWire(of: floorNode)
        guard wireNode >= 0 else { print("    BRepGraph reports no outer wire for the floor"); return }
        let coedgeCount = map.graph.wireCoEdgeCount(wireNode)
        print("    BRepGraph.outerWire(of:) -> wireCoEdgeCount: \(coedgeCount)")
        print("    agreement: \(floorEdges.count == coedgeCount ? "YES" : "NO, \(floorEdges.count) vs \(coedgeCount)")")

        // Per-edge: does Edge.adjacentFaces(in:) (the hand-rolled half of #753's fix) agree with
        // BRepGraph.faces(of:) once each edge is mapped across? Every floor boundary edge should
        // border exactly the floor and one wall -- a genuine 2-manifold edge in a single solid, so
        // this is the regime where the two ought to already agree (no cross-solid identity to
        // collapse: this fixture has one solid).
        var agree = 0
        var disagree = 0
        for edge in floorEdges {
            guard let (f1, f2) = edge.adjacentFaces(in: shape) else { continue }
            // Find this edge's BRepGraph node the same way faces were mapped, via findNode on a
            // Shape wrapping the edge.
            guard let wrapped = Shape.fromEdge(edge) else { continue }
            guard let node = map.graph.findNode(for: wrapped), node.kind == .edge else { continue }
            let brgFaces = map.graph.faces(of: node.index)
            let handRolledCount = f2 == nil ? 1 : 2
            if brgFaces.count == handRolledCount {
                agree += 1
            } else {
                disagree += 1
            }
            _ = f1
        }
        print("    per-edge face-count agreement: \(agree) agree, \(disagree) disagree (of \(floorEdges.count) edges)")

        // Cost: Edge.adjacentFaces(in:) (OCCTEdgeGetAdjacentFaces) rebuilds a whole-shape
        // TopExp::MapShapesAndAncestors edge->face map FROM SCRATCH on every call
        // (OCCTBridge_BRepGraph.mm); BRepGraph's own edge->face incidence is a real indexed
        // structure populated once at construction (unlike its face-to-face helpers -- see the
        // AAG doc comment). Measured per-call cost, not assumed, since the two are NOT
        // interchangeable performance-wise even where they agree on the answer.
        let handRolledTimes = (0..<3).map { _ -> Double in
            let start = Date()
            for edge in floorEdges { _ = edge.adjacentFaces(in: shape) }
            return Date().timeIntervalSince(start) * 1_000_000 / Double(floorEdges.count)
        }
        let graphTimes = (0..<3).map { _ -> Double in
            let start = Date()
            for edge in floorEdges {
                guard let wrapped = Shape.fromEdge(edge), let node = map.graph.findNode(for: wrapped) else { continue }
                _ = map.graph.faces(of: node.index)
            }
            return Date().timeIntervalSince(start) * 1_000_000 / Double(floorEdges.count)
        }
        print("    per-edge cost, Edge.adjacentFaces(in:):        "
              + "\(handRolledTimes.map { String(format: "%.1f", $0) }.joined(separator: " / ")) us/edge")
        print("    per-edge cost, BRepGraph.faces(of:) (mapped):  "
              + "\(graphTimes.map { String(format: "%.1f", $0) }.joined(separator: " / ")) us/edge")
    }

    // MARK: - Part 6: performance

    static func runPerformanceMeasurement() {
        print("--- Part 6: performance ---")
        for gridSize in [4, 8] {
            guard let plate = holedPlate(gridSize: gridSize) else {
                print("  gridSize \(gridSize): fixture build failed")
                continue
            }
            let faceCount = plate.orientedFaces().count
            let aagTimes = (0..<3).map { _ -> Double in
                let start = Date()
                _ = plate.buildAAG()
                return Date().timeIntervalSince(start) * 1000
            }
            let graphTimes = (0..<3).map { _ -> Double in
                let start = Date()
                _ = BRepGraph(shape: plate)
                return Date().timeIntervalSince(start) * 1000
            }
            let bothTimes = (0..<3).map { _ -> Double in
                let start = Date()
                let occ = plate.orientedFaces()
                _ = plate.buildAAG()
                _ = buildGraphMap(shape: plate, occurrences: occ)
                return Date().timeIntervalSince(start) * 1000
            }
            print("  grid \(gridSize)x\(gridSize) (\(faceCount) face occurrences):")
            print("    AAG.buildGraph() alone:              \(aagTimes.map { String(format: "%.1f", $0) }.joined(separator: " / ")) ms")
            print("    BRepGraph(shape:) alone:              \(graphTimes.map { String(format: "%.1f", $0) }.joined(separator: " / ")) ms")
            print("    AAG.buildGraph() + BRepGraph + map:   \(bothTimes.map { String(format: "%.1f", $0) }.joined(separator: " / ")) ms")
        }
        print("")
    }

    // MARK: - Part 7: the naive consolidation's own cost
    //
    // `AAG.buildGraph()`'s inner pairwise check (`OCCTFacesAreAdjacent`/`OCCTFaceGetSharedEdges`)
    // is O(e1 * e2) per pair -- each face's OWN edge set, typically 4-6 edges, compared directly,
    // no reference to the rest of the shape. `BRepGraph.sharedEdges(between:and:)` is O(E) per
    // call: `bgSharedEdges` (`OCCTBridge_BRepGraph.mm`) scans EVERY edge in the whole graph, not
    // just the two faces' own. Swapping the inner call naively, keeping the same O(n^2) outer
    // pair loop, changes the total cost from O(n^2 * small-constant) to O(n^2 * E) -- and E grows
    // with n for a bounded-degree face graph (E ~ O(n)), so this is a real complexity regression,
    // not just a constant-factor one. Measured directly rather than assumed.
    static func runNaiveConsolidationCost() {
        print("--- Part 7: cost of a naive per-pair BRepGraph.sharedEdges swap ---")
        for gridSize in [4, 8] {
            guard let plate = holedPlate(gridSize: gridSize) else {
                print("  gridSize \(gridSize): fixture build failed")
                continue
            }
            let occ = plate.orientedFaces()
            guard let map = buildGraphMap(shape: plate, occurrences: occ) else {
                print("  gridSize \(gridSize): could not build graph map")
                continue
            }
            let n = occ.count

            // The direct approach's own cost is Part 6's "AAG.buildGraph() alone" row for this
            // same fixture: `Face.handle`/`Shape.handle` are `internal` to OCCTSwift, so this
            // census (a separate module) cannot call `OCCTFacesAreAdjacent` itself the way
            // `AAG.buildGraph()` does -- `AAG.buildGraph()` already IS that timing.
            let directTimes = (0..<3).map { _ -> Double in
                let start = Date()
                _ = plate.buildAAG()
                return Date().timeIntervalSince(start) * 1000
            }

            let viaGraphTimes = (0..<3).map { _ -> Double in
                let start = Date()
                var found = 0
                for i in 0..<n {
                    for j in (i + 1)..<n {
                        guard map.nodeOf[i] >= 0, map.nodeOf[j] >= 0, map.nodeOf[i] != map.nodeOf[j] else { continue }
                        if !map.graph.sharedEdges(between: map.nodeOf[i], and: map.nodeOf[j]).isEmpty { found += 1 }
                    }
                }
                _ = found
                return Date().timeIntervalSince(start) * 1000
            }

            print("  grid \(gridSize)x\(gridSize) (\(n) occurrences, \(n * (n - 1) / 2) pairs, \(map.graph.edgeCount) graph edges):")
            print("    AAG.buildGraph() today (direct bridge calls): \(directTimes.map { String(format: "%.1f", $0) }.joined(separator: " / ")) ms")
            print("    via BRepGraph.sharedEdges, all pairs:          \(viaGraphTimes.map { String(format: "%.1f", $0) }.joined(separator: " / ")) ms")
        }
        print("")
    }

    // MARK: - Part 8: the fix actually worth making -- BRepGraph only for CONFIRMED-adjacent pairs
    //
    // The O(n^2) adjacency TEST stays on the cheap direct bridge call (`OCCTFacesAreAdjacent`,
    // O(e1*e2) per pair, unaffected by this). Only once a pair is already known adjacent -- an
    // O(n)-sized subset for a bounded-degree face graph, not O(n^2) -- does it pay BRepGraph's
    // O(E) `sharedEdges` cost, to get the TRUE count instead of the capped-at-10 one. This
    // measures whether that hybrid's added cost is small enough to be worth it.
    static func runHybridFixCost() {
        print("--- Part 8: cost of fixing the cap ONLY for already-adjacent pairs ---")
        for gridSize in [4, 8] {
            guard let plate = holedPlate(gridSize: gridSize) else {
                print("  gridSize \(gridSize): fixture build failed")
                continue
            }
            let occ = plate.orientedFaces()
            let aag = plate.buildAAG()
            guard let map = buildGraphMap(shape: plate, occurrences: occ) else {
                print("  gridSize \(gridSize): could not build graph map")
                continue
            }
            let n = occ.count
            var adjacentPairs: [(Int, Int)] = []
            for i in 0..<n {
                for j in (i + 1)..<n where aag.edge(between: i, and: j) != nil {
                    adjacentPairs.append((i, j))
                }
            }
            let extraTimes = (0..<3).map { _ -> Double in
                let start = Date()
                for (i, j) in adjacentPairs {
                    guard map.nodeOf[i] >= 0, map.nodeOf[j] >= 0, map.nodeOf[i] != map.nodeOf[j] else { continue }
                    _ = map.graph.sharedEdges(between: map.nodeOf[i], and: map.nodeOf[j]).count
                }
                return Date().timeIntervalSince(start) * 1000
            }
            print("  grid \(gridSize)x\(gridSize) (\(n) occurrences, \(adjacentPairs.count) confirmed-adjacent pairs):")
            print("    BRepGraph build + map (one-time, Part 6's own row above)")
            print("    extra: sharedEdges on confirmed-adjacent pairs only: "
                  + "\(extraTimes.map { String(format: "%.2f", $0) }.joined(separator: " / ")) ms")
        }
        print("")
    }

    // MARK: - Entry point

    static func run() {
        runNodeCountComparison()

        print("--- Part 2: pairwise adjacency / sharedEdges agreement ---")
        _ = runPairwiseComparison(name: "plain box", shape: SharedFixture.plainBox())
        _ = runPairwiseComparison(name: "vertical split, order A", shape: SharedFixture.splitBoxCompound(order: .asSplit))
        _ = runPairwiseComparison(name: "horizontal split, order A", shape: SharedFixture.horizontalSplitBoxCompound(order: .asSplit))
        if let three = threeDisjointBoxesCompound() {
            _ = runPairwiseComparison(name: "three disjoint boxes", shape: three)
        }
        print("")

        print("--- Part 3: the shared wall's neighbor set, BRepGraph-unfiltered ---")
        print("vertical split fixture:")
        runWallNeighborDemo(shape: SharedFixture.splitBoxCompound(order: .asSplit))
        print("horizontal split fixture:")
        runWallNeighborDemo(shape: SharedFixture.horizontalSplitBoxCompound(order: .asSplit))
        print("")

        runTenCapMeasurement()
        runEnclosureComparison()
        runPerformanceMeasurement()
        runNaiveConsolidationCost()
        runHybridFixCost()
    }
}
