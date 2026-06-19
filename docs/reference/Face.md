---
title: Face
parent: API Reference
---

# Face

A `Face` represents a bounded surface region within a 3D solid — the Swift analog of OCCT's `TopoDS_Face`. Faces carry a reference to an underlying geometric surface (plane, cylinder, B-spline, etc.) trimmed by a boundary wire. Obtain faces by calling `Shape.faces()`, by constructing `Face(_ shape:)` from a face-typed `Shape`, or via the filtering helpers `Shape.upwardFaces()` and `Shape.horizontalFaces()`.

## Topics

- [Initializers](#initializers) · [Properties](#properties) · [Surface Properties (v0.18.0)](#surface-properties-v0180) · [Shape Extension — Face Analysis](#shape-extension--face-analysis) · [BRepGProp\_Face Evaluation (v0.45.0)](#brepgprop_face-evaluation-v0450)

---

## Initializers

### `Face.init?(_ shape:)`

Constructs a `Face` from a `Shape` that wraps a `TopoDS_Face`. Returns `nil` if the shape is null or wraps a non-face topology type.

```swift
public convenience init?(_ shape: Shape)
```

Inverse of `Shape.fromFace(_:)`. Use when you have a face-typed `Shape` (e.g. from `Shape.subShapes(ofType: .face)`) and need the typed `Face` object.

- **Parameters:** `shape` — a `Shape` wrapping a `TopoDS_Face`.
- **Returns:** `nil` if `shape` is null or `shape.shapeType != .face`.
- **OCCT:** `TopoDS::Face` — checks `ShapeType() == TopAbs_FACE`, then casts the underlying `TopoDS_Shape`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  let faceShapes = box.subShapes(ofType: .face)
  if let face = Face(faceShapes[0]) {
      print(face.surfaceType)  // .plane
  }
  ```

---

### `index`

Index of this face within the parent shape from which it was extracted (`-1` if standalone).

```swift
public let index: Int
```

Set automatically when a `Face` is created via `Shape.faces()`; faces constructed via `Face(_ shape:)` get index `-1`.

- **Example:**
  ```swift
  let faces = Shape.box(width: 10, height: 5, depth: 2)!.faces()
  for face in faces {
      print(face.index)  // 0, 1, 2, 3, 4, 5
  }
  ```

---

## Properties

### `normal`

The outward normal vector at the parametric centre of the face.

```swift
public var normal: SIMD3<Double>? { get }
```

Evaluates the surface normal at the midpoint of the face's UV parameter range. Respects face orientation (`TopAbs_REVERSED` flips the result).

- **Returns:** Unit normal vector, or `nil` if the normal is undefined at the centre (e.g. degenerate face or singular parametric point).
- **OCCT:** `BRepAdaptor_Surface` + `BRepLProp_SLProps::Normal` — adapts the face, evaluates at `(uMid, vMid)`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  for face in box.faces() {
      if let n = face.normal {
          print(n)  // one of ±X, ±Y, ±Z for a box
      }
  }
  ```

---

### `outerWire`

The outer boundary wire of the face.

```swift
public var outerWire: Wire? { get }
```

Returns the outermost wire (the single outer boundary loop); inner wires (holes) are not returned here.

- **Returns:** The outer `Wire`, or `nil` if the face has no outer wire or retrieval fails.
- **OCCT:** `BRepTools::OuterWire` — returns the outermost `TopoDS_Wire` of the face.
- **Example:**
  ```swift
  if let face = Shape.box(width: 5, height: 5, depth: 5)!.faces().first,
     let boundary = face.outerWire {
      print(boundary.length)
  }
  ```

---

### `bounds`

The axis-aligned bounding box of the face.

```swift
public var bounds: (min: SIMD3<Double>, max: SIMD3<Double>) { get }
```

- **Returns:** Tuple of min and max corners of the AABB. Returns `(.zero, .zero)` on error.
- **OCCT:** `BRepBndLib::Add` + `Bnd_Box::Get`.
- **Example:**
  ```swift
  let face = Shape.box(width: 10, height: 5, depth: 2)!.faces()[0]
  let bb = face.bounds
  // bb.min and bb.max define the face's extents
  ```

---

### `isPlanar`

Whether the face's underlying surface is a plane.

```swift
public var isPlanar: Bool { get }
```

- **Returns:** `true` if the underlying `GeomAbs_SurfaceType` is `GeomAbs_Plane`.
- **OCCT:** `BRepAdaptor_Surface::GetType() == GeomAbs_Plane`.
- **Example:**
  ```swift
  let face = Shape.box(width: 10, height: 10, depth: 10)!.faces()[0]
  #expect(face.isPlanar)  // box faces are planar
  ```

---

### `isHorizontal(tolerance:)`

Whether the face's normal is pointing up or down (parallel to the Z axis within the given tolerance).

```swift
public func isHorizontal(tolerance: Double = 0.01) -> Bool
```

Pure-Swift: computes `abs(normal.z) > cos(tolerance)`.

- **Parameters:** `tolerance` — angle tolerance in radians (default ~0.57°).
- **Returns:** `true` if the face's centre normal is within `tolerance` of the ±Z axis; `false` if `normal` is `nil`.
- **Example:**
  ```swift
  let top = Shape.box(width: 10, height: 10, depth: 5)!.faces()
      .filter { $0.isHorizontal() }
  #expect(top.count == 2)  // top and bottom of box
  ```

---

### `isUpwardFacing(tolerance:)`

Whether the face's normal points upward (positive Z component).

```swift
public func isUpwardFacing(tolerance: Double = 0.01) -> Bool
```

Pure-Swift: computes `normal.z > cos(tolerance)`.

- **Parameters:** `tolerance` — angle tolerance in radians (default ~0.57°).
- **Returns:** `true` if the face is horizontal and upward-facing; `false` if `normal` is `nil`.
- **Example:**
  ```swift
  let floor = Shape.box(width: 10, height: 10, depth: 5)!.faces()
      .filter { $0.isUpwardFacing() }
  #expect(floor.count == 1)  // top face
  ```

---

### `isDownwardFacing(tolerance:)`

Whether the face's normal points downward (negative Z component).

```swift
public func isDownwardFacing(tolerance: Double = 0.01) -> Bool
```

Pure-Swift: computes `normal.z < -cos(tolerance)`.

- **Parameters:** `tolerance` — angle tolerance in radians (default ~0.57°).
- **Returns:** `true` if the face is horizontal and downward-facing; `false` if `normal` is `nil`.
- **Example:**
  ```swift
  let ceiling = Shape.box(width: 10, height: 10, depth: 5)!.faces()
      .filter { $0.isDownwardFacing() }
  #expect(ceiling.count == 1)  // bottom face
  ```

---

### `isVertical(tolerance:)`

Whether the face's normal is horizontal (perpendicular to Z axis).

```swift
public func isVertical(tolerance: Double = 0.01) -> Bool
```

Pure-Swift: computes `abs(normal.z) < sin(tolerance)`.

- **Parameters:** `tolerance` — angle tolerance in radians (default ~0.57°).
- **Returns:** `true` if the face's normal lies in the XY plane within `tolerance`; `false` if `normal` is `nil`.
- **Example:**
  ```swift
  let walls = Shape.box(width: 10, height: 10, depth: 5)!.faces()
      .filter { $0.isVertical() }
  #expect(walls.count == 4)  // four side faces
  ```

---

### `zLevel`

The Z coordinate of a horizontal planar face.

```swift
public var zLevel: Double? { get }
```

Returns `nil` if the face is not planar, not horizontal (normal within 0.99 of ±Z), or the bridge call fails.

- **Returns:** The Z coordinate of the face's plane location, or `nil` if the face is non-planar or non-horizontal.
- **OCCT:** `BRepAdaptor_Surface::Plane()` → `gp_Pln::Location().Z()`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 5)!
  let zLevels = box.faces().compactMap { $0.zLevel }
  // zLevels contains 0.0 (bottom) and 5.0 (top)
  ```

---

## Surface Properties (v0.18.0)

### `SurfaceType`

Classification of the underlying geometric surface type.

```swift
public enum SurfaceType: Int32, Sendable {
    case plane = 0, cylinder = 1, cone = 2, sphere = 3, torus = 4
    case bezierSurface = 5, bsplineSurface = 6
    case surfaceOfRevolution = 7, surfaceOfExtrusion = 8
    case offsetSurface = 9, other = 10
}
```

Corresponds to OCCT's `GeomAbs_SurfaceType` enumeration, mapped via `BRepAdaptor_Surface::GetType()`.

---

### `PrincipalCurvatures`

Result of a principal curvature query at a UV parameter.

```swift
public struct PrincipalCurvatures: Sendable {
    public let kMin: Double
    public let kMax: Double
    public let dirMin: SIMD3<Double>
    public let dirMax: SIMD3<Double>
}
```

- `kMin` / `kMax` — minimum and maximum principal curvatures (reciprocals of principal radii).
- `dirMin` / `dirMax` — unit direction vectors of the principal curvature lines on the surface.

---

### `SurfaceProjection`

Result of projecting a 3D point onto the face's surface.

```swift
public struct SurfaceProjection: Sendable {
    public let point: SIMD3<Double>
    public let u: Double
    public let v: Double
    public let distance: Double
}
```

- `point` — closest 3D point on the surface.
- `u`, `v` — UV parameters of that point.
- `distance` — Euclidean distance from the query point to `point`.

---

### `uvBounds`

The UV parameter bounds of the face as trimmed by its boundary wires.

```swift
public var uvBounds: (uMin: Double, uMax: Double, vMin: Double, vMax: Double)? { get }
```

Uses `BRepTools::UVBounds` which accounts for the face's trimming wires. For integration-ready bounds that respect face orientation, use `naturalBounds` instead.

- **Returns:** UV extents, or `nil` on error.
- **OCCT:** `BRepTools::UVBounds`.
- **Example:**
  ```swift
  if let uv = face.uvBounds {
      let uMid = (uv.uMin + uv.uMax) / 2
      let vMid = (uv.vMin + uv.vMax) / 2
      let center = face.point(atU: uMid, v: vMid)
  }
  ```

---

### `surfaceType`

The geometric surface type of this face.

```swift
public var surfaceType: SurfaceType { get }
```

Never fails — returns `.other` if the type cannot be determined.

- **OCCT:** `BRepAdaptor_Surface::GetType()` mapped to `SurfaceType`.
- **Example:**
  ```swift
  let cyl = Shape.cylinder(radius: 5, height: 10)!
  let side = cyl.faces().first { $0.surfaceType == .cylinder }
  ```

---

### `area(tolerance:)`

The surface area of the face.

```swift
public func area(tolerance: Double = 1e-6) -> Double
```

- **Parameters:** `tolerance` — numerical integration tolerance (default 1e-6).
- **Returns:** Area in squared model units; returns `-1.0` on error.
- **OCCT:** `BRepGProp::SurfaceProperties` + `GProp_GProps::Mass`.
- **Example:**
  ```swift
  let topFace = Shape.box(width: 10, height: 5, depth: 2)!
      .faces().filter { $0.isUpwardFacing() }.first!
  #expect(topFace.area() ≈ 50.0)
  ```

---

### `point(atU:v:)`

Evaluates the 3D point on the surface at UV parameters.

```swift
public func point(atU u: Double, v: Double) -> SIMD3<Double>?
```

- **Parameters:** `u` — U surface parameter; `v` — V surface parameter.
- **Returns:** 3D point, or `nil` if the surface is null or evaluation fails.
- **OCCT:** `BRep_Tool::Surface` + `Geom_Surface::D0(u, v, pnt)`.
- **Example:**
  ```swift
  if let uv = face.uvBounds {
      let mid = face.point(atU: (uv.uMin + uv.uMax) / 2,
                           v:   (uv.vMin + uv.vMax) / 2)
  }
  ```

---

### `normal(atU:v:)`

Evaluates the outward surface normal at UV parameters.

```swift
public func normal(atU u: Double, v: Double) -> SIMD3<Double>?
```

Respects face orientation (`TopAbs_REVERSED` flips the result). Uses order-1 surface properties.

- **Parameters:** `u` — U parameter; `v` — V parameter.
- **Returns:** Unit normal vector, or `nil` if the normal is undefined at `(u, v)`.
- **OCCT:** `BRep_Tool::Surface` + `GeomLProp_SLProps::Normal` (order 1, `Precision::Confusion()` tolerance).
- **Example:**
  ```swift
  if let uv = face.uvBounds, let n = face.normal(atU: uv.uMin, v: uv.vMin) {
      print(n)
  }
  ```

---

### `gaussianCurvature(atU:v:)`

The Gaussian curvature of the surface at UV parameters.

```swift
public func gaussianCurvature(atU u: Double, v: Double) -> Double?
```

Gaussian curvature = k₁ × k₂ (product of principal curvatures). Positive on convex/concave surfaces; negative on saddle surfaces; zero on developable surfaces.

- **Parameters:** `u` — U parameter; `v` — V parameter.
- **Returns:** Gaussian curvature value, or `nil` if curvature is undefined at `(u, v)`.
- **OCCT:** `GeomLProp_SLProps::GaussianCurvature` (order 2).
- **Example:**
  ```swift
  let sphere = Shape.sphere(radius: 5)!
  if let face = sphere.faces().first, let uv = face.uvBounds {
      let k = face.gaussianCurvature(atU: (uv.uMin + uv.uMax) / 2,
                                     v:   (uv.vMin + uv.vMax) / 2)
      // k ≈ 1/25 (= 1/r²) for a sphere of radius 5
  }
  ```

---

### `meanCurvature(atU:v:)`

The mean curvature of the surface at UV parameters.

```swift
public func meanCurvature(atU u: Double, v: Double) -> Double?
```

Mean curvature = (k₁ + k₂) / 2. Zero on minimal surfaces; equal to 1/R on a sphere of radius R.

- **Parameters:** `u` — U parameter; `v` — V parameter.
- **Returns:** Mean curvature value, or `nil` if curvature is undefined at `(u, v)`.
- **OCCT:** `GeomLProp_SLProps::MeanCurvature` (order 2).
- **Example:**
  ```swift
  if let face = Shape.cylinder(radius: 5, height: 10)!.faces()
      .first(where: { $0.surfaceType == .cylinder }),
     let uv = face.uvBounds {
      let h = face.meanCurvature(atU: (uv.uMin + uv.uMax) / 2,
                                 v:   (uv.vMin + uv.vMax) / 2)
      // h ≈ 0.1 (1/(2r)) for a cylinder
  }
  ```

---

### `principalCurvatures(atU:v:)`

The principal curvatures and their directions at UV parameters.

```swift
public func principalCurvatures(atU u: Double, v: Double) -> PrincipalCurvatures?
```

Returns both principal curvature values (kMin, kMax) and their surface directions. Requires order-2 surface property evaluation.

- **Parameters:** `u` — U parameter; `v` — V parameter.
- **Returns:** `PrincipalCurvatures` struct, or `nil` if curvature is undefined at `(u, v)`.
- **OCCT:** `GeomLProp_SLProps::MinCurvature`, `MaxCurvature`, `CurvatureDirections` (order 2).
- **Example:**
  ```swift
  if let uv = face.uvBounds,
     let pc = face.principalCurvatures(atU: (uv.uMin + uv.uMax) / 2,
                                       v:   (uv.vMin + uv.vMax) / 2) {
      print(pc.kMin, pc.kMax, pc.dirMin, pc.dirMax)
  }
  ```

---

### `project(point:)`

Projects a 3D point onto the face's surface, returning the closest point.

```swift
public func project(point: SIMD3<Double>) -> SurfaceProjection?
```

Restricts the projection to the face's UV parameter range (as returned by `BRepTools::UVBounds`).

- **Parameters:** `point` — 3D query point.
- **Returns:** `SurfaceProjection` with the closest 3D point, its UV parameters, and the distance; `nil` if no projection exists or the face is null.
- **OCCT:** `GeomAPI_ProjectPointOnSurf::NearestPoint` / `LowerDistanceParameters` / `LowerDistance`.
- **Example:**
  ```swift
  let face = Shape.box(width: 10, height: 10, depth: 10)!.faces()[0]
  if let proj = face.project(point: SIMD3(5, 5, 20)) {
      print(proj.point, proj.distance)
  }
  ```

---

### `allProjections(of:)`

Returns all projection results (not just the nearest) for a 3D point onto the face's surface.

```swift
public func allProjections(of point: SIMD3<Double>) -> [SurfaceProjection]
```

Uses a fixed buffer of up to 32 results. For most surfaces there is only one projection; multiple results arise on periodic or multiply-connected surfaces.

- **Parameters:** `point` — 3D query point.
- **Returns:** Array of `SurfaceProjection` values (may be empty if no projections are found).
- **OCCT:** `GeomAPI_ProjectPointOnSurf::NbPoints` / `Point(i)` / `Parameters(i)` / `Distance(i)`.
- **Example:**
  ```swift
  let projections = face.allProjections(of: SIMD3(0, 0, 100))
  for p in projections {
      print(p.point, p.u, p.v, p.distance)
  }
  ```

---

### `intersection(with:tolerance:)`

Computes the intersection curves between this face and another face.

```swift
public func intersection(with other: Face, tolerance: Double = 1e-6) -> Shape?
```

The result is a `Shape` containing intersection edges (or a compound thereof). Returns `nil` if the faces do not intersect or construction fails.

- **Parameters:** `other` — the second face; `tolerance` — fuzzy intersection tolerance (default 1e-6).
- **Returns:** A `Shape` containing the intersection curves, or `nil` if there is no intersection.
- **OCCT:** `BRepAlgoAPI_Section` — `Approximation(true)`, `ComputePCurveOn1(true)`, `ComputePCurveOn2(true)`, `SetFuzzyValue(tolerance)`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  let faces = box.faces()
  if faces.count >= 2,
     let seam = faces[0].intersection(with: faces[1]) {
      // seam contains the shared edge geometry
  }
  ```

---

## Shape Extension — Face Analysis

These methods are declared as extensions on `Shape` and operate on the face sub-shapes of a solid.

---

### `Shape.faces()`

Returns all face sub-shapes of the solid as typed `Face` objects.

```swift
public func faces() -> [Face]
```

Each returned `Face` carries its ordinal `index` within the traversal order. Returns an empty array if the shape has no faces or `TopExp_Explorer` fails.

- **OCCT:** `TopExp_Explorer(shape, TopAbs_FACE)` — iterates all `TopoDS_Face` sub-shapes.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  let faces = box.faces()
  #expect(faces.count == 6)
  ```

---

### `Shape.horizontalFaces(tolerance:)`

Returns the subset of faces whose normals point up or down.

```swift
public func horizontalFaces(tolerance: Double = 0.01) -> [Face]
```

Pure-Swift filter over `faces()` using `Face.isHorizontal(tolerance:)`.

- **Parameters:** `tolerance` — angle tolerance in radians (default ~0.57°).
- **Returns:** Faces with normals within `tolerance` of the ±Z axis.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 5)!
  let h = box.horizontalFaces()
  #expect(h.count == 2)
  ```

---

### `Shape.upwardFaces(tolerance:)`

Returns the subset of faces whose normals point upward (positive Z).

```swift
public func upwardFaces(tolerance: Double = 0.01) -> [Face]
```

Pure-Swift filter over `faces()` using `Face.isUpwardFacing(tolerance:)`. Useful for identifying pocket floors and platform surfaces in CAM.

- **Parameters:** `tolerance` — angle tolerance in radians (default ~0.57°).
- **Returns:** Upward-facing horizontal faces.
- **Example:**
  ```swift
  let pocketFloors = myPart.upwardFaces()
  for face in pocketFloors {
      print(face.zLevel ?? "non-planar")
  }
  ```

---

### `Shape.facesByZLevel(tolerance:)`

Groups horizontal faces by their Z height.

```swift
public func facesByZLevel(tolerance: Double = 0.01) -> [Double: [Face]]
```

Calls `horizontalFaces()`, then groups faces whose `zLevel` values are within `tolerance` of each other. Designed for CAM pocket detection and layer-by-layer machining analysis.

- **Parameters:** `tolerance` — Z grouping tolerance; faces within this Z distance are placed in the same group.
- **Returns:** Dictionary mapping representative Z values to arrays of horizontal faces at that level.
- **Note:** Only planar horizontal faces (those with a non-nil `zLevel`) are included; non-planar horizontal faces are silently dropped.
- **Example:**
  ```swift
  let stepped = Shape.box(width: 10, height: 10, depth: 5)! // simplified
  let byZ = stepped.facesByZLevel()
  for (z, faces) in byZ.sorted(by: { $0.key < $1.key }) {
      print("Z=\(z): \(faces.count) face(s)")
  }
  ```

---

## BRepGProp\_Face Evaluation (v0.45.0)

### `GPropEvaluation`

Result of evaluating a face at UV parameters using `BRepGProp_Face`.

```swift
public struct GPropEvaluation: Sendable {
    public let point: SIMD3<Double>
    public let normal: SIMD3<Double>
}
```

- `point` — 3D point on the surface at `(u, v)`.
- `normal` — unnormalized surface normal (`dS/du × dS/dv`). The magnitude equals the local area element (Jacobian determinant), making it suitable for numerical surface integration.

---

### `naturalBounds`

The natural parametric bounds of the face using `BRepGProp_Face`.

```swift
public var naturalBounds: (uMin: Double, uMax: Double, vMin: Double, vMax: Double)? { get }
```

Unlike `uvBounds` (which uses `BRepTools::UVBounds`), this uses `BRepGProp_Face::Bounds`, which accounts for face orientation and returns integration-ready bounds.

- **Returns:** UV bounds, or `nil` on error.
- **OCCT:** `BRepGProp_Face::Bounds`.
- **Example:**
  ```swift
  if let nb = face.naturalBounds {
      let eval = face.evaluateGProp(u: (nb.uMin + nb.uMax) / 2,
                                    v: (nb.vMin + nb.vMax) / 2)
  }
  ```

---

### `evaluateGProp(u:v:)`

Evaluates the face surface at UV parameters via `BRepGProp_Face`, returning both the 3D point and the unnormalized surface normal.

```swift
public func evaluateGProp(u: Double, v: Double) -> GPropEvaluation?
```

The returned `normal` is the cross product `dS/du × dS/dv` whose magnitude equals the local surface area element. Use this for surface integration (e.g. computing area, flux integrals) rather than for visual normal shading (use `normal(atU:v:)` for unit normals).

- **Parameters:** `u` — U parameter; `v` — V parameter.
- **Returns:** `GPropEvaluation` with point and unnormalized normal, or `nil` on error.
- **OCCT:** `BRepGProp_Face::Normal(u, v, point, normal)`.
- **Example:**
  ```swift
  if let nb = face.naturalBounds,
     let eval = face.evaluateGProp(u: (nb.uMin + nb.uMax) / 2,
                                   v: (nb.vMin + nb.vMax) / 2) {
      let areaElement = simd_length(eval.normal)  // Jacobian at this UV point
      print(eval.point, eval.normal, areaElement)
  }
  ```
- **Note:** The `normal` field is NOT a unit vector — its magnitude carries the area element. Call `.normalized` on it only if you need the direction without the scaling factor.
