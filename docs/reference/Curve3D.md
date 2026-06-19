---
title: Curve3D
parent: API Reference
---

# Curve3D

A `Curve3D` is a parametric 3D curve — the Swift analog of OCCT's `Geom_Curve` class hierarchy. It wraps lines, segments, circles, ellipses, arcs, parabolas, hyperbolas, BSplines, Bezier curves, and specialty curves (helix, sine wave, TBezier, AHT Bezier) polymorphically behind a single opaque handle. Obtain a `Curve3D` via one of the static factory methods on `Curve3D`, by extracting it from an `Edge`, or by converting a `Wire` edge's underlying geometry.

> **Note:** `Curve3D` is documented across several pages — see also **Curve3D — Analytic Types**, **Curve3D — Analysis**, and **Curve3D — Construction**.

## Topics

- [Properties](#properties) · [Evaluation](#evaluation) · [Primitive Curves](#primitive-curves) · [BSpline & Bezier](#bspline--bezier) · [Operations](#operations) · [Conversion (GeomConvert)](#conversion-geomconvert) · [Draw (Discretization for Metal)](#draw-discretization-for-metal) · [Bounding Box](#bounding-box) · [Ellipse Arcs](#ellipse-arcs) · [Curve joining (v0.49.0)](#curve-joining-v0490) · [Curve3D Transform (v0.128.0)](#curve3d-transform-v01280) · [GeomEval Analytical Curve Factories (v0.130.0)](#geomeval-analytical-curve-factories-v01300) · [GeomEval TBezier / AHTBezier Curves, TransformedCurve (v0.131.0)](#geomeval-tbezier--ahtbezier-curves-transformedcurve-v01310)

---

## Properties

### `domain`

The parametric domain `[first, last]` of the curve.

```swift
public var domain: ClosedRange<Double> { get }
```

OCCT curves are defined over a specific parameter interval. Use `domain.lowerBound` and `domain.upperBound` when calling `point(at:)`, `d1(at:)`, `d2(at:)`, and related methods.

- **Returns:** A closed range of valid parameter values for this curve.
- **OCCT:** `Geom_Curve::FirstParameter` / `LastParameter`.
- **Example:**
  ```swift
  let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
  let d = circle.domain   // 0...2π
  let mid = circle.point(at: (d.lowerBound + d.upperBound) / 2)
  ```

---

### `isClosed`

Whether the curve forms a closed loop (start point equals end point).

```swift
public var isClosed: Bool { get }
```

- **OCCT:** `Geom_Curve::IsClosed`.
- **Example:**
  ```swift
  let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
  #expect(circle.isClosed == true)
  ```

---

### `isPeriodic`

Whether the curve repeats with a fixed period.

```swift
public var isPeriodic: Bool { get }
```

- **OCCT:** `Geom_Curve::IsPeriodic`.
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: .zero, to: SIMD3(10, 0, 0))!
  #expect(seg.isPeriodic == false)
  ```

---

### `period`

The period of the curve, or `nil` if the curve is not periodic.

```swift
public var period: Double? { get }
```

- **Returns:** Period value, or `nil` if `isPeriodic` is `false`.
- **OCCT:** `Geom_Curve::Period`.
- **Example:**
  ```swift
  let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
  if let p = circle.period { print(p) }  // ≈ 2π
  ```

---

### `startPoint`

The 3D point at the start of the parametric domain.

```swift
public var startPoint: SIMD3<Double> { get }
```

Convenience for `point(at: domain.lowerBound)`.

- **OCCT:** `Geom_Curve::Value(FirstParameter)`.
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: SIMD3(1, 2, 3), to: SIMD3(4, 5, 6))!
  print(seg.startPoint)  // SIMD3(1.0, 2.0, 3.0)
  ```

---

### `endPoint`

The 3D point at the end of the parametric domain.

```swift
public var endPoint: SIMD3<Double> { get }
```

Convenience for `point(at: domain.upperBound)`.

- **OCCT:** `Geom_Curve::Value(LastParameter)`.
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: SIMD3(1, 2, 3), to: SIMD3(4, 5, 6))!
  print(seg.endPoint)  // SIMD3(4.0, 5.0, 6.0)
  ```

---

## Evaluation

### `point(at:)`

Evaluates the 3D point on the curve at a given parameter.

```swift
public func point(at u: Double) -> SIMD3<Double>
```

- **Parameters:** `u` — parameter value within `domain`.
- **Returns:** 3D position on the curve.
- **OCCT:** `Geom_Curve::Value(u)`.
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: .zero, to: SIMD3(10, 0, 0))!
  let mid = seg.point(at: (seg.domain.lowerBound + seg.domain.upperBound) / 2)
  // mid ≈ SIMD3(5, 0, 0)
  ```

---

### `d1(at:)`

Evaluates the position and first derivative (tangent) at a parameter.

```swift
public func d1(at u: Double) -> (point: SIMD3<Double>, tangent: SIMD3<Double>)
```

The tangent vector is not normalised — its magnitude depends on the parameterization. For a unit tangent, normalise the result.

- **Parameters:** `u` — parameter value within `domain`.
- **Returns:** Tuple of position and first-derivative vector.
- **OCCT:** `Geom_Curve::D1(u, P, V1)`.
- **Example:**
  ```swift
  let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
  let (pos, tan) = circle.d1(at: 0)
  ```

---

### `d2(at:)`

Evaluates position, first derivative, and second derivative at a parameter.

```swift
public func d2(at u: Double) -> (point: SIMD3<Double>, d1: SIMD3<Double>, d2: SIMD3<Double>)
```

The second derivative is needed for curvature and osculating-circle calculations.

- **Parameters:** `u` — parameter value within `domain`.
- **Returns:** Tuple of position, first derivative, and second derivative.
- **OCCT:** `Geom_Curve::D2(u, P, V1, V2)`.
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: .zero, to: SIMD3(10, 0, 0))!
  let (pt, v1, v2) = seg.d2(at: 0)
  // v2 ≈ SIMD3(0, 0, 0) — zero second derivative for a line
  ```

---

## Primitive Curves

### `Curve3D.line(through:direction:)`

Creates an infinite line through a point in a direction.

```swift
public static func line(through point: SIMD3<Double>, direction: SIMD3<Double>) -> Curve3D?
```

The curve is not bounded; its domain is `(-∞, +∞)`. Use `trimmed(from:to:)` or `segment(from:to:)` if a bounded segment is required.

- **Parameters:** `point` — a point on the line; `direction` — line direction (need not be normalised).
- **Returns:** Line curve, or `nil` if `direction` is zero.
- **OCCT:** `Geom_Line(gp_Lin(point, direction))`.
- **Example:**
  ```swift
  let line = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0))
  ```

---

### `Curve3D.segment(from:to:)`

Creates a bounded line segment between two points.

```swift
public static func segment(from p1: SIMD3<Double>, to p2: SIMD3<Double>) -> Curve3D?
```

Equivalent to an infinite line trimmed to the arc-length interval `[0, distance(p1, p2)]`.

- **Parameters:** `p1` — start point; `p2` — end point.
- **Returns:** Segment curve, or `nil` if `p1` and `p2` coincide.
- **OCCT:** `GC_MakeSegment(p1, p2)` → `Geom_TrimmedCurve`.
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 5, 3))!
  print(seg.length)  // ≈ 11.58
  ```

---

### `Curve3D.circle(center:normal:radius:)`

Creates a full (unrimmed) circle in a plane defined by a centre point and normal.

```swift
public static func circle(center: SIMD3<Double>, normal: SIMD3<Double>, radius: Double) -> Curve3D?
```

The circle is periodic with period `2π`. The X axis of the local frame is determined by OCCT's `gp_Ax2` construction from `normal`.

- **Parameters:** `center` — circle centre; `normal` — plane normal; `radius` — circle radius (must be > 0).
- **Returns:** Full circle curve, or `nil` if `radius ≤ 0` or `normal` is zero.
- **OCCT:** `Geom_Circle(gp_Ax2(...), radius)`.
- **Example:**
  ```swift
  let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
  #expect(circle.isClosed)
  ```

---

### `Curve3D.arcOfCircle(start:interior:end:)`

Creates a circular arc through three specified points.

```swift
public static func arcOfCircle(start: SIMD3<Double>, interior: SIMD3<Double>, end: SIMD3<Double>) -> Curve3D?
```

OCCT derives the centre and radius from the three points. The arc sweeps from `start` through `interior` to `end`.

- **Parameters:** `start` — first endpoint; `interior` — a point on the arc; `end` — second endpoint.
- **Returns:** Arc curve, or `nil` if the three points are collinear or coincident.
- **OCCT:** `GC_MakeArcOfCircle(start, interior, end)` → `Geom_TrimmedCurve`.
- **Example:**
  ```swift
  let arc = Curve3D.arcOfCircle(
      start: SIMD3(5, 0, 0), interior: SIMD3(0, 5, 0), end: SIMD3(-5, 0, 0))!
  ```

---

### `Curve3D.arc(through:_:_:)`

Alias for `arcOfCircle(start:interior:end:)`.

```swift
public static func arc(through p1: SIMD3<Double>, _ pm: SIMD3<Double>, _ p2: SIMD3<Double>) -> Curve3D?
```

- **Parameters:** `p1` — first endpoint; `pm` — interior midpoint; `p2` — second endpoint.
- **Returns:** Arc curve, or `nil` if points are collinear or coincident.
- **OCCT:** `GC_MakeArcOfCircle` → `Geom_TrimmedCurve`.
- **Example:**
  ```swift
  let arc = Curve3D.arc(through: SIMD3(5, 0, 0), SIMD3(0, 5, 0), SIMD3(-5, 0, 0))
  ```

---

### `Curve3D.ellipse(center:normal:majorRadius:minorRadius:)`

Creates a full ellipse in a plane defined by a centre and normal.

```swift
public static func ellipse(center: SIMD3<Double>, normal: SIMD3<Double>,
                           majorRadius: Double, minorRadius: Double) -> Curve3D?
```

The major axis direction is determined automatically by `gp_Ax2`. Use `arcOfEllipse` to create a bounded arc.

- **Parameters:** `center` — ellipse centre; `normal` — plane normal; `majorRadius` — semi-major axis (must be > `minorRadius`); `minorRadius` — semi-minor axis (must be > 0).
- **Returns:** Full ellipse curve, or `nil` on failure.
- **OCCT:** `Geom_Ellipse(gp_Ax2(...), majorRadius, minorRadius)`.
- **Example:**
  ```swift
  let ellipse = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1),
                                majorRadius: 10, minorRadius: 5)!
  ```

---

### `Curve3D.parabola(center:normal:focal:)`

Creates a parabola with the given focal distance in a plane.

```swift
public static func parabola(center: SIMD3<Double>, normal: SIMD3<Double>, focal: Double) -> Curve3D?
```

- **Parameters:** `center` — vertex of the parabola; `normal` — plane normal; `focal` — focal distance (must be > 0).
- **Returns:** Parabola curve, or `nil` if `focal ≤ 0`.
- **OCCT:** `Geom_Parabola(gp_Ax2(...), focal)`.
- **Example:**
  ```swift
  let par = Curve3D.parabola(center: .zero, normal: SIMD3(0, 0, 1), focal: 2)
  ```

---

### `Curve3D.hyperbola(center:normal:majorRadius:minorRadius:)`

Creates a hyperbola in a plane defined by a centre and normal.

```swift
public static func hyperbola(center: SIMD3<Double>, normal: SIMD3<Double>,
                             majorRadius: Double, minorRadius: Double) -> Curve3D?
```

- **Parameters:** `center` — hyperbola centre; `normal` — plane normal; `majorRadius` — real semi-axis; `minorRadius` — imaginary semi-axis (both must be > 0).
- **Returns:** Hyperbola curve, or `nil` on failure.
- **OCCT:** `Geom_Hyperbola(gp_Ax2(...), majorRadius, minorRadius)`.
- **Example:**
  ```swift
  let hyp = Curve3D.hyperbola(center: .zero, normal: SIMD3(0, 0, 1),
                               majorRadius: 3, minorRadius: 2)
  ```

---

## BSpline & Bezier

### `Curve3D.bspline(poles:weights:knots:multiplicities:degree:)`

Creates a BSpline (or rational NURBS) curve from explicit poles, knots, multiplicities, and degree.

```swift
public static func bspline(poles: [SIMD3<Double>], weights: [Double]? = nil,
                           knots: [Double], multiplicities: [Int32],
                           degree: Int) -> Curve3D?
```

When `weights` is `nil`, all pole weights default to 1.0 (non-rational B-spline). Provides complete control over knot structure for CAD data exchange use cases.

- **Parameters:**
  - `poles` — control points (minimum 2).
  - `weights` — per-pole weights (`nil` = uniform 1.0).
  - `knots` — distinct knot values.
  - `multiplicities` — per-knot multiplicity.
  - `degree` — curve degree (≥ 1).
- **Returns:** BSpline/NURBS curve, or `nil` if parameters are invalid.
- **OCCT:** `Geom_BSplineCurve(poles, knots, multiplicities, degree)`.
- **Example:**
  ```swift
  let poles: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(5,10,0), SIMD3(10,0,0)]
  let knots = [0.0, 1.0]
  let mults: [Int32] = [4, 4]
  let bsp = Curve3D.bspline(poles: poles, knots: knots, multiplicities: mults, degree: 3)
  ```

---

### `Curve3D.bezier(poles:weights:)`

Creates a Bezier curve from control points, with optional rational weights.

```swift
public static func bezier(poles: [SIMD3<Double>], weights: [Double]? = nil) -> Curve3D?
```

The curve passes through the first and last pole. Interior poles act as attractors. The degree equals `poles.count - 1`.

- **Parameters:** `poles` — control points (minimum 2); `weights` — per-pole rational weights (`nil` = uniform 1.0).
- **Returns:** Bezier curve, or `nil` if fewer than 2 poles or construction fails.
- **OCCT:** `Geom_BezierCurve(poles)` or `Geom_BezierCurve(poles, weights)`.
- **Example:**
  ```swift
  let bez = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(5,10,0), SIMD3(10,0,0)])!
  print(bez.startPoint)  // SIMD3(0, 0, 0)
  ```

---

### `Curve3D.interpolate(points:closed:tolerance:)`

Creates a BSpline that passes exactly through all specified points.

```swift
public static func interpolate(points: [SIMD3<Double>], closed: Bool = false,
                               tolerance: Double = 1e-6) -> Curve3D?
```

Unlike `bspline(poles:…)`, the curve passes exactly through every point. Use `closed: true` for a periodic loop.

- **Parameters:** `points` — points the curve must pass through (minimum 2); `closed` — closed/periodic curve; `tolerance` — interpolation precision.
- **Returns:** Interpolated BSpline curve, or `nil` on failure.
- **OCCT:** `GeomAPI_Interpolate` + `Perform()`.
- **Example:**
  ```swift
  let pts: [SIMD3<Double>] = [
      SIMD3(0,0,0), SIMD3(5,5,0), SIMD3(10,0,0), SIMD3(15,5,0)
  ]
  if let curve = Curve3D.interpolate(points: pts) {
      print(curve.point(at: curve.domain.lowerBound))  // ≈ SIMD3(0,0,0)
  }
  ```

---

### `Curve3D.interpolate(points:startTangent:endTangent:tolerance:)`

Creates a BSpline through points with constrained endpoint tangents.

```swift
public static func interpolate(points: [SIMD3<Double>],
                               startTangent: SIMD3<Double>,
                               endTangent: SIMD3<Double>,
                               tolerance: Double = 1e-6) -> Curve3D?
```

- **Parameters:** `points` — interpolation points; `startTangent` — tangent at the first point; `endTangent` — tangent at the last point; `tolerance` — precision.
- **Returns:** Interpolated BSpline, or `nil` on failure.
- **OCCT:** `GeomAPI_Interpolate::Load(startTangent, endTangent)` + `Perform()`.
- **Example:**
  ```swift
  let pts: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(10, 10, 0)]
  let curve = Curve3D.interpolate(
      points: pts,
      startTangent: SIMD3(1, 0, 0),
      endTangent: SIMD3(0, 1, 0))
  ```

---

### `Curve3D.fit(points:minDegree:maxDegree:tolerance:)`

Fits a BSpline curve through points using least-squares approximation.

```swift
public static func fit(points: [SIMD3<Double>], minDegree: Int = 3, maxDegree: Int = 8,
                       tolerance: Double = 1e-3) -> Curve3D?
```

Unlike `interpolate`, the fitted curve does not necessarily pass through every point — it minimises squared error, which produces smoother results from noisy data.

- **Parameters:** `points` — data points; `minDegree`/`maxDegree` — degree range; `tolerance` — approximation error.
- **Returns:** Approximating BSpline, or `nil` on failure.
- **OCCT:** `GeomAPI_PointsToBSpline` (via `OCCTCurve3DFitPoints`).
- **Example:**
  ```swift
  let pts: [SIMD3<Double>] = stride(from: 0.0, to: 10.0, by: 0.5).map {
      SIMD3($0, sin($0), 0)
  }
  let curve = Curve3D.fit(points: pts)
  ```

---

### `poleCount`

The number of control poles, or `nil` if the curve is not a BSpline or Bezier.

```swift
public var poleCount: Int? { get }
```

- **Returns:** Pole count, or `nil` if the underlying curve has no poles (e.g. a line or circle).
- **OCCT:** `Geom_BSplineCurve::NbPoles` / `Geom_BezierCurve::NbPoles`.
- **Example:**
  ```swift
  let bez = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(5,5,0), SIMD3(10,0,0)])!
  #expect(bez.poleCount == 3)
  ```

---

### `poles`

The control points of a BSpline or Bezier curve.

```swift
public var poles: [SIMD3<Double>]? { get }
```

- **Returns:** Array of control points, or `nil` if the curve is not a BSpline or Bezier.
- **OCCT:** `Geom_BSplineCurve::Poles` / `Geom_BezierCurve::Poles`.
- **Example:**
  ```swift
  let original: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(5,5,0), SIMD3(10,0,0)]
  let bez = Curve3D.bezier(poles: original)!
  if let pts = bez.poles {
      #expect(pts.count == 3)
  }
  ```

---

### `degree`

The polynomial degree of a BSpline or Bezier curve.

```swift
public var degree: Int { get }
```

Returns `-1` if the underlying curve is not a BSpline or Bezier.

- **OCCT:** `Geom_BSplineCurve::Degree` / `Geom_BezierCurve::Degree`.
- **Example:**
  ```swift
  let bez = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(5,5,0), SIMD3(10,0,0)])!
  #expect(bez.degree == 2)
  ```

---

## Operations

### `trimmed(from:to:)`

Trims the curve to a sub-interval `[u1, u2]` of its parameter domain.

```swift
public func trimmed(from u1: Double, to u2: Double) -> Curve3D?
```

- **Parameters:** `u1` — lower trim parameter; `u2` — upper trim parameter (must satisfy `u1 < u2`).
- **Returns:** Trimmed curve, or `nil` if trimming fails.
- **OCCT:** `Geom_TrimmedCurve(curve, u1, u2)`.
- **Example:**
  ```swift
  let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
  let halfCircle = circle.trimmed(from: 0, to: .pi)
  ```

---

### `reversed()`

Returns a copy of the curve with reversed parameterization.

```swift
public func reversed() -> Curve3D?
```

The start and end points are swapped. The domain is adjusted to remain positive.

- **Returns:** Reversed curve, or `nil` on failure.
- **OCCT:** `Geom_Curve::Reversed()`.
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: SIMD3(0,0,0), to: SIMD3(10,0,0))!
  let rev = seg.reversed()!
  print(rev.startPoint)  // SIMD3(10, 0, 0)
  ```

---

### `translated(by:)`

Returns a copy of the curve translated by a displacement vector.

```swift
public func translated(by delta: SIMD3<Double>) -> Curve3D?
```

- **Parameters:** `delta` — translation vector.
- **Returns:** Translated curve, or `nil` on failure.
- **OCCT:** `Geom_Curve::Translate(gp_Vec)`.
- **Example:**
  ```swift
  let c = Curve3D.circle(center: .zero, normal: SIMD3(0,0,1), radius: 5)!
  let lifted = c.translated(by: SIMD3(0, 0, 10))!
  print(lifted.point(at: 0).z)  // 10.0
  ```

---

### `rotated(around:direction:angle:)`

Returns a copy of the curve rotated around an axis.

```swift
public func rotated(around axisOrigin: SIMD3<Double>, direction: SIMD3<Double>,
                    angle: Double) -> Curve3D?
```

- **Parameters:** `axisOrigin` — a point on the rotation axis; `direction` — axis direction; `angle` — rotation angle in radians.
- **Returns:** Rotated curve, or `nil` on failure.
- **OCCT:** `Geom_Curve::Rotate(gp_Ax1, angle)`.
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: SIMD3(1,0,0), to: SIMD3(10,0,0))!
  let rotated = seg.rotated(around: .zero, direction: SIMD3(0,0,1), angle: .pi/2)
  ```

---

### `scaled(from:factor:)`

Returns a copy of the curve scaled from a centre point.

```swift
public func scaled(from center: SIMD3<Double>, factor: Double) -> Curve3D?
```

- **Parameters:** `center` — fixed point of the scaling; `factor` — scale factor.
- **Returns:** Scaled curve, or `nil` on failure.
- **OCCT:** `Geom_Curve::Scale(gp_Pnt, factor)`.
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: SIMD3(0,0,0), to: SIMD3(10,0,0))!
  let doubled = seg.scaled(from: .zero, factor: 2)!
  print(doubled.length!)  // 20.0
  ```

---

### `mirrored(acrossPoint:)`

Returns a copy of the curve mirrored through a point.

```swift
public func mirrored(acrossPoint point: SIMD3<Double>) -> Curve3D?
```

- **Parameters:** `point` — the point of symmetry.
- **Returns:** Mirrored curve, or `nil` on failure.
- **OCCT:** `Geom_Curve::Mirror(gp_Pnt)`.
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: SIMD3(1,0,0), to: SIMD3(4,0,0))!
  let mir = seg.mirrored(acrossPoint: SIMD3(2.5, 0, 0))!
  ```

---

### `mirrored(acrossAxis:direction:)`

Returns a copy of the curve mirrored across an axis (line).

```swift
public func mirrored(acrossAxis point: SIMD3<Double>, direction: SIMD3<Double>) -> Curve3D?
```

- **Parameters:** `point` — a point on the axis; `direction` — axis direction.
- **Returns:** Mirrored curve, or `nil` on failure.
- **OCCT:** `Geom_Curve::Mirror(gp_Ax1)`.
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: SIMD3(0,1,0), to: SIMD3(10,1,0))!
  let mir = seg.mirrored(acrossAxis: .zero, direction: SIMD3(1,0,0))
  ```

---

### `mirrored(acrossPlane:normal:)`

Returns a copy of the curve mirrored across a plane.

```swift
public func mirrored(acrossPlane point: SIMD3<Double>, normal: SIMD3<Double>) -> Curve3D?
```

- **Parameters:** `point` — a point on the plane; `normal` — plane normal.
- **Returns:** Mirrored curve, or `nil` on failure.
- **OCCT:** `Geom_Curve::Mirror(gp_Ax2)`.
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: SIMD3(0,0,5), to: SIMD3(10,0,5))!
  let mir = seg.mirrored(acrossPlane: .zero, normal: SIMD3(0,0,1))
  ```

---

### `length`

The total arc length of the curve over its full domain.

```swift
public var length: Double? { get }
```

- **Returns:** Arc length in model units, or `nil` if measurement fails (e.g. infinite line with unbounded domain).
- **OCCT:** `GCPnts_AbscissaPoint::Length(adaptor)`.
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: .zero, to: SIMD3(3, 4, 0))!
  print(seg.length!)  // 5.0
  ```

---

### `length(from:to:)`

The arc length between two parameter values.

```swift
public func length(from u1: Double, to u2: Double) -> Double?
```

- **Parameters:** `u1` — start parameter; `u2` — end parameter.
- **Returns:** Arc length, or `nil` on failure.
- **OCCT:** `GCPnts_AbscissaPoint::Length(adaptor, u1, u2)`.
- **Example:**
  ```swift
  let circle = Curve3D.circle(center: .zero, normal: SIMD3(0,0,1), radius: 1)!
  let d = circle.domain
  let halfLen = circle.length(from: d.lowerBound, to: d.lowerBound + .pi)
  // halfLen ≈ π
  ```

---

## Conversion (GeomConvert)

### `toBSpline()`

Converts the curve to an equivalent `Geom_BSplineCurve` representation.

```swift
public func toBSpline() -> Curve3D?
```

Any analytic curve (line, circle, ellipse, arc) can be represented exactly as a rational BSpline. Required before using BSpline-specific query APIs.

- **Returns:** BSpline curve, or `nil` if conversion fails.
- **OCCT:** `GeomConvert::CurveToBSplineCurve(curve)`.
- **Example:**
  ```swift
  let circle = Curve3D.circle(center: .zero, normal: SIMD3(0,0,1), radius: 5)!
  if let bsp = circle.toBSpline() {
      print(bsp.poleCount!)  // NURBS representation of the circle
  }
  ```

---

### `toBezierSegments()`

Splits a BSpline curve into an array of Bezier segment curves.

```swift
public func toBezierSegments() -> [Curve3D]?
```

The input must be (or be convertible to) a `Geom_BSplineCurve`. Internally converts the curve to BSpline first if needed.

- **Returns:** Array of Bezier segment curves, or `nil` if the curve cannot be split (e.g. unbounded line) or the result is empty.
- **OCCT:** `GeomConvert_BSplineCurveToBezierCurve::Arc(i)`.
- **Example:**
  ```swift
  let bsp = Curve3D.interpolate(points: [
      SIMD3(0,0,0), SIMD3(3,4,0), SIMD3(6,0,0), SIMD3(9,4,0)
  ])!
  if let segs = bsp.toBezierSegments() {
      print(segs.count)  // number of Bezier arcs
  }
  ```

---

### `Curve3D.join(_:tolerance:)`

Joins multiple curves into a single BSpline by converting and concatenating them.

```swift
public static func join(_ curves: [Curve3D], tolerance: Double = 1e-6) -> Curve3D?
```

Each input curve is converted to BSpline form before joining. Curves must meet end-to-end within `tolerance`. Prefer `joined(curves:tolerance:)` (v0.49.0) which uses `GeomConvert_CompCurveToBSplineCurve` directly.

- **Parameters:** `curves` — curves to join in order; `tolerance` — gap tolerance for endpoint matching.
- **Returns:** Joined BSpline curve, or `nil` if the array is empty or joining fails.
- **OCCT:** `GeomConvert::CurveToBSplineCurve` + `GeomConvert_CompCurveToBSplineCurve`.
- **Example:**
  ```swift
  let seg1 = Curve3D.segment(from: SIMD3(0,0,0), to: SIMD3(5,0,0))!
  let seg2 = Curve3D.segment(from: SIMD3(5,0,0), to: SIMD3(10,5,0))!
  if let joined = Curve3D.join([seg1, seg2]) {
      print(joined.length!)
  }
  ```

---

### `approximated(tolerance:continuity:maxSegments:maxDegree:)`

Approximates this curve with a BSpline of specified continuity.

```swift
public func approximated(tolerance: Double = 1e-3, continuity: Int = 2,
                         maxSegments: Int = 100, maxDegree: Int = 8) -> Curve3D?
```

Useful for converting an analytical curve to a polynomial BSpline with controlled accuracy. `continuity` maps to `GeomAbs_Shape`: 0=C0, 1=G1, 2=C1, 3=G2, 4=C2.

- **Parameters:** `tolerance` — approximation error; `continuity` — minimum continuity order; `maxSegments` — maximum number of BSpline spans; `maxDegree` — maximum polynomial degree.
- **Returns:** Approximating BSpline, or `nil` on failure.
- **OCCT:** `GeomConvert_ApproxCurve(curve, tolerance, continuity, maxSegments, maxDegree)`.
- **Example:**
  ```swift
  let circle = Curve3D.circle(center: .zero, normal: SIMD3(0,0,1), radius: 5)!
  let approx = circle.approximated(tolerance: 0.01, continuity: 2)
  ```

---

## Draw (Discretization for Metal)

### `drawAdaptive(angularDeflection:chordalDeflection:maxPoints:)`

Discretizes the curve using adaptive angular and chordal deflection criteria.

```swift
public func drawAdaptive(angularDeflection: Double = 0.1,
                         chordalDeflection: Double = 0.01,
                         maxPoints: Int = 4096) -> [SIMD3<Double>]
```

Concentrates sample points where the curve bends sharply, producing an efficient polyline for Metal rendering. Returns an empty array if the curve cannot be discretized.

- **Parameters:** `angularDeflection` — maximum angle between consecutive tangents (radians); `chordalDeflection` — maximum chord-to-curve deviation; `maxPoints` — buffer size limit.
- **Returns:** Array of 3D points along the curve; never force-unwrap.
- **OCCT:** `GCPnts_TangentialDeflection(adaptor, angularDefl, chordalDefl)`.
- **Example:**
  ```swift
  let circle = Curve3D.circle(center: .zero, normal: SIMD3(0,0,1), radius: 5)!
  let pts = circle.drawAdaptive(angularDeflection: 0.05, chordalDeflection: 0.005)
  // pts suitable for Metal vertex buffer
  ```

---

### `drawUniform(pointCount:)`

Discretizes the curve at uniform arc-length intervals.

```swift
public func drawUniform(pointCount: Int) -> [SIMD3<Double>]
```

All consecutive point pairs are separated by the same arc-length. Good for even distribution of sample points regardless of curvature.

- **Parameters:** `pointCount` — desired number of output points.
- **Returns:** Array of 3D points, or empty array on failure.
- **OCCT:** `GCPnts_UniformAbscissa(adaptor, pointCount)`.
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: .zero, to: SIMD3(10, 0, 0))!
  let pts = seg.drawUniform(pointCount: 11)
  // pts[5] ≈ SIMD3(5, 0, 0)
  ```

---

### `drawDeflection(deflection:maxPoints:)`

Discretizes the curve using a pure chordal-deflection criterion.

```swift
public func drawDeflection(deflection: Double = 0.01,
                           maxPoints: Int = 4096) -> [SIMD3<Double>]
```

- **Parameters:** `deflection` — maximum chord-to-curve deviation; `maxPoints` — buffer size limit.
- **Returns:** Array of 3D points; empty on failure.
- **OCCT:** `GCPnts_UniformDeflection(adaptor, deflection)`.
- **Example:**
  ```swift
  let circle = Curve3D.circle(center: .zero, normal: SIMD3(0,0,1), radius: 10)!
  let pts = circle.drawDeflection(deflection: 0.01)
  ```

---

## Bounding Box

### `boundingBox`

The axis-aligned bounding box of the curve.

```swift
public var boundingBox: (min: SIMD3<Double>, max: SIMD3<Double>)? { get }
```

- **Returns:** Tuple of min and max corner coordinates, or `nil` if the bounding box cannot be computed (e.g. unbounded line).
- **OCCT:** `BRepBndLib::AddGenev` / `Bnd_Box` (via `OCCTCurve3DGetBoundingBox`).
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: SIMD3(1,2,3), to: SIMD3(4,5,6))!
  if let bb = seg.boundingBox {
      // bb.min ≈ SIMD3(1, 2, 3), bb.max ≈ SIMD3(4, 5, 6)
  }
  ```

---

## Ellipse Arcs

### `Curve3D.arcOfEllipse(center:normal:majorRadius:minorRadius:startAngle:endAngle:counterclockwise:)`

Creates an elliptical arc between two angular parameters.

```swift
public static func arcOfEllipse(center: SIMD3<Double>, normal: SIMD3<Double>,
                                majorRadius: Double, minorRadius: Double,
                                startAngle: Double, endAngle: Double,
                                counterclockwise: Bool = true) -> Curve3D?
```

The major axis direction is determined by OCCT's `gp_Ax2` construction from `normal`. Angles are measured from the major axis in the ellipse plane.

- **Parameters:** `center` — ellipse centre; `normal` — plane normal; `majorRadius` — semi-major axis; `minorRadius` — semi-minor axis; `startAngle`/`endAngle` — arc bounds in radians; `counterclockwise` — winding direction.
- **Returns:** Elliptical arc curve, or `nil` on failure.
- **OCCT:** `GC_MakeArcOfEllipse(elips, angle1, angle2, sense)` → `Geom_TrimmedCurve`.
- **Example:**
  ```swift
  let arc = Curve3D.arcOfEllipse(
      center: .zero, normal: SIMD3(0, 0, 1),
      majorRadius: 10, minorRadius: 5,
      startAngle: 0, endAngle: .pi)
  ```

---

### `Curve3D.arcOfEllipse(center:normal:majorRadius:minorRadius:from:to:counterclockwise:)`

Creates an elliptical arc through two endpoint points on the ellipse.

```swift
public static func arcOfEllipse(center: SIMD3<Double>, normal: SIMD3<Double>,
                                majorRadius: Double, minorRadius: Double,
                                from: SIMD3<Double>, to: SIMD3<Double>,
                                counterclockwise: Bool = true) -> Curve3D?
```

Both `from` and `to` must lie on the ellipse (within tolerance). Use this form when angles are not known but the endpoint coordinates are.

- **Parameters:** `center` — ellipse centre; `normal` — plane normal; `majorRadius`/`minorRadius` — ellipse radii; `from` — start point on the ellipse; `to` — end point on the ellipse; `counterclockwise` — winding direction.
- **Returns:** Elliptical arc curve, or `nil` if points do not lie on the ellipse or construction fails.
- **OCCT:** `GC_MakeArcOfEllipse(elips, from, to, sense)` → `Geom_TrimmedCurve`.
- **Example:**
  ```swift
  let arc = Curve3D.arcOfEllipse(
      center: .zero, normal: SIMD3(0, 0, 1),
      majorRadius: 10, minorRadius: 5,
      from: SIMD3(10, 0, 0), to: SIMD3(-10, 0, 0))
  ```

---

## Curve joining (v0.49.0)

### `Curve3D.joined(curves:tolerance:)`

Joins multiple curves end-to-end into a single BSpline curve.

```swift
public static func joined(curves: [Curve3D], tolerance: Double = 1e-6) -> Curve3D?
```

Uses `GeomConvert_CompCurveToBSplineCurve` to concatenate curves in order. Curves must meet end-to-end within `tolerance`. This is the preferred join method for v0.49.0+ (compared to the older `Curve3D.join(_:tolerance:)` which uses a different internal code path).

- **Parameters:** `curves` — ordered array of curves to concatenate; `tolerance` — endpoint gap tolerance.
- **Returns:** Joined BSpline curve, or `nil` if the array is empty or any gap exceeds `tolerance`.
- **OCCT:** `GeomConvert_CompCurveToBSplineCurve::Add` + `BSplineCurve()`.
- **Example:**
  ```swift
  let seg1 = Curve3D.segment(from: SIMD3(0,0,0), to: SIMD3(5,0,0))!
  let seg2 = Curve3D.segment(from: SIMD3(5,0,0), to: SIMD3(10,5,0))!
  if let joined = Curve3D.joined(curves: [seg1, seg2]) {
      print(joined.length!)
  }
  ```

---

## Curve3D Transform (v0.128.0)

In-place mutation methods that modify the curve handle directly, unlike the `translated(by:)` / `rotated(around:…)` family which return new copies.

### `TransformType`

Enum encoding the type of in-place transform to apply.

```swift
public enum TransformType: Int32, Sendable {
    case translation = 0
    case rotation = 1
    case scale = 2
    case mirrorPoint = 3
    case mirrorAxis = 4
    case mirrorPlane = 5
}
```

Used internally by the in-place transform methods below.

---

### `translate(dx:dy:dz:)`

Translates the curve in place by `(dx, dy, dz)`.

```swift
@discardableResult
public func translate(dx: Double, dy: Double, dz: Double) -> Bool
```

- **Parameters:** `dx`, `dy`, `dz` — displacement components.
- **Returns:** `true` on success.
- **OCCT:** `Geom_Curve::Translate(gp_Vec)` (in-place, via `OCCTCurve3DTransform`).
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: .zero, to: SIMD3(10, 0, 0))!
  seg.translate(dx: 0, dy: 5, dz: 0)
  print(seg.startPoint)  // SIMD3(0, 5, 0)
  ```

---

### `rotate(axisOrigin:axisDirection:angle:)`

Rotates the curve in place around an axis.

```swift
@discardableResult
public func rotate(axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>, angle: Double) -> Bool
```

- **Parameters:** `axisOrigin` — point on the rotation axis; `axisDirection` — axis direction; `angle` — rotation angle in radians.
- **Returns:** `true` on success.
- **OCCT:** `Geom_Curve::Rotate(gp_Ax1, angle)` (in-place).
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: SIMD3(1, 0, 0), to: SIMD3(10, 0, 0))!
  seg.rotate(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), angle: .pi / 2)
  ```

---

### `scale(center:factor:)`

Scales the curve in place from a centre point.

```swift
@discardableResult
public func scale(center: SIMD3<Double>, factor: Double) -> Bool
```

- **Parameters:** `center` — fixed point of scaling; `factor` — scale factor.
- **Returns:** `true` on success.
- **OCCT:** `Geom_Curve::Scale(gp_Pnt, factor)` (in-place).
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: .zero, to: SIMD3(5, 0, 0))!
  seg.scale(center: .zero, factor: 2)
  print(seg.length!)  // 10.0
  ```

---

### `mirrorPoint(_:)`

Mirrors the curve in place through a point.

```swift
@discardableResult
public func mirrorPoint(_ point: SIMD3<Double>) -> Bool
```

- **Parameters:** `point` — point of symmetry.
- **Returns:** `true` on success.
- **OCCT:** `Geom_Curve::Mirror(gp_Pnt)` (in-place).
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(4, 0, 0))!
  seg.mirrorPoint(SIMD3(2, 0, 0))
  ```

---

### `mirrorAxis(origin:direction:)`

Mirrors the curve in place through an axis (line).

```swift
@discardableResult
public func mirrorAxis(origin: SIMD3<Double>, direction: SIMD3<Double>) -> Bool
```

- **Parameters:** `origin` — a point on the mirror axis; `direction` — axis direction.
- **Returns:** `true` on success.
- **OCCT:** `Geom_Curve::Mirror(gp_Ax1)` (in-place).
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: SIMD3(0, 2, 0), to: SIMD3(10, 2, 0))!
  seg.mirrorAxis(origin: .zero, direction: SIMD3(1, 0, 0))
  ```

---

### `mirrorPlane(origin:normal:)`

Mirrors the curve in place through a plane.

```swift
@discardableResult
public func mirrorPlane(origin: SIMD3<Double>, normal: SIMD3<Double>) -> Bool
```

- **Parameters:** `origin` — a point on the mirror plane; `normal` — plane normal.
- **Returns:** `true` on success.
- **OCCT:** `Geom_Curve::Mirror(gp_Ax2)` (in-place).
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: SIMD3(0, 0, 3), to: SIMD3(10, 0, 3))!
  seg.mirrorPlane(origin: .zero, normal: SIMD3(0, 0, 1))
  ```

---

## GeomEval Analytical Curve Factories (v0.130.0)

### `Curve3D.circularHelix(radius:pitch:)`

Creates a circular helix curve.

```swift
public static func circularHelix(radius: Double, pitch: Double) -> Curve3D?
```

The helix is parameterized as `C(t) = R·cos(t)·X + R·sin(t)·Y + (P·t / 2π)·Z`, where R is the radius and P is the pitch. Negative `pitch` produces a left-handed helix.

- **Parameters:** `radius` — helix radius (must be > 0); `pitch` — axial advance per full 2π turn (may be negative for left-hand winding).
- **Returns:** Helix curve, or `nil` if `radius ≤ 0`.
- **OCCT:** `GeomEval_CircularHelixCurve(ax, radius, pitch)`.
- **Example:**
  ```swift
  if let helix = Curve3D.circularHelix(radius: 5, pitch: 2) {
      let pts = helix.drawAdaptive()
      // pts trace one full revolution from t=0 to t=2π
  }
  ```
- **Note:** Use `trimmed(from:to:)` to limit the helix to a specific number of turns: `helix.trimmed(from: 0, to: turns * 2 * .pi)`.

---

### `Curve3D.sineWave(amplitude:omega:phase:)`

Creates a 3D sine wave curve along the X axis.

```swift
public static func sineWave(amplitude: Double, omega: Double, phase: Double = 0.0) -> Curve3D?
```

Parameterized as `C(t) = t·X + A·sin(ω·t + φ)·Y`. The curve extends infinitely along X; trim it for practical use.

- **Parameters:** `amplitude` — wave amplitude (must be > 0); `omega` — angular frequency (must be > 0); `phase` — phase offset in radians (default 0).
- **Returns:** Sine wave curve, or `nil` if `amplitude ≤ 0` or `omega ≤ 0`.
- **OCCT:** `GeomEval_SineWaveCurve(ax, amplitude, omega, phase)`.
- **Example:**
  ```swift
  if let wave = Curve3D.sineWave(amplitude: 2, omega: .pi) {
      let bounded = wave.trimmed(from: 0, to: 4)
      let pts = bounded?.drawAdaptive() ?? []
  }
  ```

---

## GeomEval TBezier / AHTBezier Curves, TransformedCurve (v0.131.0)

### `translated(tx:ty:tz:)`

Creates a translated copy of this curve via `GeomAdaptor_TransformedCurve`.

```swift
public func translated(tx: Double, ty: Double, tz: Double) -> Curve3D?
```

This overload differs from `translated(by:)` — it uses `GeomAdaptor_TransformedCurve` internally, which may preserve the adaptor wrapper rather than modifying the underlying `Geom_Curve` handle.

- **Parameters:** `tx`, `ty`, `tz` — translation components.
- **Returns:** Translated curve, or `nil` on error.
- **OCCT:** `GeomAdaptor_TransformedCurve` (via `OCCTGeomAdaptorTransformedCurveCreate`).
- **Example:**
  ```swift
  let seg = Curve3D.segment(from: .zero, to: SIMD3(10, 0, 0))!
  if let moved = seg.translated(tx: 0, ty: 5, tz: 0) {
      print(moved.startPoint)  // SIMD3(0, 5, 0)
  }
  ```

---

### `Curve3D.tBezier(poles:alpha:)`

Creates a 3D Trigonometric Bezier curve.

```swift
public static func tBezier(poles: [SIMD3<Double>], alpha: Double) -> Curve3D?
```

Uses a trigonometric Bernstein-like basis `{1, sin(α·t), cos(α·t), …}`. The parameter domain is `[0, π/α]`. Can represent circular arcs exactly without rational weights.

- **Parameters:** `poles` — control points (count must be odd and ≥ 3); `alpha` — frequency parameter (must be > 0).
- **Returns:** TBezier curve, or `nil` if `poles.count < 3`, `poles.count` is even, or `alpha ≤ 0`.
- **OCCT:** `GeomEval_TBezierCurve(poles, alpha)`.
- **Example:**
  ```swift
  let poles: [SIMD3<Double>] = [SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(-1, 0, 0)]
  if let tb = Curve3D.tBezier(poles: poles, alpha: 1.0) {
      let pts = tb.drawAdaptive()
  }
  ```

---

### `Curve3D.tBezierRational(poles:weights:alpha:)`

Creates a rational 3D Trigonometric Bezier curve.

```swift
public static func tBezierRational(poles: [SIMD3<Double>], weights: [Double], alpha: Double) -> Curve3D?
```

Extends `tBezier` with per-pole rational weights (all must be > 0). Requires `poles.count == weights.count`.

- **Parameters:** `poles` — control points (odd count ≥ 3); `weights` — positive per-pole weights (same count as `poles`); `alpha` — frequency parameter (> 0).
- **Returns:** Rational TBezier curve, or `nil` if count constraints are violated or construction fails.
- **OCCT:** `GeomEval_TBezierCurve(poles, weights, alpha)`.
- **Example:**
  ```swift
  let poles: [SIMD3<Double>] = [SIMD3(1,0,0), SIMD3(0,1,0), SIMD3(-1,0,0)]
  let weights = [1.0, 0.707, 1.0]
  let tb = Curve3D.tBezierRational(poles: poles, weights: weights, alpha: 1.0)
  ```

---

### `Curve3D.ahtBezier(poles:algDegree:alpha:beta:)`

Creates a 3D Algebraic-Hyperbolic-Trigonometric (AHT) Bezier curve.

```swift
public static func ahtBezier(poles: [SIMD3<Double>], algDegree: Int, alpha: Double, beta: Double) -> Curve3D?
```

Uses a mixed basis: `{1, t, …, t^k, sinh(α·t), cosh(α·t), sin(β·t), cos(β·t)}`. The number of poles must equal `algDegree + 1 + 2*(alpha>0) + 2*(beta>0)`. Parameter range is `[0, 1]`.

- **Parameters:** `poles` — control points; `algDegree` — algebraic polynomial degree (≥ 0); `alpha` — hyperbolic frequency (≥ 0; 0 omits hyperbolic terms); `beta` — trigonometric frequency (≥ 0; 0 omits trig terms).
- **Returns:** AHT Bezier curve, or `nil` if the pole count is wrong or construction fails.
- **OCCT:** `GeomEval_AHTBezierCurve(poles, algDegree, alpha, beta)`.
- **Example:**
  ```swift
  // Degree-2 algebraic + trig: needs 3+0+2 = 5 poles
  let poles: [SIMD3<Double>] = [
      SIMD3(0,0,0), SIMD3(2,1,0), SIMD3(4,0,0),
      SIMD3(6,1,0), SIMD3(8,0,0)
  ]
  let aht = Curve3D.ahtBezier(poles: poles, algDegree: 2, alpha: 0, beta: .pi)
  ```

---

### `Curve3D.ahtBezierRational(poles:weights:algDegree:alpha:beta:)`

Creates a rational 3D AHT Bezier curve.

```swift
public static func ahtBezierRational(poles: [SIMD3<Double>], weights: [Double],
                                     algDegree: Int, alpha: Double, beta: Double) -> Curve3D?
```

Rational extension of `ahtBezier`. Requires `poles.count == weights.count` and all weights > 0.

- **Parameters:** `poles` — control points; `weights` — positive per-pole weights; `algDegree` — algebraic degree; `alpha` — hyperbolic frequency; `beta` — trigonometric frequency.
- **Returns:** Rational AHT Bezier curve, or `nil` if constraints are violated.
- **OCCT:** `GeomEval_AHTBezierCurve(poles, weights, algDegree, alpha, beta)`.
- **Example:**
  ```swift
  let poles: [SIMD3<Double>] = [
      SIMD3(0,0,0), SIMD3(2,1,0), SIMD3(4,0,0),
      SIMD3(6,1,0), SIMD3(8,0,0)
  ]
  let weights = [1.0, 1.0, 1.0, 1.0, 1.0]
  let aht = Curve3D.ahtBezierRational(poles: poles, weights: weights,
                                       algDegree: 2, alpha: 0, beta: .pi)
  ```
