// #777: `PocketFeature.isOpen`'s enclosure test reaches `Edge.adjacentFaces(in:)` once per
// floor boundary edge, and `OCCTEdgeGetAdjacentFaces` rebuilds a whole-shape
// `TopExp::MapShapesAndAncestors` edge-to-face map from scratch on every call
// (`OCCTBridge_BRepGraph.mm`). #761 measured the per-call gap against `BRepGraph`'s indexed
// incidence at 3x to 8x and left the fix as a follow-up.
//
// This harness answers three separate questions, because #761's per-edge ratio alone decides
// nothing (okf/policies/measure-dont-assume.md: it is a real measurement of a real thing, and it
// is not the quantity a fix has to beat).
//
//   1. Is the gap still there on current `main`? Pass 4a moved `buildGraph()`/`detectHoles()`
//      around it (#943), so the number may have moved.
//   2. What does the whole `detectPocketsAAG()` call cost, and what share of it is the enclosure
//      test? A per-edge saving on a four-edge floor is worth microseconds; the one-time cost of
//      standing up a `BRepGraph` to collect it is measured here rather than left out.
//   3. Do the candidate replacements return the SAME verdict, including where a per-edge test and
//      an indexed one can legitimately disagree: an edge bounding more than two faces, a seam edge
//      on a periodic surface, and a degenerate edge.
//
// Four enclosure predicates are implemented side by side over the public API and run interleaved
// in one process, so a machine-load spike lands on all of them rather than on whichever ran first:
//
//   - `adjacentFacesPredicate`: what `isEdgeCoveredByAWall` did before this issue. Ask the whole
//     shape which faces bound the edge, then test those against the covering set by `IsSame`.
//   - `coveringEdgesPredicate`: the replacement. Ask each covering face for its own edges, then
//     test the floor's boundary edge for membership by `IsSame`. The same predicate, evaluated
//     from the other end, and never touching anything but the covering faces.
//   - `coveringEdgesHashedPredicate`: the same replacement with the covering edges bucketed by
//     `Shape.hashCode` rather than scanned linearly. This is the form that shipped; the linear one
//     is kept alongside it because which of the two wins depends on the fixture.
//   - `brepGraphPredicate`: the route #777 proposed. Build one `BRepGraph` for the shape, map the
//     covering faces onto its nodes, and read `faces(of:)` per floor boundary edge. The graph is
//     built once per shape, not once per pocket, which is what a real implementation inside
//     `detectPockets()` would do and is the arrangement most favourable to it.
//
// Run with: swift run Harnesses 777-pocket-isopen
//
// See Scripts/repro/777-pocket-isopen/README.md for the measured tables and the reasoning from
// them to the change that shipped.

import Foundation
import OCCTSwift

// MARK: - Timing

/// Wall-clock elapsed seconds for `body`, via the monotonic Dispatch clock (`ContinuousClock`
/// needs macOS 13+, above this package's macOS 12 deployment target).
private func measureSeconds(_ body: () -> Void) -> Double {
    let start = DispatchTime.now().uptimeNanoseconds
    body()
    let end = DispatchTime.now().uptimeNanoseconds
    return Double(end - start) / 1_000_000_000
}

/// min / median / max of a timing sample.
///
/// A single number is not evidence on a loaded machine, so every timing row here reports the
/// spread and the run count rather than one figure.
private struct Spread {
    let samples: [Double]

    var minimum: Double { samples.min() ?? 0 }
    var maximum: Double { samples.max() ?? 0 }
    var median: Double {
        guard !samples.isEmpty else { return 0 }
        let sorted = samples.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 1 { return sorted[mid] }
        return (sorted[mid - 1] + sorted[mid]) / 2
    }

    /// Microseconds, as `median (min .. max)`.
    var describedMicroseconds: String {
        String(
            format: "%10.1f us  (%.1f .. %.1f)",
            median * 1_000_000, minimum * 1_000_000, maximum * 1_000_000)
    }
}

// MARK: - Fixtures

private struct Fixture {
    let name: String
    let shape: Shape
}

/// The issue's own two shapes, plus three that scale the two axes the cost depends on: how many
/// edges a floor's outer wire has, and how big the whole shape is (which is what the discarded
/// per-call edge-to-face map gets rebuilt over).
private func timingFixtures() -> [Fixture] {
    var built: [Fixture] = []

    if let box = Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20),
        let tool = Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15),
        let cut = box.subtracting(tool)
    {
        built.append(Fixture(name: "blind rectangular pocket (4 walls, 4 floor edges)", shape: cut))
    }

    if let box = Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20),
        let tool = Shape.cylinder(at: .zero, direction: SIMD3(0, 0, 1), radius: 4, height: 20),
        let cut = box.subtracting(tool)
    {
        built.append(Fixture(name: "blind cylindrical pocket (1 wall, 1 floor edge)", shape: cut))
    }

    for sides in [24, 48] {
        if let many = polygonalPocket(sides: sides) {
            built.append(
                Fixture(
                    name: "\(sides)-sided polygonal pocket (\(sides) walls, \(sides) floor edges)",
                    shape: many))
        }
    }

    if let slotted = openSlottedPlate(slots: 8) {
        built.append(
            Fixture(
                name: "plate with 8 OPEN slots (the short-circuit case, see the README)",
                shape: slotted))
    }

    for grid in [3, 5] {
        if let plate = pocketedPlate(gridSize: grid) {
            let faces = plate.orientedFaces().count
            built.append(
                Fixture(
                    name: "plate, \(grid)x\(grid) grid of pockets (\(faces) face occurrences)",
                    shape: plate))
        }
    }

    return built
}

/// A plate crossed by open-ended slots. Every slot's floor has a boundary edge that borders no
/// wall, which is the case the pre-#777 test could answer without ever building a second map: its
/// `contains { !covered }` short-circuits on the first uncovered edge, while the replacement
/// always indexes the whole covering set first. Every other fixture here is an enclosed pocket, so
/// without this row the comparison would only ever measure the arrangement that favours the
/// replacement.
private func openSlottedPlate(slots: Int) -> Shape? {
    let pitch = 14.0
    let span = pitch * Double(slots)
    guard var plate = Shape.box(origin: .zero, width: span, height: 60, depth: 20) else {
        return nil
    }
    for index in 0..<slots {
        let x = Double(index) * pitch + 4
        // Runs past both y bounds, so the slot floor is open at both ends.
        guard let tool = Shape.box(origin: SIMD3(x, -5, 10), width: 6, height: 70, depth: 15),
            let cut = plate.subtracting(tool)
        else { return nil }
        plate = cut
    }
    return plate
}

/// A regular n-gon pocket sunk into a plate: one wall and one floor boundary edge per side, so the
/// per-edge cost scales with `sides` while the shape itself stays small.
private func polygonalPocket(sides: Int) -> Shape? {
    guard let plate = Shape.box(origin: SIMD3(-20, -20, -10), width: 40, height: 40, depth: 20)
    else { return nil }
    let radius = 12.0
    let points = (0..<sides).map { index -> SIMD3<Double> in
        let angle = 2 * Double.pi * Double(index) / Double(sides)
        return SIMD3(radius * cos(angle), radius * sin(angle), 10)
    }
    guard let profile = Wire.polygon3D(points, closed: true),
        let tool = Shape.extrude(profile: profile, direction: SIMD3(0, 0, -1), length: 6)
    else { return nil }
    return plate.subtracting(tool)
}

/// A plate with a grid of square pockets. Every pocket is its own `detectPockets()` iteration, and
/// the whole shape grows with the grid, which is the axis the discarded per-call map is built over.
private func pocketedPlate(gridSize: Int) -> Shape? {
    let pitch = 20.0
    let span = pitch * Double(gridSize)
    guard var plate = Shape.box(origin: .zero, width: span, height: span, depth: 20) else {
        return nil
    }
    for row in 0..<gridSize {
        for column in 0..<gridSize {
            let x = Double(column) * pitch + pitch / 2 - 5
            let y = Double(row) * pitch + pitch / 2 - 5
            guard let tool = Shape.box(origin: SIMD3(x, y, 10), width: 10, height: 10, depth: 15),
                let cut = plate.subtracting(tool)
            else { return nil }
            plate = cut
        }
    }
    return plate
}

// MARK: - The three enclosure predicates, over the public API

/// Everything one pocket's enclosure test needs, resolved once so the predicates below are timed
/// on the test itself rather than on re-deriving their own inputs.
private struct PocketWork {
    let shape: Shape
    let occurrences: [Face]
    /// `wallFaceIndices` only. Every fixture here is sharp-cornered, so `detectPockets()`'s own
    /// covering set (walls UNION #762's absorbed junction faces) is the same list; a filleted
    /// fixture would need the junction indices too, and those are not public.
    let coveringFaces: [Int]
    let floorBoundaryEdges: [Edge]
}

private func pocketWork(for shape: Shape) -> [PocketWork] {
    let occurrences = shape.orientedFaces()
    return shape.detectPocketsAAG().compactMap { pocket -> PocketWork? in
        guard pocket.floorFaceIndex < occurrences.count,
            let outer = occurrences[pocket.floorFaceIndex].outerWire
        else { return nil }
        return PocketWork(
            shape: shape,
            occurrences: occurrences,
            coveringFaces: pocket.wallFaceIndices,
            floorBoundaryEdges: outer.edges())
    }
}

/// The pre-#777 test: ask the whole shape which faces bound this edge, then match those against
/// the covering set by `IsSame`. Returns true when the pocket is ENCLOSED.
private func adjacentFacesPredicate(_ work: PocketWork) -> Bool {
    work.floorBoundaryEdges.allSatisfy { edge in
        guard let (face1, face2) = edge.adjacentFaces(in: work.shape) else { return false }
        return work.coveringFaces.contains { index in
            let covering = work.occurrences[index]
            return facesAreSame(face1, covering)
                || (face2.map { facesAreSame($0, covering) } ?? false)
        }
    }
}

private func facesAreSame(_ first: Face, _ second: Face) -> Bool {
    guard let a = Shape.fromFace(first), let b = Shape.fromFace(second) else { return false }
    return a.isSame(as: b)
}

/// The replacement: ask each covering face for its own edges, then test the floor's boundary edge
/// for membership by `IsSame`. The covering set is resolved once per pocket, which is where the
/// saving comes from.
private func coveringEdgesPredicate(_ work: PocketWork) -> Bool {
    let coveringEdges = work.coveringFaces.flatMap { index -> [Shape] in
        guard let asShape = Shape.fromFace(work.occurrences[index]) else { return [] }
        return asShape.subShapes(ofType: .edge)
    }
    return work.floorBoundaryEdges.allSatisfy { edge in
        guard let wrapped = Shape.fromEdge(edge) else { return false }
        return coveringEdges.contains { $0.isSame(as: wrapped) }
    }
}

/// The replacement again, with the covering edges bucketed by `Shape.hashCode` instead of scanned
/// linearly. `OCCTShapeHashCode` is `std::hash<TopoDS_Shape>`, which is exactly the hash
/// `TopTools_ShapeMapHasher` pairs with `IsSame` (`TopTools_ShapeMapHasher.hxx`, read rather than
/// assumed), so two `IsSame` shapes always land in the same bucket and a bucket miss is a definite
/// non-match. Measured against the linear form to decide whether the extra structure earns itself.
///
/// **This is a hand copy of `CoveringEdges` (`Sources/OCCTSwift/CoveringEdges.swift`), not a call
/// into it**: the harness links `OCCTSwift` as an ordinary dependency and cannot see an internal
/// type. Keep the two in step. If `CoveringEdges` changes and this does not, the harness goes on
/// reporting a number for something it still calls "the form that shipped", which is the class of
/// drift #761 was filed about in the first place.
private func coveringEdgesHashedPredicate(_ work: PocketWork) -> Bool {
    var buckets: [Int: [Shape]] = [:]
    for index in work.coveringFaces {
        guard let asShape = Shape.fromFace(work.occurrences[index]) else { continue }
        for edge in asShape.subShapes(ofType: .edge) {
            buckets[edge.hashCode, default: []].append(edge)
        }
    }
    return work.floorBoundaryEdges.allSatisfy { edge in
        guard let wrapped = Shape.fromEdge(edge), let bucket = buckets[wrapped.hashCode] else {
            return false
        }
        return bucket.contains { $0.isSame(as: wrapped) }
    }
}

/// #777's own proposal: `BRepGraph`'s indexed edge-to-face incidence, with the graph supplied by
/// the caller so its construction is paid once per shape rather than once per pocket.
private func brepGraphPredicate(_ work: PocketWork, graph: BRepGraph) -> Bool {
    var coveringNodes = Set<Int>()
    for index in work.coveringFaces {
        guard let asShape = Shape.fromFace(work.occurrences[index]),
            let node = graph.findNode(for: asShape), node.kind == .face
        else { continue }
        coveringNodes.insert(node.index)
    }
    return work.floorBoundaryEdges.allSatisfy { edge in
        guard let wrapped = Shape.fromEdge(edge),
            let node = graph.findNode(for: wrapped), node.kind == .edge
        else { return false }
        return graph.faces(of: node.index).contains { coveringNodes.contains($0) }
    }
}

// MARK: - Harness

enum PocketEnclosureTiming {

    private static let runs = 25

    static func run() {
        print("=== #777: PocketFeature.isOpen's enclosure test, measured ===")
        print("")
        let built = timingFixtures()
        describeFixtures(built)
        comparePredicates(built)
        measureDetectPockets(built)
        compareIncidence()
        compareBoundaryVerdicts()
    }

    // MARK: Part 1

    private static func describeFixtures(_ built: [Fixture]) {
        print("--- Part 1: what each fixture presents to the enclosure test ---")
        for fixture in built {
            let work = pocketWork(for: fixture.shape)
            let edges = work.reduce(0) { $0 + $1.floorBoundaryEdges.count }
            let covering = work.reduce(0) { $0 + $1.coveringFaces.count }
            print("  \(fixture.name)")
            print(
                "    pockets \(work.count), floor boundary edges \(edges), "
                    + "covering faces \(covering), shape edges \(fixture.shape.edges().count)")
        }
        print("")
    }

    // MARK: Part 2

    private static func comparePredicates(_ built: [Fixture]) {
        print("--- Part 2: the enclosure test alone, four ways, interleaved, \(runs) runs ---")
        print("    (each row covers the whole shape's pockets, not one pocket)")
        for fixture in built {
            let work = pocketWork(for: fixture.shape)
            guard !work.isEmpty else { continue }

            // Warm up: first touch of a shape's triangulation/caches is not what is under test.
            // All four, not just the first two: the BRepGraph row otherwise pays graph
            // construction cold on its first sample and is then compared against three rows
            // that do not.
            _ = work.map(adjacentFacesPredicate)
            _ = work.map(coveringEdgesPredicate)
            _ = work.map(coveringEdgesHashedPredicate)
            if let warmGraph = BRepGraph(shape: fixture.shape) {
                _ = work.map { brepGraphPredicate($0, graph: warmGraph) }
            }

            var adjacent: [Double] = []
            var covering: [Double] = []
            var hashed: [Double] = []
            var graph: [Double] = []
            for _ in 0..<runs {
                adjacent.append(measureSeconds { work.forEach { _ = adjacentFacesPredicate($0) } })
                covering.append(measureSeconds { work.forEach { _ = coveringEdgesPredicate($0) } })
                hashed.append(
                    measureSeconds { work.forEach { _ = coveringEdgesHashedPredicate($0) } })
                graph.append(
                    measureSeconds {
                        guard let built = BRepGraph(shape: fixture.shape) else { return }
                        work.forEach { _ = brepGraphPredicate($0, graph: built) }
                    })
            }

            let adjacentSpread = Spread(samples: adjacent)
            let coveringSpread = Spread(samples: covering)
            let hashedSpread = Spread(samples: hashed)
            print("  \(fixture.name)")
            print("    adjacentFaces(in:), per edge:   \(adjacentSpread.describedMicroseconds)")
            print("    covering edges, linear scan:    \(coveringSpread.describedMicroseconds)")
            print("    covering edges, hash-bucketed:  \(hashedSpread.describedMicroseconds)")
            print("    BRepGraph, one graph per shape: \(Spread(samples: graph).describedMicroseconds)")
            print(
                String(
                    format:
                        "    speedup over adjacentFaces, linear scan: %.1fx median / %.1fx min",
                    adjacentSpread.median / max(coveringSpread.median, 1e-12),
                    adjacentSpread.minimum / max(coveringSpread.minimum, 1e-12)))
            print(
                String(
                    format:
                        "    speedup over adjacentFaces, hash-bucketed: %.1fx median / %.1fx min",
                    adjacentSpread.median / max(hashedSpread.median, 1e-12),
                    adjacentSpread.minimum / max(hashedSpread.minimum, 1e-12)))
        }
        print("")
    }

    // MARK: Part 3

    private static func measureDetectPockets(_ built: [Fixture]) {
        print("--- Part 3: the whole detectPocketsAAG() call, \(runs) runs ---")
        print("    (Part 2's first row is the share of this that the issue is about)")
        for fixture in built {
            _ = fixture.shape.detectPocketsAAG()
            let samples = (0..<runs).map { _ in
                measureSeconds { _ = fixture.shape.detectPocketsAAG() }
            }
            print("  \(fixture.name)")
            print("    detectPocketsAAG():             \(Spread(samples: samples).describedMicroseconds)")
        }
        print("")
    }

    // MARK: Part 4

    /// Edge-to-face incidence, all three constructions, over EVERY edge of each fixture rather
    /// than only the ones a pocket happens to reach. This is where the constructions can diverge,
    /// and a pocket verdict is a lossy view of it: an index is not a drop-in for a scan just
    /// because both are correct on a box.
    private static func compareIncidence() {
        print("--- Part 4: edge-to-face incidence, every edge, three constructions ---")
        print("    A = the face OCCURRENCES Edge.adjacentFaces(in:)'s <=2 faces match by IsSame")
        print("    B = the face occurrences whose own edge list contains the edge")
        print("    C = BRepGraph.faces(of:), reported as a count only (its own node space)")
        print("    The predicate asks 'is a covering index in this set', so A vs B as SETS is what")
        print("    decides whether the replacement can change a verdict, and in which direction.")
        for fixture in incidenceFixtures() {
            reportIncidence(name: fixture.name, shape: fixture.shape)
        }
        print("")
    }

    private static func incidenceFixtures() -> [Fixture] {
        var built: [Fixture] = []
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            built.append(Fixture(name: "plain box (every edge bounds exactly 2 faces)", shape: box))
        }
        if let cylinder = Shape.cylinder(radius: 5, height: 10) {
            built.append(Fixture(name: "cylinder (seam edge on a periodic surface)", shape: cylinder))
        }
        if let cone = Shape.cone(bottomRadius: 5, topRadius: 0, height: 10) {
            built.append(Fixture(name: "cone (apex is a degenerate, zero-length edge)", shape: cone))
        }
        if let sphere = Shape.sphere(radius: 5) {
            built.append(Fixture(name: "sphere (a seam and two degenerate pole edges)", shape: sphere))
        }
        if let split = horizontalSplitCompound() {
            built.append(
                Fixture(name: "two solids sharing one cut face (edges bound 4 faces)", shape: split))
        }
        return built
    }

    private static func reportIncidence(name: String, shape: Shape) {
        let occurrences = shape.orientedFaces()
        let faceEdges: [[Shape]] = occurrences.map { face in
            guard let asShape = Shape.fromFace(face) else { return [] }
            return asShape.subShapes(ofType: .edge)
        }
        let graph = BRepGraph(shape: shape)

        var histogramA: [Int: Int] = [:]
        var histogramB: [Int: Int] = [:]
        var histogramC: [Int: Int] = [:]
        var strictlySmaller = 0
        var notASubset = 0

        let edges = shape.edges()
        for edge in edges {
            guard let wrapped = Shape.fromEdge(edge) else { continue }
            var setA = Set<Int>()
            if let (face1, face2) = edge.adjacentFaces(in: shape) {
                for (index, occurrence) in occurrences.enumerated() {
                    if facesAreSame(face1, occurrence)
                        || (face2.map { facesAreSame($0, occurrence) } ?? false)
                    {
                        setA.insert(index)
                    }
                }
            }
            var setB = Set<Int>()
            for (index, list) in faceEdges.enumerated()
            where list.contains(where: { $0.isSame(as: wrapped) }) {
                setB.insert(index)
            }
            var countC = -1
            if let graph, let node = graph.findNode(for: wrapped), node.kind == .edge {
                countC = graph.faces(of: node.index).count
            }
            histogramA[setA.count, default: 0] += 1
            histogramB[setB.count, default: 0] += 1
            histogramC[countC, default: 0] += 1
            if setA.isSubset(of: setB) {
                if setA.count < setB.count { strictlySmaller += 1 }
            } else {
                notASubset += 1
            }
        }

        print("  \(name): \(edges.count) distinct edges, \(occurrences.count) face occurrences")
        print("    |A| histogram: \(describe(histogramA))")
        print("    |B| histogram: \(describe(histogramB))")
        print("    |C| histogram: \(describe(histogramC))")
        print(
            "    edges where A is a STRICT subset of B (B sees a face A cannot): \(strictlySmaller); "
                + "edges where A is NOT a subset of B (B loses a face A had): \(notASubset)")
    }

    private static func describe(_ histogram: [Int: Int]) -> String {
        histogram.keys.sorted().map { "\($0) faces x\(histogram[$0] ?? 0)" }.joined(separator: ", ")
    }

    /// Two solids sharing one horizontal cut face, compounded. Every edge of that shared face is
    /// bounded by four faces (each solid's own side face and its own occurrence of the cut face),
    /// which is the case `Edge.adjacentFaces(in:)` structurally cannot report.
    private static func horizontalSplitCompound() -> Shape? {
        guard let block = Shape.box(width: 10, height: 10, depth: 10),
            let pieces = block.split(atPlane: SIMD3(0, 0, 4), normal: SIMD3(0, 0, 1)),
            pieces.count == 2
        else { return nil }
        return Shape.compound(pieces)
    }

    // MARK: Part 5

    /// The pocket verdict itself, on the boundary shapes, so a divergence in Part 4's incidence is
    /// followed through to the answer the public API actually returns.
    private static func compareBoundaryVerdicts() {
        print("--- Part 5: pocket verdicts on the boundary fixtures ---")
        boundaryVerdict(
            name: "seam edge: blind cylindrical pocket, radius 6",
            shape: cylindricalPocket(radius: 6))
        boundaryVerdict(
            name: "degenerate edge: conical pocket, apex on the axis",
            shape: conicalPocket())
        boundaryVerdict(
            name: ">2 faces: a pocketed box split down the middle, compounded",
            shape: splitPocketCompound())
        print("")
    }

    private static func boundaryVerdict(name: String, shape: Shape?) {
        print("  \(name)")
        guard let shape else {
            print("    fixture could not be built")
            return
        }
        let work = pocketWork(for: shape)
        guard !work.isEmpty else {
            print("    no pocket detected, so the enclosure test never runs here")
            return
        }
        let graph = BRepGraph(shape: shape)
        for (index, item) in work.enumerated() {
            let multiFaceEdges = item.floorBoundaryEdges.filter { edge in
                guard let wrapped = Shape.fromEdge(edge) else { return false }
                return shape.adjacentFaces(forEdge: wrapped).count > 2
            }.count
            let a = adjacentFacesPredicate(item)
            let b = coveringEdgesPredicate(item)
            let c = graph.map { brepGraphPredicate(item, graph: $0) }
            print(
                "    pocket \(index): \(item.floorBoundaryEdges.count) floor boundary edges "
                    + "(bounded by >2 faces: \(multiFaceEdges)), "
                    + "\(item.coveringFaces.count) covering faces")
            print(
                "      enclosed? adjacentFaces=\(a) covering-edges=\(b) "
                    + "BRepGraph=\(c.map(String.init(describing:)) ?? "n/a") "
                    + "-> \(a == b ? "AGREE" : "DISAGREE")")
        }
    }

    private static func cylindricalPocket(radius: Double) -> Shape? {
        guard let box = Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20),
            let tool = Shape.cylinder(
                at: .zero, direction: SIMD3(0, 0, 1), radius: radius, height: 20)
        else { return nil }
        return box.subtracting(tool)
    }

    private static func conicalPocket() -> Shape? {
        guard let box = Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20),
            let cone = Shape.cone(
                at: SIMD3(0, 0, 10), direction: SIMD3(0, 0, -1), bottomRadius: 8, topRadius: 0,
                height: 8)
        else { return nil }
        return box.subtracting(cone)
    }

    /// A pocketed box cut in half through the pocket, then compounded. Each half's floor keeps a
    /// boundary edge lying on the cut plane, and that edge is bounded by both halves' cut faces as
    /// well as both halves' floors: four faces on one edge, on a shape that still presents a
    /// pocket to `detectPockets()`.
    private static func splitPocketCompound() -> Shape? {
        guard let box = Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20),
            let tool = Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15),
            let cut = box.subtracting(tool),
            let pieces = cut.split(atPlane: .zero, normal: SIMD3(1, 0, 0)),
            pieces.count == 2
        else { return nil }
        return Shape.compound(pieces)
    }
}
