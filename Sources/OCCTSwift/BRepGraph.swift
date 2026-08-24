//
//  BRepGraph.swift
//  OCCTSwift
//
//  Graph-based B-Rep topology representation (OCCT BRepGraph)
//

import Foundation
import OCCTBridge

/// A graph-based representation of B-Rep topology.
///
/// `BRepGraph` provides cache-friendly traversal, O(1) upward navigation,
/// and parallel geometry extraction over a shape's topology. Built from a
/// `Shape`, it indexes all faces, edges, vertices, wires, shells, and solids
/// as flat entity vectors with integer cross-references.
///
/// ```swift
/// let box = Shape.box(width: 10, height: 10, depth: 10)
/// let graph = BRepGraph(shape: box)!
/// print(graph.stats)  // faces: 6, edges: 12, vertices: 8
///
/// // Fast adjacency queries
/// let neighbors = graph.adjacentFaces(of: 0)  // [1, 2, 3, 4]
/// let shared = graph.sharedEdges(between: 0, and: 1)  // [3]
/// ```
public final class BRepGraph: @unchecked Sendable {
    internal let handle: OCCTBRepGraphRef

    /// Per-node attribute store (see `BRepGraph+Attributes.swift`).
    ///
    /// Holds arbitrary typed metadata keyed by ``NodeRef`` — fit residuals, provenance,
    /// mesh-region sets, etc. Pure Swift sidecar; never touches the underlying C++ graph.
    /// Serialized via ``snapshot()`` / ``init(snapshot:)``.
    public var attributes = NodeAttributeStore()

    /// BREP of the shape this graph was built from, captured at construction.
    ///
    /// Used by ``snapshot()`` so a session can be reconstructed exactly. `nil` only if the
    /// shape failed to serialize. Reflects the shape as built; topology-mutating builder ops
    /// after construction are not re-captured here (rebuild the graph to re-snapshot).
    internal var sourceBREP: String?

    /// Build a topology graph from a shape.
    /// - Parameters:
    ///   - shape: The shape to analyze.
    ///   - parallel: Whether to build using parallel threads (default: false).
    public init?(shape: Shape, parallel: Bool = false) {
        guard let h = OCCTBRepGraphCreate(shape.handle, parallel) else { return nil }
        self.handle = h
        self.sourceBREP = shape.toBREPString()
    }

    deinit {
        OCCTBRepGraphRelease(handle)
    }

    // MARK: - Internal Helpers

    /// Shared count-then-fetch helper for the bridge's `...Count`/`...Indices` accessor pairs.
    ///
    /// Every adjacency/relation query (`adjacentFaces(of:)`, `sharedEdges(between:and:)`,
    /// `edgeWires(_:)`, `rootProductIndices`, etc.) allocates an `Int32` buffer sized by a
    /// prior count call, fills it via a bridge `...Indices` function, then maps back to
    /// `[Int]`. `fetch` receives the buffer's base address to call the bridge function with.
    ///
    /// Guards `count <= 0`, not just `count == 0`: the underlying bridge `...Count` functions
    /// derive their result via an unchecked narrowing `(int32_t)` cast from a `size_t`, so a
    /// sufficiently large (theoretical) graph could produce a negative count. Without this
    /// guard, `[Int32](repeating:count:)` would trap; with it, a negative count degrades to
    /// `[]` like an empty result.
    private func fetchIndices(count: Int, fetch: (UnsafeMutablePointer<Int32>) -> Void) -> [Int] {
        guard count > 0 else { return [] }
        var indices = [Int32](repeating: 0, count: count)
        indices.withUnsafeMutableBufferPointer { buf in
            fetch(buf.baseAddress!)
        }
        return indices.map { Int($0) }
    }

    // MARK: - Topology Counts

    /// Total number of nodes in the graph (all entity kinds).
    public var nodeCount: Int { Int(OCCTBRepGraphNbNodes(handle)) }

    /// Number of faces.
    public var faceCount: Int { Int(OCCTBRepGraphNbFaces(handle)) }
    /// Number of active (non-removed) faces.
    public var activeFaceCount: Int { Int(OCCTBRepGraphNbActiveFaces(handle)) }
    /// Number of edges.
    public var edgeCount: Int { Int(OCCTBRepGraphNbEdges(handle)) }
    /// Number of active edges.
    public var activeEdgeCount: Int { Int(OCCTBRepGraphNbActiveEdges(handle)) }
    /// Number of vertices.
    public var vertexCount: Int { Int(OCCTBRepGraphNbVertices(handle)) }
    /// Number of active vertices.
    public var activeVertexCount: Int { Int(OCCTBRepGraphNbActiveVertices(handle)) }
    /// Number of wires.
    public var wireCount: Int { Int(OCCTBRepGraphNbWires(handle)) }
    /// Number of shells.
    public var shellCount: Int { Int(OCCTBRepGraphNbShells(handle)) }
    /// Number of solids.
    public var solidCount: Int { Int(OCCTBRepGraphNbSolids(handle)) }
    /// Number of coedges (half-edges).
    public var coedgeCount: Int { Int(OCCTBRepGraphNbCoEdges(handle)) }
    /// Number of compounds.
    public var compoundCount: Int { Int(OCCTBRepGraphNbCompounds(handle)) }

    // MARK: - Geometry Counts

    /// Number of distinct surfaces.
    public var surfaceCount: Int { Int(OCCTBRepGraphNbSurfaces(handle)) }
    /// Number of distinct 3D curves.
    public var curve3DCount: Int { Int(OCCTBRepGraphNbCurves3D(handle)) }
    /// Number of distinct 2D curves.
    public var curve2DCount: Int { Int(OCCTBRepGraphNbCurves2D(handle)) }

    // MARK: - Face Queries

    /// Indices of faces adjacent to a given face (sharing an edge).
    public func adjacentFaces(of faceIndex: Int) -> [Int] {
        let count = Int(OCCTBRepGraphFaceAdjacentCount(handle, Int32(faceIndex)))
        return fetchIndices(count: count) { buf in
            OCCTBRepGraphFaceAdjacentIndices(handle, Int32(faceIndex), buf)
        }
    }

    /// Indices of edges shared between two faces.
    public func sharedEdges(between faceA: Int, and faceB: Int) -> [Int] {
        let count = Int(OCCTBRepGraphFaceSharedEdgeCount(handle, Int32(faceA), Int32(faceB)))
        return fetchIndices(count: count) { buf in
            OCCTBRepGraphFaceSharedEdgeIndices(handle, Int32(faceA), Int32(faceB), buf)
        }
    }

    /// Index of the outer wire of a face.
    public func outerWire(of faceIndex: Int) -> Int {
        Int(OCCTBRepGraphFaceOuterWire(handle, Int32(faceIndex)))
    }

    // MARK: - Edge Queries

    /// Number of faces an edge belongs to.
    public func faceCount(of edgeIndex: Int) -> Int {
        Int(OCCTBRepGraphEdgeNbFaces(handle, Int32(edgeIndex)))
    }

    /// Indices of faces an edge belongs to.
    public func faces(of edgeIndex: Int) -> [Int] {
        fetchIndices(count: faceCount(of: edgeIndex)) { buf in
            OCCTBRepGraphEdgeFaceIndices(handle, Int32(edgeIndex), buf)
        }
    }

    /// Whether an edge is a boundary edge (belongs to only one face).
    public func isBoundaryEdge(_ edgeIndex: Int) -> Bool {
        OCCTBRepGraphEdgeIsBoundary(handle, Int32(edgeIndex))
    }

    /// Whether an edge is manifold (belongs to exactly two faces).
    public func isManifoldEdge(_ edgeIndex: Int) -> Bool {
        OCCTBRepGraphEdgeIsManifold(handle, Int32(edgeIndex))
    }

    /// Indices of edges adjacent to a given edge (sharing a vertex).
    public func adjacentEdges(of edgeIndex: Int) -> [Int] {
        let count = Int(OCCTBRepGraphEdgeAdjacentCount(handle, Int32(edgeIndex)))
        return fetchIndices(count: count) { buf in
            OCCTBRepGraphEdgeAdjacentIndices(handle, Int32(edgeIndex), buf)
        }
    }

    // MARK: - Vertex Queries

    /// Indices of edges connected to a vertex.
    public func edges(of vertexIndex: Int) -> [Int] {
        let count = Int(OCCTBRepGraphVertexEdgeCount(handle, Int32(vertexIndex)))
        return fetchIndices(count: count) { buf in
            OCCTBRepGraphVertexEdgeIndices(handle, Int32(vertexIndex), buf)
        }
    }

    // MARK: - Explorers

    /// Node kind enumeration matching OCCT BRepGraph_NodeId::Kind.
    ///
    /// Topology kinds 0–5 are core hierarchy; 6/7 are containers; 8 is the
    /// face-context coedge entity. Assembly kinds (Product, Occurrence) start
    /// at 10, leaving slot 9 reserved for future topology extension.
    public enum NodeKind: Int32, Sendable, Codable {
        case solid = 0
        case shell = 1
        case face = 2
        case wire = 3
        case edge = 4
        case vertex = 5
        case compound = 6
        case compSolid = 7
        case coedge = 8
        case product = 10
        case occurrence = 11
    }

    /// Count descendant nodes of a given kind from a root node.
    public func childCount(rootKind: NodeKind, rootIndex: Int, targetKind: NodeKind) -> Int {
        Int(
            OCCTBRepGraphChildCount(
                handle, rootKind.rawValue, Int32(rootIndex), targetKind.rawValue))
    }

    /// Count parent nodes of a given node.
    public func parentCount(nodeKind: NodeKind, nodeIndex: Int) -> Int {
        Int(OCCTBRepGraphParentCount(handle, nodeKind.rawValue, Int32(nodeIndex)))
    }

    // MARK: - Node Status

    /// Check if a node has been soft-removed.
    public func isRemoved(nodeKind: NodeKind, nodeIndex: Int) -> Bool {
        OCCTBRepGraphIsRemoved(handle, nodeKind.rawValue, Int32(nodeIndex))
    }

    // MARK: - Root Nodes

    /// Root node as (kind, index) pair.
    public struct RootNode: Sendable {
        public let kind: NodeKind
        public let index: Int
    }

    /// Root nodes of the graph.
    public var rootNodes: [RootNode] {
        let count = Int(OCCTBRepGraphRootCount(handle))
        if count == 0 { return [] }
        var kinds = [Int32](repeating: 0, count: count)
        var indices = [Int32](repeating: 0, count: count)
        kinds.withUnsafeMutableBufferPointer { kBuf in
            indices.withUnsafeMutableBufferPointer { iBuf in
                OCCTBRepGraphRootNodes(handle, kBuf.baseAddress!, iBuf.baseAddress!)
            }
        }
        return (0..<count).compactMap { i in
            guard let kind = NodeKind(rawValue: kinds[i]) else { return nil }
            return RootNode(kind: kind, index: Int(indices[i]))
        }
    }

    // MARK: - Validate

    /// Validation result.
    public struct ValidationResult: Sendable {
        public let isValid: Bool
        public let errorCount: Int
        public let warningCount: Int
    }

    /// Validate the graph structure.
    public func validate() -> ValidationResult {
        let r = OCCTBRepGraphValidateDetailed(handle)
        return ValidationResult(
            isValid: r.isValid,
            errorCount: Int(r.errorCount),
            warningCount: Int(r.warningCount))
    }

    /// Whether the graph is structurally valid.
    public var isValid: Bool { OCCTBRepGraphValidate(handle) }

    // MARK: - Compact

    /// Compaction result.
    public struct CompactResult: Sendable {
        public let removedVertices: Int
        public let removedEdges: Int
        public let removedFaces: Int
        public let nodesAfter: Int
    }

    /// Compact the graph by removing unreferenced nodes.
    @discardableResult
    public func compact() -> CompactResult {
        let r = OCCTBRepGraphCompact(handle)
        return CompactResult(
            removedVertices: Int(r.removedVertices),
            removedEdges: Int(r.removedEdges),
            removedFaces: Int(r.removedFaces),
            nodesAfter: Int(r.nodesAfter))
    }

    // MARK: - Deduplicate

    /// Deduplication result.
    public struct DeduplicateResult: Sendable {
        public let canonicalSurfaces: Int
        public let canonicalCurves: Int
        public let surfaceRewrites: Int
        public let curveRewrites: Int
    }

    /// Deduplicate shared geometry in the graph.
    @discardableResult
    public func deduplicate() -> DeduplicateResult {
        let r = OCCTBRepGraphDeduplicate(handle)
        return DeduplicateResult(
            canonicalSurfaces: Int(r.canonicalSurfaces),
            canonicalCurves: Int(r.canonicalCurves),
            surfaceRewrites: Int(r.surfaceRewrites),
            curveRewrites: Int(r.curveRewrites))
    }

    // MARK: - Statistics

    /// Comprehensive graph statistics.
    public struct Stats: Sendable, CustomStringConvertible {
        public let solids: Int
        public let shells: Int
        public let faces: Int
        public let wires: Int
        public let edges: Int
        public let vertices: Int
        public let coedges: Int
        public let compounds: Int
        public let totalNodes: Int
        public let surfaces: Int
        public let curves3D: Int
        public let curves2D: Int

        public var description: String {
            "BRepGraph.Stats(solids: \(solids), shells: \(shells), faces: \(faces), "
                + "wires: \(wires), edges: \(edges), vertices: \(vertices), coedges: \(coedges), "
                + "nodes: \(totalNodes), surfaces: \(surfaces), curves3D: \(curves3D), curves2D: \(curves2D))"
        }
    }

    /// Get comprehensive graph statistics.
    public var stats: Stats {
        let s = OCCTBRepGraphGetStats(handle)
        return Stats(
            solids: Int(s.solids), shells: Int(s.shells), faces: Int(s.faces),
            wires: Int(s.wires), edges: Int(s.edges), vertices: Int(s.vertices),
            coedges: Int(s.coedges), compounds: Int(s.compounds),
            totalNodes: Int(s.totalNodes), surfaces: Int(s.surfaces),
            curves3D: Int(s.curves3d), curves2D: Int(s.curves2d))
    }

    // MARK: - Shape Reconstruction (v0.133.0)

    /// Reconstruct a TopoDS_Shape from a graph node.
    public func shape(nodeKind: NodeKind, nodeIndex: Int) -> Shape? {
        guard let ref = OCCTBRepGraphShapeFromNode(handle, nodeKind.rawValue, Int32(nodeIndex))
        else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Find the node (kind, index) for a shape.
    ///
    /// Returns nil if not found.
    public func findNode(for shape: Shape) -> (kind: NodeKind, index: Int)? {
        var outKind: Int32 = -1
        var outIndex: Int32 = -1
        OCCTBRepGraphFindNode(handle, shape.handle, &outKind, &outIndex)
        if outKind < 0 { return nil }
        guard let kind = NodeKind(rawValue: outKind) else { return nil }
        return (kind: kind, index: Int(outIndex))
    }

    /// Check if a shape is known to the graph.
    public func hasNode(for shape: Shape) -> Bool {
        OCCTBRepGraphHasNode(handle, shape.handle)
    }

    // MARK: - Vertex Geometry (v0.133.0)

    /// Get the 3D point of a vertex.
    public func vertexPoint(_ vertexIndex: Int) -> (x: Double, y: Double, z: Double) {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        OCCTBRepGraphVertexPoint(handle, Int32(vertexIndex), &x, &y, &z)
        return (x, y, z)
    }

    /// Get the tolerance of a vertex.
    public func vertexTolerance(_ vertexIndex: Int) -> Double {
        OCCTBRepGraphVertexTolerance(handle, Int32(vertexIndex))
    }

    // MARK: - Edge Geometry (v0.133.0)

    /// Get the tolerance of an edge.
    public func edgeTolerance(_ edgeIndex: Int) -> Double {
        OCCTBRepGraphEdgeTolerance(handle, Int32(edgeIndex))
    }

    /// Check if an edge is degenerated.
    public func isEdgeDegenerated(_ edgeIndex: Int) -> Bool {
        OCCTBRepGraphEdgeIsDegenerated(handle, Int32(edgeIndex))
    }

    /// Check if an edge has the SameParameter flag.
    public func isEdgeSameParameter(_ edgeIndex: Int) -> Bool {
        OCCTBRepGraphEdgeIsSameParameter(handle, Int32(edgeIndex))
    }

    /// Check if an edge has the SameRange flag.
    public func isEdgeSameRange(_ edgeIndex: Int) -> Bool {
        OCCTBRepGraphEdgeIsSameRange(handle, Int32(edgeIndex))
    }

    /// Get the parameter range of an edge.
    public func edgeRange(_ edgeIndex: Int) -> (first: Double, last: Double) {
        var first = 0.0
        var last = 0.0
        OCCTBRepGraphEdgeRange(handle, Int32(edgeIndex), &first, &last)
        return (first, last)
    }

    /// Check if an edge has a 3D curve.
    public func edgeHasCurve(_ edgeIndex: Int) -> Bool {
        OCCTBRepGraphEdgeHasCurve(handle, Int32(edgeIndex))
    }

    /// Check if an edge is a seam (closed) on a face.
    public func isEdgeClosedOnFace(edgeIndex: Int, faceIndex: Int) -> Bool {
        OCCTBRepGraphEdgeIsClosedOnFace(handle, Int32(edgeIndex), Int32(faceIndex))
    }

    /// Check if an edge has a 3D polygon.
    public func edgeHasPolygon3D(_ edgeIndex: Int) -> Bool {
        OCCTBRepGraphEdgeHasPolygon3D(handle, Int32(edgeIndex))
    }

    /// Get the maximum continuity order of an edge (GeomAbs_Shape enum as Int).
    public func edgeMaxContinuity(_ edgeIndex: Int) -> Int {
        Int(OCCTBRepGraphEdgeMaxContinuity(handle, Int32(edgeIndex)))
    }

    // MARK: - Face Geometry (v0.133.0)

    /// Get the tolerance of a face.
    public func faceTolerance(_ faceIndex: Int) -> Double {
        OCCTBRepGraphFaceTolerance(handle, Int32(faceIndex))
    }

    /// Check if a face has the natural restriction flag.
    public func isFaceNaturalRestriction(_ faceIndex: Int) -> Bool {
        OCCTBRepGraphFaceIsNaturalRestriction(handle, Int32(faceIndex))
    }

    /// Check if a face has a surface.
    public func faceHasSurface(_ faceIndex: Int) -> Bool {
        OCCTBRepGraphFaceHasSurface(handle, Int32(faceIndex))
    }

    /// Check if a face has a triangulation.
    public func faceHasTriangulation(_ faceIndex: Int) -> Bool {
        OCCTBRepGraphFaceHasTriangulation(handle, Int32(faceIndex))
    }

    // MARK: - Wire Queries (v0.133.0)

    /// Check if a wire is topologically closed.
    public func isWireClosed(_ wireIndex: Int) -> Bool {
        OCCTBRepGraphWireIsClosed(handle, Int32(wireIndex))
    }

    /// Number of coedges in a wire.
    public func wireCoEdgeCount(_ wireIndex: Int) -> Int {
        Int(OCCTBRepGraphWireNbCoEdges(handle, Int32(wireIndex)))
    }

    /// Number of faces a wire belongs to.
    public func wireFaceCount(_ wireIndex: Int) -> Int {
        Int(OCCTBRepGraphWireFaceCount(handle, Int32(wireIndex)))
    }

    /// Indices of faces a wire belongs to.
    public func wireFaces(_ wireIndex: Int) -> [Int] {
        fetchIndices(count: wireFaceCount(wireIndex)) { buf in
            OCCTBRepGraphWireFaceIndices(handle, Int32(wireIndex), buf)
        }
    }

    // MARK: - CoEdge Queries (v0.133.0)

    /// Get the edge index of a coedge.
    public func coedgeEdge(_ coedgeIndex: Int) -> Int {
        Int(OCCTBRepGraphCoEdgeEdge(handle, Int32(coedgeIndex)))
    }

    /// Get the face index of a coedge.
    public func coedgeFace(_ coedgeIndex: Int) -> Int {
        Int(OCCTBRepGraphCoEdgeFace(handle, Int32(coedgeIndex)))
    }

    /// Get the seam pair coedge index, or nil if none.
    public func coedgeSeamPair(_ coedgeIndex: Int) -> Int? {
        let idx = Int(OCCTBRepGraphCoEdgeSeamPair(handle, Int32(coedgeIndex)))
        return idx >= 0 ? idx : nil
    }

    /// Check if a coedge has a PCurve.
    public func coedgeHasPCurve(_ coedgeIndex: Int) -> Bool {
        OCCTBRepGraphCoEdgeHasPCurve(handle, Int32(coedgeIndex))
    }

    /// Get the PCurve parameter range of a coedge.
    public func coedgeRange(_ coedgeIndex: Int) -> (first: Double, last: Double) {
        var first = 0.0
        var last = 0.0
        OCCTBRepGraphCoEdgeRange(handle, Int32(coedgeIndex), &first, &last)
        return (first, last)
    }

    // MARK: - Shell Queries (v0.133.0)

    /// Number of solids a shell belongs to.
    public func shellSolidCount(_ shellIndex: Int) -> Int {
        Int(OCCTBRepGraphShellSolidCount(handle, Int32(shellIndex)))
    }

    /// Indices of solids a shell belongs to.
    public func shellSolids(_ shellIndex: Int) -> [Int] {
        fetchIndices(count: shellSolidCount(shellIndex)) { buf in
            OCCTBRepGraphShellSolidIndices(handle, Int32(shellIndex), buf)
        }
    }

    // MARK: - Solid Queries (v0.133.0)

    /// Number of comp-solids a solid belongs to.
    public func solidCompSolidCount(_ solidIndex: Int) -> Int {
        Int(OCCTBRepGraphSolidCompSolidCount(handle, Int32(solidIndex)))
    }

    // MARK: - History (v0.133.0)

    /// Number of history records.
    public var historyRecordCount: Int {
        Int(OCCTBRepGraphHistoryNbRecords(handle))
    }

    /// Whether history recording is enabled.
    public var isHistoryEnabled: Bool {
        get { OCCTBRepGraphHistoryIsEnabled(handle) }
        set { OCCTBRepGraphHistorySetEnabled(handle, newValue) }
    }

    /// Clear all history records.
    public func clearHistory() {
        OCCTBRepGraphHistoryClear(handle)
    }

    // MARK: - History Record Readback (v0.141, #72 Phase 0)

    /// A (kind, index) pair identifying a node in a `BRepGraph`.
    ///
    /// This is the Swift mirror of OCCT's `BRepGraph_NodeId`. Two pairs with the
    /// same kind+index refer to the same node **within a given graph instance**;
    /// across graph rebuilds you have to translate through the history records.
    public struct NodeRef: Sendable, Hashable, Codable {
        public let kind: NodeKind
        public let index: Int

        public init(kind: NodeKind, index: Int) {
            self.kind = kind
            self.index = index
        }

        public var isValid: Bool { index >= 0 }
    }

    /// A single atomic modification event in the graph's history log.
    ///
    /// The mapping captures the topological fate of each affected node:
    /// - `original -> [one replacement]`: modified in place
    /// - `original -> [multiple replacements]`: split (e.g. edge split by fillet)
    /// - `original -> []`: deleted
    public struct HistoryRecord: Sendable {
        public let operationName: String
        public let sequenceNumber: Int
        public let mapping: [NodeRef: [NodeRef]]
    }

    /// Get a single history record by index.
    ///
    /// - Parameter index: 0-based index into the history log.
    /// - Returns: The record, or nil if `index` is out of range.
    public func historyRecord(at index: Int) -> HistoryRecord? {
        guard index >= 0, index < historyRecordCount else { return nil }
        var opNameBuffer = [CChar](repeating: 0, count: 128)
        var sequence: Int32 = 0
        let ok = opNameBuffer.withUnsafeMutableBufferPointer { buf in
            OCCTBRepGraphHistoryGetRecordInfo(
                handle, Int32(index),
                buf.baseAddress!, Int32(buf.count),
                &sequence)
        }
        guard ok else { return nil }
        // The bridge fills a fixed 128-byte buffer and NUL-terminates it. Decode only up to that
        // terminator — String(decoding:as:) over the whole buffer would carry the NUL padding into
        // the string.
        let opName = String(
            decoding: opNameBuffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) },
            as: UTF8.self)

        // Collect originals.
        let count = Int(OCCTBRepGraphHistoryGetRecordOriginalsCount(handle, Int32(index)))
        guard count > 0 else {
            return HistoryRecord(operationName: opName, sequenceNumber: Int(sequence), mapping: [:])
        }
        var origKinds = [Int32](repeating: 0, count: count)
        var origIndices = [Int32](repeating: 0, count: count)
        _ = origKinds.withUnsafeMutableBufferPointer { kindsBuf in
            origIndices.withUnsafeMutableBufferPointer { indicesBuf in
                OCCTBRepGraphHistoryGetRecordOriginals(
                    handle, Int32(index),
                    kindsBuf.baseAddress!,
                    indicesBuf.baseAddress!,
                    Int32(count))
            }
        }

        // For each original, fetch its replacement list.
        var mapping: [NodeRef: [NodeRef]] = [:]
        for i in 0..<count {
            guard let origKind = NodeKind(rawValue: origKinds[i]) else { continue }
            let orig = NodeRef(kind: origKind, index: Int(origIndices[i]))

            // Try modest buffer first; retry larger if needed.
            var replCap = 8
            var replKinds = [Int32](repeating: 0, count: replCap)
            var replIndices = [Int32](repeating: 0, count: replCap)
            var total: Int32 = 0
            total = replKinds.withUnsafeMutableBufferPointer { kb in
                replIndices.withUnsafeMutableBufferPointer { ib in
                    OCCTBRepGraphHistoryGetRecordMapping(
                        handle, Int32(index),
                        origKind.rawValue, Int32(orig.index),
                        kb.baseAddress!, ib.baseAddress!,
                        Int32(replCap))
                }
            }
            if total < 0 { continue }  // original not bound — skip
            if Int(total) > replCap {
                replCap = Int(total)
                replKinds = [Int32](repeating: 0, count: replCap)
                replIndices = [Int32](repeating: 0, count: replCap)
                _ = replKinds.withUnsafeMutableBufferPointer { kb in
                    replIndices.withUnsafeMutableBufferPointer { ib in
                        OCCTBRepGraphHistoryGetRecordMapping(
                            handle, Int32(index),
                            origKind.rawValue, Int32(orig.index),
                            kb.baseAddress!, ib.baseAddress!,
                            Int32(replCap))
                    }
                }
            }
            var replacements: [NodeRef] = []
            for j in 0..<Int(total) {
                guard let k = NodeKind(rawValue: replKinds[j]) else { continue }
                replacements.append(NodeRef(kind: k, index: Int(replIndices[j])))
            }
            mapping[orig] = replacements
        }
        return HistoryRecord(
            operationName: opName,
            sequenceNumber: Int(sequence),
            mapping: mapping)
    }

    /// All history records, in order.
    public var historyRecords: [HistoryRecord] {
        (0..<historyRecordCount).compactMap { historyRecord(at: $0) }
    }

    /// Walk backwards from a derived node to its root original via the reverse map.
    ///
    /// Returns the node itself if it has no recorded history.
    public func findOriginal(of derived: NodeRef) -> NodeRef {
        var outKind: Int32 = 0
        var outIndex: Int32 = 0
        guard
            OCCTBRepGraphHistoryFindOriginal(
                handle,
                derived.kind.rawValue, Int32(derived.index),
                &outKind, &outIndex),
            let kind = NodeKind(rawValue: outKind)
        else {
            return derived
        }
        return NodeRef(kind: kind, index: Int(outIndex))
    }

    /// True if any history record names `original` as a key (i.e. some recorded
    /// operation modified or deleted this node).
    ///
    /// Use this with `findDerived` to disambiguate the two cases that both
    /// return `[]` from `findDerived`: an explicitly-deleted node has a record
    /// with empty replacements, while an untouched node is simply absent from
    /// every record's mapping. See also `findDerivedOrSelf(of:)` for the
    /// common "where did this node end up?" lookup.
    public func hasHistoryRecord(for original: NodeRef) -> Bool {
        for record in historyRecords {
            if record.mapping[original] != nil { return true }
        }
        return false
    }

    /// Walk forwards from an original node and return its derivatives, falling
    /// back to `[original]` when the node was untouched and `[]` when the node
    /// was explicitly deleted.
    ///
    /// `findDerived(of:)` returns `[]` for both untouched and deleted nodes —
    /// callers can't tell "this face survived the mutation unchanged" from
    /// "this face was cut away". This entry point disambiguates by checking
    /// whether any history record names the node as an `original` key:
    ///
    /// - non-empty `findDerived` result → return it (live derivatives)
    /// - empty result + record present  → `[]` (explicitly deleted)
    /// - empty result + no record       → `[original]` (untouched, same index)
    ///
    /// Use this when you want a single deterministic answer to "where did
    /// this node end up?" — the typical selection-remap case. Use
    /// `findDerived` + `hasHistoryRecord` directly if you need to distinguish
    /// the deleted-vs-untouched cases at the call site.
    public func findDerivedOrSelf(of original: NodeRef) -> [NodeRef] {
        let derived = findDerived(of: original)
        if !derived.isEmpty { return derived }
        return hasHistoryRecord(for: original) ? [] : [original]
    }

    /// Walk forwards from an original node to all transitively derived nodes.
    ///
    /// Returns empty if the node has no recorded descendants.
    ///
    /// **Note:** an empty result is ambiguous between "untouched" and
    /// "explicitly deleted". Use `findDerivedOrSelf(of:)` for the common
    /// case, or pair this call with `hasHistoryRecord(for:)` to disambiguate.
    public func findDerived(of original: NodeRef) -> [NodeRef] {
        var cap = 16
        var kinds = [Int32](repeating: 0, count: cap)
        var indices = [Int32](repeating: 0, count: cap)
        var total = kinds.withUnsafeMutableBufferPointer { kb in
            indices.withUnsafeMutableBufferPointer { ib in
                OCCTBRepGraphHistoryFindDerived(
                    handle,
                    original.kind.rawValue, Int32(original.index),
                    kb.baseAddress!, ib.baseAddress!,
                    Int32(cap))
            }
        }
        if Int(total) > cap {
            cap = Int(total)
            kinds = [Int32](repeating: 0, count: cap)
            indices = [Int32](repeating: 0, count: cap)
            total = kinds.withUnsafeMutableBufferPointer { kb in
                indices.withUnsafeMutableBufferPointer { ib in
                    OCCTBRepGraphHistoryFindDerived(
                        handle,
                        original.kind.rawValue, Int32(original.index),
                        kb.baseAddress!, ib.baseAddress!,
                        Int32(cap))
                }
            }
        }
        var result: [NodeRef] = []
        for i in 0..<Int(total) {
            guard let k = NodeKind(rawValue: kinds[i]) else { continue }
            result.append(NodeRef(kind: k, index: Int(indices[i])))
        }
        return result
    }

    /// Record a 1-to-N modification event on the graph's history log.
    ///
    /// Use this when you mutate the graph outside BRepGraph's own builder API
    /// and want your changes to participate in history queries.
    ///
    /// - Parameters:
    ///   - operationName: Human-readable operation label.
    ///   - original: The node that was modified.
    ///   - replacements: The node(s) that replace it. Empty array = node was deleted.
    public func recordHistory(
        operationName: String,
        original: NodeRef,
        replacements: [NodeRef]
    ) {
        let replKinds = replacements.map { $0.kind.rawValue }
        let replIndices = replacements.map { Int32($0.index) }
        operationName.withCString { namePtr in
            replKinds.withUnsafeBufferPointer { kindsBuf in
                replIndices.withUnsafeBufferPointer { indicesBuf in
                    OCCTBRepGraphHistoryRecord(
                        handle, namePtr,
                        original.kind.rawValue, Int32(original.index),
                        kindsBuf.baseAddress,
                        indicesBuf.baseAddress,
                        Int32(replacements.count))
                }
            }
        }
    }

    /// True if a recorded operation consumed `node`, leaving it no image in the result.
    ///
    /// This is distinct from having no successors: a node with no history record at
    /// all is simply untouched, whereas a deleted node was explicitly consumed. Use
    /// this to tell "the cut removed this edge" apart from "the cut never saw it".
    ///
    /// ```swift
    /// let strips = graph.currentForms(of: pinned)
    /// if strips.isEmpty && graph.historyIsDeleted(pinned) {
    ///     // consumed by the operation, not merely unrecorded
    /// }
    /// ```
    public func historyIsDeleted(_ node: NodeRef) -> Bool {
        OCCTBRepGraphHistoryIsDeleted(handle, node.kind.rawValue, Int32(node.index))
    }

    /// Every node a recorded operation consumed with no image in the result.
    public var historyDeletedNodes: [NodeRef] {
        let total = OCCTBRepGraphHistoryDeletedNodes(handle, nil, nil, 0)
        guard total > 0 else { return [] }
        var kinds = [Int32](repeating: 0, count: Int(total))
        var indices = [Int32](repeating: 0, count: Int(total))
        _ = kinds.withUnsafeMutableBufferPointer { kBuf in
            indices.withUnsafeMutableBufferPointer { iBuf in
                OCCTBRepGraphHistoryDeletedNodes(handle, kBuf.baseAddress, iBuf.baseAddress, total)
            }
        }
        return (0..<Int(total)).compactMap { i in
            NodeKind(rawValue: kinds[i]).map { NodeRef(kind: $0, index: Int(indices[i])) }
        }
    }

    /// Add an operation's result to this graph and absorb its history, so the
    /// entities you were already holding keep resolving to their successors.
    ///
    /// This is the supported way to carry a picked face (or edge, or vertex)
    /// across an operation that rebuilds the shape — a boolean, a fillet, a
    /// chamfer. Because the input and the result live in the *same* graph
    /// instance, the `NodeRef`s and `GraphUID`s you already hold stay valid:
    /// there is no second graph to look them up in, and a UID only ever means
    /// something in the graph that minted it (#295).
    ///
    /// After this call, ``currentForms(of:)`` on an input node returns its
    /// successors, and the ``TopologyRef`` recipes (`.splitOf`, `.createdBy`)
    /// resolve against the records this emits.
    ///
    /// Build the graph from the operation's *input* shape, not its result — the
    /// input roots must already be in this graph.
    ///
    /// ```swift
    /// // Cut a channel across a box's top face, then keep hold of the face.
    /// let base = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10)!
    /// let graph = BRepGraph(shape: base)!
    ///
    /// // The topology root. Note this is findNode(for:), NOT rootNodes — that
    /// // enumerates Products and is empty for a graph built from a Shape.
    /// let rootNode = graph.findNode(for: base)!
    /// let root = BRepGraph.NodeRef(kind: rootNode.kind, index: rootNode.index)
    ///
    /// // Identify the top face and pin it BEFORE the cut.
    /// let faces = base.faces()
    /// let centroids = base.measure().faceCentroids
    /// let topIndex = centroids.enumerated().max { $0.element.z < $1.element.z }!.offset
    /// let topFace = Shape.fromFace(faces[topIndex])!
    /// let topNode = graph.findNode(for: topFace)!
    /// let pinned = BRepGraph.NodeRef(kind: topNode.kind, index: topNode.index)
    ///
    /// // Cut, then hand the result and its history back to the same graph.
    /// let tool = Shape.box(origin: SIMD3(-1, 4, 8), width: 12, height: 2, depth: 4)!
    /// let (result, history) = base.subtractedWithFullHistory(tool)!
    /// graph.add(result, absorbing: history, inputRoots: [root], operationName: "channel-cut")
    ///
    /// // The pinned face now resolves to the two strips it was split into.
    /// // Filter by kind: currentForms also returns the section edges the cut
    /// // generated on that face, since it unions modified and generated.
    /// let strips = graph.currentForms(of: pinned).filter { $0.kind == .face }   // 2 faces
    /// graph.resolve(.splitOf(original: .literal(pinned), occurrence: 0))        // .success(face)
    /// ```
    ///
    /// - Note: Only vertices, edges, faces and solids are tracked
    ///   (`BRepTools_History` carries no wires, shells or compounds), so nothing
    ///   is recorded for those kinds.
    ///
    /// - Parameters:
    ///   - result: The operation's result shape.
    ///   - history: The history handle returned alongside it by any
    ///     `*WithFullHistory` operation.
    ///   - inputRoots: Nodes in this graph whose subshapes should be tracked —
    ///     normally the root(s) the input shape was added as.
    ///   - operationName: Label recorded on every emitted record; the same string
    ///     `TopologyRef.createdBy(operationName:)` matches on.
    /// - Returns: The added result's topology-root node, or nil if the add or the
    ///   absorb failed.
    @discardableResult
    public func add(
        _ result: Shape,
        absorbing history: ShapeHistoryRef,
        inputRoots: [NodeRef],
        operationName: String
    ) -> NodeRef? {
        guard !inputRoots.isEmpty else { return nil }
        // Synthesize a BRepTools_History from the retained builder. Owned here and
        // released once absorbed — the graph copies what it needs into its log.
        guard let btHistory = OCCTBooleanHistoryAsBRepToolsHistory(history.handle) else {
            return nil
        }
        defer { OCCTHistoryDestroy(btHistory) }

        let rootKinds = inputRoots.map { $0.kind.rawValue }
        let rootIndices = inputRoots.map { Int32($0.index) }
        var outKind: Int32 = -1
        var outIndex: Int32 = -1

        let ok = operationName.withCString { namePtr in
            rootKinds.withUnsafeBufferPointer { kindsBuf in
                rootIndices.withUnsafeBufferPointer { indicesBuf in
                    OCCTBRepGraphAddWithHistory(
                        handle, result.handle, btHistory,
                        kindsBuf.baseAddress!,
                        indicesBuf.baseAddress!,
                        Int32(inputRoots.count),
                        namePtr,
                        &outKind, &outIndex)
                }
            }
        }
        guard ok, outKind >= 0, let kind = NodeKind(rawValue: outKind) else { return nil }
        return NodeRef(kind: kind, index: Int(outIndex))
    }

    // MARK: - Poly Counts (v0.133.0)

    /// Number of triangulations in the graph.
    public var triangulationCount: Int { Int(OCCTBRepGraphNbTriangulations(handle)) }

    /// Number of 3D polygons in the graph.
    public var polygon3DCount: Int { Int(OCCTBRepGraphNbPolygons3D(handle)) }

    // MARK: - MeshView (v0.158.0, OCCT 8.0.0 beta1 two-tier mesh storage)

    /// Number of 2D polygons (PCurve discretizations) in the graph.
    public var polygon2DCount: Int { Int(OCCTBRepGraphMeshNbPolygons2D(handle)) }

    /// Number of polygon-on-triangulation reps (coedge discretizations parameterized on a face triangulation).
    public var polygonOnTriCount: Int { Int(OCCTBRepGraphMeshNbPolygonsOnTri(handle)) }

    /// Number of active (non-removed) triangulations.
    public var activeTriangulationCount: Int {
        Int(OCCTBRepGraphMeshNbActiveTriangulations(handle))
    }

    /// Number of active 3D polygons.
    public var activePolygon3DCount: Int { Int(OCCTBRepGraphMeshNbActivePolygons3D(handle)) }

    /// Number of active 2D polygons.
    public var activePolygon2DCount: Int { Int(OCCTBRepGraphMeshNbActivePolygons2D(handle)) }

    /// Number of active polygon-on-triangulation reps.
    public var activePolygonOnTriCount: Int { Int(OCCTBRepGraphMeshNbActivePolygonsOnTri(handle)) }

    /// Active triangulation rep id for a face, checking the algorithm-derived mesh cache first
    /// and falling back to the persistent (STEP-imported) tier.
    ///
    /// Returns nil if neither tier has mesh data for the face.
    public func meshFaceActiveTriangulationRepId(_ faceIndex: Int) -> Int? {
        let id = Int(OCCTBRepGraphMeshFaceActiveTriangulationRepId(handle, Int32(faceIndex)))
        return id >= 0 ? id : nil
    }

    /// Active polygon-3D rep id for an edge (cache-first, persistent fallback).
    ///
    /// Returns nil if neither tier has polygon-3D mesh data for the edge.
    public func meshEdgePolygon3DRepId(_ edgeIndex: Int) -> Int? {
        let id = Int(OCCTBRepGraphMeshEdgePolygon3DRepId(handle, Int32(edgeIndex)))
        return id >= 0 ? id : nil
    }

    /// Whether a coedge has cached mesh data (polygon-on-tri or polygon-2D).
    ///
    /// Cache-only check — does not consult the persistent tier.
    public func meshCoEdgeHasMesh(_ coedgeIndex: Int) -> Bool {
        OCCTBRepGraphMeshCoEdgeHasMesh(handle, Int32(coedgeIndex))
    }

    // MARK: - MeshCache write API (v0.160.0)

    /// Create a triangulation rep in the graph's mesh storage.
    ///
    /// Returns the rep id, or nil on failure.
    public func createTriangulationRep(_ triangulation: Triangulation) -> Int? {
        let id = Int(OCCTBRepGraphMeshCreateTriangulationRep(handle, triangulation.handle))
        return id >= 0 ? id : nil
    }

    /// Create a polygon-3D rep in the graph's mesh storage.
    ///
    /// Returns the rep id, or nil on failure.
    public func createPolygon3DRep(_ polygon: Polygon3D) -> Int? {
        let id = Int(OCCTBRepGraphMeshCreatePolygon3DRep(handle, polygon.handle))
        return id >= 0 ? id : nil
    }

    /// Create a polygon-on-triangulation rep linked to an existing triangulation rep.
    ///
    /// Returns the rep id, or nil.
    public func createPolygonOnTriRep(_ polygon: PolygonOnTriangulation, triRepId: Int) -> Int? {
        let id = Int(
            OCCTBRepGraphMeshCreatePolygonOnTriRep(handle, polygon.handle, Int32(triRepId)))
        return id >= 0 ? id : nil
    }

    /// Append a triangulation rep to a face's cached mesh (multi-LOD support).
    public func appendCachedTriangulation(faceIndex: Int, triRepId: Int) {
        OCCTBRepGraphMeshAppendCachedTriangulation(handle, Int32(faceIndex), Int32(triRepId))
    }

    /// Set the active triangulation index in a face's cached mesh.
    public func setCachedActiveIndex(faceIndex: Int, activeIndex: Int) {
        OCCTBRepGraphMeshSetCachedActiveIndex(handle, Int32(faceIndex), Int32(activeIndex))
    }

    /// Set the polygon-3D rep in an edge's cached mesh.
    public func setCachedPolygon3D(edgeIndex: Int, polyRepId: Int) {
        OCCTBRepGraphMeshSetCachedPolygon3D(handle, Int32(edgeIndex), Int32(polyRepId))
    }

    /// Append a polygon-on-tri rep to a coedge's cached mesh (seam edge support).
    public func appendCachedPolygonOnTri(coedgeIndex: Int, polyRepId: Int) {
        OCCTBRepGraphMeshAppendCachedPolygonOnTri(handle, Int32(coedgeIndex), Int32(polyRepId))
    }

    /// Set the polygon-2D rep in a coedge's cached mesh.
    public func setCachedPolygon2D(coedgeIndex: Int, poly2DRepId: Int) {
        OCCTBRepGraphMeshSetCachedPolygon2D(handle, Int32(coedgeIndex), Int32(poly2DRepId))
    }

    // MARK: - Active Geometry Counts (v0.133.0)

    /// Number of active (non-removed) surfaces.
    public var activeSurfaceCount: Int { Int(OCCTBRepGraphNbActiveSurfaces(handle)) }

    /// Number of active 3D curves.
    public var activeCurve3DCount: Int { Int(OCCTBRepGraphNbActiveCurves3D(handle)) }

    /// Number of active 2D curves.
    public var activeCurve2DCount: Int { Int(OCCTBRepGraphNbActiveCurves2D(handle)) }

    // MARK: - SameDomain (v0.133.0)

    /// Indices of same-domain faces for a given face.
    public func sameDomainFaces(of faceIndex: Int) -> [Int] {
        let count = Int(OCCTBRepGraphFaceSameDomainCount(handle, Int32(faceIndex)))
        return fetchIndices(count: count) { buf in
            OCCTBRepGraphFaceSameDomainIndices(handle, Int32(faceIndex), buf)
        }
    }

    // MARK: - Copy and Transform (v0.133.0)

    /// Deep copy of the graph.
    public func copy(copyGeometry: Bool = true) -> BRepGraph? {
        guard let ref = OCCTBRepGraphCopy(handle, copyGeometry) else { return nil }
        return BRepGraph(borrowedHandle: ref)
    }

    /// Copy a single face sub-graph.
    public func copyFace(_ faceIndex: Int, copyGeometry: Bool = true) -> BRepGraph? {
        guard let ref = OCCTBRepGraphCopyFace(handle, Int32(faceIndex), copyGeometry) else {
            return nil
        }
        return BRepGraph(borrowedHandle: ref)
    }

    /// Transform the graph by a translation.
    public func translated(dx: Double, dy: Double, dz: Double, copyGeometry: Bool = true)
        -> BRepGraph?
    {
        guard let ref = OCCTBRepGraphTransformTranslation(handle, dx, dy, dz, copyGeometry) else {
            return nil
        }
        return BRepGraph(borrowedHandle: ref)
    }

    /// Internal initializer from an already-created handle (takes ownership).
    internal init(borrowedHandle: OCCTBRepGraphRef) {
        self.handle = borrowedHandle
    }

    // MARK: - Product (Assembly) Queries (v0.134.0)

    /// Number of products in the graph (0 for simple shapes).
    public var productCount: Int { Int(OCCTBRepGraphNbProducts(handle)) }

    /// Number of occurrences in the graph (0 for simple shapes).
    public var occurrenceCount: Int { Int(OCCTBRepGraphNbOccurrences(handle)) }

    /// Whether product at index is an assembly.
    public func productIsAssembly(_ productIndex: Int) -> Bool {
        OCCTBRepGraphProductIsAssembly(handle, Int32(productIndex))
    }

    /// Whether product at index is a part.
    public func productIsPart(_ productIndex: Int) -> Bool {
        OCCTBRepGraphProductIsPart(handle, Int32(productIndex))
    }

    /// Number of active child occurrences of a product.
    public func productComponentCount(_ productIndex: Int) -> Int {
        Int(OCCTBRepGraphProductNbComponents(handle, Int32(productIndex)))
    }

    /// Shape root node of a product, or nil if assembly/invalid.
    public func productShapeRoot(_ productIndex: Int) -> (kind: NodeKind, index: Int)? {
        let k = OCCTBRepGraphProductShapeRootKind(handle, Int32(productIndex))
        let i = OCCTBRepGraphProductShapeRootIndex(handle, Int32(productIndex))
        guard k >= 0, let kind = NodeKind(rawValue: k) else { return nil }
        return (kind: kind, index: Int(i))
    }

    /// Product index of an occurrence.
    public func occurrenceProduct(_ occIndex: Int) -> Int {
        Int(OCCTBRepGraphOccurrenceProduct(handle, Int32(occIndex)))
    }

    /// Parent product index of an occurrence.
    public func occurrenceParentProduct(_ occIndex: Int) -> Int {
        Int(OCCTBRepGraphOccurrenceParentProduct(handle, Int32(occIndex)))
    }

    /// Number of root products.
    public var rootProductCount: Int {
        Int(OCCTBRepGraphRootProductCount(handle))
    }

    /// Indices of root products.
    public var rootProductIndices: [Int] {
        fetchIndices(count: rootProductCount) { buf in
            OCCTBRepGraphRootProductIndices(handle, buf)
        }
    }

    // MARK: - Reference Counts (v0.134.0)

    /// Reference kind enumeration matching BRepGraph_RefId::Kind.
    public enum RefKind: Int32, Sendable {
        case shell = 0
        case face = 1
        case wire = 2
        case coedge = 3
        case vertex = 4
        case solid = 5
        case child = 6
        case occurrence = 7
    }

    /// Number of shell reference entries.
    public var shellRefCount: Int { Int(OCCTBRepGraphNbShellRefs(handle)) }

    /// Number of face reference entries.
    public var faceRefCount: Int { Int(OCCTBRepGraphNbFaceRefs(handle)) }

    /// Number of wire reference entries.
    public var wireRefCount: Int { Int(OCCTBRepGraphNbWireRefs(handle)) }

    /// Number of coedge reference entries.
    public var coedgeRefCount: Int { Int(OCCTBRepGraphNbCoEdgeRefs(handle)) }

    /// Number of vertex reference entries.
    public var vertexRefCount: Int { Int(OCCTBRepGraphNbVertexRefs(handle)) }

    /// Number of solid reference entries.
    public var solidRefCount: Int { Int(OCCTBRepGraphNbSolidRefs(handle)) }

    /// Number of child reference entries.
    public var childRefCount: Int { Int(OCCTBRepGraphNbChildRefs(handle)) }

    /// Number of occurrence reference entries.
    public var occurrenceRefCount: Int { Int(OCCTBRepGraphNbOccurrenceRefs(handle)) }

    // MARK: - Reference Entry Queries (v0.134.0)

    /// Child node kind from a reference entry.
    public func refChildNodeKind(_ refKind: RefKind, refIndex: Int) -> NodeKind? {
        let k = OCCTBRepGraphRefChildNodeKind(handle, refKind.rawValue, Int32(refIndex))
        guard k >= 0 else { return nil }
        return NodeKind(rawValue: k)
    }

    /// Child node index from a reference entry.
    public func refChildNodeIndex(_ refKind: RefKind, refIndex: Int) -> Int {
        Int(OCCTBRepGraphRefChildNodeIndex(handle, refKind.rawValue, Int32(refIndex)))
    }

    /// Whether a reference entry is removed.
    public func isRefRemoved(_ refKind: RefKind, refIndex: Int) -> Bool {
        OCCTBRepGraphRefIsRemoved(handle, refKind.rawValue, Int32(refIndex))
    }

    /// Orientation of a reference entry (TopAbs_Orientation as Int).
    public func refOrientation(_ refKind: RefKind, refIndex: Int) -> Int {
        Int(OCCTBRepGraphRefOrientation(handle, refKind.rawValue, Int32(refIndex)))
    }

    // MARK: - Face Definition Details (v0.134.0)

    /// Number of wire refs on a face.
    public func faceWireCount(_ faceIndex: Int) -> Int {
        Int(OCCTBRepGraphFaceNbWires(handle, Int32(faceIndex)))
    }

    /// Number of isolated vertex refs on a face.
    public func faceVertexRefCount(_ faceIndex: Int) -> Int {
        Int(OCCTBRepGraphFaceNbVertexRefs(handle, Int32(faceIndex)))
    }

    // MARK: - Edge Definition Details (v0.134.0)

    /// Start vertex definition index of an edge, or nil if invalid.
    public func edgeStartVertex(_ edgeIndex: Int) -> Int? {
        let idx = Int(OCCTBRepGraphEdgeStartVertex(handle, Int32(edgeIndex)))
        return idx >= 0 ? idx : nil
    }

    /// End vertex definition index of an edge, or nil if invalid.
    public func edgeEndVertex(_ edgeIndex: Int) -> Int? {
        let idx = Int(OCCTBRepGraphEdgeEndVertex(handle, Int32(edgeIndex)))
        return idx >= 0 ? idx : nil
    }

    /// Whether an edge is topologically closed (start == end vertex).
    public func isEdgeClosed(_ edgeIndex: Int) -> Bool {
        OCCTBRepGraphEdgeIsClosed(handle, Int32(edgeIndex))
    }

    // MARK: - Compound/CompSolid Queries (v0.134.0)

    /// Number of parent compounds of a compound.
    public func compoundParentCount(_ compoundIndex: Int) -> Int {
        Int(OCCTBRepGraphCompoundParentCount(handle, Int32(compoundIndex)))
    }

    /// Number of child refs of a compound.
    public func compoundChildCount(_ compoundIndex: Int) -> Int {
        Int(OCCTBRepGraphCompoundChildCount(handle, Int32(compoundIndex)))
    }

    /// Number of solid refs in a comp-solid.
    public func compSolidSolidCount(_ compSolidIndex: Int) -> Int {
        Int(OCCTBRepGraphCompSolidSolidCount(handle, Int32(compSolidIndex)))
    }

    /// Number of parent compounds of a comp-solid.
    public func compSolidCompoundCount(_ compSolidIndex: Int) -> Int {
        Int(OCCTBRepGraphCompSolidCompoundCount(handle, Int32(compSolidIndex)))
    }

    // MARK: - Edge Additional Queries (v0.134.0)

    /// Indices of wires an edge belongs to.
    public func edgeWires(_ edgeIndex: Int) -> [Int] {
        let count = Int(OCCTBRepGraphEdgeWireCount(handle, Int32(edgeIndex)))
        return fetchIndices(count: count) { buf in
            OCCTBRepGraphEdgeWireIndices(handle, Int32(edgeIndex), buf)
        }
    }

    /// Indices of coedges of an edge.
    public func edgeCoEdges(_ edgeIndex: Int) -> [Int] {
        let count = Int(OCCTBRepGraphEdgeCoEdgeCount(handle, Int32(edgeIndex)))
        return fetchIndices(count: count) { buf in
            OCCTBRepGraphEdgeCoEdgeIndices(handle, Int32(edgeIndex), buf)
        }
    }

    /// Find the coedge index for an (edge, face) pair, or nil if not found.
    public func edgeFindCoEdge(edgeIndex: Int, faceIndex: Int) -> Int? {
        let idx = Int(OCCTBRepGraphEdgeFindCoEdge(handle, Int32(edgeIndex), Int32(faceIndex)))
        return idx >= 0 ? idx : nil
    }

    // MARK: - Face Additional Queries (v0.134.0)

    /// Number of shells a face belongs to.
    public func faceShellCount(_ faceIndex: Int) -> Int {
        Int(OCCTBRepGraphFaceShellCount(handle, Int32(faceIndex)))
    }

    /// Indices of shells a face belongs to.
    public func faceShells(_ faceIndex: Int) -> [Int] {
        fetchIndices(count: faceShellCount(faceIndex)) { buf in
            OCCTBRepGraphFaceShellIndices(handle, Int32(faceIndex), buf)
        }
    }

    /// Number of compounds a face belongs to.
    public func faceCompoundCount(_ faceIndex: Int) -> Int {
        Int(OCCTBRepGraphFaceCompoundCount(handle, Int32(faceIndex)))
    }

    // MARK: - Shell Additional Queries (v0.134.0)

    /// Number of compounds a shell belongs to.
    public func shellCompoundCount(_ shellIndex: Int) -> Int {
        Int(OCCTBRepGraphShellCompoundCount(handle, Int32(shellIndex)))
    }

    /// Whether a shell is closed.
    public func isShellClosed(_ shellIndex: Int) -> Bool {
        OCCTBRepGraphShellIsClosed(handle, Int32(shellIndex))
    }

    // MARK: - Solid Additional Queries (v0.134.0)

    /// Number of compounds a solid belongs to.
    public func solidCompoundCount(_ solidIndex: Int) -> Int {
        Int(OCCTBRepGraphSolidCompoundCount(handle, Int32(solidIndex)))
    }

    // MARK: - CompSolid Count (v0.134.0)

    /// Number of comp-solids in the graph.
    public var compSolidCount: Int { Int(OCCTBRepGraphNbCompSolids(handle)) }

    // MARK: - Builder: Add Topology Nodes (v0.135.0)

    /// Add a vertex to the graph.
    /// - Parameters:
    ///   - x: X coordinate.
    ///   - y: Y coordinate.
    ///   - z: Z coordinate.
    ///   - tolerance: Vertex tolerance.
    /// - Returns: Vertex definition index, or nil on failure.
    public func addVertex(x: Double, y: Double, z: Double, tolerance: Double) -> Int? {
        let idx = Int(OCCTBRepGraphBuilderAddVertex(handle, x, y, z, tolerance))
        return idx >= 0 ? idx : nil
    }

    /// Add an empty shell to the graph.
    /// - Returns: Shell definition index, or nil on failure.
    public func addShell() -> Int? {
        let idx = Int(OCCTBRepGraphBuilderAddShell(handle))
        return idx >= 0 ? idx : nil
    }

    /// Add an empty solid to the graph.
    /// - Returns: Solid definition index, or nil on failure.
    public func addSolid() -> Int? {
        let idx = Int(OCCTBRepGraphBuilderAddSolid(handle))
        return idx >= 0 ? idx : nil
    }

    /// Link a face to a shell.
    /// - Parameters:
    ///   - shellIndex: Shell definition index.
    ///   - faceIndex: Face definition index.
    ///   - orientation: TopAbs_Orientation value (0=FORWARD, 1=REVERSED, 2=INTERNAL, 3=EXTERNAL).
    /// - Returns: Face reference index, or nil on failure.
    public func addFaceToShell(shellIndex: Int, faceIndex: Int, orientation: Int = 0) -> Int? {
        let idx = Int(
            OCCTBRepGraphBuilderAddFaceToShell(
                handle, Int32(shellIndex), Int32(faceIndex), Int32(orientation)))
        return idx >= 0 ? idx : nil
    }

    /// Link a shell to a solid.
    /// - Parameters:
    ///   - solidIndex: Solid definition index.
    ///   - shellIndex: Shell definition index.
    ///   - orientation: TopAbs_Orientation value (0=FORWARD, 1=REVERSED, 2=INTERNAL, 3=EXTERNAL).
    /// - Returns: Shell reference index, or nil on failure.
    public func addShellToSolid(solidIndex: Int, shellIndex: Int, orientation: Int = 0) -> Int? {
        let idx = Int(
            OCCTBRepGraphBuilderAddShellToSolid(
                handle, Int32(solidIndex), Int32(shellIndex), Int32(orientation)))
        return idx >= 0 ? idx : nil
    }

    /// Add a compound with child node entries.
    /// - Parameter children: Array of (kind, index) pairs for child nodes.
    /// - Returns: Compound definition index, or nil on failure.
    public func addCompound(children: [(kind: NodeKind, index: Int)]) -> Int? {
        if children.isEmpty { return nil }
        var kinds = children.map { $0.kind.rawValue }
        var indices = children.map { Int32($0.index) }
        let idx = Int(
            kinds.withUnsafeMutableBufferPointer { kBuf in
                indices.withUnsafeMutableBufferPointer { iBuf in
                    OCCTBRepGraphBuilderAddCompound(
                        handle, kBuf.baseAddress!, iBuf.baseAddress!, Int32(children.count))
                }
            })
        return idx >= 0 ? idx : nil
    }

    /// Add a comp-solid with child solid indices.
    /// - Parameter solidIndices: Array of solid definition indices.
    /// - Returns: CompSolid definition index, or nil on failure.
    public func addCompSolid(solidIndices: [Int]) -> Int? {
        if solidIndices.isEmpty { return nil }
        var indices = solidIndices.map { Int32($0) }
        let idx = Int(
            indices.withUnsafeMutableBufferPointer { buf in
                OCCTBRepGraphBuilderAddCompSolid(
                    handle, buf.baseAddress!, Int32(solidIndices.count))
            })
        return idx >= 0 ? idx : nil
    }

    // MARK: - Builder: Remove/Modify Nodes (v0.135.0)

    /// Mark a node as removed (soft deletion).
    public func removeNode(nodeKind: NodeKind, nodeIndex: Int) {
        OCCTBRepGraphBuilderRemoveNode(handle, nodeKind.rawValue, Int32(nodeIndex))
    }

    /// Mark a node and all its descendants as removed (cascading soft deletion).
    public func removeSubgraph(nodeKind: NodeKind, nodeIndex: Int) {
        OCCTBRepGraphBuilderRemoveSubgraph(handle, nodeKind.rawValue, Int32(nodeIndex))
    }

    // MARK: - Builder: Append Shapes (v0.135.0)

    /// Append a shape to the graph (flattened: container nodes removed, faces as roots).
    public func appendFlattenedShape(_ shape: Shape, parallel: Bool = false) {
        OCCTBRepGraphBuilderAppendFlattenedShape(handle, shape.handle, parallel)
    }

    /// Append a shape to the graph preserving full topology hierarchy.
    public func appendFullShape(_ shape: Shape, parallel: Bool = false) {
        OCCTBRepGraphBuilderAppendFullShape(handle, shape.handle, parallel)
    }

    // MARK: - Builder: Deferred Invalidation (v0.135.0)

    /// Begin deferred invalidation mode for batch mutations.
    public func beginDeferredInvalidation() {
        OCCTBRepGraphBuilderBeginDeferred(handle)
    }

    /// End deferred invalidation mode and batch-flush all accumulated changes.
    public func endDeferredInvalidation() {
        OCCTBRepGraphBuilderEndDeferred(handle)
    }

    /// Whether deferred invalidation mode is currently active.
    public var isDeferredMode: Bool {
        OCCTBRepGraphBuilderIsDeferredMode(handle)
    }

    /// Finalize batch mutations (validates reverse-index consistency).
    public func commitMutation() {
        OCCTBRepGraphBuilderCommitMutation(handle)
    }

    // MARK: - Builder: Edge Splitting (v0.135.0)

    /// Split an edge at a vertex and 3D curve parameter.
    /// - Parameters:
    ///   - edgeIndex: Edge definition index to split.
    ///   - vertexIndex: Vertex definition index at the split point.
    ///   - param: Parameter on the 3D curve at the split point.
    /// - Returns: Tuple of (subA, subB) edge indices, or nil on failure.
    public func splitEdge(edgeIndex: Int, vertexIndex: Int, param: Double) -> (
        subA: Int, subB: Int
    )? {
        var subA: Int32 = -1
        var subB: Int32 = -1
        OCCTBRepGraphBuilderSplitEdge(
            handle, Int32(edgeIndex), Int32(vertexIndex), param, &subA, &subB)
        if subA >= 0 && subB >= 0 {
            return (subA: Int(subA), subB: Int(subB))
        }
        return nil
    }

    // MARK: - Builder: Replace Edge in Wire (v0.135.0)

    /// Replace one edge with another in a wire definition.
    /// - Parameters:
    ///   - wireIndex: Wire definition index.
    ///   - oldEdgeIndex: Edge to replace.
    ///   - newEdgeIndex: Replacement edge.
    ///   - reversed: Whether to reverse the orientation of the replacement.
    public func replaceEdgeInWire(
        wireIndex: Int, oldEdgeIndex: Int, newEdgeIndex: Int, reversed: Bool = false
    ) {
        OCCTBRepGraphBuilderReplaceEdgeInWire(
            handle, Int32(wireIndex), Int32(oldEdgeIndex), Int32(newEdgeIndex), reversed)
    }

    // MARK: - Builder: Remove Ref (v0.135.0)

    /// Mark a reference entry as removed.
    /// - Parameters:
    ///   - refKind: Reference kind.
    ///   - refIndex: Reference index.
    /// - Returns: True if the reference transitioned from active to removed.
    @discardableResult
    public func removeRef(refKind: RefKind, refIndex: Int) -> Bool {
        OCCTBRepGraphBuilderRemoveRef(handle, refKind.rawValue, Int32(refIndex))
    }

    // MARK: - Builder: Clear Mesh (v0.135.0)

    /// Clear all mesh representations for a face and its coedges.
    public func clearFaceMesh(faceIndex: Int) {
        OCCTBRepGraphBuilderClearFaceMesh(handle, Int32(faceIndex))
    }

    /// Clear Polygon3D representation from an edge.
    public func clearEdgePolygon3D(edgeIndex: Int) {
        OCCTBRepGraphBuilderClearEdgePolygon3D(handle, Int32(edgeIndex))
    }

    // MARK: - Builder: Validate Mutation (v0.135.0)

    /// Validate mutation-boundary invariants.
    /// - Returns: True if no issues were found.
    public func validateMutation() -> Bool {
        OCCTBRepGraphBuilderValidateMutation(handle)
    }

    // MARK: - EditorView Field Setters (v0.159.0)

    /// Set the 3D point of a vertex definition.
    public func setVertexPoint(_ vertexIndex: Int, x: Double, y: Double, z: Double) {
        OCCTBRepGraphSetVertexPoint(handle, Int32(vertexIndex), x, y, z)
    }

    /// Set the tolerance of a vertex definition.
    public func setVertexTolerance(_ vertexIndex: Int, tolerance: Double) {
        OCCTBRepGraphSetVertexTolerance(handle, Int32(vertexIndex), tolerance)
    }

    /// Set the tolerance of an edge definition.
    public func setEdgeTolerance(_ edgeIndex: Int, tolerance: Double) {
        OCCTBRepGraphSetEdgeTolerance(handle, Int32(edgeIndex), tolerance)
    }

    /// Set the parametric range of an edge definition.
    public func setEdgeParamRange(_ edgeIndex: Int, first: Double, last: Double) {
        OCCTBRepGraphSetEdgeParamRange(handle, Int32(edgeIndex), first, last)
    }

    /// Set the SameParameter flag of an edge definition.
    public func setEdgeSameParameter(_ edgeIndex: Int, sameParameter: Bool) {
        OCCTBRepGraphSetEdgeSameParameter(handle, Int32(edgeIndex), sameParameter)
    }

    /// Set the SameRange flag of an edge definition.
    public func setEdgeSameRange(_ edgeIndex: Int, sameRange: Bool) {
        OCCTBRepGraphSetEdgeSameRange(handle, Int32(edgeIndex), sameRange)
    }

    /// Set the IsDegenerate flag of an edge definition.
    ///
    /// - Parameters:
    ///   - edgeIndex: The edge index.
    ///   - degenerate: Whether the edge is degenerate.
    public func setEdgeDegenerate(_ edgeIndex: Int, degenerate: Bool) {
        OCCTBRepGraphSetEdgeDegenerate(handle, Int32(edgeIndex), degenerate)
    }

    /// Set the IsClosed flag (StartVertex == EndVertex topology) of an edge.
    public func setEdgeIsClosed(_ edgeIndex: Int, isClosed: Bool) {
        OCCTBRepGraphSetEdgeIsClosed(handle, Int32(edgeIndex), isClosed)
    }

    /// Set the parametric range of a coedge definition.
    public func setCoEdgeParamRange(_ coedgeIndex: Int, first: Double, last: Double) {
        OCCTBRepGraphSetCoEdgeParamRange(handle, Int32(coedgeIndex), first, last)
    }

    /// Set the orientation of a coedge in its owning face.
    ///
    /// - Parameters:
    ///   - coedgeIndex: The coedge index.
    ///   - orientation: 0=Forward, 1=Reversed, 2=Internal, 3=External.
    public func setCoEdgeOrientation(_ coedgeIndex: Int, orientation: Int) {
        OCCTBRepGraphSetCoEdgeOrientation(handle, Int32(coedgeIndex), Int32(orientation))
    }

    /// Set the IsClosed flag of a wire definition.
    public func setWireIsClosed(_ wireIndex: Int, isClosed: Bool) {
        OCCTBRepGraphSetWireIsClosed(handle, Int32(wireIndex), isClosed)
    }

    /// Set the tolerance of a face definition.
    public func setFaceTolerance(_ faceIndex: Int, tolerance: Double) {
        OCCTBRepGraphSetFaceTolerance(handle, Int32(faceIndex), tolerance)
    }

    /// Set the natural-restriction flag of a face definition.
    ///
    /// - Parameters:
    ///   - faceIndex: The face index.
    ///   - naturalRestriction: Whether the face has natural restriction.
    public func setFaceNaturalRestriction(_ faceIndex: Int, naturalRestriction: Bool) {
        OCCTBRepGraphSetFaceNaturalRestriction(handle, Int32(faceIndex), naturalRestriction)
    }

    /// Set the IsClosed flag of a shell definition.
    public func setShellIsClosed(_ shellIndex: Int, isClosed: Bool) {
        OCCTBRepGraphSetShellIsClosed(handle, Int32(shellIndex), isClosed)
    }

    // MARK: - EditorView Add operations (v0.161.0)

    /// Attach an internal vertex (built from the graph vertex's point) to an edge as a runtime
    /// supplement attachment.
    ///
    /// Returns the layer-local attachment uid, or nil on failure.
    /// - Note: Edge-internal vertices are a supplemental, runtime concept in OCCT 8.0.0p1
    ///   (`BRepGraph_LayerTopoSupplement`); a clean shape has none until one is added here.
    /// - Parameters:
    ///   - edgeIndex: The edge index.
    ///   - vertexIndex: The vertex index.
    ///   - orientation: Accepted for source-compat but ignored by the supplement layer.
    /// - Returns: The layer-local attachment uid, or nil on failure.
    public func edgeAddInternalVertex(_ edgeIndex: Int, vertexIndex: Int, orientation: Int = 2)
        -> Int?
    {
        let id = Int(
            OCCTBRepGraphEdgeAddInternalVertex(
                handle, Int32(edgeIndex), Int32(vertexIndex), Int32(orientation)))
        return id >= 0 ? id : nil
    }

    /// Attach a direct vertex (built from the graph vertex's point) to a face as a runtime supplement
    /// attachment.
    ///
    /// Returns the layer-local attachment uid, or nil on failure.
    /// - Note: Face-direct vertices are a supplemental, runtime concept in OCCT 8.0.0p1
    ///   (`BRepGraph_LayerTopoSupplement`); a clean box has none until one is added here.
    /// - Parameters:
    ///   - faceIndex: The face index.
    ///   - vertexIndex: The vertex index.
    ///   - orientation: Accepted for source-compat but ignored by the supplement layer.
    /// - Returns: The layer-local attachment uid, or nil on failure.
    public func faceAddVertex(_ faceIndex: Int, vertexIndex: Int, orientation: Int = 0) -> Int? {
        let id = Int(
            OCCTBRepGraphFaceAddVertex(
                handle, Int32(faceIndex), Int32(vertexIndex), Int32(orientation)))
        return id >= 0 ? id : nil
    }

    /// Link an auxiliary non-face child (Wire or Edge) to a shell.
    ///
    /// Returns child-ref id or nil.
    public func shellAddChild(
        _ shellIndex: Int, childKind: Int, childIndex: Int, orientation: Int = 0
    ) -> Int? {
        let id = Int(
            OCCTBRepGraphShellAddChild(
                handle, Int32(shellIndex), Int32(childKind), Int32(childIndex), Int32(orientation)))
        return id >= 0 ? id : nil
    }

    /// Link an auxiliary non-shell child (Edge or Vertex) to a solid.
    ///
    /// Returns child-ref id or nil.
    public func solidAddChild(
        _ solidIndex: Int, childKind: Int, childIndex: Int, orientation: Int = 0
    ) -> Int? {
        let id = Int(
            OCCTBRepGraphSolidAddChild(
                handle, Int32(solidIndex), Int32(childKind), Int32(childIndex), Int32(orientation)))
        return id >= 0 ? id : nil
    }

    /// Append a single child to an existing compound definition.
    ///
    /// Returns child-ref id or nil.
    public func compoundAddChild(
        _ compoundIndex: Int, childKind: Int, childIndex: Int, orientation: Int = 0
    ) -> Int? {
        let id = Int(
            OCCTBRepGraphCompoundAddChild(
                handle, Int32(compoundIndex), Int32(childKind), Int32(childIndex),
                Int32(orientation)))
        return id >= 0 ? id : nil
    }

    /// Append a single solid to an existing compsolid definition.
    ///
    /// Returns solid-ref id or nil.
    public func compSolidAddSolid(_ compSolidIndex: Int, solidIndex: Int, orientation: Int = 0)
        -> Int?
    {
        let id = Int(
            OCCTBRepGraphCompSolidAddSolid(
                handle, Int32(compSolidIndex), Int32(solidIndex), Int32(orientation)))
        return id >= 0 ? id : nil
    }

    // MARK: - EditorView Remove operations (v0.161.0)

    /// Detach an exact vertex ref from an edge definition.
    ///
    /// Returns true if the active usage was removed.
    public func edgeRemoveVertex(_ edgeIndex: Int, vertexRefIndex: Int) -> Bool {
        OCCTBRepGraphEdgeRemoveVertex(handle, Int32(edgeIndex), Int32(vertexRefIndex))
    }

    /// Remap an edge-owned vertex reference to a different vertex definition.
    ///
    /// Returns the new vertex-ref id, or nil.
    public func edgeReplaceVertex(_ edgeIndex: Int, oldVertexRefIndex: Int, newVertexIndex: Int)
        -> Int?
    {
        let id = Int(
            OCCTBRepGraphEdgeReplaceVertex(
                handle, Int32(edgeIndex), Int32(oldVertexRefIndex), Int32(newVertexIndex)))
        return id >= 0 ? id : nil
    }

    /// Detach a coedge ref from a wire definition.
    ///
    /// Returns true if the coedge reference was removed.
    public func wireRemoveCoEdge(_ wireIndex: Int, coedgeRefIndex: Int) -> Bool {
        OCCTBRepGraphWireRemoveCoEdge(handle, Int32(wireIndex), Int32(coedgeRefIndex))
    }

    /// Detach a face-direct vertex supplement attachment by its uid (the value returned by
    /// `faceAddVertex`).
    ///
    /// Returns true if the attachment existed and was removed.
    public func faceRemoveVertex(_ faceIndex: Int, attachmentUID: Int) -> Bool {
        OCCTBRepGraphFaceRemoveVertex(handle, Int32(faceIndex), Int64(attachmentUID))
    }

    /// Detach a wire ref from a face definition.
    ///
    /// Returns true if the wire reference was removed.
    public func faceRemoveWire(_ faceIndex: Int, wireRefIndex: Int) -> Bool {
        OCCTBRepGraphFaceRemoveWire(handle, Int32(faceIndex), Int32(wireRefIndex))
    }

    /// Detach a face ref from a shell definition.
    public func shellRemoveFace(_ shellIndex: Int, faceRefIndex: Int) -> Bool {
        OCCTBRepGraphShellRemoveFace(handle, Int32(shellIndex), Int32(faceRefIndex))
    }

    /// Detach an auxiliary child ref from a shell.
    public func shellRemoveChild(_ shellIndex: Int, childRefIndex: Int) -> Bool {
        OCCTBRepGraphShellRemoveChild(handle, Int32(shellIndex), Int32(childRefIndex))
    }

    /// Detach a shell ref from a solid definition.
    public func solidRemoveShell(_ solidIndex: Int, shellRefIndex: Int) -> Bool {
        OCCTBRepGraphSolidRemoveShell(handle, Int32(solidIndex), Int32(shellRefIndex))
    }

    /// Detach an auxiliary child ref from a solid.
    public func solidRemoveChild(_ solidIndex: Int, childRefIndex: Int) -> Bool {
        OCCTBRepGraphSolidRemoveChild(handle, Int32(solidIndex), Int32(childRefIndex))
    }

    /// Detach a child ref from a compound definition.
    public func compoundRemoveChild(_ compoundIndex: Int, childRefIndex: Int) -> Bool {
        OCCTBRepGraphCompoundRemoveChild(handle, Int32(compoundIndex), Int32(childRefIndex))
    }

    /// Detach a solid ref from a compsolid definition.
    public func compSolidRemoveSolid(_ compSolidIndex: Int, solidRefIndex: Int) -> Bool {
        OCCTBRepGraphCompSolidRemoveSolid(handle, Int32(compSolidIndex), Int32(solidRefIndex))
    }

    /// Remove a representation (surface, curve, triangulation, polygon) from storage.
    public func removeRep(repKind: Int, repIndex: Int) {
        OCCTBRepGraphRemoveRep(handle, Int32(repKind), Int32(repIndex))
    }

    // MARK: - EditorView Ref setters (v0.161.0)

    public func setVertexRefOrientation(_ vertexRefIndex: Int, orientation: Int) {
        OCCTBRepGraphSetVertexRefOrientation(handle, Int32(vertexRefIndex), Int32(orientation))
    }
    public func setVertexRefVertexDefId(_ vertexRefIndex: Int, vertexIndex: Int) {
        OCCTBRepGraphSetVertexRefVertexDefId(handle, Int32(vertexRefIndex), Int32(vertexIndex))
    }
    public func setEdgeStartVertexRefId(_ edgeIndex: Int, vertexRefIndex: Int) {
        OCCTBRepGraphSetEdgeStartVertexRefId(handle, Int32(edgeIndex), Int32(vertexRefIndex))
    }
    public func setEdgeEndVertexRefId(_ edgeIndex: Int, vertexRefIndex: Int) {
        OCCTBRepGraphSetEdgeEndVertexRefId(handle, Int32(edgeIndex), Int32(vertexRefIndex))
    }
    public func setEdgeCurve3DRepId(_ edgeIndex: Int, curve3DRepId: Int) {
        OCCTBRepGraphSetEdgeCurve3DRepId(handle, Int32(edgeIndex), Int32(curve3DRepId))
    }
    public func setEdgePolygon3DRepId(_ edgeIndex: Int, polygon3DRepId: Int) {
        OCCTBRepGraphSetEdgePolygon3DRepId(handle, Int32(edgeIndex), Int32(polygon3DRepId))
    }
    public func setCoEdgeRefCoEdgeDefId(_ coedgeRefIndex: Int, coedgeIndex: Int) {
        OCCTBRepGraphSetCoEdgeRefCoEdgeDefId(handle, Int32(coedgeRefIndex), Int32(coedgeIndex))
    }
    public func setCoEdgeEdgeDefId(_ coedgeIndex: Int, edgeIndex: Int) {
        OCCTBRepGraphSetCoEdgeEdgeDefId(handle, Int32(coedgeIndex), Int32(edgeIndex))
    }
    public func setCoEdgeFaceDefId(_ coedgeIndex: Int, faceIndex: Int) {
        OCCTBRepGraphSetCoEdgeFaceDefId(handle, Int32(coedgeIndex), Int32(faceIndex))
    }
    public func setCoEdgeCurve2DRepId(_ coedgeIndex: Int, curve2DRepId: Int) {
        OCCTBRepGraphSetCoEdgeCurve2DRepId(handle, Int32(coedgeIndex), Int32(curve2DRepId))
    }
    public func setCoEdgePolygon2DRepId(_ coedgeIndex: Int, polygon2DRepId: Int) {
        OCCTBRepGraphSetCoEdgePolygon2DRepId(handle, Int32(coedgeIndex), Int32(polygon2DRepId))
    }
    public func setCoEdgePolygonOnTriRepId(_ coedgeIndex: Int, polygonOnTriRepId: Int) {
        OCCTBRepGraphSetCoEdgePolygonOnTriRepId(
            handle, Int32(coedgeIndex), Int32(polygonOnTriRepId))
    }
    public func clearCoEdgePCurveBinding(_ coedgeIndex: Int) {
        OCCTBRepGraphClearCoEdgePCurveBinding(handle, Int32(coedgeIndex))
    }
    public func setWireRefIsOuter(_ wireRefIndex: Int, isOuter: Bool) {
        OCCTBRepGraphSetWireRefIsOuter(handle, Int32(wireRefIndex), isOuter)
    }
    public func setWireRefOrientation(_ wireRefIndex: Int, orientation: Int) {
        OCCTBRepGraphSetWireRefOrientation(handle, Int32(wireRefIndex), Int32(orientation))
    }
    public func setWireRefWireDefId(_ wireRefIndex: Int, wireIndex: Int) {
        OCCTBRepGraphSetWireRefWireDefId(handle, Int32(wireRefIndex), Int32(wireIndex))
    }
    public func setFaceSurfaceRepId(_ faceIndex: Int, surfaceRepId: Int) {
        OCCTBRepGraphSetFaceSurfaceRepId(handle, Int32(faceIndex), Int32(surfaceRepId))
    }
    public func setFaceRefOrientation(_ faceRefIndex: Int, orientation: Int) {
        OCCTBRepGraphSetFaceRefOrientation(handle, Int32(faceRefIndex), Int32(orientation))
    }
    /// Set the face definition index for a face reference.
    ///
    /// - Parameters:
    ///   - faceRefIndex: The face reference index.
    ///   - faceIndex: The face definition index.
    public func setFaceRefFaceDefId(_ faceRefIndex: Int, faceIndex: Int) {
        OCCTBRepGraphSetFaceRefFaceDefId(handle, Int32(faceRefIndex), Int32(faceIndex))
    }
    /// Set the orientation of a shell reference.
    ///
    /// - Parameters:
    ///   - shellRefIndex: The shell reference index.
    ///   - orientation: The orientation value.
    public func setShellRefOrientation(_ shellRefIndex: Int, orientation: Int) {
        OCCTBRepGraphSetShellRefOrientation(handle, Int32(shellRefIndex), Int32(orientation))
    }
    /// Set the shell definition index for a shell reference.
    ///
    /// - Parameters:
    ///   - shellRefIndex: The shell reference index.
    ///   - shellIndex: The shell definition index.
    public func setShellRefShellDefId(_ shellRefIndex: Int, shellIndex: Int) {
        OCCTBRepGraphSetShellRefShellDefId(handle, Int32(shellRefIndex), Int32(shellIndex))
    }
    /// Set the orientation of a solid reference.
    ///
    /// - Parameters:
    ///   - solidRefIndex: The solid reference index.
    ///   - orientation: The orientation value.
    public func setSolidRefOrientation(_ solidRefIndex: Int, orientation: Int) {
        OCCTBRepGraphSetSolidRefOrientation(handle, Int32(solidRefIndex), Int32(orientation))
    }
    /// Set the solid definition index for a solid reference.
    ///
    /// - Parameters:
    ///   - solidRefIndex: The solid reference index.
    ///   - solidIndex: The solid definition index.
    public func setSolidRefSolidDefId(_ solidRefIndex: Int, solidIndex: Int) {
        OCCTBRepGraphSetSolidRefSolidDefId(handle, Int32(solidRefIndex), Int32(solidIndex))
    }
    /// Set the child definition for an occurrence.
    ///
    /// - Parameters:
    ///   - occurrenceIndex: The occurrence index.
    ///   - childKind: The child kind.
    ///   - childIndex: The child index.
    public func setOccurrenceChildDefId(_ occurrenceIndex: Int, childKind: Int, childIndex: Int) {
        OCCTBRepGraphSetOccurrenceChildDefId(
            handle, Int32(occurrenceIndex), Int32(childKind), Int32(childIndex))
    }
    /// Set the occurrence definition index for an occurrence reference.
    ///
    /// - Parameters:
    ///   - occurrenceRefIndex: The occurrence reference index.
    ///   - occurrenceIndex: The occurrence definition index.
    public func setOccurrenceRefOccurrenceDefId(_ occurrenceRefIndex: Int, occurrenceIndex: Int) {
        OCCTBRepGraphSetOccurrenceRefOccurrenceDefId(
            handle, Int32(occurrenceRefIndex), Int32(occurrenceIndex))
    }
    /// Set the orientation of a child reference.
    ///
    /// - Parameters:
    ///   - childRefIndex: The child reference index.
    ///   - orientation: The orientation value.
    public func setChildRefOrientation(_ childRefIndex: Int, orientation: Int) {
        OCCTBRepGraphSetChildRefOrientation(handle, Int32(childRefIndex), Int32(orientation))
    }
    /// Set the child definition for a child reference.
    ///
    /// - Parameters:
    ///   - childRefIndex: The child reference index.
    ///   - childKind: The child kind.
    ///   - childIndex: The child index.
    public func setChildRefChildDefId(_ childRefIndex: Int, childKind: Int, childIndex: Int) {
        OCCTBRepGraphSetChildRefChildDefId(
            handle, Int32(childRefIndex), Int32(childKind), Int32(childIndex))
    }

    // MARK: - EditorView geometric setters & PCurve API (v0.162.0)

    /// Set the UV box (UV1 at ParamFirst, UV2 at ParamLast) of a coedge definition.
    public func setCoEdgeUVBox(_ coedgeIndex: Int, u1: Double, v1: Double, u2: Double, v2: Double) {
        OCCTBRepGraphSetCoEdgeUVBox(handle, Int32(coedgeIndex), u1, v1, u2, v2)
    }

    /// Set the geometric regularity (C^k continuity) for an edge across a pair of faces.
    ///
    /// Pass the same face index as `face1` and `face2` to set the seam continuity across
    /// a closed-surface seam line.
    ///
    /// OCCT 8.0.0 GA reshaped the continuity model: it lives on the (edge, face1, face2)
    /// triple in `BRepGraph_LayerRegularity`, replacing the per-coedge setters present in
    /// pre-1.0 (`setCoEdgeContinuity`, `setCoEdgeSeamContinuity`). The explicit seam-pair-id
    /// setter was removed — seam-pair-id is structural in GA (derived from two coedges on
    /// the same edge/face with opposite orientations).
    ///
    /// - Important: This always returns `false` against OCCT 8.0.0p1 and `continuity` is not
    ///   read at all. `BRepGraph_LayerRegularity` — the only write path in the GA continuity
    ///   model — does not compile in p1 and is absent from `libOCCT`, so the bridge function is a
    ///   stub that reports failure. There is no replacement writer; to *read* continuity, use
    ///   ``Shape/continuity(edge:face1:face2:)`` or ``Shape/maxContinuity(edge:)``, both of which
    ///   go through the shape-based `BRepLib`/`BRep_Tool` path and are unaffected. Tracked
    ///   by #513.
    ///
    /// - Parameters:
    ///   - edgeIndex: The edge index.
    ///   - face1: The first face index.
    ///   - face2: The second face index.
    ///   - continuity: Ignored (see above). Was documented as a GeomAbs_Shape value.
    /// - Returns: Always `false` on OCCT 8.0.0p1.
    @discardableResult
    public func setEdgeRegularity(_ edgeIndex: Int, face1: Int, face2: Int, continuity: Int) -> Bool
    {
        OCCTBRepGraphSetEdgeRegularity(
            handle, Int32(edgeIndex), Int32(face1), Int32(face2), Int32(continuity)) != 0
    }

    /// Set the active triangulation rep on a face (used to bind a fresh triangulation
    /// to the persistent tier; also see `appendCachedTriangulation` for cache-tier writes).
    ///
    public func setFaceTriangulationRep(_ faceIndex: Int, triRepId: Int) {
        OCCTBRepGraphSetFaceTriangulationRep(handle, Int32(faceIndex), Int32(triRepId))
    }

    /// Create a new Curve2DRep from a `Curve2D` and return its rep id, or nil on failure.
    ///
    public func coEdgeCreateCurve2DRep(_ curve2D: Curve2D) -> Int? {
        let id = Int(OCCTBRepGraphCoEdgeCreateCurve2DRep(handle, curve2D.handle))
        return id >= 0 ? id : nil
    }

    /// Assign or clear the PCurve bound to an existing coedge.
    ///
    /// - Parameters:
    ///   - coedgeIndex: The coedge index.
    ///   - curve2D: Pass nil to clear the PCurve binding.
    public func coEdgeSetPCurve(_ coedgeIndex: Int, curve2D: Curve2D?) {
        OCCTBRepGraphCoEdgeSetPCurve(handle, Int32(coedgeIndex), curve2D?.handle)
    }

    /// Attach a PCurve to an edge for a given face context (creates a new CoEdge entry).
    ///
    public func coEdgeAddPCurve(
        edgeIndex: Int, faceIndex: Int, curve2D: Curve2D,
        first: Double, last: Double, orientation: Int = 0
    ) {
        OCCTBRepGraphCoEdgeAddPCurve(
            handle, Int32(edgeIndex), Int32(faceIndex),
            curve2D.handle, first, last, Int32(orientation))
    }

    // Location setters via 12-double 3x4 matrix (gp_Trsf::SetValues convention, row-major).

    private func passLoc(_ matrix: [Double], _ call: (UnsafePointer<Double>) -> Void) {
        precondition(matrix.count == 12, "TopLoc_Location matrix must be 12 doubles (3x4)")
        matrix.withUnsafeBufferPointer { buf in call(buf.baseAddress!) }
    }

    public func setVertexRefLocalLocation(_ vertexRefIndex: Int, matrix: [Double]) {
        passLoc(matrix) {
            OCCTBRepGraphSetVertexRefLocalLocation(handle, Int32(vertexRefIndex), $0)
        }
    }
    public func setCoEdgeRefLocalLocation(_ coedgeRefIndex: Int, matrix: [Double]) {
        passLoc(matrix) {
            OCCTBRepGraphSetCoEdgeRefLocalLocation(handle, Int32(coedgeRefIndex), $0)
        }
    }
    public func setWireRefLocalLocation(_ wireRefIndex: Int, matrix: [Double]) {
        passLoc(matrix) { OCCTBRepGraphSetWireRefLocalLocation(handle, Int32(wireRefIndex), $0) }
    }
    public func setFaceRefLocalLocation(_ faceRefIndex: Int, matrix: [Double]) {
        passLoc(matrix) { OCCTBRepGraphSetFaceRefLocalLocation(handle, Int32(faceRefIndex), $0) }
    }
    public func setShellRefLocalLocation(_ shellRefIndex: Int, matrix: [Double]) {
        passLoc(matrix) { OCCTBRepGraphSetShellRefLocalLocation(handle, Int32(shellRefIndex), $0) }
    }
    public func setSolidRefLocalLocation(_ solidRefIndex: Int, matrix: [Double]) {
        passLoc(matrix) { OCCTBRepGraphSetSolidRefLocalLocation(handle, Int32(solidRefIndex), $0) }
    }
    public func setOccurrenceRefLocalLocation(_ occurrenceRefIndex: Int, matrix: [Double]) {
        passLoc(matrix) {
            OCCTBRepGraphSetOccurrenceRefLocalLocation(handle, Int32(occurrenceRefIndex), $0)
        }
    }
    public func setChildRefLocalLocation(_ childRefIndex: Int, matrix: [Double]) {
        passLoc(matrix) { OCCTBRepGraphSetChildRefLocalLocation(handle, Int32(childRefIndex), $0) }
    }

    /// Identity matrix (3x4) usable with the location setters.
    public static var identityLocationMatrix: [Double] {
        [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
        ]
    }

    // MARK: - EditorView ProductOps assembly building (v0.163.0)

    /// Wrap an existing topology root in a Product.
    ///
    /// Pass nil for an identity placement. Returns the new product id, or nil on failure.
    public func linkProductToTopology(
        shapeRootKind: Int, shapeRootIndex: Int,
        placement: [Double]? = nil
    ) -> Int? {
        let id: Int
        if let placement {
            precondition(placement.count == 12, "placement must be a 3x4 matrix (12 doubles)")
            id = placement.withUnsafeBufferPointer { buf in
                Int(
                    OCCTBRepGraphLinkProductToTopology(
                        handle, Int32(shapeRootKind), Int32(shapeRootIndex), buf.baseAddress))
            }
        } else {
            id = Int(
                OCCTBRepGraphLinkProductToTopology(
                    handle, Int32(shapeRootKind), Int32(shapeRootIndex), nil))
        }
        return id >= 0 ? id : nil
    }

    /// Create an empty product (assembly node with no direct topology).
    ///
    /// Returns product id or nil.
    public func createEmptyProduct() -> Int? {
        let id = Int(OCCTBRepGraphCreateEmptyProduct(handle))
        return id >= 0 ? id : nil
    }

    /// Link two products via a fresh occurrence.
    ///
    /// Returns the new occurrence id and the new occurrence-ref id, or nil on failure.
    /// - Parameters:
    ///   - parentProductIndex: The parent product index.
    ///   - referencedProductIndex: The referenced product index.
    ///   - placement: A 3x4 matrix (12 doubles).
    ///   - parentOccurrenceIndex: Pass nil for an unparented occurrence.
    /// - Returns: A tuple of (occurrenceIndex, occurrenceRefIndex), or nil on failure.
    public func linkProducts(
        parentProductIndex: Int, referencedProductIndex: Int,
        placement: [Double], parentOccurrenceIndex: Int? = nil
    )
        -> (occurrenceIndex: Int, occurrenceRefIndex: Int)?
    {
        precondition(placement.count == 12, "placement must be a 3x4 matrix (12 doubles)")
        var outRef: Int32 = -1
        let oid = placement.withUnsafeBufferPointer { buf -> Int in
            Int(
                OCCTBRepGraphLinkProducts(
                    handle,
                    Int32(parentProductIndex),
                    Int32(referencedProductIndex),
                    buf.baseAddress!,
                    Int32(parentOccurrenceIndex ?? -1),
                    &outRef))
        }
        guard oid >= 0, outRef >= 0 else { return nil }
        return (occurrenceIndex: oid, occurrenceRefIndex: Int(outRef))
    }

    /// Detach an occurrence ref from a product.
    ///
    /// Returns true if the active usage was removed.
    public func productRemoveOccurrence(_ productIndex: Int, occurrenceRefIndex: Int) -> Bool {
        OCCTBRepGraphProductRemoveOccurrence(handle, Int32(productIndex), Int32(occurrenceRefIndex))
    }

    /// Detach the scalar shape-root from a product.
    ///
    /// Returns true if a root was detached.
    public func productRemoveShapeRoot(_ productIndex: Int) -> Bool {
        OCCTBRepGraphProductRemoveShapeRoot(handle, Int32(productIndex))
    }

    // MARK: - EditorView RepOps non-guard setters (v0.164.0)

    /// Swap the surface bound to an existing surface rep id (without recreating the rep).
    public func repSetSurface(_ surfaceRepId: Int, surface: Surface) {
        OCCTBRepGraphRepSetSurface(handle, Int32(surfaceRepId), surface.handle)
    }
    public func repSetCurve3D(_ curve3DRepId: Int, curve: Curve3D) {
        OCCTBRepGraphRepSetCurve3D(handle, Int32(curve3DRepId), curve.handle)
    }
    public func repSetCurve2D(_ curve2DRepId: Int, curve: Curve2D) {
        OCCTBRepGraphRepSetCurve2D(handle, Int32(curve2DRepId), curve.handle)
    }
    public func repSetTriangulation(_ triRepId: Int, triangulation: Triangulation) {
        OCCTBRepGraphRepSetTriangulation(handle, Int32(triRepId), triangulation.handle)
    }
    public func repSetPolygon3D(_ polyRepId: Int, polygon: Polygon3D) {
        OCCTBRepGraphRepSetPolygon3D(handle, Int32(polyRepId), polygon.handle)
    }
    public func repSetPolygon2D(_ polyRepId: Int, polygon: Polygon2D) {
        OCCTBRepGraphRepSetPolygon2D(handle, Int32(polyRepId), polygon.handle)
    }
    public func repSetPolygonOnTri(_ polyRepId: Int, polygon: PolygonOnTriangulation) {
        OCCTBRepGraphRepSetPolygonOnTri(handle, Int32(polyRepId), polygon.handle)
    }
    public func repSetPolygonOnTriTriangulationId(_ polyOnTriRepId: Int, triRepId: Int) {
        OCCTBRepGraphRepSetPolygonOnTriTriangulationId(
            handle, Int32(polyOnTriRepId), Int32(triRepId))
    }

    // MARK: - MeshView cache entry inspection (v0.164.0)

    /// Detailed accessors for the cached-mesh tier (algorithm-derived). All return absent
    /// values (false / 0 / nil) when no cache entry exists for the entity.

    public func cachedFaceMeshIsPresent(_ faceIndex: Int) -> Bool {
        OCCTBRepGraphCachedFaceMeshIsPresent(handle, Int32(faceIndex))
    }
    public func cachedFaceMeshTriRepCount(_ faceIndex: Int) -> Int {
        Int(OCCTBRepGraphCachedFaceMeshTriRepCount(handle, Int32(faceIndex)))
    }
    public func cachedFaceMeshActiveIndex(_ faceIndex: Int) -> Int {
        Int(OCCTBRepGraphCachedFaceMeshActiveIndex(handle, Int32(faceIndex)))
    }
    /// Get the stored owner generation for a face cached mesh.
    ///
    /// - Parameter faceIndex: The face index.
    /// - Returns: The stored owner generation.
    public func cachedFaceMeshStoredOwnGen(_ faceIndex: Int) -> UInt32 {
        OCCTBRepGraphCachedFaceMeshStoredOwnGen(handle, Int32(faceIndex))
    }
    /// Get the triangulation rep id for a face cached mesh.
    ///
    /// - Parameters:
    ///   - faceIndex: The face index.
    ///   - repIndex: The rep index.
    /// - Returns: The triangulation rep id, or nil if not found.
    public func cachedFaceMeshTriRepId(_ faceIndex: Int, repIndex: Int) -> Int? {
        let id = Int(OCCTBRepGraphCachedFaceMeshTriRepId(handle, Int32(faceIndex), Int32(repIndex)))
        return id >= 0 ? id : nil
    }

    /// Check if an edge cached mesh is present.
    ///
    /// - Parameter edgeIndex: The edge index.
    /// - Returns: True if the cached mesh is present.
    public func cachedEdgeMeshIsPresent(_ edgeIndex: Int) -> Bool {
        OCCTBRepGraphCachedEdgeMeshIsPresent(handle, Int32(edgeIndex))
    }
    /// Get the polygon-3D rep id for an edge cached mesh.
    ///
    /// - Parameter edgeIndex: The edge index.
    /// - Returns: The polygon-3D rep id, or nil if not found.
    public func cachedEdgeMeshPolygon3DRepId(_ edgeIndex: Int) -> Int? {
        let id = Int(OCCTBRepGraphCachedEdgeMeshPolygon3DRepId(handle, Int32(edgeIndex)))
        return id >= 0 ? id : nil
    }
    /// Get the stored owner generation for an edge cached mesh.
    ///
    /// - Parameter edgeIndex: The edge index.
    /// - Returns: The stored owner generation.
    public func cachedEdgeMeshStoredOwnGen(_ edgeIndex: Int) -> UInt32 {
        OCCTBRepGraphCachedEdgeMeshStoredOwnGen(handle, Int32(edgeIndex))
    }

    /// Check if a coedge cached mesh is present.
    ///
    /// - Parameter coedgeIndex: The coedge index.
    /// - Returns: True if the cached mesh is present.
    public func cachedCoEdgeMeshIsPresent(_ coedgeIndex: Int) -> Bool {
        OCCTBRepGraphCachedCoEdgeMeshIsPresent(handle, Int32(coedgeIndex))
    }
    /// Get the polygon-2D rep id for a coedge cached mesh.
    ///
    /// - Parameter coedgeIndex: The coedge index.
    /// - Returns: The polygon-2D rep id, or nil if not found.
    public func cachedCoEdgeMeshPolygon2DRepId(_ coedgeIndex: Int) -> Int? {
        let id = Int(OCCTBRepGraphCachedCoEdgeMeshPolygon2DRepId(handle, Int32(coedgeIndex)))
        return id >= 0 ? id : nil
    }
    /// Get the polygon-on-triangulation rep count for a coedge cached mesh.
    ///
    /// - Parameter coedgeIndex: The coedge index.
    /// - Returns: The polygon-on-triangulation rep count.
    public func cachedCoEdgeMeshPolygonOnTriRepCount(_ coedgeIndex: Int) -> Int {
        Int(OCCTBRepGraphCachedCoEdgeMeshPolygonOnTriRepCount(handle, Int32(coedgeIndex)))
    }
    /// Get the polygon-on-triangulation rep id for a coedge cached mesh.
    ///
    /// - Parameters:
    ///   - coedgeIndex: The coedge index.
    ///   - repIndex: The rep index.
    /// - Returns: The polygon-on-triangulation rep id, or nil if not found.
    public func cachedCoEdgeMeshPolygonOnTriRepId(_ coedgeIndex: Int, repIndex: Int) -> Int? {
        let id = Int(
            OCCTBRepGraphCachedCoEdgeMeshPolygonOnTriRepId(
                handle, Int32(coedgeIndex), Int32(repIndex)))
        return id >= 0 ? id : nil
    }
    /// Get the stored owner generation for a coedge cached mesh.
    ///
    /// - Parameter coedgeIndex: The coedge index.
    /// - Returns: The stored owner generation.
    public func cachedCoEdgeMeshStoredOwnGen(_ coedgeIndex: Int) -> UInt32 {
        OCCTBRepGraphCachedCoEdgeMeshStoredOwnGen(handle, Int32(coedgeIndex))
    }

    // MARK: - UV-Grid Sampling (v0.136.0)

    /// Result of sampling a face surface on a regular UV grid.
    ///
    /// All four parallel arrays share one layout: **U-major**, u varying slowest and v fastest,
    /// so the sample at grid position `(u, v)` lives at flat index `u * vSamples + v` — the same
    /// index ``SurfaceGrid`` and ``SurfaceGridD1`` use (#404/#486).
    ///
    /// Prefer ``at(u:v:)`` over spelling the index out, because the two ways to get it wrong fail
    /// differently and neither announces itself:
    ///
    /// - Using the layout but the **wrong count as the stride** (`u * uSamples + v`) is correct
    ///   only on a square grid, where the two counts coincide. On a non-square grid it is in
    ///   range and quietly wrong when `uSamples < vSamples` (3x10 reaches 15 of 30), and past the
    ///   end when `uSamples > vSamples` (10x3 reaches 92 of 30).
    /// - Reading with the **transposed index** (`v * uSamples + u`) never traps at any aspect
    ///   ratio: it is a bijection onto the same `0..<uSamples * vSamples` range, so it can only
    ///   ever be a silent wrong answer. That was the layout this buffer was written in until
    ///   #617.
    ///
    /// ```swift
    /// guard let sample = graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 10, vSamples: 3)
    /// else { return }
    /// // Flat storage is U-major: index (u, v) == u * sample.vSamples + v.
    /// let s = sample.at(u: 9, v: 2)
    /// print(s.position, s.normal, s.gaussianCurvature, s.meanCurvature)
    ///
    /// // Walk the grid row by row (u outer, v inner) to read the buffers in storage order.
    /// for u in 0..<sample.uSamples {
    ///     for v in 0..<sample.vSamples {
    ///         let mean = sample.at(u: u, v: v).meanCurvature
    ///         if abs(mean) > 1e-6 { print("curved at (\(u), \(v)): \(mean)") }
    ///     }
    /// }
    /// ```
    public struct FaceGridSample: Sendable {
        /// Surface positions at grid points, U-major (see ``at(u:v:)``).
        public let positions: [SIMD3<Double>]
        /// Surface normals at grid points, U-major (see ``at(u:v:)``).
        public let normals: [SIMD3<Double>]
        /// Gaussian curvature at each grid point, U-major (see ``at(u:v:)``).
        public let gaussianCurvatures: [Double]
        /// Mean curvature at each grid point, U-major (see ``at(u:v:)``).
        public let meanCurvatures: [Double]
        /// Number of samples in U direction.
        public let uSamples: Int
        /// Number of samples in V direction.
        public let vSamples: Int

        /// Position, normal and curvatures at the given U/V grid index.
        ///
        /// The counterpart of ``SurfaceGrid/at(u:v:)``, resolving the same U-major index through
        /// the same shared `surfaceGridIndex` helper, so the two grid families cannot drift apart
        /// again (#617).
        ///
        /// ```swift
        /// if let sample = graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 3, vSamples: 10) {
        ///     let corner = sample.at(u: 2, v: 9)
        ///     print(corner.position, corner.meanCurvature)
        /// }
        /// ```
        ///
        /// - Parameters:
        ///   - u: U grid index, `0..<uSamples`.
        ///   - v: V grid index, `0..<vSamples`.
        /// - Returns: A tuple of (position, normal, gaussianCurvature, meanCurvature).
        public func at(u: Int, v: Int) -> (
            position: SIMD3<Double>, normal: SIMD3<Double>,
            gaussianCurvature: Double, meanCurvature: Double
        ) {
            precondition(
                u >= 0 && u < uSamples && v >= 0 && v < vSamples,
                "FaceGridSample.at(u: \(u), v: \(v)) out of range "
                    + "(uSamples: \(uSamples), vSamples: \(vSamples))")
            let i = surfaceGridIndex(u: u, v: v, vCount: vSamples)
            // The buffers carry the count the bridge actually wrote, which #419 deliberately does
            // not assume equals uSamples * vSamples — so the grid bounds above are necessary but
            // not sufficient.
            precondition(
                i < positions.count,
                "FaceGridSample.at(u: \(u), v: \(v)) names index \(i), but only "
                    + "\(positions.count) samples were written")
            return (
                position: positions[i], normal: normals[i],
                gaussianCurvature: gaussianCurvatures[i], meanCurvature: meanCurvatures[i]
            )
        }
    }

    /// Sample a face surface on a regular UV grid, evaluating positions, normals, and curvatures.
    ///
    /// The returned buffers are **U-major** (`u * vSamples + v`); read them through
    /// ``FaceGridSample/at(u:v:)`` rather than indexing by hand.
    ///
    /// ```swift
    /// guard let graph = BRepGraph(shape: solid),
    ///       let sample = graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 10, vSamples: 3)
    /// else { return }
    /// let midpoint = sample.at(u: 5, v: 1)
    /// print(midpoint.position, midpoint.gaussianCurvature)
    /// ```
    ///
    /// - Parameters:
    ///   - faceIndex: Face definition index.
    ///   - uSamples: Number of samples in U direction (must be >= 1).
    ///   - vSamples: Number of samples in V direction (must be >= 1).
    /// - Returns: Grid sample data, or nil if face has no surface, sampling fails, or the grid
    ///   cannot be served: the bound is on the **product**, which must not exceed
    ///   ``Sampling/maximumSampleCount`` (#558). This sampler fills four buffers per point
    ///   (position, normal, Gaussian and mean curvature), so it reaches the ceiling's memory cost
    ///   sooner than the point-only samplers do.
    public func sampleFaceUVGrid(faceIndex: Int, uSamples: Int, vSamples: Int) -> FaceGridSample? {
        guard let total = Sampling.gridTotal(uSamples, vSamples) else { return nil }
        var posBuffer = [Double](repeating: 0, count: total * 3)
        var nrmBuffer = [Double](repeating: 0, count: total * 3)
        var gaussBuffer = [Double](repeating: 0, count: total)
        var meanBuffer = [Double](repeating: 0, count: total)

        let result = posBuffer.withUnsafeMutableBufferPointer { posBuf in
            nrmBuffer.withUnsafeMutableBufferPointer { nrmBuf in
                gaussBuffer.withUnsafeMutableBufferPointer { gaussBuf in
                    meanBuffer.withUnsafeMutableBufferPointer { meanBuf in
                        OCCTBRepGraphSampleFaceUVGrid(
                            handle, Int32(faceIndex),
                            Int32(uSamples), Int32(vSamples),
                            posBuf.baseAddress!, nrmBuf.baseAddress!,
                            gaussBuf.baseAddress!, meanBuf.baseAddress!)
                    }
                }
            }
        }

        guard result > 0 else { return nil }

        // Unpack only the actually-written count (`result`), not the requested `total` — today
        // the bridge is all-or-nothing so the two coincide, but nothing should assume that stays
        // true (see #419). Truncate the scalar buffers to match for the same reason: all four
        // outputs must agree on how many samples are actually valid.
        let written = Int(result)
        let positions: [SIMD3<Double>] = unpackSIMD3(posBuffer, count: written)
        let normals: [SIMD3<Double>] = unpackSIMD3(nrmBuffer, count: written)

        return FaceGridSample(
            positions: positions,
            normals: normals,
            gaussianCurvatures: Array(gaussBuffer.prefix(written)),
            meanCurvatures: Array(meanBuffer.prefix(written)),
            uSamples: uSamples,
            vSamples: vSamples
        )
    }

    // MARK: - Edge Curve Sampling (v0.136.0)

    /// Sample evenly-spaced points along an edge curve.
    /// - Parameters:
    ///   - edgeIndex: Edge definition index.
    ///   - count: Number of points to sample, honoured within `1...`
    ///     ``Sampling/maximumSampleCount``; outside that range the result is empty (#558).
    /// - Returns: Array of 3D points along the edge, empty if edge has no curve.
    public func sampleEdgeCurve(edgeIndex: Int, count: Int) -> [SIMD3<Double>] {
        guard let count = Sampling.requested(count, atLeast: 1) else { return [] }
        var buffer = [Double](repeating: 0, count: count * 3)
        let result = buffer.withUnsafeMutableBufferPointer { buf in
            OCCTBRepGraphSampleEdgeCurve(handle, Int32(edgeIndex), Int32(count), buf.baseAddress!)
        }
        guard result > 0 else { return [] }
        return unpackSIMD3(buffer, count: Int(result))
    }

    // MARK: - Durable Identity (UID / RefUID / ItemUID) — OCCT 8.0.0p1

    /// A durable node identifier: a `(kind, counter)` pair that persists across mutations of
    /// **the one graph instance that minted it** — compaction, node removal — where a
    /// `(kind, index)` ``NodeRef`` does not.
    ///
    /// The counter never repeats within a kind and is stable when vector indices shift.
    /// `counter == 0` is the invalid sentinel.
    ///
    /// The scope is the graph *instance*, not the shape and not a "generation". Every graph
    /// allocates counters from 1 independently, so the same `(kind, counter)` names some
    /// unrelated node in every other graph — a box's face UID would otherwise resolve happily
    /// against a cylinder. ``graphID`` records which instance minted the UID, and
    /// ``BRepGraph/node(forUID:)`` rejects one that came from anywhere else (#295).
    ///
    /// To carry a selection across a *modelling operation* rather than across mutations of one
    /// graph, absorb the operation's history — see
    /// ``BRepGraph/add(_:absorbing:inputRoots:operationName:)``.
    ///
    /// `kind` is the raw `BRepGraph_NodeId::Kind` ordinal
    /// (0 Solid, 1 Shell, 2 Face, 3 Wire, 4 Edge, 5 Vertex, 6 Compound,
    /// 7 CompSolid, 8 CoEdge, 10 Product, 11 Occurrence).
    ///
    /// ```swift
    /// let graph = BRepGraph(shape: box)!
    /// let uid = graph.uid(ofNodeKind: 2, index: 3)!    // a face, by kind + index
    ///
    /// // The UID still names that face after a mutation renumbers the indices:
    /// graph.compact()
    /// if let node = graph.node(forUID: uid) {
    ///     print("that face is now index \(node.index)")
    /// }
    ///
    /// // A UID from another graph resolves to nothing, rather than to a wrong node:
    /// let other = BRepGraph(shape: cylinder)!
    /// print(other.node(forUID: uid))      // nil
    /// print(other.contains(uid: uid))     // false
    /// ```
    public struct GraphUID: Sendable, Hashable, Codable {
        public let kind: Int
        public let counter: UInt32

        /// The instance that minted this UID — its ``BRepGraph/instanceID``.
        ///
        /// `0` means unstamped: built by hand, or decoded from a payload written before
        /// OCCTSwift recorded provenance. An unstamped UID resolves in no graph.
        public let graphID: UInt64

        internal init(kind: Int, counter: UInt32, graphID: UInt64) {
            self.kind = kind
            self.counter = counter
            self.graphID = graphID
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            kind = try c.decode(Int.self, forKey: .kind)
            counter = try c.decode(UInt32.self, forKey: .counter)
            // Payloads written before #295 have no graphID. Decode them as unstamped instead of
            // failing the load: they resolve nowhere, which is the honest answer, since they never
            // carried the provenance that says which graph they meant.
            graphID = try c.decodeIfPresent(UInt64.self, forKey: .graphID) ?? 0
        }

        /// True if this UID has a non-zero counter.
        ///
        /// It may still fail to resolve — because it was minted by a different graph,
        /// or because its node has since been removed.
        public var isValid: Bool { counter > 0 }
    }

    /// A durable reference-entry identifier `(kind, counter)`.
    ///
    /// Scoped to one graph instance exactly as ``GraphUID`` is, and stamped with ``graphID`` for
    /// the same reason: reference counters also restart at 1 per graph.
    ///
    /// `kind` is the raw `BRepGraph_RefId::Kind` ordinal
    /// (0 Shell, 1 Face, 2 Wire, 3 Vertex, 4 Solid, 5 Child, 6 Occurrence).
    ///
    /// ```swift
    /// let graph = BRepGraph(shape: assembly)!
    /// if let uid = graph.uid(ofRefKind: 1, index: 0),      // a face reference
    ///    let ref = graph.ref(forUID: uid) {
    ///     print("face ref at index \(ref.index)")
    /// }
    /// ```
    public struct GraphRefUID: Sendable, Hashable, Codable {
        public let kind: Int
        public let counter: UInt32

        /// The instance that minted this UID — its ``BRepGraph/instanceID``.
        ///
        /// `0` means unstamped, which resolves in no graph. See ``GraphUID/graphID``.
        public let graphID: UInt64

        internal init(kind: Int, counter: UInt32, graphID: UInt64) {
            self.kind = kind
            self.counter = counter
            self.graphID = graphID
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            kind = try c.decode(Int.self, forKey: .kind)
            counter = try c.decode(UInt32.self, forKey: .counter)
            graphID = try c.decodeIfPresent(UInt64.self, forKey: .graphID) ?? 0
        }

        public var isValid: Bool { counter > 0 }
    }

    /// A durable generic item identifier covering both definition nodes and reference
    /// entries. `domain` is 1 for a node, 2 for a reference; `kind` is the raw kind
    /// ordinal in that domain's enum space.
    ///
    /// Scoped to one graph instance and stamped with ``graphID``, exactly as ``GraphUID`` is.
    ///
    /// ```swift
    /// let graph = BRepGraph(shape: box)!
    /// if let uid = graph.itemUID(ofNodeKind: 2, index: 0),
    ///    let item = graph.item(forUID: uid) {
    ///     print("domain \(item.domain) kind \(item.kind) index \(item.index)")
    /// }
    /// ```
    public struct GraphItemUID: Sendable, Hashable, Codable {
        public let domain: Int
        public let kind: Int
        public let counter: UInt32

        /// The instance that minted this UID — its ``BRepGraph/instanceID``.
        ///
        /// `0` means unstamped, which resolves in no graph. See ``GraphUID/graphID``.
        public let graphID: UInt64

        internal init(domain: Int, kind: Int, counter: UInt32, graphID: UInt64) {
            self.domain = domain
            self.kind = kind
            self.counter = counter
            self.graphID = graphID
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            domain = try c.decode(Int.self, forKey: .domain)
            kind = try c.decode(Int.self, forKey: .kind)
            counter = try c.decode(UInt32.self, forKey: .counter)
            graphID = try c.decodeIfPresent(UInt64.self, forKey: .graphID) ?? 0
        }

        public var isValid: Bool { counter > 0 }
    }

    /// Return the durable UID for a node, or `nil` if the node is invalid/removed/out of bounds.
    ///
    /// - Parameters:
    ///   - kind: raw `BRepGraph_NodeId::Kind` ordinal (e.g. 2 = Face).
    ///   - index: per-kind node index.
    /// - Returns: The GraphUID, or nil if the node is invalid/removed/out of bounds.
    public func uid(ofNodeKind kind: Int, index: Int) -> GraphUID? {
        var uidKind: Int32 = 0
        var counter: UInt32 = 0
        guard OCCTBRepGraphNodeUID(handle, Int32(kind), Int32(index), &uidKind, &counter) else {
            return nil
        }
        return GraphUID(kind: Int(uidKind), counter: counter, graphID: instanceID)
    }

    /// Resolve a node UID back to its `(kind, index)`, or `nil` if this graph did not mint it
    /// or its node no longer exists here.
    ///
    /// A UID minted by another graph returns `nil` even when its counter is in range for this
    /// one — which it usually is, since counters restart per graph (#295).
    public func node(forUID uid: GraphUID) -> (kind: Int, index: Int)? {
        guard uid.graphID == instanceID else { return nil }
        var nodeKind: Int32 = 0
        var nodeIndex: Int32 = 0
        guard OCCTBRepGraphNodeFromUID(handle, Int32(uid.kind), uid.counter, &nodeKind, &nodeIndex)
        else { return nil }
        return (Int(nodeKind), Int(nodeIndex))
    }

    /// True if this graph minted the UID and the node it names still exists here.
    public func contains(uid: GraphUID) -> Bool {
        guard uid.graphID == instanceID else { return false }
        return OCCTBRepGraphHasNodeUID(handle, Int32(uid.kind), uid.counter)
    }

    /// Return the durable RefUID for a reference entry, or `nil` if invalid/removed.
    ///
    /// - Parameters:
    ///   - kind: raw `BRepGraph_RefId::Kind` ordinal.
    ///   - index: per-kind reference index.
    /// - Returns: The GraphRefUID, or nil if invalid/removed.
    public func uid(ofRefKind kind: Int, index: Int) -> GraphRefUID? {
        var uidKind: Int32 = 0
        var counter: UInt32 = 0
        guard OCCTBRepGraphRefUID(handle, Int32(kind), Int32(index), &uidKind, &counter) else {
            return nil
        }
        return GraphRefUID(kind: Int(uidKind), counter: counter, graphID: instanceID)
    }

    /// Resolve a RefUID back to its `(kind, index)`, or `nil` if this graph did not mint it
    /// or the reference no longer exists here.
    public func ref(forUID uid: GraphRefUID) -> (kind: Int, index: Int)? {
        guard uid.graphID == instanceID else { return nil }
        var refKind: Int32 = 0
        var refIndex: Int32 = 0
        guard OCCTBRepGraphRefFromUID(handle, Int32(uid.kind), uid.counter, &refKind, &refIndex)
        else { return nil }
        return (Int(refKind), Int(refIndex))
    }

    /// True if this graph minted the RefUID and the reference it names still exists here.
    public func contains(uid: GraphRefUID) -> Bool {
        guard uid.graphID == instanceID else { return false }
        return OCCTBRepGraphHasRefUID(handle, Int32(uid.kind), uid.counter)
    }

    /// Return the durable ItemUID for a node, or `nil` if invalid/removed.
    public func itemUID(ofNodeKind kind: Int, index: Int) -> GraphItemUID? {
        var domain: Int32 = 0
        var itemKind: Int32 = 0
        var counter: UInt32 = 0
        guard
            OCCTBRepGraphItemUIDOfNode(
                handle, Int32(kind), Int32(index), &domain, &itemKind, &counter)
        else { return nil }
        return GraphItemUID(
            domain: Int(domain), kind: Int(itemKind), counter: counter, graphID: instanceID)
    }

    /// Resolve an ItemUID back to its `(domain, kind, index)`, or `nil` if this graph did not
    /// mint it or the item no longer exists here.
    public func item(forUID uid: GraphItemUID) -> (domain: Int, kind: Int, index: Int)? {
        guard uid.graphID == instanceID else { return nil }
        var domain: Int32 = 0
        var itemKind: Int32 = 0
        var index: Int32 = 0
        guard
            OCCTBRepGraphItemFromUID(
                handle, Int32(uid.domain), Int32(uid.kind), uid.counter, &domain, &itemKind, &index)
        else { return nil }
        return (Int(domain), Int(itemKind), Int(index))
    }

    /// True if this graph minted the ItemUID and the item it names still exists here.
    public func contains(uid: GraphItemUID) -> Bool {
        guard uid.graphID == instanceID else { return false }
        return OCCTBRepGraphHasItemUID(handle, Int32(uid.domain), Int32(uid.kind), uid.counter)
    }

    /// Identifies this graph instance for as long as it lives.
    ///
    /// Unique among every graph this process builds, and — because the sequence starts at a random
    /// point — distinct from any other process's ids with overwhelming probability. Every UID this
    /// graph mints carries it, which is how ``node(forUID:)`` tells one of its own nodes from a node
    /// of some other graph (#295).
    ///
    /// Identity here is the graph object, not the geometry: two graphs built from the same shape
    /// have different ids, and so a UID from one does not resolve in the other. A rebuild is a new
    /// graph by the same token.
    ///
    /// ``copy()`` and ``translated(dx:dy:dz:copyGeometry:)`` **inherit** this id, because the kernel
    /// copies the graph wholesale — it transplants the UID counter space itself, so a copy genuinely
    /// is the same identity and every UID keeps naming the same node. ``copyFace(_:copyGeometry:)``
    /// does not: it lifts one face into a new graph, which gets its own id.
    ///
    /// ```swift
    /// let graph = BRepGraph(shape: box)!
    /// let uid = graph.uid(ofNodeKind: 2, index: 0)!
    /// print(uid.graphID == graph.instanceID)      // true — this graph minted it
    ///
    /// let copy = graph.copy()!
    /// print(copy.instanceID == graph.instanceID)  // true — a copy is the same identity
    /// print(copy.node(forUID: uid) != nil)        // true — and names the same face
    ///
    /// let rebuilt = BRepGraph(shape: box)!    // same shape, new graph
    /// print(rebuilt.node(forUID: uid))            // nil
    /// ```
    public var instanceID: UInt64 {
        OCCTBRepGraphInstanceID(handle)
    }

}
