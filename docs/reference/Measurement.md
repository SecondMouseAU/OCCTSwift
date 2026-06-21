---
title: Measurement
parent: API Reference
---

# Measurement

OCCTSwift's measurement layer adds ergonomic, one-liner accessors for the most common spatial queries — angles between edges, faces, axes, and planes; circle/arc geometry extraction; revolution-surface properties; and a snapshot type (`ShapeMeasurements`) that pre-computes per-face areas/centroids/perimeters and per-edge arc lengths for the whole shape in a single call. These are convenience wrappers over OCCTSwift's existing geometry coverage (no new OCCT calls are introduced for angle computation; bridge calls are confined to `circleProperties` geometry recovery and `ShapeMeasurements.measure`).

## Topics

- [Angles — Edge](#angles--edge) · [Angles — Face](#angles--face) · [Angles — ConstructionAxis](#angles--constructionaxis) · [Angles — ConstructionPlane](#angles--constructionplane) · [Utility — unsignedAngle](#utility--unsignedangle) · [Circle Properties — Edge](#circle-properties--edge) · [Revolution Properties — Face](#revolution-properties--face) · [ShapeMeasurements](#shapemeasurements) · [Shape Extension — measure](#shape-extension--measure)

---

## Angles — Edge

Extension on `Edge` (defined in `MeasurementHelpers.swift`).

---

### `Edge.angle(to:atParameter:)`

Angle between this edge's tangent direction and another edge's tangent direction.

```swift
public func angle(to other: Edge, atParameter t: Double = 0.5) -> Double?
```

Samples each edge's tangent at the normalised parameter `t` (0 = start, 1 = end, default 0.5 = mid). For straight edges the result is the line-line angle. For curved edges it is a point estimate; the angle varies along the curve.

- **Parameters:**
  - `other` — the edge to measure against.
  - `atParameter` — normalised parameter in `[0, 1]` specifying where to sample the tangent on each edge (default `0.5`, i.e. mid-curve). Clamped to `[0, 1]`.
- **Returns:** Angle in radians in `[0, π]`, or `nil` if either edge has no `parameterBounds` or the tangent cannot be evaluated.
- **OCCT:** Pure-Swift over `Edge.tangent(at:)` + `Edge.parameterBounds`. Tangent evaluation delegates to `BRepAdaptor_Curve::DN`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  let edges = box.edges()
  if edges.count >= 2, let a = edges[0].angle(to: edges[1]) {
      print(a * 180 / .pi)  // degrees
  }
  ```

---

### `Edge.isParallel(to:toleranceRadians:)`

Whether this edge is parallel to another edge at their mid-tangents.

```swift
public func isParallel(to other: Edge, toleranceRadians: Double = 1e-4) -> Bool?
```

Convenience wrapper over `angle(to:)`. Returns `true` when the angle is within `toleranceRadians` of 0 or π (anti-parallel counts as parallel).

- **Parameters:**
  - `other` — edge to compare.
  - `toleranceRadians` — angular tolerance (default `1e-4` rad ≈ 0.006°).
- **Returns:** `true` if parallel, `false` if not, `nil` if the angle cannot be computed.
- **Example:**
  ```swift
  let edges = Shape.box(width: 10, height: 10, depth: 10)!.edges()
  if let parallel = edges[0].isParallel(to: edges[1]) {
      print(parallel)
  }
  ```

---

### `Edge.isPerpendicular(to:toleranceRadians:)`

Whether this edge is perpendicular to another edge at their mid-tangents.

```swift
public func isPerpendicular(to other: Edge, toleranceRadians: Double = 1e-4) -> Bool?
```

Returns `true` when `|angle - π/2| < toleranceRadians`.

- **Parameters:**
  - `other` — edge to compare.
  - `toleranceRadians` — angular tolerance (default `1e-4` rad).
- **Returns:** `true` if perpendicular, `false` if not, `nil` if the angle cannot be computed.
- **Example:**
  ```swift
  let edges = Shape.box(width: 10, height: 5, depth: 2)!.edges()
  if let perp = edges[0].isPerpendicular(to: edges[3]) {
      print(perp)  // true for adjacent box edges
  }
  ```

---

## Angles — Face

Extension on `Face` (defined in `MeasurementHelpers.swift`).

---

### `Face.angle(to:)`

Angle between the normals of two faces, evaluated at the UV midpoint of each.

```swift
public func angle(to other: Face) -> Double?
```

For two planar faces this equals the dihedral angle between the planes (after the normal-space mapping). For curved faces it is a point estimate at each face centre.

- **Parameters:** `other` — the face to measure against.
- **Returns:** Angle between the normals in radians in `[0, π]`, or `nil` if either face has no `uvBounds` or the normal cannot be evaluated.
- **OCCT:** Pure-Swift over `Face.normal(atU:v:)` + `Face.uvBounds`. Normal evaluation delegates to `GeomLProp_SLProps::Normal`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  let faces = box.faces()
  if faces.count >= 2, let a = faces[0].angle(to: faces[1]) {
      print(a * 180 / .pi)  // 90° for adjacent box faces
  }
  ```

---

### `Face.isParallel(to:toleranceRadians:)`

Whether this face's normal is parallel (or anti-parallel) to another face's normal.

```swift
public func isParallel(to other: Face, toleranceRadians: Double = 1e-4) -> Bool?
```

Returns `true` when the normal-to-normal angle is within `toleranceRadians` of 0 or π.

- **Parameters:**
  - `other` — face to compare.
  - `toleranceRadians` — angular tolerance (default `1e-4` rad).
- **Returns:** `true` if parallel, `false` if not, `nil` if the angle cannot be computed.
- **Example:**
  ```swift
  let faces = Shape.box(width: 10, height: 10, depth: 5)!.faces()
  // Top and bottom faces of a box are parallel
  if let par = faces[0].isParallel(to: faces[5]) {
      print(par)  // true
  }
  ```

---

### `Face.isPerpendicular(to:toleranceRadians:)`

Whether this face is perpendicular to another (normals at 90°).

```swift
public func isPerpendicular(to other: Face, toleranceRadians: Double = 1e-4) -> Bool?
```

Returns `true` when `|angle - π/2| < toleranceRadians`.

- **Parameters:**
  - `other` — face to compare.
  - `toleranceRadians` — angular tolerance (default `1e-4` rad).
- **Returns:** `true` if perpendicular, `false` if not, `nil` if the angle cannot be computed.
- **Example:**
  ```swift
  let faces = Shape.box(width: 10, height: 10, depth: 5)!.faces()
  if let perp = faces[0].isPerpendicular(to: faces[2]) {
      print(perp)  // true for a top face vs a side face
  }
  ```

---

### `Face.isCoplanar(with:tolerance:)`

Whether this face is coplanar with another — normals are parallel AND their centre points lie on the same plane.

```swift
public func isCoplanar(with other: Face, tolerance: Double = 1e-6) -> Bool?
```

Two conditions must both hold: (1) normals are parallel within `1e-4` radians, (2) the signed distance from this face's UV-midpoint to the other face's plane is less than `tolerance`.

- **Parameters:**
  - `other` — face to compare.
  - `tolerance` — point-to-plane distance tolerance (default `1e-6`).
- **Returns:** `true` if coplanar, `false` if not, `nil` if normals or points cannot be evaluated.
- **Note:** Returns `nil` (not `false`) if the faces are not parallel — callers can distinguish "non-parallel" from "parallel but offset".
- **Example:**
  ```swift
  let faces = Shape.box(width: 10, height: 10, depth: 5)!.faces()
  // Top and bottom are parallel but NOT coplanar
  if let cp = faces[0].isCoplanar(with: faces[5]) {
      print(cp)  // false
  }
  ```

---

## Angles — ConstructionAxis

Extension on `ConstructionAxis` (defined in `MeasurementHelpers.swift`).

---

### `ConstructionAxis.angle(to:in:)`

Angle between two construction axes, resolved against the given topology graph.

```swift
public func angle(to other: ConstructionAxis, in graph: TopologyGraph) -> Double?
```

Resolves each axis via `TopologyGraph.resolve(_:)` to obtain its `direction` vector, then computes the unsigned angle between the directions.

- **Parameters:**
  - `other` — the axis to compare.
  - `graph` — the `TopologyGraph` used to resolve both axis handles.
- **Returns:** Angle in radians in `[0, π]`, or `nil` if either axis fails to resolve.
- **OCCT:** Pure-Swift over `TopologyGraph.resolve` + `unsignedAngle(between:and:)`.
- **Example:**
  ```swift
  let graph = shape.topologyGraph()
  let axes = graph.constructionAxes()
  if axes.count >= 2,
     let a = axes[0].angle(to: axes[1], in: graph) {
      print(a * 180 / .pi)
  }
  ```

---

## Angles — ConstructionPlane

Extension on `ConstructionPlane` (defined in `MeasurementHelpers.swift`).

---

### `ConstructionPlane.angle(to:in:)`

Angle between two construction planes (angle between their Z-axis normals).

```swift
public func angle(to other: ConstructionPlane, in graph: TopologyGraph) -> Double?
```

Resolves each plane via `TopologyGraph.resolve(_:)` to obtain its `zAxis` vector, then computes the unsigned angle between them.

- **Parameters:**
  - `other` — the plane to compare.
  - `graph` — the `TopologyGraph` used to resolve both plane handles.
- **Returns:** Angle in radians in `[0, π]`, or `nil` if either plane fails to resolve.
- **OCCT:** Pure-Swift over `TopologyGraph.resolve` + `unsignedAngle(between:and:)`.
- **Example:**
  ```swift
  let graph = shape.topologyGraph()
  let planes = graph.constructionPlanes()
  if planes.count >= 2,
     let a = planes[0].angle(to: planes[1], in: graph) {
      print(a * 180 / .pi)
  }
  ```

---

## Utility — unsignedAngle

Free function (defined in `MeasurementHelpers.swift`).

---

### `unsignedAngle(between:and:)`

Unsigned angle in `[0, π]` between two 3D vectors.

```swift
public func unsignedAngle(between a: SIMD3<Double>, and b: SIMD3<Double>) -> Double
```

Uses the clamped dot-product formula `acos(dot(a,b) / (|a| * |b|))`. Returns `0` for degenerate (near-zero length) input rather than `nil`.

- **Parameters:**
  - `a` — first vector (need not be unit length).
  - `b` — second vector (need not be unit length).
- **Returns:** Angle in radians in `[0, π]`. Returns `0` if either vector has length ≤ `1e-12`.
- **Example:**
  ```swift
  let a = SIMD3<Double>(1, 0, 0)
  let b = SIMD3<Double>(0, 1, 0)
  let angle = unsignedAngle(between: a, and: b)  // π/2
  ```

---

## Circle Properties — Edge

Extension on `Edge`, plus the nested `CircleProperties` struct (defined in `MeasurementHelpers.swift`).

---

### `Edge.CircleProperties`

Extracted circle or arc geometry for a circular edge.

```swift
public struct CircleProperties: Sendable, Hashable {
    public let center: SIMD3<Double>
    public let radius: Double
    public let axis: SIMD3<Double>    // unit normal to the circle's plane
    public let isFullCircle: Bool
    public let startAngle: Double     // radians; 0 for a full circle
    public let endAngle: Double       // radians; 2π for a full circle
}
```

- `center` — 3D centre of the circle.
- `radius` — circle radius in model units.
- `axis` — unit normal to the circle's plane (right-hand rule relative to the curve's direction).
- `isFullCircle` — `true` when `endAngle - startAngle ≈ 2π`.
- `startAngle` / `endAngle` — parameter range in radians (equal to `parameterBounds` for a `Geom_Circle`).

---

### `Edge.circleProperties`

Circle or arc properties if this edge's underlying curve is a circle. Returns `nil` for lines, ellipses, B-splines, etc.

```swift
public var circleProperties: CircleProperties? { get }
```

Checks `curveType == .circle`, then samples three points along the parameter range and fits a circle through them via `circleThroughThreePoints`. The `axis` direction is derived from the cross product of the chord vectors.

- **Returns:** `CircleProperties`, or `nil` if the edge is not circular or parameter bounds are unavailable.
- **OCCT:** Pure-Swift over `Edge.point(at:)` + `Edge.parameterBounds` + internal `circleThroughThreePoints`. Curve type check uses `BRepAdaptor_Curve::GetType`.
- **Example:**
  ```swift
  let cyl = Shape.cylinder(radius: 5, height: 10)!
  for edge in cyl.edges() {
      if let cp = edge.circleProperties {
          print("r=\(cp.radius) full=\(cp.isFullCircle) axis=\(cp.axis)")
      }
  }
  ```

---

## Revolution Properties — Face

Extension on `Face`, plus the nested `RevolutionProperties` struct (defined in `MeasurementHelpers.swift`).

---

### `Face.RevolutionProperties`

Axis and representative radius for a revolved surface face.

```swift
public struct RevolutionProperties: Sendable, Hashable {
    public let axis: ShapeAxis
    public let radius: Double
}
```

- `axis` — the primary revolution axis (a `ShapeAxis` carrying `origin` and `direction`).
- `radius` — distance from the axis to the face centre, in model units. For cylindrical faces this is the exact cylinder radius. For cones, spheres, tori, and surfaces of revolution it is a representative radial distance at the UV midpoint; use `Surface` dedicated properties for major/minor radii.

---

### `Face.revolutionProperties`

Axis and representative radius if this face's underlying surface is cylindrical, conical, toroidal, spherical, or a surface of revolution.

```swift
public var revolutionProperties: RevolutionProperties? { get }
```

Returns `nil` for planar faces or free-form (B-spline) surfaces. For all supported types the radius is computed as the distance from the axis line to the UV-midpoint of the face.

- **Returns:** `RevolutionProperties`, or `nil` if `primaryAxis` is unavailable or `surfaceType` is not one of `.cylinder`, `.cone`, `.sphere`, `.torus`, `.surfaceOfRevolution`.
- **OCCT:** Pure-Swift over `Face.primaryAxis` + `Face.surfaceType` + `Face.uvBounds` + `Face.point(atU:v:)`. `primaryAxis` delegates to `BRepAdaptor_Surface` axis extraction.
- **Note:** For surfaces where "radius" is ambiguous (e.g. a torus has major and minor radius), this returns only a single representative value. Use `Surface` for full parametric detail.
- **Example:**
  ```swift
  let cyl = Shape.cylinder(radius: 5, height: 10)!
  for face in cyl.faces() {
      if let rp = face.revolutionProperties {
          print("r=\(rp.radius) axis=\(rp.axis.direction)")
      }
  }
  ```

---

## ShapeMeasurements

Defined in `ShapeMeasurements.swift`. A snapshot of per-face and per-edge scalar measurements for a `Shape`, indexed parallel to `Shape.faces()` and `Shape.edge(at:)`.

---

### `ShapeMeasurements` (struct)

```swift
public struct ShapeMeasurements: Sendable
```

All four stored arrays are parallel to the shape's face/edge enumeration order and are computed together by `Shape.measure(linearTolerance:)`.

---

### `ShapeMeasurements.faceAreas`

Per-face surface areas, indexed parallel to `shape.faces()`.

```swift
public let faceAreas: [Double]
```

`faceAreas[i]` is the area of `shape.faces()[i]`. Computed via `BRepGProp::SurfaceProperties`.

- **OCCT:** `BRepGProp::SurfaceProperties` + `GProp_GProps::Mass`.
- **Example:**
  ```swift
  let m = Shape.box(width: 10, height: 10, depth: 5)!.measure()
  for (i, area) in m.faceAreas.enumerated() {
      print("face \(i): area = \(area)")
  }
  ```

---

### `ShapeMeasurements.edgeLengths`

Per-edge arc lengths, indexed parallel to `0..<shape.edgeCount`.

```swift
public let edgeLengths: [Double]
```

`edgeLengths[i]` is the arc length of `shape.edge(at: i)`. A missing edge (nil from `Shape.edge(at:)`) contributes `0.0`.

- **OCCT:** `Edge.length` — delegates to `BRepGProp::LinearProperties` + `GProp_GProps::Mass`.
- **Example:**
  ```swift
  let m = Shape.box(width: 10, height: 10, depth: 5)!.measure()
  print(m.edgeLengths)  // 12 values for a box
  ```

---

### `ShapeMeasurements.faceCentroids`

Per-face surface centres of mass, indexed parallel to `shape.faces()`.

```swift
public let faceCentroids: [SIMD3<Double>]
```

`faceCentroids[i]` is the surface centre-of-mass of `shape.faces()[i]`, computed via `BRepGProp_Sinert` (surface inertia). Empty array if the struct was constructed without centroids.

- **OCCT:** `OCCTBRepGPropSinert` → `BRepGProp_Sinert::CentreOfMass`.
- **Example:**
  ```swift
  let m = Shape.box(width: 10, height: 10, depth: 5)!.measure()
  for (i, c) in m.faceCentroids.enumerated() {
      print("face \(i) centroid: \(c)")
  }
  ```

---

### `ShapeMeasurements.facePerimeters`

Per-face outer-boundary lengths, indexed parallel to `shape.faces()`.

```swift
public let facePerimeters: [Double?]
```

`facePerimeters[i]` is the arc length of the outer wire of `shape.faces()[i]`, or `nil` if the face has no outer wire or wire length is unavailable. Inner-wire (hole) perimeters are excluded.

- **OCCT:** `Face.outerWire?.length` → `BRepTools::OuterWire` + `BRepGProp::LinearProperties`.
- **Example:**
  ```swift
  let m = Shape.box(width: 10, height: 10, depth: 5)!.measure()
  for p in m.facePerimeters {
      print(p.map { "\($0)" } ?? "no outer wire")
  }
  ```

---

### `ShapeMeasurements.init(faceAreas:edgeLengths:faceCentroids:facePerimeters:)`

Memberwise initialiser for constructing `ShapeMeasurements` directly.

```swift
public init(
    faceAreas: [Double],
    edgeLengths: [Double],
    faceCentroids: [SIMD3<Double>] = [],
    facePerimeters: [Double?] = []
)
```

Useful when building measurement snapshots programmatically (e.g. from cached data). `faceCentroids` and `facePerimeters` default to empty arrays for back-compat with callers that only need areas and lengths.

- **Parameters:**
  - `faceAreas` — per-face areas parallel to `shape.faces()`.
  - `edgeLengths` — per-edge lengths parallel to `0..<shape.edgeCount`.
  - `faceCentroids` — per-face centroids; defaults to `[]`.
  - `facePerimeters` — per-face outer-wire lengths; defaults to `[]`.
- **Example:**
  ```swift
  let m = ShapeMeasurements(faceAreas: [50, 50, 100, 100, 50, 50],
                             edgeLengths: Array(repeating: 10, count: 12))
  print(m.totalFaceArea)  // 400
  ```

---

### `ShapeMeasurements.totalFaceArea`

Sum of all face areas.

```swift
public var totalFaceArea: Double { get }
```

Convenience over `faceAreas.reduce(0, +)`. Useful as a quick total-surface metric.

- **Example:**
  ```swift
  let m = Shape.box(width: 10, height: 10, depth: 10)!.measure()
  print(m.totalFaceArea)  // 600.0
  ```

---

### `ShapeMeasurements.totalEdgeLength`

Sum of all edge arc lengths.

```swift
public var totalEdgeLength: Double { get }
```

Convenience over `edgeLengths.reduce(0, +)`.

- **Example:**
  ```swift
  let m = Shape.box(width: 10, height: 10, depth: 10)!.measure()
  print(m.totalEdgeLength)  // 120.0 (12 edges × 10)
  ```

---

### `ShapeMeasurements.totalFacePerimeter`

Sum of all available face outer-wire lengths (`nil` entries are treated as zero).

```swift
public var totalFacePerimeter: Double { get }
```

Convenience over `facePerimeters.reduce(0) { acc, p in acc + (p ?? 0) }`.

- **Example:**
  ```swift
  let m = Shape.box(width: 10, height: 10, depth: 10)!.measure()
  print(m.totalFacePerimeter)  // 240.0 (6 faces × 4 × 10)
  ```

---

## Shape Extension — measure

---

### `Shape.measure(linearTolerance:)`

Compute per-face area / centroid / perimeter and per-edge arc length for this shape in one call.

```swift
public func measure(linearTolerance: Double = 1e-6) -> ShapeMeasurements
```

Iterates `faces()` and `edge(at:)`, computing all four measurement arrays. The `faceCentroids` array is populated from `Face.surfaceInertia` (which calls `BRepGProp_Sinert`); `facePerimeters` uses `Face.outerWire?.length`.

- **Parameters:** `linearTolerance` — numerical integration tolerance forwarded to `Face.area(tolerance:)` (default `1e-6`). Tighten only if you observe precision issues at the cost of slightly longer computation.
- **Returns:** A `ShapeMeasurements` snapshot with all four arrays populated and indexed parallel to the shape's face/edge enumeration.
- **OCCT:** `BRepGProp::SurfaceProperties` (face areas), `BRepGProp_Sinert` (centroids), `BRepGProp::LinearProperties` (edge lengths + outer-wire lengths), `BRepTools::OuterWire` (outer wire lookup).
- **Example:**
  ```swift
  let part = Shape.box(width: 100, height: 50, depth: 20)!
  let m = part.measure()
  print("surface area:", m.totalFaceArea)       // 22000
  print("total edge length:", m.totalEdgeLength) // 1440
  for (i, (area, centroid)) in zip(m.faceAreas, m.faceCentroids).enumerated() {
      print("face \(i): area=\(area) centroid=\(centroid)")
  }
  ```
