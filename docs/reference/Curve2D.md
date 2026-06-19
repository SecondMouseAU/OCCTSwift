---
title: Curve2D
parent: API Reference
---

# Curve2D

A `Curve2D` is a parametric 2D curve — the Swift analog of OCCT's `Geom2d_Curve` class hierarchy. It wraps lines, segments, circles, arcs, ellipses, parabolas, hyperbolas, BSplines, and Bezier curves polymorphically behind a single opaque handle. `Curve2D` instances are used as pcurves (parameter-space curves on surfaces), 2D profiles, and constraint inputs. Obtain one via the static factory methods on `Curve2D`, `Curve2DGcc`, or by evaluating an existing curve at a point.

> **Note:** `Curve2D` is documented across several pages — see also **Curve2D — Analytic Types**, **Curve2D — Analysis**, and **Curve2D — Constraint Solvers**.

## Topics

- [Properties](#properties) · [Evaluation](#evaluation) · [Primitive Curves](#primitive-curves) · [Draw (Discretization for Metal)](#draw-discretization-for-metal) · [BSpline & Bezier](#bspline--bezier) · [Operations](#operations) · [Additional Arc Types](#additional-arc-types) · [Conversion Extras](#conversion-extras) · [Conversion](#conversion) · [Circle Construction](#circle-construction) · [Line Construction](#line-construction) · [Curve2D Transform (v0.128.0)](#curve2d-transform-v01280) · [Geom2dEval TBezier / AHTBezier Curves (v0.131.0)](#geom2deval-tbezier--ahtbezier-curves-v01310) · [v0.51.0: GC_MakeLine2d variants](#v0510-gc_makeline2d-variants)

---

## Properties

### `domain`

The parametric domain of the curve as a closed range `[first, last]`.

```swift
public var domain: ClosedRange<Double> { get }
```

Use `domain.lowerBound` and `domain.upperBound` when calling `point(at:)`, `d1(at:)`, or any parameter-based method.

- **Returns:** Closed range of valid parameter values.
- **OCCT:** `Geom2d_Curve::FirstParameter` / `LastParameter`.
- **Example:**
  ```swift
  let arc = Curve2D.arcOfCircle(center: .zero, radius: 5, startAngle: 0, endAngle: .pi)!
  let d = arc.domain   // 0...π
  let mid = arc.point(at: (d.lowerBound + d.upperBound) / 2)
  ```

---

### `isClosed`

Whether the curve forms a closed loop.

```swift
public var isClosed: Bool { get }
```

- **OCCT:** `Geom2d_Curve::IsClosed`.
- **Example:**
  ```swift
  let circle = Curve2D.circle(center: .zero, radius: 5)!
  #expect(circle.isClosed == true)
  ```

---

### `isPeriodic`

Whether the curve is periodic (e.g. a full circle or ellipse).

```swift
public var isPeriodic: Bool { get }
```

- **OCCT:** `Geom2d_Curve::IsPeriodic`.
- **Example:**
  ```swift
  let seg = Curve2D.segment(from: .zero, to: SIMD2(10, 0))!
  #expect(seg.isPeriodic == false)
  ```

---

### `period`

The period of the curve, or `nil` if the curve is not periodic.

```swift
public var period: Double? { get }
```

- **Returns:** Period value, or `nil` if `isPeriodic` is `false`.
- **OCCT:** `Geom2d_Curve::Period`.
- **Example:**
  ```swift
  let circle = Curve2D.circle(center: .zero, radius: 5)!
  if let p = circle.period { print(p) }  // ≈ 2π
  ```

---

### `startPoint`

The point at the start of the parameter domain.

```swift
public var startPoint: SIMD2<Double> { get }
```

Convenience for `point(at: domain.lowerBound)`.

- **OCCT:** `Geom2d_Curve::Value(FirstParameter)`.
- **Example:**
  ```swift
  let seg = Curve2D.segment(from: SIMD2(1, 2), to: SIMD2(4, 5))!
  print(seg.startPoint)  // SIMD2(1.0, 2.0)
  ```

---

### `endPoint`

The point at the end of the parameter domain.

```swift
public var endPoint: SIMD2<Double> { get }
```

Convenience for `point(at: domain.upperBound)`.

- **OCCT:** `Geom2d_Curve::Value(LastParameter)`.
- **Example:**
  ```swift
  let seg = Curve2D.segment(from: SIMD2(1, 2), to: SIMD2(4, 5))!
  print(seg.endPoint)  // SIMD2(4.0, 5.0)
  ```

---

## Evaluation

### `point(at:)`

Evaluates the 2D curve position at a parameter.

```swift
public func point(at u: Double) -> SIMD2<Double>
```

- **Parameters:** `u` — parameter value within `domain`.
- **Returns:** 2D point on the curve.
- **OCCT:** `Geom2d_Curve::Value(u)`.
- **Example:**
  ```swift
  let seg = Curve2D.segment(from: .zero, to: SIMD2(10, 0))!
  let mid = seg.point(at: (seg.domain.lowerBound + seg.domain.upperBound) / 2)
  // mid ≈ SIMD2(5, 0)
  ```

---

### `d1(at:)`

Evaluates the position and first derivative (tangent) at a parameter.

```swift
public func d1(at u: Double) -> (point: SIMD2<Double>, tangent: SIMD2<Double>)
```

The tangent vector is not normalised — its magnitude depends on the parameterisation.

- **Parameters:** `u` — parameter value within `domain`.
- **Returns:** Tuple of position and first-derivative vector.
- **OCCT:** `Geom2d_Curve::D1(u, P, V1)`.
- **Example:**
  ```swift
  let circle = Curve2D.circle(center: .zero, radius: 5)!
  let (pos, tan) = circle.d1(at: 0)
  ```

---

### `d2(at:)`

Evaluates position, first derivative, and second derivative at a parameter.

```swift
public func d2(at u: Double) -> (point: SIMD2<Double>, d1: SIMD2<Double>, d2: SIMD2<Double>)
```

- **Parameters:** `u` — parameter value within `domain`.
- **Returns:** Tuple of position, first derivative, and second derivative.
- **OCCT:** `Geom2d_Curve::D2(u, P, V1, V2)`.
- **Example:**
  ```swift
  let seg = Curve2D.segment(from: .zero, to: SIMD2(10, 0))!
  let (pt, v1, v2) = seg.d2(at: 0)
  // v2 ≈ SIMD2(0, 0) — zero second derivative for a line
  ```

---

## Primitive Curves

### `Curve2D.line(through:direction:)`

Creates an infinite line through a point in a direction.

```swift
public static func line(through point: SIMD2<Double>, direction: SIMD2<Double>) -> Curve2D?
```

The curve is unbounded; its domain is `(-∞, +∞)`. Use `segment(from:to:)` for a bounded segment.

- **Parameters:** `point` — a point on the line; `direction` — line direction (need not be normalised).
- **Returns:** Infinite line curve, or `nil` if `direction` is zero.
- **OCCT:** `Geom2d_Line(gp_Lin2d(point, direction))`.
- **Example:**
  ```swift
  let line = Curve2D.line(through: .zero, direction: SIMD2(1, 0))
  ```

---

### `Curve2D.segment(from:to:)`

Creates a bounded line segment between two points.

```swift
public static func segment(from p1: SIMD2<Double>, to p2: SIMD2<Double>) -> Curve2D?
```

- **Parameters:** `p1` — start point; `p2` — end point.
- **Returns:** Segment curve, or `nil` if the points coincide.
- **OCCT:** `Geom2d_TrimmedCurve` wrapping a `Geom2d_Line`.
- **Example:**
  ```swift
  let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 5))!
  print(seg.length!)  // ≈ 11.18
  ```

---

### `Curve2D.circle(center:radius:)`

Creates a full (untrimmed) circle.

```swift
public static func circle(center: SIMD2<Double>, radius: Double) -> Curve2D?
```

The circle is periodic with period `2π`. U=0 starts on the positive X axis of the local frame.

- **Parameters:** `center` — circle centre; `radius` — circle radius (must be > 0).
- **Returns:** Full circle curve, or `nil` if `radius ≤ 0`.
- **OCCT:** `Geom2d_Circle(gp_Circ2d(...))`.
- **Example:**
  ```swift
  let circle = Curve2D.circle(center: .zero, radius: 5)!
  #expect(circle.isClosed)
  ```

---

### `Curve2D.arcOfCircle(center:radius:startAngle:endAngle:)`

Creates a circular arc between two angles.

```swift
public static func arcOfCircle(center: SIMD2<Double>, radius: Double,
                               startAngle: Double, endAngle: Double) -> Curve2D?
```

- **Parameters:** `center` — circle centre; `radius` — radius (> 0); `startAngle` — start angle in radians; `endAngle` — end angle in radians.
- **Returns:** Circular arc, or `nil` on failure.
- **OCCT:** `GCE2d_MakeArcOfCircle` → `Geom2d_TrimmedCurve`.
- **Example:**
  ```swift
  let arc = Curve2D.arcOfCircle(center: .zero, radius: 5,
                                 startAngle: 0, endAngle: .pi / 2)!
  ```

---

### `Curve2D.arcThrough(_:_:_:)`

Creates a circular arc passing through three points.

```swift
public static func arcThrough(_ p1: SIMD2<Double>, _ p2: SIMD2<Double>,
                              _ p3: SIMD2<Double>) -> Curve2D?
```

OCCT derives the centre and radius from the three points. The arc sweeps from `p1` through `p2` to `p3`.

- **Parameters:** `p1` — start point; `p2` — interior point; `p3` — end point.
- **Returns:** Arc curve, or `nil` if points are collinear or coincident.
- **OCCT:** `GCE2d_MakeArcOfCircle(p1, p2, p3)` → `Geom2d_TrimmedCurve`.
- **Example:**
  ```swift
  let arc = Curve2D.arcThrough(SIMD2(5, 0), SIMD2(0, 5), SIMD2(-5, 0))
  ```

---

### `Curve2D.ellipse(center:majorRadius:minorRadius:rotation:)`

Creates a full ellipse.

```swift
public static func ellipse(center: SIMD2<Double>, majorRadius: Double,
                           minorRadius: Double, rotation: Double = 0) -> Curve2D?
```

- **Parameters:** `center` — ellipse centre; `majorRadius` — semi-major axis (must be ≥ `minorRadius`); `minorRadius` — semi-minor axis; `rotation` — rotation of the major axis from the X axis in radians (default 0).
- **Returns:** Full ellipse curve, or `nil` on failure.
- **OCCT:** `Geom2d_Ellipse(gp_Elips2d(...))`.
- **Example:**
  ```swift
  let ellipse = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5)!
  ```

---

### `Curve2D.arcOfEllipse(center:majorRadius:minorRadius:rotation:startAngle:endAngle:)`

Creates an elliptical arc between two angles.

```swift
public static func arcOfEllipse(center: SIMD2<Double>, majorRadius: Double,
                                minorRadius: Double, rotation: Double = 0,
                                startAngle: Double, endAngle: Double) -> Curve2D?
```

- **Parameters:** `center` — centre; `majorRadius` — semi-major axis; `minorRadius` — semi-minor axis; `rotation` — major-axis rotation in radians (default 0); `startAngle`/`endAngle` — arc bounds in radians.
- **Returns:** Elliptical arc, or `nil` on failure.
- **OCCT:** `GCE2d_MakeArcOfEllipse` → `Geom2d_TrimmedCurve`.
- **Example:**
  ```swift
  let arc = Curve2D.arcOfEllipse(center: .zero, majorRadius: 10, minorRadius: 5,
                                  startAngle: 0, endAngle: .pi)
  ```

---

### `Curve2D.parabola(focus:direction:focalLength:)`

Creates a parabola.

```swift
public static func parabola(focus: SIMD2<Double>, direction: SIMD2<Double>,
                            focalLength: Double) -> Curve2D?
```

- **Parameters:** `focus` — focus point; `direction` — axis direction from vertex toward focus; `focalLength` — distance from vertex to focus (must be > 0).
- **Returns:** Parabola curve, or `nil` if `focalLength ≤ 0`.
- **OCCT:** `Geom2d_Parabola(gp_Parab2d(...))`.
- **Example:**
  ```swift
  let par = Curve2D.parabola(focus: SIMD2(0, 2), direction: SIMD2(0, 1), focalLength: 2)
  ```

---

### `Curve2D.hyperbola(center:majorRadius:minorRadius:rotation:)`

Creates a hyperbola.

```swift
public static func hyperbola(center: SIMD2<Double>, majorRadius: Double,
                             minorRadius: Double, rotation: Double = 0) -> Curve2D?
```

- **Parameters:** `center` — hyperbola centre; `majorRadius` — real semi-axis; `minorRadius` — imaginary semi-axis (both must be > 0); `rotation` — major-axis rotation in radians (default 0).
- **Returns:** Hyperbola curve, or `nil` on failure.
- **OCCT:** `Geom2d_Hyperbola(gp_Hypr2d(...))`.
- **Example:**
  ```swift
  let hyp = Curve2D.hyperbola(center: .zero, majorRadius: 3, minorRadius: 2)
  ```

---

## Draw (Discretization for Metal)

### `drawAdaptive(angularDeflection:chordalDeflection:maxPoints:)`

Adaptively discretizes the curve using angular and chordal deflection criteria.

```swift
public func drawAdaptive(angularDeflection: Double = 0.1,
                         chordalDeflection: Double = 0.01,
                         maxPoints: Int = 4096) -> [SIMD2<Double>]
```

Concentrates sample points where curvature is high and fewer where the curve is straight, producing an efficient polyline for Metal rendering.

- **Parameters:** `angularDeflection` — maximum angle between consecutive tangents (radians); `chordalDeflection` — maximum chord-to-curve deviation; `maxPoints` — buffer size limit.
- **Returns:** Array of 2D points along the curve; empty on failure.
- **OCCT:** `GCPnts_TangentialDeflection` (via `OCCTCurve2DDrawAdaptive`).
- **Example:**
  ```swift
  let circle = Curve2D.circle(center: .zero, radius: 5)!
  let pts = circle.drawAdaptive(angularDeflection: 0.05, chordalDeflection: 0.005)
  // pts suitable for Metal vertex buffer
  ```

---

### `drawUniform(pointCount:)`

Discretizes the curve at exactly `pointCount` uniformly-spaced arc-length points.

```swift
public func drawUniform(pointCount: Int) -> [SIMD2<Double>]
```

- **Parameters:** `pointCount` — desired number of output points.
- **Returns:** Array of 2D points; empty on failure.
- **OCCT:** `GCPnts_UniformAbscissa` (via `OCCTCurve2DDrawUniform`).
- **Example:**
  ```swift
  let seg = Curve2D.segment(from: .zero, to: SIMD2(10, 0))!
  let pts = seg.drawUniform(pointCount: 11)
  // pts[5] ≈ SIMD2(5, 0)
  ```

---

### `drawDeflection(deflection:maxPoints:)`

Discretizes the curve using a maximum chordal-deflection criterion.

```swift
public func drawDeflection(deflection: Double = 0.01,
                           maxPoints: Int = 4096) -> [SIMD2<Double>]
```

- **Parameters:** `deflection` — maximum chord-to-curve deviation; `maxPoints` — buffer size limit.
- **Returns:** Array of 2D points; empty on failure.
- **OCCT:** `GCPnts_UniformDeflection` (via `OCCTCurve2DDrawDeflection`).
- **Example:**
  ```swift
  let circle = Curve2D.circle(center: .zero, radius: 10)!
  let pts = circle.drawDeflection(deflection: 0.01)
  ```

---

## BSpline & Bezier

### `Curve2D.bspline(poles:weights:knots:multiplicities:degree:)`

Creates a BSpline (or rational NURBS) curve from control points, knots, multiplicities, and degree.

```swift
public static func bspline(poles: [SIMD2<Double>], weights: [Double]? = nil,
                           knots: [Double], multiplicities: [Int32],
                           degree: Int) -> Curve2D?
```

When `weights` is `nil` all pole weights default to 1.0 (non-rational BSpline).

- **Parameters:**
  - `poles` — control points (minimum 2).
  - `weights` — per-pole weights (`nil` = uniform 1.0).
  - `knots` — distinct knot values.
  - `multiplicities` — per-knot multiplicity.
  - `degree` — curve degree (≥ 1).
- **Returns:** BSpline/NURBS curve, or `nil` if parameters are invalid.
- **OCCT:** `Geom2d_BSplineCurve(poles, knots, multiplicities, degree)`.
- **Example:**
  ```swift
  let poles: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 0)]
  let knots = [0.0, 1.0]
  let mults: [Int32] = [4, 4]
  let bsp = Curve2D.bspline(poles: poles, knots: knots, multiplicities: mults, degree: 3)
  ```

---

### `Curve2D.bezier(poles:weights:)`

Creates a Bezier curve from control points with optional rational weights.

```swift
public static func bezier(poles: [SIMD2<Double>], weights: [Double]? = nil) -> Curve2D?
```

The curve passes through the first and last pole. The degree equals `poles.count − 1`.

- **Parameters:** `poles` — control points (minimum 2); `weights` — per-pole rational weights (`nil` = uniform 1.0).
- **Returns:** Bezier curve, or `nil` if fewer than 2 poles or construction fails.
- **OCCT:** `Geom2d_BezierCurve(poles)` or the weighted overload.
- **Example:**
  ```swift
  let bez = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 0)])!
  print(bez.startPoint)  // SIMD2(0, 0)
  ```

---

### `Curve2D.interpolate(through:closed:tolerance:)`

Interpolates a smooth BSpline curve through the given points.

```swift
public static func interpolate(through points: [SIMD2<Double>], closed: Bool = false,
                               tolerance: Double = 1e-6) -> Curve2D?
```

The curve passes exactly through every point. Use `closed: true` for a periodic loop.

- **Parameters:** `points` — interpolation points (minimum 2); `closed` — closed/periodic curve; `tolerance` — point coincidence tolerance.
- **Returns:** Interpolated BSpline, or `nil` on failure.
- **OCCT:** `Geom2dAPI_Interpolate` + `Perform()`.
- **Example:**
  ```swift
  let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0)]
  if let c = Curve2D.interpolate(through: pts) {
      print(c.point(at: c.domain.lowerBound))  // ≈ SIMD2(0, 0)
  }
  ```

---

### `Curve2D.interpolate(through:startTangent:endTangent:tolerance:)`

Interpolates through points with constrained endpoint tangents.

```swift
public static func interpolate(through points: [SIMD2<Double>],
                               startTangent: SIMD2<Double>,
                               endTangent: SIMD2<Double>,
                               tolerance: Double = 1e-6) -> Curve2D?
```

- **Parameters:** `points` — interpolation points; `startTangent` — tangent at the first point; `endTangent` — tangent at the last point; `tolerance` — precision.
- **Returns:** Interpolated BSpline, or `nil` on failure.
- **OCCT:** `Geom2dAPI_Interpolate::Load(startTangent, endTangent)` + `Perform()`.
- **Example:**
  ```swift
  let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(10, 10)]
  let c = Curve2D.interpolate(through: pts,
                               startTangent: SIMD2(1, 0),
                               endTangent: SIMD2(0, 1))
  ```

---

### `Curve2D.interpolate(through:tangents:closed:tolerance:)`

Interpolates through points with per-point tangent constraints at arbitrary indices.

```swift
public static func interpolate(through points: [SIMD2<Double>],
                               tangents: [Int: SIMD2<Double>],
                               closed: Bool = false,
                               tolerance: Double = 1e-6) -> Curve2D?
```

Use this when you need tangent continuity at specific interior transition points — for example where a straight section meets a circular arc.

- **Parameters:** `points` — interpolation points (≥ 2); `tangents` — dictionary mapping point index to unit tangent direction (unconstrained indices use C2); `closed` — closed/periodic curve; `tolerance` — coincidence tolerance.
- **Returns:** Interpolated BSpline, or `nil` on failure.
- **OCCT:** `OCCTCurve2DInterpolateWithInteriorTangents`.
- **Example:**
  ```swift
  let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0)]
  let c = Curve2D.interpolate(through: pts, tangents: [1: SIMD2(1, 0)])
  ```

---

### `Curve2D.fit(through:minDegree:maxDegree:tolerance:)`

Approximates a BSpline curve fitting through points within tolerance.

```swift
public static func fit(through points: [SIMD2<Double>], minDegree: Int = 3,
                       maxDegree: Int = 8, tolerance: Double = 1e-3) -> Curve2D?
```

Unlike `interpolate`, the fitted curve minimises squared error — it does not necessarily pass exactly through every point. Good for noisy data.

- **Parameters:** `points` — data points; `minDegree`/`maxDegree` — degree range; `tolerance` — approximation error.
- **Returns:** Approximating BSpline, or `nil` on failure.
- **OCCT:** `Geom2dAPI_PointsToBSpline` (via `OCCTCurve2DFitPoints`).
- **Example:**
  ```swift
  let pts: [SIMD2<Double>] = stride(from: 0.0, to: 10.0, by: 0.5).map {
      SIMD2($0, sin($0))
  }
  let c = Curve2D.fit(through: pts)
  ```

---

### `poleCount`

The number of control points (poles), or `nil` if not a BSpline or Bezier.

```swift
public var poleCount: Int? { get }
```

- **Returns:** Pole count, or `nil`.
- **OCCT:** `Geom2d_BSplineCurve::NbPoles` / `Geom2d_BezierCurve::NbPoles`.
- **Example:**
  ```swift
  let bez = Curve2D.bezier(poles: [SIMD2(0,0), SIMD2(5,5), SIMD2(10,0)])!
  #expect(bez.poleCount == 3)
  ```

---

### `poles`

The control points (poles), or `nil` if not a BSpline or Bezier.

```swift
public var poles: [SIMD2<Double>]? { get }
```

- **Returns:** Array of 2D control points, or `nil`.
- **OCCT:** `Geom2d_BSplineCurve::Poles` / `Geom2d_BezierCurve::Poles`.
- **Example:**
  ```swift
  let bez = Curve2D.bezier(poles: [SIMD2(0,0), SIMD2(5,5), SIMD2(10,0)])!
  if let pts = bez.poles { #expect(pts.count == 3) }
  ```

---

### `degree`

The polynomial degree, or `nil` if not a BSpline or Bezier.

```swift
public var degree: Int? { get }
```

- **OCCT:** `Geom2d_BSplineCurve::Degree` / `Geom2d_BezierCurve::Degree`.
- **Example:**
  ```swift
  let bez = Curve2D.bezier(poles: [SIMD2(0,0), SIMD2(5,5), SIMD2(10,0)])!
  #expect(bez.degree == 2)
  ```

---

## Operations

### `trimmed(from:to:)`

Creates a trimmed copy of this curve between two parameters.

```swift
public func trimmed(from u1: Double, to u2: Double) -> Curve2D?
```

- **Parameters:** `u1` — lower trim parameter; `u2` — upper trim parameter (must satisfy `u1 < u2`).
- **Returns:** Trimmed curve, or `nil` on failure.
- **OCCT:** `Geom2d_TrimmedCurve(curve, u1, u2)`.
- **Example:**
  ```swift
  let circle = Curve2D.circle(center: .zero, radius: 5)!
  let halfArc = circle.trimmed(from: 0, to: .pi)
  ```

---

### `offset(by:)`

Creates an offset curve at the given distance.

```swift
public func offset(by distance: Double) -> Curve2D?
```

Positive distance offsets to the left of the curve direction.

- **Parameters:** `distance` — signed offset distance.
- **Returns:** Offset curve, or `nil` on failure.
- **OCCT:** `Geom2d_OffsetCurve(curve, distance)`.
- **Example:**
  ```swift
  let seg = Curve2D.segment(from: .zero, to: SIMD2(10, 0))!
  let parallel = seg.offset(by: 5)
  ```

---

### `reversed()`

Creates a reversed copy of this curve (parameter direction flipped).

```swift
public func reversed() -> Curve2D?
```

Start and end points are swapped.

- **Returns:** Reversed curve, or `nil` on failure.
- **OCCT:** `Geom2d_Curve::Reversed()`.
- **Example:**
  ```swift
  let seg = Curve2D.segment(from: .zero, to: SIMD2(10, 0))!
  let rev = seg.reversed()!
  print(rev.startPoint)  // SIMD2(10, 0)
  ```

---

### `translated(by:)`

Creates a translated copy of this curve.

```swift
public func translated(by delta: SIMD2<Double>) -> Curve2D?
```

- **Parameters:** `delta` — translation vector.
- **Returns:** Translated curve, or `nil` on failure.
- **OCCT:** `Geom2d_Curve::Translated(gp_Vec2d)`.
- **Example:**
  ```swift
  let c = Curve2D.circle(center: .zero, radius: 5)!
  let moved = c.translated(by: SIMD2(10, 0))!
  print(moved.point(at: 0).x)  // ≈ 15.0
  ```

---

### `rotated(around:angle:)`

Creates a rotated copy of this curve.

```swift
public func rotated(around center: SIMD2<Double>, angle: Double) -> Curve2D?
```

- **Parameters:** `center` — rotation centre point; `angle` — rotation angle in radians.
- **Returns:** Rotated curve, or `nil` on failure.
- **OCCT:** `Geom2d_Curve::Rotated(gp_Pnt2d, angle)`.
- **Example:**
  ```swift
  let seg = Curve2D.segment(from: SIMD2(1, 0), to: SIMD2(10, 0))!
  let rotated = seg.rotated(around: .zero, angle: .pi / 2)
  ```

---

### `scaled(from:factor:)`

Creates a scaled copy of this curve.

```swift
public func scaled(from center: SIMD2<Double>, factor: Double) -> Curve2D?
```

- **Parameters:** `center` — fixed point of scaling; `factor` — scale factor.
- **Returns:** Scaled curve, or `nil` on failure.
- **OCCT:** `Geom2d_Curve::Scaled(gp_Pnt2d, factor)`.
- **Example:**
  ```swift
  let seg = Curve2D.segment(from: .zero, to: SIMD2(5, 0))!
  let doubled = seg.scaled(from: .zero, factor: 2)!
  print(doubled.length!)  // 10.0
  ```

---

### `mirrored(acrossLine:direction:)`

Creates a copy mirrored across an axis line.

```swift
public func mirrored(acrossLine point: SIMD2<Double>, direction: SIMD2<Double>) -> Curve2D?
```

- **Parameters:** `point` — a point on the mirror axis; `direction` — axis direction.
- **Returns:** Mirrored curve, or `nil` on failure.
- **OCCT:** `Geom2d_Curve::Mirror(gp_Ax2d)`.
- **Example:**
  ```swift
  let seg = Curve2D.segment(from: SIMD2(0, 1), to: SIMD2(10, 1))!
  let mir = seg.mirrored(acrossLine: .zero, direction: SIMD2(1, 0))
  ```

---

### `mirrored(acrossPoint:)`

Creates a copy mirrored through a point.

```swift
public func mirrored(acrossPoint point: SIMD2<Double>) -> Curve2D?
```

- **Parameters:** `point` — the point of symmetry.
- **Returns:** Mirrored curve, or `nil` on failure.
- **OCCT:** `Geom2d_Curve::Mirror(gp_Pnt2d)`.
- **Example:**
  ```swift
  let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(4, 0))!
  let mir = seg.mirrored(acrossPoint: SIMD2(2, 0))!
  ```

---

### `length`

The total arc length of the curve, or `nil` on error.

```swift
public var length: Double? { get }
```

- **Returns:** Arc length in model units, or `nil` if measurement fails.
- **OCCT:** `GCPnts_AbscissaPoint::Length(adaptor)`.
- **Example:**
  ```swift
  let seg = Curve2D.segment(from: .zero, to: SIMD2(3, 4))!
  print(seg.length!)  // 5.0
  ```

---

### `length(from:to:)`

Arc length between two parameter values.

```swift
public func length(from u1: Double, to u2: Double) -> Double?
```

- **Parameters:** `u1` — start parameter; `u2` — end parameter.
- **Returns:** Arc length, or `nil` on failure.
- **OCCT:** `GCPnts_AbscissaPoint::Length(adaptor, u1, u2)`.
- **Example:**
  ```swift
  let circle = Curve2D.circle(center: .zero, radius: 1)!
  let d = circle.domain
  let halfLen = circle.length(from: d.lowerBound, to: d.lowerBound + .pi)
  // halfLen ≈ π
  ```

---

### `parameterAtLength(_:from:)`

Returns the curve parameter at the given arc-length distance from a starting parameter.

```swift
public func parameterAtLength(_ arcLength: Double, from fromParameter: Double? = nil) -> Double?
```

Use this to trim a curve to a specific arc length, or to place features at measured positions along a composite curve.

- **Parameters:** `arcLength` — desired arc-length distance; may be negative to travel in reverse; `fromParameter` — starting parameter (defaults to `domain.lowerBound`).
- **Returns:** Parameter value at the given arc-length offset, or `nil` if the computation fails.
- **OCCT:** `GCPnts_AbscissaPoint` (via `OCCTCurve2DParameterAtLength`).
- **Example:**
  ```swift
  let seg = Curve2D.segment(from: .zero, to: SIMD2(10, 0))!
  if let u = seg.parameterAtLength(5) {
      let pt = seg.point(at: u)  // ≈ SIMD2(5, 0)
  }
  ```

---

## Additional Arc Types

### `Curve2D.arcOfHyperbola(center:majorRadius:minorRadius:rotation:startAngle:endAngle:)`

Creates a trimmed arc of a hyperbola.

```swift
public static func arcOfHyperbola(center: SIMD2<Double>, majorRadius: Double,
                                  minorRadius: Double, rotation: Double = 0,
                                  startAngle: Double, endAngle: Double) -> Curve2D?
```

- **Parameters:** `center` — hyperbola centre; `majorRadius` — real semi-axis; `minorRadius` — imaginary semi-axis; `rotation` — major-axis rotation in radians (default 0); `startAngle`/`endAngle` — arc bounds in radians.
- **Returns:** Hyperbolic arc, or `nil` on failure.
- **OCCT:** `GCE2d_MakeArcOfHyperbola` → `Geom2d_TrimmedCurve`.
- **Example:**
  ```swift
  let arc = Curve2D.arcOfHyperbola(center: .zero, majorRadius: 3, minorRadius: 2,
                                    startAngle: -1, endAngle: 1)
  ```

---

### `Curve2D.arcOfParabola(focus:direction:focalLength:startParam:endParam:)`

Creates a trimmed arc of a parabola.

```swift
public static func arcOfParabola(focus: SIMD2<Double>, direction: SIMD2<Double>,
                                 focalLength: Double,
                                 startParam: Double, endParam: Double) -> Curve2D?
```

- **Parameters:** `focus` — focus point; `direction` — axis direction; `focalLength` — focal distance (> 0); `startParam`/`endParam` — parameter range of the arc.
- **Returns:** Parabolic arc, or `nil` on failure.
- **OCCT:** `GCE2d_MakeArcOfParabola` → `Geom2d_TrimmedCurve`.
- **Example:**
  ```swift
  let arc = Curve2D.arcOfParabola(focus: SIMD2(0, 1), direction: SIMD2(0, 1),
                                   focalLength: 1, startParam: -2, endParam: 2)
  ```

---

## Conversion Extras

### `approximated(tolerance:continuity:maxSegments:maxDegree:)`

Re-approximates this curve as a BSpline with controlled degree and continuity.

```swift
public func approximated(tolerance: Double = 1e-3, continuity: Int = 2,
                         maxSegments: Int = 100, maxDegree: Int = 8) -> Curve2D?
```

`continuity` maps to `GeomAbs_Shape`: 0=C0, 1=C1, 2=C2, 3=C3.

- **Parameters:** `tolerance` — maximum approximation error; `continuity` — desired continuity order; `maxSegments` — maximum number of BSpline segments; `maxDegree` — maximum polynomial degree.
- **Returns:** Approximated BSpline, or `nil` on failure.
- **OCCT:** `Approx_Curve2d` (via `OCCTCurve2DApproximate`).
- **Example:**
  ```swift
  let circle = Curve2D.circle(center: .zero, radius: 5)!
  let approx = circle.approximated(tolerance: 0.01, continuity: 2)
  ```

---

### `splitIndicesAtDiscontinuities(continuity:)`

Finds knot indices where a BSpline has continuity discontinuities.

```swift
public func splitIndicesAtDiscontinuities(continuity: Int = 1) -> [Int]?
```

- **Parameters:** `continuity` — desired continuity level to check (0=C0, 1=C1, etc.).
- **Returns:** Array of knot indices where continuity drops below the requested level, or `nil` if not a BSpline or no discontinuities found.
- **OCCT:** `Geom2d_BSplineCurve` knot analysis (via `OCCTCurve2DSplitAtDiscontinuities`).
- **Example:**
  ```swift
  if let bsp = Curve2D.bspline(poles: [...], knots: [...], multiplicities: [...], degree: 3) {
      let indices = bsp.splitIndicesAtDiscontinuities(continuity: 1)
  }
  ```

---

### `toArcsAndSegments(tolerance:angleTolerance:)`

Approximates this curve as a sequence of arcs and line segments.

```swift
public func toArcsAndSegments(tolerance: Double = 0.01,
                              angleTolerance: Double = 0.04) -> [Curve2D]?
```

Useful for CNC G-code generation where only arcs and lines are supported.

- **Parameters:** `tolerance` — maximum approximation error; `angleTolerance` — maximum angular deviation for arc fitting.
- **Returns:** Array of arc/segment `Curve2D` objects, or `nil` on failure.
- **OCCT:** `Geom2dConvert_ApproxCurve` arc-and-segment decomposition.
- **Example:**
  ```swift
  let ellipse = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5)!
  if let arcs = ellipse.toArcsAndSegments(tolerance: 0.01) {
      // arcs suitable for G02/G03/G01 G-code output
  }
  ```

---

## Conversion

### `toBSpline(tolerance:)`

Converts this curve to an equivalent BSpline representation.

```swift
public func toBSpline(tolerance: Double = 1e-6) -> Curve2D?
```

Any analytic curve (line, circle, ellipse, arc) can be represented exactly as a rational BSpline. Required before using BSpline-specific query APIs.

- **Parameters:** `tolerance` — conversion precision.
- **Returns:** BSpline curve, or `nil` if conversion fails.
- **OCCT:** `Geom2dConvert::CurveToBSplineCurve(curve)`.
- **Example:**
  ```swift
  let circle = Curve2D.circle(center: .zero, radius: 5)!
  if let bsp = circle.toBSpline() {
      print(bsp.poleCount!)  // NURBS representation of the circle
  }
  ```

---

### `toBezierSegments()`

Splits a BSpline curve into its constituent Bezier segments.

```swift
public func toBezierSegments() -> [Curve2D]?
```

- **Returns:** Array of Bezier segment curves, or `nil` if the curve is not a BSpline or decomposition fails.
- **OCCT:** `Geom2dConvert_BSplineCurveToBezierCurve::Arc(i)`.
- **Example:**
  ```swift
  let bsp = Curve2D.interpolate(through: [SIMD2(0,0), SIMD2(3,4), SIMD2(6,0)])!
  if let segs = bsp.toBezierSegments() {
      print(segs.count)
  }
  ```

---

### `Curve2D.join(_:tolerance:)`

Joins multiple curves into a single BSpline.

```swift
public static func join(_ curves: [Curve2D], tolerance: Double = 1e-6) -> Curve2D?
```

Each input curve is converted to BSpline form before concatenation. Curves must meet end-to-end within `tolerance`.

- **Parameters:** `curves` — curves to join in order; `tolerance` — endpoint gap tolerance.
- **Returns:** Joined BSpline, or `nil` if the array is empty or joining fails.
- **OCCT:** `Geom2dConvert_CompCurveToBSplineCurve` (via `OCCTCurve2DJoinToBSpline`).
- **Example:**
  ```swift
  let seg1 = Curve2D.segment(from: .zero, to: SIMD2(5, 0))!
  let seg2 = Curve2D.segment(from: SIMD2(5, 0), to: SIMD2(10, 5))!
  if let joined = Curve2D.join([seg1, seg2]) {
      print(joined.length!)
  }
  ```

---

## Circle Construction

Methods on `Curve2DGcc` that construct circles satisfying geometric constraints. See the `Curve2DGcc` enum for the full solver; the entries below correspond to the `// MARK: - Circle Construction` section.

### `Curve2DGcc.circlesTangentTo(_:_:_:_:_:_:tolerance:)`

Finds circles tangent to three curves.

```swift
public static func circlesTangentTo(
    _ c1: Curve2D, _ q1: Curve2DQualifier = .unqualified,
    _ c2: Curve2D, _ q2: Curve2DQualifier = .unqualified,
    _ c3: Curve2D, _ q3: Curve2DQualifier = .unqualified,
    tolerance: Double = 1e-6
) -> [Curve2DCircleSolution]
```

- **Parameters:** `c1`/`c2`/`c3` — input curves; `q1`/`q2`/`q3` — qualifiers (`.unqualified`, `.enclosing`, `.enclosed`, `.outside`); `tolerance` — geometric tolerance.
- **Returns:** Array of `Curve2DCircleSolution` values (each with `center` and `radius`); may be empty.
- **OCCT:** `Geom2dGcc_Circ2d3Tan`.
- **Example:**
  ```swift
  let c1 = Curve2D.circle(center: SIMD2(-5, 0), radius: 2)!
  let c2 = Curve2D.circle(center: SIMD2(5, 0), radius: 2)!
  let c3 = Curve2D.circle(center: SIMD2(0, 5), radius: 2)!
  let sols = Curve2DGcc.circlesTangentTo(c1, .outside, c2, .outside, c3, .outside)
  ```

---

### `Curve2DGcc.circlesTangentToTwoCurvesAndPoint(_:_:_:_:point:tolerance:)`

Finds circles tangent to two curves and passing through a point.

```swift
public static func circlesTangentToTwoCurvesAndPoint(
    _ c1: Curve2D, _ q1: Curve2DQualifier = .unqualified,
    _ c2: Curve2D, _ q2: Curve2DQualifier = .unqualified,
    point: SIMD2<Double>,
    tolerance: Double = 1e-6
) -> [Curve2DCircleSolution]
```

- **Parameters:** `c1`/`c2` — input curves; `q1`/`q2` — qualifiers; `point` — required pass-through point; `tolerance` — tolerance.
- **Returns:** Array of solutions.
- **OCCT:** `Geom2dGcc_Circ2d2TanPt`.
- **Example:**
  ```swift
  let sols = Curve2DGcc.circlesTangentToTwoCurvesAndPoint(
      c1, .unqualified, c2, .unqualified, point: SIMD2(0, 0))
  ```

---

### `Curve2DGcc.circlesTangentWithCenter(_:_:center:tolerance:)`

Finds circles tangent to a curve with a given center point.

```swift
public static func circlesTangentWithCenter(
    _ curve: Curve2D, _ qualifier: Curve2DQualifier = .unqualified,
    center: SIMD2<Double>,
    tolerance: Double = 1e-6
) -> [Curve2DCircleSolution]
```

- **Parameters:** `curve` — input curve; `qualifier` — qualifier; `center` — desired circle centre; `tolerance` — tolerance.
- **Returns:** Array of solutions.
- **OCCT:** `Geom2dGcc_Circ2dTanCen`.
- **Example:**
  ```swift
  let sols = Curve2DGcc.circlesTangentWithCenter(circle, .outside, center: SIMD2(10, 0))
  ```

---

### `Curve2DGcc.circlesTangentToTwoCurves(_:_:_:_:radius:tolerance:)`

Finds circles tangent to two curves with a given radius.

```swift
public static func circlesTangentToTwoCurves(
    _ c1: Curve2D, _ q1: Curve2DQualifier = .unqualified,
    _ c2: Curve2D, _ q2: Curve2DQualifier = .unqualified,
    radius: Double,
    tolerance: Double = 1e-6
) -> [Curve2DCircleSolution]
```

- **Parameters:** `c1`/`c2` — input curves; `q1`/`q2` — qualifiers; `radius` — required radius; `tolerance` — tolerance.
- **Returns:** Array of solutions.
- **OCCT:** `Geom2dGcc_Circ2d2TanRad`.
- **Example:**
  ```swift
  let sols = Curve2DGcc.circlesTangentToTwoCurves(c1, .outside, c2, .outside, radius: 3)
  ```

---

### `Curve2DGcc.circlesTangentToPointWithRadius(_:_:point:radius:tolerance:)`

Finds circles tangent to a curve, passing through a point, with a given radius.

```swift
public static func circlesTangentToPointWithRadius(
    _ curve: Curve2D, _ qualifier: Curve2DQualifier = .unqualified,
    point: SIMD2<Double>, radius: Double,
    tolerance: Double = 1e-6
) -> [Curve2DCircleSolution]
```

- **Parameters:** `curve` — input curve; `qualifier` — qualifier; `point` — pass-through point; `radius` — required radius; `tolerance` — tolerance.
- **Returns:** Array of solutions.
- **OCCT:** `Geom2dGcc_Circ2dTanPtRad`.
- **Example:**
  ```swift
  let sols = Curve2DGcc.circlesTangentToPointWithRadius(
      circle, .outside, point: SIMD2(0, 0), radius: 4)
  ```

---

### `Curve2DGcc.circlesThroughTwoPoints(_:_:radius:tolerance:)`

Finds circles through two points with a given radius.

```swift
public static func circlesThroughTwoPoints(
    _ p1: SIMD2<Double>, _ p2: SIMD2<Double>,
    radius: Double,
    tolerance: Double = 1e-6
) -> [Curve2DCircleSolution]
```

- **Parameters:** `p1`/`p2` — required pass-through points; `radius` — required radius; `tolerance` — tolerance.
- **Returns:** Array of solutions (0, 1, or 2).
- **OCCT:** `Geom2dGcc_Circ2d2PtRad`.
- **Example:**
  ```swift
  let sols = Curve2DGcc.circlesThroughTwoPoints(SIMD2(-3, 0), SIMD2(3, 0), radius: 5)
  ```

---

### `Curve2DGcc.circleThroughThreePoints(_:_:_:tolerance:)`

Finds the circle through three points.

```swift
public static func circleThroughThreePoints(
    _ p1: SIMD2<Double>, _ p2: SIMD2<Double>, _ p3: SIMD2<Double>,
    tolerance: Double = 1e-6
) -> [Curve2DCircleSolution]
```

- **Parameters:** `p1`/`p2`/`p3` — three points; `tolerance` — coincidence tolerance.
- **Returns:** Array with one solution, or empty if collinear.
- **OCCT:** `Geom2dGcc_Circ2d3Pt`.
- **Example:**
  ```swift
  let sols = Curve2DGcc.circleThroughThreePoints(
      SIMD2(5, 0), SIMD2(0, 5), SIMD2(-5, 0))
  ```

---

## Line Construction

Methods on `Curve2DGcc` that construct lines satisfying geometric constraints. Corresponds to `// MARK: - Line Construction`.

### `Curve2DGcc.linesTangentTo(_:_:_:_:tolerance:)`

Finds lines tangent to two curves.

```swift
public static func linesTangentTo(
    _ c1: Curve2D, _ q1: Curve2DQualifier = .unqualified,
    _ c2: Curve2D, _ q2: Curve2DQualifier = .unqualified,
    tolerance: Double = 1e-6
) -> [Curve2DLineSolution]
```

- **Parameters:** `c1`/`c2` — input curves; `q1`/`q2` — qualifiers; `tolerance` — tolerance.
- **Returns:** Array of `Curve2DLineSolution` values (each with a `point` on the line and `direction`).
- **OCCT:** `Geom2dGcc_Lin2d2Tan`.
- **Example:**
  ```swift
  let c1 = Curve2D.circle(center: SIMD2(-5, 0), radius: 2)!
  let c2 = Curve2D.circle(center: SIMD2(5, 0), radius: 2)!
  let lines = Curve2DGcc.linesTangentTo(c1, .outside, c2, .outside)
  ```

---

### `Curve2DGcc.linesTangentToPoint(_:_:point:tolerance:)`

Finds lines tangent to a curve and passing through a point.

```swift
public static func linesTangentToPoint(
    _ curve: Curve2D, _ qualifier: Curve2DQualifier = .unqualified,
    point: SIMD2<Double>,
    tolerance: Double = 1e-6
) -> [Curve2DLineSolution]
```

- **Parameters:** `curve` — input curve; `qualifier` — qualifier; `point` — pass-through point; `tolerance` — tolerance.
- **Returns:** Array of line solutions.
- **OCCT:** `Geom2dGcc_Lin2dTanPt`.
- **Example:**
  ```swift
  let circle = Curve2D.circle(center: .zero, radius: 3)!
  let lines = Curve2DGcc.linesTangentToPoint(circle, .outside, point: SIMD2(10, 0))
  ```

---

## Curve2D Transform (v0.128.0)

In-place mutation methods that modify the curve handle directly, unlike `translated(by:)` / `rotated(around:…)` which return new copies.

### `TransformType2D`

Enum encoding the type of in-place 2D transform.

```swift
public enum TransformType2D: Int32, Sendable {
    case translation = 0
    case rotation = 1
    case scale = 2
    case mirrorPoint = 3
    case mirrorAxis = 4
}
```

Used internally by the in-place transform methods below.

---

### `translate(dx:dy:)`

Translates the curve in place by `(dx, dy)`.

```swift
@discardableResult
public func translate(dx: Double, dy: Double) -> Bool
```

- **Parameters:** `dx`, `dy` — displacement components.
- **Returns:** `true` on success.
- **OCCT:** `Geom2d_Curve::Translate(gp_Vec2d)` (in-place, via `OCCTCurve2DTransform`).
- **Example:**
  ```swift
  let seg = Curve2D.segment(from: .zero, to: SIMD2(10, 0))!
  seg.translate(dx: 0, dy: 5)
  print(seg.startPoint)  // SIMD2(0, 5)
  ```

---

### `rotate(center:angle:)`

Rotates the curve in place around a centre point.

```swift
@discardableResult
public func rotate(center: SIMD2<Double>, angle: Double) -> Bool
```

- **Parameters:** `center` — rotation centre; `angle` — rotation angle in radians.
- **Returns:** `true` on success.
- **OCCT:** `Geom2d_Curve::Rotate(gp_Pnt2d, angle)` (in-place).
- **Example:**
  ```swift
  let seg = Curve2D.segment(from: SIMD2(1, 0), to: SIMD2(10, 0))!
  seg.rotate(center: .zero, angle: .pi / 2)
  ```

---

### `scale(center:factor:)`

Scales the curve in place from a centre point.

```swift
@discardableResult
public func scale(center: SIMD2<Double>, factor: Double) -> Bool
```

- **Parameters:** `center` — fixed point of scaling; `factor` — scale factor.
- **Returns:** `true` on success.
- **OCCT:** `Geom2d_Curve::Scale(gp_Pnt2d, factor)` (in-place).
- **Example:**
  ```swift
  let seg = Curve2D.segment(from: .zero, to: SIMD2(5, 0))!
  seg.scale(center: .zero, factor: 2)
  print(seg.length!)  // 10.0
  ```

---

### `mirrorPoint(_:)`

Mirrors the curve in place through a point.

```swift
@discardableResult
public func mirrorPoint(_ point: SIMD2<Double>) -> Bool
```

- **Parameters:** `point` — point of symmetry.
- **Returns:** `true` on success.
- **OCCT:** `Geom2d_Curve::Mirror(gp_Pnt2d)` (in-place).
- **Example:**
  ```swift
  let seg = Curve2D.segment(from: .zero, to: SIMD2(4, 0))!
  seg.mirrorPoint(SIMD2(2, 0))
  ```

---

### `mirrorAxis(origin:direction:)`

Mirrors the curve in place through an axis.

```swift
@discardableResult
public func mirrorAxis(origin: SIMD2<Double>, direction: SIMD2<Double>) -> Bool
```

- **Parameters:** `origin` — a point on the mirror axis; `direction` — axis direction.
- **Returns:** `true` on success.
- **OCCT:** `Geom2d_Curve::Mirror(gp_Ax2d)` (in-place).
- **Example:**
  ```swift
  let seg = Curve2D.segment(from: SIMD2(0, 2), to: SIMD2(10, 2))!
  seg.mirrorAxis(origin: .zero, direction: SIMD2(1, 0))
  ```

---

## Geom2dEval TBezier / AHTBezier Curves (v0.131.0)

### `Curve2D.tBezier(poles:alpha:)`

Creates a 2D Trigonometric Bezier curve.

```swift
public static func tBezier(poles: [SIMD2<Double>], alpha: Double) -> Curve2D?
```

Uses a trigonometric Bernstein-like basis `{1, sin(α·t), cos(α·t), …}`. Parameter domain is `[0, π/α]`. Can represent circular arcs exactly without rational weights.

- **Parameters:** `poles` — 2D control points (count must be odd and ≥ 3); `alpha` — frequency parameter (must be > 0).
- **Returns:** TBezier curve, or `nil` if `poles.count < 3`, count is even, or `alpha ≤ 0`.
- **OCCT:** `OCCTGeom2dEvalTBezierCurveCreate`.
- **Example:**
  ```swift
  let poles: [SIMD2<Double>] = [SIMD2(1, 0), SIMD2(0, 1), SIMD2(-1, 0)]
  if let tb = Curve2D.tBezier(poles: poles, alpha: 1.0) {
      let pts = tb.drawAdaptive()
  }
  ```

---

### `Curve2D.ahtBezier(poles:algDegree:alpha:beta:)`

Creates a 2D Algebraic-Hyperbolic-Trigonometric (AHT) Bezier curve.

```swift
public static func ahtBezier(poles: [SIMD2<Double>], algDegree: Int, alpha: Double, beta: Double) -> Curve2D?
```

Uses a mixed basis: `{1, t, …, t^k, sinh(α·t), cosh(α·t), sin(β·t), cos(β·t)}`. The number of poles must equal `algDegree + 1 + 2*(alpha>0) + 2*(beta>0)`. Parameter range is `[0, 1]`.

- **Parameters:** `poles` — 2D control points; `algDegree` — algebraic polynomial degree (≥ 0); `alpha` — hyperbolic frequency (≥ 0; 0 omits hyperbolic terms); `beta` — trigonometric frequency (≥ 0; 0 omits trig terms).
- **Returns:** AHT Bezier curve, or `nil` if the pole count is wrong or construction fails.
- **OCCT:** `OCCTGeom2dEvalAHTBezierCurveCreate`.
- **Example:**
  ```swift
  // Degree-2 algebraic + trig: needs 3 + 0 + 2 = 5 poles
  let poles: [SIMD2<Double>] = [
      SIMD2(0, 0), SIMD2(2, 1), SIMD2(4, 0),
      SIMD2(6, 1), SIMD2(8, 0)
  ]
  let aht = Curve2D.ahtBezier(poles: poles, algDegree: 2, alpha: 0, beta: .pi)
  ```

---

## v0.51.0: GC_MakeLine2d variants

### `Curve2D.lineThroughPoints(_:_:)`

Creates a 2D infinite line passing through two points.

```swift
public static func lineThroughPoints(_ p1: SIMD2<Double>, _ p2: SIMD2<Double>) -> Curve2D?
```

Unlike `segment(from:to:)` which creates a finite segment, this creates an infinite line through the two points.

- **Parameters:** `p1` — first point on the line; `p2` — second point on the line.
- **Returns:** 2D infinite line, or `nil` if points coincide.
- **OCCT:** `GC_MakeLine2d(p1, p2)` (via `OCCTCurve2DMakeLineThroughPoints`).
- **Example:**
  ```swift
  let line = Curve2D.lineThroughPoints(SIMD2(0, 0), SIMD2(5, 3))
  ```

---

### `Curve2D.lineParallel(point:direction:distance:)`

Creates a 2D line parallel to a reference line at a given signed offset.

```swift
public static func lineParallel(
    point: SIMD2<Double>, direction: SIMD2<Double>, distance: Double
) -> Curve2D?
```

Positive `distance` offsets to the left of the direction.

- **Parameters:** `point` — a point on the reference line; `direction` — reference line direction; `distance` — signed offset distance.
- **Returns:** 2D infinite line, or `nil` on failure.
- **OCCT:** `GC_MakeLine2d` parallel variant (via `OCCTCurve2DMakeLineParallel`).
- **Example:**
  ```swift
  let line = Curve2D.lineParallel(
      point: .zero, direction: SIMD2(1, 0), distance: 5)
  // Creates y = 5 (5 units above the X axis)
  ```
