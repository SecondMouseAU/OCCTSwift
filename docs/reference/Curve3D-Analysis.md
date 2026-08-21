---
title: Curve3D. Analysis
parent: API Reference
---

# Curve3D. Analysis

This page covers the analysis and query members of `Curve3D`: curvature and local differential geometry, projection onto planes and surfaces, curve-to-curve and curve-to-surface distance and intersection, quasi-uniform sampling, `ShapeAnalysis_Curve` utilities, continuity analysis, extrema (curve–curve, curve–surface, point–curve), `ProjLib` surface projection, and `gce` analytic-curve factories. For factory methods, B-spline/Bezier construction, and geometric operations see the main [`Curve3D`](Curve3D.md) page.

## Topics

- [Local Properties](#local-properties) · [LocalAnalysis](#localanalysis) · [Projection (v0.22.0)](#projection-v0220) · [Batch Evaluation (v0.29.0)](#batch-evaluation-v0290) · [Curve Distance & Intersection (v0.30.0)](#curve-distance--intersection-v0300) · [Quasi-Uniform Sampling (v0.31.0)](#quasi-uniform-sampling-v0310) · [ShapeAnalysis\_Curve Expansion (v0.49.0)](#shapeanalysis_curve-expansion-v0490) · [v0.80.0: Extrema, ProjLib, gce Factories](#v0800-extrema-projlib-gce-factories) · [ExtremaPC, Point-Curve Distance (v0.130.0)](#extremapc--point-curve-distance-v01300)

---

## Local Properties

Differential geometry queries at a parameter value on the curve, backed by `GeomLProp_CLProps`.

---

### `curvature(at:)`

Returns the curvature at parameter `u`.

```swift
public func curvature(at u: Double) -> Double?
```

The curvature is the reciprocal of the radius of the osculating circle at `u`. Zero on a straight line; larger values indicate tighter bends.

- **Parameters:** `u`, curve parameter.
- **Returns:** Curvature value; `nil` when `GeomLProp_CLProps::IsTangentDefined()` is false there, a point with no significant derivative of any order, e.g. a Bezier whose control points all coincide. This was `0` until #595, which is also every straight curve's real curvature. A **cusp** is not an absence: OCCT calls the curvature infinite there and returns `Double.greatestFiniteMagnitude` (`RealLast()`), which is still reported as a value.
- **OCCT:** `GeomLProp_CLProps::Curvature`.
- **Example:**
  ```swift
  if let arc = Curve3D.arc(center: .zero, radius: 5, startAngle: 0, endAngle: .pi) {
      let k = arc.curvature(at: 0)  // ≈ 0.2 (1/R)
  }
  if let line = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)) {
      line.curvature(at: 3)         // 0, straight, and that is the answer, not a failure
  }
  ```

---

### `tangentDirection(at:)`

Returns the unit tangent direction at parameter `u`.

```swift
public func tangentDirection(at u: Double) -> SIMD3<Double>?
```

- **Parameters:** `u`, curve parameter.
- **Returns:** Unit tangent vector, or `nil` when the tangent cannot be computed (e.g. at a cusp).
- **OCCT:** `GeomLProp_CLProps::Tangent`.
- **Example:**
  ```swift
  if let c = Curve3D.line(from: .zero, to: SIMD3(1, 0, 0)),
     let t = c.tangentDirection(at: 0) {
      // t ≈ SIMD3(1, 0, 0)
  }
  ```

---

### `normal(at:)`

Returns the principal normal direction at parameter `u`.

```swift
public func normal(at u: Double) -> SIMD3<Double>?
```

The principal normal points toward the center of curvature.

- **Parameters:** `u`, curve parameter.
- **Returns:** Unit principal normal vector, or `nil` on a straight segment (curvature is zero, normal is undefined).
- **OCCT:** `GeomLProp_CLProps::Normal`.
- **Example:**
  ```swift
  if let arc = Curve3D.arc(center: .zero, radius: 5, startAngle: 0, endAngle: .pi),
     let n = arc.normal(at: 0) {
      // n points inward toward center
  }
  ```

---

### `centerOfCurvature(at:)`

Returns the center of the osculating circle at parameter `u`.

```swift
public func centerOfCurvature(at u: Double) -> SIMD3<Double>?
```

- **Parameters:** `u`, curve parameter.
- **Returns:** 3D center of curvature, or `nil` when curvature is zero (straight segment).
- **OCCT:** `GeomLProp_CLProps::CentreOfCurvature`.
- **Example:**
  ```swift
  if let arc = Curve3D.arc(center: .zero, radius: 5, startAngle: 0, endAngle: .pi),
     let c = arc.centerOfCurvature(at: 0) {
      // c ≈ SIMD3(0, 0, 0), center of the arc
  }
  ```

---

### `torsion(at:)`

Returns the torsion at parameter `u` (the rate of change of the osculating plane).

```swift
public func torsion(at u: Double) -> Double?
```

Torsion is zero for planar curves. Non-zero values indicate the curve is twisting out of its local plane.

- **Parameters:** `u`, curve parameter.
- **Returns:** Torsion value (signed); `0` for planar curves, which is a real answer, and `nil` where there is no osculating plane to twist out of, a straight stretch, where the first two derivatives are parallel. Those two were the same `0` until #595 (every circle and ellipse is planar, so the collision was as ordinary as `curvature(at:)`'s).
- **OCCT:** `GeomLProp_CLProps::Torsion`.
- **Example:**
  ```swift
  if let helix = Curve3D.circularHelix(radius: 5, pitch: 2) {
      let tau = helix.torsion(at: 0)  // non-zero for a helix
  }
  if let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 4) {
      circle.torsion(at: 1)           // 0, planar, and that is the answer
  }
  ```

---

## LocalAnalysis

Continuity analysis between two curves at a shared junction, backed by `LocalAnalysis_CurveContinuity`.

---

### `ContinuityAnalysis`

Struct returned by `continuityWith(_:u1:u2:order:)`.

```swift
public struct ContinuityAnalysis: Sendable {
    public let order: ContinuityClass
    public let measured: Set<ContinuityClass>
    public let c0Value: Double
    public let g1Angle: Double
    public let c1Angle: Double
    public let c1Ratio: Double
    public let c2Angle: Double
    public let c2Ratio: Double
    public let g2Angle: Double
    public let g2CurvatureVariation: Double
    public let flags: Int
    public func holds(_ continuity: ContinuityClass) -> Bool?
    public var isC0: Bool? { holds(.c0) }
    public var isG1: Bool? { holds(.g1) }
    public var isC1: Bool? { holds(.c1) }
    public var isG2: Bool? { holds(.g2) }
    public var isC2: Bool? { holds(.c2) }
}
```

- `order`: the class the junction was analysed at, i.e. the request after saturation. `LocalAnalysis_CurveContinuity::ContinuityStatus()` echoes its constructor argument, so this is never a finding; it exists to tell you where a saturated request landed.
- `measured`: the classes this `order` actually evaluated. Each order runs one branch: `.c0` measures C0; `.g1` measures C0 and G1; `.c1` measures C0 and C1; `.g2` measures C0, G1 and G2; `.c2` measures C0, C1 and C2. **No order measures all five.**
- `c0Value`: positional gap distance at the junction.
- `g1Angle`: angle between tangent directions (radians), or `-1` if G1 was not measured or does not hold.
- `c1Angle` / `c1Ratio`, angle and magnitude ratio between first derivatives, or `-1`.
- `c2Angle` / `c2Ratio`, angle and magnitude ratio between second derivatives, or `-1`.
- `g2Angle`: angle between osculating planes, or `-1`.
- `g2CurvatureVariation`: curvature variation at the junction, or `-1`.
- `flags`: bitmask (bit 0 = C0 … bit 4 = C2), masked to `measured`.
- `holds(_:)` returns `nil` for a class outside `measured`, which is what separates "does not hold" from "never asked". Prefer it to `flags`.

> Before #495 the `is*` helpers were non-optional and read straight off the bitmask, so a class the order never computed answered `true` from an uninitialised member, a 90° corner analysed at `.c0` reported `isC2 == true`, with `c2Angle == 0.0` alongside it.

---

#### `ContinuityAnalysis.order`

The class the junction was analysed at, i.e. the request after saturation. `LocalAnalysis_CurveContinuity::ContinuityStatus()` echoes its constructor argument, so this is never a finding; it exists to tell you where a saturated request landed.

#### `ContinuityAnalysis.measured`

The classes this `order` actually evaluated. Each order runs one branch: `.c0` measures C0; `.g1` measures C0 and G1; `.c1` measures C0 and C1; `.g2` measures C0, G1 and G2; `.c2` measures C0, C1 and C2. No order measures all five.

#### `ContinuityAnalysis.c0Value`

Positional gap distance at the junction.

#### `ContinuityAnalysis.g1Angle`

Angle between tangent directions (radians), or `-1` if G1 was not measured or does not hold.

#### `ContinuityAnalysis.c1Angle`

Angle between first derivatives, or `-1` if C1 was not measured or does not hold.

#### `ContinuityAnalysis.c1Ratio`

Magnitude ratio between first derivatives, or `-1` if C1 was not measured or does not hold.

#### `ContinuityAnalysis.c2Angle`

Angle between second derivatives, or `-1` if C2 was not measured or does not hold.

#### `ContinuityAnalysis.c2Ratio`

Magnitude ratio between second derivatives, or `-1` if C2 was not measured or does not hold.

#### `ContinuityAnalysis.g2Angle`

Angle between osculating planes, or `-1` if G2 was not measured or does not hold.

#### `ContinuityAnalysis.g2CurvatureVariation`

Curvature variation at the junction, or `-1` if G2 was not measured or does not hold.

#### `ContinuityAnalysis.flags`

Bitmask of the classes that hold (bit 0 = C0 through bit 4 = C2), masked to `measured`: a clear bit means "does not hold or was not measured". Prefer `holds(_:)`, which tells the two apart.

#### `ContinuityAnalysis.holds(_:)`

```swift
public func holds(_ continuity: ContinuityClass) -> Bool?
```

Whether `continuity` holds at the junction, or `nil` if `order` never measured it. Tests exact-class membership, not a floor: a `true` for `.g2` implies nothing about `.c1`.

- **Example:**
  ```swift
  let a = corner.continuityWith(other, u1: e1, u2: s2, order: .c1)!
  a.holds(.c1)   // false: measured, and the junction is not C1
  a.holds(.g1)   // nil: order .c1 never computes G1
  ```

#### `ContinuityAnalysis.isC0`

`holds(.c0)`. Always measured (every order measures C0).

#### `ContinuityAnalysis.isG1`

`holds(.g1)`. `nil` unless `order` is `.g1` or `.g2`.

#### `ContinuityAnalysis.isC1`

`holds(.c1)`. `nil` unless `order` is `.c1` or `.c2`.

#### `ContinuityAnalysis.isG2`

`holds(.g2)`. `nil` unless `order` is `.g2`.

#### `ContinuityAnalysis.isC2`

`holds(.c2)`. `nil` unless `order` is `.c2`.

> Before #495 the `is*` helpers were non-optional and read straight off the bitmask, so a class the order never computed answered `true` from an uninitialised member, a 90° corner analysed at `.c0` reported `isC2 == true`, with `c2Angle == 0.0` alongside it.

---

### `continuityWith(_:u1:u2:order:)`

Analyses the continuity between this curve at parameter `u1` and another curve at parameter `u2`.

```swift
public func continuityWith(_ other: Curve3D, u1: Double, u2: Double,
                           order: ContinuityClass = .c2) -> ContinuityAnalysis?
```

`order` **selects** the analysis rather than capping it, see `measured` above. `.c2` is the strictest class `LocalAnalysis_CurveContinuity` implements, so `.c3` and `.cN` saturate to it.

- **Parameters:** `other`, the second curve; `u1`, parameter on this curve; `u2`, parameter on `other`; `order`, the class to measure (default `.c2`).
- **Returns:** `ContinuityAnalysis`, or `nil` if `LocalAnalysis_CurveContinuity` fails.
- **OCCT:** `LocalAnalysis_CurveContinuity`.
- **Note:** the `.c2` and `.g2` branches need a non-zero second derivative on both curves, so a straight line cannot be analysed above `.c1`/`.g1`.
- **Example:**
  ```swift
  // Tangency is its own question: the .c2 default never computes G1.
  if let ca = c1.continuityWith(c2, u1: c1.domain.upperBound,
                                u2: c2.domain.lowerBound, order: .g1) {
      print(ca.holds(.g1), ca.g1Angle)
      print(ca.holds(.c1))            // nil, .g1 does not measure C1
  }
  ```

---

## Projection (v0.22.0)

Project this curve onto a plane along a direction, returning a 3D curve in that plane.

---

### `projectedOnPlane(origin:normal:direction:)`

Projects this curve onto a plane along a specified direction.

```swift
public func projectedOnPlane(
    origin:    SIMD3<Double>,
    normal:    SIMD3<Double>,
    direction: SIMD3<Double>
) -> Curve3D?
```

Uses `GeomProjLib::ProjectOnPlane`. The result is a 3D curve lying in the target plane. The projection direction must not be parallel to the plane normal.

- **Parameters:** `origin`, a point on the target plane; `normal`, the plane normal; `direction`, projection direction (must not be parallel to `normal`).
- **Returns:** Projected 3D curve lying in the plane, or `nil` if projection fails.
- **OCCT:** `GeomProjLib::ProjectOnPlane`.
- **Example:**
  ```swift
  if let helix = Curve3D.circularHelix(radius: 5, pitch: 2),
     let proj  = helix.projectedOnPlane(
         origin: .zero,
         normal: SIMD3(0, 0, 1),
         direction: SIMD3(0, 0, 1)) {
      // proj is the spiral footprint of the helix on the XY plane
  }
  ```

---

## Batch Evaluation (v0.29.0)

Evaluate a curve at many parameter values in a single bridge call, using OCCT's batch
`GeomGridEval_Curve` evaluator rather than one `D0`/`D1` call per parameter. These two are the
canonical batch spellings; `evalBatchD0`/`D1` and `gridEvalD0`/`D1` forwarded here as deprecated
aliases ([#486](https://github.com/SecondMouseAU/OCCTSwift/issues/486)) and were removed at v2.0.0
([#784](https://github.com/SecondMouseAU/OCCTSwift/issues/784)).

---

### `evaluateGrid(_:)`

Evaluates the curve at multiple parameter values in one call.

```swift
public func evaluateGrid(_ parameters: [Double]) -> [SIMD3<Double>]
```

Significantly faster than calling `point(at:)` in a loop for large parameter arrays. Returns an empty array when `parameters` is empty or the bridge call fails.

- **Parameters:** `parameters`, array of curve parameter values.
- **Returns:** Array of 3D points in the same order as `parameters`. Length equals `parameters.count` on success; may be shorter if the bridge returns fewer valid results.
- **OCCT:** `GeomGridEval_Curve::EvaluateGrid` via `OCCTCurve3DEvaluateGrid`.
- **Example:**
  ```swift
  if let arc = Curve3D.arc(center: .zero, radius: 5, startAngle: 0, endAngle: .pi) {
      let params = stride(from: arc.domain.lowerBound,
                          through: arc.domain.upperBound,
                          by: 0.1).map { $0 }
      let pts = arc.evaluateGrid(params)
  }
  ```

---

### `evaluateGridD1(_:)`

Evaluates the curve and its first derivative at multiple parameter values in one call.

```swift
public func evaluateGridD1(_ parameters: [Double]) -> [(point: SIMD3<Double>, tangent: SIMD3<Double>)]
```

Returns point and (unnormalized) tangent vector at each parameter. Suitable for building polylines with tangent information for rendering or downstream processing.

- **Parameters:** `parameters`, array of curve parameter values.
- **Returns:** Array of `(point, tangent)` tuples. The tangent is the first derivative, not the unit tangent, normalize if needed.
- **OCCT:** `GeomGridEval_Curve::EvaluateGridD1` via `OCCTCurve3DEvaluateGridD1`.
- **Example:**
  ```swift
  if let c = Curve3D.bspline(points: myPoints) {
      let params = stride(from: 0.0, through: 1.0, by: 0.05).map { $0 }
      let pts = c.evaluateGridD1(params)
      for (pt, tan) in pts {
          // pt is position; tan is tangent vector at that parameter
      }
  }
  ```

---

### `planeNormal(tolerance:)`

Returns the plane normal if this curve is planar, or `nil` if it is not.

```swift
public func planeNormal(tolerance: Double = 0) -> SIMD3<Double>?
```

Uses `ShapeAnalysis_Curve::IsPlanar` to test whether the curve lies in a plane within `tolerance`. A returned normal is not unit-normalized; normalize it before use.

- **Parameters:** `tolerance`, planarity tolerance (default `0` uses OCCT internal precision).
- **Returns:** The plane normal direction if the curve is planar within tolerance, or `nil` if not planar.
- **OCCT:** `ShapeAnalysis_Curve::IsPlanar`.
- **Example:**
  ```swift
  if let arc = Curve3D.arc(center: .zero, radius: 5, startAngle: 0, endAngle: .pi),
     let n = arc.planeNormal() {
      // n ≈ SIMD3(0, 0, 1) for an arc in the XY plane
  }
  ```

---

## Curve Distance & Intersection (v0.30.0)

Minimum-distance, extrema, and intersection between curves and surfaces.

---

### `CurveExtremaResult`

Struct representing a single extremal distance result between two curves.

```swift
public struct CurveExtremaResult: Sendable {
    public let distance:   Double
    public let point1:     SIMD3<Double>
    public let point2:     SIMD3<Double>
    public let parameter1: Double
    public let parameter2: Double
}
```

- `distance`: distance between the two extremal points.
- `point1` / `point2`, closest (or farthest) points on the first and second curve respectively.
- `parameter1` / `parameter2`, parameter values on each curve at the extremal points.

---

### `CurveSurfaceHit`

Struct representing a single curve–surface intersection point.

```swift
public struct CurveSurfaceHit: Sendable {
    public let point:          SIMD3<Double>
    public let curveParameter: Double
    public let surfaceU:       Double
    public let surfaceV:       Double
}
```

- `point`: 3D intersection coordinates.
- `curveParameter`: parameter along the curve at the intersection.
- `surfaceU` / `surfaceV`, surface UV parameters at the intersection.

---

#### `CurveSurfaceHit.curveParameter`

Parameter along the curve at the intersection.

#### `CurveSurfaceHit.surfaceU`

Surface U parameter at the intersection.

#### `CurveSurfaceHit.surfaceV`

Surface V parameter at the intersection.

---

### `minDistance(to:)` (curve overload)

Returns the minimum distance from this curve to another curve.

```swift
public func minDistance(to other: Curve3D) -> Double?
```

- **Parameters:** `other`, the curve to measure against.
- **Returns:** Minimum distance, or `nil` when `GeomAPI_ExtremaCurveCurve` finds no extrema.
- **OCCT:** `GeomAPI_ExtremaCurveCurve::LowerDistance`.
- **Example:**
  ```swift
  if let c1 = Curve3D.line(from: .zero, to: SIMD3(10, 0, 0)),
     let c2 = Curve3D.line(from: SIMD3(0, 5, 0), to: SIMD3(10, 5, 0)),
     let d  = c1.minDistance(to: c2) {
      print(d)  // ≈ 5.0
  }
  ```

---

### `extrema(with:maxCount:)`

Finds all extremal distances (closest and farthest point pairs) between this curve and another.

```swift
public func extrema(with other: Curve3D, maxCount: Int = 20) -> [CurveExtremaResult]
```

Returns up to `maxCount` results. For simple queries where only the minimum distance matters, prefer `minDistance(to:)`.

- **Parameters:** `other`, the second curve; `maxCount`, output *capacity* (default 20), clamped
  into `0...Sampling.maximumSampleCount` (10,000,000); 0 or less returns empty (#622).
- **Returns:** Array of `CurveExtremaResult` values. Empty when the curves are parallel: OCCT
  represents that case as a single unbounded family of equidistant solutions rather than a finite
  set of point pairs, so there is no `(point1, point2)` pair to report. Also empty if the algorithm
  finds nothing. Use `minDistance(to:)` for the (well-defined) distance in the parallel case.
- **OCCT:** `GeomAPI_ExtremaCurveCurve`.
- **Example:**
  ```swift
  if let c1 = Curve3D.arc(center: .zero, radius: 5, startAngle: 0, endAngle: .pi),
     let c2 = Curve3D.arc(center: SIMD3(10, 0, 0), radius: 3, startAngle: 0, endAngle: .pi) {
      let results = c1.extrema(with: c2)
      if let closest = results.min(by: { $0.distance < $1.distance }) {
          print(closest.distance)
      }
  }
  ```

---

### `intersections(with:maxHits:)` (surface overload)

Finds intersection points between this curve and a surface.

```swift
public func intersections(with surface: Surface, maxHits: Int = 100) -> [CurveSurfaceHit]
```

Returns an empty array when the curve does not pierce the surface. Both transverse and tangent intersections are returned.

- **Parameters:** `surface`, the surface to intersect with; `maxHits`, output *capacity*
  (default 100), clamped into `0...Sampling.maximumSampleCount` (10,000,000); 0 or less
  returns empty (#622).
- **Returns:** Array of `CurveSurfaceHit` values (may be empty).
- **OCCT:** `GeomAPI_IntCS`.
- **Example:**
  ```swift
  if let line = Curve3D.line(from: SIMD3(0, 0, -10), to: SIMD3(0, 0, 10)),
     let srf  = Surface.sphere(radius: 5) {
      let hits = line.intersections(with: srf)
      // hits.count == 2 for a line passing through the center of the sphere
  }
  ```

---

### `minDistance(to:)` (surface overload)

Returns the minimum distance from this curve to a surface.

```swift
public func minDistance(to surface: Surface) -> Double?
```

- **Parameters:** `surface`, the surface to measure against.
- **Returns:** Minimum distance, or `nil` when `GeomAPI_ExtremaCurveSurface` finds no solution.
- **OCCT:** `GeomAPI_ExtremaCurveSurface::LowerDistance`.
- **Example:**
  ```swift
  if let c   = Curve3D.line(from: SIMD3(0, 0, 10), to: SIMD3(10, 0, 10)),
     let srf = Surface.sphere(radius: 5),
     let d   = c.minDistance(to: srf) {
      print(d)  // ≈ 5.0 (line is 10 units from center, sphere radius 5)
  }
  ```

---

### `toAnalytical(tolerance:)`

Converts a freeform curve to an analytic curve if it can be recognised as one.

```swift
public func toAnalytical(tolerance: Double = 1e-4) -> Curve3D?
```

Recognises lines, circles, and ellipses within the given tolerance. Useful after fitting operations that produce a B-spline approximation of a canonical shape.

- **Parameters:** `tolerance`, recognition tolerance (default `1e-4`).
- **Returns:** Analytic `Curve3D` (a `Geom_Line`, `Geom_Circle`, or `Geom_Ellipse`), or `nil` if the curve is not recognisable as a standard type.
- **OCCT:** `GeomConvert_CurveToAnaCurve`.
- **Example:**
  ```swift
  if let approxCircle = someFittedCurve.toAnalytical() {
      // approxCircle is now a Geom_Circle if recognised
  }
  ```

---

## Quasi-Uniform Sampling (v0.31.0)

Distribute sample points approximately evenly along curve arc length, backed by `GCPnts_QuasiUniformAbscissa` and `GCPnts_QuasiUniformDeflection`.

---

### `quasiUniformParameters(count:)`

Returns parameter values at quasi-uniform arc-length intervals.

```swift
public func quasiUniformParameters(count: Int) -> [Double]
```

Uses `GCPnts_QuasiUniformAbscissa` to space `count` parameters approximately evenly along the arc length of the curve. The result is suitable for passing to `evaluateGrid(_:)`. The first parameter is always the start of the curve's domain and the last is always its end.

- **Parameters:** `count`, the desired number of sample parameters, a *request*, honoured within `2...Sampling.maximumSampleCount` (10,000,000); outside that range the result is empty. OCCT documents the lower bound but enforces it with a `Raise_if`, which the pinned Release kernel compiles out, so this layer applies it (#501); the upper bound is this layer's too, since `count` sizes a Swift allocation and is cast to the bridge's `int32_t`, and both ends used to abort the process (#558).
- **Returns:** Array of parameter values of length up to `count`, never more; empty on failure.
- **OCCT:** `GCPnts_QuasiUniformAbscissa`. It can compute one point beyond the request on a poorly-conditioned curve (measured on a 1e6 x 1e-3 ellipse); the surplus is dropped, but the curve's end parameter is kept in the last slot rather than truncated away.
- **Example:**
  ```swift
  if let c = Curve3D.bspline(points: myPoints) {
      let params = c.quasiUniformParameters(count: 50)
      let pts = c.evaluateGrid(params)
  }
  ```

---

### `quasiUniformDeflectionPoints(deflection:maxPoints:)`

Returns 3D sample points distributed so that the chord deviation stays within `deflection`.

```swift
public func quasiUniformDeflectionPoints(deflection: Double, maxPoints: Int = 500) -> [SIMD3<Double>]
```

Uses `GCPnts_QuasiUniformDeflection`. Tighter curves produce more points; straighter segments produce fewer. The result is suitable for polygon rendering.

- **Parameters:** `deflection`, maximum allowed chord deviation from the curve; `maxPoints`, output *capacity* (default 500), clamped into `0...Sampling.maximumSampleCount` (10,000,000), so an unservable capacity returns the same points rather than a coarser sampling; 0 or less returns empty (#558). The deflection decides the actual point count.
- **Returns:** Array of 3D points (may be empty on failure).
- **OCCT:** `GCPnts_QuasiUniformDeflection`.
- **Example:**
  ```swift
  if let arc = Curve3D.arc(center: .zero, radius: 5, startAngle: 0, endAngle: .pi) {
      let pts = arc.quasiUniformDeflectionPoints(deflection: 0.01)
      // pts is a polyline approximation with ≤0.01 chord error
  }
  ```

---

## ShapeAnalysis\_Curve Expansion (v0.49.0)

Point-projection, range validation, and parametric sampling via `ShapeAnalysis_Curve`.

---

### `PointProjection`

Struct returned by `projectPoint(_:precision:)`.

```swift
public struct PointProjection: Sendable {
    public let distance:  Double
    public let parameter: Double
    public let point:     SIMD3<Double>
}
```

- `distance`: 3D distance from the query point to the projected point on the curve.
- `parameter`: parameter on the curve at the closest point.
- `point`: 3D coordinates of the closest point on the curve.

---

### `projectPoint(_:precision:)`

Projects a 3D point onto this curve to find the closest point.

```swift
public func projectPoint(_ point: SIMD3<Double>, precision: Double = 1e-6) -> PointProjection
```

Always returns a result (never `nil`); a non-zero `distance` indicates the query point was not on the curve.

The answer is always inside the curve's own `domain`, and always the true nearest point. Where the query point has no perpendicular foot on the curve, anything past the end of a trimmed curve, or off to one side of an arc, the nearest point is an end, and that is what comes back. [`nearestParameter(to:)`](Curve3D-Construction.md#nearestparameterto) is the scalar spelling of this and agrees with it exactly; it reported `nil` for exactly those points until #615 routed it through the same helper.

- **Parameters:** `point`, 3D point to project; `precision`, projection precision (default `1e-6`).
- **Returns:** `PointProjection` with distance, parameter, and closest curve point.
- **OCCT:** `ShapeAnalysis_Curve::Project` and `GeomAPI_ProjectPointOnCurve`, minimised together with the domain's ends, no one of the three is correct alone (#539).
- **Example:**
  ```swift
  if let c = Curve3D.line(from: .zero, to: SIMD3(10, 0, 0)) {
      let proj = c.projectPoint(SIMD3(5, 3, 0))
      print(proj.point)     // ≈ SIMD3(5, 0, 0)
      print(proj.distance)  // ≈ 3.0
  }

  // Past the end of a trimmed curve: the end, not the basis line.
  if let seg = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0))?.trimmed(from: 3, to: 8) {
      let proj = seg.projectPoint(SIMD3(100, 0, 0))
      print(proj.parameter)  // 8.0
      print(proj.distance)   // 92.0
  }
  ```

> **Before #539** this projected onto the curve's *underlying basis* curve, so
> the trimmed-segment case above reported parameter `100`, distance `0`, a `distance < tolerance`
> proximity test read a point 92 units away as lying on the curve. A point on a full circle but
> outside an arc's own span read as distance 0 for the same reason.

---

### `distance(to:precision:)`

Returns the shortest distance from a 3D point to this curve.

```swift
public func distance(to point: SIMD3<Double>, precision: Double = 1e-6) -> Double
```

Convenience wrapper over `projectPoint(_:precision:)` when only the scalar distance is needed, so it measures to the same nearest point: over the curve's own `domain`, ends included.

- **Parameters:** `point`, query point; `precision`, projection precision (default `1e-6`).
- **Returns:** Shortest distance from `point` to the curve.
- **OCCT:** Delegates to `projectPoint(_:precision:)`, and inherits its #539 fix.
- **Example:**
  ```swift
  if let c = Curve3D.line(from: .zero, to: SIMD3(10, 0, 0)) {
      let d = c.distance(to: SIMD3(5, 3, 0))  // ≈ 3.0
  }
  ```

---

### `ValidatedRange`

Struct returned by `validateRange(first:last:precision:)`.

```swift
public struct ValidatedRange: Sendable {
    public let first:       Double
    public let last:        Double
    public let wasAdjusted: Bool
}
```

- `first` / `last`, validated (and possibly clamped) parameter bounds.
- `wasAdjusted`: `true` if the input range was outside the curve's parametric domain and was adjusted.

| Field | Meaning |
|---|---|
| `first` | Validated (and possibly clamped) first parameter. |
| `last` | Validated (and possibly clamped) last parameter. |
| `wasAdjusted` | `true` if the requested range was outside the curve's parametric domain and had to be adjusted. |

#### `Curve3D.ValidatedRange.wasAdjusted`

`true` if the requested range needed adjusting to fit the curve's domain.

---

### `validateRange(first:last:precision:)`

Validates and optionally adjusts a parameter range to lie within the curve's parametric domain.

```swift
public func validateRange(first: Double, last: Double, precision: Double = 1e-6) -> ValidatedRange
```

Uses `ShapeAnalysis_Curve::ValidateRange`. Useful before trimming or sampling a curve when the input parameters may be slightly outside the domain.

- **Parameters:** `first`, desired start parameter; `last`, desired end parameter; `precision`, tolerance for domain comparison (default `1e-6`).
- **Returns:** `ValidatedRange` with adjusted `first`/`last` and a flag indicating whether adjustment occurred.
- **OCCT:** `ShapeAnalysis_Curve::ValidateRange`.
- **Example:**
  ```swift
  if let c = Curve3D.arc(center: .zero, radius: 5, startAngle: 0, endAngle: .pi) {
      let vr = c.validateRange(first: -0.001, last: 3.15)
      // vr.wasAdjusted == true; vr.first clamped to domain start
  }
  ```

---

### `samplePoints(first:last:maxPoints:)`

Returns sample points distributed along the curve between two parameter values.

```swift
public func samplePoints(first: Double, last: Double, maxPoints: Int = 1000) -> [SIMD3<Double>]
```

Uses `ShapeAnalysis_Curve::GetSamplePoints`. The distribution is chosen internally by OCCT for good geometric coverage, not strict arc-length uniformity. For uniform spacing see `quasiUniformParameters(count:)`.

- **Parameters:** `first`, start parameter; `last`, end parameter; `maxPoints`, output *capacity* (default 1000), clamped into `0...Sampling.maximumSampleCount` (10,000,000), so an unservable capacity returns the same points rather than a coarser sampling; 0 or less returns empty (#558).
- **Returns:** Array of 3D sample points (may be empty on failure).
- **OCCT:** `ShapeAnalysis_Curve::GetSamplePoints`.
- **Example:**
  ```swift
  if let c = Curve3D.bspline(points: myPoints) {
      let lo = c.domain.lowerBound
      let hi = c.domain.upperBound
      let pts = c.samplePoints(first: lo, last: hi, maxPoints: 200)
  }
  ```

---

## v0.80.0: Extrema, ProjLib, gce Factories

Low-level `Extrema_ExtCC` / `Extrema_ExtCS` curve-curve and curve-surface distance, `ProjLib` surface projection, and `gce` analytic-curve factories.

---

### `CurveCurveExtrema`

Summary result of a curve-curve extrema computation.

```swift
public struct CurveCurveExtrema: Sendable {
    public let isDone:     Bool
    public let isParallel: Bool
    public let count:      Int
}
```

- `isDone`: `true` when the algorithm completed successfully.
- `isParallel`: `true` when the two curves are parallel (distance is constant along the range).
- `count`: number of extremal point pairs found.

---

### `ExtremaPointPair`

A single extremal point pair returned by `extremaCCPoint(...)` or `extremaCSPoint(...)`.

```swift
public struct ExtremaPointPair: Sendable {
    public let squareDistance: Double
    public let point1:         SIMD3<Double>
    public let param1:         Double
    public let point2:         SIMD3<Double>
    public let param2:         Double
}
```

- `squareDistance`: squared distance between the two extremal points (take `sqrt` for actual distance).
- `point1` / `param1`, point and parameter on the first curve (or query curve for curve-surface).
- `point2` / `param2`, point and parameter on the second curve, or UV parameters packed as `(u, v, 0)` for curve-surface.

---

#### `ExtremaPointPair.point1`

Point on the first curve (or the query curve, for curve-surface).

#### `ExtremaPointPair.param1`

Parameter on the first curve (or the query curve, for curve-surface).

#### `ExtremaPointPair.point2`

Point on the second curve, or the UV point packed as `(u, v, 0)` for curve-surface.

#### `ExtremaPointPair.param2`

Parameter on the second curve, or the surface U parameter for curve-surface (`point2.z` carries V).

---

### `extremaCC(range1:other:range2:)`

Computes curve-to-curve extrema using `Extrema_ExtCC`.

```swift
public func extremaCC(
    range1: ClosedRange<Double>? = nil,
    other:  Curve3D,
    range2: ClosedRange<Double>? = nil
) -> CurveCurveExtrema
```

When `range1` or `range2` is `nil`, the curve's full `domain` is used. Check `isParallel` before accessing individual point pairs, the `Known OCCT Bugs` section notes that `BRepExtrema_ExtCC` can crash on parallel edges (guarded in the bridge).

- **Parameters:** `range1`, optional parameter range restricting the search on this curve; `other`, the second curve; `range2`, optional parameter range on `other`.
- **Returns:** `CurveCurveExtrema` summary; use `extremaCCPoint(...)` to retrieve individual pairs.
- **OCCT:** `Extrema_ExtCC`.
- **Example:**
  ```swift
  if let c1 = Curve3D.arc(center: .zero, radius: 5, startAngle: 0, endAngle: .pi),
     let c2 = Curve3D.arc(center: SIMD3(20, 0, 0), radius: 3, startAngle: 0, endAngle: .pi) {
      let ex = c1.extremaCC(other: c2)
      if ex.isDone && !ex.isParallel {
          for i in 1...ex.count {
              let pair = c1.extremaCCPoint(other: c2, index: i)
              print(pair.squareDistance.squareRoot())
          }
      }
  }
  ```

---

### `extremaCCPoint(range1:other:range2:index:)`

Returns the Nth extremal point pair from a curve-curve computation (1-based index).

```swift
public func extremaCCPoint(
    range1: ClosedRange<Double>? = nil,
    other:  Curve3D,
    range2: ClosedRange<Double>? = nil,
    index:  Int
) -> ExtremaPointPair
```

Re-runs `Extrema_ExtCC` internally; call only after `extremaCC(...)` confirms `isDone` and `count >= index`.

- **Parameters:** `range1`, optional range on this curve; `other`, the second curve; `range2`, optional range on `other`; `index`, 1-based extremum index.
- **Returns:** `ExtremaPointPair` for the Nth extremum.
- **OCCT:** `Extrema_ExtCC`.

---

### `LocalExtremaResult`

Result of a local curve-curve extremum search near a seed.

```swift
public struct LocalExtremaResult: Sendable {
    public let isDone:         Bool
    public let squareDistance: Double
    public let point1:         SIMD3<Double>
    public let param1:         Double
    public let point2:         SIMD3<Double>
    public let param2:         Double
}
```

- `isDone`: `true` when the local solver converged.
- Other fields are the same as `ExtremaPointPair`.

| Field | Meaning |
|---|---|
| `isDone` | `true` when the local solver converged. |
| `squareDistance` | Squared distance between the two extremal points (take `sqrt` for actual distance). |
| `point1` / `param1` | Point and parameter on this curve. |
| `point2` / `param2` | Point and parameter on the other curve. |

#### `Curve3D.LocalExtremaResult.param2`

Parameter on the other curve at the local extremum.

---

### `locateExtremaCC(range1:other:range2:seedU:seedV:)`

Finds a local curve-curve extremum near seed parameters.

```swift
public func locateExtremaCC(
    range1: ClosedRange<Double>? = nil,
    other:  Curve3D,
    range2: ClosedRange<Double>? = nil,
    seedU:  Double,
    seedV:  Double
) -> LocalExtremaResult
```

Uses `Extrema_LocateExtCC` for a fast local search around `(seedU, seedV)`. Useful when you already have a good initial guess (e.g. from a prior `extremaCC` call) and want to refine it.

- **Parameters:** `range1`, optional range on this curve; `other`, the second curve; `range2`, optional range on `other`; `seedU`, initial parameter guess on this curve; `seedV`, initial parameter guess on `other`.
- **Returns:** `LocalExtremaResult` with convergence flag and result.
- **OCCT:** `Extrema_LocateExtCC`.
- **Example:**
  ```swift
  if let c1 = Curve3D.bspline(points: pts1),
     let c2 = Curve3D.bspline(points: pts2) {
      let local = c1.locateExtremaCC(other: c2, seedU: 0.5, seedV: 0.3)
      if local.isDone {
          print(local.squareDistance.squareRoot())
      }
  }
  ```

---

### `CurveSurfaceExtrema`

Summary result of a curve-surface extrema computation.

```swift
public struct CurveSurfaceExtrema: Sendable {
    public let isDone:     Bool
    public let isParallel: Bool
    public let count:      Int
}
```

Fields mirror `CurveCurveExtrema`.

---

### `extremaCS(range:surface:)`

Computes curve-to-surface extrema.

```swift
public func extremaCS(
    range:   ClosedRange<Double>? = nil,
    surface: Surface
) -> CurveSurfaceExtrema
```

- **Parameters:** `range`, optional parameter range on this curve; `surface`, the target surface.
- **Returns:** `CurveSurfaceExtrema` summary; use `extremaCSPoint(...)` for individual results.
- **OCCT:** `Extrema_ExtCS`.
- **Example:**
  ```swift
  if let c = Curve3D.line(from: SIMD3(0, 0, 10), to: SIMD3(10, 0, 10)),
     let s = Surface.sphere(radius: 5) {
      let ex = c.extremaCS(surface: s)
      if ex.isDone {
          let pair = c.extremaCSPoint(surface: s, index: 1)
          print(pair.squareDistance.squareRoot())
      }
  }
  ```

---

### `extremaCSPoint(range:surface:index:)`

Returns the Nth extremal point pair from a curve-surface computation (1-based index).

```swift
public func extremaCSPoint(
    range:   ClosedRange<Double>? = nil,
    surface: Surface,
    index:   Int
) -> ExtremaPointPair
```

- **Parameters:** `range`, optional parameter range on this curve; `surface`, the target surface; `index`, 1-based extremum index.
- **Returns:** `ExtremaPointPair`; `param2` encodes the surface U parameter, and `point2.z` encodes V.
- **OCCT:** `Extrema_ExtCS`.

---

### `projectOnSurface(_:range:tolerance:)`

Projects this curve onto a surface, returning a B-spline approximation of the on-surface curve.

```swift
public func projectOnSurface(
    _ surface:  Surface,
    range:      ClosedRange<Double>? = nil,
    tolerance:  Double = 1e-3
) -> Curve3D?
```

Uses `ProjLib_ProjectOnSurface` / `ProjLib_ComputeApprox` to produce a B-spline approximation of the 3D curve lying on the surface.

- **Parameters:** `surface`, the surface to project onto; `range`, optional parameter range on this curve (defaults to full domain); `tolerance`, approximation tolerance (default `1e-3`).
- **Returns:** A new `Curve3D` (B-spline) lying on the surface, or `nil` on failure.
- **OCCT:** `OCCTProjLibProjectOnSurface` → `ProjLib_ProjectOnSurface`.
- **Example:**
  ```swift
  if let line = Curve3D.line(from: SIMD3(0, 0, -10), to: SIMD3(0, 0, 10)),
     let sph  = Surface.sphere(radius: 10),
     let onSph = line.projectOnSurface(sph) {
      // onSph is a B-spline arc along the sphere meridian
  }
  ```

---

### `circleThrough3Points(_:_:_:)`

Creates a circle through three 3D points.

```swift
public static func circleThrough3Points(
    _ p1: SIMD3<Double>,
    _ p2: SIMD3<Double>,
    _ p3: SIMD3<Double>
) -> Curve3D?
```

- **Parameters:** `p1`, `p2`, `p3`, three non-collinear points.
- **Returns:** A `Geom_Circle` passing through all three points, or `nil` if the points are collinear.
- **OCCT:** `gce_MakeCirc` (3-point constructor).
- **Example:**
  ```swift
  if let c = Curve3D.circleThrough3Points(
      SIMD3(5, 0, 0), SIMD3(0, 5, 0), SIMD3(-5, 0, 0)) {
      // c is the circle with radius 5 in the XY plane
  }
  ```

---

### `circleFromCenterNormal(center:normal:radius:)`

Creates a circle from a center point, normal direction, and radius.

```swift
public static func circleFromCenterNormal(
    center: SIMD3<Double>,
    normal: SIMD3<Double>,
    radius: Double
) -> Curve3D?
```

- **Parameters:** `center`, center of the circle; `normal`, plane normal; `radius`, circle radius.
- **Returns:** A `Geom_Circle`, or `nil` on failure (zero normal, or `radius <= 0`).
- **OCCT:** `gce_MakeCirc` (center + normal + radius constructor).
- **Note:** Geometrically identical to [`circle(center:normal:radius:)`](Curve3D.md), which builds the same `gp_Ax2(center, normal)` frame directly. Both enforce the same `radius > 0` precondition, `gce_MakeCirc` itself only rejects a strictly-negative radius, so the bridge adds the zero check to keep the two factories in agreement (#399).
- **Example:**
  ```swift
  if let c = Curve3D.circleFromCenterNormal(
      center: .zero, normal: SIMD3(0, 0, 1), radius: 10) {
      // c is a circle of radius 10 in the XY plane
  }
  ```

---

### `lineFrom2Points(_:_:)`

Creates a line (infinite) through two 3D points.

```swift
public static func lineFrom2Points(_ p1: SIMD3<Double>, _ p2: SIMD3<Double>) -> Curve3D?
```

- **Parameters:** `p1`, `p2`, two distinct points on the line.
- **Returns:** A `Geom_Line`, or `nil` if the points are coincident.
- **OCCT:** `gce_MakeLin`.
- **Example:**
  ```swift
  if let l = Curve3D.lineFrom2Points(SIMD3(0, 0, 0), SIMD3(1, 0, 0)) {
      // l is an infinite line along the X axis
  }
  ```

---

### `directionFrom2Points(_:_:)`

Computes a unit direction vector from two 3D points.

```swift
public static func directionFrom2Points(
    _ p1: SIMD3<Double>,
    _ p2: SIMD3<Double>
) -> SIMD3<Double>?
```

A pure-math utility; does not create a curve. Returns `nil` when the points are coincident.

- **Parameters:** `p1`, origin point; `p2`, destination point.
- **Returns:** Unit direction vector from `p1` toward `p2`, or `nil` if `p1 == p2`.
- **OCCT:** `gce_MakeDir`.
- **Example:**
  ```swift
  if let d = Curve3D.directionFrom2Points(SIMD3(0, 0, 0), SIMD3(3, 4, 0)) {
      // d ≈ SIMD3(0.6, 0.8, 0)
  }
  ```

---

### `ellipseFromCenterNormal(center:normal:majorRadius:minorRadius:)`

Creates a full ellipse from a center, normal, and semi-axis lengths.

```swift
public static func ellipseFromCenterNormal(
    center:      SIMD3<Double>,
    normal:      SIMD3<Double>,
    majorRadius: Double,
    minorRadius: Double
) -> Curve3D?
```

- **Parameters:** `center`, center of the ellipse; `normal`, plane normal; `majorRadius`, semi-major axis length; `minorRadius`, semi-minor axis length (must be ≤ `majorRadius`).
- **Returns:** A `Geom_Ellipse`, or `nil` on failure (either radius `<= 0`, or `minorRadius > majorRadius`).
- **OCCT:** `gce_MakeElips`.
- **Note:** Geometrically identical to [`ellipse(center:normal:majorRadius:minorRadius:)`](Curve3D.md), and enforces the same radius preconditions, `gce_MakeElips` itself accepts a zero minor radius, so the bridge adds the zero check to keep the two factories in agreement (#399).
- **Example:**
  ```swift
  if let e = Curve3D.ellipseFromCenterNormal(
      center: .zero, normal: SIMD3(0, 0, 1),
      majorRadius: 10, minorRadius: 5) {
      // e is an ellipse with semi-axes 10 and 5 in the XY plane
  }
  ```

---

### `hyperbolaFromCenterNormal(center:normal:majorRadius:minorRadius:)`

Creates a hyperbola from a center, normal, and semi-axis lengths.

```swift
public static func hyperbolaFromCenterNormal(
    center:      SIMD3<Double>,
    normal:      SIMD3<Double>,
    majorRadius: Double,
    minorRadius: Double
) -> Curve3D?
```

- **Parameters:** `center`, center; `normal`, plane normal; `majorRadius`, semi-transverse axis; `minorRadius`, semi-conjugate axis.
- **Returns:** A `Geom_Hyperbola`, or `nil` on failure (either radius `<= 0`).
- **OCCT:** `gce_MakeHypr`.
- **Note:** Geometrically identical to [`hyperbola(center:normal:majorRadius:minorRadius:)`](Curve3D.md), and enforces the same radius preconditions, `gce_MakeHypr` itself accepts a zero radius, so the bridge adds the zero check to keep the two factories in agreement (#399).
- **Example:**
  ```swift
  if let h = Curve3D.hyperbolaFromCenterNormal(
      center: .zero, normal: SIMD3(0, 0, 1),
      majorRadius: 5, minorRadius: 3) { }
  ```

---

### `parabolaFromCenterNormal(center:normal:focal:)`

Creates a parabola from a vertex (center), normal, and focal distance.

```swift
public static func parabolaFromCenterNormal(
    center: SIMD3<Double>,
    normal: SIMD3<Double>,
    focal:  Double
) -> Curve3D?
```

- **Parameters:** `center`, vertex (apex) of the parabola; `normal`, plane normal; `focal`, focal distance (distance from vertex to focus).
- **Returns:** A `Geom_Parabola`, or `nil` on failure (`focal <= 0`).
- **OCCT:** `gce_MakeParab`.
- **Note:** Geometrically identical to [`parabola(center:normal:focal:)`](Curve3D.md), and enforces the same focal-length precondition, `gce_MakeParab` itself accepts a zero focal length, so the bridge adds the zero check to keep the two factories in agreement (#399).
- **Example:**
  ```swift
  if let p = Curve3D.parabolaFromCenterNormal(
      center: .zero, normal: SIMD3(0, 0, 1), focal: 2) { }
  ```

---

### `serializeCurves(_:)`

Serializes an array of curves to a string using `GeomTools_CurveSet`.

```swift
public static func serializeCurves(_ curves: [Curve3D]) -> String?
```

The format is OCCT's internal text stream format, suitable for persistence or interprocess transfer. Round-trip with `deserializeCurves(_:)`.

- **Parameters:** `curves`, curves to serialize.
- **Returns:** Serialized string, or `nil` on failure.
- **OCCT:** `GeomTools_CurveSet::Write`.
- **Example:**
  ```swift
  if let c1 = Curve3D.line(from: .zero, to: SIMD3(1, 0, 0)),
     let c2 = Curve3D.arc(center: .zero, radius: 5, startAngle: 0, endAngle: .pi),
     let data = Curve3D.serializeCurves([c1, c2]) {
      // store or transmit `data`
  }
  ```

---

### `deserializeCurves(_:)`

Deserializes curves from a string produced by `serializeCurves(_:)`.

```swift
public static func deserializeCurves(_ data: String) -> [Curve3D]?
```

- **Parameters:** `data`, string produced by `serializeCurves(_:)`.
- **Returns:** Array of reconstructed `Curve3D` values, or `nil` if parsing fails or yields no curves.
- **OCCT:** `GeomTools_CurveSet::Read`.
- **Example:**
  ```swift
  if let curves = Curve3D.deserializeCurves(storedData) {
      for c in curves { /* use c */ }
  }
  ```

---

## ExtremaPC. Point-Curve Distance (v0.130.0)

All-extrema and minimum-distance computation from a point to a curve, backed by `Extrema_ExtPC`.

---

### `ExtremumResult`

Struct returned by `extrema(from:)` and `extrema(from:uMin:uMax:)`.

```swift
public struct ExtremumResult: Sendable {
    public let parameter: Double
    public let distance:  Double
    public let point:     SIMD3<Double>
}
```

- `parameter`: curve parameter at the extremal point.
- `distance`: distance from the query point to the extremal curve point.
- `point`: 3D coordinates of the extremal point on the curve.

---

### `extrema(from:)`

Finds all extrema (closest and farthest points) from a query point to this curve.

```swift
public func extrema(from point: SIMD3<Double>) -> [ExtremumResult]
```

Uses `Extrema_ExtPC` over the full curve domain. Returns up to 64 results. The minimum-distance result is the `ExtremumResult` with the smallest `distance`.

- **Parameters:** `point`, the query point.
- **Returns:** Array of `ExtremumResult` values (empty on failure or no extrema found).
- **OCCT:** `Extrema_ExtPC`.
- **Example:**
  ```swift
  if let arc = Curve3D.arc(center: .zero, radius: 5, startAngle: 0, endAngle: .pi) {
      let results = arc.extrema(from: SIMD3(3, 4, 0))
      if let nearest = results.min(by: { $0.distance < $1.distance }) {
          print(nearest.point, nearest.distance)
      }
  }
  ```

---

### `extrema(from:uMin:uMax:)`

Finds all extrema from a point to a bounded segment of this curve.

```swift
public func extrema(from point: SIMD3<Double>, uMin: Double, uMax: Double) -> [ExtremumResult]
```

Restricts the search to `[uMin, uMax]` using `Extrema_ExtPC` with bounded adaptor. Returns up to 64 results.

- **Parameters:** `point`, query point; `uMin`, lower parameter bound; `uMax`, upper parameter bound.
- **Returns:** Array of `ExtremumResult` values within the specified range (empty on failure).
- **OCCT:** `Extrema_ExtPC` with bounded `GeomAdaptor_Curve`.
- **Example:**
  ```swift
  if let c = Curve3D.bspline(points: myPoints) {
      let lo = c.domain.lowerBound
      let mid = (lo + c.domain.upperBound) / 2
      let results = c.extrema(from: SIMD3(1, 2, 3), uMin: lo, uMax: mid)
  }
  ```

---

### `minimumDistance(from:)`

Returns the minimum distance from a point to this curve.

```swift
public func minimumDistance(from point: SIMD3<Double>) -> Double?
```

Convenience method backed by `Extrema_ExtPC`. Returns `nil` when the algorithm fails to find any extremum.

- **Parameters:** `point`, the query point.
- **Returns:** Minimum distance, or `nil` on failure.
- **OCCT:** `Extrema_ExtPC` via `OCCTExtremaPCMinDistance`.
- **Example:**
  ```swift
  if let c = Curve3D.arc(center: .zero, radius: 5, startAngle: 0, endAngle: .pi),
     let d = c.minimumDistance(from: SIMD3(0, 10, 0)) {
      print(d)  // ≈ 5.0
  }
  ```
