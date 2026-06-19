---
title: Curve3D — Analytic Types
parent: API Reference
---

# Curve3D — Analytic Types

These members expose type-specific properties of analytic curves (circle, ellipse, hyperbola, parabola, line) plus B-spline/Bézier pole/knot/weight accessors. They are valid only when the underlying curve is of the matching kind — accessing them on a mismatched curve type returns zero/nil silently. See the main [Curve3D](Curve3D.md) page for construction methods, evaluation, and operations.

## Topics

- [BSpline Queries](#bspline-queries) · [BSpline Knot Splitting (v0.40.0)](#bspline-knot-splitting-v0400) · [Geom_Circle Properties (v0.108.0)](#geom_circle-properties-v01080) · [Geom_Ellipse Properties (v0.108.0)](#geom_ellipse-properties-v01080) · [Geom_Hyperbola Properties (v0.108.0)](#geom_hyperbola-properties-v01080) · [Geom_Parabola Properties (v0.108.0)](#geom_parabola-properties-v01080) · [Geom_Line Properties (v0.108.0)](#geom_line-properties-v01080) · [Bezier Curve deep method completion (v0.125.0)](#bezier-curve-deep-method-completion-v01250) · [Bezier 3D completions (v0.126.0)](#bezier-3d-completions-v01260) · [BSpline completions (v0.127.0)](#bspline-completions-v01270)

---

## BSpline Queries

### `poleCount`

Number of poles (control points), or `nil` if the curve is not a B-spline or Bézier.

```swift
public var poleCount: Int? { get }
```

- **Returns:** Pole count, or `nil` when the curve cannot be downcast to `Geom_BSplineCurve` or `Geom_BezierCurve`.
- **OCCT:** `Geom_BSplineCurve::NbPoles` / `Geom_BezierCurve::NbPoles`.
- **Example:**
  ```swift
  if let curve = Curve3D.bspline(poles: pts, knots: knots, multiplicities: mults, degree: 3) {
      if let n = curve.poleCount { /* n == pts.count */ }
  }
  ```

---

### `poles`

All poles (control points) of a B-spline or Bézier curve.

```swift
public var poles: [SIMD3<Double>]? { get }
```

- **Returns:** Array of pole positions in model space, or `nil` if the curve is not a B-spline/Bézier or retrieval fails.
- **OCCT:** `Geom_BSplineCurve::Pole` / `Geom_BezierCurve::Pole` (iterated via `NbPoles`).
- **Example:**
  ```swift
  if let curve = Curve3D.bspline(poles: pts, knots: knots, multiplicities: mults, degree: 3),
     let poles = curve.poles {
      for p in poles { print(p) }
  }
  ```

---

### `degree`

Polynomial degree of the B-spline or Bézier curve.

```swift
public var degree: Int { get }
```

- **Returns:** Degree of the curve, or `-1` if the curve is not a B-spline or Bézier.
- **OCCT:** `Geom_BSplineCurve::Degree` / `Geom_BezierCurve::Degree`.
- **Example:**
  ```swift
  if let curve = Curve3D.bspline(poles: pts, knots: knots, multiplicities: mults, degree: 3) {
      let d = curve.degree  // 3
  }
  ```

---

## BSpline Knot Splitting (v0.40.0)

### `ContinuityOrder`

Continuity level used for knot-splitting analysis.

```swift
public enum ContinuityOrder: Int32 {
    case c0 = 0   // positional
    case c1 = 1   // tangent
    case c2 = 2   // curvature
}
```

Pass to `continuityBreaks(minContinuity:)` to specify the minimum required continuity across knots.

---

### `continuityBreaks(minContinuity:)`

Parameter values where the B-spline's internal continuity drops below the specified level.

```swift
public func continuityBreaks(minContinuity: ContinuityOrder = .c1) -> [Double]?
```

Only works on `Geom_BSplineCurve`. Returns knot parameters where the curve's continuity is strictly less than `minContinuity`. Useful for splitting a composite B-spline into smooth segments.

- **Parameters:** `minContinuity` — minimum continuity to require (default `.c1`).
- **Returns:** Array of parameter values at continuity breaks (up to 256), or `nil` if the curve is not a B-spline.
- **OCCT:** `GeomConvert_BSplineCurveKnotSplitting::NbSplits` / `SplitValue`, resolved via `Geom_BSplineCurve::Knot`.
- **Example:**
  ```swift
  if let curve = Curve3D.bspline(poles: pts, knots: knots, multiplicities: mults, degree: 3),
     let breaks = curve.continuityBreaks(minContinuity: .c1) {
      let segments = curve.toBezierSegments() // split at each break
  }
  ```

---

## Geom_Circle Properties (v0.108.0)

### `circleProperties`

Returns the circle-specific property accessor for this curve.

```swift
public var circleProperties: CircleProperties { get }
```

Meaningful only when the curve wraps a `Geom_Circle`. Accessing members on a non-circle returns zero.

- **Returns:** A `CircleProperties` value backed by the same internal handle.
- **OCCT:** `Geom_Circle` — accessed via `Handle(Geom_Circle)::DownCast`.
- **Example:**
  ```swift
  if let curve = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) {
      let cp = curve.circleProperties
  }
  ```

---

### `CircleProperties.radius`

The radius of the circle.

```swift
public var radius: Double { get }
```

- **Returns:** Radius in model units, or `0` if the curve is not a `Geom_Circle`.
- **OCCT:** `Geom_Circle::Radius`.
- **Example:**
  ```swift
  if let curve = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) {
      let r = curve.circleProperties.radius  // 5.0
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
- **Returns:** `true` on success, `false` if the curve is not a circle or the value is invalid.
- **OCCT:** `Geom_Circle::SetRadius`.
- **Example:**
  ```swift
  if let curve = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) {
      curve.circleProperties.setRadius(8)
  }
  ```

---

### `CircleProperties.eccentricity`

The eccentricity of the circle (always `0.0`).

```swift
public var eccentricity: Double { get }
```

- **Returns:** `0.0` for any circle; `0` if the curve is not a circle.
- **OCCT:** `Geom_Circle::Eccentricity`.
- **Example:**
  ```swift
  if let curve = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) {
      let e = curve.circleProperties.eccentricity  // 0.0
  }
  ```

---

### `CircleProperties.center`

The centre point of the circle.

```swift
public var center: SIMD3<Double> { get }
```

- **Returns:** Centre position in model space, or `.zero` if the curve is not a circle.
- **OCCT:** `Geom_Circle::Circ().Location()` via `gp_Circ::Location`.
- **Example:**
  ```swift
  if let curve = Curve3D.circle(center: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1), radius: 5) {
      let c = curve.circleProperties.center  // SIMD3(1, 2, 3)
  }
  ```

---

### `CircleProperties.xAxis`

The X axis of the circle's local frame: a position point and direction.

```swift
public var xAxis: (position: SIMD3<Double>, direction: SIMD3<Double>) { get }
```

The X axis lies in the circle's plane, pointing toward the zero-angle parameter position.

- **Returns:** Tuple `(position, direction)`. Returns `(.zero, .zero)` if the curve is not a circle.
- **OCCT:** `Geom_Circle::XAxis` → `gp_Ax1::Location` + `gp_Ax1::Direction`.
- **Example:**
  ```swift
  if let curve = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) {
      let ax = curve.circleProperties.xAxis
  }
  ```

---

### `CircleProperties.yAxis`

The Y axis of the circle's local frame: a position point and direction.

```swift
public var yAxis: (position: SIMD3<Double>, direction: SIMD3<Double>) { get }
```

The Y axis lies in the circle's plane, 90° counterclockwise from the X axis.

- **Returns:** Tuple `(position, direction)`. Returns `(.zero, .zero)` if the curve is not a circle.
- **OCCT:** `Geom_Circle::YAxis` → `gp_Ax1::Location` + `gp_Ax1::Direction`.
- **Example:**
  ```swift
  if let curve = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) {
      let ay = curve.circleProperties.yAxis
  }
  ```

---

## Geom_Ellipse Properties (v0.108.0)

### `ellipseProperties`

Returns the ellipse-specific property accessor for this curve.

```swift
public var ellipseProperties: EllipseProperties { get }
```

Meaningful only when the curve wraps a `Geom_Ellipse`. Accessing members on a non-ellipse returns zero.

- **Returns:** An `EllipseProperties` value backed by the same internal handle.
- **OCCT:** `Geom_Ellipse` — accessed via `Handle(Geom_Ellipse)::DownCast`.
- **Example:**
  ```swift
  if let curve = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1),
                                  majorRadius: 10, minorRadius: 5) {
      let ep = curve.ellipseProperties
  }
  ```

---

### `EllipseProperties.majorRadius`

The major radius (semi-major axis length).

```swift
public var majorRadius: Double { get }
```

- **Returns:** Major radius in model units, or `0` if the curve is not a `Geom_Ellipse`.
- **OCCT:** `Geom_Ellipse::MajorRadius`.
- **Example:**
  ```swift
  if let curve = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1),
                                  majorRadius: 10, minorRadius: 5) {
      let R = curve.ellipseProperties.majorRadius  // 10.0
  }
  ```

---

### `EllipseProperties.minorRadius`

The minor radius (semi-minor axis length).

```swift
public var minorRadius: Double { get }
```

- **Returns:** Minor radius in model units, or `0` if the curve is not a `Geom_Ellipse`.
- **OCCT:** `Geom_Ellipse::MinorRadius`.
- **Example:**
  ```swift
  if let curve = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1),
                                  majorRadius: 10, minorRadius: 5) {
      let r = curve.ellipseProperties.minorRadius  // 5.0
  }
  ```

---

### `EllipseProperties.setMajorRadius(_:)`

Mutates the ellipse's major radius in place.

```swift
@discardableResult
public func setMajorRadius(_ r: Double) -> Bool
```

- **Parameters:** `r` — new major radius (must be > minor radius per OCCT).
- **Returns:** `true` on success, `false` if the curve is not an ellipse or the value is invalid.
- **OCCT:** `Geom_Ellipse::SetMajorRadius`.
- **Example:**
  ```swift
  if let curve = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1),
                                  majorRadius: 10, minorRadius: 5) {
      curve.ellipseProperties.setMajorRadius(12)
  }
  ```

---

### `EllipseProperties.setMinorRadius(_:)`

Mutates the ellipse's minor radius in place.

```swift
@discardableResult
public func setMinorRadius(_ r: Double) -> Bool
```

- **Parameters:** `r` — new minor radius (must be < major radius per OCCT).
- **Returns:** `true` on success, `false` if the curve is not an ellipse or the value is invalid.
- **OCCT:** `Geom_Ellipse::SetMinorRadius`.
- **Example:**
  ```swift
  if let curve = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1),
                                  majorRadius: 10, minorRadius: 5) {
      curve.ellipseProperties.setMinorRadius(3)
  }
  ```

---

### `EllipseProperties.eccentricity`

The eccentricity of the ellipse (0 < e < 1).

```swift
public var eccentricity: Double { get }
```

- **Returns:** Eccentricity `e = sqrt(1 − (b/a)²)`, or `0` if the curve is not an ellipse.
- **OCCT:** `Geom_Ellipse::Eccentricity`.
- **Example:**
  ```swift
  if let curve = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1),
                                  majorRadius: 10, minorRadius: 5) {
      let e = curve.ellipseProperties.eccentricity  // ≈ 0.866
  }
  ```

---

### `EllipseProperties.focal`

The focal distance (distance between the two foci, i.e. `2c`).

```swift
public var focal: Double { get }
```

- **Returns:** `2 * sqrt(a² − b²)`, or `0` if the curve is not an ellipse.
- **OCCT:** `Geom_Ellipse::Focal`.
- **Example:**
  ```swift
  if let curve = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1),
                                  majorRadius: 10, minorRadius: 5) {
      let f = curve.ellipseProperties.focal  // ≈ 17.32
  }
  ```

---

### `EllipseProperties.focus1`

The first focus point.

```swift
public var focus1: SIMD3<Double> { get }
```

- **Returns:** First focus position in model space, or `.zero` if the curve is not an ellipse.
- **OCCT:** `Geom_Ellipse::Focus1`.
- **Example:**
  ```swift
  if let curve = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1),
                                  majorRadius: 10, minorRadius: 5) {
      let f1 = curve.ellipseProperties.focus1
  }
  ```

---

### `EllipseProperties.focus2`

The second focus point.

```swift
public var focus2: SIMD3<Double> { get }
```

- **Returns:** Second focus position in model space, or `.zero` if the curve is not an ellipse.
- **OCCT:** `Geom_Ellipse::Focus2`.
- **Example:**
  ```swift
  if let curve = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1),
                                  majorRadius: 10, minorRadius: 5) {
      let f2 = curve.ellipseProperties.focus2
  }
  ```

---

### `EllipseProperties.parameter`

The semi-latus rectum (`b² / a`).

```swift
public var parameter: Double { get }
```

- **Returns:** Semi-latus rectum in model units, or `0` if the curve is not an ellipse.
- **OCCT:** `Geom_Ellipse::Parameter`.
- **Example:**
  ```swift
  if let curve = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1),
                                  majorRadius: 10, minorRadius: 5) {
      let p = curve.ellipseProperties.parameter  // 2.5 (25/10)
  }
  ```

---

### `EllipseProperties.directrix1`

The first directrix (position + direction).

```swift
public var directrix1: (position: SIMD3<Double>, direction: SIMD3<Double>) { get }
```

The directrix is perpendicular to the major axis. Its distance from the centre is `a / e`.

- **Returns:** Tuple `(position, direction)`. Returns `(.zero, .zero)` if the curve is not an ellipse.
- **OCCT:** `Geom_Ellipse::Directrix1` → `gp_Ax1::Location` + `gp_Ax1::Direction`.
- **Example:**
  ```swift
  if let curve = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1),
                                  majorRadius: 10, minorRadius: 5) {
      let d1 = curve.ellipseProperties.directrix1
  }
  ```

---

## Geom_Hyperbola Properties (v0.108.0)

### `hyperbolaProperties`

Returns the hyperbola-specific property accessor for this curve.

```swift
public var hyperbolaProperties: HyperbolaProperties { get }
```

Meaningful only when the curve wraps a `Geom_Hyperbola`. Accessing members on a non-hyperbola returns zero.

- **Returns:** A `HyperbolaProperties` value backed by the same internal handle.
- **OCCT:** `Geom_Hyperbola` — accessed via `Handle(Geom_Hyperbola)::DownCast`.
- **Example:**
  ```swift
  if let curve = Curve3D.hyperbola(center: .zero, normal: SIMD3(0, 0, 1),
                                    majorRadius: 5, minorRadius: 3) {
      let hp = curve.hyperbolaProperties
  }
  ```

---

### `HyperbolaProperties.majorRadius`

The major radius (real semi-axis).

```swift
public var majorRadius: Double { get }
```

- **Returns:** Real semi-axis length in model units, or `0` if the curve is not a `Geom_Hyperbola`.
- **OCCT:** `Geom_Hyperbola::MajorRadius`.
- **Example:**
  ```swift
  if let curve = Curve3D.hyperbola(center: .zero, normal: SIMD3(0, 0, 1),
                                    majorRadius: 5, minorRadius: 3) {
      let a = curve.hyperbolaProperties.majorRadius  // 5.0
  }
  ```

---

### `HyperbolaProperties.minorRadius`

The minor radius (imaginary semi-axis).

```swift
public var minorRadius: Double { get }
```

- **Returns:** Imaginary semi-axis length in model units, or `0` if the curve is not a `Geom_Hyperbola`.
- **OCCT:** `Geom_Hyperbola::MinorRadius`.
- **Example:**
  ```swift
  if let curve = Curve3D.hyperbola(center: .zero, normal: SIMD3(0, 0, 1),
                                    majorRadius: 5, minorRadius: 3) {
      let b = curve.hyperbolaProperties.minorRadius  // 3.0
  }
  ```

---

### `HyperbolaProperties.setMajorRadius(_:)`

Mutates the hyperbola's major radius in place.

```swift
@discardableResult
public func setMajorRadius(_ r: Double) -> Bool
```

- **Parameters:** `r` — new major radius (must be > 0).
- **Returns:** `true` on success, `false` if the curve is not a hyperbola or the value is invalid.
- **OCCT:** `Geom_Hyperbola::SetMajorRadius`.
- **Example:**
  ```swift
  if let curve = Curve3D.hyperbola(center: .zero, normal: SIMD3(0, 0, 1),
                                    majorRadius: 5, minorRadius: 3) {
      curve.hyperbolaProperties.setMajorRadius(7)
  }
  ```

---

### `HyperbolaProperties.setMinorRadius(_:)`

Mutates the hyperbola's minor radius in place.

```swift
@discardableResult
public func setMinorRadius(_ r: Double) -> Bool
```

- **Parameters:** `r` — new minor radius (must be > 0).
- **Returns:** `true` on success, `false` if the curve is not a hyperbola or the value is invalid.
- **OCCT:** `Geom_Hyperbola::SetMinorRadius`.
- **Example:**
  ```swift
  if let curve = Curve3D.hyperbola(center: .zero, normal: SIMD3(0, 0, 1),
                                    majorRadius: 5, minorRadius: 3) {
      curve.hyperbolaProperties.setMinorRadius(4)
  }
  ```

---

### `HyperbolaProperties.eccentricity`

The eccentricity of the hyperbola (e > 1).

```swift
public var eccentricity: Double { get }
```

- **Returns:** `e = sqrt(1 + (b/a)²) > 1`, or `0` if the curve is not a hyperbola.
- **OCCT:** `Geom_Hyperbola::Eccentricity`.
- **Example:**
  ```swift
  if let curve = Curve3D.hyperbola(center: .zero, normal: SIMD3(0, 0, 1),
                                    majorRadius: 5, minorRadius: 3) {
      let e = curve.hyperbolaProperties.eccentricity  // ≈ 1.166
  }
  ```

---

### `HyperbolaProperties.focal`

The focal distance (distance between the two foci, i.e. `2c`).

```swift
public var focal: Double { get }
```

- **Returns:** `2 * sqrt(a² + b²)`, or `0` if the curve is not a hyperbola.
- **OCCT:** `Geom_Hyperbola::Focal`.
- **Example:**
  ```swift
  if let curve = Curve3D.hyperbola(center: .zero, normal: SIMD3(0, 0, 1),
                                    majorRadius: 5, minorRadius: 3) {
      let f = curve.hyperbolaProperties.focal  // ≈ 11.66
  }
  ```

---

### `HyperbolaProperties.focus1`

The first focus point.

```swift
public var focus1: SIMD3<Double> { get }
```

- **Returns:** First focus in model space, or `.zero` if the curve is not a hyperbola.
- **OCCT:** `Geom_Hyperbola::Focus1`.
- **Example:**
  ```swift
  if let curve = Curve3D.hyperbola(center: .zero, normal: SIMD3(0, 0, 1),
                                    majorRadius: 5, minorRadius: 3) {
      let f1 = curve.hyperbolaProperties.focus1
  }
  ```

---

### `HyperbolaProperties.asymptote1`

The first asymptote (position + direction).

```swift
public var asymptote1: (position: SIMD3<Double>, direction: SIMD3<Double>) { get }
```

For a standard hyperbola with semi-axes `a`, `b`, the asymptote direction is `(a, b, 0)` (normalised). The two asymptotes are symmetric about the transverse axis.

- **Returns:** Tuple `(position, direction)`. Returns `(.zero, .zero)` if the curve is not a hyperbola.
- **OCCT:** `Geom_Hyperbola::Asymptote1` → `gp_Ax1::Location` + `gp_Ax1::Direction`.
- **Example:**
  ```swift
  if let curve = Curve3D.hyperbola(center: .zero, normal: SIMD3(0, 0, 1),
                                    majorRadius: 5, minorRadius: 3) {
      let a1 = curve.hyperbolaProperties.asymptote1
  }
  ```

---

## Geom_Parabola Properties (v0.108.0)

### `parabolaProperties`

Returns the parabola-specific property accessor for this curve.

```swift
public var parabolaProperties: ParabolaProperties { get }
```

Meaningful only when the curve wraps a `Geom_Parabola`. Accessing members on a non-parabola returns zero.

- **Returns:** A `ParabolaProperties` value backed by the same internal handle.
- **OCCT:** `Geom_Parabola` — accessed via `Handle(Geom_Parabola)::DownCast`.
- **Example:**
  ```swift
  if let curve = Curve3D.parabola(vertex: .zero, normal: SIMD3(0, 0, 1), focal: 3) {
      let pp = curve.parabolaProperties
  }
  ```

---

### `ParabolaProperties.focal`

The focal distance of the parabola.

```swift
public var focal: Double { get }
```

Distance from the vertex to the focus. The directrix is the same distance on the opposite side of the vertex.

- **Returns:** Focal length in model units, or `0` if the curve is not a `Geom_Parabola`.
- **OCCT:** `Geom_Parabola::Focal`.
- **Example:**
  ```swift
  if let curve = Curve3D.parabola(vertex: .zero, normal: SIMD3(0, 0, 1), focal: 3) {
      let f = curve.parabolaProperties.focal  // 3.0
  }
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
- **OCCT:** `Geom_Parabola::SetFocal`.
- **Example:**
  ```swift
  if let curve = Curve3D.parabola(vertex: .zero, normal: SIMD3(0, 0, 1), focal: 3) {
      curve.parabolaProperties.setFocal(5)
  }
  ```

---

### `ParabolaProperties.focus`

The focus point of the parabola.

```swift
public var focus: SIMD3<Double> { get }
```

- **Returns:** Focus position in model space, or `.zero` if the curve is not a parabola.
- **OCCT:** `Geom_Parabola::Focus`.
- **Example:**
  ```swift
  if let curve = Curve3D.parabola(vertex: .zero, normal: SIMD3(0, 0, 1), focal: 3) {
      let fpt = curve.parabolaProperties.focus
  }
  ```

---

### `ParabolaProperties.eccentricity`

The eccentricity of the parabola (always `1.0`).

```swift
public var eccentricity: Double { get }
```

- **Returns:** `1.0` for any parabola; `0` if the curve is not a parabola.
- **OCCT:** `Geom_Parabola::Eccentricity`.
- **Example:**
  ```swift
  if let curve = Curve3D.parabola(vertex: .zero, normal: SIMD3(0, 0, 1), focal: 3) {
      let e = curve.parabolaProperties.eccentricity  // 1.0
  }
  ```

---

### `ParabolaProperties.parameter`

The parameter of the parabola (`2 * focal`).

```swift
public var parameter: Double { get }
```

Half the length of the latus rectum; the perpendicular chord through the focus.

- **Returns:** `2 * focal` in model units, or `0` if the curve is not a parabola.
- **OCCT:** `Geom_Parabola::Parameter`.
- **Example:**
  ```swift
  if let curve = Curve3D.parabola(vertex: .zero, normal: SIMD3(0, 0, 1), focal: 3) {
      let p = curve.parabolaProperties.parameter  // 6.0
  }
  ```

---

### `ParabolaProperties.directrix`

The directrix of the parabola (position + direction).

```swift
public var directrix: (position: SIMD3<Double>, direction: SIMD3<Double>) { get }
```

The directrix is a line perpendicular to the parabola's axis at distance `focal` on the opposite side of the vertex from the focus.

- **Returns:** Tuple `(position, direction)`. Returns `(.zero, .zero)` if the curve is not a parabola.
- **OCCT:** `Geom_Parabola::Directrix` → `gp_Ax1::Location` + `gp_Ax1::Direction`.
- **Example:**
  ```swift
  if let curve = Curve3D.parabola(vertex: .zero, normal: SIMD3(0, 0, 1), focal: 3) {
      let d = curve.parabolaProperties.directrix
  }
  ```

---

## Geom_Line Properties (v0.108.0)

### `lineProperties`

Returns the line-specific property accessor for this curve.

```swift
public var lineProperties: LineProperties { get }
```

Meaningful only when the curve wraps a `Geom_Line`. Accessing members on a non-line returns zero.

- **Returns:** A `LineProperties` value backed by the same internal handle.
- **OCCT:** `Geom_Line` — accessed via `Handle(Geom_Line)::DownCast`.
- **Example:**
  ```swift
  if let curve = Curve3D.line(origin: .zero, direction: SIMD3(1, 0, 0)) {
      let lp = curve.lineProperties
  }
  ```

---

### `LineProperties.direction`

The unit direction vector of the line.

```swift
public var direction: SIMD3<Double> { get }
```

- **Returns:** Unit direction, or `.zero` if the curve is not a `Geom_Line`.
- **OCCT:** `Geom_Line::Lin().Direction()`.
- **Example:**
  ```swift
  if let curve = Curve3D.line(origin: .zero, direction: SIMD3(1, 0, 0)) {
      let d = curve.lineProperties.direction  // SIMD3(1, 0, 0)
  }
  ```

---

### `LineProperties.location`

The origin (location) point of the line.

```swift
public var location: SIMD3<Double> { get }
```

- **Returns:** Origin position in model space, or `.zero` if the curve is not a line.
- **OCCT:** `Geom_Line::Lin().Location()`.
- **Example:**
  ```swift
  if let curve = Curve3D.line(origin: SIMD3(1, 2, 3), direction: SIMD3(0, 0, 1)) {
      let loc = curve.lineProperties.location  // SIMD3(1, 2, 3)
  }
  ```

---

### `LineProperties.setDirection(_:)`

Mutates the line's direction in place.

```swift
@discardableResult
public func setDirection(_ d: SIMD3<Double>) -> Bool
```

- **Parameters:** `d` — new direction (will be normalised by OCCT via `gp_Dir`; must be non-zero).
- **Returns:** `true` on success, `false` if the curve is not a line or `d` is degenerate.
- **OCCT:** `Geom_Line::SetDirection`.
- **Example:**
  ```swift
  if let curve = Curve3D.line(origin: .zero, direction: SIMD3(1, 0, 0)) {
      curve.lineProperties.setDirection(SIMD3(0, 1, 0))
  }
  ```

---

### `LineProperties.setLocation(_:)`

Mutates the line's origin point in place.

```swift
@discardableResult
public func setLocation(_ p: SIMD3<Double>) -> Bool
```

- **Parameters:** `p` — new origin point.
- **Returns:** `true` on success, `false` if the curve is not a line.
- **OCCT:** `Geom_Line::SetLocation`.
- **Example:**
  ```swift
  if let curve = Curve3D.line(origin: .zero, direction: SIMD3(1, 0, 0)) {
      curve.lineProperties.setLocation(SIMD3(5, 0, 0))
  }
  ```

---

### `LineProperties.position`

The line's position axis: origin location and unit direction.

```swift
public var position: (location: SIMD3<Double>, direction: SIMD3<Double>) { get }
```

Combines location and direction into a single call via the underlying `gp_Ax1`.

- **Returns:** Tuple `(location, direction)`. Returns `(.zero, .zero)` if the curve is not a line.
- **OCCT:** `Geom_Line::Position` → `gp_Ax1::Location` + `gp_Ax1::Direction`.
- **Example:**
  ```swift
  if let curve = Curve3D.line(origin: SIMD3(1, 0, 0), direction: SIMD3(0, 1, 0)) {
      let pos = curve.lineProperties.position
  }
  ```

---

### `LineProperties.lin`

The `gp_Lin` representation: origin location and unit direction.

```swift
public var lin: (location: SIMD3<Double>, direction: SIMD3<Double>) { get }
```

Equivalent to `position` but reads the data via `Geom_Line::Lin()` rather than `Geom_Line::Position()`. Both return the same values in practice.

- **Returns:** Tuple `(location, direction)`. Returns `(.zero, .zero)` if the curve is not a line.
- **OCCT:** `Geom_Line::Lin()` → `gp_Lin::Location` + `gp_Lin::Direction`.
- **Example:**
  ```swift
  if let curve = Curve3D.line(origin: .zero, direction: SIMD3(0, 0, 1)) {
      let l = curve.lineProperties.lin
  }
  ```

---

## Bezier Curve deep method completion (v0.125.0)

### `bezierStartPoint`

The start point (first pole) of the Bézier curve.

```swift
public var bezierStartPoint: SIMD3<Double> { get }
```

Returns `.zero` if the curve is not a `Geom_BezierCurve`.

- **OCCT:** `Geom_BezierCurve::StartPoint`.
- **Example:**
  ```swift
  if let curve = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(1,1,0), SIMD3(2,0,0)]) {
      let start = curve.bezierStartPoint  // SIMD3(0,0,0)
  }
  ```

---

### `bezierEndPoint`

The end point (last pole) of the Bézier curve.

```swift
public var bezierEndPoint: SIMD3<Double> { get }
```

Returns `.zero` if the curve is not a `Geom_BezierCurve`.

- **OCCT:** `Geom_BezierCurve::EndPoint`.
- **Example:**
  ```swift
  if let curve = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(1,1,0), SIMD3(2,0,0)]) {
      let end = curve.bezierEndPoint  // SIMD3(2,0,0)
  }
  ```

---

### `bezierPoles`

All poles of the Bézier curve as an array.

```swift
public var bezierPoles: [SIMD3<Double>] { get }
```

Returns an empty array if the curve is not a `Geom_BezierCurve` or has no poles.

- **OCCT:** `Geom_BezierCurve::NbPoles` + `Geom_BezierCurve::Pole` (iterated).
- **Example:**
  ```swift
  if let curve = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(1,1,0), SIMD3(2,0,0)]) {
      let pts = curve.bezierPoles  // count == 3
  }
  ```

---

### `bezierWeights`

All weights of the rational Bézier curve.

```swift
public var bezierWeights: [Double]? { get }
```

- **Returns:** Array of weights (one per pole), or `nil` if the curve is non-rational or not a Bézier.
- **OCCT:** `Geom_BezierCurve::Weight` (iterated) — returns `nil` when the curve is non-rational.
- **Example:**
  ```swift
  if let curve = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(1,1,0), SIMD3(2,0,0)],
                                 weights: [1, 0.5, 1]) {
      if let w = curve.bezierWeights { print(w) }
  }
  ```

---

### `bezierIsClosed`

Whether the Bézier curve is geometrically closed.

```swift
public var bezierIsClosed: Bool { get }
```

- **Returns:** `true` if the first and last pole coincide within tolerance; always `false` for non-Bézier curves.
- **OCCT:** `Geom_BezierCurve::IsClosed`.
- **Example:**
  ```swift
  if let curve = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(1,1,0), SIMD3(0,0,0)]) {
      let closed = curve.bezierIsClosed  // true
  }
  ```

---

### `bezierIsPeriodic`

Whether the Bézier curve is periodic.

```swift
public var bezierIsPeriodic: Bool { get }
```

Bézier curves are never periodic in OCCT; this always returns `false` for `Geom_BezierCurve`.

- **Returns:** `false` for any Bézier curve; `false` for non-Bézier curves.
- **OCCT:** `Geom_BezierCurve::IsPeriodic`.
- **Example:**
  ```swift
  if let curve = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(1,1,0), SIMD3(2,0,0)]) {
      let p = curve.bezierIsPeriodic  // false
  }
  ```

---

### `bezierContinuity`

The global continuity class of the Bézier curve (0 = C0, 1 = C1, 2 = C2, 3 = C3, 4 = CN).

```swift
public var bezierContinuity: Int { get }
```

A Bézier curve of degree ≥ 1 is always C∞ (returns `4` = CN). Returns `0` for non-Bézier curves.

- **OCCT:** `Geom_BezierCurve::Continuity` → `GeomAbs_Shape` mapped to Int.
- **Example:**
  ```swift
  if let curve = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(1,1,0), SIMD3(2,0,0)]) {
      let cont = curve.bezierContinuity  // 4 (CN)
  }
  ```

---

### `bezierIsCN(_:)`

Whether the Bézier curve is at least C`n` continuous.

```swift
public func bezierIsCN(_ n: Int) -> Bool
```

- **Parameters:** `n` — required continuity order.
- **Returns:** `true` if the curve is at least C`n`; `false` for non-Bézier curves.
- **OCCT:** `Geom_BezierCurve::IsCN`.
- **Example:**
  ```swift
  if let curve = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(1,1,0), SIMD3(2,0,0)]) {
      let ok = curve.bezierIsCN(2)  // true
  }
  ```

---

## Bezier 3D completions (v0.126.0)

### `bezierInsertPoleBefore(_:point:)`

Insert a pole before a given index in the Bézier curve (1-based).

```swift
@discardableResult
public func bezierInsertPoleBefore(_ index: Int, point: SIMD3<Double>) -> Bool
```

Modifies the underlying `Geom_BezierCurve` in place, increasing the pole count by one and raising the degree by one.

- **Parameters:**
  - `index` — 1-based insertion position (the new pole is placed before this index).
  - `point` — new control point position.
- **Returns:** `true` on success, `false` if the curve is not a Bézier or the index is out of range.
- **OCCT:** `Geom_BezierCurve::InsertPoleAfter` (called with `index − 1` to implement before semantics).
- **Example:**
  ```swift
  if let curve = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(2,0,0)]) {
      curve.bezierInsertPoleBefore(2, point: SIMD3(1, 1, 0))
      // curve now has 3 poles
  }
  ```

---

### `bezierReverse()`

Reverse the parameterization of the Bézier curve in place.

```swift
@discardableResult
public func bezierReverse() -> Bool
```

Poles are reordered so the curve traces the same path in the opposite parameter direction.

- **Returns:** `true` on success, `false` if the curve is not a Bézier.
- **OCCT:** `Geom_BezierCurve::Reverse`.
- **Example:**
  ```swift
  if let curve = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(1,1,0), SIMD3(2,0,0)]) {
      curve.bezierReverse()
      let start = curve.bezierStartPoint  // now SIMD3(2,0,0)
  }
  ```

---

### `bezierSetPoleWithWeight(index:point:weight:)`

Set a pole and its weight simultaneously on a rational Bézier curve.

```swift
@discardableResult
public func bezierSetPoleWithWeight(index: Int, point: SIMD3<Double>, weight: Double) -> Bool
```

- **Parameters:**
  - `index` — 1-based pole index.
  - `point` — new control point position.
  - `weight` — new weight for the pole (must be > 0).
- **Returns:** `true` on success, `false` if the curve is not a Bézier, the index is out of range, or the weight is non-positive.
- **OCCT:** `Geom_BezierCurve::SetPole` + `Geom_BezierCurve::SetWeight`.
- **Example:**
  ```swift
  if let curve = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(1,1,0), SIMD3(2,0,0)],
                                 weights: [1, 1, 1]) {
      curve.bezierSetPoleWithWeight(index: 2, point: SIMD3(1, 2, 0), weight: 0.5)
  }
  ```

---

## BSpline completions (v0.127.0)

### `bsplinePeriodicNormalization(_:)`

Normalize a parameter value for a periodic B-spline curve.

```swift
public func bsplinePeriodicNormalization(_ u: Double) -> Double?
```

Maps an arbitrary parameter value into the curve's fundamental period `[first, first + period)`.

- **Parameters:** `u` — raw parameter value.
- **Returns:** Normalized parameter in the fundamental period, or `nil` if the curve is not a periodic B-spline.
- **OCCT:** `Geom_BSplineCurve::PeriodicNormalization`.
- **Example:**
  ```swift
  if let curve = Curve3D.interpolatePeriodic(points: pts),
     let norm = curve.bsplinePeriodicNormalization(7.5) {
      let pt = curve.point(at: norm)
  }
  ```

---

### `bsplineIsG1(tFirst:tLast:angularTolerance:)`

Check G1 (tangent) continuity of a B-spline on a parameter range.

```swift
public func bsplineIsG1(tFirst: Double, tLast: Double, angularTolerance: Double = 0.01) -> Bool
```

Uses OCCT's `Geom_BSplineCurve::IsG1` to verify that the curve's tangent direction changes by at most `angularTolerance` radians everywhere in `[tFirst, tLast]`.

- **Parameters:**
  - `tFirst` — start of parameter range.
  - `tLast` — end of parameter range.
  - `angularTolerance` — angular tolerance in radians (default `0.01`).
- **Returns:** `true` if G1 continuous on the range; `false` otherwise or if the curve is not a B-spline.
- **OCCT:** `Geom_BSplineCurve::IsG1`.
- **Example:**
  ```swift
  if let curve = Curve3D.bspline(poles: pts, knots: knots, multiplicities: mults, degree: 3) {
      let d = curve.domain
      let smooth = curve.bsplineIsG1(tFirst: d.lowerBound, tLast: d.upperBound)
  }
  ```
