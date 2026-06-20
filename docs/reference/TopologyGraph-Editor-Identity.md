---
title: TopologyGraph — Editor Geometry, Sampling & Durable Identity
parent: API Reference
---

# TopologyGraph — Editor Geometry, Sampling & Durable Identity

This page covers the final sections of `TopologyGraph` (source lines 1622–2055): geometric setters for the EditorView, assembly-building ProductOps, in-place RepOps swaps, MeshView cache inspection, UV-grid and edge-curve sampling, and the durable-identity UID/RefUID/ItemUID API. See the other **TopologyGraph — …** pages for the core read API, write helpers, and I/O.

## Topics

- [EditorView Geometric Setters & PCurve API](#editorview-geometric-setters--pcurve-api) · [EditorView ProductOps Assembly Building](#editorview-productops-assembly-building) · [EditorView RepOps Non-Guard Setters](#editorview-repops-non-guard-setters) · [MeshView Cache Entry Inspection](#meshview-cache-entry-inspection) · [UV-Grid Sampling](#uv-grid-sampling) · [Edge Curve Sampling](#edge-curve-sampling) · [Durable Identity (UID / RefUID / ItemUID)](#durable-identity-uid--refuid--itemuid)

---

## EditorView Geometric Setters & PCurve API

*(v0.162.0)* Low-level geometric mutation of coedge, edge, face, and reference-entry nodes — used when reconstructing or repairing a `BRepGraph` from external data.

---

### `setCoEdgeUVBox(_:u1:v1:u2:v2:)`

Set the UV bounding box (UV1 at `ParamFirst`, UV2 at `ParamLast`) of a coedge definition.

```swift
public func setCoEdgeUVBox(_ coedgeIndex: Int, u1: Double, v1: Double, u2: Double, v2: Double)
```

- **Parameters:** `coedgeIndex` — per-kind coedge index; `u1/v1` — UV at the first parameter; `u2/v2` — UV at the last parameter.
- **OCCT:** `BRepGraph_CoEdgeDef` UV-box field (via `OCCTBRepGraphSetCoEdgeUVBox`).
- **Example:**
  ```swift
  graph.setCoEdgeUVBox(0, u1: 0.0, v1: 0.0, u2: 1.0, v2: 1.0)
  ```

---

### `setEdgeRegularity(_:face1:face2:continuity:)`

Set the geometric regularity (C^k continuity) for an edge across a pair of faces.

```swift
@discardableResult
public func setEdgeRegularity(_ edgeIndex: Int, face1: Int, face2: Int, continuity: Int) -> Bool
```

Pass the same index for `face1` and `face2` to set the seam continuity across a closed-surface seam line. In OCCT 8.0.0 GA the continuity model lives on the `(edge, face1, face2)` triple in `BRepGraph_LayerRegularity`; the earlier per-coedge setters were removed.

- **Parameters:**
  - `edgeIndex` — per-kind edge index.
  - `face1`, `face2` — adjacent face indices (equal for seam).
  - `continuity` — `GeomAbs_Shape` ordinal: 0 = C0, 1 = C1, 2 = C2, 3 = C3, 4 = CN.
- **Returns:** `true` if written; `false` if the `LayerRegularity` layer is not registered in this graph.
- **OCCT:** `BRepGraph_LayerRegularity` (via `OCCTBRepGraphSetEdgeRegularity`).
- **Example:**
  ```swift
  let ok = graph.setEdgeRegularity(2, face1: 0, face2: 1, continuity: 2)  // C2 across faces 0 & 1
  ```

---

### `setFaceTriangulationRep(_:triRepId:)`

Set the active triangulation rep on a face, binding a fresh `Triangulation` to the persistent tier.

```swift
public func setFaceTriangulationRep(_ faceIndex: Int, triRepId: Int)
```

Also see `appendCachedTriangulation` for cache-tier writes.

- **Parameters:** `faceIndex` — per-kind face index; `triRepId` — rep-store triangulation id.
- **OCCT:** `BRepGraph_FaceDef` triangulation-rep field (via `OCCTBRepGraphSetFaceTriangulationRep`).

---

### `coEdgeCreateCurve2DRep(_:)`

Create a new `Curve2DRep` from a `Curve2D` and return its rep id.

```swift
public func coEdgeCreateCurve2DRep(_ curve2D: Curve2D) -> Int?
```

- **Parameters:** `curve2D` — the 2D curve to wrap in a new rep entry.
- **Returns:** Non-negative rep id on success, or `nil` on failure.
- **OCCT:** `BRepGraph_RepStore` curve-2D entry (via `OCCTBRepGraphCoEdgeCreateCurve2DRep`).
- **Example:**
  ```swift
  if let repId = graph.coEdgeCreateCurve2DRep(myCurve2D) {
      graph.coEdgeSetPCurve(3, curve2D: myCurve2D)
  }
  ```

---

### `coEdgeSetPCurve(_:curve2D:)`

Assign or clear the PCurve bound to an existing coedge.

```swift
public func coEdgeSetPCurve(_ coedgeIndex: Int, curve2D: Curve2D?)
```

- **Parameters:** `coedgeIndex` — per-kind coedge index; `curve2D` — the curve to assign, or `nil` to clear the binding.
- **OCCT:** `BRepGraph_CoEdgeDef` curve-2D field (via `OCCTBRepGraphCoEdgeSetPCurve`).

---

### `coEdgeAddPCurve(edgeIndex:faceIndex:curve2D:first:last:orientation:)`

Attach a PCurve to an edge for a given face context, creating a new CoEdge entry.

```swift
public func coEdgeAddPCurve(edgeIndex: Int, faceIndex: Int, curve2D: Curve2D,
                              first: Double, last: Double, orientation: Int = 0)
```

- **Parameters:**
  - `edgeIndex` — the edge to attach the PCurve to.
  - `faceIndex` — the face context.
  - `curve2D` — the parametric curve.
  - `first`, `last` — parameter range on the curve.
  - `orientation` — 0 = forward, 1 = reversed (default `0`).
- **OCCT:** `BRepGraph` coedge construction (via `OCCTBRepGraphCoEdgeAddPCurve`).
- **Example:**
  ```swift
  graph.coEdgeAddPCurve(edgeIndex: 1, faceIndex: 0, curve2D: pcurve,
                         first: 0.0, last: 1.0, orientation: 0)
  ```

---

### `setVertexRefLocalLocation(_:matrix:)`

Set the local `TopLoc_Location` of a vertex reference entry.

```swift
public func setVertexRefLocalLocation(_ vertexRefIndex: Int, matrix: [Double])
```

`matrix` is a row-major 3×4 array (12 doubles) following the `gp_Trsf::SetValues` convention — rows are `[r00 r01 r02 tx | r10 r11 r12 ty | r20 r21 r22 tz]`. Use `TopologyGraph.identityLocationMatrix` for a no-op placement.

- **Parameters:** `vertexRefIndex` — per-kind vertex-ref index; `matrix` — 12-element row-major 3×4 transform.
- **OCCT:** `TopLoc_Location` via `gp_Trsf::SetValues` (via `OCCTBRepGraphSetVertexRefLocalLocation`).
- **Note:** Precondition: `matrix.count == 12`.

---

### `setCoEdgeRefLocalLocation(_:matrix:)`

Set the local `TopLoc_Location` of a coedge reference entry.

```swift
public func setCoEdgeRefLocalLocation(_ coedgeRefIndex: Int, matrix: [Double])
```

- **Parameters:** `coedgeRefIndex` — per-kind coedge-ref index; `matrix` — 12-element 3×4 row-major transform.
- **OCCT:** `TopLoc_Location` (via `OCCTBRepGraphSetCoEdgeRefLocalLocation`).

---

### `setWireRefLocalLocation(_:matrix:)`

Set the local `TopLoc_Location` of a wire reference entry.

```swift
public func setWireRefLocalLocation(_ wireRefIndex: Int, matrix: [Double])
```

- **OCCT:** `TopLoc_Location` (via `OCCTBRepGraphSetWireRefLocalLocation`).

---

### `setFaceRefLocalLocation(_:matrix:)`

Set the local `TopLoc_Location` of a face reference entry.

```swift
public func setFaceRefLocalLocation(_ faceRefIndex: Int, matrix: [Double])
```

- **OCCT:** `TopLoc_Location` (via `OCCTBRepGraphSetFaceRefLocalLocation`).

---

### `setShellRefLocalLocation(_:matrix:)`

Set the local `TopLoc_Location` of a shell reference entry.

```swift
public func setShellRefLocalLocation(_ shellRefIndex: Int, matrix: [Double])
```

- **OCCT:** `TopLoc_Location` (via `OCCTBRepGraphSetShellRefLocalLocation`).

---

### `setSolidRefLocalLocation(_:matrix:)`

Set the local `TopLoc_Location` of a solid reference entry.

```swift
public func setSolidRefLocalLocation(_ solidRefIndex: Int, matrix: [Double])
```

- **OCCT:** `TopLoc_Location` (via `OCCTBRepGraphSetSolidRefLocalLocation`).

---

### `setOccurrenceRefLocalLocation(_:matrix:)`

Set the local `TopLoc_Location` of an occurrence reference entry.

```swift
public func setOccurrenceRefLocalLocation(_ occurrenceRefIndex: Int, matrix: [Double])
```

- **OCCT:** `TopLoc_Location` (via `OCCTBRepGraphSetOccurrenceRefLocalLocation`).

---

### `setChildRefLocalLocation(_:matrix:)`

Set the local `TopLoc_Location` of a child reference entry.

```swift
public func setChildRefLocalLocation(_ childRefIndex: Int, matrix: [Double])
```

- **OCCT:** `TopLoc_Location` (via `OCCTBRepGraphSetChildRefLocalLocation`).

---

### `identityLocationMatrix`

Identity matrix (3×4) suitable for all `set*LocalLocation` calls.

```swift
public static var identityLocationMatrix: [Double] { get }
```

Returns `[1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0]` — a row-major identity with zero translation.

- **Example:**
  ```swift
  graph.setFaceRefLocalLocation(0, matrix: TopologyGraph.identityLocationMatrix)
  ```

---

## EditorView ProductOps Assembly Building

*(v0.163.0)* Methods for building and editing the product/assembly graph layer of `BRepGraph`.

---

### `linkProductToTopology(shapeRootKind:shapeRootIndex:placement:)`

Wrap an existing topology root in a new Product.

```swift
public func linkProductToTopology(shapeRootKind: Int, shapeRootIndex: Int,
                                   placement: [Double]? = nil) -> Int?
```

- **Parameters:**
  - `shapeRootKind` — `BRepGraph_NodeId::Kind` ordinal of the topology root (e.g. 0 = Solid).
  - `shapeRootIndex` — per-kind node index of the root.
  - `placement` — optional 12-element 3×4 row-major placement matrix; pass `nil` for identity.
- **Returns:** New product id on success, or `nil` on failure.
- **OCCT:** `BRepGraph` product-layer creation (via `OCCTBRepGraphLinkProductToTopology`).
- **Note:** Precondition: `placement.count == 12` if non-nil.
- **Example:**
  ```swift
  if let pid = graph.linkProductToTopology(shapeRootKind: 0, shapeRootIndex: 0) {
      print("Product id:", pid)
  }
  ```

---

### `createEmptyProduct()`

Create an empty product (assembly node with no direct topology).

```swift
public func createEmptyProduct() -> Int?
```

- **Returns:** New product id, or `nil` on failure.
- **OCCT:** `BRepGraph` product-layer (via `OCCTBRepGraphCreateEmptyProduct`).
- **Example:**
  ```swift
  guard let assemblyId = graph.createEmptyProduct() else { return }
  ```

---

### `linkProducts(parentProductIndex:referencedProductIndex:placement:parentOccurrenceIndex:)`

Link two products via a fresh occurrence (assembly reference).

```swift
public func linkProducts(parentProductIndex: Int, referencedProductIndex: Int,
                          placement: [Double], parentOccurrenceIndex: Int? = nil)
    -> (occurrenceIndex: Int, occurrenceRefIndex: Int)?
```

- **Parameters:**
  - `parentProductIndex` — product that will own the new occurrence.
  - `referencedProductIndex` — product being instanced.
  - `placement` — 12-element 3×4 row-major transform for the instance.
  - `parentOccurrenceIndex` — pass `nil` for an unparented occurrence.
- **Returns:** Tuple of `(occurrenceIndex, occurrenceRefIndex)`, or `nil` on failure.
- **OCCT:** `BRepGraph` occurrence construction (via `OCCTBRepGraphLinkProducts`).
- **Note:** Precondition: `placement.count == 12`.
- **Example:**
  ```swift
  let matrix = TopologyGraph.identityLocationMatrix
  if let result = graph.linkProducts(parentProductIndex: 0,
                                      referencedProductIndex: 1,
                                      placement: matrix) {
      print("Occurrence:", result.occurrenceIndex,
            "OccurrenceRef:", result.occurrenceRefIndex)
  }
  ```

---

### `productRemoveOccurrence(_:occurrenceRefIndex:)`

Detach an occurrence ref from a product.

```swift
public func productRemoveOccurrence(_ productIndex: Int, occurrenceRefIndex: Int) -> Bool
```

- **Parameters:** `productIndex` — the owning product; `occurrenceRefIndex` — the occurrence-ref to remove.
- **Returns:** `true` if the active usage was removed.
- **OCCT:** `BRepGraph` product-layer (via `OCCTBRepGraphProductRemoveOccurrence`).

---

### `productRemoveShapeRoot(_:)`

Detach the scalar shape-root from a product.

```swift
public func productRemoveShapeRoot(_ productIndex: Int) -> Bool
```

- **Returns:** `true` if a root was detached.
- **OCCT:** `BRepGraph` product-layer (via `OCCTBRepGraphProductRemoveShapeRoot`).

---

## EditorView RepOps Non-Guard Setters

*(v0.164.0)* In-place swaps of the geometry object bound to an existing rep-store entry. These do not recreate the rep — they update the pointer in-place, allowing dependent coedges/edges/faces to pick up new geometry without structural graph changes.

---

### `repSetSurface(_:surface:)`

Swap the surface bound to an existing surface rep id.

```swift
public func repSetSurface(_ surfaceRepId: Int, surface: Surface)
```

- **Parameters:** `surfaceRepId` — rep-store surface rep id; `surface` — the replacement `Surface`.
- **OCCT:** `BRepGraph_RepStore` surface entry (via `OCCTBRepGraphRepSetSurface`).

---

### `repSetCurve3D(_:curve:)`

Swap the 3D curve bound to an existing curve-3D rep id.

```swift
public func repSetCurve3D(_ curve3DRepId: Int, curve: Curve3D)
```

- **OCCT:** `BRepGraph_RepStore` curve-3D entry (via `OCCTBRepGraphRepSetCurve3D`).

---

### `repSetCurve2D(_:curve:)`

Swap the 2D curve bound to an existing curve-2D rep id.

```swift
public func repSetCurve2D(_ curve2DRepId: Int, curve: Curve2D)
```

- **OCCT:** `BRepGraph_RepStore` curve-2D entry (via `OCCTBRepGraphRepSetCurve2D`).

---

### `repSetTriangulation(_:triangulation:)`

Swap the triangulation bound to an existing triangulation rep id.

```swift
public func repSetTriangulation(_ triRepId: Int, triangulation: Triangulation)
```

- **OCCT:** `BRepGraph_RepStore` triangulation entry (via `OCCTBRepGraphRepSetTriangulation`).

---

### `repSetPolygon3D(_:polygon:)`

Swap the `Polygon3D` bound to an existing polygon-3D rep id.

```swift
public func repSetPolygon3D(_ polyRepId: Int, polygon: Polygon3D)
```

- **OCCT:** `BRepGraph_RepStore` polygon-3D entry (via `OCCTBRepGraphRepSetPolygon3D`).

---

### `repSetPolygon2D(_:polygon:)`

Swap the `Polygon2D` bound to an existing polygon-2D rep id.

```swift
public func repSetPolygon2D(_ polyRepId: Int, polygon: Polygon2D)
```

- **OCCT:** `BRepGraph_RepStore` polygon-2D entry (via `OCCTBRepGraphRepSetPolygon2D`).

---

### `repSetPolygonOnTri(_:polygon:)`

Swap the `PolygonOnTriangulation` bound to an existing polygon-on-triangulation rep id.

```swift
public func repSetPolygonOnTri(_ polyRepId: Int, polygon: PolygonOnTriangulation)
```

- **OCCT:** `BRepGraph_RepStore` polygon-on-tri entry (via `OCCTBRepGraphRepSetPolygonOnTri`).

---

### `repSetPolygonOnTriTriangulationId(_:triRepId:)`

Update the triangulation id referenced by an existing polygon-on-triangulation rep.

```swift
public func repSetPolygonOnTriTriangulationId(_ polyOnTriRepId: Int, triRepId: Int)
```

- **Parameters:** `polyOnTriRepId` — the polygon-on-tri rep to update; `triRepId` — the new triangulation rep id.
- **OCCT:** `BRepGraph_RepStore` polygon-on-tri triangulation-id field (via `OCCTBRepGraphRepSetPolygonOnTriTriangulationId`).
- **Example:**
  ```swift
  // After replacing a triangulation, rebind the polygon-on-tri to the new rep:
  graph.repSetTriangulation(newTriRepId, triangulation: updatedTri)
  graph.repSetPolygonOnTriTriangulationId(polyOnTriRepId, triRepId: newTriRepId)
  ```

---

## MeshView Cache Entry Inspection

*(v0.164.0)* Read-only accessors for the cached-mesh tier (algorithm-derived meshes). All return absent values (`false`, `0`, or `nil`) when no cache entry exists for the entity.

---

### `cachedFaceMeshIsPresent(_:)`

Whether a cached mesh entry exists for the given face.

```swift
public func cachedFaceMeshIsPresent(_ faceIndex: Int) -> Bool
```

- **OCCT:** `BRepGraph_MeshCache` face entry (via `OCCTBRepGraphCachedFaceMeshIsPresent`).

---

### `cachedFaceMeshTriRepCount(_:)`

Number of triangulation reps in the cached mesh entry for a face.

```swift
public func cachedFaceMeshTriRepCount(_ faceIndex: Int) -> Int
```

- **OCCT:** `OCCTBRepGraphCachedFaceMeshTriRepCount`.

---

### `cachedFaceMeshActiveIndex(_:)`

The active triangulation rep index within the cached mesh entry for a face.

```swift
public func cachedFaceMeshActiveIndex(_ faceIndex: Int) -> Int
```

- **OCCT:** `OCCTBRepGraphCachedFaceMeshActiveIndex`.

---

### `cachedFaceMeshStoredOwnGen(_:)`

The stored generation counter from when the cached face mesh was last committed.

```swift
public func cachedFaceMeshStoredOwnGen(_ faceIndex: Int) -> UInt32
```

Compare against `generation` to detect stale caches.

- **OCCT:** `OCCTBRepGraphCachedFaceMeshStoredOwnGen`.

---

### `cachedFaceMeshTriRepId(_:repIndex:)`

The triangulation rep id at a given rep-slot in the cached face mesh.

```swift
public func cachedFaceMeshTriRepId(_ faceIndex: Int, repIndex: Int) -> Int?
```

- **Returns:** Non-negative rep id, or `nil` if `repIndex` is out of range.
- **OCCT:** `OCCTBRepGraphCachedFaceMeshTriRepId`.
- **Example:**
  ```swift
  if graph.cachedFaceMeshIsPresent(0) {
      let count = graph.cachedFaceMeshTriRepCount(0)
      for i in 0..<count {
          if let repId = graph.cachedFaceMeshTriRepId(0, repIndex: i) {
              print("TriRep:", repId)
          }
      }
  }
  ```

---

### `cachedEdgeMeshIsPresent(_:)`

Whether a cached mesh entry exists for the given edge.

```swift
public func cachedEdgeMeshIsPresent(_ edgeIndex: Int) -> Bool
```

- **OCCT:** `OCCTBRepGraphCachedEdgeMeshIsPresent`.

---

### `cachedEdgeMeshPolygon3DRepId(_:)`

The polygon-3D rep id in the cached edge mesh entry.

```swift
public func cachedEdgeMeshPolygon3DRepId(_ edgeIndex: Int) -> Int?
```

- **Returns:** Non-negative rep id, or `nil` if no entry exists.
- **OCCT:** `OCCTBRepGraphCachedEdgeMeshPolygon3DRepId`.

---

### `cachedEdgeMeshStoredOwnGen(_:)`

The stored generation counter for the cached edge mesh.

```swift
public func cachedEdgeMeshStoredOwnGen(_ edgeIndex: Int) -> UInt32
```

- **OCCT:** `OCCTBRepGraphCachedEdgeMeshStoredOwnGen`.

---

### `cachedCoEdgeMeshIsPresent(_:)`

Whether a cached mesh entry exists for the given coedge.

```swift
public func cachedCoEdgeMeshIsPresent(_ coedgeIndex: Int) -> Bool
```

- **OCCT:** `OCCTBRepGraphCachedCoEdgeMeshIsPresent`.

---

### `cachedCoEdgeMeshPolygon2DRepId(_:)`

The polygon-2D rep id in the cached coedge mesh entry.

```swift
public func cachedCoEdgeMeshPolygon2DRepId(_ coedgeIndex: Int) -> Int?
```

- **Returns:** Non-negative rep id, or `nil` if no entry exists.
- **OCCT:** `OCCTBRepGraphCachedCoEdgeMeshPolygon2DRepId`.

---

### `cachedCoEdgeMeshPolygonOnTriRepCount(_:)`

Number of polygon-on-triangulation reps in the cached coedge mesh entry.

```swift
public func cachedCoEdgeMeshPolygonOnTriRepCount(_ coedgeIndex: Int) -> Int
```

- **OCCT:** `OCCTBRepGraphCachedCoEdgeMeshPolygonOnTriRepCount`.

---

### `cachedCoEdgeMeshPolygonOnTriRepId(_:repIndex:)`

The polygon-on-triangulation rep id at a given rep-slot in the cached coedge mesh.

```swift
public func cachedCoEdgeMeshPolygonOnTriRepId(_ coedgeIndex: Int, repIndex: Int) -> Int?
```

- **Returns:** Non-negative rep id, or `nil` if `repIndex` is out of range.
- **OCCT:** `OCCTBRepGraphCachedCoEdgeMeshPolygonOnTriRepId`.

---

### `cachedCoEdgeMeshStoredOwnGen(_:)`

The stored generation counter for the cached coedge mesh.

```swift
public func cachedCoEdgeMeshStoredOwnGen(_ coedgeIndex: Int) -> UInt32
```

- **OCCT:** `OCCTBRepGraphCachedCoEdgeMeshStoredOwnGen`.

---

## UV-Grid Sampling

*(v0.136.0)*

### `FaceGridSample`

Result of sampling a face surface on a regular UV grid.

```swift
public struct FaceGridSample: Sendable {
    /// Surface positions at grid points.
    public let positions: [SIMD3<Double>]
    /// Surface normals at grid points.
    public let normals: [SIMD3<Double>]
    /// Gaussian curvature at each grid point.
    public let gaussianCurvatures: [Double]
    /// Mean curvature at each grid point.
    public let meanCurvatures: [Double]
    /// Number of samples in U direction.
    public let uSamples: Int
    /// Number of samples in V direction.
    public let vSamples: Int
}
```

Grid points are laid out in row-major order: `index = u * vSamples + v` where `u ∈ [0, uSamples)` and `v ∈ [0, vSamples)`.

---

### `sampleFaceUVGrid(faceIndex:uSamples:vSamples:)`

Sample a face surface on a regular UV grid, evaluating positions, normals, and principal curvatures.

```swift
public func sampleFaceUVGrid(faceIndex: Int, uSamples: Int, vSamples: Int) -> FaceGridSample?
```

- **Parameters:**
  - `faceIndex` — face definition index.
  - `uSamples` — number of samples in U direction (must be ≥ 1).
  - `vSamples` — number of samples in V direction (must be ≥ 1).
- **Returns:** `FaceGridSample` with `uSamples × vSamples` entries, or `nil` if the face has no surface or sampling fails.
- **OCCT:** `GeomLProp_SLProps` (position, normal, curvature evaluation) via `OCCTBRepGraphSampleFaceUVGrid`.
- **Example:**
  ```swift
  if let grid = graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 5, vSamples: 5) {
      for (i, pos) in grid.positions.enumerated() {
          let kG = grid.gaussianCurvatures[i]
          let kH = grid.meanCurvatures[i]
          print("(\(pos.x), \(pos.y), \(pos.z))  kG=\(kG) kH=\(kH)")
      }
  }
  ```

---

## Edge Curve Sampling

*(v0.136.0)*

### `sampleEdgeCurve(edgeIndex:count:)`

Sample evenly-spaced points along an edge curve.

```swift
public func sampleEdgeCurve(edgeIndex: Int, count: Int) -> [SIMD3<Double>]
```

- **Parameters:**
  - `edgeIndex` — edge definition index.
  - `count` — number of points to sample (must be ≥ 1).
- **Returns:** Array of 3D points along the edge curve, in parameter order; empty if the edge has no curve or sampling fails.
- **OCCT:** `GeomAdaptor_Curve` (via `OCCTBRepGraphSampleEdgeCurve`).
- **Example:**
  ```swift
  let pts = graph.sampleEdgeCurve(edgeIndex: 0, count: 20)
  for p in pts {
      print(p.x, p.y, p.z)
  }
  ```

---

## Durable Identity (UID / RefUID / ItemUID)

*(OCCT 8.0.0p1)* The UID system provides counter-based identifiers that remain stable across graph mutations (compaction, node removal) within one graph generation. Unlike `(kind, index)` pairs, counters never repeat within a kind and survive vector-index shifts. A counter of `0` is always the invalid sentinel.

### `GraphUID`

A durable node identifier: a `(kind, counter)` pair for a definition node.

```swift
public struct GraphUID: Sendable, Hashable, Codable {
    public var kind: Int
    public var counter: UInt32
    public init(kind: Int, counter: UInt32)
    public var isValid: Bool { get }
}
```

`kind` is the raw `BRepGraph_NodeId::Kind` ordinal:

| Value | Node type |
|------:|-----------|
| 0 | Solid |
| 1 | Shell |
| 2 | Face |
| 3 | Wire |
| 4 | Edge |
| 5 | Vertex |
| 6 | Compound |
| 7 | CompSolid |
| 8 | CoEdge |
| 10 | Product |
| 11 | Occurrence |

`isValid` returns `true` when `counter > 0`; a valid UID may still fail to resolve if the node has been removed from the graph.

---

### `GraphRefUID`

A durable reference-entry identifier: a `(kind, counter)` pair for a reference (ref) node.

```swift
public struct GraphRefUID: Sendable, Hashable, Codable {
    public var kind: Int
    public var counter: UInt32
    public init(kind: Int, counter: UInt32)
    public var isValid: Bool { get }
}
```

`kind` is the raw `BRepGraph_RefId::Kind` ordinal:

| Value | Ref type |
|------:|----------|
| 0 | Shell |
| 1 | Face |
| 2 | Wire |
| 3 | Vertex |
| 4 | Solid |
| 5 | Child |
| 6 | Occurrence |

---

### `GraphItemUID`

A durable generic item identifier covering both definition nodes (`domain == 1`) and reference entries (`domain == 2`).

```swift
public struct GraphItemUID: Sendable, Hashable, Codable {
    public var domain: Int
    public var kind: Int
    public var counter: UInt32
    public init(domain: Int, kind: Int, counter: UInt32)
    public var isValid: Bool { get }
}
```

`domain` values: 1 = node, 2 = reference. `kind` is the raw kind ordinal in that domain's enum space.

---

### `uid(ofNodeKind:index:)`

Return the durable `GraphUID` for a node.

```swift
public func uid(ofNodeKind kind: Int, index: Int) -> GraphUID?
```

- **Parameters:** `kind` — raw `BRepGraph_NodeId::Kind` ordinal; `index` — per-kind node index.
- **Returns:** `GraphUID` with a non-zero counter, or `nil` if the node is invalid, removed, or out of bounds.
- **OCCT:** `BRepGraph_NodeId` UID query (via `OCCTBRepGraphNodeUID`).
- **Example:**
  ```swift
  if let faceUID = graph.uid(ofNodeKind: 2, index: 0) {  // Face at index 0
      print("Face UID counter:", faceUID.counter)
  }
  ```

---

### `node(forUID:)`

Resolve a `GraphUID` back to its `(kind, index)` in the current graph generation.

```swift
public func node(forUID uid: GraphUID) -> (kind: Int, index: Int)?
```

- **Parameters:** `uid` — a `GraphUID` previously obtained from `uid(ofNodeKind:index:)`.
- **Returns:** `(kind, index)` tuple if the UID resolves in the current generation, or `nil` if the node no longer exists.
- **OCCT:** `BRepGraph_NodeId` reverse lookup (via `OCCTBRepGraphNodeFromUID`).
- **Example:**
  ```swift
  guard let faceUID = graph.uid(ofNodeKind: 2, index: 0) else { return }
  // ... graph mutations ...
  if let resolved = graph.node(forUID: faceUID) {
      print("Face now at index:", resolved.index)
  }
  ```

---

### `contains(uid:) — GraphUID`

Return `true` if a `GraphUID` is valid and exists in this graph generation.

```swift
public func contains(uid: GraphUID) -> Bool
```

- **OCCT:** `OCCTBRepGraphHasNodeUID`.

---

### `uid(ofRefKind:index:)`

Return the durable `GraphRefUID` for a reference entry.

```swift
public func uid(ofRefKind kind: Int, index: Int) -> GraphRefUID?
```

- **Parameters:** `kind` — raw `BRepGraph_RefId::Kind` ordinal; `index` — per-kind reference index.
- **Returns:** `GraphRefUID`, or `nil` if invalid or removed.
- **OCCT:** `BRepGraph_RefId` UID query (via `OCCTBRepGraphRefUID`).

---

### `ref(forUID:)`

Resolve a `GraphRefUID` back to its `(kind, index)`.

```swift
public func ref(forUID uid: GraphRefUID) -> (kind: Int, index: Int)?
```

- **Returns:** `(kind, index)` if the UID resolves, or `nil` if the reference no longer exists.
- **OCCT:** `BRepGraph_RefId` reverse lookup (via `OCCTBRepGraphRefFromUID`).

---

### `contains(uid:) — GraphRefUID`

Return `true` if a `GraphRefUID` is valid and exists in this graph generation.

```swift
public func contains(uid: GraphRefUID) -> Bool
```

- **OCCT:** `OCCTBRepGraphHasRefUID`.

---

### `itemUID(ofNodeKind:index:)`

Return the durable `GraphItemUID` for a node (domain 1).

```swift
public func itemUID(ofNodeKind kind: Int, index: Int) -> GraphItemUID?
```

- **Returns:** `GraphItemUID` with `domain == 1`, or `nil` if the node is invalid or removed.
- **OCCT:** `BRepGraph` item-UID layer (via `OCCTBRepGraphItemUIDOfNode`).
- **Example:**
  ```swift
  if let itemUID = graph.itemUID(ofNodeKind: 2, index: 0) {
      assert(itemUID.domain == 1)
  }
  ```

---

### `item(forUID:)`

Resolve a `GraphItemUID` back to its `(domain, kind, index)`.

```swift
public func item(forUID uid: GraphItemUID) -> (domain: Int, kind: Int, index: Int)?
```

- **Returns:** `(domain, kind, index)` if the UID resolves, or `nil` if the item no longer exists.
- **OCCT:** `BRepGraph` item-UID reverse lookup (via `OCCTBRepGraphItemFromUID`).

---

### `generation`

The current graph generation counter.

```swift
public var generation: UInt32 { get }
```

Incremented each time the graph is cleared or rebuilt. Compare a cached `storedOwnGen` value against `generation` to detect whether a cached mesh is stale.

- **OCCT:** `BRepGraph` generation field (via `OCCTBRepGraphGeneration`).
- **Example:**
  ```swift
  let gen = graph.generation
  // After rebuild:
  let cachedGen = graph.cachedFaceMeshStoredOwnGen(0)
  let isStale = cachedGen != gen
  ```
