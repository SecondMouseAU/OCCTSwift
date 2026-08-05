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
/// - Edges connect adjacent occurrences (those sharing a B-Rep edge), except the two occurrences
///   of one shared face, which are never linked to each other
/// - Each graph edge is attributed with convexity information
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
    /// Index of the floor face
    public let floorFaceIndex: Int

    /// Indices of the wall faces
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
    /// ```swift
    /// let box = Shape.box(width: 20, height: 20, depth: 20)!
    /// let pocket = Shape.box(origin: SIMD3(5, 5, 10), width: 10, height: 10, depth: 15)!
    /// let result = box.subtracting(pocket)!
    /// print(result.detectPocketsAAG().count)   // 1
    /// ```
    public func detectPocketsAAG() -> [PocketFeature] {
        let aag = buildAAG()
        return aag.detectPockets()
    }
}
