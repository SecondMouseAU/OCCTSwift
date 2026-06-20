---
title: TopologyGraph — Builders & Editor Mutation
parent: API Reference
---

# TopologyGraph — Builders & Editor Mutation

This page covers the **mutation surface** of `TopologyGraph` — every query and builder method from
the `// MARK: Edge/Face/Shell/Solid Additional Queries`, `CompSolid Count`, `Builder:` and
`EditorView` sections (source lines 1093–1621). See the main **TopologyGraph** page for
construction, traversal, and the core query API.

## Topics

- [Edge Additional Queries](#edge-additional-queries) · [Face Additional Queries](#face-additional-queries) · [Shell Additional Queries](#shell-additional-queries) · [Solid Additional Queries](#solid-additional-queries) · [CompSolid Count](#compsolid-count) · [Builder: Add Topology Nodes](#builder-add-topology-nodes) · [Builder: Remove/Modify Nodes](#builder-removemodify-nodes) · [Builder: Append Shapes](#builder-append-shapes) · [Builder: Deferred Invalidation](#builder-deferred-invalidation) · [Builder: Edge Splitting](#builder-edge-splitting) · [Builder: Replace Edge in Wire](#builder-replace-edge-in-wire) · [Builder: Remove Ref](#builder-remove-ref) · [Builder: Clear Mesh](#builder-clear-mesh) · [Builder: Validate Mutation](#builder-validate-mutation) · [EditorView Field Setters](#editorview-field-setters) · [EditorView Add Operations](#editorview-add-operations) · [EditorView Remove Operations](#editorview-remove-operations) · [EditorView Ref Setters](#editorview-ref-setters)

---

## Edge Additional Queries

### `edgeWires(_:)`

Returns the indices of all wires that contain a given edge.

```swift
public func edgeWires(_ edgeIndex: Int) -> [Int]
```

- **Parameters:** `edgeIndex` — edge definition index.
- **Returns:** array of wire definition indices; empty if the edge belongs to no wires.
- **OCCT:** `BRepGraph_EditorView` (graph topo layer — wire-membership reverse lookup).
- **Example:**
  ```swift
  let graph = TopologyGraph(shape: solid)
  let wires = graph.edgeWires(0)
  print("edge 0 belongs to \(wires.count) wire(s)")
  ```

---

### `edgeCoEdges(_:)`

Returns the indices of all coedge definitions associated with an edge.

```swift
public func edgeCoEdges(_ edgeIndex: Int) -> [Int]
```

- **Parameters:** `edgeIndex` — edge definition index.
- **Returns:** array of coedge definition indices; empty if none.
- **OCCT:** `BRepGraph_EditorView` (coedge reverse lookup via edge topo layer).
- **Example:**
  ```swift
  let coedges = graph.edgeCoEdges(0)
  for ci in coedges { print("coedge \(ci)") }
  ```

---

### `edgeFindCoEdge(edgeIndex:faceIndex:)`

Finds the coedge index for a given (edge, face) pair.

```swift
public func edgeFindCoEdge(edgeIndex: Int, faceIndex: Int) -> Int?
```

- **Parameters:** `edgeIndex` — edge definition index; `faceIndex` — face definition index.
- **Returns:** coedge definition index, or `nil` if no coedge links this edge to this face.
- **OCCT:** `BRepGraph_Tool::Edge::FindCoEdgeId`.
- **Example:**
  ```swift
  if let ci = graph.edgeFindCoEdge(edgeIndex: 2, faceIndex: 0) {
      print("coedge \(ci) links edge 2 to face 0")
  }
  ```

---

## Face Additional Queries

### `faceShellCount(_:)`

Returns the number of shells that contain a given face.

```swift
public func faceShellCount(_ faceIndex: Int) -> Int
```

- **Parameters:** `faceIndex` — face definition index.
- **OCCT:** `BRepGraph_EditorView` (face-shell parent reverse lookup).

---

### `faceShells(_:)`

Returns the indices of all shells that contain a given face.

```swift
public func faceShells(_ faceIndex: Int) -> [Int]
```

- **Parameters:** `faceIndex` — face definition index.
- **Returns:** array of shell definition indices; empty if the face belongs to no shells.
- **OCCT:** `BRepGraph_EditorView` (face-shell reverse lookup).
- **Example:**
  ```swift
  let shells = graph.faceShells(0)
  print("face 0 is in \(shells.count) shell(s)")
  ```

---

### `faceCompoundCount(_:)`

Returns the number of compounds that directly contain a given face.

```swift
public func faceCompoundCount(_ faceIndex: Int) -> Int
```

- **Parameters:** `faceIndex` — face definition index.
- **OCCT:** `BRepGraph_EditorView` (face-compound parent reverse lookup).

---

## Shell Additional Queries

### `shellCompoundCount(_:)`

Returns the number of compounds that directly contain a given shell.

```swift
public func shellCompoundCount(_ shellIndex: Int) -> Int
```

- **Parameters:** `shellIndex` — shell definition index.
- **OCCT:** `BRepGraph_EditorView` (shell-compound parent reverse lookup).

---

### `isShellClosed(_:)`

Returns whether a shell is topologically closed (every edge is shared by exactly two faces).

```swift
public func isShellClosed(_ shellIndex: Int) -> Bool
```

- **Parameters:** `shellIndex` — shell definition index.
- **OCCT:** `BRepGraph_EditorView` (shell closure derived from face-boundary edge incidence).
- **Note:** In OCCT 8.0.0p1 this is a derived property, not a stored flag.
- **Example:**
  ```swift
  if graph.isShellClosed(0) { print("manifold solid") }
  ```

---

## Solid Additional Queries

### `solidCompoundCount(_:)`

Returns the number of compounds that directly contain a given solid.

```swift
public func solidCompoundCount(_ solidIndex: Int) -> Int
```

- **Parameters:** `solidIndex` — solid definition index.
- **OCCT:** `BRepGraph_EditorView` (solid-compound parent reverse lookup).

---

## CompSolid Count

### `compSolidCount`

Number of comp-solid definitions in the graph.

```swift
public var compSolidCount: Int { get }
```

- **OCCT:** `BRepGraph_EditorView::NbCompSolids`.
- **Example:**
  ```swift
  print(graph.compSolidCount)
  ```

---

## Builder: Add Topology Nodes

### `addVertex(x:y:z:tolerance:)`

Adds a new vertex definition to the graph.

```swift
public func addVertex(x: Double, y: Double, z: Double, tolerance: Double) -> Int?
```

- **Parameters:** `x`, `y`, `z` — 3D position; `tolerance` — vertex tolerance.
- **Returns:** vertex definition index, or `nil` on failure.
- **OCCT:** `BRepGraph_EditorView::Vertices().Add(gp_Pnt, tolerance)`.
- **Example:**
  ```swift
  if let vi = graph.addVertex(x: 0, y: 0, z: 0, tolerance: 1e-7) {
      print("vertex \(vi) added")
  }
  ```

---

### `addShell()`

Adds a new empty shell definition to the graph.

```swift
public func addShell() -> Int?
```

- **Returns:** shell definition index, or `nil` on failure.
- **OCCT:** `BRepGraph_EditorView::Shells().Add()`.
- **Example:**
  ```swift
  if let si = graph.addShell() {
      print("shell \(si) added")
  }
  ```

---

### `addSolid()`

Adds a new empty solid definition to the graph.

```swift
public func addSolid() -> Int?
```

- **Returns:** solid definition index, or `nil` on failure.
- **OCCT:** `BRepGraph_EditorView::Solids().Add()`.

---

### `addFaceToShell(shellIndex:faceIndex:orientation:)`

Links a face into a shell by creating a face reference entry.

```swift
public func addFaceToShell(shellIndex: Int, faceIndex: Int, orientation: Int = 0) -> Int?
```

- **Parameters:** `shellIndex` — shell definition index; `faceIndex` — face definition index; `orientation` — `TopAbs_Orientation` integer (0=FORWARD, 1=REVERSED, 2=INTERNAL, 3=EXTERNAL).
- **Returns:** face reference index, or `nil` on failure.
- **OCCT:** `BRepGraph_EditorView::Shells().Append(BRepGraph_ShellId, BRepGraph_FaceId, TopAbs_Orientation)`.
- **Example:**
  ```swift
  if let si = graph.addShell(), let fi = graph.addFaceToShell(shellIndex: si, faceIndex: 0) {
      print("face ref \(fi) added to shell \(si)")
  }
  ```

---

### `addShellToSolid(solidIndex:shellIndex:orientation:)`

Links a shell into a solid by creating a shell reference entry.

```swift
public func addShellToSolid(solidIndex: Int, shellIndex: Int, orientation: Int = 0) -> Int?
```

- **Parameters:** `solidIndex` — solid definition index; `shellIndex` — shell definition index; `orientation` — `TopAbs_Orientation` integer.
- **Returns:** shell reference index, or `nil` on failure.
- **OCCT:** `BRepGraph_EditorView::Solids().Append(BRepGraph_SolidId, BRepGraph_ShellId, TopAbs_Orientation)`.

---

### `addCompound(children:)`

Creates a new compound definition with the specified child nodes.

```swift
public func addCompound(children: [(kind: NodeKind, index: Int)]) -> Int?
```

- **Parameters:** `children` — array of `(kind, index)` pairs identifying each child node.
- **Returns:** compound definition index, or `nil` if `children` is empty or on failure.
- **OCCT:** `BRepGraph_EditorView::Compounds().Add(NCollection_Array1<BRepGraph_NodeId>)`.
- **Example:**
  ```swift
  if let ci = graph.addCompound(children: [(.solid, 0), (.solid, 1)]) {
      print("compound \(ci) created")
  }
  ```

---

### `addCompSolid(solidIndices:)`

Creates a new comp-solid definition from an array of solid indices.

```swift
public func addCompSolid(solidIndices: [Int]) -> Int?
```

- **Parameters:** `solidIndices` — solid definition indices to collect into the comp-solid.
- **Returns:** comp-solid definition index, or `nil` if `solidIndices` is empty or on failure.
- **OCCT:** `BRepGraph_EditorView::CompSolids().Add(NCollection_Array1<BRepGraph_SolidId>)`.

---

## Builder: Remove/Modify Nodes

### `removeNode(nodeKind:nodeIndex:)`

Marks a single node as removed (soft deletion — the graph entry persists but is flagged inactive).

```swift
public func removeNode(nodeKind: NodeKind, nodeIndex: Int)
```

- **Parameters:** `nodeKind` — node kind; `nodeIndex` — definition index.
- **OCCT:** `BRepGraph_EditorView::Gen().RemoveNode(BRepGraph_NodeId)`.
- **Example:**
  ```swift
  graph.removeNode(nodeKind: .face, nodeIndex: 3)
  ```

---

### `removeSubgraph(nodeKind:nodeIndex:)`

Marks a node and all its topological descendants as removed (cascading soft deletion).

```swift
public func removeSubgraph(nodeKind: NodeKind, nodeIndex: Int)
```

- **Parameters:** `nodeKind` — root node kind; `nodeIndex` — root definition index.
- **OCCT:** `BRepGraph_EditorView::Gen().RemoveSubgraph(BRepGraph_NodeId)`.
- **Note:** Use this instead of iterating descendants manually when pruning a subtree.
- **Example:**
  ```swift
  graph.removeSubgraph(nodeKind: .solid, nodeIndex: 1)
  ```

---

## Builder: Append Shapes

### `appendFlattenedShape(_:parallel:)`

Appends a `Shape` to the graph in flattened mode — container nodes are removed and faces are
registered directly as graph roots.

```swift
public func appendFlattenedShape(_ shape: Shape, parallel: Bool = false)
```

- **Parameters:** `shape` — shape to ingest; `parallel` — whether to use multi-threaded ingestion.
- **OCCT:** `BRepGraph::ShapesView::Add(TopoDS_Shape, Options{Flatten=true})`.
- **Example:**
  ```swift
  graph.appendFlattenedShape(compound, parallel: true)
  ```

---

### `appendFullShape(_:parallel:)`

Appends a `Shape` to the graph preserving the full B-Rep topology hierarchy.

```swift
public func appendFullShape(_ shape: Shape, parallel: Bool = false)
```

- **Parameters:** `shape` — shape to ingest; `parallel` — whether to use multi-threaded ingestion.
- **OCCT:** `BRepGraph::ShapesView::Add(TopoDS_Shape, Options{Flatten=false})`.
- **Example:**
  ```swift
  graph.appendFullShape(solid)
  ```

---

## Builder: Deferred Invalidation

### `beginDeferredInvalidation()`

Enters deferred invalidation mode. In this mode reverse-index updates are batched instead of
applied immediately, making bulk mutations significantly faster.

```swift
public func beginDeferredInvalidation()
```

- **OCCT:** `BRepGraph_EditorView::BeginDeferredInvalidation()`.
- **Note:** Always pair with `endDeferredInvalidation()`.

---

### `endDeferredInvalidation()`

Exits deferred invalidation mode and flushes all accumulated reverse-index changes.

```swift
public func endDeferredInvalidation()
```

- **OCCT:** `BRepGraph_EditorView::EndDeferredInvalidation()`.
- **Example:**
  ```swift
  graph.beginDeferredInvalidation()
  for face in facesToRemove { graph.removeNode(nodeKind: .face, nodeIndex: face) }
  graph.endDeferredInvalidation()
  ```

---

### `isDeferredMode`

Whether deferred invalidation mode is currently active.

```swift
public var isDeferredMode: Bool { get }
```

- **OCCT:** `BRepGraph_EditorView::IsDeferredMode()`.

---

### `commitMutation()`

Validates reverse-index consistency after a batch mutation; call after `endDeferredInvalidation()`.

```swift
public func commitMutation()
```

- **OCCT:** `BRepGraph_EditorView::CommitMutation()`.

---

## Builder: Edge Splitting

### `splitEdge(edgeIndex:vertexIndex:param:)`

Splits an edge at a given vertex and curve parameter, producing two sub-edges.

```swift
public func splitEdge(edgeIndex: Int, vertexIndex: Int, param: Double) -> (subA: Int, subB: Int)?
```

- **Parameters:** `edgeIndex` — edge definition index to split; `vertexIndex` — vertex definition index at the split point; `param` — parameter on the 3D curve at the split point.
- **Returns:** `(subA, subB)` edge definition indices, or `nil` if the split fails.
- **OCCT:** `BRepGraph_EditorView::Edges().Split(BRepGraph_EdgeId, BRepGraph_VertexId, double, subA, subB)`.
- **Example:**
  ```swift
  if let (a, b) = graph.splitEdge(edgeIndex: 0, vertexIndex: 5, param: 0.5) {
      print("split into edges \(a) and \(b)")
  }
  ```

---

## Builder: Replace Edge in Wire

### `replaceEdgeInWire(wireIndex:oldEdgeIndex:newEdgeIndex:reversed:)`

Substitutes one edge for another in a wire definition.

```swift
public func replaceEdgeInWire(wireIndex: Int, oldEdgeIndex: Int, newEdgeIndex: Int, reversed: Bool = false)
```

- **Parameters:** `wireIndex` — wire definition index; `oldEdgeIndex` — edge to replace; `newEdgeIndex` — replacement edge; `reversed` — whether to reverse the orientation of the replacement edge.
- **OCCT:** `BRepGraph_EditorView::Wires().ReplaceEdge(BRepGraph_WireId, BRepGraph_EdgeId, BRepGraph_EdgeId, bool)`.
- **Example:**
  ```swift
  graph.replaceEdgeInWire(wireIndex: 0, oldEdgeIndex: 2, newEdgeIndex: 7)
  ```

---

## Builder: Remove Ref

### `removeRef(refKind:refIndex:)`

Marks a reference entry as removed.

```swift
@discardableResult
public func removeRef(refKind: RefKind, refIndex: Int) -> Bool
```

- **Parameters:** `refKind` — reference kind (see `RefKind` enum); `refIndex` — reference index.
- **Returns:** `true` if the reference transitioned from active to removed.
- **OCCT:** `BRepGraph_EditorView::Gen().RemoveRef(BRepGraph_RefId)`.
- **Example:**
  ```swift
  let removed = graph.removeRef(refKind: .face, refIndex: 4)
  ```

---

## Builder: Clear Mesh

### `clearFaceMesh(faceIndex:)`

Clears all mesh representations (triangulation and coedge polygon-on-triangulation) for a face.

```swift
public func clearFaceMesh(faceIndex: Int)
```

- **Parameters:** `faceIndex` — face definition index.
- **OCCT:** `BRepGraph_EditorView::Mesh::Editor::Faces().Clear(BRepGraph_FaceId)`.

---

### `clearEdgePolygon3D(edgeIndex:)`

Clears the Polygon3D mesh representation from an edge.

```swift
public func clearEdgePolygon3D(edgeIndex: Int)
```

- **Parameters:** `edgeIndex` — edge definition index.
- **OCCT:** `BRepGraph_EditorView::Mesh::Editor::Edges().Clear(BRepGraph_EdgeId)`.
- **Example:**
  ```swift
  graph.clearFaceMesh(faceIndex: 0)
  graph.clearEdgePolygon3D(edgeIndex: 0)
  ```

---

## Builder: Validate Mutation

### `validateMutation()`

Validates mutation-boundary invariants after a batch of graph edits.

```swift
public func validateMutation() -> Bool
```

- **Returns:** `true` if no consistency issues were found.
- **OCCT:** `BRepGraph_EditorView::ValidateMutationBoundary()`.
- **Example:**
  ```swift
  guard graph.validateMutation() else { fatalError("graph mutation left inconsistent state") }
  ```

---

## EditorView Field Setters

These setters write directly into definition fields via `BRepGraph_EditorView`. Several flags
became derived properties in OCCT 8.0.0p1 and are accepted by the API but are **no-ops** (noted
per entry).

### `setVertexPoint(_:x:y:z:)`

Set the 3D point of a vertex definition.

```swift
public func setVertexPoint(_ vertexIndex: Int, x: Double, y: Double, z: Double)
```

- **Parameters:** `vertexIndex` — vertex definition index; `x`, `y`, `z` — new position.
- **OCCT:** `BRepGraph_EditorView::Vertices().SetPoint(BRepGraph_VertexId, gp_Pnt)`.

---

### `setVertexTolerance(_:tolerance:)`

Set the tolerance of a vertex definition.

```swift
public func setVertexTolerance(_ vertexIndex: Int, tolerance: Double)
```

- **Parameters:** `vertexIndex` — vertex definition index; `tolerance` — new tolerance value.
- **OCCT:** `BRepGraph_EditorView::Vertices().SetTolerance(BRepGraph_VertexId, double)`.

---

### `setEdgeTolerance(_:tolerance:)`

Set the tolerance of an edge definition.

```swift
public func setEdgeTolerance(_ edgeIndex: Int, tolerance: Double)
```

- **Parameters:** `edgeIndex` — edge definition index; `tolerance` — new tolerance value.
- **OCCT:** `BRepGraph_EditorView::Edges().SetTolerance(BRepGraph_EdgeId, double)`.

---

### `setEdgeParamRange(_:first:last:)`

Set the parametric range of an edge definition.

```swift
public func setEdgeParamRange(_ edgeIndex: Int, first: Double, last: Double)
```

- **Parameters:** `edgeIndex` — edge definition index; `first`, `last` — parametric bounds.
- **OCCT:** `BRepGraph_EditorView::Edges().SetParamRange(BRepGraph_EdgeId, double, double)`.

---

### `setEdgeSameParameter(_:sameParameter:)`

Set the `SameParameter` flag of an edge definition.

```swift
public func setEdgeSameParameter(_ edgeIndex: Int, sameParameter: Bool)
```

- **Parameters:** `edgeIndex` — edge definition index; `sameParameter` — flag value.
- **Note:** **No-op in OCCT 8.0.0p1.** `SameParameter` is now a derived per-coedge property computed from the pcurve vs 3D curve; there is no longer a settable edge flag. Kept for ABI compatibility.

---

### `setEdgeSameRange(_:sameRange:)`

Set the `SameRange` flag of an edge definition.

```swift
public func setEdgeSameRange(_ edgeIndex: Int, sameRange: Bool)
```

- **Parameters:** `edgeIndex` — edge definition index; `sameRange` — flag value.
- **Note:** **No-op in OCCT 8.0.0p1.** Same reason as `setEdgeSameParameter`.

---

### `setEdgeDegenerate(_:degenerate:)`

Set the `IsDegenerate` flag of an edge definition.

```swift
public func setEdgeDegenerate(_ edgeIndex: Int, degenerate: Bool)
```

- **Parameters:** `edgeIndex` — edge definition index; `degenerate` — flag value.
- **Note:** **No-op in OCCT 8.0.0p1.** Degeneracy is derived from geometry/topology; there is no longer a settable flag.

---

### `setEdgeIsClosed(_:isClosed:)`

Set the `IsClosed` flag of an edge definition.

```swift
public func setEdgeIsClosed(_ edgeIndex: Int, isClosed: Bool)
```

- **Parameters:** `edgeIndex` — edge definition index; `isClosed` — flag value.
- **Note:** **No-op in OCCT 8.0.0p1.** Closure is derived from whether start-vertex == end-vertex; there is no longer a settable flag.

---

### `setCoEdgeParamRange(_:first:last:)`

Set the parametric range of a coedge definition.

```swift
public func setCoEdgeParamRange(_ coedgeIndex: Int, first: Double, last: Double)
```

- **Parameters:** `coedgeIndex` — coedge definition index; `first`, `last` — parametric bounds on the pcurve.
- **OCCT:** `BRepGraph_EditorView::CoEdges().SetParamRange(BRepGraph_CoEdgeId, double, double)`.

---

### `setCoEdgeOrientation(_:orientation:)`

Set the orientation of a coedge in its owning face.

```swift
public func setCoEdgeOrientation(_ coedgeIndex: Int, orientation: Int)
```

- **Parameters:** `coedgeIndex` — coedge definition index; `orientation` — `TopAbs_Orientation` integer (0=Forward, 1=Reversed, 2=Internal, 3=External).
- **OCCT:** `BRepGraph_EditorView::CoEdges().SetOrientation(BRepGraph_CoEdgeId, TopAbs_Orientation)`.

---

### `setWireIsClosed(_:isClosed:)`

Set the `IsClosed` flag of a wire definition.

```swift
public func setWireIsClosed(_ wireIndex: Int, isClosed: Bool)
```

- **Parameters:** `wireIndex` — wire definition index; `isClosed` — flag value.
- **Note:** **No-op in OCCT 8.0.0p1.** Wire closure is derived from the ordered coedge chain; there is no longer a settable flag.

---

### `setFaceTolerance(_:tolerance:)`

Set the tolerance of a face definition.

```swift
public func setFaceTolerance(_ faceIndex: Int, tolerance: Double)
```

- **Parameters:** `faceIndex` — face definition index; `tolerance` — new tolerance value.
- **OCCT:** `BRepGraph_EditorView::Faces().SetTolerance(BRepGraph_FaceId, double)`.

---

### `setFaceNaturalRestriction(_:naturalRestriction:)`

Set the natural-restriction flag of a face definition.

```swift
public func setFaceNaturalRestriction(_ faceIndex: Int, naturalRestriction: Bool)
```

- **Parameters:** `faceIndex` — face definition index; `naturalRestriction` — flag value.
- **Note:** **No-op in OCCT 8.0.0p1.** The natural-restriction flag is no longer stored or settable.

---

### `setShellIsClosed(_:isClosed:)`

Set the `IsClosed` flag of a shell definition.

```swift
public func setShellIsClosed(_ shellIndex: Int, isClosed: Bool)
```

- **Parameters:** `shellIndex` — shell definition index; `isClosed` — flag value.
- **Note:** **No-op in OCCT 8.0.0p1.** Shell closure is derived from face-boundary edge incidence; there is no longer a settable flag.

---

## EditorView Add Operations

### `edgeAddInternalVertex(_:vertexIndex:orientation:)`

Attaches an internal vertex to an edge as a runtime supplement attachment (OCCT 8.0.0p1 model).

```swift
public func edgeAddInternalVertex(_ edgeIndex: Int, vertexIndex: Int, orientation: Int = 2) -> Int?
```

- **Parameters:** `edgeIndex` — edge definition index; `vertexIndex` — vertex definition index; `orientation` — accepted for source compatibility but **ignored** by the supplement layer.
- **Returns:** layer-local attachment UID, or `nil` on failure. Store this to remove the attachment later via `faceRemoveVertex(_:attachmentUID:)`.
- **OCCT:** `BRepGraph_EditorView::Supplement().AttachToEdge(BRepGraph_EdgeId, TopoDS_Vertex, AttachmentKind::EdgeInternalVertex)` via `BRepGraph_LayerTopoSupplement`.
- **Note:** Internal-edge vertices are a supplemental, runtime concept in OCCT 8.0.0p1 — a clean shape has none until one is added here.
- **Example:**
  ```swift
  if let uid = graph.edgeAddInternalVertex(0, vertexIndex: 3) {
      print("attached internal vertex, uid=\(uid)")
  }
  ```

---

### `faceAddVertex(_:vertexIndex:orientation:)`

Attaches a direct vertex to a face as a runtime supplement attachment (OCCT 8.0.0p1 model).

```swift
public func faceAddVertex(_ faceIndex: Int, vertexIndex: Int, orientation: Int = 0) -> Int?
```

- **Parameters:** `faceIndex` — face definition index; `vertexIndex` — vertex definition index; `orientation` — accepted for source compatibility but **ignored** by the supplement layer.
- **Returns:** layer-local attachment UID, or `nil` on failure. Store this UID to pass to `faceRemoveVertex(_:attachmentUID:)`.
- **OCCT:** `BRepGraph_EditorView::Supplement().AttachToFace(BRepGraph_FaceId, TopoDS_Vertex, AttachmentKind::FaceDirectVertex)` via `BRepGraph_LayerTopoSupplement`.

---

### `shellAddChild(_:childKind:childIndex:orientation:)`

Links an auxiliary non-face child (Wire or Edge) to a shell.

```swift
public func shellAddChild(_ shellIndex: Int, childKind: Int, childIndex: Int, orientation: Int = 0) -> Int?
```

- **Parameters:** `shellIndex` — shell definition index; `childKind` — raw `NodeKind` integer; `childIndex` — child definition index; `orientation` — `TopAbs_Orientation` integer.
- **Returns:** child-ref id, or `nil` on failure.
- **OCCT:** `BRepGraph_EditorView::Shells().Append(BRepGraph_ShellId, BRepGraph_FaceId, TopAbs_Orientation)` (OCCT 8.0.0p1: shells own only faces; non-face kinds return `nil`).
- **Note:** In OCCT 8.0.0p1 shells own only face children — passing a non-face kind returns `nil`.

---

### `solidAddChild(_:childKind:childIndex:orientation:)`

Links an auxiliary non-shell child (Edge or Vertex) to a solid.

```swift
public func solidAddChild(_ solidIndex: Int, childKind: Int, childIndex: Int, orientation: Int = 0) -> Int?
```

- **Parameters:** `solidIndex` — solid definition index; `childKind` — raw `NodeKind` integer; `childIndex` — child definition index; `orientation` — `TopAbs_Orientation` integer.
- **Returns:** child-ref id, or `nil` on failure.
- **OCCT:** `BRepGraph_EditorView::Solids().Append(BRepGraph_SolidId, BRepGraph_ShellId, TopAbs_Orientation)` (OCCT 8.0.0p1: solids own only shells; non-shell kinds return `nil`).

---

### `compoundAddChild(_:childKind:childIndex:orientation:)`

Appends a single child node to an existing compound definition.

```swift
public func compoundAddChild(_ compoundIndex: Int, childKind: Int, childIndex: Int, orientation: Int = 0) -> Int?
```

- **Parameters:** `compoundIndex` — compound definition index; `childKind` — raw `NodeKind` integer; `childIndex` — child definition index; `orientation` — `TopAbs_Orientation` integer.
- **Returns:** child-ref id, or `nil` on failure.
- **OCCT:** `BRepGraph_EditorView::Compounds().Append(BRepGraph_CompoundId, BRepGraph_NodeId, TopAbs_Orientation)`.
- **Example:**
  ```swift
  if let ref = graph.compoundAddChild(0, childKind: NodeKind.solid.rawValue, childIndex: 2) {
      print("added solid 2 to compound 0, ref=\(ref)")
  }
  ```

---

### `compSolidAddSolid(_:solidIndex:orientation:)`

Appends a single solid to an existing comp-solid definition.

```swift
public func compSolidAddSolid(_ compSolidIndex: Int, solidIndex: Int, orientation: Int = 0) -> Int?
```

- **Parameters:** `compSolidIndex` — comp-solid definition index; `solidIndex` — solid definition index; `orientation` — `TopAbs_Orientation` integer.
- **Returns:** solid-ref id, or `nil` on failure.
- **OCCT:** `BRepGraph_EditorView::CompSolids().Append(BRepGraph_CompSolidId, BRepGraph_SolidId, TopAbs_Orientation)`.

---

## EditorView Remove Operations

### `edgeRemoveVertex(_:vertexRefIndex:)`

Detaches a vertex reference from an edge definition.

```swift
public func edgeRemoveVertex(_ edgeIndex: Int, vertexRefIndex: Int) -> Bool
```

- **Parameters:** `edgeIndex` — edge definition index; `vertexRefIndex` — vertex reference index.
- **Returns:** `true` if the active usage was removed.
- **OCCT:** `BRepGraph_EditorView::Edges().RemoveVertex(BRepGraph_EdgeId, BRepGraph_VertexRefId)`.

---

### `edgeReplaceVertex(_:oldVertexRefIndex:newVertexIndex:)`

Remaps an edge-owned vertex reference to a different vertex definition.

```swift
public func edgeReplaceVertex(_ edgeIndex: Int, oldVertexRefIndex: Int, newVertexIndex: Int) -> Int?
```

- **Parameters:** `edgeIndex` — edge definition index; `oldVertexRefIndex` — existing vertex reference index; `newVertexIndex` — new vertex definition index.
- **Returns:** new vertex-ref id, or `nil` on failure.
- **OCCT:** `BRepGraph_EditorView::Edges().ReplaceVertex(BRepGraph_EdgeId, BRepGraph_VertexRefId, BRepGraph_VertexId)`.

---

### `wireRemoveCoEdge(_:coedgeRefIndex:)`

Detaches a coedge reference from a wire definition.

```swift
public func wireRemoveCoEdge(_ wireIndex: Int, coedgeRefIndex: Int) -> Bool
```

- **Parameters:** `wireIndex` — wire definition index; `coedgeRefIndex` — coedge reference index.
- **Returns:** `true` if the active usage was removed.
- **OCCT:** `BRepGraph_EditorView::Wires().RemoveCoEdge(BRepGraph_WireId, BRepGraph_CoEdgeId)`.
- **Note:** In OCCT 8.0.0p1 coedges are not ref-counted; `coedgeRefIndex` is a direct `BRepGraph_CoEdgeId`.

---

### `faceRemoveVertex(_:attachmentUID:)`

Detaches a face-direct vertex supplement attachment by its UID.

```swift
public func faceRemoveVertex(_ faceIndex: Int, attachmentUID: Int) -> Bool
```

- **Parameters:** `faceIndex` — face definition index (unused in OCCT 8.0.0p1; the UID is globally unique within the supplement layer); `attachmentUID` — the UID returned by `faceAddVertex`.
- **Returns:** `true` if the attachment existed and was removed.
- **OCCT:** `BRepGraph_EditorView::Supplement().RemoveAttachment(uint64_t uid)` via `BRepGraph_LayerTopoSupplement`.

---

### `faceRemoveWire(_:wireRefIndex:)`

Detaches a wire reference from a face definition.

```swift
public func faceRemoveWire(_ faceIndex: Int, wireRefIndex: Int) -> Bool
```

- **Parameters:** `faceIndex` — face definition index; `wireRefIndex` — wire reference index.
- **Returns:** `true` if the active usage was removed.
- **OCCT:** `BRepGraph_EditorView::Faces().RemoveWire(BRepGraph_FaceId, BRepGraph_WireRefId)`.

---

### `shellRemoveFace(_:faceRefIndex:)`

Detaches a face reference from a shell definition.

```swift
public func shellRemoveFace(_ shellIndex: Int, faceRefIndex: Int) -> Bool
```

- **Parameters:** `shellIndex` — shell definition index; `faceRefIndex` — face reference index.
- **Returns:** `true` if the active usage was removed.
- **OCCT:** `BRepGraph_EditorView::Shells().RemoveFace(BRepGraph_ShellId, BRepGraph_FaceRefId)`.

---

### `shellRemoveChild(_:childRefIndex:)`

Detaches an auxiliary child reference from a shell.

```swift
public func shellRemoveChild(_ shellIndex: Int, childRefIndex: Int) -> Bool
```

- **Parameters:** `shellIndex` — shell definition index; `childRefIndex` — child reference index.
- **Returns:** `true` if the active usage was removed.
- **OCCT:** `BRepGraph_EditorView::Shells().RemoveFace(BRepGraph_ShellId, BRepGraph_FaceRefId)` (OCCT 8.0.0p1: shells own only faces; the child-ref is treated as a face-ref).

---

### `solidRemoveShell(_:shellRefIndex:)`

Detaches a shell reference from a solid definition.

```swift
public func solidRemoveShell(_ solidIndex: Int, shellRefIndex: Int) -> Bool
```

- **Parameters:** `solidIndex` — solid definition index; `shellRefIndex` — shell reference index.
- **Returns:** `true` if the active usage was removed.
- **OCCT:** `BRepGraph_EditorView::Solids().RemoveShell(BRepGraph_SolidId, BRepGraph_ShellRefId)`.

---

### `solidRemoveChild(_:childRefIndex:)`

Detaches an auxiliary child reference from a solid.

```swift
public func solidRemoveChild(_ solidIndex: Int, childRefIndex: Int) -> Bool
```

- **Parameters:** `solidIndex` — solid definition index; `childRefIndex` — child reference index.
- **Returns:** `true` if the active usage was removed.
- **OCCT:** `BRepGraph_EditorView::Solids().RemoveShell(BRepGraph_SolidId, BRepGraph_ShellRefId)` (OCCT 8.0.0p1: solids own only shells; the child-ref is treated as a shell-ref).

---

### `compoundRemoveChild(_:childRefIndex:)`

Detaches a child reference from a compound definition.

```swift
public func compoundRemoveChild(_ compoundIndex: Int, childRefIndex: Int) -> Bool
```

- **Parameters:** `compoundIndex` — compound definition index; `childRefIndex` — child reference index.
- **Returns:** `true` if the active usage was removed.
- **OCCT:** `BRepGraph_EditorView::Compounds().RemoveChild(BRepGraph_CompoundId, BRepGraph_ChildRefId)`.

---

### `compSolidRemoveSolid(_:solidRefIndex:)`

Detaches a solid reference from a comp-solid definition.

```swift
public func compSolidRemoveSolid(_ compSolidIndex: Int, solidRefIndex: Int) -> Bool
```

- **Parameters:** `compSolidIndex` — comp-solid definition index; `solidRefIndex` — solid reference index.
- **Returns:** `true` if the active usage was removed.
- **OCCT:** `BRepGraph_EditorView::CompSolids().RemoveSolid(BRepGraph_CompSolidId, BRepGraph_SolidRefId)`.

---

### `removeRep(repKind:repIndex:)`

Removes a representation (surface, curve, triangulation, polygon) from its side-registry slot.

```swift
public func removeRep(repKind: Int, repIndex: Int)
```

- **Parameters:** `repKind` — representation kind integer (0=FaceSurface, 1=FaceTriangulation, 2=EdgeCurve3D, 3=EdgePolygon3D, 4=CoEdgeCurve2D, 5=CoEdgePolygon2D, 6=CoEdgePolygonOnTri); `repIndex` — index returned when the rep was added.
- **OCCT:** Pure-Swift side-registry nullification; does not call a single OCCT C++ method — the slot is nullified so that a subsequent `Set*RepId()` call resolving the same index becomes a safe no-op.
- **Note:** In OCCT 8.0.0p1 representations are owned by their topology definitions and cleared through per-kind editors. This method nullifies the OCCTSwift side-registry slot only.

---

## EditorView Ref Setters

These setters write directly into reference-entry fields via `BRepGraph_EditorView`. Entries marked
**no-op** are not yet modifiable in the underlying OCCT 8.0.0p1 API and are retained for ABI
compatibility.

### `setVertexRefOrientation(_:orientation:)`

```swift
public func setVertexRefOrientation(_ vertexRefIndex: Int, orientation: Int)
```

- **OCCT:** `BRepGraph_EditorView::Vertices().SetRefOrientation(BRepGraph_VertexRefId, TopAbs_Orientation)`.

---

### `setVertexRefVertexDefId(_:vertexIndex:)`

```swift
public func setVertexRefVertexDefId(_ vertexRefIndex: Int, vertexIndex: Int)
```

- **OCCT:** `BRepGraph_EditorView::Vertices().SetRefChildVertexId` (renamed in OCCT 8.0.0p1).

---

### `setEdgeStartVertexRefId(_:vertexRefIndex:)`

```swift
public func setEdgeStartVertexRefId(_ edgeIndex: Int, vertexRefIndex: Int)
```

- **OCCT:** `BRepGraph_EditorView::Edges().SetStartVertexRefId(BRepGraph_EdgeId, BRepGraph_VertexRefId)`.

---

### `setEdgeEndVertexRefId(_:vertexRefIndex:)`

```swift
public func setEdgeEndVertexRefId(_ edgeIndex: Int, vertexRefIndex: Int)
```

- **OCCT:** `BRepGraph_EditorView::Edges().SetEndVertexRefId(BRepGraph_EdgeId, BRepGraph_VertexRefId)`.

---

### `setEdgeCurve3DRepId(_:curve3DRepId:)`

```swift
public func setEdgeCurve3DRepId(_ edgeIndex: Int, curve3DRepId: Int)
```

- **OCCT:** `BRepGraph_EditorView::Edges()` curve-3D rep slot setter.

---

### `setEdgePolygon3DRepId(_:polygon3DRepId:)`

```swift
public func setEdgePolygon3DRepId(_ edgeIndex: Int, polygon3DRepId: Int)
```

- **OCCT:** `BRepGraph_EditorView::Edges()` polygon-3D rep slot setter.

---

### `setCoEdgeRefCoEdgeDefId(_:coedgeIndex:)`

```swift
public func setCoEdgeRefCoEdgeDefId(_ coedgeRefIndex: Int, coedgeIndex: Int)
```

- **Note:** **No-op in OCCT 8.0.0p1.** CoEdge ref-to-def remapping is not exposed by the current editor API.

---

### `setCoEdgeEdgeDefId(_:edgeIndex:)`

```swift
public func setCoEdgeEdgeDefId(_ coedgeIndex: Int, edgeIndex: Int)
```

- **OCCT:** `BRepGraph_EditorView::CoEdges()` edge-def id setter.

---

### `setCoEdgeFaceDefId(_:faceIndex:)`

```swift
public func setCoEdgeFaceDefId(_ coedgeIndex: Int, faceIndex: Int)
```

- **OCCT:** `BRepGraph_EditorView::CoEdges()` face-def id setter.

---

### `setCoEdgeCurve2DRepId(_:curve2DRepId:)`

```swift
public func setCoEdgeCurve2DRepId(_ coedgeIndex: Int, curve2DRepId: Int)
```

- **OCCT:** `BRepGraph_EditorView::CoEdges()` curve-2D rep slot setter.

---

### `setCoEdgePolygon2DRepId(_:polygon2DRepId:)`

```swift
public func setCoEdgePolygon2DRepId(_ coedgeIndex: Int, polygon2DRepId: Int)
```

- **OCCT:** `BRepGraph_EditorView::CoEdges()` polygon-2D rep slot setter.

---

### `setCoEdgePolygonOnTriRepId(_:polygonOnTriRepId:)`

```swift
public func setCoEdgePolygonOnTriRepId(_ coedgeIndex: Int, polygonOnTriRepId: Int)
```

- **OCCT:** `BRepGraph_EditorView::CoEdges()` polygon-on-triangulation rep slot setter.

---

### `clearCoEdgePCurveBinding(_:)`

Clears all pcurve bindings (curve-2D, polygon-2D, polygon-on-tri) from a coedge definition.

```swift
public func clearCoEdgePCurveBinding(_ coedgeIndex: Int)
```

- **OCCT:** `BRepGraph_EditorView::CoEdges()` pcurve clearing helper.

---

### `setWireRefIsOuter(_:isOuter:)`

```swift
public func setWireRefIsOuter(_ wireRefIndex: Int, isOuter: Bool)
```

- **Note:** **No-op in OCCT 8.0.0p1.** The outer-wire flag is not settable via the editor; the outer wire is determined by orientation.

---

### `setWireRefOrientation(_:orientation:)`

```swift
public func setWireRefOrientation(_ wireRefIndex: Int, orientation: Int)
```

- **OCCT:** `BRepGraph_EditorView::Faces()` wire-ref orientation setter (WireRefId → TopAbs_Orientation).

---

### `setWireRefWireDefId(_:wireIndex:)`

```swift
public func setWireRefWireDefId(_ wireRefIndex: Int, wireIndex: Int)
```

- **OCCT:** `BRepGraph_EditorView::Faces()` wire-ref def-id setter.

---

### `setFaceSurfaceRepId(_:surfaceRepId:)`

```swift
public func setFaceSurfaceRepId(_ faceIndex: Int, surfaceRepId: Int)
```

- **OCCT:** `BRepGraph_EditorView::Faces()` surface rep slot setter.

---

### `setFaceRefOrientation(_:orientation:)`

```swift
public func setFaceRefOrientation(_ faceRefIndex: Int, orientation: Int)
```

- **OCCT:** `BRepGraph_EditorView::Shells()` face-ref orientation setter.

---

### `setFaceRefFaceDefId(_:faceIndex:)`

```swift
public func setFaceRefFaceDefId(_ faceRefIndex: Int, faceIndex: Int)
```

- **OCCT:** `BRepGraph_EditorView::Shells()` face-ref def-id setter.

---

### `setShellRefOrientation(_:orientation:)`

```swift
public func setShellRefOrientation(_ shellRefIndex: Int, orientation: Int)
```

- **OCCT:** `BRepGraph_EditorView::Solids()` shell-ref orientation setter.

---

### `setShellRefShellDefId(_:shellIndex:)`

```swift
public func setShellRefShellDefId(_ shellRefIndex: Int, shellIndex: Int)
```

- **OCCT:** `BRepGraph_EditorView::Solids()` shell-ref def-id setter.

---

### `setSolidRefOrientation(_:orientation:)`

```swift
public func setSolidRefOrientation(_ solidRefIndex: Int, orientation: Int)
```

- **OCCT:** `BRepGraph_EditorView::CompSolids()` solid-ref orientation setter.

---

### `setSolidRefSolidDefId(_:solidIndex:)`

```swift
public func setSolidRefSolidDefId(_ solidRefIndex: Int, solidIndex: Int)
```

- **OCCT:** `BRepGraph_EditorView::CompSolids()` solid-ref def-id setter.

---

### `setOccurrenceChildDefId(_:childKind:childIndex:)`

```swift
public func setOccurrenceChildDefId(_ occurrenceIndex: Int, childKind: Int, childIndex: Int)
```

- **OCCT:** `BRepGraph_EditorView` occurrence def child-id setter.

---

### `setOccurrenceRefOccurrenceDefId(_:occurrenceIndex:)`

```swift
public func setOccurrenceRefOccurrenceDefId(_ occurrenceRefIndex: Int, occurrenceIndex: Int)
```

- **OCCT:** `BRepGraph_EditorView` occurrence-ref def-id setter.

---

### `setChildRefOrientation(_:orientation:)`

```swift
public func setChildRefOrientation(_ childRefIndex: Int, orientation: Int)
```

- **OCCT:** `BRepGraph_EditorView::Compounds()` child-ref orientation setter.

---

### `setChildRefChildDefId(_:childKind:childIndex:)`

```swift
public func setChildRefChildDefId(_ childRefIndex: Int, childKind: Int, childIndex: Int)
```

- **OCCT:** `BRepGraph_EditorView::Compounds()` child-ref def-id setter (updates the `BRepGraph_NodeId` for the reference).
