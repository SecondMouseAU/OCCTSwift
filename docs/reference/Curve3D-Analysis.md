---
title: Curve3D — Analysis
parent: API Reference
---

# Curve3D — Analysis

This page covers the analysis and query members of `Curve3D`: curvature and local differential geometry, projection onto planes and surfaces, curve-to-curve and curve-to-surface distance and intersection, quasi-uniform sampling, `ShapeAnalysis_Curve` utilities, continuity analysis, extrema (curve–curve, curve–surface, point–curve), `ProjLib` surface projection, and `gce` analytic-curve factories. For factory methods, B-spline/Bezier construction, and geometric operations see the main [`Curve3D`](Curve3D.md) page.

## Topics

- [Local Properties](#local-properties) · [LocalAnalysis](#localanalysis) · [Projection (v0.22.0)](#projection-v0220) · [Batch Evaluation (v0.29.0)](#batch-evaluation-v0290) · [Curve Distance & Intersection (v0.30.0)](#curve-distance--intersection-v0300) · [Quasi-Uniform Sampling (v0.31.0)](#quasi-uniform-sampling-v0310) · [ShapeAnalysis\_Curve Expansion (v0.49.0)](#shapeanalysis_curve-expansion-v0490) · [v0.80.0: Extrema, ProjLib, gce Factories](#v0800-extrema-projlib-gce-factories) · [ExtremaPC — Point-Curve Distance (v0.130.0)](#extremapc--point-curve-distance-v01300)

---

## Local Properties

Differential geometry queries at a parameter value on the curve, backed by `GeomLProp_CLProps`.

---

### `curvature(at:)`

Returns the curvature at parameter `u`.

```swift
public func curvature(at u: Double) -> Double
```

The curvature is the reciprocal of the radius of the osculating circle at `u`. Zero on a straight line; larger values indicate tighter bends.

- **Parameters:** `u` — curve parameter.
- **Returns:** Curvature value; `0` when `GeomLProp_CLProps` cannot compute it (e.g. tangent is zero-length).
- **OCCT:** `GeomLProp_CLProps::Curvature`.
- **Example:**
  ```swift
  if let arc = Curve3D.arc(center: .zero, radius: 5, startAngle: 0, endAngle: .pi) {
      let k = arc.curvature(at: 0)  // ≈ 0.2 (1/R)
  }
  ```

---

### `tangentDirection(at:)`

Returns the unit tangent direction at parameter `u`.

```swift
public func tangentDirection(at u: Double) -> SIMD3<Double>?
```

- **Parameters:** `u` — curve parameter.
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

- **Parameters:** `u` — curve parameter.
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

- **Parameters:** `u` — curve parameter.
- **Returns:** 3D center of curvature, or `nil` when curvature is zero (straight segment).
- **OCCT:** `GeomLProp_CLProps::CentreOfCurvature`.
- **Example:**
  ```swift
  if let arc = Curve3D.arc(center: .zero, radius: 5, startAngle: 0, endAngle: .pi),
     let c = arc.centerOfCurvature(at: 0) {
      // c ≈ SIMD3(0, 0, 0) — center of the arc
  }
  ```

---

### `torsion(at:)`

Returns the torsion at parameter `u` (the rate of change of the osculating plane).

```swift
public func torsion(at u: Double) -> Double
```

Torsion is zero for planar curves. Non-zero values indicate the curve is twisting out of its local plane.

- **Parameters:** `u` — curve parameter.
- **Returns:** Torsion value (signed); `0` for planar curves or when torsion cannot be computed.
- **OCCT:** `GeomLProp_CLProps::Torsion`.
- **Example:**
  ```swift
  if let helix = Curve3D.helix(radius: 5, pitch: 2, turns: 3) {
      let tau = helix.torsion(at: 0)  // non-zero for a helix
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
    public let status: Int
    public let c0Value: Double
    public let g1Angle: Double
    public let c1Angle: Double
    public let c1Ratio: Double
    public let c2Angle: Double
    public let c2Ratio: Double
    public let g2Angle: Double
    public let g2CurvatureVariation: Double
    public let flags: Int
    public var isC0: Bool { flags & 1  != 0 }
    public var isG1: Bool { flags & 2  != 0 }
    public var isC1: Bool { flags & 4  != 0 }
    public var isG2: Bool { flags & 8  != 0 }
    public var isC2: Bool { flags & 16 != 0 }
}
```

- `status` — raw `GeomAbs_Shape` continuity code (0=C0, 1=G1, 2=C1, 3=G2, 4=C2).
- `c0Value` — positional gap distance at the junction.
- `g1Angle` — angle between tangent directions (radians).
- `c1Angle` / `c1Ratio` — angle and magnitude ratio between first derivatives.
- `c2Angle` / `c2Ratio` — angle and magnitude ratio between second derivatives.
- `g2Angle` — angle between osculating planes.
- `g2CurvatureVariation` — curvature variation at the junction.
- `flags` — bitmask encoding continuity levels; decoded by computed boolean helpers `isC0` … `isC2`.

---

### `continuityWith(_:u1:u2:order:)`

Analyses the continuity between this curve at parameter `u1` and another curve at parameter `u2`.

```swift
public func continuityWith(_ other: Curve3D, u1: Double, u2: Double, order: Int = 4) -> ContinuityAnalysis?
```

`order` controls the maximum continuity level tested: 0=C0, 1=G1, 2=C1, 3=G2, 4=C2 (default). Use at shared endpoints when assembling curves that are expected to meet smoothly.

- **Parameters:** `other` — the second curve; `u1` — parameter on this curve; `u2` — parameter on `other`; `order` — highest order to test (0–4, default 4).
- **Returns:** `ContinuityAnalysis`, or `nil` if `LocalAnalysis_CurveContinuity` fails (e.g. degenerate tangent, invalid order).
- **OCCT:** `LocalAnalysis_CurveContinuity`.
- **Example:**
  ```swift
  if let ca = c1.continuityWith(c2, u1: c1.domain.upperBound, u2: c2.domain.lowerBound) {
      print(ca.isG1, ca.g1Angle)
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

- **Parameters:** `origin` — a point on the target plane; `normal` — the plane normal; `direction` — projection direction (must not be parallel to `normal`).
- **Returns:** Projected 3D curve lying in the plane, or `nil` if projection fails.
- **OCCT:** `GeomProjLib::ProjectOnPlane`.
- **Example:**
  ```swift
  if let helix = Curve3D.helix(radius: 5, pitch: 2, turns: 3),
     let proj  = helix.projectedOnPlane(
         origin: .zero,
         normal: SIMD3(0, 0, 1),
         direction: SIMD3(0, 0, 1)) {
      // proj is the spiral footprint of the helix on the XY plane
  }
  ```

---

## Batch Evaluation (v0.29.0)

Evaluate a curve at many parameter values in a single bridge call for efficiency.

---

### `evaluateGrid(_:)`

Evaluates the curve at multiple parameter values in one call.

```swift
public func evaluateGrid(_ parameters: [Double]) -> [SIMD3<Double>]
```

Significantly faster than calling `point(at:)` in a loop for large parameter arrays. Returns an empty array when `parameters` is empty or the bridge call fails.

- **Parameters:** `parameters` — array of curve parameter values.
- **Returns:** Array of 3D points in the same order as `parameters`. Length equals `parameters.count` on success; may be shorter if the bridge returns fewer valid results.
- **OCCT:** `Geom_Curve::D0` per point, batched through the bridge.
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

- **Parameters:** `parameters` — array of curve parameter values.
- **Returns:** Array of `(point, tangent)` tuples. The tangent is the first derivative, not the unit tangent — normalize if needed.
- **OCCT:** `Geom_Curve::D1` per point, batched through the bridge.
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

- **Parameters:** `tolerance` — planarity tolerance (default `0` uses OCCT internal precision).
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

- `distance` — distance between the two extremal points.
- `point1` / `point2` — closest (or farthest) points on the first and second curve respectively.
- `parameter1` / `parameter2` — parameter values on each curve at the extremal points.

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

- `point` — 3D intersection coordinates.
- `curveParameter` — parameter along the curve at the intersection.
- `surfaceU` / `surfaceV` — surface UV parameters at the intersection.

---

### `minDistance(to:)` (curve overload)

Returns the minimum distance from this curve to another curve.

```swift
public func minDistance(to other: Curve3D) -> Double?
```

- **Parameters:** `other` — the curve to measure against.
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

- **Parameters:** `other` — the second curve; `maxCount` — maximum number of extrema to return (default 20).
- **Returns:** Array of `CurveExtremaResult` values (may be empty if the algorithm finds nothing).
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

- **Parameters:** `surface` — the surface to intersect with; `maxHits` — upper bound on returned hits (default 100).
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

- **Parameters:** `surface` — the surface to measure against.
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

- **Parameters:** `tolerance` — recognition tolerance (default `1e-4`).
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

Uses `GCPnts_QuasiUniformAbscissa` to space `count` parameters approximately evenly along the arc length of the curve. The result is suitable for passing to `evaluateGrid(_:)`.

- **Parameters:** `count` — desired number of sample parameters.
- **Returns:** Array of parameter values of length up to `count`; empty on failure.
- **OCCT:** `GCPnts_QuasiUniformAbscissa`.
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

- **Parameters:** `deflection` — maximum allowed chord deviation from the curve; `maxPoints` — upper bound on returned points (default 500).
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

- `distance` — 3D distance from the query point to the projected point on the curve.
- `parameter` — parameter on the curve at the closest point.
- `point` — 3D coordinates of the closest point on the curve.

---

### `projectPoint(_:precision:)`

Projects a 3D point onto this curve to find the closest point.

```swift
public func projectPoint(_ point: SIMD3<Double>, precision: Double = 1e-6) -> PointProjection
```

Uses `ShapeAnalysis_Curve::Project`. Always returns a result (never `nil`); a non-zero `distance` indicates the query point was not on the curve.

- **Parameters:** `point` — 3D point to project; `precision` — projection precision (default `1e-6`).
- **Returns:** `PointProjection` with distance, parameter, and closest curve point.
- **OCCT:** `ShapeAnalysis_Curve::Project`.
- **Example:**
  ```swift
  if let c = Curve3D.line(from: .zero, to: SIMD3(10, 0, 0)) {
      let proj = c.projectPoint(SIMD3(5, 3, 0))
      print(proj.point)     // ≈ SIMD3(5, 0, 0)
      print(proj.distance)  // ≈ 3.0
  }
  ```

---

### `distance(to:precision:)`

Returns the shortest distance from a 3D point to this curve.

```swift
public func distance(to point: SIMD3<Double>, precision: Double = 1e-6) -> Double
```

Convenience wrapper over `projectPoint(_:precision:)` when only the scalar distance is needed.

- **Parameters:** `point` — query point; `precision` — projection precision (default `1e-6`).
- **Returns:** Shortest distance from `point` to the curve.
- **OCCT:** Delegates to `ShapeAnalysis_Curve::Project` via `projectPoint(_:precision:)`.
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

- `first` / `last` — validated (and possibly clamped) parameter bounds.
- `wasAdjusted` — `true` if the input range was outside the curve's parametric domain and was adjusted.

---

### `validateRange(first:last:precision:)`

Validates and optionally adjusts a parameter range to lie within the curve's parametric domain.

```swift
public func validateRange(first: Double, last: Double, precision: Double = 1e-6) -> ValidatedRange
```

Uses `ShapeAnalysis_Curve::ValidateRange`. Useful before trimming or sampling a curve when the input parameters may be slightly outside the domain.

- **Parameters:** `first` — desired start parameter; `last` — desired end parameter; `precision` — tolerance for domain comparison (default `1e-6`).
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

- **Parameters:** `first` — start parameter; `last` — end parameter; `maxPoints` — upper bound on returned points (default 1000).
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

- `isDone` — `true` when the algorithm completed successfully.
- `isParallel` — `true` when the two curves are parallel (distance is constant along the range).
- `count` — number of extremal point pairs found.

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

- `squareDistance` — squared distance between the two extremal points (take `sqrt` for actual distance).
- `point1` / `param1` — point and parameter on the first curve (or query curve for curve-surface).
- `point2` / `param2` — point and parameter on the second curve, or UV parameters packed as `(u, v, 0)` for curve-surface.

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

When `range1` or `range2` is `nil`, the curve's full `domain` is used. Check `isParallel` before accessing individual point pairs — the `Known OCCT Bugs` section notes that `BRepExtrema_ExtCC` can crash on parallel edges (guarded in the bridge).

- **Parameters:** `range1` — optional parameter range restricting the search on this curve; `other` — the second curve; `range2` — optional parameter range on `other`.
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

- **Parameters:** `range1` — optional range on this curve; `other` — the second curve; `range2` — optional range on `other`; `index` — 1-based extremum index.
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

- `isDone` — `true` when the local solver converged.
- Other fields are the same as `ExtremaPointPair`.

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

- **Parameters:** `range1` — optional range on this curve; `other` — the second curve; `range2` — optional range on `other`; `seedU` — initial parameter guess on this curve; `seedV` — initial parameter guess on `other`.
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

- **Parameters:** `range` — optional parameter range on this curve; `surface` — the target surface.
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

- **Parameters:** `range` — optional parameter range on this curve; `surface` — the target surface; `index` — 1-based extremum index.
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

- **Parameters:** `surface` — the surface to project onto; `range` — optional parameter range on this curve (defaults to full domain); `tolerance` — approximation tolerance (default `1e-3`).
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

- **Parameters:** `p1`, `p2`, `p3` — three non-collinear points.
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

- **Parameters:** `center` — center of the circle; `normal` — plane normal; `radius` — circle radius.
- **Returns:** A `Geom_Circle`, or `nil` on failure (e.g. zero normal or radius).
- **OCCT:** `gce_MakeCirc` (center + normal + radius constructor).
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

- **Parameters:** `p1`, `p2` — two distinct points on the line.
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

- **Parameters:** `p1` — origin point; `p2` — destination point.
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

- **Parameters:** `center` — center of the ellipse; `normal` — plane normal; `majorRadius` — semi-major axis length; `minorRadius` — semi-minor axis length (must be ≤ `majorRadius`).
- **Returns:** A `Geom_Ellipse`, or `nil` on failure.
- **OCCT:** `gce_MakeElips`.
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

- **Parameters:** `center` — center; `normal` — plane normal; `majorRadius` — semi-transverse axis; `minorRadius` — semi-conjugate axis.
- **Returns:** A `Geom_Hyperbola`, or `nil` on failure.
- **OCCT:** `gce_MakeHypr`.
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

- **Parameters:** `center` — vertex (apex) of the parabola; `normal` — plane normal; `focal` — focal distance (distance from vertex to focus).
- **Returns:** A `Geom_Parabola`, or `nil` on failure.
- **OCCT:** `gce_MakeParab`.
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

- **Parameters:** `curves` — curves to serialize.
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

- **Parameters:** `data` — string produced by `serializeCurves(_:)`.
- **Returns:** Array of reconstructed `Curve3D` values, or `nil` if parsing fails or yields no curves.
- **OCCT:** `GeomTools_CurveSet::Read`.
- **Example:**
  ```swift
  if let curves = Curve3D.deserializeCurves(storedData) {
      for c in curves { /* use c */ }
  }
  ```

---

## ExtremaPC — Point-Curve Distance (v0.130.0)

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

- `parameter` — curve parameter at the extremal point.
- `distance` — distance from the query point to the extremal curve point.
- `point` — 3D coordinates of the extremal point on the curve.

---

### `extrema(from:)`

Finds all extrema (closest and farthest points) from a query point to this curve.

```swift
public func extrema(from point: SIMD3<Double>) -> [ExtremumResult]
```

Uses `Extrema_ExtPC` over the full curve domain. Returns up to 64 results. The minimum-distance result is the `ExtremumResult` with the smallest `distance`.

- **Parameters:** `point` — the query point.
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

- **Parameters:** `point` — query point; `uMin` — lower parameter bound; `uMax` — upper parameter bound.
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

- **Parameters:** `point` — the query point.
- **Returns:** Minimum distance, or `nil` on failure.
- **OCCT:** `Extrema_ExtPC` via `OCCTExtremaPCMinDistance`.
- **Example:**
  ```swift
  if let c = Curve3D.arc(center: .zero, radius: 5, startAngle: 0, endAngle: .pi),
     let d = c.minimumDistance(from: SIMD3(0, 10, 0)) {
      print(d)  // ≈ 5.0
  }
  ```
