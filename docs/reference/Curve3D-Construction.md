---
title: Curve3D — Construction
parent: API Reference
---

# Curve3D — Construction

This page documents higher-level `Curve3D` construction APIs: arcs of conics (hyperbola, parabola), three-point ellipse and hyperbola factories, periodic conversion, parameter-splitting, expanded interpolation variants, and arc-length utilities. For the core type overview, primitives, BSpline/Bezier construction, operations, and transforms, see the main [Curve3D](Curve3D.md) page.

## Topics

- [Arc Construction, Periodic Conversion, Splitting (v0.50.0)](#arc-construction-periodic-conversion-splitting-v0500) · [GC_MakeEllipse/Hyperbola Three-Point Constructors (v0.51.0)](#gc_makeellipsehyperbola-three-point-constructors-v0510) · [Interpolation Expansion, Length, Closest Point (v0.115.0)](#interpolation-expansion-length-closest-point-v01150)

---

## Arc Construction, Periodic Conversion, Splitting (v0.50.0)

### `Curve3D.arcOfHyperbola(center:direction:majorRadius:minorRadius:alpha1:alpha2:sense:)`

Creates a trimmed arc of a hyperbola between two parameter values.

```swift
public static func arcOfHyperbola(
    center: SIMD3<Double> = .zero,
    direction: SIMD3<Double> = SIMD3(0, 0, 1),
    majorRadius: Double,
    minorRadius: Double,
    alpha1: Double,
    alpha2: Double,
    sense: Bool = true
) -> Curve3D?
```

The hyperbola lies in the plane whose normal is `direction`. `alpha1` and `alpha2` are the start and end hyperbolic parameters (not angles). `sense: true` preserves the natural parameterization direction.

- **Parameters:** `center` — hyperbola centre; `direction` — plane normal; `majorRadius` — real semi-axis (a); `minorRadius` — imaginary semi-axis (b); `alpha1` — start parameter; `alpha2` — end parameter; `sense` — parameterization direction (`true` = natural).
- **Returns:** Trimmed hyperbolic arc, or `nil` on failure.
- **OCCT:** `GC_MakeArcOfHyperbola(gp_Hypr, alpha1, alpha2, sense)` → `Geom_TrimmedCurve`.
- **Example:**
  ```swift
  if let arc = Curve3D.arcOfHyperbola(
      majorRadius: 5, minorRadius: 3,
      alpha1: -1.0, alpha2: 1.0
  ) {
      let pts = arc.drawAdaptive()
  }
  ```

---

### `Curve3D.arcOfParabola(center:direction:focalDistance:alpha1:alpha2:sense:)`

Creates a trimmed arc of a parabola between two parameter values.

```swift
public static func arcOfParabola(
    center: SIMD3<Double> = .zero,
    direction: SIMD3<Double> = SIMD3(0, 0, 1),
    focalDistance: Double,
    alpha1: Double,
    alpha2: Double,
    sense: Bool = true
) -> Curve3D?
```

The parabola vertex is at `center` and the focal distance determines its opening width. `alpha1` and `alpha2` are the parabolic parameters bounding the arc.

- **Parameters:** `center` — parabola vertex; `direction` — plane normal; `focalDistance` — focal distance (must be > 0); `alpha1` — start parameter; `alpha2` — end parameter; `sense` — parameterization direction.
- **Returns:** Trimmed parabolic arc, or `nil` on failure.
- **OCCT:** `GC_MakeArcOfParabola(gp_Parab, alpha1, alpha2, sense)` → `Geom_TrimmedCurve`.
- **Example:**
  ```swift
  if let arc = Curve3D.arcOfParabola(focalDistance: 4, alpha1: -3.0, alpha2: 3.0) {
      let mid = arc.point(at: arc.domain.lowerBound + (arc.domain.upperBound - arc.domain.lowerBound) / 2)
  }
  ```

---

### `convertToPeriodic()`

Converts a closed BSpline curve to its periodic form.

```swift
public func convertToPeriodic() -> Curve3D?
```

The curve must be closed (start point equals end point). The resulting periodic BSpline seamlessly wraps around without a visible join. Use this before surfaces or wires that require periodic input.

- **Returns:** Periodic BSpline curve, or `nil` if the curve is not closed or periodic conversion is not possible.
- **OCCT:** `ShapeCustom_Curve::ConvertToPeriodic`.
- **Example:**
  ```swift
  if let closed = Curve3D.interpolate(points: [
      SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(-1, 0, 0), SIMD3(0, -1, 0)
  ], closed: true) {
      if let periodic = closed.convertToPeriodic() {
          #expect(periodic.isPeriodic)
      }
  }
  ```

---

### `SplitResult`

A pair of curve segments produced by `splitAt(parameter:)`.

```swift
public struct SplitResult {
    public let first: Curve3D   // segment before the split parameter
    public let second: Curve3D  // segment after the split parameter
}
```

---

### `splitAt(parameter:)`

Splits this curve at a parameter value into two segments.

```swift
public func splitAt(parameter: Double) -> SplitResult?
```

The split parameter must lie strictly inside the curve's domain (`domain.lowerBound < parameter < domain.upperBound`). Returns two curves whose domains cover `[first, parameter]` and `[parameter, last]` respectively.

- **Parameters:** `parameter` — split position within the open interior of `domain`.
- **Returns:** `SplitResult` with `first` and `second` segments, or `nil` if `parameter` is outside the open interior or splitting fails.
- **OCCT:** `ShapeUpgrade_SplitCurve3d::Perform` → `TColGeom_HArray1OfCurve`.
- **Example:**
  ```swift
  if let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)),
     let result = seg.splitAt(parameter: seg.domain.lowerBound + (seg.domain.upperBound - seg.domain.lowerBound) / 2) {
      #expect(result.first.endPoint.x < result.second.startPoint.x + 1e-6)
  }
  ```

---

## GC_MakeEllipse/Hyperbola Three-Point Constructors (v0.51.0)

### `Curve3D.ellipseThreePoints(s1:s2:center:)`

Creates a full ellipse defined by two axis endpoints and a centre.

```swift
public static func ellipseThreePoints(
    s1: SIMD3<Double>, s2: SIMD3<Double>, center: SIMD3<Double>
) -> Curve3D?
```

`s1` is the end of the major axis (determines major radius and axis direction); `s2` defines the extent of the minor axis. The plane is determined by the three points. This form is convenient when the three geometric points are known but the radii and normal must be derived.

- **Parameters:** `s1` — major axis endpoint; `s2` — minor axis extent point; `center` — ellipse centre.
- **Returns:** Full ellipse curve, or `nil` if the three points are degenerate or `GC_MakeEllipse` fails.
- **OCCT:** `GC_MakeEllipse(gp_Pnt s1, gp_Pnt s2, gp_Pnt center)`.
- **Example:**
  ```swift
  if let ellipse = Curve3D.ellipseThreePoints(
      s1: SIMD3(10, 0, 0), s2: SIMD3(0, 5, 0), center: .zero
  ) {
      let pts = ellipse.drawAdaptive()
  }
  ```

---

### `Curve3D.hyperbolaThreePoints(s1:s2:center:)`

Creates a full hyperbola defined by two axis endpoints and a centre.

```swift
public static func hyperbolaThreePoints(
    s1: SIMD3<Double>, s2: SIMD3<Double>, center: SIMD3<Double>
) -> Curve3D?
```

`s1` is the end of the real (transverse) axis; `s2` defines the extent of the imaginary (conjugate) axis. Analogous to `ellipseThreePoints` for hyperbolas.

- **Parameters:** `s1` — transverse axis endpoint; `s2` — conjugate axis extent point; `center` — hyperbola centre.
- **Returns:** Full hyperbola curve, or `nil` on failure.
- **OCCT:** `GC_MakeHyperbola(gp_Pnt s1, gp_Pnt s2, gp_Pnt center)`.
- **Example:**
  ```swift
  if let hyp = Curve3D.hyperbolaThreePoints(
      s1: SIMD3(5, 0, 0), s2: SIMD3(0, 3, 0), center: .zero
  ) {
      let arc = hyp.trimmed(from: -1.0, to: 1.0)
  }
  ```

---

## Interpolation Expansion, Length, Closest Point (v0.115.0)

### `Curve3D.interpolate(points:startTangent:endTangent:)`

Interpolates a BSpline through points with constrained endpoint tangents.

```swift
public static func interpolate(
    points: [SIMD3<Double>],
    startTangent: SIMD3<Double>,
    endTangent: SIMD3<Double>
) -> Curve3D?
```

Like `interpolate(points:closed:tolerance:)` but pins the tangent direction at the first and last interpolation points. Useful when the approach and departure directions are known (e.g. G1 join to adjacent geometry).

- **Parameters:** `points` — interpolation points (minimum 2); `startTangent` — tangent at the first point; `endTangent` — tangent at the last point.
- **Returns:** Interpolated BSpline, or `nil` on failure.
- **OCCT:** `GeomAPI_Interpolate::Load(startTangent, endTangent)` + `Perform()`.
- **Example:**
  ```swift
  if let curve = Curve3D.interpolate(
      points: [SIMD3(0, 0, 0), SIMD3(5, 5, 0), SIMD3(10, 0, 0)],
      startTangent: SIMD3(1, 0, 0),
      endTangent: SIMD3(1, 0, 0)
  ) {
      let len = curve.totalArcLength
  }
  ```

---

### `Curve3D.interpolate(points:tangents:tangentFlags:)`

Interpolates a BSpline with per-point tangent constraints.

```swift
public static func interpolate(
    points: [SIMD3<Double>],
    tangents: [SIMD3<Double>],
    tangentFlags: [Bool]
) -> Curve3D?
```

Each point can independently opt in or out of its tangent constraint via `tangentFlags`. All three arrays must have the same length.

- **Parameters:** `points` — interpolation points; `tangents` — desired tangent at each point; `tangentFlags` — `true` to enforce the corresponding tangent, `false` to ignore it.
- **Returns:** Interpolated BSpline, or `nil` if array lengths differ or interpolation fails.
- **OCCT:** `GeomAPI_Interpolate::Load(tangents, tangentFlags)` + `Perform()`.
- **Example:**
  ```swift
  let pts: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(5,3,0), SIMD3(10,0,0)]
  let tans: [SIMD3<Double>] = [SIMD3(1,1,0), SIMD3(1,0,0), SIMD3(1,-1,0)]
  let flags = [true, false, true]  // enforce only first and last tangents
  if let curve = Curve3D.interpolate(points: pts, tangents: tans, tangentFlags: flags) {
      let d = curve.domain
      #expect(curve.point(at: d.lowerBound).x < 1e-6)
  }
  ```

---

### `Curve3D.interpolate(points:parameters:)`

Interpolates a BSpline at explicitly specified parameter values.

```swift
public static func interpolate(
    points: [SIMD3<Double>],
    parameters: [Double]
) -> Curve3D?
```

Controls the parameterization explicitly — each point is placed at the corresponding parameter value. `points` and `parameters` must have the same length. Parameters must be strictly increasing.

- **Parameters:** `points` — interpolation points; `parameters` — parameter value for each point (same count, strictly increasing).
- **Returns:** Interpolated BSpline, or `nil` if counts differ or construction fails.
- **OCCT:** `GeomAPI_Interpolate(pts, params, Standard_False, tol)` + `Perform()`.
- **Example:**
  ```swift
  let pts: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(3,5,0), SIMD3(10,0,0)]
  let params = [0.0, 0.3, 1.0]
  if let curve = Curve3D.interpolate(points: pts, parameters: params) {
      #expect(abs(curve.point(at: 0.3).y - 5.0) < 0.5)
  }
  ```

---

### `Curve3D.interpolatePeriodic(points:)`

Interpolates a periodic (closed) BSpline through the given points.

```swift
public static func interpolatePeriodic(points: [SIMD3<Double>]) -> Curve3D?
```

The resulting curve is periodic: it passes through all points and closes smoothly back to the first point without an explicit closing segment. The first and last points need not coincide.

- **Parameters:** `points` — interpolation points (minimum 2, typically 3 or more for a non-degenerate loop).
- **Returns:** Periodic interpolated BSpline, or `nil` on failure.
- **OCCT:** `GeomAPI_Interpolate(pts, Standard_True, tol)` + `Perform()`.
- **Example:**
  ```swift
  if let loop = Curve3D.interpolatePeriodic(points: [
      SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(-1, 0, 0), SIMD3(0, -1, 0)
  ]) {
      #expect(loop.isPeriodic)
  }
  ```

---

### `Curve3D.approximate(points:degMin:degMax:continuity:tolerance:)`

Approximates a BSpline through points with degree and continuity control.

```swift
public static func approximate(
    points: [SIMD3<Double>],
    degMin: Int = 3,
    degMax: Int = 8,
    continuity: Int = 2,
    tolerance: Double = 1e-3
) -> Curve3D?
```

Unlike `interpolate`, the curve does not pass exactly through every point; it minimises deviation within `tolerance`. `continuity` maps to `GeomAbs_Shape`: 0=C0, 1=G1, 2=C1.

- **Parameters:** `points` — data points (minimum 2); `degMin` — minimum polynomial degree; `degMax` — maximum polynomial degree; `continuity` — minimum continuity order (0=C0, 1=G1, 2=C1); `tolerance` — maximum allowed deviation.
- **Returns:** Approximating BSpline, or `nil` on failure.
- **OCCT:** `GeomAPI_PointsToBSpline(pts, degMin, degMax, continuity, tolerance)`.
- **Example:**
  ```swift
  let pts: [SIMD3<Double>] = [
      SIMD3(0,0,0), SIMD3(2,3,0), SIMD3(5,1,0), SIMD3(8,4,0), SIMD3(10,0,0)
  ]
  if let curve = Curve3D.approximate(points: pts, degMin: 3, degMax: 8,
                                      continuity: 2, tolerance: 1e-3) {
      let len = curve.totalArcLength
  }
  ```

---

### `Curve3D.approximate(points:parameters:degMin:degMax:continuity:tolerance:)`

Approximates a BSpline with explicit parameter values at each point.

```swift
public static func approximate(
    points: [SIMD3<Double>],
    parameters: [Double],
    degMin: Int = 3,
    degMax: Int = 8,
    continuity: Int = 2,
    tolerance: Double = 1e-3
) -> Curve3D?
```

Combines approximation with explicit parameterization — useful when the data comes with known parameter stamps (e.g. timestamps or arc-length fractions).

- **Parameters:** `points` — data points; `parameters` — parameter for each point (same count, strictly increasing); `degMin`/`degMax` — degree bounds; `continuity` — minimum continuity; `tolerance` — maximum deviation.
- **Returns:** Approximating BSpline, or `nil` if counts differ or construction fails.
- **OCCT:** `GeomAPI_PointsToBSpline(pts, params, degMin, degMax, continuity, tolerance)`.
- **Example:**
  ```swift
  let pts: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(3,5,0), SIMD3(10,0,0)]
  let params = [0.0, 0.3, 1.0]
  if let curve = Curve3D.approximate(points: pts, parameters: params, degMin: 2, degMax: 6) {
      let len = curve.totalArcLength
  }
  ```

---

### `arcLength(from:to:)`

The arc length of this curve between two parameter values.

```swift
public func arcLength(from u1: Double, to u2: Double) -> Double
```

Non-optional; returns `0` if the curve is invalid or an exception occurs internally.

- **Parameters:** `u1` — start parameter; `u2` — end parameter (must satisfy `u1 ≤ u2`).
- **Returns:** Arc length in model units.
- **OCCT:** `GCPnts_AbscissaPoint::Length(GeomAdaptor_Curve(curve, u1, u2))`.
- **Example:**
  ```swift
  if let curve = Curve3D.interpolate(
      points: [SIMD3(0,0,0), SIMD3(10,0,0)],
      startTangent: SIMD3(1,0,0), endTangent: SIMD3(1,0,0)
  ) {
      let d = curve.domain
      let len = curve.arcLength(from: d.lowerBound, to: d.upperBound)
      #expect(len > 0)
  }
  ```

---

### `parameterAtLength(_:from:)`

Finds the parameter at a given arc-length distance from a starting parameter.

```swift
public func parameterAtLength(_ arcLength: Double, from startParam: Double? = nil) -> Double
```

Uses `GCPnts_AbscissaPoint` for accurate arc-length parameterisation. Positive `arcLength` advances forward; negative reverses. Returns `0` on internal failure.

- **Parameters:** `arcLength` — distance to advance along the curve; `startParam` — starting parameter (defaults to `domain.lowerBound`).
- **Returns:** The parameter value at the specified arc-length distance from `startParam`.
- **OCCT:** `GCPnts_AbscissaPoint(adaptor, arcLength, startParam)::Parameter`.
- **Example:**
  ```swift
  let line = Curve3D.segment(from: SIMD3(0,0,0), to: SIMD3(10,0,0))!
  let midParam = line.parameterAtLength(5.0)
  let midPt = line.point(at: midParam)
  #expect(abs(midPt.x - 5.0) < 0.01)
  ```

---

### `totalArcLength`

The total arc length of the curve over its full domain.

```swift
public var totalArcLength: Double { get }
```

Integrates the curve from `domain.lowerBound` to `domain.upperBound`. Distinct from the `length` property on the main page (which returns `Double?`); this always returns a `Double` (0 on failure).

- **Returns:** Total arc length in model units.
- **OCCT:** `GCPnts_AbscissaPoint::Length(GeomAdaptor_Curve(curve))`.
- **Example:**
  ```swift
  let circle = Curve3D.circle(center: .zero, normal: SIMD3(0,0,1), radius: 10)!
  let circumference = circle.totalArcLength
  #expect(abs(circumference - 2 * Double.pi * 10) < 0.1)
  ```

---

### `arcLengthBetween(_:_:)`

The arc length between two parameter values.

```swift
public func arcLengthBetween(_ param1: Double, _ param2: Double) -> Double
```

Like `arcLength(from:to:)` but with unlabelled parameters. Returns `0` on failure.

- **Parameters:** `param1` — first parameter; `param2` — second parameter.
- **Returns:** Arc length between the two parameters.
- **OCCT:** `GCPnts_AbscissaPoint::Length(adaptor, param1, param2)`.
- **Example:**
  ```swift
  let line = Curve3D.segment(from: SIMD3(0,0,0), to: SIMD3(10,0,0))!
  let d = line.domain
  let half = line.arcLengthBetween(d.lowerBound, (d.lowerBound + d.upperBound) / 2)
  #expect(abs(half - 5.0) < 0.01)
  ```

---

### `closestParameter(to:)`

Finds the parameter of the closest point on this curve to a given 3D point.

```swift
public func closestParameter(to point: SIMD3<Double>) -> Double
```

Uses a projection; returns `0` if projection finds no points or an exception occurs.

- **Parameters:** `point` — the query point in 3D space.
- **Returns:** Parameter `u` such that `self.point(at: u)` is the nearest point on the curve to `point`.
- **OCCT:** `GeomAPI_ProjectPointOnCurve::LowerDistanceParameter`.
- **Example:**
  ```swift
  if let line = Curve3D.line(through: .zero, direction: SIMD3(1,0,0)) {
      let param = line.closestParameter(to: SIMD3(5, 3, 0))
      #expect(abs(param - 5.0) < 0.1)
  }
  ```

---

### `splitAtContinuity(continuity:tolerance:maxSegments:)`

Splits this curve at continuity discontinuities, returning the resulting segments.

```swift
public func splitAtContinuity(
    continuity: Int = 1,
    tolerance: Double = 1e-6,
    maxSegments: Int = 32
) -> [Curve3D]
```

The curve is first converted to BSpline form, then split at C1 (or higher) discontinuities. For `continuity > 1` the implementation returns the single converted BSpline unchanged (higher-order splitting not yet implemented). Returns an empty array on failure.

- **Parameters:** `continuity` — continuity level to split at (0=C0, 1=C1); `tolerance` — discontinuity detection tolerance; `maxSegments` — maximum output segment count.
- **Returns:** Array of BSpline curve segments (at least one on success).
- **OCCT:** `GeomConvert::C0BSplineToArrayOfC1BSplineCurve` (for `continuity ≤ 1`).
- **Example:**
  ```swift
  if let curve = Curve3D.fit(points: [SIMD3(0,0,0), SIMD3(5,5,0), SIMD3(10,0,0)]) {
      let segs = curve.splitAtContinuity()
      #expect(segs.count >= 1)
  }
  ```

---

### `Curve3D.concatenateG1(curves:tolerance:)`

Concatenates an array of curves into a single BSpline with G1 continuity.

```swift
public static func concatenateG1(curves: [Curve3D], tolerance: Double = 1e-6) -> Curve3D?
```

Each input curve is converted to BSpline form before joining. Curves must connect end-to-end within `tolerance`.

- **Parameters:** `curves` — ordered array of curves to join; `tolerance` — endpoint gap tolerance.
- **Returns:** Joined BSpline curve, or `nil` if the array is empty or conversion fails.
- **OCCT:** `GeomConvert_CompCurveToBSplineCurve::Add` + `BSplineCurve()`.
- **Example:**
  ```swift
  let pts1: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(5,5,0), SIMD3(10,0,0)]
  let pts2: [SIMD3<Double>] = [SIMD3(10,0,0), SIMD3(15,-5,0), SIMD3(20,0,0)]
  if let c1 = Curve3D.fit(points: pts1),
     let c2 = Curve3D.fit(points: pts2),
     let joined = Curve3D.concatenateG1(curves: [c1, c2]) {
      #expect(joined.totalArcLength > c1.totalArcLength)
  }
  ```
