---
title: TopologyGraph
parent: API Reference
---

# TopologyGraph

`TopologyGraph` is OCCTSwift's graph-based view of B-Rep topology, wrapping OCCT's `BRepGraph` package. It indexes all faces, edges, vertices, wires, shells, solids, coedges, and compounds of a `Shape` as flat integer-indexed entity vectors with O(1) cross-references, enabling cache-friendly traversal, fast adjacency queries, and parallel geometry extraction. Obtain one via `TopologyGraph(shape:)`.

> **TopologyGraph is large — documented across several pages.** This is the core (construction, counts, topology queries, explorers, validate/compact/deduplicate, statistics, geometry readback); see the other **TopologyGraph — …** pages for topology detail/history/mesh, builders & editor mutation, editor geometry/sampling/durable-identity, and attributes/snapshots/references.

## Topics

- [Lifecycle](#lifecycle) · [Topology Counts](#topology-counts) · [Geometry Counts](#geometry-counts) · [Face Queries](#face-queries) · [Edge Queries](#edge-queries) · [Vertex Queries](#vertex-queries) · [Explorers](#explorers) · [Node Status](#node-status) · [Root Nodes](#root-nodes) · [Validate](#validate) · [Compact](#compact) · [Deduplicate](#deduplicate) · [Statistics](#statistics) · [Shape Reconstruction](#shape-reconstruction) · [Vertex Geometry](#vertex-geometry) · [Edge Geometry](#edge-geometry) · [Face Geometry](#face-geometry) · [Wire Queries](#wire-queries)

---

## Lifecycle

### `attributes`

Per-node attribute store for arbitrary typed metadata keyed by `NodeRef`.

```swift
public var attributes = NodeAttributeStore()
```

Holds fit residuals, provenance, mesh-region sets, and other sidecar data. Pure Swift; never touches the underlying C++ graph. Serialized via `snapshot()` / `init(snapshot:)`.

---

### `init?(shape:parallel:)`

Build a topology graph from a shape.

```swift
public init?(shape: Shape, parallel: Bool = false)
```

Ingests the shape's full B-Rep topology into an indexed graph. Pass `parallel: true` to build using multi-threaded traversal (faster for large shapes; not safe to call concurrently with other graph ops).

- **Parameters:** `shape` — the shape to analyze; `parallel` — whether to use parallel construction (default: `false`).
- **Returns:** A fully built `TopologyGraph`, or `nil` if ingestion fails.
- **OCCT:** `BRepGraph::ShapesView::Add(shape, opts)` with `opts.Parallel` set accordingly.
- **Example:**
  ```swift
  if let box = Shape.box(width: 10, height: 10, depth: 10),
     let graph = TopologyGraph(shape: box) {
      print(graph.faceCount)   // 6
      print(graph.edgeCount)   // 12
      print(graph.vertexCount) // 8
  }
  ```

---

### `deinit`

Releases the underlying OCCT graph handle.

```swift
deinit
```

- **OCCT:** `OCCTBRepGraphRelease` → `delete` the `OCCTBRepGraph` C++ struct.

---

## Topology Counts

### `nodeCount`

Total number of nodes in the graph (all entity kinds).

```swift
public var nodeCount: Int { get }
```

- **OCCT:** `BRepGraph::TopoView::Gen().NbNodes()`.

---

### `faceCount`

Number of faces.

```swift
public var faceCount: Int { get }
```

- **OCCT:** `BRepGraph::TopoView::Faces().Nb()`.

---

### `activeFaceCount`

Number of active (non-removed) faces.

```swift
public var activeFaceCount: Int { get }
```

Removed faces (soft-deleted by editor operations) are excluded. See `compact()` to permanently purge them.

- **OCCT:** `BRepGraph::TopoView::Faces().NbActive()`.

---

### `edgeCount`

Number of edges.

```swift
public var edgeCount: Int { get }
```

- **OCCT:** `BRepGraph::TopoView::Edges().Nb()`.

---

### `activeEdgeCount`

Number of active (non-removed) edges.

```swift
public var activeEdgeCount: Int { get }
```

- **OCCT:** `BRepGraph::TopoView::Edges().NbActive()`.

---

### `vertexCount`

Number of vertices.

```swift
public var vertexCount: Int { get }
```

- **OCCT:** `BRepGraph::TopoView::Vertices().Nb()`.

---

### `activeVertexCount`

Number of active (non-removed) vertices.

```swift
public var activeVertexCount: Int { get }
```

- **OCCT:** `BRepGraph::TopoView::Vertices().NbActive()`.

---

### `wireCount`

Number of wires.

```swift
public var wireCount: Int { get }
```

- **OCCT:** `BRepGraph::TopoView::Wires().Nb()`.

---

### `shellCount`

Number of shells.

```swift
public var shellCount: Int { get }
```

- **OCCT:** `BRepGraph::TopoView::Shells().Nb()`.

---

### `solidCount`

Number of solids.

```swift
public var solidCount: Int { get }
```

- **OCCT:** `BRepGraph::TopoView::Solids().Nb()`.

---

### `coedgeCount`

Number of coedges (half-edges).

```swift
public var coedgeCount: Int { get }
```

Each coedge is the directed use of an edge within a specific wire/face context; a manifold edge has exactly two coedges.

- **OCCT:** `BRepGraph::TopoView::CoEdges().Nb()`.

---

### `compoundCount`

Number of compounds.

```swift
public var compoundCount: Int { get }
```

- **OCCT:** `BRepGraph::TopoView::Compounds().Nb()`.

---

## Geometry Counts

### `surfaceCount`

Number of distinct surfaces.

```swift
public var surfaceCount: Int { get }
```

Counts unique surface definitions after deduplication (if `deduplicate()` has been called, duplicates are collapsed to one canonical surface).

- **OCCT:** `BRepGraph::TopoView::Geometry().NbFaceSurfaces()`.

---

### `curve3DCount`

Number of distinct 3D curves.

```swift
public var curve3DCount: Int { get }
```

- **OCCT:** `BRepGraph::TopoView::Geometry().NbEdgeCurves3D()`.

---

### `curve2DCount`

Number of distinct 2D curves (pcurves).

```swift
public var curve2DCount: Int { get }
```

- **OCCT:** `BRepGraph::TopoView::Geometry().NbCoEdgeCurves2D()`.

---

## Face Queries

### `adjacentFaces(of:)`

Indices of faces adjacent to a given face (sharing an edge).

```swift
public func adjacentFaces(of faceIndex: Int) -> [Int]
```

- **Parameters:** `faceIndex` — zero-based face index.
- **Returns:** Array of face indices that share at least one edge with the given face.
- **OCCT:** Derived from `BRepGraph_FacesOfEdge` iteration over all edges — two faces are adjacent iff they share an edge.
- **Example:**
  ```swift
  if let box = Shape.box(width: 10, height: 10, depth: 10),
     let graph = TopologyGraph(shape: box) {
      let neighbors = graph.adjacentFaces(of: 0)
      // neighbors has 4 entries for a box face
  }
  ```

---

### `sharedEdges(between:and:)`

Indices of edges shared between two faces.

```swift
public func sharedEdges(between faceA: Int, and faceB: Int) -> [Int]
```

- **Parameters:** `faceA`, `faceB` — zero-based face indices.
- **Returns:** Edge indices belonging to both faces.
- **OCCT:** Derived from `BRepGraph_FacesOfEdge` iteration.
- **Example:**
  ```swift
  let shared = graph.sharedEdges(between: 0, and: 1)
  ```

---

### `outerWire(of:)`

Index of the outer wire of a face.

```swift
public func outerWire(of faceIndex: Int) -> Int
```

- **Parameters:** `faceIndex` — zero-based face index.
- **Returns:** Wire index of the outer (boundary) wire, or `-1` if not found.
- **OCCT:** `BRepGraph_Tool::Face::OuterWire()`.

---

## Edge Queries

### `faceCount(of:)`

Number of faces an edge belongs to.

```swift
public func faceCount(of edgeIndex: Int) -> Int
```

- **Parameters:** `edgeIndex` — zero-based edge index.
- **Returns:** 1 for boundary edges, 2 for manifold edges, ≥3 for non-manifold.
- **OCCT:** `BRepGraph::TopoView::Edges().NbFaces()`.

---

### `faces(of:)`

Indices of faces an edge belongs to.

```swift
public func faces(of edgeIndex: Int) -> [Int]
```

- **Parameters:** `edgeIndex` — zero-based edge index.
- **Returns:** Array of face indices that own this edge.
- **OCCT:** `BRepGraph_FacesOfEdge` iterator.

---

### `isBoundaryEdge(_:)`

Whether an edge is a boundary edge (belongs to only one face).

```swift
public func isBoundaryEdge(_ edgeIndex: Int) -> Bool
```

- **Parameters:** `edgeIndex` — zero-based edge index.
- **OCCT:** `BRepGraph_Tool::Edge::IsBoundary()`.

---

### `isManifoldEdge(_:)`

Whether an edge is manifold (belongs to exactly two faces).

```swift
public func isManifoldEdge(_ edgeIndex: Int) -> Bool
```

- **Parameters:** `edgeIndex` — zero-based edge index.
- **OCCT:** `BRepGraph_Tool::Edge::IsManifold()`.

---

### `adjacentEdges(of:)`

Indices of edges adjacent to a given edge (sharing a vertex).

```swift
public func adjacentEdges(of edgeIndex: Int) -> [Int]
```

- **Parameters:** `edgeIndex` — zero-based edge index.
- **Returns:** Edge indices that share at least one vertex with the given edge.
- **OCCT:** Derived from `BRepGraph::TopoView::Vertices().Edges()` incidence.

---

## Vertex Queries

### `edges(of:)`

Indices of edges connected to a vertex.

```swift
public func edges(of vertexIndex: Int) -> [Int]
```

- **Parameters:** `vertexIndex` — zero-based vertex index.
- **Returns:** Edge indices incident on this vertex.
- **OCCT:** `BRepGraph::TopoView::Vertices().Edges()`.
- **Example:**
  ```swift
  let edgesAtCorner = graph.edges(of: 0)
  // 3 edges for a box corner vertex
  ```

---

## Explorers

### `NodeKind`

Node kind enumeration matching `BRepGraph_NodeId::Kind`.

```swift
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
```

Topology kinds 0–5 are the core B-Rep hierarchy; 6/7 are containers; 8 is the face-context coedge entity. Assembly kinds (`product`, `occurrence`) start at 10; slot 9 is reserved. Matches `BRepGraph_NodeId::Kind` raw values.

---

### `childCount(rootKind:rootIndex:targetKind:)`

Count descendant nodes of a given kind from a root node.

```swift
public func childCount(rootKind: NodeKind, rootIndex: Int, targetKind: NodeKind) -> Int
```

Traverses the topology hierarchy downward from the specified root node and counts all reachable nodes of `targetKind`.

- **Parameters:** `rootKind` — kind of the starting node; `rootIndex` — its zero-based index; `targetKind` — kind to count.
- **Returns:** Number of reachable descendant nodes.
- **OCCT:** `BRepGraph_ChildExplorer(graph, root, targetKind)`.
- **Example:**
  ```swift
  // How many faces does solid 0 contain?
  let faceCount = graph.childCount(rootKind: .solid, rootIndex: 0, targetKind: .face)
  ```

---

### `parentCount(nodeKind:nodeIndex:)`

Count parent nodes of a given node.

```swift
public func parentCount(nodeKind: NodeKind, nodeIndex: Int) -> Int
```

Traverses upward in the topology hierarchy and counts all parent nodes of the given node.

- **Parameters:** `nodeKind` — kind of the node; `nodeIndex` — its zero-based index.
- **Returns:** Number of parent nodes.
- **OCCT:** `BRepGraph_ParentExplorer(graph, node)`.

---

## Node Status

### `isRemoved(nodeKind:nodeIndex:)`

Check if a node has been soft-removed.

```swift
public func isRemoved(nodeKind: NodeKind, nodeIndex: Int) -> Bool
```

Soft-removed nodes are logically deleted but remain in the flat index until `compact()` is called. Active counts (`activeFaceCount`, etc.) exclude them.

- **Parameters:** `nodeKind` — kind of the node; `nodeIndex` — its zero-based index.
- **OCCT:** `BRepGraph::TopoView::Gen().IsRemoved(nid)`.

---

## Root Nodes

### `RootNode`

Root node as a (kind, index) pair.

```swift
public struct RootNode: Sendable {
    public let kind: NodeKind
    public let index: Int
}
```

Returned by `rootNodes` to identify the top-level product or topology entries of the graph.

---

### `rootNodes`

Root nodes of the graph.

```swift
public var rootNodes: [RootNode] { get }
```

For a shape built without assembly context (`CreateAutoProduct: false`), root nodes reflect the top-level topology of the original shape (solids, shells, or compounds). Each element carries both a `NodeKind` and its zero-based index.

- **OCCT:** `BRepGraph::RootProductIds()`.
- **Example:**
  ```swift
  for root in graph.rootNodes {
      print("\(root.kind) at index \(root.index)")
  }
  ```

---

## Validate

### `ValidationResult`

Validation result returned by `validate()`.

```swift
public struct ValidationResult: Sendable {
    public let isValid: Bool
    public let errorCount: Int
    public let warningCount: Int
}
```

- `isValid` — `true` if the graph has no structural errors.
- `errorCount` — number of error-severity issues.
- `warningCount` — number of warning-severity issues.

---

### `validate()`

Validate the graph structure, returning detailed counts.

```swift
public func validate() -> ValidationResult
```

Runs `BRepGraph_Validate::Perform` and reports errors and warnings. Use when you need issue counts; use `isValid` for a fast boolean check.

- **Returns:** `ValidationResult` with error and warning counts.
- **OCCT:** `BRepGraph_Validate::Perform(graph)` with `NbIssues(Severity::Error/Warning)`.
- **Example:**
  ```swift
  let result = graph.validate()
  if !result.isValid {
      print("\(result.errorCount) errors, \(result.warningCount) warnings")
  }
  ```

---

### `isValid`

Whether the graph is structurally valid.

```swift
public var isValid: Bool { get }
```

Fast boolean validity check. Prefer `validate()` when you need error/warning counts.

- **OCCT:** `BRepGraph_Validate::Perform(graph).IsValid()`.

---

## Compact

### `CompactResult`

Compaction result returned by `compact()`.

```swift
public struct CompactResult: Sendable {
    public let removedVertices: Int
    public let removedEdges: Int
    public let removedFaces: Int
    public let nodesAfter: Int
}
```

- `removedVertices/Edges/Faces` — count of nodes purged per entity type.
- `nodesAfter` — total node count after compaction.

---

### `compact()`

Compact the graph by permanently removing all soft-deleted nodes.

```swift
@discardableResult
public func compact() -> CompactResult
```

After editor operations soft-remove nodes, call `compact()` to reclaim memory and renumber indices. Note: any previously captured indices are invalid after compaction.

- **Returns:** `CompactResult` describing what was removed.
- **OCCT:** `BRepGraph_Compact::Perform(graph)`.
- **Example:**
  ```swift
  let result = graph.compact()
  print("Removed \(result.removedFaces) faces; \(result.nodesAfter) nodes remain")
  ```

---

## Deduplicate

### `DeduplicateResult`

Deduplication result returned by `deduplicate()`.

```swift
public struct DeduplicateResult: Sendable {
    public let canonicalSurfaces: Int
    public let canonicalCurves: Int
    public let surfaceRewrites: Int
    public let curveRewrites: Int
}
```

- `canonicalSurfaces/Curves` — number of unique geometry handles retained.
- `surfaceRewrites/curveRewrites` — number of face/edge geometry references updated to point at the canonical handle.

---

### `deduplicate()`

Deduplicate shared geometry in the graph.

```swift
@discardableResult
public func deduplicate() -> DeduplicateResult
```

Finds surfaces and curves that are geometrically identical and collapses them to a single canonical handle, reducing memory use and enabling same-domain face detection.

- **Returns:** `DeduplicateResult` describing the canonicalization.
- **OCCT:** `BRepGraph_Deduplicate::Perform(graph)`.
- **Example:**
  ```swift
  let dedup = graph.deduplicate()
  print("\(dedup.surfaceRewrites) surface refs collapsed to \(dedup.canonicalSurfaces) unique")
  ```

---

## Statistics

### `Stats`

Comprehensive graph statistics.

```swift
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

    public var description: String { get }
}
```

All counts in one allocation. `description` formats the struct as a readable summary string.

---

### `stats`

Get comprehensive graph statistics.

```swift
public var stats: Stats { get }
```

Reads all topology and geometry counts in a single call.

- **OCCT:** `BRepGraph::TopoView` fields — `Solids/Shells/Faces/Wires/Edges/Vertices/CoEdges/Compounds().Nb()`, `Gen().NbNodes()`, `Geometry().NbFaceSurfaces/NbEdgeCurves3D/NbCoEdgeCurves2D()`.
- **Example:**
  ```swift
  if let box = Shape.box(width: 10, height: 10, depth: 10),
     let graph = TopologyGraph(shape: box) {
      print(graph.stats)
      // TopologyGraph.Stats(solids: 1, shells: 1, faces: 6, wires: 6, edges: 12, vertices: 8, ...)
  }
  ```

---

## Shape Reconstruction

### `shape(nodeKind:nodeIndex:)`

Reconstruct a `Shape` from a graph node.

```swift
public func shape(nodeKind: NodeKind, nodeIndex: Int) -> Shape?
```

Returns the `TopoDS_Shape` stored for the specified node, reconstructed as an OCCTSwift `Shape`.

- **Parameters:** `nodeKind` — entity kind; `nodeIndex` — zero-based index.
- **Returns:** Reconstructed `Shape`, or `nil` if the node is invalid or null.
- **OCCT:** `BRepGraph::ShapesView::Shape(nid)`.
- **Example:**
  ```swift
  if let faceShape = graph.shape(nodeKind: .face, nodeIndex: 0) {
      // faceShape is a TopoDS_Face wrapped as a Shape
  }
  ```

---

### `findNode(for:)`

Find the node (kind, index) for a shape.

```swift
public func findNode(for shape: Shape) -> (kind: NodeKind, index: Int)?
```

Looks up the graph node that corresponds to the given `Shape`. Useful for round-tripping from a `Shape` to its graph index.

- **Parameters:** `shape` — the shape to look up.
- **Returns:** A `(kind, index)` tuple if the shape is known to the graph, `nil` otherwise.
- **OCCT:** `BRepGraph::ShapesView::FindNode(shape)`.

---

### `hasNode(for:)`

Check if a shape is known to the graph.

```swift
public func hasNode(for shape: Shape) -> Bool
```

- **Parameters:** `shape` — the shape to check.
- **OCCT:** `BRepGraph::ShapesView::HasNode(shape)`.

---

## Vertex Geometry

### `vertexPoint(_:)`

Get the 3D point of a vertex.

```swift
public func vertexPoint(_ vertexIndex: Int) -> (x: Double, y: Double, z: Double)
```

- **Parameters:** `vertexIndex` — zero-based vertex index.
- **Returns:** The XYZ coordinates of the vertex point.
- **OCCT:** `BRepGraph_Tool::Vertex::Pnt(graph, BRepGraph_VertexId(index))`.
- **Example:**
  ```swift
  let pt = graph.vertexPoint(0)
  print("(\(pt.x), \(pt.y), \(pt.z))")
  ```

---

### `vertexTolerance(_:)`

Get the tolerance of a vertex.

```swift
public func vertexTolerance(_ vertexIndex: Int) -> Double
```

- **Parameters:** `vertexIndex` — zero-based vertex index.
- **Returns:** The vertex tolerance (modelling precision for this vertex).
- **OCCT:** `BRepGraph_Tool::Vertex::Tolerance(graph, BRepGraph_VertexId(index))`.

---

## Edge Geometry

### `edgeTolerance(_:)`

Get the tolerance of an edge.

```swift
public func edgeTolerance(_ edgeIndex: Int) -> Double
```

- **Parameters:** `edgeIndex` — zero-based edge index.
- **OCCT:** `BRepGraph_Tool::Edge::Tolerance(graph, BRepGraph_EdgeId(index))`.

---

### `isEdgeDegenerated(_:)`

Check if an edge is degenerated.

```swift
public func isEdgeDegenerated(_ edgeIndex: Int) -> Bool
```

Degenerated edges have zero-length 3D curves (e.g. the apex edge of a cone). They carry a pcurve but no meaningful 3D geometry.

- **Parameters:** `edgeIndex` — zero-based edge index.
- **OCCT:** `BRepGraph_Tool::Edge::Degenerated(graph, BRepGraph_EdgeId(index))`.

---

### `isEdgeSameParameter(_:)`

Check if an edge has the SameParameter flag.

```swift
public func isEdgeSameParameter(_ edgeIndex: Int) -> Bool
```

`SameParameter` means the 3D curve and all pcurves share the same parameter range. Resolved via the first coedge of the edge; returns `true` for free edges with no coedge.

- **Parameters:** `edgeIndex` — zero-based edge index.
- **OCCT:** `BRepGraph_Tool::CoEdge::SameParameter(graph, coEdgeId)` (p1: per-coedge property).

---

### `isEdgeSameRange(_:)`

Check if an edge has the SameRange flag.

```swift
public func isEdgeSameRange(_ edgeIndex: Int) -> Bool
```

`SameRange` means all pcurves of an edge have the same parameter range as the 3D curve. Resolved via the first coedge.

- **Parameters:** `edgeIndex` — zero-based edge index.
- **OCCT:** `BRepGraph_Tool::CoEdge::SameRange(graph, coEdgeId)` (p1: per-coedge property).

---

### `edgeRange(_:)`

Get the parameter range of an edge.

```swift
public func edgeRange(_ edgeIndex: Int) -> (first: Double, last: Double)
```

- **Parameters:** `edgeIndex` — zero-based edge index.
- **Returns:** The (first, last) parameter values of the edge's 3D curve.
- **OCCT:** `BRepGraph_Tool::Edge::Range(graph, BRepGraph_EdgeId(index))`.

---

### `edgeHasCurve(_:)`

Check if an edge has a 3D curve.

```swift
public func edgeHasCurve(_ edgeIndex: Int) -> Bool
```

Degenerated edges may lack a 3D curve. Use before accessing curve geometry.

- **Parameters:** `edgeIndex` — zero-based edge index.
- **OCCT:** `BRepGraph_Tool::Edge::HasCurve(graph, BRepGraph_EdgeId(index))`.

---

### `isEdgeClosedOnFace(edgeIndex:faceIndex:)`

Check if an edge is a seam (closed) on a face.

```swift
public func isEdgeClosedOnFace(edgeIndex: Int, faceIndex: Int) -> Bool
```

A seam edge appears twice in the wire of a closed face (e.g. the longitudinal seam of a cylinder). In OCCT 8.0.0 p1, this is `IsSeamOnFace`.

- **Parameters:** `edgeIndex` — zero-based edge index; `faceIndex` — zero-based face index.
- **OCCT:** `BRepGraph_Tool::Edge::IsSeamOnFace(graph, edgeId, faceId)`.

---

### `edgeHasPolygon3D(_:)`

Check if an edge has a 3D polygon (mesh discretization).

```swift
public func edgeHasPolygon3D(_ edgeIndex: Int) -> Bool
```

Returns `true` if the edge has a cached or persistent `Poly_Polygon3D` in the graph's mesh layer.

- **Parameters:** `edgeIndex` — zero-based edge index.
- **OCCT:** `BRepGraph::MeshView::Effective().Edges().Has(BRepGraph_EdgeId(index))`.

---

### `edgeMaxContinuity(_:)`

Get the maximum continuity order of an edge (as `GeomAbs_Shape` raw int).

```swift
public func edgeMaxContinuity(_ edgeIndex: Int) -> Int
```

Returns the `GeomAbs_Shape` continuity enum raw value (0 = C0, 1 = C1, 2 = C2, …). Currently returns `0` always — `BRepGraph_LayerRegularity` is unavailable in OCCT 8.0.0 p1 due to an upstream header bug. Use `Shape.maxContinuity` (`BRep_Tool::MaxContinuity`) as an alternative.

- **Parameters:** `edgeIndex` — zero-based edge index.
- **Note:** Always returns 0 in OCCT 8.0.0 p1 — `BRepGraph_LayerRegularity` does not compile/link. Use `Shape.maxContinuity` instead.

---

## Face Geometry

### `faceTolerance(_:)`

Get the tolerance of a face.

```swift
public func faceTolerance(_ faceIndex: Int) -> Double
```

- **Parameters:** `faceIndex` — zero-based face index.
- **OCCT:** `BRepGraph_Tool::Face::Tolerance(graph, BRepGraph_FaceId(index))`.

---

### `isFaceNaturalRestriction(_:)`

Check if a face has the natural restriction flag.

```swift
public func isFaceNaturalRestriction(_ faceIndex: Int) -> Bool
```

In OCCT p1, this is derived: a face with no bounding wires (`NbWires == 0`) is considered naturally restricted. In practice, p1 always materializes bounding wires, so this typically returns `false` for real graphs.

- **Parameters:** `faceIndex` — zero-based face index.
- **OCCT:** `BRepGraph_Tool::Face::NbWires(graph, faceId) == 0`.

---

### `faceHasSurface(_:)`

Check if a face has a surface.

```swift
public func faceHasSurface(_ faceIndex: Int) -> Bool
```

- **Parameters:** `faceIndex` — zero-based face index.
- **OCCT:** `BRepGraph_Tool::Face::HasSurface(graph, BRepGraph_FaceId(index))`.

---

### `faceHasTriangulation(_:)`

Check if a face has a triangulation.

```swift
public func faceHasTriangulation(_ faceIndex: Int) -> Bool
```

Returns `true` if the face has a cached or persistent `Poly_Triangulation` in the graph's mesh layer.

- **Parameters:** `faceIndex` — zero-based face index.
- **OCCT:** `BRepGraph::MeshView::Effective().Faces().Has(BRepGraph_FaceId(index))`.

---

## Wire Queries

### `isWireClosed(_:)`

Check if a wire is topologically closed.

```swift
public func isWireClosed(_ wireIndex: Int) -> Bool
```

- **Parameters:** `wireIndex` — zero-based wire index.
- **OCCT:** `BRepGraph_Tool::Wire::IsClosed(graph, BRepGraph_WireId(index))`.

---

### `wireCoEdgeCount(_:)`

Number of coedges in a wire.

```swift
public func wireCoEdgeCount(_ wireIndex: Int) -> Int
```

- **Parameters:** `wireIndex` — zero-based wire index.
- **OCCT:** `BRepGraph_Tool::Wire::NbCoEdges(graph, BRepGraph_WireId(index))`.

---

### `wireFaceCount(_:)`

Number of faces a wire belongs to.

```swift
public func wireFaceCount(_ wireIndex: Int) -> Int
```

- **Parameters:** `wireIndex` — zero-based wire index.
- **OCCT:** `BRepGraph_FacesOfWire` iterator over the wire's `ParentWireRefIds` (p1 replacement for `WireOps::Faces()`).

---

### `wireFaces(_:)`

Indices of faces a wire belongs to.

```swift
public func wireFaces(_ wireIndex: Int) -> [Int]
```

- **Parameters:** `wireIndex` — zero-based wire index.
- **Returns:** Face indices that own this wire.
- **OCCT:** `BRepGraph_FacesOfWire` iterator over `BRepGraph::TopoView::Wires().Relations().ParentWireRefIds`.
- **Example:**
  ```swift
  let faces = graph.wireFaces(0)
  // outer wire of face 0 belongs to exactly face 0
  ```
