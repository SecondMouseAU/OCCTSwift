---
title: Curve2D — Analytic Types
parent: API Reference
---

# Curve2D — Analytic Types

These members expose the type-specific properties of the five analytic 2D curve kinds (circle, ellipse, hyperbola, parabola, line) plus an offset-curve accessor, and provide B-spline/Bézier query and mutation methods; they are meaningful only when the underlying `Curve2D` wraps an OCCT object of the matching kind — accessing them on a mismatched type returns zero/nil/false silently. See the main `Curve2D` page for construction, evaluation, and general operations.

## Topics

- [BSpline Queries](#bspline-queries) · [Geom2d_Circle Properties](#geom2d_circle-properties-v01080) · [Geom2d_Ellipse Properties](#geom2d_ellipse-properties-v01080) · [Geom2d_Hyperbola Properties](#geom2d_hyperbola-properties-v01080) · [Geom2d_Parabola Properties](#geom2d_parabola-properties-v01080) · [Geom2d_Line Properties](#geom2d_line-properties-v01080) · [Geom2d_OffsetCurve Properties](#geom2d_offsetcurve-properties-v01080) · [Geom2d_BSplineCurve Deep Methods](#geom2d_bsplinecurve-deep-method-completion-v01250) · [Bezier 2D Completions](#bezier-2d-completions-v01260)

---

## BSpline Queries

### `poleCount`

The number of control points (poles), or `nil` if the curve is not a BSpline or Bézier.

```swift
public var poleCount: Int? { get }
```

- **Returns:** Pole count, or `nil` for non-spline curve kinds.
- **OCCT:** `Geom2d_BSplineCurve::NbPoles` / `Geom2d_BezierCurve::NbPoles`.
- **Example:**
  ```swift
  if let c = Curve2D.bspline(points: [.zero, SIMD2(1, 0), SIMD2(1, 1)]) {
      if let n = c.poleCount { /* n == 3 */ }
  }
  ```

---

### `poles`

The control points (poles) as an array, or `nil` if the curve is not a BSpline or Bézier.

```swift
public var poles: [SIMD2<Double>]? { get }
```

- **Returns:** Array of 2D pole coordinates in OCCT 1-based order (index 0 = pole 1), or `nil`.
- **OCCT:** `Geom2d_BSplineCurve::Pole(i)` / `Geom2d_BezierCurve::Pole(i)`.
- **Example:**
  ```swift
  if let pts = curve.poles {
      for p in pts { print(p) }
  }
  ```

---

### `degree`

The curve degree, or `nil` if the curve is not a BSpline or Bézier.

```swift
public var degree: Int? { get }
```

- **Returns:** Polynomial degree (≥ 1), or `nil` for non-spline kinds.
- **OCCT:** `Geom2d_BSplineCurve::Degree` / `Geom2d_BezierCurve::Degree`.
- **Example:**
  ```swift
  if let deg = curve.degree { /* typically 3 for cubic */ }
  ```

---

## Geom2d_Circle Properties (v0.108.0)

### `circleProperties`

Access 2D circle-specific properties. Meaningful only when the underlying curve is a `Geom2d_Circle`.

```swift
public var circleProperties: CircleProperties { get }
```

- **Returns:** A `CircleProperties` accessor backed by the same internal handle. Members return zero/false for non-circle curves.
- **OCCT:** `Geom2d_Circle` — accessed via `Handle(Geom2d_Circle)::DownCast`.
- **Example:**
  ```swift
  if let c = Curve2D.circle(center: .zero, radius: 5) {
      let props = c.circleProperties
  }
  ```

---

### `CircleProperties.radius`

The radius of the 2D circle.

```swift
public var radius: Double { get }
```

- **Returns:** Radius in model units, or `0` if the curve is not a circle.
- **OCCT:** `Geom2d_Circle::Radius`.
- **Example:**
  ```swift
  if let c = Curve2D.circle(center: .zero, radius: 5) {
      let r = c.circleProperties.radius  // 5.0
  }
  ```

---

### `CircleProperties.setRadius(_:)`

Mutates the circle's radius in place.

```swift
@discardableResult
public func setRadius(_ r: Double) -> Bool
```

- **Parameters:** `r` — new radius (must be > 0).
- **Returns:** `true` on success, `false` if the curve is not a circle or `r` is invalid.
- **OCCT:** `Geom2d_Circle::SetRadius`.
- **Example:**
  ```swift
  if let c = Curve2D.circle(center: .zero, radius: 5) {
      c.circleProperties.setRadius(8)
  }
  ```

---

### `CircleProperties.eccentricity`

The eccentricity of the circle (always `0.0`).

```swift
public var eccentricity: Double { get }
```

- **Returns:** `0.0` for a valid circle, or `0` if the curve is not a circle.
- **OCCT:** `Geom2d_Circle::Eccentricity`.
- **Example:**
  ```swift
  let e = c.circleProperties.eccentricity  // 0.0
  ```

---

### `CircleProperties.center`

The centre point of the circle.

```swift
public var center: SIMD2<Double> { get }
```

- **Returns:** Centre in model space, or `.zero` if the curve is not a circle.
- **OCCT:** `Geom2d_Circle::Circ2d().Location()`.
- **Example:**
  ```swift
  if let c = Curve2D.circle(center: SIMD2(1, 2), radius: 5) {
      let ctr = c.circleProperties.center  // SIMD2(1, 2)
  }
  ```

---

### `CircleProperties.xAxis`

The X axis of the circle's local coordinate system (position + direction).

```swift
public var xAxis: (position: SIMD2<Double>, direction: SIMD2<Double>) { get }
```

The position is a point on the axis; the direction is the unit X axis direction.

- **Returns:** Tuple `(position, direction)`. Returns `(.zero, .zero)` if the curve is not a circle.
- **OCCT:** `Geom2d_Circle::XAxis` → `gp_Ax2d::Location` + `gp_Ax2d::Direction`.
- **Example:**
  ```swift
  if let c = Curve2D.circle(center: .zero, radius: 5) {
      let ax = c.circleProperties.xAxis
      // ax.direction ≈ SIMD2(1, 0)
  }
  ```

---

## Geom2d_Ellipse Properties (v0.108.0)

### `ellipseProperties`

Access 2D ellipse-specific properties. Meaningful only when the underlying curve is a `Geom2d_Ellipse`.

```swift
public var ellipseProperties: EllipseProperties { get }
```

- **Returns:** An `EllipseProperties` accessor backed by the same internal handle.
- **OCCT:** `Geom2d_Ellipse` — accessed via `Handle(Geom2d_Ellipse)::DownCast`.
- **Example:**
  ```swift
  if let c = Curve2D.ellipse(majorRadius: 5, minorRadius: 3) {
      let props = c.ellipseProperties
  }
  ```

---

### `EllipseProperties.majorRadius`

The major (semi-major) radius of the ellipse.

```swift
public var majorRadius: Double { get }
```

- **Returns:** Major radius in model units, or `0` if the curve is not an ellipse.
- **OCCT:** `Geom2d_Ellipse::MajorRadius`.
- **Example:**
  ```swift
  let a = c.ellipseProperties.majorRadius
  ```

---

### `EllipseProperties.minorRadius`

The minor (semi-minor) radius of the ellipse.

```swift
public var minorRadius: Double { get }
```

- **Returns:** Minor radius in model units, or `0` if the curve is not an ellipse.
- **OCCT:** `Geom2d_Ellipse::MinorRadius`.
- **Example:**
  ```swift
  let b = c.ellipseProperties.minorRadius
  ```

---

### `EllipseProperties.setMajorRadius(_:)`

Mutates the ellipse's major radius in place.

```swift
@discardableResult
public func setMajorRadius(_ r: Double) -> Bool
```

- **Parameters:** `r` — new major radius (must be ≥ minor radius per OCCT).
- **Returns:** `true` on success, `false` if the curve is not an ellipse or the value is invalid.
- **OCCT:** `Geom2d_Ellipse::SetMajorRadius`.
- **Example:**
  ```swift
  c.ellipseProperties.setMajorRadius(10)
  ```

---

### `EllipseProperties.setMinorRadius(_:)`

Mutates the ellipse's minor radius in place.

```swift
@discardableResult
public func setMinorRadius(_ r: Double) -> Bool
```

- **Parameters:** `r` — new minor radius (must be ≤ major radius per OCCT).
- **Returns:** `true` on success, `false` if the curve is not an ellipse or the value is invalid.
- **OCCT:** `Geom2d_Ellipse::SetMinorRadius`.
- **Example:**
  ```swift
  c.ellipseProperties.setMinorRadius(2)
  ```

---

### `EllipseProperties.eccentricity`

The eccentricity of the ellipse (`√(1 − (b/a)²)`).

```swift
public var eccentricity: Double { get }
```

- **Returns:** Eccentricity in [0, 1), or `0` if the curve is not an ellipse.
- **OCCT:** `Geom2d_Ellipse::Eccentricity`.
- **Example:**
  ```swift
  let e = c.ellipseProperties.eccentricity
  ```

---

### `EllipseProperties.focal`

The focal distance of the ellipse (distance between the two foci).

```swift
public var focal: Double { get }
```

- **Returns:** Distance between foci (`2ae`), or `0` if the curve is not an ellipse.
- **OCCT:** `Geom2d_Ellipse::Focal`.
- **Example:**
  ```swift
  let f = c.ellipseProperties.focal
  ```

---

### `EllipseProperties.focus1`

The first focus of the ellipse.

```swift
public var focus1: SIMD2<Double> { get }
```

- **Returns:** First focus point in model space, or `.zero` if the curve is not an ellipse.
- **OCCT:** `Geom2d_Ellipse::Focus1`.
- **Example:**
  ```swift
  let f1 = c.ellipseProperties.focus1
  ```

---

## Geom2d_Hyperbola Properties (v0.108.0)

### `hyperbolaProperties`

Access 2D hyperbola-specific properties. Meaningful only when the underlying curve is a `Geom2d_Hyperbola`.

```swift
public var hyperbolaProperties: HyperbolaProperties { get }
```

- **Returns:** A `HyperbolaProperties` accessor backed by the same internal handle.
- **OCCT:** `Geom2d_Hyperbola` — accessed via `Handle(Geom2d_Hyperbola)::DownCast`.
- **Example:**
  ```swift
  if let c = Curve2D.hyperbola(majorRadius: 4, minorRadius: 3) {
      let props = c.hyperbolaProperties
  }
  ```

---

### `HyperbolaProperties.majorRadius`

The major radius of the hyperbola (real semi-axis).

```swift
public var majorRadius: Double { get }
```

- **Returns:** Major radius, or `0` if the curve is not a hyperbola.
- **OCCT:** `Geom2d_Hyperbola::MajorRadius`.
- **Example:**
  ```swift
  let a = c.hyperbolaProperties.majorRadius
  ```

---

### `HyperbolaProperties.minorRadius`

The minor radius of the hyperbola (imaginary semi-axis).

```swift
public var minorRadius: Double { get }
```

- **Returns:** Minor radius, or `0` if the curve is not a hyperbola.
- **OCCT:** `Geom2d_Hyperbola::MinorRadius`.
- **Example:**
  ```swift
  let b = c.hyperbolaProperties.minorRadius
  ```

---

### `HyperbolaProperties.eccentricity`

The eccentricity of the hyperbola (`√(1 + (b/a)²)`, always > 1).

```swift
public var eccentricity: Double { get }
```

- **Returns:** Eccentricity (> 1 for a valid hyperbola), or `0` if not a hyperbola.
- **OCCT:** `Geom2d_Hyperbola::Eccentricity`.
- **Example:**
  ```swift
  let e = c.hyperbolaProperties.eccentricity  // > 1.0
  ```

---

### `HyperbolaProperties.focal`

The focal distance of the hyperbola (distance between the two foci).

```swift
public var focal: Double { get }
```

- **Returns:** Distance between foci, or `0` if not a hyperbola.
- **OCCT:** `Geom2d_Hyperbola::Focal`.
- **Example:**
  ```swift
  let f = c.hyperbolaProperties.focal
  ```

---

### `HyperbolaProperties.focus1`

The first focus of the hyperbola.

```swift
public var focus1: SIMD2<Double> { get }
```

- **Returns:** First focus point, or `.zero` if not a hyperbola.
- **OCCT:** `Geom2d_Hyperbola::Focus1`.
- **Example:**
  ```swift
  let f1 = c.hyperbolaProperties.focus1
  ```

---

## Geom2d_Parabola Properties (v0.108.0)

### `parabolaProperties`

Access 2D parabola-specific properties. Meaningful only when the underlying curve is a `Geom2d_Parabola`.

```swift
public var parabolaProperties: ParabolaProperties { get }
```

- **Returns:** A `ParabolaProperties` accessor backed by the same internal handle.
- **OCCT:** `Geom2d_Parabola` — accessed via `Handle(Geom2d_Parabola)::DownCast`.
- **Example:**
  ```swift
  if let c = Curve2D.parabola(focal: 2) {
      let props = c.parabolaProperties
  }
  ```

---

### `ParabolaProperties.focal`

The focal distance of the parabola (distance from vertex to focus).

```swift
public var focal: Double { get }
```

- **Returns:** Focal distance, or `0` if the curve is not a parabola.
- **OCCT:** `Geom2d_Parabola::Focal`.
- **Example:**
  ```swift
  let f = c.parabolaProperties.focal
  ```

---

### `ParabolaProperties.setFocal(_:)`

Mutates the parabola's focal distance in place.

```swift
@discardableResult
public func setFocal(_ f: Double) -> Bool
```

- **Parameters:** `f` — new focal distance (must be > 0).
- **Returns:** `true` on success, `false` if the curve is not a parabola or `f` is invalid.
- **OCCT:** `Geom2d_Parabola::SetFocal`.
- **Example:**
  ```swift
  c.parabolaProperties.setFocal(3)
  ```

---

### `ParabolaProperties.focus`

The focus point of the parabola.

```swift
public var focus: SIMD2<Double> { get }
```

- **Returns:** Focus point in model space, or `.zero` if not a parabola.
- **OCCT:** `Geom2d_Parabola::Focus`.
- **Example:**
  ```swift
  let fp = c.parabolaProperties.focus
  ```

---

### `ParabolaProperties.eccentricity`

The eccentricity of the parabola (always `1.0`).

```swift
public var eccentricity: Double { get }
```

- **Returns:** `1.0` for a valid parabola, or `0` if not a parabola.
- **OCCT:** `Geom2d_Parabola::Eccentricity`.
- **Example:**
  ```swift
  let e = c.parabolaProperties.eccentricity  // 1.0
  ```

---

### `ParabolaProperties.parameter`

The parameter of the parabola (equal to `2 * focal`).

```swift
public var parameter: Double { get }
```

- **Returns:** `2 * focal`, or `0` if not a parabola.
- **OCCT:** `Geom2d_Parabola::Parameter`.
- **Example:**
  ```swift
  let p = c.parabolaProperties.parameter  // == 2 * focal
  ```

---

## Geom2d_Line Properties (v0.108.0)

### `lineProperties`

Access 2D line-specific properties. Meaningful only when the underlying curve is a `Geom2d_Line`.

```swift
public var lineProperties: LineProperties { get }
```

- **Returns:** A `LineProperties` accessor backed by the same internal handle.
- **OCCT:** `Geom2d_Line` — accessed via `Handle(Geom2d_Line)::DownCast`.
- **Example:**
  ```swift
  if let c = Curve2D.line(from: .zero, to: SIMD2(1, 0)) {
      let props = c.lineProperties
  }
  ```

---

### `LineProperties.direction`

The unit direction of the 2D line.

```swift
public var direction: SIMD2<Double> { get }
```

- **Returns:** Unit direction vector, or `.zero` if the curve is not a line.
- **OCCT:** `Geom2d_Line::Direction` (via `gp_Lin2d::Direction`).
- **Example:**
  ```swift
  let d = c.lineProperties.direction  // e.g. SIMD2(1, 0)
  ```

---

### `LineProperties.location`

The origin (location) of the 2D line.

```swift
public var location: SIMD2<Double> { get }
```

- **Returns:** A point on the line through which the parametric origin passes, or `.zero` if not a line.
- **OCCT:** `Geom2d_Line::Location` (via `gp_Lin2d::Location`).
- **Example:**
  ```swift
  let loc = c.lineProperties.location
  ```

---

### `LineProperties.setDirection(_:)`

Mutates the line's direction in place.

```swift
@discardableResult
public func setDirection(_ d: SIMD2<Double>) -> Bool
```

- **Parameters:** `d` — new direction (need not be unit; OCCT normalises it).
- **Returns:** `true` on success, `false` if the curve is not a line.
- **OCCT:** `Geom2d_Line::SetDirection`.
- **Example:**
  ```swift
  c.lineProperties.setDirection(SIMD2(0, 1))
  ```

---

### `LineProperties.setLocation(_:)`

Mutates the line's origin point in place.

```swift
@discardableResult
public func setLocation(_ p: SIMD2<Double>) -> Bool
```

- **Parameters:** `p` — new location point.
- **Returns:** `true` on success, `false` if the curve is not a line.
- **OCCT:** `Geom2d_Line::SetLocation`.
- **Example:**
  ```swift
  c.lineProperties.setLocation(SIMD2(1, 2))
  ```

---

### `LineProperties.distance(to:)`

The perpendicular distance from the line to a 2D point.

```swift
public func distance(to point: SIMD2<Double>) -> Double
```

- **Parameters:** `point` — the query point in model space.
- **Returns:** Perpendicular distance; `0` if the curve is not a line.
- **OCCT:** `Geom2d_Line::Distance` (via `gp_Lin2d::Distance`).
- **Example:**
  ```swift
  let d = c.lineProperties.distance(to: SIMD2(0, 3))
  ```

---

### `LineProperties.lin2d`

The `gp_Lin2d` representation of the line (location + direction).

```swift
public var lin2d: (location: SIMD2<Double>, direction: SIMD2<Double>) { get }
```

Retrieves both the origin point and direction in a single call.

- **Returns:** Tuple `(location, direction)`. Returns `(.zero, .zero)` if not a line.
- **OCCT:** `Geom2d_Line::Lin2d` → `gp_Lin2d::Location` + `gp_Lin2d::Direction`.
- **Example:**
  ```swift
  let lin = c.lineProperties.lin2d
  // lin.location, lin.direction
  ```

---

## Geom2d_OffsetCurve Properties (v0.108.0)

### `offsetProperties`

Access 2D offset-curve-specific properties. Meaningful only when the underlying curve is a `Geom2d_OffsetCurve`.

```swift
public var offsetProperties: OffsetProperties { get }
```

- **Returns:** An `OffsetProperties` accessor backed by the same internal handle.
- **OCCT:** `Geom2d_OffsetCurve` — accessed via `Handle(Geom2d_OffsetCurve)::DownCast`.
- **Example:**
  ```swift
  if let base = Curve2D.circle(center: .zero, radius: 5),
     let oc = base.offset(by: 1) {
      let props = oc.offsetProperties
  }
  ```

---

### `OffsetProperties.offset`

The signed offset value.

```swift
public var offset: Double { get }
```

Positive values offset to the left of the curve direction; negative to the right.

- **Returns:** Offset distance, or `0` if the curve is not an offset curve.
- **OCCT:** `Geom2d_OffsetCurve::Offset`.
- **Example:**
  ```swift
  let v = oc.offsetProperties.offset  // 1.0
  ```

---

### `OffsetProperties.setOffset(_:)`

Mutates the offset value in place.

```swift
@discardableResult
public func setOffset(_ v: Double) -> Bool
```

- **Parameters:** `v` — new offset distance.
- **Returns:** `true` on success, `false` if the curve is not an offset curve.
- **OCCT:** `Geom2d_OffsetCurve::SetOffsetValue`.
- **Example:**
  ```swift
  oc.offsetProperties.setOffset(2.0)
  ```

---

### `OffsetProperties.basisCurve`

The basis curve from which this offset curve was derived.

```swift
public var basisCurve: Curve2D? { get }
```

- **Returns:** The underlying `Curve2D`, or `nil` if the curve is not an offset curve or the basis handle is null.
- **OCCT:** `Geom2d_OffsetCurve::BasisCurve`.
- **Example:**
  ```swift
  if let basis = oc.offsetProperties.basisCurve {
      let r = basis.circleProperties.radius
  }
  ```

---

## Geom2d_BSplineCurve Deep Method Completion (v0.125.0)

### `bsplineLocalD0(u:fromK1:toK2:)`

Evaluates the curve position within a specific knot span.

```swift
public func bsplineLocalD0(u: Double, fromK1: Int, toK2: Int) -> SIMD2<Double>
```

- **Parameters:** `u` — parameter value; `fromK1`, `toK2` — knot span indices (1-based, obtained from `bsplineLocateU`).
- **Returns:** Point on the curve at `u` within the span. Returns `.zero` if not a BSpline.
- **OCCT:** `Geom2d_BSplineCurve::LocalD0`.
- **Example:**
  ```swift
  let (k1, k2) = curve.bsplineLocateU(u: 0.5, paramTol: 1e-7)
  let pt = curve.bsplineLocalD0(u: 0.5, fromK1: k1, toK2: k2)
  ```

---

### `bsplineLocalD1(u:fromK1:toK2:)`

Evaluates position and first derivative within a knot span.

```swift
public func bsplineLocalD1(u: Double, fromK1: Int, toK2: Int)
    -> (point: SIMD2<Double>, v1: SIMD2<Double>)
```

- **Parameters:** `u` — parameter; `fromK1`, `toK2` — knot span indices.
- **Returns:** Tuple `(point, v1)` where `v1` is the first derivative vector.
- **OCCT:** `Geom2d_BSplineCurve::LocalD1`.
- **Example:**
  ```swift
  let (k1, k2) = curve.bsplineLocateU(u: 0.5, paramTol: 1e-7)
  let r = curve.bsplineLocalD1(u: 0.5, fromK1: k1, toK2: k2)
  // r.point, r.v1
  ```

---

### `bsplineLocalD2(u:fromK1:toK2:)`

Evaluates position and first two derivatives within a knot span.

```swift
public func bsplineLocalD2(u: Double, fromK1: Int, toK2: Int)
    -> (point: SIMD2<Double>, v1: SIMD2<Double>, v2: SIMD2<Double>)
```

- **Parameters:** `u` — parameter; `fromK1`, `toK2` — knot span indices.
- **Returns:** Tuple `(point, v1, v2)`.
- **OCCT:** `Geom2d_BSplineCurve::LocalD2`.
- **Example:**
  ```swift
  let r = curve.bsplineLocalD2(u: 0.5, fromK1: k1, toK2: k2)
  ```

---

### `bsplineLocalD3(u:fromK1:toK2:)`

Evaluates position and first three derivatives within a knot span.

```swift
public func bsplineLocalD3(u: Double, fromK1: Int, toK2: Int)
    -> (point: SIMD2<Double>, v1: SIMD2<Double>, v2: SIMD2<Double>, v3: SIMD2<Double>)
```

- **Parameters:** `u` — parameter; `fromK1`, `toK2` — knot span indices.
- **Returns:** Tuple `(point, v1, v2, v3)`.
- **OCCT:** `Geom2d_BSplineCurve::LocalD3`.
- **Example:**
  ```swift
  let r = curve.bsplineLocalD3(u: 0.5, fromK1: k1, toK2: k2)
  ```

---

### `bsplineLocalDN(u:fromK1:toK2:n:)`

Evaluates the N-th derivative within a knot span.

```swift
public func bsplineLocalDN(u: Double, fromK1: Int, toK2: Int, n: Int) -> SIMD2<Double>
```

- **Parameters:** `u` — parameter; `fromK1`, `toK2` — span indices; `n` — derivative order.
- **Returns:** N-th derivative vector at `u` within the span.
- **OCCT:** `Geom2d_BSplineCurve::LocalDN`.
- **Example:**
  ```swift
  let d2 = curve.bsplineLocalDN(u: 0.5, fromK1: k1, toK2: k2, n: 2)
  ```

---

### `bsplineLocalValue(u:fromK1:toK2:)`

Evaluates only the curve value (no derivatives) within a knot span.

```swift
public func bsplineLocalValue(u: Double, fromK1: Int, toK2: Int) -> SIMD2<Double>
```

- **Parameters:** `u` — parameter; `fromK1`, `toK2` — span indices.
- **Returns:** Point on the curve.
- **OCCT:** `Geom2d_BSplineCurve::LocalValue`.
- **Example:**
  ```swift
  let pt = curve.bsplineLocalValue(u: 0.5, fromK1: k1, toK2: k2)
  ```

---

### `bsplineLocateU(u:paramTol:)`

Locates the knot span indices enclosing a parameter value.

```swift
public func bsplineLocateU(u: Double, paramTol: Double) -> (i1: Int, i2: Int)
```

- **Parameters:** `u` — parameter to locate; `paramTol` — tolerance for coincidence with a knot.
- **Returns:** Tuple `(i1, i2)` of 1-based knot indices bracketing `u`. Use as `fromK1`/`toK2` in local evaluation methods.
- **OCCT:** `Geom2d_BSplineCurve::LocateU`.
- **Example:**
  ```swift
  let (k1, k2) = curve.bsplineLocateU(u: 0.5, paramTol: 1e-7)
  ```

---

### `bsplineFirstUKnotIndex`

The index of the first knot (lower bound of the valid span range).

```swift
public var bsplineFirstUKnotIndex: Int { get }
```

- **Returns:** 1-based index of the first knot; `0` if not a BSpline.
- **OCCT:** `Geom2d_BSplineCurve::FirstUKnotIndex`.
- **Example:**
  ```swift
  let lo = curve.bsplineFirstUKnotIndex
  ```

---

### `bsplineLastUKnotIndex`

The index of the last knot (upper bound of the valid span range).

```swift
public var bsplineLastUKnotIndex: Int { get }
```

- **Returns:** 1-based index of the last knot; `0` if not a BSpline.
- **OCCT:** `Geom2d_BSplineCurve::LastUKnotIndex`.
- **Example:**
  ```swift
  let hi = curve.bsplineLastUKnotIndex
  ```

---

### `bsplineKnot(index:)`

Returns the knot value at a 1-based index.

```swift
public func bsplineKnot(index: Int) -> Double
```

- **Parameters:** `index` — 1-based knot index (valid range: `bsplineFirstUKnotIndex ... bsplineLastUKnotIndex`).
- **Returns:** Knot parameter value; `0` if not a BSpline or index is out of range.
- **OCCT:** `Geom2d_BSplineCurve::Knot`.
- **Example:**
  ```swift
  let k = curve.bsplineKnot(index: 2)
  ```

---

### `bsplineKnotDistribution`

The knot distribution type of the BSpline.

```swift
public var bsplineKnotDistribution: Int { get }
```

- **Returns:** Integer code: `0` = NonUniform, `1` = Uniform, `2` = QuasiUniform, `3` = PiecewiseBezier; `0` also if not a BSpline.
- **OCCT:** `Geom2d_BSplineCurve::KnotDistribution`.
- **Example:**
  ```swift
  let dist = curve.bsplineKnotDistribution
  ```

---

### `bsplineMultiplicity(index:)`

The knot multiplicity at a 1-based index.

```swift
public func bsplineMultiplicity(index: Int) -> Int
```

- **Parameters:** `index` — 1-based knot index.
- **Returns:** Multiplicity at the knot; `0` if not a BSpline or index is out of range.
- **OCCT:** `Geom2d_BSplineCurve::Multiplicity`.
- **Example:**
  ```swift
  let m = curve.bsplineMultiplicity(index: 1)
  ```

---

### `bsplineMultiplicities`

All knot multiplicities as an array.

```swift
public var bsplineMultiplicities: [Int] { get }
```

- **Returns:** Array of multiplicity values in knot order; empty if not a BSpline.
- **OCCT:** `Geom2d_BSplineCurve::Multiplicities` (via repeated `Multiplicity`).
- **Example:**
  ```swift
  let mults = curve.bsplineMultiplicities
  ```

---

### `bsplineStartPoint`

The start point of the BSpline (at first parameter).

```swift
public var bsplineStartPoint: SIMD2<Double> { get }
```

- **Returns:** Start point; `.zero` if not a BSpline.
- **OCCT:** `Geom2d_BSplineCurve::StartPoint`.
- **Example:**
  ```swift
  let s = curve.bsplineStartPoint
  ```

---

### `bsplineEndPoint`

The end point of the BSpline (at last parameter).

```swift
public var bsplineEndPoint: SIMD2<Double> { get }
```

- **Returns:** End point; `.zero` if not a BSpline.
- **OCCT:** `Geom2d_BSplineCurve::EndPoint`.
- **Example:**
  ```swift
  let e = curve.bsplineEndPoint
  ```

---

### `bsplinePoles`

All control points (poles) of the BSpline.

```swift
public var bsplinePoles: [SIMD2<Double>] { get }
```

Equivalent to iterating `Pole(i)` for `i` in 1...NbPoles. Prefer this over `poles` when you know the curve is a BSpline (avoids Bézier fallback).

- **Returns:** Array of poles in order; empty if not a BSpline.
- **OCCT:** `Geom2d_BSplineCurve::Pole(i)`.
- **Example:**
  ```swift
  for p in curve.bsplinePoles { print(p) }
  ```

---

### `bsplineIsClosed`

Whether the BSpline is closed (start and end poles coincide within tolerance).

```swift
public var bsplineIsClosed: Bool { get }
```

- **Returns:** `true` if closed; `false` if open or not a BSpline.
- **OCCT:** `Geom2d_BSplineCurve::IsClosed`.
- **Example:**
  ```swift
  if curve.bsplineIsClosed { /* closed loop */ }
  ```

---

### `bsplineIsPeriodic`

Whether the BSpline is periodic.

```swift
public var bsplineIsPeriodic: Bool { get }
```

- **Returns:** `true` if periodic; `false` otherwise.
- **OCCT:** `Geom2d_BSplineCurve::IsPeriodic`.
- **Example:**
  ```swift
  if curve.bsplineIsPeriodic { /* periodic */ }
  ```

---

### `bsplineContinuity`

The global geometric continuity of the BSpline.

```swift
public var bsplineContinuity: Int { get }
```

- **Returns:** Integer code: `0` = C0, `1` = C1, `2` = C2, `3` = C3, `4` = CN; `0` if not a BSpline.
- **OCCT:** `Geom2d_BSplineCurve::Continuity`.
- **Example:**
  ```swift
  let cont = curve.bsplineContinuity  // typically 2 (C2) for cubic B-splines
  ```

---

### `bsplineIsCN(_:)`

Tests whether the BSpline is at least C*n* continuous.

```swift
public func bsplineIsCN(_ n: Int) -> Bool
```

- **Parameters:** `n` — continuity order to test.
- **Returns:** `true` if the curve is at least C*n*; `false` otherwise or if not a BSpline.
- **OCCT:** `Geom2d_BSplineCurve::IsCN`.
- **Example:**
  ```swift
  if curve.bsplineIsCN(2) { /* C2 continuous */ }
  ```

---

## Bezier 2D Completions (v0.126.0)

### `bezierInsertPoleAfter(_:point:)`

Inserts a new pole after a given 1-based index in a 2D Bézier curve.

```swift
@discardableResult
public func bezierInsertPoleAfter(_ index: Int, point: SIMD2<Double>) -> Bool
```

- **Parameters:** `index` — 1-based index after which to insert; `point` — new pole coordinates.
- **Returns:** `true` on success, `false` if not a Bézier or `index` is out of range.
- **OCCT:** `Geom2d_BezierCurve::InsertPoleAfter`.
- **Example:**
  ```swift
  curve.bezierInsertPoleAfter(1, point: SIMD2(0.5, 0.5))
  ```

---

### `bezierRemovePole(_:)`

Removes the pole at a given 1-based index from a 2D Bézier curve.

```swift
@discardableResult
public func bezierRemovePole(_ index: Int) -> Bool
```

Removing a pole lowers the degree by one. A Bézier must have at least 2 poles.

- **Parameters:** `index` — 1-based pole index to remove.
- **Returns:** `true` on success, `false` if not a Bézier or the operation would violate constraints.
- **OCCT:** `Geom2d_BezierCurve::RemovePole`.
- **Example:**
  ```swift
  curve.bezierRemovePole(2)
  ```

---

### `bezierSegment(u1:u2:)`

Restricts a 2D Bézier curve to the parameter interval `[u1, u2]` in place.

```swift
@discardableResult
public func bezierSegment(u1: Double, u2: Double) -> Bool
```

The curve is reparametrized so the new domain is `[0, 1]`.

- **Parameters:** `u1`, `u2` — start and end parameters within the current domain `[0, 1]`.
- **Returns:** `true` on success, `false` if not a Bézier.
- **OCCT:** `Geom2d_BezierCurve::Segment`.
- **Example:**
  ```swift
  curve.bezierSegment(u1: 0.25, u2: 0.75)
  ```

---

### `bezierIncreaseDegree(_:)`

Raises the degree of a 2D Bézier curve (adds poles to preserve shape).

```swift
@discardableResult
public func bezierIncreaseDegree(_ degree: Int) -> Bool
```

Degree elevation is exact — the curve shape does not change.

- **Parameters:** `degree` — new degree (must be greater than the current degree).
- **Returns:** `true` on success, `false` if not a Bézier or the requested degree is not higher.
- **OCCT:** `Geom2d_BezierCurve::Increase`.
- **Example:**
  ```swift
  curve.bezierIncreaseDegree(4)
  ```

---

### `bezierStartPoint`

The start point of the Bézier curve (first pole).

```swift
public var bezierStartPoint: SIMD2<Double> { get }
```

- **Returns:** Start point; `.zero` if not a Bézier.
- **OCCT:** `Geom2d_BezierCurve::StartPoint`.
- **Example:**
  ```swift
  let s = curve.bezierStartPoint
  ```

---

### `bezierEndPoint`

The end point of the Bézier curve (last pole).

```swift
public var bezierEndPoint: SIMD2<Double> { get }
```

- **Returns:** End point; `.zero` if not a Bézier.
- **OCCT:** `Geom2d_BezierCurve::EndPoint`.
- **Example:**
  ```swift
  let e = curve.bezierEndPoint
  ```

---

### `bezierPoles`

All control points of the 2D Bézier curve.

```swift
public var bezierPoles: [SIMD2<Double>] { get }
```

- **Returns:** Array of poles in order (index 0 = pole 1); empty if not a Bézier.
- **OCCT:** `Geom2d_BezierCurve::Pole(i)`.
- **Example:**
  ```swift
  for p in curve.bezierPoles { print(p) }
  ```

---

### `bezierReverse()`

Reverses the parametric direction of a 2D Bézier curve in place.

```swift
@discardableResult
public func bezierReverse() -> Bool
```

Poles are reordered so the new start pole is the old end pole.

- **Returns:** `true` on success, `false` if not a Bézier.
- **OCCT:** `Geom2d_BezierCurve::Reverse`.
- **Example:**
  ```swift
  curve.bezierReverse()
  ```
