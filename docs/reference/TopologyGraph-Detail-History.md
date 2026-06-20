---
title: TopologyGraph — Topology Detail, History & Mesh
parent: API Reference
---

# TopologyGraph — Topology Detail, History & Mesh

This page covers the detail-query, history, mesh-storage, assembly, and structural reference members of `TopologyGraph`. For the core construction, counts, adjacency, geometry, and serialization API see [TopologyGraph](TopologyGraph.md).

## Topics

- [CoEdge Queries](#coedge-queries) · [Shell Queries](#shell-queries) · [Solid Queries](#solid-queries) · [History](#history) · [History Record Readback](#history-record-readback) · [Poly Counts](#poly-counts) · [MeshView](#meshview) · [MeshCache Write API](#meshcache-write-api) · [Active Geometry Counts](#active-geometry-counts) · [SameDomain](#samedomain) · [Copy and Transform](#copy-and-transform) · [Product/Assembly Queries](#productassembly-queries) · [Reference Counts](#reference-counts) · [Reference Entry Queries](#reference-entry-queries) · [Face Definition Details](#face-definition-details) · [Edge Definition Details](#edge-definition-details) · [Compound/CompSolid Queries](#compoundcompsolid-queries)

---

## CoEdge Queries

### `coedgeEdge(_:)`

Returns the index of the underlying edge for a coedge.

```swift
public func coedgeEdge(_ coedgeIndex: Int) -> Int
```

- **Parameters:** `coedgeIndex` — 0-based coedge index.
- **Returns:** Edge index.
- **OCCT:** `BRepGraph_CoEdge::Edge` via `OCCTBRepGraphCoEdgeEdge`.
- **Example:**
  ```swift
  let edgeIdx = graph.coedgeEdge(0)
  ```

---

### `coedgeFace(_:)`

Returns the index of the face that owns a coedge.

```swift
public func coedgeFace(_ coedgeIndex: Int) -> Int
```

- **Parameters:** `coedgeIndex` — 0-based coedge index.
- **Returns:** Face index.
- **OCCT:** `BRepGraph_CoEdge::Face` via `OCCTBRepGraphCoEdgeFace`.
- **Example:**
  ```swift
  let faceIdx = graph.coedgeFace(0)
  ```

---

### `coedgeSeamPair(_:)`

Returns the index of the paired seam coedge, or `nil` if this coedge is not part of a seam pair.

```swift
public func coedgeSeamPair(_ coedgeIndex: Int) -> Int?
```

- **Parameters:** `coedgeIndex` — 0-based coedge index.
- **Returns:** Paired coedge index, or `nil` when none.
- **OCCT:** `BRepGraph_CoEdge::SeamPair` via `OCCTBRepGraphCoEdgeSeamPair`.
- **Example:**
  ```swift
  if let pair = graph.coedgeSeamPair(0) {
      print("seam pair coedge: \(pair)")
  }
  ```

---

### `coedgeHasPCurve(_:)`

Returns whether a coedge has a parametric curve (PCurve) on its face.

```swift
public func coedgeHasPCurve(_ coedgeIndex: Int) -> Bool
```

- **Parameters:** `coedgeIndex` — 0-based coedge index.
- **OCCT:** `BRepGraph_CoEdge::HasPCurve` via `OCCTBRepGraphCoEdgeHasPCurve`.
- **Example:**
  ```swift
  if graph.coedgeHasPCurve(0) {
      let range = graph.coedgeRange(0)
  }
  ```

---

### `coedgeRange(_:)`

Returns the parameter range of a coedge's PCurve.

```swift
public func coedgeRange(_ coedgeIndex: Int) -> (first: Double, last: Double)
```

- **Parameters:** `coedgeIndex` — 0-based coedge index.
- **Returns:** Tuple of `(first, last)` parameter values.
- **OCCT:** `BRepGraph_CoEdge::Range` via `OCCTBRepGraphCoEdgeRange`.
- **Example:**
  ```swift
  let (u0, u1) = graph.coedgeRange(0)
  ```

---

## Shell Queries

### `shellSolidCount(_:)`

Returns the number of solids that contain a given shell.

```swift
public func shellSolidCount(_ shellIndex: Int) -> Int
```

- **Parameters:** `shellIndex` — 0-based shell index.
- **OCCT:** `BRepGraph_Shell` upward links via `OCCTBRepGraphShellSolidCount`.
- **Example:**
  ```swift
  let n = graph.shellSolidCount(0)
  ```

---

### `shellSolids(_:)`

Returns the indices of solids that contain a given shell.

```swift
public func shellSolids(_ shellIndex: Int) -> [Int]
```

- **Parameters:** `shellIndex` — 0-based shell index.
- **Returns:** Array of solid indices (may be empty for free shells).
- **OCCT:** `BRepGraph_Shell` upward links via `OCCTBRepGraphShellSolidIndices`.
- **Example:**
  ```swift
  let solidIndices = graph.shellSolids(0)
  ```

---

## Solid Queries

### `solidCompSolidCount(_:)`

Returns the number of comp-solids that contain a given solid.

```swift
public func solidCompSolidCount(_ solidIndex: Int) -> Int
```

- **Parameters:** `solidIndex` — 0-based solid index.
- **OCCT:** `BRepGraph_Solid` upward links via `OCCTBRepGraphSolidCompSolidCount`.
- **Example:**
  ```swift
  let n = graph.solidCompSolidCount(0)
  ```

---

## History

### `historyRecordCount`

Number of history records currently stored in the graph.

```swift
public var historyRecordCount: Int { get }
```

- **OCCT:** `BRepGraph_History::NbRecords` via `OCCTBRepGraphHistoryNbRecords`.
- **Example:**
  ```swift
  print("history records: \(graph.historyRecordCount)")
  ```

---

### `isHistoryEnabled`

Whether history recording is enabled.

```swift
public var isHistoryEnabled: Bool { get set }
```

- **OCCT:** `BRepGraph_History::IsEnabled` / `SetEnabled` via `OCCTBRepGraphHistoryIsEnabled` / `OCCTBRepGraphHistorySetEnabled`.
- **Example:**
  ```swift
  graph.isHistoryEnabled = true
  ```

---

### `clearHistory()`

Removes all history records from the graph.

```swift
public func clearHistory()
```

- **OCCT:** `BRepGraph_History::Clear` via `OCCTBRepGraphHistoryClear`.
- **Example:**
  ```swift
  graph.clearHistory()
  ```

---

## History Record Readback

### `NodeRef`

A `(kind, index)` pair identifying a node within a `TopologyGraph`.

```swift
public struct NodeRef: Sendable, Hashable, Codable {
    public let kind: NodeKind
    public let index: Int

    public init(kind: NodeKind, index: Int)

    public var isValid: Bool { get }
}
```

Swift mirror of OCCT's `BRepGraph_NodeId`. Two `NodeRef` values with equal `kind` and `index` refer to the same node **within a given graph instance**. Cross-graph translation requires walking history records.

- **`isValid`** — `true` when `index >= 0`.

---

### `HistoryRecord`

A single atomic modification event in the graph's history log.

```swift
public struct HistoryRecord: Sendable {
    public let operationName: String
    public let sequenceNumber: Int
    public let mapping: [NodeRef: [NodeRef]]
}
```

The `mapping` encodes the fate of each affected node:

- `original → [one replacement]` — modified in place
- `original → [multiple replacements]` — split (e.g. edge split by fillet)
- `original → []` — deleted

---

### `historyRecord(at:)`

Returns a single history record by 0-based index, or `nil` if the index is out of range.

```swift
public func historyRecord(at index: Int) -> HistoryRecord?
```

- **Parameters:** `index` — 0-based index into the history log.
- **Returns:** The decoded `HistoryRecord`, or `nil` if `index ≥ historyRecordCount`.
- **OCCT:** `OCCTBRepGraphHistoryGetRecordInfo`, `OCCTBRepGraphHistoryGetRecordOriginals`, `OCCTBRepGraphHistoryGetRecordMapping`.
- **Example:**
  ```swift
  if let rec = graph.historyRecord(at: 0) {
      print(rec.operationName, rec.mapping.count)
  }
  ```

---

### `historyRecords`

All history records in order.

```swift
public var historyRecords: [HistoryRecord] { get }
```

- **Returns:** Array of every `HistoryRecord` from index 0 through `historyRecordCount - 1`.
- **Example:**
  ```swift
  for rec in graph.historyRecords {
      print("\(rec.operationName): \(rec.mapping.count) node(s) affected")
  }
  ```

---

### `findOriginal(of:)`

Walks backwards from a derived node to its root original via the reverse history map.

```swift
public func findOriginal(of derived: NodeRef) -> NodeRef
```

- **Parameters:** `derived` — node to trace back.
- **Returns:** The root original `NodeRef`, or `derived` itself if no history exists for it.
- **OCCT:** `OCCTBRepGraphHistoryFindOriginal`.
- **Example:**
  ```swift
  let original = graph.findOriginal(of: NodeRef(kind: .face, index: 2))
  ```

---

### `hasHistoryRecord(for:)`

Returns `true` if any history record names `original` as a key (i.e. some recorded operation modified or deleted the node).

```swift
public func hasHistoryRecord(for original: NodeRef) -> Bool
```

Use alongside `findDerived(of:)` to distinguish "explicitly deleted" (record present, empty replacements) from "untouched" (no record at all).

- **Parameters:** `original` — node to check.
- **Example:**
  ```swift
  let ref = NodeRef(kind: .face, index: 0)
  if graph.hasHistoryRecord(for: ref) {
      print("face 0 was modified or deleted")
  }
  ```

---

### `findDerivedOrSelf(of:)`

Walks forwards from an original node and returns its live derivatives, falling back to `[original]` when untouched or `[]` when explicitly deleted.

```swift
public func findDerivedOrSelf(of original: NodeRef) -> [NodeRef]
```

This is the preferred single-entry-point for "where did this node end up?" queries:

- Non-empty `findDerived` result → returns live derivatives.
- Empty result + history record present → `[]` (explicitly deleted).
- Empty result + no history record → `[original]` (untouched, same index).

- **Parameters:** `original` — node to trace forward.
- **Returns:** Array of current `NodeRef` values (never `nil`).
- **Example:**
  ```swift
  let current = graph.findDerivedOrSelf(of: NodeRef(kind: .face, index: 0))
  for ref in current {
      print("live face index: \(ref.index)")
  }
  ```

---

### `findDerived(of:)`

Walks forwards from an original node and returns all transitively derived nodes.

```swift
public func findDerived(of original: NodeRef) -> [NodeRef]
```

Returns an empty array for both untouched and explicitly deleted nodes. Use `findDerivedOrSelf(of:)` or pair with `hasHistoryRecord(for:)` to disambiguate.

- **Parameters:** `original` — node to trace forward.
- **Returns:** Array of derived `NodeRef` values; empty if no recorded descendants.
- **OCCT:** `OCCTBRepGraphHistoryFindDerived`.
- **Example:**
  ```swift
  let derived = graph.findDerived(of: NodeRef(kind: .edge, index: 3))
  ```

---

### `recordHistory(operationName:original:replacements:)`

Records a 1-to-N modification event on the graph's history log.

```swift
public func recordHistory(operationName: String,
                          original: NodeRef,
                          replacements: [NodeRef])
```

Use this when mutating the graph outside BRepGraph's own builder API so the change participates in history queries.

- **Parameters:**
  - `operationName` — human-readable label for the event.
  - `original` — the node that was modified.
  - `replacements` — replacement node(s). Pass `[]` to record a deletion.
- **OCCT:** `OCCTBRepGraphHistoryRecord`.
- **Example:**
  ```swift
  graph.recordHistory(
      operationName: "fillet",
      original: NodeRef(kind: .edge, index: 1),
      replacements: [NodeRef(kind: .face, index: 6), NodeRef(kind: .face, index: 7)]
  )
  ```

---

## Poly Counts

### `triangulationCount`

Total number of triangulations stored in the graph.

```swift
public var triangulationCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphNbTriangulations`.

---

### `polygon3DCount`

Total number of 3D polygons stored in the graph.

```swift
public var polygon3DCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphNbPolygons3D`.

---

## MeshView

The MeshView properties expose OCCT 8.0.0's two-tier mesh storage model: a persistent tier (imported from file) and an algorithm-derived cache tier. Query methods check the cache first and fall back to the persistent tier.

### `polygon2DCount`

Number of 2D polygons (PCurve discretizations) in the graph.

```swift
public var polygon2DCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphMeshNbPolygons2D`.

---

### `polygonOnTriCount`

Number of polygon-on-triangulation reps (coedge discretizations parameterized on a face triangulation).

```swift
public var polygonOnTriCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphMeshNbPolygonsOnTri`.

---

### `activeTriangulationCount`

Number of active (non-removed) triangulations.

```swift
public var activeTriangulationCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphMeshNbActiveTriangulations`.

---

### `activePolygon3DCount`

Number of active 3D polygons.

```swift
public var activePolygon3DCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphMeshNbActivePolygons3D`.

---

### `activePolygon2DCount`

Number of active 2D polygons.

```swift
public var activePolygon2DCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphMeshNbActivePolygons2D`.

---

### `activePolygonOnTriCount`

Number of active polygon-on-triangulation reps.

```swift
public var activePolygonOnTriCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphMeshNbActivePolygonsOnTri`.

---

### `meshFaceActiveTriangulationRepId(_:)`

Returns the active triangulation rep id for a face, checking the algorithm-derived mesh cache first and falling back to the persistent (STEP-imported) tier.

```swift
public func meshFaceActiveTriangulationRepId(_ faceIndex: Int) -> Int?
```

- **Parameters:** `faceIndex` — 0-based face index.
- **Returns:** Rep id, or `nil` if neither tier has mesh data for the face.
- **OCCT:** `OCCTBRepGraphMeshFaceActiveTriangulationRepId`.
- **Example:**
  ```swift
  if let repId = graph.meshFaceActiveTriangulationRepId(0) {
      print("triangulation rep: \(repId)")
  }
  ```

---

### `meshEdgePolygon3DRepId(_:)`

Returns the active polygon-3D rep id for an edge (cache-first, persistent fallback).

```swift
public func meshEdgePolygon3DRepId(_ edgeIndex: Int) -> Int?
```

- **Parameters:** `edgeIndex` — 0-based edge index.
- **Returns:** Rep id, or `nil` if neither tier has polygon-3D mesh data for the edge.
- **OCCT:** `OCCTBRepGraphMeshEdgePolygon3DRepId`.
- **Example:**
  ```swift
  if let repId = graph.meshEdgePolygon3DRepId(0) {
      print("polygon3D rep: \(repId)")
  }
  ```

---

### `meshCoEdgeHasMesh(_:)`

Returns whether a coedge has cached mesh data (polygon-on-tri or polygon-2D). Cache-only check — does not consult the persistent tier.

```swift
public func meshCoEdgeHasMesh(_ coedgeIndex: Int) -> Bool
```

- **Parameters:** `coedgeIndex` — 0-based coedge index.
- **OCCT:** `OCCTBRepGraphMeshCoEdgeHasMesh`.
- **Example:**
  ```swift
  if graph.meshCoEdgeHasMesh(0) {
      // coedge 0 has cached discretization
  }
  ```

---

## MeshCache Write API

These methods populate the graph's algorithm-derived mesh cache. Use them after running a tessellation algorithm to store results for later retrieval via the MeshView properties.

### `createTriangulationRep(_:)`

Creates a triangulation rep in the graph's mesh storage.

```swift
public func createTriangulationRep(_ triangulation: Triangulation) -> Int?
```

- **Parameters:** `triangulation` — the `Triangulation` to store.
- **Returns:** Rep id, or `nil` on failure.
- **OCCT:** `OCCTBRepGraphMeshCreateTriangulationRep`.
- **Example:**
  ```swift
  guard let tri = Triangulation(...), let repId = graph.createTriangulationRep(tri) else { return }
  graph.appendCachedTriangulation(faceIndex: 0, triRepId: repId)
  ```

---

### `createPolygon3DRep(_:)`

Creates a polygon-3D rep in the graph's mesh storage.

```swift
public func createPolygon3DRep(_ polygon: Polygon3D) -> Int?
```

- **Parameters:** `polygon` — the `Polygon3D` to store.
- **Returns:** Rep id, or `nil` on failure.
- **OCCT:** `OCCTBRepGraphMeshCreatePolygon3DRep`.
- **Example:**
  ```swift
  if let repId = graph.createPolygon3DRep(poly) {
      graph.setCachedPolygon3D(edgeIndex: 0, polyRepId: repId)
  }
  ```

---

### `createPolygonOnTriRep(_:triRepId:)`

Creates a polygon-on-triangulation rep linked to an existing triangulation rep.

```swift
public func createPolygonOnTriRep(_ polygon: PolygonOnTriangulation, triRepId: Int) -> Int?
```

- **Parameters:**
  - `polygon` — the `PolygonOnTriangulation` to store.
  - `triRepId` — id of the parent triangulation rep.
- **Returns:** Rep id, or `nil` on failure.
- **OCCT:** `OCCTBRepGraphMeshCreatePolygonOnTriRep`.
- **Example:**
  ```swift
  if let repId = graph.createPolygonOnTriRep(polyOnTri, triRepId: triId) {
      graph.appendCachedPolygonOnTri(coedgeIndex: 0, polyRepId: repId)
  }
  ```

---

### `appendCachedTriangulation(faceIndex:triRepId:)`

Appends a triangulation rep to a face's cached mesh (multi-LOD support).

```swift
public func appendCachedTriangulation(faceIndex: Int, triRepId: Int)
```

- **Parameters:**
  - `faceIndex` — 0-based face index.
  - `triRepId` — rep id returned by `createTriangulationRep(_:)`.
- **OCCT:** `OCCTBRepGraphMeshAppendCachedTriangulation`.

---

### `setCachedActiveIndex(faceIndex:activeIndex:)`

Sets the active triangulation index in a face's cached mesh.

```swift
public func setCachedActiveIndex(faceIndex: Int, activeIndex: Int)
```

- **Parameters:**
  - `faceIndex` — 0-based face index.
  - `activeIndex` — index into the face's cached triangulation list to activate.
- **OCCT:** `OCCTBRepGraphMeshSetCachedActiveIndex`.

---

### `setCachedPolygon3D(edgeIndex:polyRepId:)`

Sets the polygon-3D rep in an edge's cached mesh.

```swift
public func setCachedPolygon3D(edgeIndex: Int, polyRepId: Int)
```

- **Parameters:**
  - `edgeIndex` — 0-based edge index.
  - `polyRepId` — rep id returned by `createPolygon3DRep(_:)`.
- **OCCT:** `OCCTBRepGraphMeshSetCachedPolygon3D`.

---

### `appendCachedPolygonOnTri(coedgeIndex:polyRepId:)`

Appends a polygon-on-tri rep to a coedge's cached mesh (seam edge support).

```swift
public func appendCachedPolygonOnTri(coedgeIndex: Int, polyRepId: Int)
```

- **Parameters:**
  - `coedgeIndex` — 0-based coedge index.
  - `polyRepId` — rep id returned by `createPolygonOnTriRep(_:triRepId:)`.
- **OCCT:** `OCCTBRepGraphMeshAppendCachedPolygonOnTri`.

---

### `setCachedPolygon2D(coedgeIndex:poly2DRepId:)`

Sets the polygon-2D rep in a coedge's cached mesh.

```swift
public func setCachedPolygon2D(coedgeIndex: Int, poly2DRepId: Int)
```

- **Parameters:**
  - `coedgeIndex` — 0-based coedge index.
  - `poly2DRepId` — rep id of the polygon-2D entry.
- **OCCT:** `OCCTBRepGraphMeshSetCachedPolygon2D`.

---

## Active Geometry Counts

### `activeSurfaceCount`

Number of active (non-removed) surfaces.

```swift
public var activeSurfaceCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphNbActiveSurfaces`.

---

### `activeCurve3DCount`

Number of active 3D curves.

```swift
public var activeCurve3DCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphNbActiveCurves3D`.

---

### `activeCurve2DCount`

Number of active 2D curves.

```swift
public var activeCurve2DCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphNbActiveCurves2D`.

---

## SameDomain

### `sameDomainFaces(of:)`

Returns the indices of same-domain faces for a given face (faces sharing the same geometric support).

```swift
public func sameDomainFaces(of faceIndex: Int) -> [Int]
```

- **Parameters:** `faceIndex` — 0-based face index.
- **Returns:** Array of co-domain face indices (empty if none).
- **OCCT:** `BRepGraph_Face::SameDomain` via `OCCTBRepGraphFaceSameDomainIndices`.
- **Example:**
  ```swift
  let coplanar = graph.sameDomainFaces(of: 0)
  ```

---

## Copy and Transform

### `copy(copyGeometry:)`

Creates a deep copy of the graph.

```swift
public func copy(copyGeometry: Bool = true) -> TopologyGraph?
```

- **Parameters:** `copyGeometry` — when `true` (default), geometry handles are also copied; when `false`, the new graph shares geometry with the original.
- **Returns:** New `TopologyGraph`, or `nil` on failure.
- **OCCT:** `OCCTBRepGraphCopy`.
- **Example:**
  ```swift
  if let clone = graph.copy() {
      // work on clone without affecting graph
  }
  ```

---

### `copyFace(_:copyGeometry:)`

Creates a new graph containing only the sub-graph of a single face.

```swift
public func copyFace(_ faceIndex: Int, copyGeometry: Bool = true) -> TopologyGraph?
```

- **Parameters:**
  - `faceIndex` — 0-based index of the face to extract.
  - `copyGeometry` — whether to copy geometry handles (default: `true`).
- **Returns:** New `TopologyGraph` for the face sub-graph, or `nil` on failure.
- **OCCT:** `OCCTBRepGraphCopyFace`.
- **Example:**
  ```swift
  if let faceGraph = graph.copyFace(0) {
      print("isolated face edges: \(faceGraph.edgeCount)")
  }
  ```

---

### `translated(dx:dy:dz:copyGeometry:)`

Returns a new graph translated by `(dx, dy, dz)`.

```swift
public func translated(dx: Double, dy: Double, dz: Double, copyGeometry: Bool = true) -> TopologyGraph?
```

- **Parameters:**
  - `dx`, `dy`, `dz` — translation components in model units.
  - `copyGeometry` — whether to copy geometry handles (default: `true`).
- **Returns:** Translated `TopologyGraph`, or `nil` on failure.
- **OCCT:** `OCCTBRepGraphTransformTranslation`.
- **Example:**
  ```swift
  if let moved = graph.translated(dx: 10, dy: 0, dz: 0) {
      // moved is offset by 10 units along X
  }
  ```

---

## Product/Assembly Queries

These properties and methods expose the product/occurrence hierarchy when the graph was built from an assembly shape (e.g. loaded via `Document`). Simple shapes have `productCount == 0`.

### `productCount`

Number of products in the graph.

```swift
public var productCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphNbProducts`.

---

### `occurrenceCount`

Number of occurrences in the graph.

```swift
public var occurrenceCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphNbOccurrences`.

---

### `productIsAssembly(_:)`

Returns whether a product at the given index is an assembly (has child occurrences).

```swift
public func productIsAssembly(_ productIndex: Int) -> Bool
```

- **Parameters:** `productIndex` — 0-based product index.
- **OCCT:** `OCCTBRepGraphProductIsAssembly`.
- **Example:**
  ```swift
  if graph.productIsAssembly(0) { print("product 0 is an assembly") }
  ```

---

### `productIsPart(_:)`

Returns whether a product at the given index is a leaf part (no child occurrences).

```swift
public func productIsPart(_ productIndex: Int) -> Bool
```

- **Parameters:** `productIndex` — 0-based product index.
- **OCCT:** `OCCTBRepGraphProductIsPart`.

---

### `productComponentCount(_:)`

Returns the number of active child occurrences of a product.

```swift
public func productComponentCount(_ productIndex: Int) -> Int
```

- **Parameters:** `productIndex` — 0-based product index.
- **OCCT:** `OCCTBRepGraphProductNbComponents`.

---

### `productShapeRoot(_:)`

Returns the shape root node `(kind, index)` of a product, or `nil` if the product is an assembly or the index is invalid.

```swift
public func productShapeRoot(_ productIndex: Int) -> (kind: NodeKind, index: Int)?
```

- **Parameters:** `productIndex` — 0-based product index.
- **Returns:** Tuple of `(kind, index)`, or `nil`.
- **OCCT:** `OCCTBRepGraphProductShapeRootKind` / `OCCTBRepGraphProductShapeRootIndex`.
- **Example:**
  ```swift
  if let root = graph.productShapeRoot(0) {
      print("shape root kind: \(root.kind), index: \(root.index)")
  }
  ```

---

### `occurrenceProduct(_:)`

Returns the product index referenced by an occurrence.

```swift
public func occurrenceProduct(_ occIndex: Int) -> Int
```

- **Parameters:** `occIndex` — 0-based occurrence index.
- **OCCT:** `OCCTBRepGraphOccurrenceProduct`.

---

### `occurrenceParentProduct(_:)`

Returns the parent product index of an occurrence.

```swift
public func occurrenceParentProduct(_ occIndex: Int) -> Int
```

- **Parameters:** `occIndex` — 0-based occurrence index.
- **OCCT:** `OCCTBRepGraphOccurrenceParentProduct`.

---

### `rootProductCount`

Number of root (top-level) products in the graph.

```swift
public var rootProductCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphRootProductCount`.

---

### `rootProductIndices`

Indices of all root products.

```swift
public var rootProductIndices: [Int] { get }
```

- **Returns:** Array of root product indices; empty for simple (non-assembly) shapes.
- **OCCT:** `OCCTBRepGraphRootProductIndices`.
- **Example:**
  ```swift
  for idx in graph.rootProductIndices {
      print("root product \(idx): isAssembly=\(graph.productIsAssembly(idx))")
  }
  ```

---

## Reference Counts

`TopologyGraph` stores topology as definition nodes (face, edge, …) and typed reference entries that link parent nodes to child nodes with orientation. The counts below reflect the size of each reference table.

### `RefKind`

Enumeration matching OCCT's `BRepGraph_RefId::Kind`.

```swift
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
```

---

### `shellRefCount`

Number of shell reference entries.

```swift
public var shellRefCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphNbShellRefs`.

---

### `faceRefCount`

Number of face reference entries.

```swift
public var faceRefCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphNbFaceRefs`.

---

### `wireRefCount`

Number of wire reference entries.

```swift
public var wireRefCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphNbWireRefs`.

---

### `coedgeRefCount`

Number of coedge reference entries.

```swift
public var coedgeRefCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphNbCoEdgeRefs`.

---

### `vertexRefCount`

Number of vertex reference entries.

```swift
public var vertexRefCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphNbVertexRefs`.

---

### `solidRefCount`

Number of solid reference entries.

```swift
public var solidRefCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphNbSolidRefs`.

---

### `childRefCount`

Number of child reference entries (used in compounds and assemblies).

```swift
public var childRefCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphNbChildRefs`.

---

### `occurrenceRefCount`

Number of occurrence reference entries.

```swift
public var occurrenceRefCount: Int { get }
```

- **OCCT:** `OCCTBRepGraphNbOccurrenceRefs`.

---

## Reference Entry Queries

### `refChildNodeKind(_:refIndex:)`

Returns the child node kind for a reference entry, or `nil` if invalid.

```swift
public func refChildNodeKind(_ refKind: RefKind, refIndex: Int) -> NodeKind?
```

- **Parameters:**
  - `refKind` — the reference table to query.
  - `refIndex` — 0-based index into that table.
- **Returns:** `NodeKind` of the child, or `nil`.
- **OCCT:** `OCCTBRepGraphRefChildNodeKind`.
- **Example:**
  ```swift
  if let kind = graph.refChildNodeKind(.face, refIndex: 0) {
      print("child kind: \(kind)")
  }
  ```

---

### `refChildNodeIndex(_:refIndex:)`

Returns the child node index for a reference entry.

```swift
public func refChildNodeIndex(_ refKind: RefKind, refIndex: Int) -> Int
```

- **Parameters:**
  - `refKind` — the reference table to query.
  - `refIndex` — 0-based index into that table.
- **OCCT:** `OCCTBRepGraphRefChildNodeIndex`.

---

### `isRefRemoved(_:refIndex:)`

Returns whether a reference entry has been soft-removed.

```swift
public func isRefRemoved(_ refKind: RefKind, refIndex: Int) -> Bool
```

- **Parameters:**
  - `refKind` — the reference table to query.
  - `refIndex` — 0-based index into that table.
- **OCCT:** `OCCTBRepGraphRefIsRemoved`.

---

### `refOrientation(_:refIndex:)`

Returns the orientation of a reference entry as a `TopAbs_Orientation` raw integer.

```swift
public func refOrientation(_ refKind: RefKind, refIndex: Int) -> Int
```

- **Parameters:**
  - `refKind` — the reference table to query.
  - `refIndex` — 0-based index into that table.
- **Returns:** `TopAbs_Orientation` value: `0` = Forward, `1` = Reversed, `2` = Internal, `3` = External.
- **OCCT:** `OCCTBRepGraphRefOrientation`.
- **Example:**
  ```swift
  let orient = graph.refOrientation(.face, refIndex: 0)
  // 0 = Forward, 1 = Reversed
  ```

---

## Face Definition Details

### `faceWireCount(_:)`

Returns the number of wire refs on a face (outer wire + any hole wires).

```swift
public func faceWireCount(_ faceIndex: Int) -> Int
```

- **Parameters:** `faceIndex` — 0-based face index.
- **OCCT:** `OCCTBRepGraphFaceNbWires`.
- **Example:**
  ```swift
  let wireCount = graph.faceWireCount(0)
  let hasHoles = wireCount > 1
  ```

---

### `faceVertexRefCount(_:)`

Returns the number of isolated vertex refs on a face.

```swift
public func faceVertexRefCount(_ faceIndex: Int) -> Int
```

- **Parameters:** `faceIndex` — 0-based face index.
- **OCCT:** `OCCTBRepGraphFaceNbVertexRefs`.

---

## Edge Definition Details

### `edgeStartVertex(_:)`

Returns the start vertex definition index of an edge, or `nil` if invalid.

```swift
public func edgeStartVertex(_ edgeIndex: Int) -> Int?
```

- **Parameters:** `edgeIndex` — 0-based edge index.
- **Returns:** Vertex index, or `nil` if the edge has no recorded start vertex.
- **OCCT:** `OCCTBRepGraphEdgeStartVertex`.
- **Example:**
  ```swift
  if let v0 = graph.edgeStartVertex(0) {
      let pt = graph.vertexPoint(v0)
  }
  ```

---

### `edgeEndVertex(_:)`

Returns the end vertex definition index of an edge, or `nil` if invalid.

```swift
public func edgeEndVertex(_ edgeIndex: Int) -> Int?
```

- **Parameters:** `edgeIndex` — 0-based edge index.
- **Returns:** Vertex index, or `nil` if the edge has no recorded end vertex.
- **OCCT:** `OCCTBRepGraphEdgeEndVertex`.

---

### `isEdgeClosed(_:)`

Returns whether an edge is topologically closed (start vertex equals end vertex).

```swift
public func isEdgeClosed(_ edgeIndex: Int) -> Bool
```

- **Parameters:** `edgeIndex` — 0-based edge index.
- **OCCT:** `OCCTBRepGraphEdgeIsClosed`.
- **Note:** Distinct from `isEdgeDegenerated` — a closed edge forms a loop; a degenerate edge collapses to a point.
- **Example:**
  ```swift
  if graph.isEdgeClosed(0) {
      print("edge 0 is a closed loop")
  }
  ```

---

## Compound/CompSolid Queries

### `compoundParentCount(_:)`

Returns the number of parent compounds of a compound.

```swift
public func compoundParentCount(_ compoundIndex: Int) -> Int
```

- **Parameters:** `compoundIndex` — 0-based compound index.
- **OCCT:** `OCCTBRepGraphCompoundParentCount`.

---

### `compoundChildCount(_:)`

Returns the number of child refs of a compound.

```swift
public func compoundChildCount(_ compoundIndex: Int) -> Int
```

- **Parameters:** `compoundIndex` — 0-based compound index.
- **OCCT:** `OCCTBRepGraphCompoundChildCount`.
- **Example:**
  ```swift
  let n = graph.compoundChildCount(0)
  print("compound 0 has \(n) children")
  ```

---

### `compSolidSolidCount(_:)`

Returns the number of solid refs in a comp-solid.

```swift
public func compSolidSolidCount(_ compSolidIndex: Int) -> Int
```

- **Parameters:** `compSolidIndex` — 0-based comp-solid index.
- **OCCT:** `OCCTBRepGraphCompSolidSolidCount`.

---

### `compSolidCompoundCount(_:)`

Returns the number of parent compounds of a comp-solid.

```swift
public func compSolidCompoundCount(_ compSolidIndex: Int) -> Int
```

- **Parameters:** `compSolidIndex` — 0-based comp-solid index.
- **OCCT:** `OCCTBRepGraphCompSolidCompoundCount`.
