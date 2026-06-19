---
title: Edge
parent: API Reference
---

# Edge

An `Edge` is a bounded curve in 3D space — the Swift analog of OCCT's `TopoDS_Edge`. Edges are the one-dimensional elements of B-Rep topology: each edge carries a `Geom_Curve` trimmed to a parameter range, and connects two vertices. Obtain edges by calling `shape.edges()`, `shape.edge(at:)`, or by constructing a `Wire` and extracting via `wire.edges()`.

## Topics

- [Initializers](#initializers) · [Properties](#properties) · [3D Curve Properties](#3d-curve-properties) · [Sampling](#sampling) · [Shape Extension for Edge Access](#shape-extension-for-edge-access) · [Edge Analysis](#edge-analysis) · [Curve Approximation](#curve-approximation) · [Edge Splitting](#edge-splitting) · [PCurve / BRepAdaptor\_Curve2d](#pcurve--brepadaptor_curve2d)

---

## Initializers

### `Edge.init?(_ shape:)`

Constructs an `Edge` by extracting the edge topology from a `Shape`. Returns `nil` if `shape` is null or wraps a non-edge topology type.

```swift
public convenience init?(_ shape: Shape)
```

Use when you have an edge-typed `Shape` (e.g. from sub-shape iteration) and need the typed `Edge` object.

- **Parameters:** `shape` — a `Shape` wrapping a `TopoDS_Edge`.
- **Returns:** `nil` if `shape` is null or its topology type is not `TopAbs_EDGE`.
- **OCCT:** `TopoDS::Edge` — casts the underlying `TopoDS_Shape` after checking `ShapeType() == TopAbs_EDGE`.
- **Example:**
  ```swift
  let shapes = box.subShapes(ofType: .edge)
  if let edge = Edge(shapes[0]) {
      print(edge.length)
  }
  ```

---

## Properties

### `index`

The index of this edge within the parent shape, or `-1` if the edge was created standalone.

```swift
public let index: Int
```

Reflects the 0-based position at which `shape.edge(at:)` returned this edge. Set to `-1` for edges obtained via `Edge(_ shape:)`.

- **Example:**
  ```swift
  let edge = box.edge(at: 3)!
  print(edge.index)  // 3
  ```

---

### `length`

The arc length of the edge.

```swift
public var length: Double { get }
```

- **Returns:** Length in model units. Returns `0` for degenerate or null edges.
- **OCCT:** `BRepGProp::LinearProperties` — computes linear mass (= arc length) of the edge.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  let edge = box.edge(at: 0)!
  print(edge.length)  // 10.0
  ```

---

### `bounds`

The axis-aligned bounding box of the edge.

```swift
public var bounds: (min: SIMD3<Double>, max: SIMD3<Double>) { get }
```

- **Returns:** Tuple of the AABB min and max corners. Returns `(.zero, .zero)` on failure.
- **OCCT:** `BRepBndLib::Add` + `Bnd_Box::Get`.
- **Example:**
  ```swift
  let b = box.edge(at: 0)!.bounds
  // b.min and b.max define the bounding box of that edge
  ```

---

### `isLine`

Whether this edge's underlying curve is a straight line.

```swift
public var isLine: Bool { get }
```

- **OCCT:** `BRepAdaptor_Curve::GetType()` compared to `GeomAbs_Line`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  let hasLines = box.edges().contains(where: \.isLine)
  ```

---

### `isCircle`

Whether this edge's underlying curve is a full or partial circle.

```swift
public var isCircle: Bool { get }
```

- **OCCT:** `BRepAdaptor_Curve::GetType()` compared to `GeomAbs_Circle`.
- **Example:**
  ```swift
  let cyl = Shape.cylinder(radius: 5, height: 10)!
  let circEdge = cyl.edges().first(where: \.isCircle)
  ```

---

### `endpoints`

The start and end 3D points of the edge (its bounding vertices).

```swift
public var endpoints: (start: SIMD3<Double>, end: SIMD3<Double>) { get }
```

Extracts the vertex positions using `TopExp::Vertices`. Returns `(.zero, .zero)` on failure (e.g. degenerate edge with no vertices).

- **Returns:** Tuple of the edge's start and end vertex positions.
- **OCCT:** `TopExp::Vertices` + `BRep_Tool::Pnt`.
- **Example:**
  ```swift
  let ep = box.edge(at: 0)!.endpoints
  print(ep.start, ep.end)
  ```

---

## 3D Curve Properties

Properties and methods in this section provide parametric access to the edge's underlying `Geom_Curve`. Parameters are **native OCCT curve parameters** (not normalised to `[0, 1]`); query `parameterBounds` first.

---

### `CurveType`

Curve type classification for an edge's underlying geometry.

```swift
public enum CurveType: Int32, Sendable {
    case line = 0, circle = 1, ellipse = 2, hyperbola = 3, parabola = 4
    case bezierCurve = 5, bsplineCurve = 6, offsetCurve = 7, other = 8
}
```

Matches `GeomAbs_CurveType` values from `BRepAdaptor_Curve`. Use `curveType` to distinguish geometric type before calling type-specific accessors.

---

### `CurveProjection`

Result of projecting a point onto an edge's curve.

```swift
public struct CurveProjection: Sendable {
    public let point: SIMD3<Double>
    public let parameter: Double
    public let distance: Double
}
```

- `point` — closest point on the curve.
- `parameter` — native curve parameter at the closest point.
- `distance` — Euclidean distance from the query point to `point`.

---

### `parameterBounds`

The native OCCT parameter range `[first, last]` for this edge's underlying curve.

```swift
public var parameterBounds: (first: Double, last: Double)? { get }
```

Required before calling any `at parameter:` method — OCCT parameters are not normalised. For a line of length 10 starting at the origin, `first ≈ 0` and `last ≈ 10`.

- **Returns:** `(first, last)` parameter tuple, or `nil` if the edge has no 3D curve.
- **OCCT:** `BRep_Tool::Curve` — returns the handle and its parameter range.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  let edge = box.edge(at: 0)!
  if let b = edge.parameterBounds {
      let mid = (b.first + b.last) / 2.0
      let pt = edge.point(at: mid)
  }
  ```

---

### `curveType`

The geometric type of this edge's curve.

```swift
public var curveType: CurveType { get }
```

- **Returns:** One of `CurveType`'s cases. Returns `.other` for unknown or null curves.
- **OCCT:** `BRepAdaptor_Curve::GetType()`.
- **Example:**
  ```swift
  for edge in shape.edges() {
      if edge.curveType == .circle {
          // handle circular edges
      }
  }
  ```

---

### `point(at:)`

Returns the 3D position on the edge's curve at a native OCCT parameter.

```swift
public func point(at parameter: Double) -> SIMD3<Double>?
```

- **Parameters:** `parameter` — a value in `[parameterBounds.first, parameterBounds.last]`.
- **Returns:** 3D point, or `nil` if the edge has no curve or the parameter is out of domain.
- **OCCT:** `BRep_Tool::Curve` → `Geom_Curve::D0`.
- **Example:**
  ```swift
  let edge = cyl.edges().first(where: \.isCircle)!
  if let b = edge.parameterBounds {
      let mid = (b.first + b.last) / 2.0
      let pt = edge.point(at: mid)
  }
  ```

---

### `curvature(at:)`

Returns the curvature (1/radius) of the edge's curve at a native parameter.

```swift
public func curvature(at parameter: Double) -> Double?
```

A straight line has curvature `0`; a circle of radius R has curvature `1/R`.

- **Parameters:** `parameter` — native curve parameter.
- **Returns:** Curvature ≥ 0, or `nil` if the tangent is undefined or the edge has no curve.
- **OCCT:** `BRep_Tool::Curve` → `GeomLProp_CLProps::Curvature`.
- **Example:**
  ```swift
  let radius = 5.0
  let cyl = Shape.cylinder(radius: radius, height: 10)!
  if let edge = cyl.edges().first(where: \.isCircle),
     let b = edge.parameterBounds {
      let curv = edge.curvature(at: (b.first + b.last) / 2.0)
      // curv ≈ 0.2 (1/5)
  }
  ```

---

### `tangent(at:)`

Returns the unit tangent vector at a native curve parameter.

```swift
public func tangent(at parameter: Double) -> SIMD3<Double>?
```

- **Parameters:** `parameter` — native curve parameter.
- **Returns:** Unit tangent vector in the direction of increasing parameter, or `nil` if undefined.
- **OCCT:** `BRep_Tool::Curve` → `GeomLProp_CLProps::Tangent`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  if let edge = box.edges().first(where: \.isLine),
     let b = edge.parameterBounds {
      let t = edge.tangent(at: (b.first + b.last) / 2.0)
  }
  ```

---

### `normal(at:)`

Returns the principal normal direction at a native curve parameter.

```swift
public func normal(at parameter: Double) -> SIMD3<Double>?
```

The principal normal points toward the centre of curvature. For straight edges, curvature is zero and the normal is undefined.

- **Parameters:** `parameter` — native curve parameter.
- **Returns:** Unit normal vector, or `nil` if the curvature is zero or the tangent is undefined.
- **OCCT:** `BRep_Tool::Curve` → `GeomLProp_CLProps::Normal`.
- **Example:**
  ```swift
  if let edge = cyl.edges().first(where: \.isCircle),
     let b = edge.parameterBounds {
      let n = edge.normal(at: (b.first + b.last) / 2.0)
  }
  ```

---

### `centerOfCurvature(at:)`

Returns the centre of curvature at a native curve parameter.

```swift
public func centerOfCurvature(at parameter: Double) -> SIMD3<Double>?
```

The centre of curvature lies on the principal normal at distance 1/κ from the curve point. Undefined (returns `nil`) for zero-curvature (straight) segments.

- **Parameters:** `parameter` — native curve parameter.
- **Returns:** 3D centre of curvature, or `nil` if curvature is zero or computation fails.
- **OCCT:** `BRep_Tool::Curve` → `GeomLProp_CLProps::CentreOfCurvature`.
- **Example:**
  ```swift
  if let edge = cyl.edges().first(where: \.isCircle),
     let b = edge.parameterBounds {
      let cc = edge.centerOfCurvature(at: b.first)
      // cc is the circle centre
  }
  ```

---

### `torsion(at:)`

Returns the torsion of the edge's curve at a native parameter.

```swift
public func torsion(at parameter: Double) -> Double?
```

Torsion measures the rate at which the osculating plane twists. Zero for planar curves (lines, circles, arcs). Non-zero for space curves (helices, general B-splines).

- **Parameters:** `parameter` — native curve parameter.
- **Returns:** Torsion value (can be negative), or `nil` if computation fails. Returns `0.0` for degenerate (zero-curvature cross-product) configurations.
- **OCCT:** `Geom_Curve::D3` — uses the formula τ = (d1 × d2) · d3 / |d1 × d2|².
- **Example:**
  ```swift
  // A helix has non-zero torsion
  if let helix = Wire.helix(radius: 5, pitch: 2, turns: 3),
     let shape = Shape.fromWire(helix) {
      let edges = shape.edges()
      if let edge = edges.first,
         let b = edge.parameterBounds {
          let tau = edge.torsion(at: b.first)
      }
  }
  ```

---

### `project(point:)`

Projects a 3D point onto this edge's curve, returning the closest point.

```swift
public func project(point: SIMD3<Double>) -> CurveProjection?
```

Uses OCCT's `GeomAPI_ProjectPointOnCurve` bounded to the edge's parameter range, ensuring the projected point lies within the edge bounds.

- **Parameters:** `point` — query point in 3D space.
- **Returns:** `CurveProjection` with the closest point, its parameter, and the distance; or `nil` if the edge has no curve or projection fails.
- **OCCT:** `BRep_Tool::Curve` + `GeomAPI_ProjectPointOnCurve`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  if let edge = box.edges().first(where: \.isLine) {
      let ep = edge.endpoints
      let mid = (ep.start + ep.end) / 2.0
      if let proj = edge.project(point: mid + SIMD3(1, 1, 1)) {
          print(proj.distance)  // ≈ √3
      }
  }
  ```

---

### `distance(to:)`

The shortest distance from a 3D point to this edge. Returns `nil` if the projection fails.

```swift
public func distance(to point: SIMD3<Double>) -> Double?
```

Pure-Swift convenience — delegates to `project(point:)?.distance`.

- **Parameters:** `point` — query point.
- **Returns:** Distance to the nearest point on the edge, or `nil` on failure.
- **OCCT:** Delegates to `project(point:)` → `GeomAPI_ProjectPointOnCurve`.
- **Example:**
  ```swift
  if let d = edge.distance(to: SIMD3(5, 5, 5)) {
      print("Distance to edge: \(d)")
  }
  ```

---

### `curve3D`

The 3D curve underlying this edge as a standalone `Curve3D`.

```swift
public var curve3D: Curve3D? { get }
```

Returns a `Geom_TrimmedCurve` wrapping the edge's geometry, trimmed to the edge's parameter range. Returns `nil` for edges with no 3D curve representation (rare — typically pcurve-only edges before `BuildCurves3d`).

Use cases include extracting `CircleProperties` from a circular edge, emitting native DXF entities, or feeding edge geometry into parametric analysis pipelines.

- **Returns:** `Curve3D` wrapping a `Geom_TrimmedCurve`, or `nil` if no 3D curve exists.
- **OCCT:** `BRepLib::BuildCurves3d` + `BRep_Tool::Curve`.
- **Example:**
  ```swift
  if let edge = cyl.edges().first(where: \.isCircle),
     let curve = edge.curve3D {
      let props = curve.circleProperties
  }
  ```

---

## Sampling

### `points(count:)`

Returns uniformly-sampled points along the edge curve.

```swift
public func points(count: Int? = nil) -> [SIMD3<Double>]
```

When `count` is `nil`, automatically computes a point count at approximately 0.5 model-unit spacing (`max(2, Int(length / 0.5) + 1)`). Points are evenly spaced in the OCCT parameter domain (not arc-length).

- **Parameters:** `count` — number of points to generate; `nil` = automatic.
- **Returns:** Array of 3D points; empty on failure or for degenerate edges.
- **OCCT:** `BRepAdaptor_Curve::Value` — samples at uniformly-spaced parameter values.
- **Example:**
  ```swift
  let cyl = Shape.cylinder(radius: 5, height: 10)!
  if let circEdge = cyl.edges().first(where: \.isCircle) {
      let pts = circEdge.points(count: 32)
      // pts has 32 points around the circle
  }
  ```

---

## Shape Extension for Edge Access

These members are declared on `Shape` in `Edge.swift` and provide indexed access to all edges in a shape.

---

### `edgeCount`

The total number of edges in the shape.

```swift
public var edgeCount: Int { get }
```

- **OCCT:** `TopExp::MapShapes(shape, TopAbs_EDGE, map)` → `map.Extent()` via `TopTools_IndexedMapOfShape`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  print(box.edgeCount)  // 12
  ```

---

### `edge(at:)`

Returns the edge at a given 0-based index.

```swift
public func edge(at index: Int) -> Edge? 
```

- **Parameters:** `index` — 0-based edge index.
- **Returns:** `Edge` at the given index, or `nil` if the index is out of range.
- **OCCT:** `TopExp::MapShapes` + `TopoDS::Edge` — extracts from `TopTools_IndexedMapOfShape` (1-based internally; index is adjusted).
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  if let edge = box.edge(at: 0) {
      print(edge.length)
  }
  ```

---

### `edges()`

Returns all edges from the shape as typed `Edge` objects.

```swift
public func edges() -> [Edge]
```

Iterates `edge(at:)` from 0 to `edgeCount - 1`. The order matches `edgeCount` / `edge(at:)` — i.e., `TopTools_IndexedMapOfShape` traversal order, which can vary between runs.

- **Returns:** Array of all `Edge` objects; empty if the shape has no edges.
- **OCCT:** `TopExp::MapShapes(shape, TopAbs_EDGE)` — collects all edges via indexed map.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  let edges = box.edges()
  // edges.count == 12
  for edge in edges {
      if edge.isLine { print(edge.length) }
  }
  ```
- **Note:** Edge indices may vary across runs — iterate edges to find a specific one rather than relying on a fixed index.

---

## Edge Analysis

### `hasCurve3D`

Whether this edge has an underlying 3D curve.

```swift
public var hasCurve3D: Bool { get }
```

- **OCCT:** `ShapeAnalysis_Edge::HasCurve3d`.
- **Example:**
  ```swift
  for edge in shape.edges() {
      if edge.hasCurve3D {
          let curve = edge.curve3D
      }
  }
  ```

---

### `isClosed3D`

Whether this edge is closed — i.e., its start and end vertices coincide.

```swift
public var isClosed3D: Bool { get }
```

Closed edges appear as the single circular edge of a cylinder face.

- **OCCT:** `ShapeAnalysis_Edge::IsClosed3d`.
- **Example:**
  ```swift
  let cyl = Shape.cylinder(radius: 5, height: 10)!
  let hasClosedEdge = cyl.edges().contains(where: \.isClosed3D)
  // hasClosedEdge == true (the circular top/bottom edges)
  ```

---

### `isSeam(on:)`

Whether this edge is a seam edge on the given face.

```swift
public func isSeam(on face: Face) -> Bool
```

A seam edge appears twice on a face with different orientations — e.g., the seam line on a cylindrical face where the surface wraps around. Relevant for surface parameterisation and UV-space computations.

- **Parameters:** `face` — the face to test against.
- **Returns:** `true` if the edge is a seam on `face`.
- **OCCT:** `ShapeAnalysis_Edge::IsSeam`.
- **Example:**
  ```swift
  let cyl = Shape.cylinder(radius: 5, height: 10)!
  let faces = cyl.faces()
  for edge in cyl.edges() {
      if edge.isSeam(on: faces[0]) {
          print("found seam edge")
      }
  }
  ```

---

### `adjacentFaces(in:)`

Returns the faces adjacent to this edge within a parent shape.

```swift
public func adjacentFaces(in shape: Shape) -> (Face, Face?)?
```

Most interior edges have exactly two adjacent faces (manifold solid). Boundary edges (on open shells) have only one. The shape must be the same solid from which this edge was extracted.

- **Parameters:** `shape` — the parent shape containing this edge.
- **Returns:** Tuple `(face1, face2)` where `face2` is `nil` for boundary edges; or `nil` if the edge has no adjacent faces in `shape`.
- **OCCT:** `TopExp::MapShapesAndAncestors(shape, TopAbs_EDGE, TopAbs_FACE, map)`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  if let edge = box.edge(at: 0),
     let (f1, f2) = edge.adjacentFaces(in: box) {
      print("face1, face2:", f1, f2 as Any)
  }
  ```

---

### `dihedralAngle(between:and:at:)`

Computes the dihedral angle between two faces at this edge.

```swift
public func dihedralAngle(between face1: Face, and face2: Face, at parameter: Double = 0.5) -> Double?
```

The dihedral angle is measured between the face normals evaluated at a point along the edge. A value of `π` (180°) indicates tangent (smooth) faces; less than `π` is convex; greater than `π` is concave.

- **Parameters:**
  - `face1` — first adjacent face.
  - `face2` — second adjacent face.
  - `parameter` — normalised position along the edge in `[0.0, 1.0]` where to measure (default: midpoint).
- **Returns:** Dihedral angle in radians `[0, 2π]`, or `nil` on error (e.g. degenerate normals or missing PCurves).
- **OCCT:** `BRepAdaptor_Curve` + `BRep_Tool::CurveOnSurface` + `BRepAdaptor_Surface::D1` — computes face normals from first derivatives at the UV parameter.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  for edge in box.edges() {
      if let (f1, f2) = edge.adjacentFaces(in: box), let f2 {
          if let angle = edge.dihedralAngle(between: f1, and: f2) {
              // angle ≈ π/2 for all edges of a box
              print(angle)
          }
      }
  }
  ```

---

## Curve Approximation

### `CurveApproximation`

Result of B-spline approximation of an edge's curve.

```swift
public struct CurveApproximation: Sendable {
    public let maxError: Double
    public let degree: Int
    public let poleCount: Int
}
```

- `maxError` — maximum deviation between the original curve and the B-spline approximation.
- `degree` — B-spline degree of the result.
- `poleCount` — number of B-spline control points (poles) in the result.

---

### `approximatedCurve(tolerance:maxSegments:maxDegree:)`

Approximates this edge's curve as a B-spline `Curve3D`.

```swift
public func approximatedCurve(tolerance: Double = 1e-3,
                               maxSegments: Int = 100,
                               maxDegree: Int = 8) -> Curve3D?
```

Uses `Approx_Curve3d` with C² continuity to convert any curve type (line, circle, ellipse, etc.) into a B-spline representation. Useful for normalising geometry before export or downstream processing.

- **Parameters:**
  - `tolerance` — maximum allowed approximation error (default `1e-3`).
  - `maxSegments` — maximum number of B-spline segments (default `100`).
  - `maxDegree` — maximum B-spline degree (default `8`).
- **Returns:** Approximated B-spline as a `Curve3D`, or `nil` on failure.
- **OCCT:** `BRepAdaptor_Curve` + `Approx_Curve3d` (GeomAbs_C2).
- **Example:**
  ```swift
  let cyl = Shape.cylinder(radius: 5, height: 10)!
  if let edge = cyl.edges().first(where: \.isCircle),
     let bspline = edge.approximatedCurve(tolerance: 1e-4) {
      let dom = bspline.domain
  }
  ```

---

### `curveApproximationInfo(tolerance:maxSegments:maxDegree:)`

Returns information about B-spline approximation without creating the curve object.

```swift
public func curveApproximationInfo(tolerance: Double = 1e-3,
                                    maxSegments: Int = 100,
                                    maxDegree: Int = 8) -> CurveApproximation?
```

Runs the same `Approx_Curve3d` computation as `approximatedCurve(tolerance:maxSegments:maxDegree:)` but returns only the metadata — error, degree, and pole count — without allocating a full `Curve3D`.

- **Parameters:**
  - `tolerance` — maximum allowed approximation error (default `1e-3`).
  - `maxSegments` — maximum number of B-spline segments (default `100`).
  - `maxDegree` — maximum B-spline degree (default `8`).
- **Returns:** `CurveApproximation` struct, or `nil` on failure.
- **OCCT:** `BRepAdaptor_Curve` + `Approx_Curve3d` (GeomAbs_C2) — reads `MaxError()`, `Degree()`, `NbPoles()`.
- **Example:**
  ```swift
  let cyl = Shape.cylinder(radius: 5, height: 10)!
  if let edge = cyl.edges().first(where: \.isCircle),
     let info = edge.curveApproximationInfo() {
      print(info.maxError, info.degree, info.poleCount)
  }
  ```

---

## Edge Splitting

### `split(at:vertex:)`

Splits this edge into two new edges at the specified parameter value.

```swift
public func split(at parameter: Double, vertex: SIMD3<Double>) -> (Edge, Edge)?
```

Divides the edge at `parameter`, placing a new vertex at `vertex`. The two result edges share the new vertex. The original edge is not modified.

- **Parameters:**
  - `parameter` — native OCCT curve parameter at which to split (must be within `parameterBounds`).
  - `vertex` — 3D position for the split vertex (should lie on the curve at `parameter`).
- **Returns:** Tuple `(edge1, edge2)` representing the two halves, or `nil` if splitting fails.
- **OCCT:** `ShapeFix_SplitTool::SplitEdge` with a synthetic planar face context.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  for edge in box.edges() where edge.isLine {
      if let b = edge.parameterBounds,
         let midPt = edge.point(at: (b.first + b.last) / 2.0) {
          let midParam = (b.first + b.last) / 2.0
          if let (e1, e2) = edge.split(at: midParam, vertex: midPt) {
              print(e1.length, e2.length)
          }
      }
      break
  }
  ```
- **Note:** The synthetic planar face used internally (`gp_Pln` through the curve midpoint with Z normal) may cause `SplitEdge` to fail for space curves not lying near Z=0. Provide a curve midpoint as `vertex` for best results.

---

## PCurve / BRepAdaptor\_Curve2d

Members in this section access the 2D parametric curve (PCurve) of an edge on a specific face — the `Geom2d_Curve` that maps the edge into the face's UV parameter space.

---

### `pcurveParams(on:)`

Returns the 2D parametric curve parameter range for this edge on a face.

```swift
public func pcurveParams(on face: Face) -> (first: Double, last: Double)?
```

- **Parameters:** `face` — the face on which this edge lies.
- **Returns:** `(first, last)` parameter range for the PCurve, or `nil` if no PCurve exists for this edge on `face`.
- **OCCT:** `BRepAdaptor_Curve2d` — adaptor over the edge's PCurve on the face's surface.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 20, depth: 30)!
  let faces = box.faces()
  let edges = box.edges()
  for edge in edges {
      if let params = edge.pcurveParams(on: faces[0]) {
          print(params.first, params.last)
          break
      }
  }
  ```

---

### `pcurveValue(at:on:)`

Evaluates the 2D parametric curve of this edge on a face at the given parameter.

```swift
public func pcurveValue(at parameter: Double, on face: Face) -> SIMD2<Double>?
```

Returns the UV coordinate on the face's surface corresponding to the given curve parameter.

- **Parameters:**
  - `parameter` — curve parameter (within the range from `pcurveParams(on:)`).
  - `face` — the face on which the edge lies.
- **Returns:** UV point on the face surface, or `nil` on failure.
- **OCCT:** `BRepAdaptor_Curve2d::Value`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 20, depth: 30)!
  let faces = box.faces()
  for edge in box.edges() {
      if let params = edge.pcurveParams(on: faces[0]) {
          let mid = (params.first + params.last) / 2.0
          if let uv = edge.pcurveValue(at: mid, on: faces[0]) {
              print("UV:", uv)
              break
          }
      }
  }
  ```

---

### `approxCurveOnSurface(face:tolerance:maxSegments:maxDegree:)`

Approximates the 3D curve of this edge on a face from its PCurve.

```swift
public func approxCurveOnSurface(face: Face, tolerance: Double = 1e-4,
                                  maxSegments: Int = 10, maxDegree: Int = 8) -> Shape?
```

Uses `Approx_CurveOnSurface` to compute a 3D B-spline from the edge's 2D parametric curve on the given face's surface. Returns the result as a `Shape` wrapping a new `TopoDS_Edge` with the approximated 3D curve.

- **Parameters:**
  - `face` — the face whose surface defines the PCurve-to-3D mapping.
  - `tolerance` — approximation tolerance (default `1e-4`).
  - `maxSegments` — maximum B-spline segments (default `10`).
  - `maxDegree` — maximum B-spline degree (default `8`).
- **Returns:** `Shape` wrapping the new edge with approximated 3D curve, or `nil` on failure (e.g. no PCurve found).
- **OCCT:** `BRep_Tool::CurveOnSurface` + `Approx_CurveOnSurface` (GeomAbs_C2) + `BRepBuilderAPI_MakeEdge`.
- **Example:**
  ```swift
  let cyl = Shape.cylinder(radius: 5, height: 10)!
  let faces = cyl.faces()
  let edges = cyl.edges()
  if faces.count > 0 {
      if let approxShape = edges[0].approxCurveOnSurface(face: faces[0]) {
          // approxShape wraps an edge with a B-spline 3D curve
      }
  }
  ```
