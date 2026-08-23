import Foundation
import OCCTBridge
import simd

// MARK: - Edge Convexity

/// Classification of the dihedral angle at an edge between two faces.
public enum EdgeConvexity: Int32, Sendable {
    case concave = -1  // Interior angle > 180° (pocket-like, going inward)
    case smooth = 0  // Tangent faces (~180°)
    case convex = 1  // Interior angle < 180° (fillet-like, going outward)

    init(fromOCCT value: OCCTEdgeConvexity) {
        switch value {
        case OCCTEdgeConvexityConcave: self = .concave
        case OCCTEdgeConvexitySmooth: self = .smooth
        case OCCTEdgeConvexityConvex: self = .convex
        default: self = .smooth
        }
    }
}

// MARK: - Attributed Adjacency Graph

/// A node in the Attributed Adjacency Graph representing one B-Rep face **occurrence**.
///
/// AAG builds its node set from ``Shape/orientedFaces()``, not ``Shape/faces()`` (#642): a face
/// shared by two solids in a compound, the ordinary result of a split, appears as **two**.
/// nodes, one per owning solid, each carrying the normal and derived predicates (isHorizontal,.
/// isUpward, isDownward, isVertical, zLevel) that solid's own orientation produces.
///
/// On any.
/// shape whose faces are not shared this is exactly the node set `faces()` would have produced, in.
/// the same order.
public struct AAGNode: Sendable {
    /// This node's position in the graph, the index every AAG method (``AAG/neighbors(of:)``,
    /// ``AAG/edge(between:and:)``, ``AAG/concaveNeighbors(of:)``, ``AAG/convexNeighbors(of:)``)
    /// takes and returns.
    ///
    /// An **occurrence** index into ``Shape/orientedFaces()``, not a distinct.
    /// face index: two nodes can share the same underlying face (see `distinctFaceIndex`).
    public let faceIndex: Int

    /// This occurrence's underlying face, its position in ``Shape/faces()``, the deduplicated.
    /// enumeration.
    ///
    /// Two nodes with the same distinctFaceIndex are the two sides of one shared face (a wall.
    /// between two solids in a compound): same geometry, opposite orientation, opposed normals.
    ///
    /// AAG does not build a graph edge between such a pair: sharing every boundary edge with
    /// itself is not adjacency, it is identity.
    ///
    /// On a shape whose faces are not shared, every node.
    /// has a distinct distinctFaceIndex, equal to its faceIndex.
    public let distinctFaceIndex: Int

    /// Face normal at center (if computable).
    public let normal: SIMD3<Double>?

    /// Whether face is planar.
    public let isPlanar: Bool

    /// Whether face is horizontal (normal points up or down).
    public let isHorizontal: Bool

    /// Whether face is upward-facing.
    public let isUpward: Bool

    /// Whether face is downward-facing.
    public let isDownward: Bool

    /// Whether face is vertical.
    public let isVertical: Bool

    /// Z level if horizontal planar face.
    public let zLevel: Double?

    /// Bounding box of the face's exact geometry (#733).
    ///
    /// Unlike ``Face/bounds``, this is never enlarged by mesh triangulation, so it does not change.
    /// depending on whether the shape has been meshed before `AAG` was built from it.
    public let bounds: (min: SIMD3<Double>, max: SIMD3<Double>)
}

/// An edge in the Attributed Adjacency Graph representing adjacency between two faces.
public struct AAGEdge: Sendable {
    /// Index of first adjacent face.
    public let face1Index: Int

    /// Index of second adjacent face.
    public let face2Index: Int

    /// Convexity classification of the shared edge(s).
    public let convexity: EdgeConvexity

    /// Number of shared edges between the faces.
    public let sharedEdgeCount: Int
}

/// Attributed Adjacency Graph for feature recognition.
///
/// The AAG represents the topology of a shape as a graph where:
/// - Nodes are face **occurrences** (``Shape/orientedFaces()``, #642). A face shared between two.
///   solids in a compound is two nodes, one per owning solid, each with that solid's own normal.
///   and derived predicates.
/// - Edges connect adjacent occurrences (those sharing a B-Rep edge) **within the same solid**.
///   (#699), except the two occurrences of one shared face, which are never linked to each other.
/// - Each graph edge is attributed with convexity information.
///
/// ## Adjacency is scoped to one solid (#699).
///
/// Two occurrences sharing a B-Rep edge but belonging to different solids in a compound are.
/// adjacent *in the compound* and not adjacent in *either* solid: a floor face's candidate walls
/// are the faces bounding the same body, not any face anywhere in the compound that happens to.
/// touch the same edge locus.
///
/// Neither OCCTFaceGetSharedEdgeSummary nor OCCTEdgeGetConvexity has any.
/// notion of solid membership on their own, so `buildGraph()` restricts which occurrence pairs it.
/// hands to them, using `Shape.solids` and `orientedFaces()`'s own traversal order rather than a.
/// new bridge entry point (see `AAG.solidGroups(occurrenceCount:in:)`'s doc comment for the derivation).
///
/// On a.
/// shape with zero or one solid, including every single-solid shape, this changes nothing: there
/// is no cross-solid pair to restrict.
///
/// ## Node identity (#642).
///
/// An earlier version built nodes from ``Shape/faces()``, the deduplicated enumeration that keeps.
/// only the first orientation a shared face is reached in. `AAGNode.isUpward`/isHorizontal/etc.
/// are derived from the node's normal, so which orientation survived the dedup silently decided.
/// the answer: the same compound, compounded in the opposite member order, produced a different
/// node set and therefore a different ``detectPockets()`` result for identical geometry.
///
/// Building.
/// from ``Shape/orientedFaces()`` instead keeps both sides of a shared face as their own node, so.
/// the graph, and everything that reads it, no longer depends on compound member order.
///
/// Two other approaches were considered and rejected:
/// - **One node per distinct face, carrying both normals.** Preserves the old index model, but.
///   every normal-derived predicate becomes two-valued and every caller of isUpward/.
///   isHorizontal/etc. has to say which side it means.
///
///   That pushes the ambiguity onto every.
///   consumer instead of resolving it once, in the graph.
/// - **Restrict AAG to single-solid input and document the limitation.** Legitimate only if AAG.
///   is never meaningful across solids, which was not established, and it would not fix anything.
///   for the multi-solid case: it would just make the wrong answer a documented one.
///
/// ```swift.
/// let box = Shape.box(width: 10, height: 10, depth: 10)!
/// let halves = box.split(atPlane: SIMD3(0, 0, 4), normal: SIMD3(0, 0, 1))!
///
/// // Same geometry, opposite compound member order.
/// let orderA = Shape.compound(halves)!.
/// let orderB = Shape.compound(halves.reversed())!.
///
/// // Order-independent: both sides of the shared wall are their own node either way.
/// print(orderA.detectPocketsAAG().count == orderB.detectPocketsAAG().count)   // true.
/// ```.
///
/// ## Why this does not build on BRepGraph (#761).
///
/// BRepGraph (`BRepGraph.swift`) answers the same two raw questions this type does --.
/// `adjacentFaces(of:)`/`sharedEdges(between:and:)` look like a ready-made replacement for the
/// pairwise OCCTFaceGetSharedEdgeSummary call `buildGraph()` makes below.
///
/// Measured (`Scripts/repro/761-aag-brepgraph-adjacency/`), not assumed, they are not.
/// interchangeable, for two independent reasons:
///
/// 1. **the BRepGraph\'s face-node identity is IsSame-deduplicated**, exactly the collapse rule.
///    `Shape.faces()` uses and #642's own fix moved AAG's node set away from.
///    (`BRepGraph::ShapesView::FindNode` hashes on TopTools_ShapeMapHasher, which is IsSame:
///    same underlying face, either orientation, one node). A face shared by two solids has ONE.
///
///    BRepGraph node, not two occurrence nodes, confirmed by mapping every occurrence of.
///    `orientedFaces()` to its BRepGraph node via `findNode(for:)` on both split fixtures: the
///    wall's two occurrences always resolve to the identical node index.
///
///    Querying that one node's.
///    `adjacentFaces(of:)` returns neighbors from BOTH solids merged (measured: 8 faces spanning
///    both solid groups on the vertical- and horizontal-cut fixtures), because BRepGraph has no.
///    concept of "this face as seen from solid A" versus "from solid B" to keep them apart.
///
///    That.
///    is exactly the cross-solid contamination #699 fixed by restricting `buildGraph()`'s own.
///    pairwise loop to same-solid pairs, a fix that is possible here because AAG keeps a.
///    separate node per occurrence, and would not be expressible against a graph that has already.
///    thrown that distinction away.
/// 2. **A per-pair swap is measurably slower, and the gap widens with model size.** the BRepGraph\'s.
///    own `adjacentFaces(of:)`/`sharedEdges(between:and:)` (bgAdjacentFaces/bgSharedEdges,
///    `OCCTBridge_BRepGraph.mm`) each linearly scan every edge in the WHOLE graph, because OCCT.
///    8.0.0p1 dropped `TopoView::FaceOps`'s direct face-face helpers and there is no indexed
///    face-to-face incidence to query instead.
///
///    The direct call compares only the two.
///    faces' own (small, typically 4-6) edge sets.
///
///    Measured on a plate with a grid of drilled.
///    holes: replacing the inner call, same O(n^2) outer loop, cost 2.4x more wall time at 22
///    face occurrences and 8x more at 70, growing, not constant, because the graph's own edge.
///    count grows with the model while each face's own edge count does not.
///
///    Restricting the swap.
///    to only the pairs already confirmed adjacent (a much smaller, roughly-linear subset) still.
///    roughly doubled the total cost of `buildGraph()`, because the BRepGraph\'s per-call scan cost is.
///    comparable to this type's ENTIRE current O(n^2) probe, before even counting the cost of.
///    building the BRepGraph and the occurrence-to-node map in the first place.
///
/// What #761 fixed instead: the one genuine correctness gap the comparison surfaced,
/// `AAGEdge.sharedEdgeCount` silently capping at 10 (the OCCTFaceGetSharedEdges\'s buffer, sized by a.
/// hardcoded caller argument, not the true count) even though `BRepGraph.sharedEdges(between:and:)`
/// has no such cap, confirmed on a synthetic fixture at 12 real shared edges, reported as 10.
///
/// Fixed at the root, in the SAME direct call this type already makes, with none of the scaling.
/// cost a BRepGraph-routed fix would have carried. #761 did that with an.
///
/// OCCTFaceGetSharedEdgeCount call sizing the buffer before OCCTFaceGetSharedEdges filled.
/// it; #783 then replaced both with.
/// the single OCCTFaceGetSharedEdgeSummary call `buildGraph()` makes today, which returns the.
/// true total and the first shared edge from one walk of the pair.
///
/// Neither of the two earlier.
/// functions is called from this file any more (#811).
public final class AAG: @unchecked Sendable {
    /// The shape this graph represents.
    public let shape: Shape

    /// All nodes (faces) in the graph.
    public private(set) var nodes: [AAGNode] = []

    /// All edges (adjacencies) in the graph.
    public private(set) var edges: [AAGEdge] = []

    /// Adjacency list: for each face index, list of (neighbor index, edge index).
    public private(set) var adjacencyList: [[Int: Int]] = []

    /// The same face occurrences `nodes` was built from (``Shape/orientedFaces()``), cached.
    /// once here so a consumer that needs the underlying Face (``AAG/detectPockets(tolerance:)``,
    /// for the floor's own outer wire) does not re-run the traversal `buildGraph()` already paid.
    /// for (#753).
    ///
    /// Index-for-index aligned with `nodes`, by construction: both come from this
    /// one array.
    ///
    /// Not Sendable-relevant beyond what `nodes`/`edges`/`adjacencyList` already.
    /// are, since it is written once here, in `buildGraph()`, and never mutated again.
    private var faceOccurrences: [Face] = []

    /// Create an AAG from a shape.
    public init(shape: Shape) {
        self.shape = shape
        buildGraph()
    }

    private func buildGraph() {
        // #642: orientedFaces(), not faces(). faces() keeps only the first orientation a shared
        // face was reached in, so a wall shared by two solids in a compound derived its normal
        // (and therefore isHorizontal/isUpward/isDownward/isVertical/zLevel) from whichever side
        // the dedup happened to keep, which depends on compound member order. orientedFaces()
        // keeps both sides as separate occurrences, each with the normal its own owning solid
        // sees, so the node set, and everything built on it, stops depending on that order. On a
        // shape whose faces are not shared this is exactly the faces() node set, in the same order.
        // #943: a face whose bounding box is void has no extent for any of the geometric
        // comparisons below (floor/wall matching, pocket depth, adjacency ranking), and `bounds`
        // is a stored, non-optional property of AAGNode. Dropping such a face is the only answer
        // that neither fabricates a box nor crashes on a force-unwrap; `faces` is filtered before
        // anything derives from it, so `nodes`, `faceOccurrences` and `adjacencyList` stay
        // index-for-index aligned by construction, and `distinctFaceIndex` still maps each node
        // back to the shape's own face enumeration. An explorer-derived face with no box is not
        // reachable on any fixture in this tree; this is the contract, not a live case.
        var faces: [Face] = []
        var faceBounds: [(min: SIMD3<Double>, max: SIMD3<Double>)] = []
        for face in shape.orientedFaces() {
            guard let box = face.exactBounds else { continue }
            faces.append(face)
            faceBounds.append(box)
        }
        let faceCount = faces.count
        // Cached for detectPockets() (#753): same array, same traversal, so caching it here
        // costs nothing this method wasn't already paying and saves a re-traversal per call.
        faceOccurrences = faces

        // Initialize adjacency list
        adjacencyList = Array(repeating: [:], count: faceCount)

        // Build nodes
        for (index, face) in faces.enumerated() {
            let node = AAGNode(
                faceIndex: index,
                distinctFaceIndex: face.index,
                normal: face.normal,
                isPlanar: face.isPlanar,
                isHorizontal: face.isHorizontal(),
                isUpward: face.isUpwardFacing(),
                isDownward: face.isDownwardFacing(),
                isVertical: face.isVertical(),
                zLevel: face.zLevel,
                // #733: exactBounds, not bounds. AAG's own floor/wall matching (see
                // detectPockets()'s defaultFloorRestsOnWallTolerance) compares this box against a
                // 1e-4 tolerance, and `bounds` silently grows by the mesh deflection once anything has
                // meshed this shape. AAGNode represents the shape's geometry, not its incidental
                // tessellation state, so its bounds must not move depending on whether the caller
                // happened to call mesh() first.
                bounds: faceBounds[index]
            )
            nodes.append(node)
        }

        // #699: which solid each occurrence belongs to, so the pairwise loop below never asks
        // OCCTFaceGetSharedEdgeSummary/OCCTEdgeGetConvexity about two faces from different solids.
        // Neither
        // bridge function has any notion of solid membership, both compare face1/face2 purely on
        // their own edge geometry, ignoring the `shape` argument beyond a null check, so on a
        // vertical cut, the two top-face halves (which border each other along the cut line) and
        // each half's own side of the shared wall were being compared cross-solid as well as
        // within their own solid, on top of the correct same-solid adjacencies.
        let groups = Self.solidGroups(occurrenceCount: faces.count, in: shape)

        // Build edges by checking all face pairs for adjacency
        for i in 0..<faceCount {
            for j in (i + 1)..<faceCount {
                let face1 = faces[i]
                let face2 = faces[j]

                // The two occurrences of one shared face are not neighbors of each other: they
                // are the same face, so every one of their boundary edges is "shared" with
                // itself. Without this guard the shared-edge comparison (which matches by IsSame,
                // ignoring orientation) reports a self-loop for every shared face.
                guard face1.index != face2.index else { continue }

                // #699: two occurrences in different solids are adjacent in the compound and not
                // in either solid; AAG's consumers (detectPockets(), concaveNeighbors(), etc.) want
                // the latter. `group` is nil when solid membership could not be established (a
                // single-solid shape, or a shape whose occurrence count didn't partition cleanly by
                // solid), in which case every pair is compared exactly as before #699.
                if let groups, groups[i] != groups[j] { continue }

                // #783: ONE bridge call per pair, not three. This used to ask
                // OCCTFacesAreAdjacent (is there a shared edge), then
                // OCCTFaceGetSharedEdgeCount (how many), then OCCTFaceGetSharedEdges(maxEdges: 1)
                // (give me one, for convexity), each rebuilding both faces' TopExp edge maps,
                // and the first and third literally redundant since the third always re-finds the
                // edge the first proved exists. A non-zero count IS adjacency.
                //
                // #761: the count is the TRUE count. The old code sized a fixed 10-slot buffer and
                // reported whatever fit, so a pair sharing more than ten edges silently
                // under-reported. Measured directly: a synthetic 11-notch fixture shares 12
                // and the old code said 10.
                var firstShared: OCCTEdgeRef?
                let trueCount = Int(
                    OCCTFaceGetSharedEdgeSummary(
                        shape.handle, face1.handle, face2.handle, &firstShared))
                if trueCount > 0 {
                    var convexity: EdgeConvexity = .smooth
                    if let firstEdge = firstShared {
                        let occtConvexity = OCCTEdgeGetConvexity(
                            shape.handle, firstEdge,
                            face1.handle, face2.handle
                        )
                        convexity = EdgeConvexity(fromOCCT: occtConvexity)
                        OCCTEdgeRelease(firstEdge)
                    }

                    let edgeIndex = edges.count
                    let edge = AAGEdge(
                        face1Index: i,
                        face2Index: j,
                        convexity: convexity,
                        sharedEdgeCount: trueCount
                    )
                    edges.append(edge)

                    // Update adjacency list (bidirectional)
                    adjacencyList[i][j] = edgeIndex
                    adjacencyList[j][i] = edgeIndex
                }
            }
        }
    }

    /// Which solid each entry of occurrences (``Shape/orientedFaces()``, in order) belongs to,.
    /// or nil if solid membership can't be established for this shape (#699).
    ///
    /// Returns one group id per occurrence, two occurrences sharing a group id if and only if they.
    /// belong to the same solid.
    ///
    /// The ids are arbitrary integers, not ``Shape/solids``'s own.
    /// indices, and callers should compare them for equality only.
    ///
    /// There is no bridge entry point that answers "which solid owns this face occurrence".
    /// directly, and this deliberately does not add one: OCCTShapeGetOrientedFaces, the walk
    /// `orientedFaces()` already runs, visits every occurrence under one top-level solid.
    /// contiguously before moving to the next, because it is driven by the same single.
    ///
    /// TopExp_Explorer descent that ``Shape/solids`` itself uses to enumerate solids in.
    /// first-encountered order (both are one DFS over the same shape, filtered to a different.
    /// target type).
    ///
    /// So the flat occurrence list partitions into contiguous runs whose lengths are.
    /// each solid's own face-occurrence count, with no need to match individual faces back to a.
    /// solid by identity.
    ///
    /// Confirmed against both the vertical- and horizontal-cut two-solid.
    /// fixtures in `Scripts/repro/cluster-a-subshape-enumeration` before relying on it here, not.
    /// assumed from the traversal's documented behavior alone.
    ///
    /// nil covers two cases deliberately treated the same: a shape with zero or one solid (no
    /// cross-solid pair can exist, so nothing needs restricting), and a shape whose per-solid.
    /// occurrence counts don't sum to the total occurrence count (a compound mixing solids with.
    /// free shells/faces, or a future shape this partitioning assumption doesn't hold for).
    ///
    /// Either.
    /// way, `buildGraph()` falls back to comparing every pair, exactly as it did before #699.
    ///
    /// Note what that sum check does and does not buy.
    ///
    /// It is necessary, not sufficient: it confirms
    /// the totals line up, not that each solid's occurrences are actually contiguous or that.
    /// `Shape.solids` enumerates solids in the same order the face walk meets them.
    ///
    /// Those hold.
    /// because both are TopExp_Explorer walks over one shape tree, which is a structural property.
    /// of the traversal rather than something checked at runtime. A future topology that broke it.
    /// while still summing correctly would mis-partition silently.
    ///
    /// That is an unenforced cross-API.
    /// invariant, validated empirically on the fixtures in Issue699AAGSolidScopedAdjacencyTests,.
    /// and it is the thing to re-measure first if this ever produces a surprising adjacency.
    private static func solidGroups(occurrenceCount: Int, in shape: Shape) -> [Int]? {
        let bodies = shape.solids
        guard bodies.count > 1 else { return nil }

        let counts = bodies.map { Int(OCCTShapeGetFaceOccurrenceCount($0.handle)) }
        guard counts.reduce(0, +) == occurrenceCount else { return nil }

        var groups = [Int](repeating: -1, count: occurrenceCount)
        var cursor = 0
        for (bodyIndex, count) in counts.enumerated() {
            for k in 0..<count { groups[cursor + k] = bodyIndex }
            cursor += count
        }
        return groups
    }

    /// Get neighbors of a face.
    public func neighbors(of faceIndex: Int) -> [Int] {
        guard faceIndex < adjacencyList.count else { return [] }
        return Array(adjacencyList[faceIndex].keys)
    }

    /// Get the edge between two faces (if adjacent).
    public func edge(between face1: Int, and face2: Int) -> AAGEdge? {
        guard face1 < adjacencyList.count else { return nil }
        guard let edgeIndex = adjacencyList[face1][face2] else { return nil }
        return edges[edgeIndex]
    }

    /// Get all concave neighbors of a face.
    public func concaveNeighbors(of faceIndex: Int) -> [Int] {
        guard faceIndex < adjacencyList.count else { return [] }
        return adjacencyList[faceIndex].compactMap { (neighbor, edgeIndex) in
            edges[edgeIndex].convexity == .concave ? neighbor : nil
        }
    }

    /// Get all convex neighbors of a face.
    public func convexNeighbors(of faceIndex: Int) -> [Int] {
        guard faceIndex < adjacencyList.count else { return [] }
        return adjacencyList[faceIndex].compactMap { (neighbor, edgeIndex) in
            edges[edgeIndex].convexity == .convex ? neighbor : nil
        }
    }
}

// MARK: - Pocket Feature

/// A recognized pocket feature in a solid.
public struct PocketFeature: Sendable {
    /// Index of the floor face.
    ///
    /// An **occurrence** index, the same one ``AAGNode/faceIndex`` uses, so it resolves against.
    /// ``Shape/orientedFaces()`` and **not** ``Shape/faces()`` (#642).
    ///
    /// Before #642 it indexed.
    /// `faces()`; on a compound whose solids share a face the two differ, and indexing `faces()`.
    /// with it now gives the wrong face or runs off the end.
    ///
    /// To recover the distinct-face index,.
    /// read `aag.nodes[pocket.floorFaceIndex].distinctFaceIndex`.
    ///
    /// ```swift.
    /// let aag = shape.buildAAG().
    /// for pocket in shape.detectPocketsAAG() {.
    ///     let floor = shape.orientedFaces()[pocket.floorFaceIndex]   // correct.
    ///     let distinct = aag?.nodes[pocket.floorFaceIndex].distinctFaceIndex.
    ///     print(floor.area, distinct as Any).
    /// }.
    /// ```.
    public let floorFaceIndex: Int

    /// Indices of the wall faces.
    ///
    /// **Occurrence** indices into ``Shape/orientedFaces()``, on the same footing as.
    /// `floorFaceIndex` (#642).
    public let wallFaceIndices: [Int]

    /// Z level of the pocket floor.
    public let zLevel: Double

    /// Bounding box of the pocket.
    public let bounds: (min: SIMD3<Double>, max: SIMD3<Double>)

    /// Whether this is an open pocket (not fully enclosed).
    ///
    /// Tests enclosure directly (#735), not wall cardinality: every boundary edge of the floor's
    /// outer wire must be an edge of one of the pocket's covering faces, or this is true.
    ///
    /// The.
    /// covering set is `wallFaceIndices` UNION the fillet or chamfer faces absorbed at a.
    /// junction (#762), which is wider than wallFaceIndices alone and is why a filleted pocket.
    /// is not reported open.
    ///
    /// See ``AAG/detectPockets(tolerance:)``'s doc comment for the full
    /// reasoning and why a bounding-box containment check was rejected in favor of this.
    ///
    /// #777 changed how membership is looked up without changing what it asks.
    ///
    /// The one input.
    /// where the two can differ is a compound `AAG.solidGroups` cannot partition, where the.
    /// verdict can move from open to enclosed; that case is argued rather than measured and is.
    /// tracked as #1089.
    public let isOpen: Bool

    /// Approximate depth of the pocket.
    public var depth: Double {
        bounds.max.z - zLevel
    }
}

// MARK: - Feature Recognition Extensions

extension AAG {
    /// Default tolerance (model units) used to decide whether a candidate floor sits at the.
    /// bottom of one of its candidate walls (#724).
    ///
    /// Far tighter than any real pocket depth in the test suite (millimeters or more), far looser.
    /// than the ~1e-7 bounding-box noise `Face.exactBounds` reports on an exact primitive.
    ///
    /// This is a default, not a fixed constant: ``detectPockets(tolerance:)`` and
    /// ``Shape/detectPocketsAAG(tolerance:)`` both take a caller-supplied `tolerance:` parameter
    /// with this value as its default (#733), matching every other tolerance in this module.
    /// (Curve3D, Surface, the Shape\'s own geometry methods, ...) rather than hardcoding one.
    /// millimeter-scale constant for every caller regardless of the model's own units.
    public static let defaultFloorRestsOnWallTolerance = 1e-4

    /// Detect pockets in the shape using AAG analysis.
    ///
    /// A pocket is identified by:
    /// 1.
    ///
    /// An upward-facing horizontal floor face.
    /// 2.
    ///
    /// Surrounded by vertical wall faces, each resting on that floor (#724).
    /// 3.
    ///
    /// Connected to walls via concave edges.
    ///
    /// ## A wall only floors where it bottoms out (#724).
    ///
    /// A blind pocket's floor is not the only upward-facing horizontal planar face touching a.
    /// concave edge to one of its walls: the exterior surface the pocket opens THROUGH, at the
    /// wall's other end, is upward-facing and horizontal too, and is a false "floor" whenever that.
    /// rim edge classifies concave, which a curved wall's rim can do even for a correctly-open.
    /// pocket, pending #723's replacement of the underlying convexity formula.
    ///
    /// Requiring the.
    /// candidate wall's own bounding-box minimum Z to match the floor's Z (rather than trusting.
    /// every concave-and-vertical neighbor) tells the two apart without depending on that edge's.
    /// classification at all: a pocket floor is upward-facing, so it is always the LOW end of the
    /// walls that rise from it, and a wall's high end is where it opens, whether to the exterior,.
    /// to a shallower pocket's floor above it, or to open air; never to a floor of its own.
    ///
    /// A single blind cylindrical pocket bored partway into a box is the fixture that first.
    /// surfaced this: the wall's own top rim (mis)classified concave made the box's outer top
    /// face, sitting at the wall's high end rather than its low end, register as a second pocket.
    /// floor for the very same wall.
    ///
    /// ```swift.
    /// let box  = Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20)!
    /// let tool = Shape.cylinder(at: .zero, direction: SIMD3(0, 0, 1), radius: 4, height: 20)!
    /// let cut  = box.subtracting(tool)!.
    /// print(cut.detectPocketsAAG().count)   // 1, not 2.
    /// ```.
    ///
    /// This does not depend on which of the wall's two rims classifies concave: a wall whose
    /// bounding box does not bottom out at a given candidate floor's Z is excluded from that.
    /// floor's walls regardless of why it was a concave neighbor in the first place.
    ///
    /// It also.
    /// requires nothing about every edge classification in the graph being correct, only that a.
    /// genuine floor is geometrically the low end of its own walls, which is true independent of.
    /// #723.
    ///
    /// This Z check applies to a DIRECT (1-hop) concave neighbor. A wall reached only after.
    /// absorbing a fillet or chamfer junction (#762, below) skips it deliberately: that wall's
    /// own bounding box is rounded past the floor's Z by roughly the fillet radius or chamfer.
    /// leg, by construction, so requiring the match there would fail the very walls #762 exists.
    /// to find.
    ///
    /// ## A filleted or chamfered junction is absorbed, not reclassified (#762).
    ///
    /// A fillet at a floor/wall junction is tangent to both surfaces (`ChFi3d::DefineConnectType`
    /// reports `.smooth` at both new edges, by construction: a fillet is G1-continuous with
    /// both faces it blends), so floor-to-fillet and fillet-to-wall both read smooth and the.
    /// floor has **no concave neighbor at all**, so `concaveNeighbors(of:)` alone can never find
    /// it. `ChFi3d::DefineConnectType` is not wrong here: the concavity moved into the fillet
    /// FACE's own curvature, not the edges, and reclassifying the edges would be exactly the.
    /// hand-rolled-formula regression #703/#723 already fixed.
    ///
    /// A chamfer has the same missing-pocket symptom for a different reason: measured
    /// (`Scripts/repro/762-filleted-pocket-detection/`), a symmetric chamfer's two new edges.
    /// are both genuinely `.concave` (a 270-degree reentrant corner splits into two.
    /// 225-degree ones, still `>180`), so `concaveNeighbors(of:)` DOES reach the chamfer face
    /// directly, but the chamfer is planar at an intermediate angle, fails the wall's own.
    /// isVertical filter, and the search used to stop there rather than continuing past it to.
    /// the true wall.
    ///
    /// `wallsAndJunctions(fromFloor:floorZ:tolerance:)` fixes both by tracing outward from the
    /// floor through any non-wall face reached via a `.concave` edge (a chamfer, unconditionally).
    /// or a `.smooth` edge into a face confirmed to curve the right way.
    /// (``isRadiallyInwardFillet(_:)``, a fillet), continuing until it lands on a genuine
    /// vertical wall.
    ///
    /// See that method's own doc comment for the full mechanism, the ground truth.
    /// it rests on, and why the `.smooth` gate is necessary (not every tangent neighbor is a.
    /// junction to absorb; see "false-positive guards" there).
    ///
    /// ```swift.
    /// let box = Shape.box(width: 20, height: 20, depth: 20)!
    /// let pocketTool = Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15)!
    /// let cut = box.subtracting(pocketTool)!.
    /// let junctionEdges = cut.edges(where: { abs($0.bounds.min.z) < 1e-6 && abs($0.bounds.max.z) < 1e-6 })
    /// let filleted = cut.filleted(edges: junctionEdges, radius: 1.0)!
    /// print(filleted.detectPocketsAAG().count)   // 1, was 0.
    /// ```.
    ///
    /// ## Enclosure is tested directly, not by wall count (#735).
    ///
    /// `PocketFeature.isOpen` used to be `wallIndices.count < 3`. A wall count is not enclosure: a
    /// blind cylindrical pocket has exactly **one** wall (the cylinder) and is fully enclosed, so.
    /// it reported `isOpen == true`.
    ///
    /// Three walls is also the wrong threshold on its own terms, a.
    /// genuinely open three-sided slot and a closed three-walled (e.g. triangular) pocket both have.
    /// `wallIndices.count == 3` and are indistinguishable by counting alone.
    ///
    /// Measured directly: a
    /// slot cut through a box's own side face has one floor edge that borders no wall in the set.
    /// (the open side, at 3 walls covering 3 of the floor's 4 boundary edges), while the closed.
    /// triangular pocket's 3 walls cover all 3 of its floor's boundary edges.
    ///
    /// The fix tests the definition the field documents: the floor plus its covering faces form a
    /// closed loop around the floor's own boundary exactly when every boundary edge of the floor's.
    /// outer wire borders one of them.
    ///
    /// The covering set is ``PocketFeature/wallFaceIndices`` UNION.
    /// the fillet or chamfer faces absorbed at a junction (#762), wider than wallFaceIndices.
    /// alone, which is why a filleted pocket is not reported open.
    ///
    /// Tested **per edge**, not by.
    /// comparing counts (#753): for each edge of the floor's own outer wire, ask whether it is one
    /// of the covering faces' own edges, by structural identity (`TopoDS_Shape::IsSame`).
    ///
    /// An inner.
    /// wire (an island inside the pocket, e.g. a boss) never enters this test at all: the loop only
    /// ever visits the outer wire's own edges, so a boss's wall, which passes every filter above and.
    /// legitimately lands in wallIndices, cannot mask a gap in the outer boundary the way it.
    /// could when the old and new formulas both summed a per-face-pair total.
    ///
    /// #777 turned that membership test around without changing what it asks.
    ///
    /// It used to reach.
    /// ``Edge/adjacentFaces(in:)`` per boundary edge, which rebuilds a whole-shape edge-to-face
    /// map on every call; it now reads the covering faces' own edges once per pocket.
    /// (`CoveringEdges`) and tests each boundary edge against that.
    ///
    /// See.
    /// `Scripts/repro/777-pocket-isopen/` for the measurement, including the one case where the.
    /// two constructions do not return the same face set.
    ///
    /// This replaced an earlier version of this same fix that summed `AAGEdge.sharedEdgeCount`.
    /// over wallIndices and compared the sum to the outer wire's edge count.
    ///
    /// Review of #753 found.
    /// two ways that arithmetic could go wrong even though it was already wire-scoped on one side:
    /// sharedEdgeCount is a **total** across the whole face pair, inner wires included, so a boss.
    /// wall's own inner-wire edge was being added to the same sum as the outer boundary's: closed
    /// three walls plus one boss edge could reach four and look complete while the outer loop.
    /// itself still had a real gap.
    ///
    /// It was also capped at the time: the OCCTFaceGetSharedEdges\'s
    /// fixed buffer silently truncated past its slot count, so a floor/wall pair sharing more.
    /// edges than that (plausible after healing splits a boundary into segments, and confirmed on.
    /// a synthetic fixture by #761) would undercount regardless of wire scope. `buildGraph()`.
    /// now reads the true total from OCCTFaceGetSharedEdgeSummary (#783) instead, so.
    /// `AAGEdge.sharedEdgeCount` itself is no longer capped, but the per-edge test below still.
    /// does not depend on it being accurate, which is the point: it does not read
    /// sharedEdgeCount at all.
    ///
    /// Testing membership per edge instead of comparing sums removes both failure modes.
    /// structurally: the loop never visits an inner-wire edge in the first place, and it never reads
    /// a total that could be capped.
    ///
    /// A second candidate was considered and rejected: whether the pocket's bounding box sits
    /// strictly inside the parent solid's, in the horizontal axes.
    ///
    /// It is cheaper, but wrong for a.
    /// pocket that legitimately reaches an outer wall of the part while still being fully enclosed.
    /// on every side that matters (e.g. a pocket machined flush with one face of a plate), that is.
    /// a statement about *where* the pocket sits, not about whether it is closed, and the two are.
    /// independent.
    ///
    /// Enclosure is a property of the wall loop, not of the pocket's position in space.
    ///
    /// ## The tolerance filter's limitation was measured and did not reproduce as hypothesized (#753 finding 3), then fixed for a different reason (#762).
    ///
    /// Review of #753 raised a plausible-sounding compounding failure: a wall dropped by the
    /// `#724` tolerance filter above (e.g. a filleted floor/wall junction rounding the wall's.
    /// low-Z bound past floorZ) would also drop its edges from the enclosure count,.
    /// permanently misreporting a fully enclosed filleted pocket as open.
    ///
    /// Measured directly at.
    /// the time (radii 0.5 through 4 on a 10×10×15 pocket): the fillet did not reproduce that
    /// specific failure, because a filleted pocket was not detected as a pocket AT ALL:
    /// `concaveNeighbors(of:)` came back empty (the floor/wall edges are tangent, not concave,
    /// see "A filleted or chamfered junction is absorbed, not reclassified" above) and the floor.
    /// was skipped before the tolerance filter, or this enclosure test, ever ran. #762 fixed.
    /// that non-detection; this enclosure test's own coverage check is now exercised by a.
    /// filleted pocket for the first time, against wallIndices UNION the absorbed junction.
    /// faces rather than wallIndices alone (see `detectPockets(tolerance:)`'s use of
    /// coveringFaces), so the compounding failure review originally hypothesized is the thing.
    /// this union specifically forecloses, now that there is a filleted pocket for it to apply to.
    ///
    /// - Parameter tolerance: How close (model units) a wall's own low-Z bound must come to a
    ///   candidate floor's Z to count as resting on it.
    ///
    ///   Defaults to.
    ///   `defaultFloorRestsOnWallTolerance`.
    ///
    ///   Scale this with the model: the default is tuned for
    ///   millimeter-scale parts, and a shape modeled in meters or in thousandths of an inch may.
    ///   need a different value (#733). `AAGNode.bounds` itself is unaffected by meshing either.
    ///   way (#733), so widening this is about the model's own units, not about tessellation noise.
    /// - Returns: One entry per detected pocket, empty when the shape has none.
    public func detectPockets(tolerance: Double = defaultFloorRestsOnWallTolerance)
        -> [PocketFeature]
    {
        var pockets: [PocketFeature] = []

        // Find all upward-facing horizontal faces as potential floors
        let potentialFloors = nodes.enumerated().filter { _, node in
            node.isUpward && node.isHorizontal && node.isPlanar
        }

        // #735: reindexed against occurrences exactly like `PocketFeature.floorFaceIndex`'s own
        // doc comment does, so `occFaces[floorIndex]` is the same Face the floor's AAGNode
        // describes. Cached on the AAG by buildGraph() (#753) rather than recomputed here.
        let occFaces = faceOccurrences

        for (floorIndex, floorNode) in potentialFloors {
            guard let floorZ = floorNode.zLevel else { continue }

            // #762: walk concave AND absorbed-fillet/chamfer chains outward from the floor,
            // not just its direct concave neighbors, so a filleted or chamfered floor/wall
            // junction is found through the fillet/chamfer face instead of stopping at it. See
            // this method's own doc comment ("A filleted or chamfered junction is absorbed,
            // not reclassified") for the full reasoning.
            let (wallIndices, junctionIndices) = wallsAndJunctions(
                fromFloor: floorIndex, floorZ: floorZ, tolerance: tolerance)

            // Need at least one wall to be a pocket
            guard !wallIndices.isEmpty else { continue }

            // Calculate pocket bounds from floor, walls, and any absorbed junction faces
            // (#762): a fillet/chamfer's own extent reaches slightly past where the trimmed
            // wall now starts, so omitting it would silently under-report the pocket's bounds
            // by roughly the fillet radius or chamfer leg.
            var minX = floorNode.bounds.min.x
            var minY = floorNode.bounds.min.y
            var maxX = floorNode.bounds.max.x
            var maxY = floorNode.bounds.max.y
            var maxZ = floorZ

            for index in wallIndices + junctionIndices {
                let faceBounds = nodes[index].bounds
                minX = min(minX, faceBounds.min.x)
                minY = min(minY, faceBounds.min.y)
                maxX = max(maxX, faceBounds.max.x)
                maxY = max(maxY, faceBounds.max.y)
                maxZ = max(maxZ, faceBounds.max.z)
            }

            // Enclosure, not wall count (#735), tested per edge rather than by comparing counts
            // (#753): every boundary edge of the floor's own OUTER wire must border one of the
            // covering faces (wallIndices UNION junctionIndices, see below), or this pocket is
            // open. Folding the "can't measure the boundary" case
            // into `?? []`/`isEmpty` (review finding 6) makes "no outer wire" and "an outer wire
            // with zero edges" the same case they already behave as: don't claim an enclosure
            // that wasn't established, default to open.
            //
            // #762: a floor's own outer-wire boundary edge borders the ABSORBED junction face
            // (the fillet or chamfer), not the far wall, whenever one is interposed, so
            // coverage is tested against walls UNION junctions, not walls alone.
            //
            // #777: membership is read off the covering faces' own edges rather than by asking
            // the whole shape which faces bound each boundary edge. Same predicate, evaluated
            // from the other end, resolved once per pocket instead of once per edge.
            let floorOuterEdges = occFaces[floorIndex].outerWire?.edges() ?? []
            let isOpen: Bool
            if floorOuterEdges.isEmpty {
                isOpen = true
            } else {
                let coveringEdges = CoveringEdges(
                    facesAt: wallIndices + junctionIndices, in: occFaces)
                isOpen = floorOuterEdges.contains { !coveringEdges.contains($0) }
            }

            let pocket = PocketFeature(
                floorFaceIndex: floorIndex,
                wallFaceIndices: wallIndices,
                zLevel: floorZ,
                bounds: (
                    min: SIMD3(minX, minY, floorZ),
                    max: SIMD3(maxX, maxY, maxZ)
                ),
                isOpen: isOpen
            )

            pockets.append(pocket)
        }

        // Sort by Z level (deepest first)
        pockets.sort { $0.zLevel < $1.zLevel }

        return pockets
    }

    /// Finds a floor's walls by tracing concave edges, and any absorbed fillet/chamfer.
    /// junction, outward from it (#762).
    ///
    /// Returns the true (vertical) walls (what ``PocketFeature/wallFaceIndices`` reports, with.
    /// exactly the same meaning it had before this fix), and, separately, every junction face.
    /// absorbed along the way, which the enclosure test in ``detectPockets(tolerance:)`` needs: the
    /// floor's own outer-wire boundary edges border THOSE, not the far wall, whenever one is.
    /// interposed.
    ///
    /// ## Why a fillet needs a chain, and a chamfer needs a shorter one.
    ///
    /// Measured (`Scripts/repro/762-filleted-pocket-detection/`, ChFi3d::DefineConnectType
    /// against a sharp/filleted/chamfered/partially-filleted/open/boss fixture set):
    ///
    /// - **A fillet's own two new edges are both `.smooth` (tangent)**, at BOTH ends, by.
    ///   construction: a fillet is G1-continuous with both faces it blends, so there is no
    ///   local sign left to read at either edge; concave and convex fillets look identical.
    ///   there.
    ///
    ///   The concavity moved into the fillet FACE's own curvature, not the edges.
    /// - **A chamfer's own two new edges are both `.concave`** (for a pocket's floor/wall.
    ///   junction): a symmetric chamfer replacing a 270-degree reentrant corner leaves two
    ///   225-degree transitions, still `>180`. `concaveNeighbors(of:)` already reaches a
    ///   chamfer face directly; the reason detectPockets still missed a chamfered pocket.
    ///   before this fix is wallIndices' OWN isVertical filter, which a 45-degree chamfer.
    ///   face fails; the search just never continued past it to the real wall beyond.
    ///
    /// So a chamfer only ever needed the search to continue past a non-wall CONCAVE neighbor;.
    /// a fillet additionally needs `.smooth` edges to be crossable, gated by.
    /// ``isRadiallyInwardFillet(_:)`` since edge convexity alone carries no sign there.
    ///
    /// ## The `.smooth` gate: radially inward, not "concave"
    ///
    /// A `.smooth` edge is only crossed toward a face that is itself a legitimate.
    /// corner-rounding fillet: cylindrical, conical or spherical, with its own outward normal
    /// pointing back toward its axis/center (radially inward) rather than away from it.
    ///
    /// This is.
    /// the identical material-side test ``detectHoles()`` uses (#747/#760) to tell a hole's bore.
    /// from a boss's wall, aimed at a narrower question here (see.
    /// ``isRadiallyInwardFillet(_:)``'s own doc comment for why this does NOT, and does not
    /// need to, distinguish a pocket's fillet from a boss's).
    ///
    /// This specifically refuses to cross a `.smooth` edge into a face that curves the OTHER.
    /// way (radially outward): an ordinary convex/external rounding, e.g. the box's own
    /// exterior edge filleted, which is not a floor/wall junction to absorb at all, and.
    /// refuses a `.smooth` edge between two faces where neither is such a fillet (an.
    /// unrelated, incidentally-tangent planar pair).
    ///
    /// Without this gate, unconditionally.
    /// crossing every `.smooth` edge would be exactly the "transitive tangency sweeps in.
    /// faces that are not walls at all" trap #762 itself warns about.
    ///
    /// ## Why a chain-discovered wall skips the #724 Z-tolerance check.
    ///
    /// A direct (1-hop) concave neighbor still has to bottom out at the floor's own Z (#724.
    /// unchanged) to rule out grabbing the wrong (top, opening) end of a wall. A wall reached.
    /// only after absorbing at least one junction face is trusted by the CHAIN's own.
    /// contiguity instead: measured, a filleted or chamfered wall's own remaining planar
    /// remnant no longer touches the floor's Z at all: it starts roughly a fillet radius or
    /// chamfer leg distance above it, since the junction face itself is what actually bottoms.
    /// out there.
    ///
    /// Requiring the Z match on the far side of an already-verified junction chain.
    /// would make every filleted/chamfered wall fail the very check meant to confirm it is.
    /// this floor's wall, re-introducing the bug this method exists to fix.
    ///
    /// ## A direct dead end stays revisitable through a later junction.
    ///
    /// visited is marked only once an edge's outcome is decided (wall or junction), not as.
    /// soon as the edge is crossable.
    ///
    /// Review of an earlier version of this fix found the.
    /// opposite: `visited.insert(neighbor)` fired immediately after the crossable check, so a
    /// face that failed the Z-tolerance check above AS A DIRECT NEIGHBOR (`reachedThroughJunction.
    /// == false`) was marked visited regardless, and a separate edge reaching that same face.
    /// through an already-absorbed junction later in the same search, where the Z check is.
    /// bypassed and WOULD have accepted it, could never run: `guard !visited.contains(neighbor)`
    /// closed it off first.
    ///
    /// Measured, not assumed, that this is reachable on this codebase's own fixtures, not only.
    /// hypothetical: a partially-filleted pocket's two SHARP walls each have their own low-Z
    /// bound offset from the floor's exact Z by about `1.5e-7` (a BRepFilletAPI_MakeFillet.
    /// corner-blending artifact where each meets the adjacent filleted wall's own fillet),.
    /// invisible at the default tolerance but decisive at a smaller one.
    /// (Issue762DeadEndRevisitableThroughJunctionTests, `1e-8`): the direct route fails, and
    /// the fillet's own separate `.concave` edge to the same wall (not `.convex`, so not.
    /// screened by the guard below) is the only thing that finds it.
    ///
    /// Proved by injection:
    /// reintroducing the early `visited.insert` and rerunning that exact fixture at that exact.
    /// tolerance drops both sharp walls entirely (`wallFaceIndices.count` 4 to 2, isOpen.
    /// false to true); the fix restores both.
    ///
    /// A wall and a junction are both true terminal outcomes for the EDGE just crossed, so both.
    /// mark visited: a wall stops the chain outright, and a junction is queued into next
    /// exactly once regardless of how many other edges could also reach it. A dead end is not a.
    /// terminal outcome for the FACE, only for that one edge, so it alone is left out of.
    /// visited deliberately.
    ///
    /// This does not risk non-termination: the total work is still
    /// bounded by this floor's own edge count, since a dead end can be retried at most once per.
    /// incoming edge (not per BFS level), and every retry either terminates (wall or junction,.
    /// marking visited and ending the retries) or dead-ends again along that specific edge.
    ///
    /// ## `.convex` never crosses: proven load-bearing past a junction, once dead ends could be retried
    ///
    /// `EdgeConvexity.convex` means the material turns the wrong way for absorption by.
    /// definition (interior angle `<180`, "fillet-like, going outward", see the enum's own doc.
    /// comment), so refusing to cross it is correct on its face.
    ///
    /// Two earlier review rounds show.
    /// why that alone was not enough to call it proven, and why the visited-marking fix above.
    /// is what finally let a fixture demonstrate it.
    ///
    /// The guard has two call sites with different backstops.
    ///
    /// For a DIRECT (1-hop) floor.
    /// neighbor, the #724 Z-tolerance check is a second, independent line of defense: even with
    /// `.convex` unblocked, a direct neighbor still has to bottom out at the floor's own Z to.
    /// become a wall.
    ///
    /// For a face reached PAST an already-absorbed junction,.
    /// reachedThroughJunction deliberately bypasses that Z check, so `.convex` is the ONLY.
    /// remaining protection there. A first removal-matrix pass (injection C, disabling the.
    /// block alone) came back green on every test in the PR at the time, read as proof the.
    /// guard was decorative, and that reading was wrong: it measured only that direct neighbors
    /// were screened by the Z-check, and no fixture then isolated the past-a-junction path.
    ///
    /// A second pass built two fixtures specifically to isolate that path (both ground-truthed.
    /// against ChFi3d first, `Scripts/repro/762-filleted-pocket-detection/`, fixtures 5 and.
    /// 8) and both APPEARED to fail to isolate it: the filleted through-slot's open-end
    /// exterior wall, and the L-shaped pocket's reflex-corner far wall, were each also a direct.
    /// (1-hop) floor neighbor, so the #724 Z-check seemed to resolve them before the fillet's.
    /// own `.convex` edge was ever tried.
    ///
    /// That conclusion rested on an unexamined assumption:
    /// that a direct neighbor failing the Z-check was fully resolved, the same assumption the.
    /// visited-marking bug above made in code.
    ///
    /// It was not examined at the time because the bug.
    /// had not yet been found.
    ///
    /// Both "masked" fixtures were REJECTING their direct route, not.
    /// accepting it (near-boundary Z-tolerance noise on the through-slot's own construction, and.
    /// exactly on the boundary for the reflex corner's own BRepFilletAPI corner-blending.
    /// artifact), and a rejected direct neighbor used to be marked visited anyway, permanently.
    /// closing off the very `.convex`-gated path this section is about.
    ///
    /// With dead ends left revisitable and Issue762ReflexCornerPartialFilletTests restored to.
    /// the default tolerance (rather than widened past the noise, which is what let it clear.
    /// the direct route and mask this entirely), injection C alone now fails on exactly those.
    /// two fixtures: the filleted through-slot's `wallFaceIndices.count` goes 2 to 4 and its
    /// isOpen goes true to false (both exterior walls wrongly absorbed as walls of the.
    /// pocket), and the reflex-corner fixture's wallCounts goes `[2, 4]` to `[2, 5]` (WallX0.
    /// wrongly absorbed). `.convex` is not untested any more: it is what stops both, proven by
    /// the same injection that once read as clearing it.
    ///
    /// The earlier "geometric argument" this doc comment used to make (that a floor's own.
    /// polygon vertex always gives it an equally early, non-`.convex` route to whatever a.
    /// junction's `.convex` neighbor could reach, so the guard's own contribution was always.
    /// redundant) is retracted, not merely superseded: it was true of the graph as the CODE
    /// then implemented it, where a rejected direct neighbor's visited marking made that.
    /// route's failure equivalent to its success, both closing off the second route.
    ///
    /// It was.
    /// never true of the geometry itself, only of a bug that happened to make the two.
    /// indistinguishable in every fixture built to tell them apart.
    ///
    /// ## currentBordersFloorDirectly: carried by the BFS, not reconstructed from adjacency
    ///
    /// A fourth review round found the guard that decides whether a vertical `.smooth` neighbor.
    /// may become a wall, currentBordersFloorDirectly, first shipped as.
    /// `adjacencyList[floorIndex][current] != nil`: "does some edge exist between the floor and
    /// current".
    ///
    /// That is a different, weaker question than "was current reached directly.
    /// from the floor". adjacencyList is built for every edge regardless of convexity, so a.
    /// junction that only incidentally touches the floor through a non-crossable edge would.
    /// wrongly satisfy it without ever having been reached that way, reintroducing this.
    /// method's own bug for a topology none of the ten ground-truthed fixtures happened to.
    /// exercise.
    ///
    /// Not hypothetical on this codebase: the BRepFilletAPI_MakeFillet\'s own
    /// corner-blending is documented, in the Issue762ReflexCornerPartialFilletTests\'s own doc.
    /// comment (re: WallX0), to reshape an unrelated face so the floor borders it directly by
    /// incident, not by the route actually taken to reach it.
    ///
    /// Fixed by carrying the fact instead of reconstructing it: each frontier entry pairs a
    /// node index with whether IT was reached directly from the floor.
    /// (bordersFloorDirectly), decided once, at the exact moment it is enqueued.
    /// (discoveredBordersFloorDirectly, `current == floorIndex`).
    ///
    /// This is exact by.
    /// construction, not merely narrower: it cannot be fooled by any incidental edge, since it
    /// never consults `adjacencyList[floorIndex]` at all.
    ///
    /// A dedicated removal-matrix row (injection E) isolates this specific gate: forcing
    /// currentBordersFloorDirectly to its pre-fix effective value of true (as if every node.
    /// bordered the floor directly) fails exactly.
    ///
    /// Issue762VerticalCornerBlendNotAWallTests/Issue762FullyRoundedPocketChainingTests and.
    /// no other test in the full `#762`/`#753`/`#735`/`#747` suite.
    ///
    /// That isolation is the point:
    /// those same two tests also fail under injection B/D (the Z-tolerance bypass), for a.
    /// different reason (every chain-discovered wall breaks there, not specifically the.
    /// corner-blend misclassification this gate closes), so a row that merely observes them.
    /// failing under an unrelated guard's removal would not have proven this gate does anything.
    ///
    /// This is the third guard on this PR shown to need an isolating row rather than a.
    /// coincidentally-failing one: injection C was first masked by the visited-marking bug
    /// above, injections B and D backstop each other, and this gate's own first "proof" folded.
    /// into B/D's set instead of exercising itself.
    ///
    /// Full removal matrix, A through E, re-run against the grown suite (34 tests) after this.
    /// fix, each row's isolation restated:
    ///
    /// | injection | disables | isolates | tests that fail |.
    /// |---|---|---|---|.
    /// | A | the `.smooth`-edge radially-inward gate | whether a fillet is confirmed reentrant before crossing into it | 3: plain-box exterior fillet, both L-shape tests |
    /// | B | the #724 Z-tolerance bypass for chain-discovered walls | whether a chain-discovered wall is trusted by contiguity instead of its own Z | 12: every fillet/chamfer/chain-discovered-wall test, including both round-4 tests (a different mechanism than E, see above) |
    /// | C | the `.convex` edge block | whether a reentrant-the-wrong-way edge is refused | 2: filleted through-slot, L-shape reflex corner |
    /// | D | B and C together | both of the above at once | 12, identical to B's own set (B's breakage dominates) |.
    /// | E | currentBordersFloorDirectly (forced true) | whether a wall can only be accepted from the floor itself or a junction that borders it directly | 2: exactly the two round-4 tests, and only those |
    private func wallsAndJunctions(fromFloor floorIndex: Int, floorZ: Double, tolerance: Double)
        -> (walls: [Int], junctions: [Int])
    {
        var walls: [Int] = []
        var junctions: [Int] = []
        var visited: Set<Int> = [floorIndex]
        // Each frontier entry carries whether IT was reached directly from the floor, decided
        // once, at the moment it was enqueued, rather than re-derived later from adjacency
        // (#762 review, round 4 finding 1). A first version of this gate asked
        // `adjacencyList[floorIndex][current] != nil`, "does some edge exist between the floor
        // and `current`", which is the wrong question: `adjacencyList` is built for every edge
        // regardless of convexity, so a junction that only incidentally touches the floor
        // through a non-crossable edge would wrongly satisfy it without ever having been
        // reached that way. That is not hypothetical on this codebase: `BRepFilletAPI_MakeFillet`'s
        // own corner-blending is documented (`Issue762ReflexCornerPartialFilletTests`'s own doc
        // comment, re: WallX0) to reshape an unrelated face so the floor borders it directly by
        // incident, not by the route the BFS actually took. Carrying the fact the BFS already
        // knows, instead of reconstructing a weaker version of it, removes that failure mode by
        // construction rather than narrowing it.
        var frontier: [(index: Int, bordersFloorDirectly: Bool)] = [(floorIndex, true)]

        while !frontier.isEmpty {
            var next: [(index: Int, bordersFloorDirectly: Bool)] = []
            for (current, currentBordersFloorDirectly) in frontier {
                let reachedThroughJunction = current != floorIndex
                guard current < adjacencyList.count else { continue }
                // Whether `current` is itself a confirmed reentrant fillet, i.e. whether we
                // are CONTINUING an already-verified chain rather than trying to ENTER a new
                // one. `isRadiallyInwardFillet(current)` is always false for `current ==
                // floorIndex` (a floor is planar, never a fillet), so this is the entering
                // case at BFS level 0 by construction, not a separate check.
                let currentIsConfirmedFillet = isRadiallyInwardFillet(current)
                // A newly discovered junction's OWN `bordersFloorDirectly` flag: true exactly
                // when its entering edge (the one just crossed) came from the floor itself,
                // i.e. `current == floorIndex`. Every node discovered while processing the
                // floor's own frontier entry gets `true`; every node discovered one level
                // deeper or beyond gets `false`, uniformly, since by construction none of them
                // is reached with `current == floorIndex` (#762 review, round 4). "Close enough
                // to the floor, structurally, for a face it borders to be THIS floor's own
                // wall" means the floor itself, or a junction whose OWN entering edge came
                // directly from the floor: exactly the fillet or chamfer built to blend the
                // floor to its wall, which by construction has exactly two "long"
                // tangent/concave relationships, to the floor and to that wall, and nothing
                // else. A junction reached only through ANOTHER junction (a corner blend
                // continuing the chain, e.g. the torus and second fillet in fixture 9) is not
                // that specific relationship: it exists to reconcile two OTHER faces, and its
                // own far neighbor is not automatically this floor's wall just because it is
                // vertical and radially inward, since a further corner blend can be both of
                // those too.
                let discoveredBordersFloorDirectly = !reachedThroughJunction
                for (neighbor, edgeIndex) in adjacencyList[current] {
                    guard !visited.contains(neighbor) else { continue }
                    let edge = edges[edgeIndex]
                    let crossable: Bool
                    switch edge.convexity {
                    case .convex:
                        crossable = false
                    case .concave:
                        crossable = true
                    case .smooth:
                        // ENTERING a fillet chain for the first time (`current` is not itself
                        // one) requires the candidate to be a confirmed reentrant fillet: this
                        // is the only sign a tangent edge carries (#762 review). CONTINUING an
                        // already-confirmed chain accepts either the wall the fillet blends
                        // into (a vertical face, checked below) or another face that
                        // independently confirms the same reentrant curvature (a further corner
                        // blend, e.g. a torus or a second fillet, continuing the same physical
                        // corner). This is deliberately NOT `isRadiallyInwardFillet(edge.face1Index)
                        // || isRadiallyInwardFillet(edge.face2Index)`: that tests EITHER end of
                        // the edge, and once `current` is a confirmed fillet it always
                        // satisfies its own half of that OR, making every `.smooth` edge
                        // leaving it crossable regardless of what is actually on the far side,
                        // including an unrelated tangent face. Crossability alone does not
                        // decide wall vs. junction below; `currentBordersFloorDirectly` does.
                        if currentIsConfirmedFillet {
                            crossable =
                                nodes[neighbor].isVertical || isRadiallyInwardFillet(neighbor)
                        } else {
                            crossable = isRadiallyInwardFillet(neighbor)
                        }
                    }
                    guard crossable else { continue }

                    // `visited` is only marked once the outcome is decided (#762 review), not
                    // as soon as the edge is crossable. A DEAD END below (a direct vertical
                    // neighbor that fails the #724 Z-check) must stay revisitable: the same
                    // face can also be reached later through a junction, where the Z-check is
                    // bypassed entirely, and marking it visited here would permanently hide
                    // that second, accepting route behind the first, rejecting one. Wall and
                    // junction are both true terminal outcomes for THIS edge (a wall stops the
                    // chain; a junction is queued exactly once), so both mark visited; dead end
                    // is not a terminal outcome for the face, only for this particular edge.
                    let candidate = nodes[neighbor]
                    guard candidate.isVertical else {
                        // Not a wall itself: a junction face (fillet, chamfer, or a curved
                        // corner blend) absorbed into the floor/wall transition. Keep looking
                        // past it for the true wall.
                        visited.insert(neighbor)
                        junctions.append(neighbor)
                        next.append((neighbor, discoveredBordersFloorDirectly))
                        continue
                    }
                    guard currentBordersFloorDirectly else {
                        // Vertical, but reached from a junction that does not itself border the
                        // floor: not this floor's wall (that relationship belongs solely to the
                        // floor-bordering junction), and not a dead end either, since it may
                        // still be worth searching past (#762 review, round 4, fixture 9: a
                        // vertical corner-blend cylinder between a floor-bordering fillet's own
                        // torus and the genuine wall). Absorbed as a further junction instead of
                        // a wall, regardless of how the Z-check below would have scored it.
                        visited.insert(neighbor)
                        junctions.append(neighbor)
                        next.append((neighbor, discoveredBordersFloorDirectly))
                        continue
                    }
                    if reachedThroughJunction || abs(candidate.bounds.min.z - floorZ) < tolerance {
                        visited.insert(neighbor)
                        walls.append(neighbor)
                        // A found wall is terminal for this chain: do not look past it.
                    }
                    // else: a direct vertical neighbor that does not bottom out at this
                    // floor's Z is the wrong (opening) end of some other wall (#724), along
                    // THIS edge specifically: a dead end for this edge, not a wall and not a
                    // junction to search further from, but deliberately left out of `visited`
                    // so a different edge reaching the same face through an already-absorbed
                    // junction still gets a chance to accept it.
                }
            }
            frontier = next
        }
        return (walls, junctions)
    }

    /// Whether the face at nodeIndex is a cylindrical, conical or spherical fillet curving.
    ///
    /// INTO the material it borders.
    ///
    /// Its own outward normal, sampled at its own UV mid-parameter, points back toward its axis.
    /// (or, for a sphere, its center) rather than away from it (#762).
    ///
    /// This is the identical material-side test ``detectHoles()`` uses (#747/#760) to tell a.
    /// hole's bore from a boss's or a standalone cylinder's own wall, aimed at a narrower.
    /// question: not "is this whole face a hole," but "is this specific transition face a
    /// rounded-INTO junction," the shape any corner-rounding fillet has, whether it is.
    /// rounding a pocket's own concave floor/wall corner or a boss's convex base.
    ///
    /// Ground-truthed (`Scripts/repro/762-filleted-pocket-detection/`) that a pocket's fillet.
    ///
    /// AND a boss's base fillet give the IDENTICAL radially-inward signature: both are
    /// reentrant (material-wraps-270-degrees) corners at the sharp-edge level, and a fillet's.
    /// curvature sign reflects only whether it rounds INTO a reentrant corner (either case) or.
    ///
    /// OFF an external one (the box's own exterior edge, radially outward).
    ///
    /// This test.
    /// deliberately does NOT, and structurally cannot, distinguish a pocket's fillet from a.
    /// boss's: that distinction already exists, unchanged, in ``PocketFeature/isOpen``'s
    /// outer-wire-scoped enclosure test (#753). A boss's wall was already a legitimate (if.
    /// unenclosing) member of wallFaceIndices before this fix, for a floor boss standing.
    /// inside a real pocket, and it stays exactly as legitimate, and exactly as correctly.
    /// isOpen, when its own base is filleted.
    private func isRadiallyInwardFillet(_ nodeIndex: Int) -> Bool {
        guard nodeIndex < faceOccurrences.count else { return false }
        let face = faceOccurrences[nodeIndex]
        guard let revolution = face.revolutionProperties,
            let uv = face.uvBounds
        else { return false }
        return AAG.isMaterialRadiallyInward(
            of: face, revolution: revolution, uv: uv, allowSphere: true)
    }

    /// Whether a face's own outward normal, sampled at its own UV mid-parameter, points back.
    /// toward its axis (or, when allowSphere is true and the face is a sphere, its center).
    /// rather than away from it.
    ///
    /// The material-side test shared by ``detectHoles()`` (#747/#760,.
    /// which tells a hole's bore from a boss's or a standalone cylinder's own wall) and.
    /// ``isRadiallyInwardFillet(_:)`` (#762, which asks the identical question of a fillet
    /// junction).
    ///
    /// Factored into one place after review found the two had drifted into.
    /// near-duplicates differing only in sphere handling: `detectHoles()` never needs it
    /// (already gated to `.cylinder`/`.cone` before it gets here), a fillet junction can.
    /// legitimately be spherical (a corner blend). #723 and #747 both already fixed this exact.
    /// test once, on the OTHER copy that existed at the time; a second copy is a second chance.
    /// to miss the next one.
    ///
    /// revolution and uv are taken as parameters rather than recomputed here because both.
    /// callers already have them (`detectHoles()` needs `revolution.axis`/`.radius` and the uv\'s.
    /// own vMin/vMax afterward regardless; `isRadiallyInwardFillet(_:)` needs them to even
    /// know whether to call this at all), so recomputing would be the same duplication moved.
    /// one call frame over rather than removed.
    private static func isMaterialRadiallyInward(
        of face: Face,
        revolution: Face.RevolutionProperties,
        uv: (uMin: Double, uMax: Double, vMin: Double, vMax: Double),
        allowSphere: Bool
    ) -> Bool {
        let uMid = (uv.uMin + uv.uMax) / 2
        let vMid = (uv.vMin + uv.vMax) / 2
        guard let midPoint = face.point(atU: uMid, v: vMid),
            let midNormal = face.normal(atU: uMid, v: vMid)
        else { return false }

        let offset = midPoint - revolution.axis.origin
        let radial: SIMD3<Double>
        if allowSphere, face.surfaceType == .sphere {
            // A sphere has no intrinsic axis direction (primaryAxis still reports one, but
            // it is not a property of the surface); radially-from-center is the only
            // meaningful test.
            radial = offset
        } else {
            let axisUnit = simd_normalize(revolution.axis.direction)
            radial = offset - simd_dot(offset, axisUnit) * axisUnit
        }
        let radialLength = simd_length(radial)
        guard radialLength > 1e-9 else { return false }
        return simd_dot(midNormal, radial / radialLength) < 0
    }

    /// Detect holes (through or blind) in the shape.
    ///
    /// ## What "is a hole" means, under `ChFi3d::DefineConnectType` (#747)
    ///
    /// The original criterion, every neighbor connects via a concave edge, was written.
    /// against a convexity formula (pre-#723) that sometimes misclassified a curved rim as.
    /// concave when it geometrically should not be.
    ///
    /// Under the correct classifier that.
    /// criterion is unsatisfiable for either ordinary hole shape: a through-hole's wall has
    /// **zero** concave neighbors (both rims are convex, the solid occupies 90 degrees.
    /// there, not the 270 that makes an edge concave), and a blind hole's wall has exactly.
    /// **one** out of two (the floor, not the rim where it opens). "All neighbors concave".
    /// can never hold for either, which is why #747 measured zero holes for both.
    ///
    /// A hole is not defined by its neighbors' convexity at all: that only ever describes
    /// the rims where the hole *meets other geometry*, and a through-hole has no such junction.
    /// that is concave.
    ///
    /// What every hole's lateral wall shares, independent of depth, is the.
    /// wall's own intrinsic shape:
    ///
    /// 1. **Cylindrical or conical**, the two developable surface types a drilled or bored.
    ///    feature produces (a conical wall covers a countersink/counterbore transition).
    /// 2. **Closed in U by its own seam.** The wall wraps all the way around its axis, bounded.
    ///    only by rim(s) in V, not by additional edges along U. A partial revolve (an edge.
    ///    fillet is the common example) is bounded by two more edges along U as well, and is.
    ///    not a hole.
    /// 3. **Material lies radially outside the wall, not inside it.** A hole is a void: the
    ///    solid occupies the space between the bore and the surrounding stock, so the face's.
    ///    own outward normal (already corrected for ``Face/orientation``, see.
    ///    ``Face/normal(atU:v:)``) points *back toward the axis*. A boss or a standalone solid
    ///    cylinder is the mirror image of the same topology, same surface type, same closed-.
    ///    in-U shape, sometimes even the same neighbor-convexity signature (a standalone.
    ///    cylinder's wall has zero concave neighbors too), but its material fills the inside,.
    ///    so its normal points *away* from the axis.
    ///
    ///    Nothing about neighbor convexity.
    ///    distinguishes the two; this does, directly, from the wall's own geometry.
    ///
    /// This also does not assume the hole's axis is vertical: it reads the wall's actual axis
    /// (``Face/primaryAxis``) rather than inferring one from a Z-aligned bounding box, which.
    /// the previous aspect-ratio heuristic did implicitly. A pipe's bore is correctly reported.
    /// as a hole by this same rule (material lies radially outside its inner wall), and a.
    /// pipe's outer wall is correctly excluded (material lies radially inside it), a case the.
    /// old formula, keyed off a fixed Z axis and a bounding-box aspect ratio, could not.
    /// distinguish from a first-principles derivation.
    ///
    /// ```swift.
    /// let box  = Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20)!
    /// let tool = Shape.cylinder(at: .zero, direction: SIMD3(0, 0, 1), radius: 4, height: 20)!
    /// let blind = box.subtracting(tool)!.
    /// print(blind.buildAAG().detectHoles().count)   // 1, was 0.
    ///
    /// let tool2 = Shape.cylinder(at: SIMD3(0, 0, -15), direction: SIMD3(0, 0, 1), radius: 4, height: 30)!
    /// let through = box.subtracting(tool2)!.
    /// print(through.buildAAG().detectHoles().count) // 1, was 0.
    /// ```.
    ///
    /// - Note: faceIndex is an **occurrence** index into ``Shape/orientedFaces()``, not
    ///   ``Shape/faces()`` (#642), matching ``AAGNode/faceIndex``. A hole's face is rarely one.
    ///   shared between two solids, so the two indices usually coincide, but they are not the.
    ///   same thing and only the occurrence one is correct here.
    public func detectHoles() -> [(faceIndex: Int, radius: Double, depth: Double)] {
        var holes: [(faceIndex: Int, radius: Double, depth: Double)] = []
        // faceOccurrences, not a fresh shape.orientedFaces(): this loop indexes by node index, and
        // nodes were built from the cached array (#753), which buildGraph() may filter (#943). A
        // re-derived array is only index-aligned with nodes when nothing was filtered, and the
        // cache is what #753 added it for.
        let faces = faceOccurrences

        for index in nodes.indices {
            guard index < faces.count else { continue }
            let face = faces[index]

            // A drilled or bored hole's lateral wall is cylindrical, or conical for a
            // countersink/counterbore transition (#747).
            guard face.surfaceType == .cylinder || face.surfaceType == .cone else { continue }

            // Closed in U: the wall must wrap all the way around its own axis. `uvBounds` is
            // the face's trimmed parameter range (`BRepTools::UVBounds`), and a periodic
            // cylinder/cone is canonically parameterized over a full 2*pi in U; a partial
            // revolve (an edge fillet, a half-pipe) is trimmed to less than that.
            guard let uv = face.uvBounds, uv.uMax - uv.uMin >= 2 * Double.pi - 1e-6 else {
                continue
            }

            guard let revolution = face.revolutionProperties else { continue }
            let axisUnit = simd_normalize(revolution.axis.direction)

            // The material-side test (see isMaterialRadiallyInward's own doc comment, shared
            // with isRadiallyInwardFillet(_:), #762): a hole's own outward normal points back
            // toward the axis, opposite the radial direction. `allowSphere: false` is inert
            // here in practice (this function is already gated to `.cylinder`/`.cone` above,
            // so the surface-type check the sphere branch guards never fires either way) but
            // states plainly that a sphere reaching here would use the axis-projection branch,
            // not the from-center one a spherical fillet junction needs.
            guard
                AAG.isMaterialRadiallyInward(
                    of: face, revolution: revolution, uv: uv, allowSphere: false)
            else {
                continue
            }

            // Depth along the wall's own axis, not a Z-aligned bounding box: works the same
            // for a vertical hole as for one bored on any other axis.
            let uMid = (uv.uMin + uv.uMax) / 2
            guard let low = face.point(atU: uMid, v: uv.vMin),
                let high = face.point(atU: uMid, v: uv.vMax)
            else {
                continue
            }
            let depth = abs(simd_dot(high - low, axisUnit))

            holes.append((faceIndex: index, radius: revolution.radius, depth: depth))
        }

        return holes
    }
}

// MARK: - Shape Extension

extension Shape {
    /// Build an Attributed Adjacency Graph for this shape.
    ///
    /// The graph's nodes are face occurrences (``Shape/orientedFaces()``), not distinct faces.
    /// (``Shape/faces()``): a face shared by two solids in a compound is two nodes, one per owning
    /// solid, each with that solid's own normal.
    ///
    /// See `AAG` for why (#642).
    ///
    /// ```swift.
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let aag = box.buildAAG().
    /// print(aag.nodes.count)   // 6, one per face, nothing shared.
    /// ```.
    public func buildAAG() -> AAG {
        return AAG(shape: self)
    }

    /// Detect pockets using AAG-based feature recognition.
    ///
    /// Selects on each node's ``AAGNode/isUpward``, ``AAGNode/isHorizontal`` and.
    /// ``AAGNode/isPlanar``, which ``buildAAG()`` derives per face occurrence, so the result no.
    /// longer depends on a compound's member order (#642).
    ///
    /// `Shape.box(width:height:depth:)` is centred at the origin, so a 20mm box spans -10...10 on
    /// every axis; the pocket tool's footprint sits under the box's own top and its z range starts.
    /// below it, so the cut actually removes material rather than merely touching the top face.
    /// (#703).
    ///
    /// ```swift.
    /// let box = Shape.box(width: 20, height: 20, depth: 20)!
    /// let pocket = Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15)!
    /// let result = box.subtracting(pocket)!.
    /// print(result.detectPocketsAAG().count)   // 1.
    /// ```.
    ///
    /// - Parameter tolerance: Forwarded to ``AAG/detectPockets(tolerance:)``.
    ///
    /// See its doc for.
    ///   what it controls and why it defaults the way it does (#733).
    /// - Returns: One entry per detected pocket, empty when the shape has none.
    public func detectPocketsAAG(tolerance: Double = AAG.defaultFloorRestsOnWallTolerance)
        -> [PocketFeature]
    {
        let aag = buildAAG()
        return aag.detectPockets(tolerance: tolerance)
    }
}
