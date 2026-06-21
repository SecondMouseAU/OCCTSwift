---
title: 2D Geometry Primitives
parent: API Reference
---

# 2D Geometry Primitives

OCCTSwift exposes four lightweight types for 2D geometric computation: `Point2D` (a managed `Geom2d_CartesianPoint`), `Transform2D` (a `Geom2d_Transformation`), `AxisPlacement2D` (a `Geom2d_AxisPlacement`), and `ShapeAxis` (a value-typed struct describing an axis extracted from a face or solid). Together they support point arithmetic, transformation pipelines, axis-placement queries, and symmetry/revolution-axis detection.

## Topics

- [Point2D](#point2d) · [Transform2D](#transform2d) · [ShapeAxis](#shapeaxis) · [AxisPlacement2D](#axisplacement2d)

---

## Point2D

A 2D geometric point backed by `Geom2d_CartesianPoint`. Supports creation, coordinate access, mutation, distance queries, and returning transformed copies.

---

### Creation

---

#### `Point2D.init?(x:y:)`

Creates a 2D point at the given coordinates.

```swift
public init?(x: Double, y: Double)
```

- **Parameters:** `x` — X coordinate; `y` — Y coordinate.
- **Returns:** `nil` if the underlying OCCT allocation fails.
- **OCCT:** `Geom2d_CartesianPoint(x, y)`.
- **Example:**
  ```swift
  if let p = Point2D(x: 3.0, y: 4.0) {
      print(p.x, p.y)  // 3.0, 4.0
  }
  ```

---

#### `Point2D.init?(position:)`

Creates a 2D point from a `SIMD2<Double>` vector.

```swift
public convenience init?(position: SIMD2<Double>)
```

Delegates to `init(x:y:)` using the vector's components.

- **Parameters:** `position` — 2D coordinate vector.
- **Returns:** `nil` if allocation fails.
- **OCCT:** `Geom2d_CartesianPoint(position.x, position.y)`.
- **Example:**
  ```swift
  let p = Point2D(position: SIMD2(1.0, 2.0))
  ```

---

#### `Point2D.init?(_ coords:)`

Creates a 2D point from a `SIMD2<Double>` vector (convenience alias).

```swift
public convenience init?(_ coords: SIMD2<Double>)
```

Equivalent to `init(position:)`.

- **Parameters:** `coords` — 2D coordinate vector.
- **Returns:** `nil` if allocation fails.
- **Example:**
  ```swift
  let p = Point2D(SIMD2(5.0, 0.0))
  ```

---

### Properties

---

#### `x`

The X coordinate.

```swift
public var x: Double { get }
```

- **OCCT:** `Geom2d_CartesianPoint::X()`.
- **Example:**
  ```swift
  let p = Point2D(x: 3.0, y: 4.0)!
  print(p.x)  // 3.0
  ```

---

#### `y`

The Y coordinate.

```swift
public var y: Double { get }
```

- **OCCT:** `Geom2d_CartesianPoint::Y()`.
- **Example:**
  ```swift
  let p = Point2D(x: 3.0, y: 4.0)!
  print(p.y)  // 4.0
  ```

---

#### `coords`

The coordinates as a `SIMD2<Double>` vector.

```swift
public var coords: SIMD2<Double> { get }
```

Pure-Swift: returns `SIMD2(x, y)`.

- **Example:**
  ```swift
  let p = Point2D(x: 1.0, y: 2.0)!
  let v: SIMD2<Double> = p.coords  // SIMD2(1.0, 2.0)
  ```

---

#### `position`

The position as a `SIMD2<Double>` vector (alias for `coords`).

```swift
public var position: SIMD2<Double> { get }
```

Pure-Swift: returns `SIMD2(x, y)`. Identical to `coords`.

- **Example:**
  ```swift
  let p = Point2D(x: 1.0, y: 2.0)!
  let v = p.position  // SIMD2(1.0, 2.0)
  ```

---

### Mutation

---

#### `setCoords(x:y:)`

Sets both coordinates in place.

```swift
public func setCoords(x: Double, y: Double)
```

Mutates this point's underlying `Geom2d_CartesianPoint`.

- **Parameters:** `x` — new X coordinate; `y` — new Y coordinate.
- **OCCT:** `Geom2d_CartesianPoint::SetCoord(x, y)`.
- **Example:**
  ```swift
  let p = Point2D(x: 0.0, y: 0.0)!
  p.setCoords(x: 5.0, y: 10.0)
  print(p.x, p.y)  // 5.0, 10.0
  ```

---

### Distance

---

#### `distance(to:)` — point overload

Euclidean distance to another `Point2D`.

```swift
public func distance(to other: Point2D) -> Double
```

- **Parameters:** `other` — the other 2D point.
- **Returns:** Euclidean distance.
- **OCCT:** `Geom2d_CartesianPoint::Distance(other->point)`.
- **Example:**
  ```swift
  let a = Point2D(x: 0.0, y: 0.0)!
  let b = Point2D(x: 3.0, y: 4.0)!
  print(a.distance(to: b))  // 5.0
  ```

---

#### `squareDistance(to:)`

Squared Euclidean distance to another `Point2D` (avoids `sqrt`).

```swift
public func squareDistance(to other: Point2D) -> Double
```

- **Parameters:** `other` — the other 2D point.
- **Returns:** Squared Euclidean distance.
- **OCCT:** `Geom2d_CartesianPoint::SquareDistance(other->point)`.
- **Example:**
  ```swift
  let a = Point2D(x: 0.0, y: 0.0)!
  let b = Point2D(x: 3.0, y: 4.0)!
  print(a.squareDistance(to: b))  // 25.0
  ```

---

#### `distance(to:)` — curve overload

Minimum distance from this point to a 2D curve.

```swift
public func distance(to curve: Curve2D) -> Double
```

Returns `-1.0` if the projection fails or the curve has no projection points.

- **Parameters:** `curve` — the 2D curve to measure against.
- **Returns:** Minimum distance, or `-1.0` on failure.
- **OCCT:** `Geom2dAPI_ProjectPointOnCurve::LowerDistance()`.
- **Example:**
  ```swift
  if let p = Point2D(x: 5.0, y: 5.0),
     let arc = Curve2D.arc(center: SIMD2(0, 0), radius: 3, startAngle: 0, endAngle: .pi) {
      let d = p.distance(to: arc)  // distance to nearest point on arc
  }
  ```

---

### Transforms (return new Point2D)

All transform methods return new `Point2D` instances; the receiver is unchanged.

---

#### `translated(dx:dy:)`

Translates by `(dx, dy)`, returning a new point.

```swift
public func translated(dx: Double, dy: Double) -> Point2D?
```

- **Parameters:** `dx` — X offset; `dy` — Y offset.
- **Returns:** Translated copy, or `nil` on failure.
- **OCCT:** `gp_Trsf2d::SetTranslation` + `Geom2d_Geometry::Transformed`.
- **Example:**
  ```swift
  let p = Point2D(x: 1.0, y: 2.0)!
  if let q = p.translated(dx: 3.0, dy: -1.0) {
      print(q.x, q.y)  // 4.0, 1.0
  }
  ```

---

#### `rotated(center:angle:)`

Rotates around a centre point by an angle in radians, returning a new point.

```swift
public func rotated(center: SIMD2<Double>, angle: Double) -> Point2D?
```

- **Parameters:** `center` — centre of rotation; `angle` — rotation angle in radians (counter-clockwise positive).
- **Returns:** Rotated copy, or `nil` on failure.
- **OCCT:** `gp_Trsf2d::SetRotation` + `Geom2d_Geometry::Transformed`.
- **Example:**
  ```swift
  let p = Point2D(x: 1.0, y: 0.0)!
  if let q = p.rotated(center: .zero, angle: .pi / 2) {
      // q ≈ (0, 1)
  }
  ```

---

#### `scaled(center:factor:)`

Scales from a centre point by a factor, returning a new point.

```swift
public func scaled(center: SIMD2<Double>, factor: Double) -> Point2D?
```

- **Parameters:** `center` — centre of scaling; `factor` — uniform scale factor.
- **Returns:** Scaled copy, or `nil` on failure.
- **OCCT:** `gp_Trsf2d::SetScale` + `Geom2d_Geometry::Transformed`.
- **Example:**
  ```swift
  let p = Point2D(x: 2.0, y: 4.0)!
  if let q = p.scaled(center: .zero, factor: 0.5) {
      print(q.x, q.y)  // 1.0, 2.0
  }
  ```

---

#### `mirrored(point:)`

Mirrors across a point, returning a new point.

```swift
public func mirrored(point: SIMD2<Double>) -> Point2D?
```

- **Parameters:** `point` — the mirror point (centre of symmetry).
- **Returns:** Mirrored copy, or `nil` on failure.
- **OCCT:** `gp_Trsf2d::SetMirror(gp_Pnt2d)` + `Geom2d_Geometry::Transformed`.
- **Example:**
  ```swift
  let p = Point2D(x: 3.0, y: 0.0)!
  if let q = p.mirrored(point: SIMD2(0.0, 0.0)) {
      print(q.x, q.y)  // -3.0, 0.0
  }
  ```

---

#### `mirrored(axisOrigin:axisDirection:)`

Mirrors across an axis defined by origin and direction, returning a new point.

```swift
public func mirrored(axisOrigin: SIMD2<Double>, axisDirection: SIMD2<Double>) -> Point2D?
```

- **Parameters:** `axisOrigin` — a point on the mirror axis; `axisDirection` — the direction of the axis (need not be normalised).
- **Returns:** Mirrored copy, or `nil` on failure.
- **OCCT:** `gp_Trsf2d::SetMirror(gp_Ax2d)` + `Geom2d_Geometry::Transformed`.
- **Example:**
  ```swift
  let p = Point2D(x: 3.0, y: 2.0)!
  // Mirror across the Y-axis (origin=0,0 direction=0,1)
  if let q = p.mirrored(axisOrigin: .zero, axisDirection: SIMD2(0, 1)) {
      print(q.x, q.y)  // -3.0, 2.0
  }
  ```

---

#### `translated(by:)`

Translates by a `SIMD2<Double>` vector, returning a new point.

```swift
public func translated(by delta: SIMD2<Double>) -> Point2D?
```

Pure-Swift convenience: delegates to `translated(dx:dy:)`.

- **Parameters:** `delta` — 2D translation vector.
- **Returns:** Translated copy, or `nil` on failure.
- **Example:**
  ```swift
  let p = Point2D(x: 1.0, y: 1.0)!
  if let q = p.translated(by: SIMD2(2.0, 3.0)) {
      print(q.x, q.y)  // 3.0, 4.0
  }
  ```

---

#### `transformed(by:)`

Applies a `Transform2D` to this point, returning a new point.

```swift
public func transformed(by transform: Transform2D) -> Point2D?
```

- **Parameters:** `transform` — the 2D transformation to apply.
- **Returns:** Transformed copy, or `nil` on failure.
- **OCCT:** `Geom2d_Geometry::Transformed(trsf->Trsf2d())` → downcast to `Geom2d_CartesianPoint`.
- **Example:**
  ```swift
  if let t = Transform2D.rotation(center: .zero, angle: .pi),
     let p = Point2D(x: 1.0, y: 0.0),
     let q = p.transformed(by: t) {
      // q ≈ (-1, 0)
  }
  ```

---

## Transform2D

A 2D geometric transformation backed by `Geom2d_Transformation`. Supports translation, rotation, uniform scaling, point/axis mirroring, composition, inversion, and power operations.

---

### Factory Methods

---

#### `Transform2D.identity()`

Creates an identity transformation.

```swift
public static func identity() -> Transform2D?
```

- **Returns:** An identity `Transform2D`, or `nil` if allocation fails.
- **OCCT:** `Geom2d_Transformation()` (default constructor produces identity).
- **Example:**
  ```swift
  if let t = Transform2D.identity() {
      let p = SIMD2<Double>(3.0, 4.0)
      print(t.apply(to: p))  // SIMD2(3.0, 4.0)
  }
  ```

---

#### `Transform2D.translation(dx:dy:)`

Creates a translation by `(dx, dy)`.

```swift
public static func translation(dx: Double, dy: Double) -> Transform2D?
```

- **Parameters:** `dx` — X displacement; `dy` — Y displacement.
- **Returns:** Translation transform, or `nil` on failure.
- **OCCT:** `gp_Trsf2d::SetTranslation(gp_Vec2d(dx, dy))` → `Geom2d_Transformation`.
- **Example:**
  ```swift
  if let t = Transform2D.translation(dx: 5.0, dy: -2.0) {
      let q = t.apply(to: SIMD2(1.0, 1.0))  // SIMD2(6.0, -1.0)
  }
  ```

---

#### `Transform2D.rotation(center:angle:)`

Creates a rotation around a centre point by an angle in radians.

```swift
public static func rotation(center: SIMD2<Double>, angle: Double) -> Transform2D?
```

- **Parameters:** `center` — centre of rotation; `angle` — angle in radians (counter-clockwise positive).
- **Returns:** Rotation transform, or `nil` on failure.
- **OCCT:** `gp_Trsf2d::SetRotation(gp_Pnt2d, angle)` → `Geom2d_Transformation`.
- **Example:**
  ```swift
  if let t = Transform2D.rotation(center: .zero, angle: .pi / 4) {
      let q = t.apply(to: SIMD2(1.0, 0.0))
      // q ≈ (cos45°, sin45°)
  }
  ```

---

#### `Transform2D.scale(center:factor:)`

Creates a uniform scale from a centre point.

```swift
public static func scale(center: SIMD2<Double>, factor: Double) -> Transform2D?
```

- **Parameters:** `center` — fixed point of the scaling; `factor` — uniform scale factor.
- **Returns:** Scale transform, or `nil` on failure.
- **OCCT:** `gp_Trsf2d::SetScale(gp_Pnt2d, factor)` → `Geom2d_Transformation`.
- **Example:**
  ```swift
  if let t = Transform2D.scale(center: .zero, factor: 2.0) {
      let q = t.apply(to: SIMD2(3.0, 1.5))  // SIMD2(6.0, 3.0)
  }
  ```

---

#### `Transform2D.mirrorPoint(_:)`

Creates a mirror about a point (central symmetry).

```swift
public static func mirrorPoint(_ point: SIMD2<Double>) -> Transform2D?
```

- **Parameters:** `point` — the centre of symmetry.
- **Returns:** Point-mirror transform, or `nil` on failure.
- **OCCT:** `gp_Trsf2d::SetMirror(gp_Pnt2d)` → `Geom2d_Transformation`.
- **Example:**
  ```swift
  if let t = Transform2D.mirrorPoint(SIMD2(0.0, 0.0)) {
      let q = t.apply(to: SIMD2(3.0, 2.0))  // SIMD2(-3.0, -2.0)
  }
  ```

---

#### `Transform2D.mirrorAxis(origin:direction:)`

Creates a mirror about an axis defined by origin and direction.

```swift
public static func mirrorAxis(origin: SIMD2<Double>, direction: SIMD2<Double>) -> Transform2D?
```

- **Parameters:** `origin` — a point on the mirror axis; `direction` — the axis direction.
- **Returns:** Axis-mirror transform, or `nil` on failure.
- **OCCT:** `gp_Trsf2d::SetMirror(gp_Ax2d)` → `Geom2d_Transformation`.
- **Example:**
  ```swift
  // Mirror across the X-axis
  if let t = Transform2D.mirrorAxis(origin: .zero, direction: SIMD2(1, 0)) {
      let q = t.apply(to: SIMD2(2.0, 3.0))  // SIMD2(2.0, -3.0)
  }
  ```

---

### Properties

---

#### `scaleFactor`

The scale factor of this transformation.

```swift
public var scaleFactor: Double { get }
```

Returns `1.0` for rigid transformations (translation, rotation, mirroring), negative values for reflections with scaling.

- **OCCT:** `Geom2d_Transformation::ScaleFactor()`.
- **Example:**
  ```swift
  let t = Transform2D.scale(center: .zero, factor: 3.0)!
  print(t.scaleFactor)  // 3.0
  ```

---

#### `isNegative`

Whether this transformation involves a reflection (negative determinant).

```swift
public var isNegative: Bool { get }
```

`true` for mirrors and other orientation-reversing transformations.

- **OCCT:** `Geom2d_Transformation::IsNegative()`.
- **Example:**
  ```swift
  let t = Transform2D.mirrorAxis(origin: .zero, direction: SIMD2(1, 0))!
  print(t.isNegative)  // true
  ```

---

#### `matrixValues`

The 2×3 matrix values of this transformation.

```swift
public var matrixValues: (a11: Double, a12: Double, a13: Double,
                          a21: Double, a22: Double, a23: Double) { get }
```

The transformation maps `(x, y)` to `(a11·x + a12·y + a13, a21·x + a22·y + a23)`.

- **OCCT:** `Geom2d_Transformation::Value(row, col)` for rows 1–2, cols 1–3.
- **Example:**
  ```swift
  let t = Transform2D.translation(dx: 5.0, dy: 3.0)!
  let m = t.matrixValues
  // m.a11=1, m.a12=0, m.a13=5, m.a21=0, m.a22=1, m.a23=3
  ```

---

### Composition

---

#### `inverted()`

Returns the inverse of this transformation.

```swift
public func inverted() -> Transform2D?
```

- **Returns:** Inverse transform, or `nil` if the transformation is not invertible or allocation fails.
- **OCCT:** `Geom2d_Transformation::Inverted()`.
- **Example:**
  ```swift
  if let t = Transform2D.translation(dx: 5.0, dy: 3.0),
     let inv = t.inverted() {
      let q = inv.apply(to: SIMD2(6.0, 4.0))  // SIMD2(1.0, 1.0)
  }
  ```

---

#### `composed(with:)`

Composes this transformation with another: `self * other`.

```swift
public func composed(with other: Transform2D) -> Transform2D?
```

Applies `other` first, then `self`.

- **Parameters:** `other` — the second transformation.
- **Returns:** Composed transform, or `nil` on failure.
- **OCCT:** `Geom2d_Transformation::Multiplied(other)`.
- **Example:**
  ```swift
  if let rot = Transform2D.rotation(center: .zero, angle: .pi / 2),
     let trans = Transform2D.translation(dx: 1.0, dy: 0.0),
     let combined = rot.composed(with: trans) {
      // Applies trans first, then rot
      let q = combined.apply(to: SIMD2(0.0, 0.0))
  }
  ```

---

#### `powered(_:)`

Raises this transformation to the `n`-th power.

```swift
public func powered(_ n: Int32) -> Transform2D?
```

`n = 0` gives identity; negative `n` gives the inverse raised to `|n|`.

- **Parameters:** `n` — integer exponent.
- **Returns:** Composed transform, or `nil` on failure.
- **OCCT:** `Geom2d_Transformation::Powered(n)`.
- **Example:**
  ```swift
  // 90° rotation applied 4 times = identity
  if let rot = Transform2D.rotation(center: .zero, angle: .pi / 2),
     let full = rot.powered(4) {
      let q = full.apply(to: SIMD2(1.0, 0.0))  // ≈ (1.0, 0.0)
  }
  ```

---

### Application

---

#### `apply(to:)` — point overload

Applies this transformation to a `SIMD2<Double>` coordinate, returning the result.

```swift
public func apply(to point: SIMD2<Double>) -> SIMD2<Double>
```

- **Parameters:** `point` — 2D coordinate to transform.
- **Returns:** Transformed coordinate.
- **OCCT:** `gp_Trsf2d::Transforms(x, y)` (in-place on copies of the components).
- **Example:**
  ```swift
  let t = Transform2D.translation(dx: 2.0, dy: 3.0)!
  let q = t.apply(to: SIMD2(0.0, 0.0))  // SIMD2(2.0, 3.0)
  ```

---

#### `apply(to:)` — curve overload

Applies this transformation to a `Curve2D`, returning a new transformed curve.

```swift
public func apply(to curve: Curve2D) -> Curve2D?
```

- **Parameters:** `curve` — the 2D curve to transform.
- **Returns:** A new `Curve2D` with the transformation applied, or `nil` if copying or transformation fails.
- **OCCT:** `Geom2d_Curve::Copy()` then `Geom2d_Curve::Transform(trsf->Trsf2d())`.
- **Example:**
  ```swift
  if let t = Transform2D.translation(dx: 10.0, dy: 0.0),
     let line = Curve2D.line(origin: SIMD2(0, 0), direction: SIMD2(1, 0)),
     let shifted = t.apply(to: line) {
      // shifted is a line offset by 10 in X
  }
  ```

---

## ShapeAxis

A value type representing an axis extracted from a face or solid — an origin/direction pair with an optional extent range and a surface-kind tag. Produced by `Face.primaryAxis`, `Shape.revolutionAxes`, and `Shape.symmetryAxes`. Also extended onto `Surface` as `torusAxis` and `revolutionAxis`.

---

### Stored Properties

---

#### `origin`

The 3D origin of the axis.

```swift
public let origin: SIMD3<Double>
```

- **Example:**
  ```swift
  let cyl = Shape.cylinder(radius: 5, height: 20)!
  if let axes = cyl.revolutionAxes().first {
      print(axes.origin)  // origin point of the cylinder's axis
  }
  ```

---

#### `direction`

The 3D unit direction vector of the axis.

```swift
public let direction: SIMD3<Double>
```

- **Example:**
  ```swift
  let cyl = Shape.cylinder(radius: 5, height: 20)!
  if let ax = cyl.revolutionAxes().first {
      print(ax.direction)  // (0, 0, 1) for a default cylinder
  }
  ```

---

#### `extent`

The optional parametric extent along the axis.

```swift
public let extent: ClosedRange<Double>?
```

`nil` for axes where no extent is computed (most face types). When present, the range describes the axis length limits in the surface's own parameterisation.

- **Example:**
  ```swift
  let ax = Shape.cylinder(radius: 5, height: 20)!.revolutionAxes().first
  print(ax?.extent as Any)  // nil for revolution axes
  ```

---

#### `kind`

The surface kind that produced this axis.

```swift
public let kind: Kind
```

See `Kind` below.

---

#### `Kind`

Identifies the OCCT surface type that produced the axis.

```swift
public enum Kind: Int32, Sendable, Hashable {
    case cylinder   = 1
    case cone       = 2
    case sphere     = 3
    case torus      = 4
    case revolution = 5
    case extrusion  = 6
    case symmetry   = 7
}
```

- `.cylinder` — extracted from `GeomAbs_Cylinder` via `BRepAdaptor_Surface::Cylinder().Axis()`.
- `.cone` — extracted from `GeomAbs_Cone` via `BRepAdaptor_Surface::Cone().Axis()`.
- `.sphere` — extracted from `GeomAbs_Sphere` via `gp_Sphere::Location()` + `Position().Direction()`.
- `.torus` — extracted from `GeomAbs_Torus` via `BRepAdaptor_Surface::Torus().Axis()`.
- `.revolution` — extracted from `Geom_SurfaceOfRevolution::Axis()`.
- `.extrusion` — extracted from `Geom_SurfaceOfLinearExtrusion::Direction()`.
- `.symmetry` — derived from principal moments of inertia via `GProp_PrincipalProps`.

---

### Initializer

---

#### `ShapeAxis.init(origin:direction:extent:kind:)`

Creates a `ShapeAxis` with explicit values.

```swift
public init(origin: SIMD3<Double>, direction: SIMD3<Double>,
            extent: ClosedRange<Double>? = nil, kind: Kind)
```

Typically you receive `ShapeAxis` values from bridge queries rather than constructing them directly.

- **Parameters:** `origin` — axis origin; `direction` — axis direction; `extent` — optional parametric range (default `nil`); `kind` — surface kind tag.
- **Example:**
  ```swift
  let ax = ShapeAxis(origin: .zero, direction: SIMD3(0, 0, 1),
                     extent: nil, kind: .cylinder)
  ```

---

### Extension on Face

---

#### `Face.primaryAxis`

The primary axis of the face's underlying surface, if it has one.

```swift
public var primaryAxis: ShapeAxis? { get }
```

Cylindrical, conical, spherical, toroidal, surface-of-revolution, and surface-of-extrusion faces all have a canonical axis. Planes and free-form Bezier/B-spline faces return `nil`.

- **Returns:** A `ShapeAxis` describing the surface's canonical axis, or `nil` if the face has no such axis or the query fails.
- **OCCT:** `BRepAdaptor_Surface::GetType()` → per-type axis extraction (`Cylinder().Axis()`, `Cone().Axis()`, etc.).
- **Example:**
  ```swift
  let cyl = Shape.cylinder(radius: 5, height: 10)!
  for face in cyl.faces() {
      if let ax = face.primaryAxis {
          print(ax.kind, ax.origin, ax.direction)
      }
  }
  ```

---

### Extension on Shape

---

#### `Shape.revolutionAxes(tolerance:)`

All distinct axes of revolution present in the shape.

```swift
public func revolutionAxes(tolerance: Double = 1e-6) -> [ShapeAxis]
```

Explores all `TopoDS_Face` sub-shapes; collects axes from cylindrical, conical, spherical, toroidal, and surface-of-revolution faces. Deduplicates axes that coincide within `tolerance`.

- **Parameters:** `tolerance` — spatial tolerance for deduplication (default 1e-6).
- **Returns:** Array of deduplicated `ShapeAxis` values (kinds `.cylinder`, `.cone`, `.sphere`, `.torus`, `.revolution`), or empty on error.
- **OCCT:** `TopExp_Explorer(shape, TopAbs_FACE)` + per-type `BRepAdaptor_Surface` extraction.
- **Example:**
  ```swift
  let assembly = Shape.cylinder(radius: 5, height: 20)!
  let axes = assembly.revolutionAxes()
  print(axes.count)  // 1 for a simple cylinder
  ```

---

#### `Shape.symmetryAxes(fractionalTolerance:)`

Symmetry axes derived from the principal moments of inertia.

```swift
public func symmetryAxes(fractionalTolerance: Double = 1e-4) -> [ShapeAxis]
```

Returns one axis for a body with rotational symmetry (two equal principal moments), three axes for spherical symmetry (all three equal), and an empty array otherwise.

- **Parameters:** `fractionalTolerance` — two moments are considered equal when their absolute difference is below this fraction of the largest moment.
- **Returns:** Array of `ShapeAxis` values with `.kind == .symmetry`, or empty if no symmetry is detected.
- **OCCT:** `BRepGProp::VolumeProperties` + `GProp_GProps::PrincipalProperties()` → `GProp_PrincipalProps::HasSymmetryAxis()` / `HasSymmetryPoint()`.
- **Example:**
  ```swift
  let sphere = Shape.sphere(radius: 5)!
  let axes = sphere.symmetryAxes()
  print(axes.count)  // 3 (spherical symmetry)
  ```

---

### Extension on Surface

---

#### `Surface.torusAxis`

Axis of a toroidal surface (origin + direction of the rotation axis).

```swift
public var torusAxis: (origin: SIMD3<Double>, direction: SIMD3<Double>)? { get }
```

Returns `nil` if the surface is not a torus.

- **Returns:** Tuple with axis origin and direction, or `nil` if `surfaceKind != .torus`.
- **OCCT:** `OCCTSurfaceTorusAxis` — reads `gp_Torus::Axis()` from the underlying `Geom_ToroidalSurface`.
- **Example:**
  ```swift
  let torus = Surface.torus(majorRadius: 10, minorRadius: 2)!
  if let ax = torus.torusAxis {
      print(ax.origin, ax.direction)
  }
  ```

---

#### `Surface.revolutionAxis`

Axis of a surface of revolution (origin + direction).

```swift
public var revolutionAxis: (origin: SIMD3<Double>, direction: SIMD3<Double>)? { get }
```

Returns `nil` if the surface is not a surface of revolution.

- **Returns:** Tuple with axis origin and direction, or `nil` if `surfaceKind != .surfaceOfRevolution`.
- **OCCT:** `OCCTSurfaceRevolutionAxis` — reads `Geom_SurfaceOfRevolution::Axis()`.
- **Example:**
  ```swift
  // Assuming revSurface is a Geom_SurfaceOfRevolution-backed Surface
  if let ax = revSurface.revolutionAxis {
      print(ax.origin, ax.direction)
  }
  ```

---

## AxisPlacement2D

A 2D axis placement backed by `Geom2d_AxisPlacement`. Represents a coordinate frame in the 2D plane defined by an origin point and a unit direction vector. Used as a local reference system for 2D geometry construction and measurement.

---

### Creation

---

#### `AxisPlacement2D.init?(origin:direction:)`

Creates a 2D axis placement from origin and direction.

```swift
public init?(origin: SIMD2<Double>, direction: SIMD2<Double>)
```

- **Parameters:** `origin` — the origin of the axis; `direction` — the direction of the axis (normalised internally to `gp_Dir2d`).
- **Returns:** `nil` if the direction vector is zero or allocation fails.
- **OCCT:** `Geom2d_AxisPlacement(gp_Pnt2d, gp_Dir2d)`.
- **Example:**
  ```swift
  if let ax = AxisPlacement2D(origin: SIMD2(0, 0), direction: SIMD2(1, 0)) {
      print(ax.origin, ax.direction)
  }
  ```

---

### Properties

---

#### `origin`

The origin of the axis.

```swift
public var origin: SIMD2<Double> { get }
```

- **OCCT:** `Geom2d_AxisPlacement::Location()` → X/Y components.
- **Example:**
  ```swift
  let ax = AxisPlacement2D(origin: SIMD2(3, 4), direction: SIMD2(1, 0))!
  print(ax.origin)  // SIMD2(3.0, 4.0)
  ```

---

#### `direction`

The direction of the axis.

```swift
public var direction: SIMD2<Double> { get }
```

The returned vector is always of unit length (normalised by `gp_Dir2d`).

- **OCCT:** `Geom2d_AxisPlacement::Direction()` → X/Y components.
- **Example:**
  ```swift
  let ax = AxisPlacement2D(origin: .zero, direction: SIMD2(3, 4))!
  // direction is normalised: approximately (0.6, 0.8)
  print(ax.direction)
  ```

---

### Operations

---

#### `reversed()`

Creates a reversed axis (opposite direction, same origin).

```swift
public func reversed() -> AxisPlacement2D?
```

- **Returns:** A new `AxisPlacement2D` with negated direction and the same origin, or `nil` on failure.
- **OCCT:** `Geom2d_AxisPlacement::Copy()` + `Geom2d_AxisPlacement::Reverse()`.
- **Example:**
  ```swift
  let ax = AxisPlacement2D(origin: .zero, direction: SIMD2(1, 0))!
  if let rev = ax.reversed() {
      print(rev.direction)  // SIMD2(-1.0, 0.0)
  }
  ```

---

#### `angle(to:)`

The angle between this axis and another, in radians.

```swift
public func angle(to other: AxisPlacement2D) -> Double
```

Returns the angle in the range [0, π].

- **Parameters:** `other` — the second axis placement.
- **Returns:** Angle in radians between the two direction vectors.
- **OCCT:** `Geom2d_AxisPlacement::Angle(other->axis)`.
- **Example:**
  ```swift
  let ax1 = AxisPlacement2D(origin: .zero, direction: SIMD2(1, 0))!
  let ax2 = AxisPlacement2D(origin: .zero, direction: SIMD2(0, 1))!
  print(ax1.angle(to: ax2))  // π/2 ≈ 1.5708
  ```
