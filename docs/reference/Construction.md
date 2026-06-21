---
title: Construction & Sketching
parent: API Reference
---

# Construction & Sketching

The construction & sketching types implement Fusion 360-style parametric reference geometry and 2D profile creation. `ConstructionEntity` types carry _recipes_ (plane, axis, point definitions keyed on `TopologyRef`s) that are resolved against a live `TopologyGraph`; `ConstructionContext` is the document-level registry for those entities; `ConstructionLayer` bridges them to the XCAF document layer system for STEP persistence; `Sketch` hosts 2D curve elements on a plane and builds a 3D profile wire; and `Section2D` extends `Shape` to produce 2D contour drawings from planar section cuts.

## Topics

- [Placement](#placement) · [ConstructionPlane](#constructionplane) · [ConstructionAxis](#constructionaxis) · [ConstructionPoint](#constructionpoint) · [ConstructionResolutionError](#constructionresolutionerror) · [TopologyGraph resolve extensions](#topologygraph-resolve-extensions) · [TopologyGraph.childIndices](#topologygraphchildindices) · [ConstructionContext](#constructioncontext) · [Document.constructionContext](#documentconstructioncontext) · [ConstructionLayer — Document extension](#constructionlayer--document-extension) · [ConstructionContext.materialize](#constructioncontextmaterialize) · [SketchElement](#sketchelement) · [Sketch](#sketch) · [Shape.section2D](#shapesection2d) · [Shape.SectionView](#shapesectionview)

---

## Placement

A rigid-body placement in 3D space — an origin plus an orthonormal basis. Used as the resolved output of `ConstructionPlane` queries and as the coordinate frame for sketch hosting.

### `Placement.init(origin:xAxis:yAxis:zAxis:)`

Constructs a placement from an explicit orthonormal frame.

```swift
public init(origin: SIMD3<Double>, xAxis: SIMD3<Double>, yAxis: SIMD3<Double>, zAxis: SIMD3<Double>)
```

All four vectors must be provided by the caller; no normalisation is performed. `zAxis` is the plane normal when the placement describes a construction plane.

- **Parameters:**
  - `origin` — the origin point of the frame.
  - `xAxis` — unit vector along the local X axis.
  - `yAxis` — unit vector along the local Y axis.
  - `zAxis` — unit vector along the local Z axis (plane normal).
- **Example:**
  ```swift
  let placement = Placement(
      origin: SIMD3(0, 0, 10),
      xAxis:  SIMD3(1, 0, 0),
      yAxis:  SIMD3(0, 1, 0),
      zAxis:  SIMD3(0, 0, 1)
  )
  ```

---

### `Placement.init(origin:normal:)`

Constructs a placement from an origin and a normal, deriving deterministic X/Y axes perpendicular to the normal.

```swift
public init(origin: SIMD3<Double>, normal: SIMD3<Double>)
```

Picks a stable X axis using `worldUp × normal`; falls back to `worldY × normal` when the normal is near-parallel to `worldUp`. Use this convenience form when you only know the plane origin and normal and don't care about a specific X orientation.

- **Parameters:**
  - `origin` — the origin point of the plane.
  - `normal` — plane normal; will be normalised.
- **Example:**
  ```swift
  let xzPlacement = Placement(origin: .zero, normal: SIMD3(0, 1, 0))
  // xAxis ≈ (1,0,0), yAxis ≈ (0,0,1)
  ```

---

## ConstructionPlane

A recipe for a construction plane. Each case carries its defining inputs as `TopologyRef`s (or absolute geometry) that are resolved against a `TopologyGraph` at use time, so the plane tracks model edits automatically.

### `ConstructionPlane.absolute(origin:normal:)`

A fixed plane defined by a world-space point and normal.

```swift
case absolute(origin: SIMD3<Double>, normal: SIMD3<Double>)
```

Resolves immediately without consulting the topology graph — always succeeds.

- **Example:**
  ```swift
  let xy = ConstructionPlane.absolute(origin: .zero, normal: SIMD3(0, 0, 1))
  ```

---

### `ConstructionPlane.offsetFromFace(face:distance:)`

A plane parallel to a topological face, offset by `distance` along the face normal.

```swift
case offsetFromFace(face: TopologyRef, distance: Double)
```

- **Parameters:**
  - `face` — topology reference resolving to a face node.
  - `distance` — signed offset along the outward face normal (positive = outward).

---

### `ConstructionPlane.throughAxis(axis:angleDeg:)`

A plane containing an edge-derived axis, rotated `angleDeg` degrees from the reference perpendicular.

```swift
case throughAxis(axis: TopologyRef, angleDeg: Double)
```

The reference perpendicular is deduced from `worldUp × axis`. Rotation is about the axis direction.

- **Parameters:**
  - `axis` — topology reference to a linear edge.
  - `angleDeg` — rotation angle in degrees around the axis.

---

### `ConstructionPlane.tangentToFace(face:at:)`

A plane tangent to a face at a point.

```swift
case tangentToFace(face: TopologyRef, at: TopologyRef)
```

- **Parameters:**
  - `face` — topology reference resolving to the face.
  - `at` — topology reference resolving to a vertex on that face.

---

### `ConstructionPlane.midPlane(_:_:)`

A midplane equidistant between two parallel faces.

```swift
case midPlane(TopologyRef, TopologyRef)
```

The normal is the average (or either half-normal for antiparallel faces) of the two face normals.

---

### `ConstructionPlane.byThreePoints(_:_:_:)`

A plane defined by three vertex-resolved points.

```swift
case byThreePoints(TopologyRef, TopologyRef, TopologyRef)
```

Fails with `.degenerate("three points are collinear")` if the cross product is near-zero.

---

### `ConstructionPlane.normalToEdge(edge:t:)`

A plane normal to an edge at a fractional parameter along its length.

```swift
case normalToEdge(edge: TopologyRef, t: Double)
```

- **Parameters:**
  - `edge` — topology reference to the edge.
  - `t` — parameter in `[0, 1]` along the edge; clamped automatically.

---

## ConstructionAxis

A recipe for a construction axis. Resolved to `(origin: SIMD3<Double>, direction: SIMD3<Double>)` against a `TopologyGraph`.

### `ConstructionAxis.absolute(origin:direction:)`

A fixed axis at a world-space origin and direction.

```swift
case absolute(origin: SIMD3<Double>, direction: SIMD3<Double>)
```

---

### `ConstructionAxis.alongEdge(_:)`

An axis coinciding with a linear edge or the revolution axis of a cylindrical or conical edge.

```swift
case alongEdge(TopologyRef)
```

---

### `ConstructionAxis.normalToFace(face:at:)`

An axis perpendicular to a face, anchored at a vertex.

```swift
case normalToFace(face: TopologyRef, at: TopologyRef)
```

For planar faces the direction is the face normal; for cylindrical faces it is the rotation axis.

---

### `ConstructionAxis.throughPoints(_:_:)`

An axis through two vertex-resolved points.

```swift
case throughPoints(TopologyRef, TopologyRef)
```

Fails with `.degenerate("points coincide")` when the two points are within 1e-9 of each other.

---

### `ConstructionAxis.intersectionOfPlanes(_:_:)`

An axis at the intersection line of two planes.

```swift
case intersectionOfPlanes(ConstructionPlane, ConstructionPlane)
```

Fails with `.degenerate("planes are parallel")` when the cross product is near-zero.

---

## ConstructionPoint

A recipe for a construction point. Resolved to `SIMD3<Double>` against a `TopologyGraph`.

### `ConstructionPoint.absolute(_:)`

A fixed world-space point.

```swift
case absolute(SIMD3<Double>)
```

---

### `ConstructionPoint.atVertex(_:)`

The 3D coordinate of a topology vertex.

```swift
case atVertex(TopologyRef)
```

- **OCCT:** `OCCTShapeVertexPoint` — reads the `gp_Pnt` from a `TopoDS_Vertex`.

---

### `ConstructionPoint.midpointOfEdge(_:)`

The point at the parametric midpoint (t = 0.5) of an edge.

```swift
case midpointOfEdge(TopologyRef)
```

---

### `ConstructionPoint.centroidOfFace(_:)`

The UV-centroid of a face's parametric bounds, evaluated on the surface.

```swift
case centroidOfFace(TopologyRef)
```

---

### `ConstructionPoint.atEdgeParameter(edge:t:)`

The 3D point at a fractional parameter along an edge.

```swift
case atEdgeParameter(edge: TopologyRef, t: Double)
```

- **Parameters:** `t` — in `[0, 1]`; clamped before use.

---

### `ConstructionPoint.intersectionOfAxisAndPlane(_:_:)`

The 3D point where an axis intersects a plane.

```swift
case intersectionOfAxisAndPlane(ConstructionAxis, ConstructionPlane)
```

Fails with `.degenerate("axis parallel to plane")` when the axis direction is perpendicular to the plane normal.

---

## ConstructionResolutionError

Error type returned when a construction entity fails to resolve against the topology graph.

```swift
public enum ConstructionResolutionError: Error, Sendable {
    case topology(TopologyResolutionError)
    case notApplicable(String)
    case degenerate(String)
    case missingGeometry(TopologyGraph.NodeRef)
}
```

- `.topology` — the underlying `TopologyRef` could not be resolved (e.g. the node was deleted).
- `.notApplicable` — the referenced node is the wrong kind (e.g. an edge where a face was expected).
- `.degenerate` — the geometry is valid but produces a degenerate result (e.g. collinear points, parallel planes).
- `.missingGeometry` — the node exists in the graph but carries no shape geometry.

---

## TopologyGraph resolve extensions

`TopologyGraph` is extended in `ConstructionEntity.swift` to resolve the three construction entity types. These are the primary resolution entry points.

### `TopologyGraph.resolve(_:) for ConstructionPlane`

Resolves a `ConstructionPlane` recipe against the current graph state.

```swift
public func resolve(_ plane: ConstructionPlane) -> Result<Placement, ConstructionResolutionError>
```

- **Returns:** A `Placement` encoding the plane's origin and orthonormal frame, or a `ConstructionResolutionError`.
- **Example:**
  ```swift
  let plane = ConstructionPlane.absolute(origin: .zero, normal: SIMD3(0, 0, 1))
  switch graph.resolve(plane) {
  case .success(let p): print(p.origin, p.zAxis)
  case .failure(let e): print(e)
  }
  ```

---

### `TopologyGraph.resolve(_:) for ConstructionAxis`

Resolves a `ConstructionAxis` recipe against the current graph state.

```swift
public func resolve(_ axis: ConstructionAxis) -> Result<(origin: SIMD3<Double>, direction: SIMD3<Double>), ConstructionResolutionError>
```

- **Returns:** A tuple of the axis origin and unit direction vector, or a `ConstructionResolutionError`.
- **Example:**
  ```swift
  let axis = ConstructionAxis.absolute(origin: .zero, direction: SIMD3(0, 0, 1))
  if case .success(let ax) = graph.resolve(axis) {
      print(ax.origin, ax.direction)
  }
  ```

---

### `TopologyGraph.resolve(_:) for ConstructionPoint`

Resolves a `ConstructionPoint` recipe against the current graph state.

```swift
public func resolve(_ point: ConstructionPoint) -> Result<SIMD3<Double>, ConstructionResolutionError>
```

- **Returns:** The resolved 3D coordinate, or a `ConstructionResolutionError`.
- **Example:**
  ```swift
  let pt = ConstructionPoint.absolute(SIMD3(1, 2, 3))
  if case .success(let p) = graph.resolve(pt) {
      print(p)
  }
  ```

---

## TopologyGraph.childIndices

### `TopologyGraph.childIndices(rootKind:rootIndex:targetKind:)`

Returns the indices of all descendant nodes of `targetKind` under a root node.

```swift
public func childIndices(rootKind: NodeKind, rootIndex: Int, targetKind: NodeKind) -> [Int]
```

Complements `childCount(rootKind:rootIndex:targetKind:)` by giving the actual index values rather than just the count. Used internally by construction-entity resolvers when enumerating sub-topology.

- **Parameters:**
  - `rootKind` — the `NodeKind` of the root node.
  - `rootIndex` — the ordinal index of the root node in the graph.
  - `targetKind` — the `NodeKind` to collect descendants of.
- **Returns:** An array of graph indices; empty if there are none.
- **OCCT:** `OCCTBRepGraphChildIndices` — queries the pre-built BRep-graph adjacency tables.
- **Example:**
  ```swift
  let faceIndices = graph.childIndices(rootKind: .solid, rootIndex: 0, targetKind: .face)
  ```

---

## ConstructionContext

A document-level, thread-safe registry of named construction entities. Entities are stored by value under opaque typed IDs; they are resolved on demand against a `TopologyGraph`. Insertion order is preserved. Thread-safe via an internal `NSLock`.

> **Persistence note:** Construction entity _recipes_ live in Swift value storage only — they are not serialised into the XCAF/XDE shape tree. STEP round-trip preserves layer tags (see `ConstructionLayer`) but loses recipe structure. Serialise the `ConstructionContext` separately (e.g. as JSON via `Codable`) if recipe round-trip is required.

### `ConstructionContext.PlaneID`

Opaque, `Hashable`, `Sendable` identifier for a registered construction plane.

```swift
public struct PlaneID: Sendable, Hashable {
    public let raw: UUID
    public init()
}
```

Each call to `init()` produces a unique ID backed by a new `UUID`.

---

### `ConstructionContext.AxisID`

Opaque, `Hashable`, `Sendable` identifier for a registered construction axis.

```swift
public struct AxisID: Sendable, Hashable {
    public let raw: UUID
    public init()
}
```

---

### `ConstructionContext.PointID`

Opaque, `Hashable`, `Sendable` identifier for a registered construction point.

```swift
public struct PointID: Sendable, Hashable {
    public let raw: UUID
    public init()
}
```

---

### `ConstructionContext.init()`

Creates an empty construction context.

```swift
public init()
```

- **Example:**
  ```swift
  let ctx = ConstructionContext()
  ```

---

### `ConstructionContext.add(_:name:) for ConstructionPlane`

Inserts a construction plane, returning its unique ID.

```swift
@discardableResult
public func add(_ plane: ConstructionPlane, name: String? = nil) -> PlaneID
```

- **Parameters:**
  - `plane` — the plane recipe to register.
  - `name` — optional human-readable label (e.g. `"Top"`, `"XZ"`) for display purposes.
- **Returns:** A new `PlaneID`; discard if you don't need to look up the entity later.
- **Example:**
  ```swift
  let ctx = ConstructionContext()
  let xyId = ctx.add(.absolute(origin: .zero, normal: SIMD3(0, 0, 1)), name: "XY")
  ```

---

### `ConstructionContext.add(_:name:) for ConstructionAxis`

Inserts a construction axis, returning its unique ID.

```swift
@discardableResult
public func add(_ axis: ConstructionAxis, name: String? = nil) -> AxisID
```

- **Parameters:**
  - `axis` — the axis recipe.
  - `name` — optional label.
- **Returns:** A new `AxisID`.

---

### `ConstructionContext.add(_:name:) for ConstructionPoint`

Inserts a construction point, returning its unique ID.

```swift
@discardableResult
public func add(_ point: ConstructionPoint, name: String? = nil) -> PointID
```

- **Parameters:**
  - `point` — the point recipe.
  - `name` — optional label.
- **Returns:** A new `PointID`.

---

### `ConstructionContext.plane(_:)`

Looks up a registered construction plane by ID.

```swift
public func plane(_ id: PlaneID) -> ConstructionPlane?
```

- **Returns:** The `ConstructionPlane` recipe, or `nil` if the ID is not registered.

---

### `ConstructionContext.axis(_:)`

Looks up a registered construction axis by ID.

```swift
public func axis(_ id: AxisID) -> ConstructionAxis?
```

- **Returns:** The `ConstructionAxis` recipe, or `nil` if the ID is not registered.

---

### `ConstructionContext.point(_:)`

Looks up a registered construction point by ID.

```swift
public func point(_ id: PointID) -> ConstructionPoint?
```

- **Returns:** The `ConstructionPoint` recipe, or `nil` if the ID is not registered.

---

### `ConstructionContext.name(_:) for PlaneID`

Returns the human-readable label for a registered plane, if any.

```swift
public func name(_ id: PlaneID) -> String?
```

---

### `ConstructionContext.name(_:) for AxisID`

Returns the human-readable label for a registered axis, if any.

```swift
public func name(_ id: AxisID) -> String?
```

---

### `ConstructionContext.name(_:) for PointID`

Returns the human-readable label for a registered point, if any.

```swift
public func name(_ id: PointID) -> String?
```

---

### `ConstructionContext.allPlanes`

All registered planes in insertion order.

```swift
public var allPlanes: [(id: PlaneID, name: String?, plane: ConstructionPlane)] { get }
```

- **Returns:** Ordered array of `(id, name, plane)` tuples; empty if no planes are registered.

---

### `ConstructionContext.allAxes`

All registered axes in insertion order.

```swift
public var allAxes: [(id: AxisID, name: String?, axis: ConstructionAxis)] { get }
```

---

### `ConstructionContext.allPoints`

All registered points in insertion order.

```swift
public var allPoints: [(id: PointID, name: String?, point: ConstructionPoint)] { get }
```

---

### `ConstructionContext.remove(plane:)`

Removes the plane registered under `id`.

```swift
public func remove(plane id: PlaneID)
```

No-ops silently if `id` is not registered.

---

### `ConstructionContext.remove(axis:)`

Removes the axis registered under `id`.

```swift
public func remove(axis id: AxisID)
```

---

### `ConstructionContext.remove(point:)`

Removes the point registered under `id`.

```swift
public func remove(point id: PointID)
```

---

### `ConstructionContext.removeAll()`

Removes all registered planes, axes, and points.

```swift
public func removeAll()
```

---

### `ConstructionContext.resolve(_:in:) for PlaneID`

Resolves a registered plane against a topology graph, returning a `Placement`.

```swift
public func resolve(_ id: PlaneID, in graph: TopologyGraph) -> Result<Placement, ConstructionResolutionError>
```

Delegates to `TopologyGraph.resolve(_:)`. Returns `.failure(.notApplicable(...))` if `id` is not registered.

- **Parameters:**
  - `id` — the `PlaneID` to resolve.
  - `graph` — the topology graph to evaluate the recipe against.
- **Returns:** `Result<Placement, ConstructionResolutionError>`.
- **Example:**
  ```swift
  let ctx = ConstructionContext()
  let id = ctx.add(.absolute(origin: .zero, normal: SIMD3(0, 0, 1)))
  if case .success(let p) = ctx.resolve(id, in: graph) {
      print(p.origin)
  }
  ```

---

### `ConstructionContext.resolve(_:in:) for AxisID`

Resolves a registered axis against a topology graph.

```swift
public func resolve(_ id: AxisID, in graph: TopologyGraph) -> Result<(origin: SIMD3<Double>, direction: SIMD3<Double>), ConstructionResolutionError>
```

---

### `ConstructionContext.resolve(_:in:) for PointID`

Resolves a registered point against a topology graph.

```swift
public func resolve(_ id: PointID, in graph: TopologyGraph) -> Result<SIMD3<Double>, ConstructionResolutionError>
```

---

### `ConstructionContext.BrokenEntities`

Container for entities that fail resolution in `allBroken(in:)`.

```swift
public struct BrokenEntities: Sendable {
    public let planes: [(id: PlaneID, error: ConstructionResolutionError)]
    public let axes: [(id: AxisID, error: ConstructionResolutionError)]
    public let points: [(id: PointID, error: ConstructionResolutionError)]
    public var isEmpty: Bool { get }
    public var totalCount: Int { get }
}
```

- `isEmpty` — `true` when all three lists are empty (no broken entities).
- `totalCount` — total count of broken entities across all three types.

---

### `ConstructionContext.allBroken(in:)`

Inspects every registered entity against `graph` and returns those that fail resolution.

```swift
public func allBroken(in graph: TopologyGraph) -> BrokenEntities
```

Useful in agent workflows after model edits to detect stale construction references before attempting a sketch build or section.

- **Parameters:** `graph` — the topology graph to evaluate against.
- **Returns:** A `BrokenEntities` value listing planes, axes, and points that returned `.failure`.
- **Example:**
  ```swift
  let broken = ctx.allBroken(in: graph)
  if !broken.isEmpty {
      print("\(broken.totalCount) broken references")
  }
  ```

---

### `ConstructionContext.count`

Counts of registered planes, axes, and points.

```swift
public var count: (planes: Int, axes: Int, points: Int) { get }
```

- **Example:**
  ```swift
  let (p, a, pt) = ctx.count
  print("planes: \(p), axes: \(a), points: \(pt)")
  ```

---

## Document.constructionContext

### `Document.constructionContext`

Per-document construction context, created lazily on first access.

```swift
public var constructionContext: ConstructionContext { get }
```

Construction entities live alongside the document's shapes but are not part of the XDE shape tree. Each `Document` instance gets exactly one `ConstructionContext`; repeated access returns the same object.

- **Example:**
  ```swift
  let doc = Document()
  let ctx = doc.constructionContext
  let xyId = ctx.add(.absolute(origin: .zero, normal: SIMD3(0, 0, 1)), name: "XY")
  ```

---

## ConstructionLayer — Document extension

Declared in `ConstructionLayer.swift`. Provides XCAF layer tagging for construction shapes so that layer membership survives STEP/IGES round-trip.

### `Document.constructionLayerName`

The XCAF layer name used to tag construction geometry.

```swift
public static let constructionLayerName = "CONSTRUCTION"
```

Matches the layer string used by FreeCAD and the AP214 convention for construction geometry.

---

### `Document.addConstructionShape(_:)`

Adds a shape to the document and immediately tags it with the `CONSTRUCTION` XCAF layer.

```swift
@discardableResult
public func addConstructionShape(_ shape: Shape) -> Int64
```

- **Parameters:** `shape` — the shape to add (typically a face, edge, or vertex materialised from a recipe).
- **Returns:** The new label ID (≥ 0 on success, negative on failure).
- **OCCT:** `XCAFDoc_LayerTool::SetLayer` via `AssemblyNode.setLayer(_:)`.
- **Example:**
  ```swift
  let vertex = Shape.vertex(at: SIMD3(0, 0, 0))!
  let labelId = doc.addConstructionShape(vertex)
  ```

---

### `Document.constructionShapeLabels`

The label IDs of all shapes currently tagged with the `CONSTRUCTION` layer in this document.

```swift
public var constructionShapeLabels: [Int64] { get }
```

Use this after a STEP/IGES load to identify shapes that were tagged as construction geometry on export.

- **Returns:** Array of label IDs; empty if no construction-tagged shapes exist.
- **OCCT:** Filters `rootNodes` via `AssemblyNode.isLayerSet("CONSTRUCTION")`.
- **Example:**
  ```swift
  let ids = doc.constructionShapeLabels
  print("\(ids.count) construction shapes in document")
  ```

---

## ConstructionContext.materialize

### `ConstructionContext.MaterializeOptions`

Size parameters for the finite representative shapes produced by `materialize(in:graph:options:)`.

```swift
public struct MaterializeOptions: Sendable {
    public var planeHalfSize: Double = 100
    public var axisHalfLength: Double = 100
    public init(planeHalfSize: Double = 100, axisHalfLength: Double = 100)
}
```

- `planeHalfSize` — half-side of the square face representing each plane (default 100 mm).
- `axisHalfLength` — half-length of the edge representing each axis (default 100 mm).

---

### `ConstructionContext.MaterializationResult`

Summary returned by `materialize(in:graph:options:)`.

```swift
public struct MaterializationResult: Sendable {
    public let planeShapes: [(id: PlaneID, labelId: Int64)]
    public let axisShapes: [(id: AxisID, labelId: Int64)]
    public let pointShapes: [(id: PointID, labelId: Int64)]
    public let failures: [MaterializationFailure]
    public var totalMaterialized: Int { get }
}
```

- `totalMaterialized` — combined count of successfully materialised planes, axes, and points.

---

### `ConstructionContext.MaterializationFailure`

Discriminated union of failure cases from `materialize(in:graph:options:)`.

```swift
public enum MaterializationFailure: Sendable {
    case planeResolveFailed(PlaneID, ConstructionResolutionError)
    case axisResolveFailed(AxisID, ConstructionResolutionError)
    case pointResolveFailed(PointID, ConstructionResolutionError)
    case planeShapeFailed(PlaneID)
    case axisShapeFailed(AxisID)
    case pointShapeFailed(PointID)
}
```

`*ResolveFailed` cases indicate that the recipe could not be evaluated against the graph; `*ShapeFailed` cases indicate that the recipe resolved but the representative shape could not be constructed (e.g. degenerate wire).

---

### `ConstructionContext.materialize(in:graph:options:)`

Materialises all registered construction entities as `TopoDS_Shape`s on the document's `CONSTRUCTION` layer.

```swift
@discardableResult
public func materialize(in document: Document,
                        graph: TopologyGraph,
                        options: MaterializeOptions = MaterializeOptions()) -> MaterializationResult
```

Each resolved entity becomes a finite representative shape:
- Planes → a square face (side `2 × planeHalfSize`) centred on the plane origin.
- Axes → an edge of length `2 × axisHalfLength` centred on the axis origin.
- Points → a vertex.

Shapes are added to `document` via `addConstructionShape(_:)`, which tags them with the `CONSTRUCTION` XCAF layer.

- **Parameters:**
  - `document` — the document to add shapes to.
  - `graph` — the topology graph for resolving entity recipes.
  - `options` — size parameters for the representative shapes.
- **Returns:** A `MaterializationResult` describing what succeeded and what failed.
- **Example:**
  ```swift
  let result = ctx.materialize(in: doc, graph: graph)
  print("\(result.totalMaterialized) shapes materialised")
  for failure in result.failures {
      print("Failed: \(failure)")
  }
  ```

---

## SketchElement

A single 2D curve element within a `Sketch`. Elements carry their curve geometry, a construction flag, and a stable `UUID`.

### `SketchElement.CurveKind`

Discriminated union of supported 2D curve types within a sketch element.

```swift
public enum CurveKind: Sendable, Hashable {
    case line(from: SIMD2<Double>, to: SIMD2<Double>)
    case arc(center: SIMD2<Double>, radius: Double, startAngle: Double, endAngle: Double)
    case circle(center: SIMD2<Double>, radius: Double)
    case polyline([SIMD2<Double>])
}
```

Angles for `.arc` are in radians.

---

### `SketchElement.CurveKind.tessellate2D(segmentsPerRadian:)`

Returns ordered 2D sample points along this curve.

```swift
public func tessellate2D(segmentsPerRadian: Int = 16) -> [SIMD2<Double>]
```

Lines and polylines return their defining points exactly. Arcs and circles are tessellated at the given density.

- **Parameters:** `segmentsPerRadian` — number of line segments per radian of arc; default 16.
- **Returns:** Array of 2D points in order along the curve. Circles include a repeated closing point.
- **Example:**
  ```swift
  let arc = SketchElement.CurveKind.arc(center: .zero, radius: 5, startAngle: 0, endAngle: .pi)
  let pts = arc.tessellate2D(segmentsPerRadian: 32)
  ```

---

### `SketchElement.curve`

The geometry of this element.

```swift
public var curve: CurveKind
```

---

### `SketchElement.isConstruction`

Whether this element is construction geometry — excluded from `Sketch.buildProfile`.

```swift
public var isConstruction: Bool
```

Construction elements are visible in the sketch editor but do not appear in the extruded/revolved profile.

---

### `SketchElement.id`

Stable identity for the element, used for selection and constraint references.

```swift
public var id: UUID
```

---

### `SketchElement.init(curve:isConstruction:id:)`

Creates a sketch element.

```swift
public init(curve: CurveKind, isConstruction: Bool = false, id: UUID = UUID())
```

- **Parameters:**
  - `curve` — the 2D curve geometry.
  - `isConstruction` — `true` to mark as construction (default `false`).
  - `id` — stable UUID (default-generated if not provided).
- **Example:**
  ```swift
  let line = SketchElement(curve: .line(from: .zero, to: SIMD2(10, 0)))
  let guide = SketchElement(curve: .line(from: SIMD2(-5, 0), to: SIMD2(15, 0)),
                            isConstruction: true)
  ```

---

## Sketch

A collection of 2D curve elements hosted on a `ConstructionPlane`, with a `buildProfile` step that filters construction elements and lifts the result to a 3D `Wire`. Constraint solving is out of scope — elements carry coordinates directly.

### `Sketch.hostPlane`

The ID of the construction plane on which this sketch lives.

```swift
public var hostPlane: ConstructionContext.PlaneID
```

---

### `Sketch.elements`

All elements in the sketch, including construction geometry.

```swift
public var elements: [SketchElement]
```

---

### `Sketch.name`

Optional display name for the sketch.

```swift
public var name: String?
```

---

### `Sketch.init(hostPlane:elements:name:)`

Creates a sketch on the given construction plane.

```swift
public init(hostPlane: ConstructionContext.PlaneID,
            elements: [SketchElement] = [],
            name: String? = nil)
```

- **Parameters:**
  - `hostPlane` — the `PlaneID` registered in a `ConstructionContext`.
  - `elements` — initial element set (default empty).
  - `name` — optional display name.
- **Example:**
  ```swift
  let ctx = ConstructionContext()
  let planeId = ctx.add(.absolute(origin: .zero, normal: SIMD3(0, 0, 1)))
  var sketch = Sketch(hostPlane: planeId, name: "Profile")
  ```

---

### `Sketch.add(_:)`

Appends an element to the sketch.

```swift
public mutating func add(_ element: SketchElement)
```

- **Parameters:** `element` — the element to append.
- **Example:**
  ```swift
  sketch.add(SketchElement(curve: .circle(center: .zero, radius: 5)))
  ```

---

### `Sketch.profileElementCount`

Number of non-construction elements — the profile size.

```swift
public var profileElementCount: Int { get }
```

- **Returns:** Count of elements where `isConstruction == false`.
- **Example:**
  ```swift
  #expect(sketch.profileElementCount == 1)
  ```

---

### `Sketch.buildProfile(in:graph:)`

Builds a 3D closed profile wire from the sketch's non-construction elements, placed on the host construction plane.

```swift
public func buildProfile(in context: ConstructionContext,
                         graph: TopologyGraph) -> Wire?
```

Construction elements are filtered at this single site — upstream views (solver, editor) see the full element set. Each 2D point is lifted into 3D via `placement.origin + pt.x * placement.xAxis + pt.y * placement.yAxis`. The resulting polyline is closed automatically if the first and last 3D points are within 1e-9 of each other.

- **Parameters:**
  - `context` — the `ConstructionContext` that registered `hostPlane`.
  - `graph` — a `TopologyGraph` to resolve the host plane's recipe.
- **Returns:** A closed `Wire` on the resolved plane, or `nil` if the host plane fails to resolve, no profile elements exist, or fewer than 2 distinct 3D points result.
- **OCCT:** Delegates to `Wire.polygon3D(_:closed:)` — `BRepBuilderAPI_MakePolygon`.
- **Example:**
  ```swift
  let ctx = ConstructionContext()
  let planeId = ctx.add(.absolute(origin: .zero, normal: SIMD3(0, 0, 1)))
  var sketch = Sketch(hostPlane: planeId)
  sketch.add(SketchElement(curve: .circle(center: .zero, radius: 10)))
  if let wire = sketch.buildProfile(in: ctx, graph: graph) {
      let solid = Shape.extrude(wire: wire, direction: SIMD3(0, 0, 5))
  }
  ```

---

## Shape.section2D

### `Shape.section2D(planeOrigin:planeNormal:planeU:deflection:)`

Slices this shape with a plane and returns the resulting contour as a 2D `Drawing` in the plane's own coordinate frame.

```swift
public func section2D(planeOrigin: SIMD3<Double>,
                      planeNormal: SIMD3<Double>,
                      planeU: SIMD3<Double>? = nil,
                      deflection: Double = 0.1) -> Drawing?
```

Computes the 3D section edges via `sectionWithPlane`, then projects each sample point into the plane's `(u, v)` frame. The result is a `Drawing` whose `visibleEdges` contain the section contour polylines, ready for annotation, hatching, and export.

- **Parameters:**
  - `planeOrigin` — any point on the cutting plane, in world coordinates.
  - `planeNormal` — plane normal; will be normalised internally.
  - `planeU` — explicit X axis for the resulting 2D frame; must be perpendicular to `planeNormal`. When `nil` (default), a deterministic perpendicular is derived from world-up or world-Y.
  - `deflection` — tessellation tolerance for edge sampling (default 0.1 mm; use 0.01 for finer detail).
- **Returns:** A `Drawing` with the 2D contour in `visibleEdges`, or `nil` if the plane does not intersect the shape or projection fails.
- **OCCT:** `OCCTShapeSectionWithPlane` → `BRepAlgoAPI_Section`; then `Drawing.project` for the 2D assembly.
- **Example:**
  ```swift
  let box = Shape.box(width: 50, height: 50, depth: 50)!
  if let drawing = box.section2D(planeOrigin: SIMD3(0, 0, 25),
                                  planeNormal: SIMD3(0, 0, 1)) {
      // drawing.visibleEdges contains the 50×50 square contour at Z=25
      let dxf = Exporter.exportDXF(drawing: drawing)
  }
  ```

---

## Shape.SectionView

### `Shape.SectionView`

A section view spec bundling contour, hatching, and label for placement on a drawing sheet.

```swift
public struct SectionView: Sendable {
    public let drawing: Drawing
    public let label: String?
    public let cuttingPlaneOrigin: SIMD3<Double>
    public let cuttingPlaneNormal: SIMD3<Double>
}
```

- `drawing` — the `Drawing` containing the contour and any added hatching and label.
- `label` — optional string label (e.g. `"A-A"`), added as a text annotation above the drawing bounds.
- `cuttingPlaneOrigin` / `cuttingPlaneNormal` — the cutting plane that produced this view.

---

### `Shape.section2DView(planeOrigin:planeNormal:label:hatchAngle:hatchSpacing:deflection:)`

ISO 128-40-styled section view: slice + hatching + label bundled into a single `Drawing`.

```swift
public func section2DView(planeOrigin: SIMD3<Double>,
                          planeNormal: SIMD3<Double>,
                          label: String? = nil,
                          hatchAngle: Double = .pi / 4,
                          hatchSpacing: Double = 3.0,
                          deflection: Double = 0.1) -> SectionView?
```

Calls `section2D` then adds cross-hatch lines (at angle/spacing) over the bounding box of the section contour, and optionally places a text label 5 mm above the top-left corner.

- **Parameters:**
  - `planeOrigin` — any point on the cutting plane, in world coordinates.
  - `planeNormal` — plane normal; will be normalised.
  - `label` — optional annotation string (default `nil`); placed above the contour bounds.
  - `hatchAngle` — hatch line angle in radians (default π/4 = 45°).
  - `hatchSpacing` — spacing between hatch lines in model units (default 3 mm).
  - `deflection` — tessellation tolerance for edge sampling (default 0.1 mm).
- **Returns:** A `SectionView`, or `nil` if `section2D` fails (no intersection or projection error).
- **Note:** Hatching uses the bounding box of the contour as the fill boundary; full contour-interior polygon hatching is planned for a future release.
- **Example:**
  ```swift
  let shaft = Shape.cylinder(radius: 10, height: 100)!
  if let view = shaft.section2DView(planeOrigin: SIMD3(0, 0, 50),
                                     planeNormal: SIMD3(0, 0, 1),
                                     label: "A-A",
                                     hatchSpacing: 2.0) {
      print(view.label ?? "")   // "A-A"
      // view.drawing is ready to place on a sheet
  }
  ```
