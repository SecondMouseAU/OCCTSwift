import Foundation
import simd
import OCCTBridge

// MARK: - Edge Convexity

/// Classification of the dihedral angle at an edge between two faces
public enum EdgeConvexity: Int32, Sendable {
    case concave = -1   // Interior angle > 180° (pocket-like, going inward)
    case smooth = 0     // Tangent faces (~180°)
    case convex = 1     // Interior angle < 180° (fillet-like, going outward)

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
/// `AAG` builds its node set from ``Shape/orientedFaces()``, not ``Shape/faces()`` (#642): a face
/// shared by two solids in a compound, the ordinary result of a split, appears as **two**
/// nodes, one per owning solid, each carrying the normal and derived predicates (`isHorizontal`,
/// `isUpward`, `isDownward`, `isVertical`, `zLevel`) that solid's own orientation produces. On any
/// shape whose faces are not shared this is exactly the node set `faces()` would have produced, in
/// the same order.
public struct AAGNode: Sendable {
    /// This node's position in the graph, the index every `AAG` method (``AAG/neighbors(of:)``,
    /// ``AAG/edge(between:and:)``, ``AAG/concaveNeighbors(of:)``, ``AAG/convexNeighbors(of:)``)
    /// takes and returns. An **occurrence** index into ``Shape/orientedFaces()``, not a distinct
    /// face index: two nodes can share the same underlying face (see ``distinctFaceIndex``).
    public let faceIndex: Int

    /// This occurrence's underlying face, its position in ``Shape/faces()``, the deduplicated
    /// enumeration.
    ///
    /// Two nodes with the same `distinctFaceIndex` are the two sides of one shared face (a wall
    /// between two solids in a compound): same geometry, opposite orientation, opposed normals.
    /// `AAG` does not build a graph edge between such a pair: sharing every boundary edge with
    /// itself is not adjacency, it is identity. On a shape whose faces are not shared, every node
    /// has a distinct `distinctFaceIndex`, equal to its `faceIndex`.
    public let distinctFaceIndex: Int

    /// Face normal at center (if computable)
    public let normal: SIMD3<Double>?

    /// Whether face is planar
    public let isPlanar: Bool

    /// Whether face is horizontal (normal points up or down)
    public let isHorizontal: Bool

    /// Whether face is upward-facing
    public let isUpward: Bool

    /// Whether face is downward-facing
    public let isDownward: Bool

    /// Whether face is vertical
    public let isVertical: Bool

    /// Z level if horizontal planar face
    public let zLevel: Double?

    /// Bounding box of the face
    public let bounds: (min: SIMD3<Double>, max: SIMD3<Double>)
}

/// An edge in the Attributed Adjacency Graph representing adjacency between two faces
public struct AAGEdge: Sendable {
    /// Index of first adjacent face
    public let face1Index: Int

    /// Index of second adjacent face
    public let face2Index: Int

    /// Convexity classification of the shared edge(s)
    public let convexity: EdgeConvexity

    /// Number of shared edges between the faces
    public let sharedEdgeCount: Int
}

/// Attributed Adjacency Graph for feature recognition
///
/// The AAG represents the topology of a shape as a graph where:
/// - Nodes are face **occurrences** (``Shape/orientedFaces()``, #642). A face shared between two
///   solids in a compound is two nodes, one per owning solid, each with that solid's own normal
///   and derived predicates
/// - Edges connect adjacent occurrences (those sharing a B-Rep edge) **within the same solid**
///   (#699), except the two occurrences of one shared face, which are never linked to each other
/// - Each graph edge is attributed with convexity information
///
/// ## Adjacency is scoped to one solid (#699)
///
/// Two occurrences sharing a B-Rep edge but belonging to different solids in a compound are
/// adjacent *in the compound* and not adjacent in *either* solid: a floor face's candidate walls
/// are the faces bounding the same body, not any face anywhere in the compound that happens to
/// touch the same edge locus. Neither `OCCTFacesAreAdjacent` nor `OCCTEdgeGetConvexity` has any
/// notion of solid membership on their own, so `buildGraph()` restricts which occurrence pairs it
/// hands to them, using `Shape.solids` and `orientedFaces()`'s own traversal order rather than a
/// new bridge entry point (see `AAG.solidGroups(occurrenceCount:in:)`'s doc comment for the derivation). On a
/// shape with zero or one solid, including every single-solid shape, this changes nothing: there
/// is no cross-solid pair to restrict.
///
/// ## Node identity (#642)
///
/// An earlier version built nodes from ``Shape/faces()``, the deduplicated enumeration that keeps
/// only the first orientation a shared face is reached in. `AAGNode.isUpward`/`isHorizontal`/etc.
/// are derived from the node's normal, so which orientation survived the dedup silently decided
/// the answer: the same compound, compounded in the opposite member order, produced a different
/// node set and therefore a different ``detectPockets()`` result for identical geometry. Building
/// from ``Shape/orientedFaces()`` instead keeps both sides of a shared face as their own node, so
/// the graph, and everything that reads it, no longer depends on compound member order.
///
/// Two other approaches were considered and rejected:
/// - **One node per distinct face, carrying both normals.** Preserves the old index model, but
///   every normal-derived predicate becomes two-valued and every caller of `isUpward`/
///   `isHorizontal`/etc. has to say which side it means. That pushes the ambiguity onto every
///   consumer instead of resolving it once, in the graph.
/// - **Restrict `AAG` to single-solid input and document the limitation.** Legitimate only if AAG
///   is never meaningful across solids, which was not established, and it would not fix anything
///   for the multi-solid case: it would just make the wrong answer a documented one.
///
/// ```swift
/// let box = Shape.box(width: 10, height: 10, depth: 10)!
/// let halves = box.split(atPlane: SIMD3(0, 0, 4), normal: SIMD3(0, 0, 1))!
///
/// // Same geometry, opposite compound member order.
/// let orderA = Shape.compound(halves)!
/// let orderB = Shape.compound(halves.reversed())!
///
/// // Order-independent: both sides of the shared wall are their own node either way.
/// print(orderA.detectPocketsAAG().count == orderB.detectPocketsAAG().count)   // true
/// ```
public final class AAG: @unchecked Sendable {
    /// The shape this graph represents
    public let shape: Shape

    /// All nodes (faces) in the graph
    public private(set) var nodes: [AAGNode] = []

    /// All edges (adjacencies) in the graph
    public private(set) var edges: [AAGEdge] = []

    /// Adjacency list: for each face index, list of (neighbor index, edge index)
    public private(set) var adjacencyList: [[Int: Int]] = []

    /// Create an AAG from a shape
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
        let faces = shape.orientedFaces()
        let faceCount = faces.count

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
                bounds: face.bounds
            )
            nodes.append(node)
        }

        // #699: which solid each occurrence belongs to, so the pairwise loop below never asks
        // OCCTFacesAreAdjacent/OCCTEdgeGetConvexity about two faces from different solids. Neither
        // bridge function has any notion of solid membership -- both compare face1/face2 purely on
        // their own edge geometry, ignoring the `shape` argument beyond a null check -- so on a
        // vertical cut, the two top-face halves (which border each other along the cut line) and
        // each half's own side of the shared wall were being compared cross-solid as well as
        // within their own solid, on top of the correct same-solid adjacencies.
        let groups = Self.solidGroups(occurrenceCount: faces.count, in: shape)

        // Build edges by checking all face pairs for adjacency
        for i in 0..<faceCount {
            for j in (i+1)..<faceCount {
                let face1 = faces[i]
                let face2 = faces[j]

                // The two occurrences of one shared face are not neighbors of each other: they
                // are the same face, so every one of their boundary edges is "shared" with
                // itself. Without this guard OCCTFacesAreAdjacent (which compares edge sets by
                // IsSame, ignoring orientation) reports a self-loop for every shared face.
                guard face1.index != face2.index else { continue }

                // #699: two occurrences in different solids are adjacent in the compound and not
                // in either solid; AAG's consumers (detectPockets(), concaveNeighbors(), etc.) want
                // the latter. `group` is nil when solid membership could not be established (a
                // single-solid shape, or a shape whose occurrence count didn't partition cleanly by
                // solid), in which case every pair is compared exactly as before #699.
                if let groups, groups[i] != groups[j] { continue }

                // Check if adjacent
                if OCCTFacesAreAdjacent(shape.handle, face1.handle, face2.handle) {
                    // Get shared edge count and convexity
                    var sharedEdges: [OCCTEdgeRef?] = Array(repeating: nil, count: 10)
                    let edgeCount = OCCTFaceGetSharedEdges(
                        shape.handle, face1.handle, face2.handle,
                        &sharedEdges, 10
                    )

                    // Get convexity from first shared edge
                    var convexity: EdgeConvexity = .smooth
                    if edgeCount > 0, let firstEdge = sharedEdges[0] {
                        let occtConvexity = OCCTEdgeGetConvexity(
                            shape.handle, firstEdge,
                            face1.handle, face2.handle
                        )
                        convexity = EdgeConvexity(fromOCCT: occtConvexity)

                        // Release edges
                        for k in 0..<Int(edgeCount) {
                            if let edge = sharedEdges[k] {
                                OCCTEdgeRelease(edge)
                            }
                        }
                    }

                    let edgeIndex = edges.count
                    let edge = AAGEdge(
                        face1Index: i,
                        face2Index: j,
                        convexity: convexity,
                        sharedEdgeCount: Int(edgeCount)
                    )
                    edges.append(edge)

                    // Update adjacency list (bidirectional)
                    adjacencyList[i][j] = edgeIndex
                    adjacencyList[j][i] = edgeIndex
                }
            }
        }
    }

    /// Which solid each entry of `occurrences` (``Shape/orientedFaces()``, in order) belongs to,
    /// or `nil` if solid membership can't be established for this shape (#699).
    ///
    /// Returns one group id per occurrence, two occurrences sharing a group id if and only if they
    /// belong to the same solid. The ids are arbitrary integers, not ``Shape/solids``'s own
    /// indices, and callers should compare them for equality only.
    ///
    /// There is no bridge entry point that answers "which solid owns this face occurrence"
    /// directly, and this deliberately does not add one: `OCCTShapeGetOrientedFaces`, the walk
    /// `orientedFaces()` already runs, visits every occurrence under one top-level solid
    /// contiguously before moving to the next, because it is driven by the same single
    /// `TopExp_Explorer` descent that ``Shape/solids`` itself uses to enumerate solids in
    /// first-encountered order (both are one DFS over the same shape, filtered to a different
    /// target type). So the flat occurrence list partitions into contiguous runs whose lengths are
    /// each solid's own face-occurrence count, with no need to match individual faces back to a
    /// solid by identity. Confirmed against both the vertical- and horizontal-cut two-solid
    /// fixtures in `Scripts/repro/cluster-a-subshape-enumeration` before relying on it here, not
    /// assumed from the traversal's documented behavior alone.
    ///
    /// `nil` covers two cases deliberately treated the same: a shape with zero or one solid (no
    /// cross-solid pair can exist, so nothing needs restricting), and a shape whose per-solid
    /// occurrence counts don't sum to the total occurrence count (a compound mixing solids with
    /// free shells/faces, or a future shape this partitioning assumption doesn't hold for). Either
    /// way, `buildGraph()` falls back to comparing every pair, exactly as it did before #699.
    ///
    /// Note what that sum check does and does not buy. It is necessary, not sufficient: it confirms
    /// the totals line up, not that each solid's occurrences are actually contiguous or that
    /// `Shape.solids` enumerates solids in the same order the face walk meets them. Those hold
    /// because both are `TopExp_Explorer` walks over one shape tree, which is a structural property
    /// of the traversal rather than something checked at runtime. A future topology that broke it
    /// while still summing correctly would mis-partition silently. That is an unenforced cross-API
    /// invariant, validated empirically on the fixtures in `Issue699AAGSolidScopedAdjacencyTests`,
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

    /// Get neighbors of a face
    public func neighbors(of faceIndex: Int) -> [Int] {
        guard faceIndex < adjacencyList.count else { return [] }
        return Array(adjacencyList[faceIndex].keys)
    }

    /// Get the edge between two faces (if adjacent)
    public func edge(between face1: Int, and face2: Int) -> AAGEdge? {
        guard face1 < adjacencyList.count else { return nil }
        guard let edgeIndex = adjacencyList[face1][face2] else { return nil }
        return edges[edgeIndex]
    }

    /// Get all concave neighbors of a face
    public func concaveNeighbors(of faceIndex: Int) -> [Int] {
        guard faceIndex < adjacencyList.count else { return [] }
        return adjacencyList[faceIndex].compactMap { (neighbor, edgeIndex) in
            edges[edgeIndex].convexity == .concave ? neighbor : nil
        }
    }

    /// Get all convex neighbors of a face
    public func convexNeighbors(of faceIndex: Int) -> [Int] {
        guard faceIndex < adjacencyList.count else { return [] }
        return adjacencyList[faceIndex].compactMap { (neighbor, edgeIndex) in
            edges[edgeIndex].convexity == .convex ? neighbor : nil
        }
    }
}

// MARK: - Pocket Feature

/// A recognized pocket feature in a solid
public struct PocketFeature: Sendable {
    /// Index of the floor face.
    ///
    /// An **occurrence** index, the same one ``AAGNode/faceIndex`` uses, so it resolves against
    /// ``Shape/orientedFaces()`` and **not** ``Shape/faces()`` (#642). Before #642 it indexed
    /// `faces()`; on a compound whose solids share a face the two differ, and indexing `faces()`
    /// with it now gives the wrong face or runs off the end. To recover the distinct-face index,
    /// read `aag.nodes[pocket.floorFaceIndex].distinctFaceIndex`.
    ///
    /// ```swift
    /// let aag = shape.buildAAG()
    /// for pocket in shape.detectPocketsAAG() {
    ///     let floor = shape.orientedFaces()[pocket.floorFaceIndex]   // correct
    ///     let distinct = aag?.nodes[pocket.floorFaceIndex].distinctFaceIndex
    ///     print(floor.area, distinct as Any)
    /// }
    /// ```
    public let floorFaceIndex: Int

    /// Indices of the wall faces.
    ///
    /// **Occurrence** indices into ``Shape/orientedFaces()``, on the same footing as
    /// ``floorFaceIndex`` (#642).
    public let wallFaceIndices: [Int]

    /// Z level of the pocket floor
    public let zLevel: Double

    /// Bounding box of the pocket
    public let bounds: (min: SIMD3<Double>, max: SIMD3<Double>)

    /// Whether this is an open pocket (not fully enclosed)
    public let isOpen: Bool

    /// Approximate depth of the pocket
    public var depth: Double {
        bounds.max.z - zLevel
    }
}

// MARK: - Feature Recognition Extensions

extension AAG {
    /// Detect pockets in the shape using AAG analysis
    ///
    /// A pocket is identified by:
    /// 1. An upward-facing horizontal floor face
    /// 2. Surrounded by vertical wall faces
    /// 3. Connected to walls via concave edges
    public func detectPockets() -> [PocketFeature] {
        var pockets: [PocketFeature] = []

        // Find all upward-facing horizontal faces as potential floors
        let potentialFloors = nodes.enumerated().filter { _, node in
            node.isUpward && node.isHorizontal && node.isPlanar
        }

        for (floorIndex, floorNode) in potentialFloors {
            guard let floorZ = floorNode.zLevel else { continue }

            // Get concave neighbors (these should be walls)
            let concaveNeighbors = self.concaveNeighbors(of: floorIndex)

            // Filter to vertical faces only
            let wallIndices = concaveNeighbors.filter { neighborIndex in
                nodes[neighborIndex].isVertical
            }

            // Need at least one wall to be a pocket
            guard !wallIndices.isEmpty else { continue }

            // Calculate pocket bounds from floor and walls
            var minX = floorNode.bounds.min.x
            var minY = floorNode.bounds.min.y
            var maxX = floorNode.bounds.max.x
            var maxY = floorNode.bounds.max.y
            var maxZ = floorZ

            for wallIndex in wallIndices {
                let wallBounds = nodes[wallIndex].bounds
                minX = min(minX, wallBounds.min.x)
                minY = min(minY, wallBounds.min.y)
                maxX = max(maxX, wallBounds.max.x)
                maxY = max(maxY, wallBounds.max.y)
                maxZ = max(maxZ, wallBounds.max.z)
            }

            // Check if pocket is closed (all walls connected to each other form a loop)
            // For now, consider it open if it has fewer than 3 walls
            let isOpen = wallIndices.count < 3

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

    /// Detect holes (through or blind) in the shape
    ///
    /// A hole is identified by:
    /// 1. A cylindrical or conical face
    /// 2. With concave edges connecting to other faces
    ///
    /// - Note: `faceIndex` is an **occurrence** index into ``Shape/orientedFaces()``, not
    ///   ``Shape/faces()`` (#642), matching ``AAGNode/faceIndex``. A hole's face is rarely one
    ///   shared between two solids, so the two indices usually coincide, but they are not the
    ///   same thing and only the occurrence one is correct here.
    public func detectHoles() -> [(faceIndex: Int, radius: Double, depth: Double)] {
        var holes: [(faceIndex: Int, radius: Double, depth: Double)] = []

        // Find cylindrical faces that are holes (all edges are concave)
        for (index, node) in nodes.enumerated() {
            // Check if all neighbors are connected via concave edges
            let allNeighbors = neighbors(of: index)
            let concaveNeighbors = self.concaveNeighbors(of: index)

            // If all adjacencies are concave, this might be a hole
            guard allNeighbors.count == concaveNeighbors.count && allNeighbors.count >= 1 else {
                continue
            }

            // For now, use bounds to estimate if circular
            let width = node.bounds.max.x - node.bounds.min.x
            let height = node.bounds.max.y - node.bounds.min.y
            let depth = node.bounds.max.z - node.bounds.min.z

            // Check if roughly circular in XY (for vertical holes)
            let aspectRatio = max(width, height) / min(width, height)
            if aspectRatio < 1.2 && !node.isPlanar {
                let radius = (width + height) / 4.0
                holes.append((faceIndex: index, radius: radius, depth: depth))
            }
        }

        return holes
    }
}

// MARK: - Shape Extension

extension Shape {
    /// Build an Attributed Adjacency Graph for this shape.
    ///
    /// The graph's nodes are face occurrences (``Shape/orientedFaces()``), not distinct faces
    /// (``Shape/faces()``): a face shared by two solids in a compound is two nodes, one per owning
    /// solid, each with that solid's own normal. See ``AAG`` for why (#642).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let aag = box.buildAAG()
    /// print(aag.nodes.count)   // 6, one per face, nothing shared
    /// ```
    public func buildAAG() -> AAG {
        return AAG(shape: self)
    }

    /// Detect pockets using AAG-based feature recognition.
    ///
    /// Selects on each node's ``AAGNode/isUpward``, ``AAGNode/isHorizontal`` and
    /// ``AAGNode/isPlanar``, which ``buildAAG()`` derives per face occurrence, so the result no
    /// longer depends on a compound's member order (#642).
    ///
    /// `Shape.box(width:height:depth:)` is centred at the origin, so a 20mm box spans -10...10 on
    /// every axis; the pocket tool's footprint sits under the box's own top and its z range starts
    /// below it, so the cut actually removes material rather than merely touching the top face
    /// (#703).
    ///
    /// ```swift
    /// let box = Shape.box(width: 20, height: 20, depth: 20)!
    /// let pocket = Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15)!
    /// let result = box.subtracting(pocket)!
    /// print(result.detectPocketsAAG().count)   // 1
    /// ```
    public func detectPocketsAAG() -> [PocketFeature] {
        let aag = buildAAG()
        return aag.detectPockets()
    }
}
