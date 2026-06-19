---
title: Curve2D — Analysis
parent: API Reference
---

# Curve2D — Analysis

This page covers the analysis and query members of `Curve2D`: differential geometry (curvature, normal, inflection), bounding box, general-purpose intersection/projection/extrema, batch evaluation, analytical intersection primitives, 2D extrema solvers, detailed curvature-inflection classification via `Geom2dLProp`, approximation/simplification via `ShapeCustom_Curve2d` and `Approx_Curve2d`, interpolation, arc-length and trim, local extrema and gce factory construction, serialization/persistence, energy-minimal fair curves, and `Point2D` integration. For primitive construction, B-spline/Bezier operations, and transforms see the main `Curve2D` page.

## Topics

- [Local Properties (Curvature, Normal, Inflection)](#local-properties-curvature-normal-inflection) · [Bounding Box](#bounding-box) · [Analysis](#analysis) · [Batch Evaluation (v0.28.0)](#batch-evaluation-v0280) · [Extrema 2D](#extrema-2d) · [Geom2dLProp: Curvature Inflection/Extrema](#geom2dlprop-curvature-inflectionextrema) · [IntAna2d Analytical Intersections](#intana2d-analytical-intersections) · [ShapeCustom\_Curve2d & Approx\_Curve2d (v0.52.0)](#shapecustom_curve2d--approx_curve2d-v0520) · [v0.115.0: Interpolation expansion, trim, length](#v01150-interpolation-expansion-trim-length) · [v0.80.0: Extrema, gce factories, GeomTools persistence](#v0800-extrema-gce-factories-geomtools-persistence) · [FairCurve](#faircurve) · [Point2D Integration](#point2d-integration)

---

## Local Properties (Curvature, Normal, Inflection)

Differential geometry queries evaluated at a parametric point on the curve, backed by `Geom2dLProp_CLProps2d`.

---

### `curvature(at:)`

Returns the signed curvature (1 / radius of curvature) at parameter `u`.

```swift
public func curvature(at u: Double) -> Double
```

Returns `0` for straight segments or when `Geom2dLProp_CLProps2d` cannot compute the value at the given point.

- **Parameters:** `u` — curve parameter.
- **Returns:** Curvature value; `0` on error or for a straight segment.
- **OCCT:** `Geom2dLProp_CLProps2d::Curvature`.
- **Example:**
  ```swift
  if let circle = Curve2D.circle(center: .zero, radius: 5) {
      let k = circle.curvature(at: 0)  // ≈ 0.2 (1/R)
  }
  ```

---

### `normal(at:)`

Returns the unit inward normal vector at parameter `u`.

```swift
public func normal(at u: Double) -> SIMD2<Double>?
```

- **Parameters:** `u` — curve parameter.
- **Returns:** Unit normal, or `nil` if undefined (e.g. curvature is zero on a straight line).
- **OCCT:** `Geom2dLProp_CLProps2d::Normal`.
- **Example:**
  ```swift
  if let circle = Curve2D.circle(center: .zero, radius: 5),
     let n = circle.normal(at: 0) {
      print(n)  // ≈ (-1, 0) pointing toward center
  }
  ```

---

### `tangentDirection(at:)`

Returns the unit tangent direction at parameter `u`.

```swift
public func tangentDirection(at u: Double) -> SIMD2<Double>?
```

- **Parameters:** `u` — curve parameter.
- **Returns:** Unit tangent, or `nil` if undefined.
- **OCCT:** `Geom2dLProp_CLProps2d::Tangent`.
- **Example:**
  ```swift
  if let circle = Curve2D.circle(center: .zero, radius: 5),
     let t = circle.tangentDirection(at: 0) {
      print(t)  // ≈ (0, 1)
  }
  ```

---

### `centerOfCurvature(at:)`

Returns the center of the osculating circle at parameter `u`.

```swift
public func centerOfCurvature(at u: Double) -> SIMD2<Double>?
```

- **Parameters:** `u` — curve parameter.
- **Returns:** Center of curvature, or `nil` if curvature is zero (straight segment).
- **OCCT:** `Geom2dLProp_CLProps2d::CentreOfCurvature`.
- **Example:**
  ```swift
  if let circle = Curve2D.circle(center: .zero, radius: 5),
     let coc = circle.centerOfCurvature(at: 0) {
      print(coc)  // ≈ (0, 0) — the center of the circle itself
  }
  ```

---

### `inflectionPoints()`

Finds all inflection points (where curvature changes sign) and returns their parameter values.

```swift
public func inflectionPoints() -> [Double]
```

Capped internally at 256 results.

- **Returns:** Array of parameter values at inflection points (may be empty).
- **OCCT:** `Geom2dLProp_CLProps2d` inflection detection.
- **Example:**
  ```swift
  if let spline = Curve2D.interpolate(points: pts, startTangent: t1, endTangent: t2) {
      let inflections = spline.inflectionPoints()
  }
  ```

---

### `curvatureExtrema()`

Finds local minima and maxima of curvature magnitude.

```swift
public func curvatureExtrema() -> [Curve2DSpecialPoint]
```

Returns `Curve2DSpecialPoint` values with `.minCurvature` or `.maxCurvature` type classification. Capped at 256 results.

- **Returns:** Array of special points (may be empty).
- **OCCT:** `Geom2dLProp_CLProps2d` curvature extrema.
- **Example:**
  ```swift
  if let spline = Curve2D.interpolate(points: pts, startTangent: t1, endTangent: t2) {
      for sp in spline.curvatureExtrema() {
          print(sp.parameter, sp.type)
      }
  }
  ```

---

### `allSpecialPoints()`

Returns all special points — both inflection points and curvature extrema — in a single pass.

```swift
public func allSpecialPoints() -> [Curve2DSpecialPoint]
```

Capped internally at 256 results.

- **Returns:** Array of `Curve2DSpecialPoint` values (`.inflection`, `.minCurvature`, or `.maxCurvature`).
- **OCCT:** `Geom2dLProp_CLProps2d`.
- **Example:**
  ```swift
  if let spline = Curve2D.interpolate(points: pts, startTangent: t1, endTangent: t2) {
      let special = spline.allSpecialPoints()
  }
  ```

---

### `Curve2DSpecialPointType`

Enum classifying a special point on a curve.

```swift
public enum Curve2DSpecialPointType: Int32, Sendable {
    case inflection    = 0
    case minCurvature  = 1
    case maxCurvature  = 2
}
```

---

### `Curve2DSpecialPoint`

Struct returned by `curvatureExtrema()` and `allSpecialPoints()`.

```swift
public struct Curve2DSpecialPoint: Sendable {
    public let parameter: Double
    public let type: Curve2DSpecialPointType
}
```

- `parameter` — curve parameter at the special point.
- `type` — inflection, minimum curvature, or maximum curvature.

---

## Bounding Box

---

### `boundingBox`

The axis-aligned bounding box of this curve.

```swift
public var boundingBox: (min: SIMD2<Double>, max: SIMD2<Double>)?
```

- **Returns:** Tuple with `min` and `max` corners, or `nil` if the underlying curve has no computable bounding box.
- **OCCT:** `Geom2dAdaptor_Curve` + `BndLib_Add2dCurve`.
- **Example:**
  ```swift
  if let circle = Curve2D.circle(center: .zero, radius: 5),
     let bb = circle.boundingBox {
      print(bb.min, bb.max)  // ≈ (-5,-5), (5,5)
  }
  ```

---

## Analysis

General-purpose 2D intersection, projection, and extrema members of `Curve2D`.

---

### `Curve2DIntersection`

Struct representing an intersection between two 2D curves.

```swift
public struct Curve2DIntersection: Sendable {
    public let point:      SIMD2<Double>
    public let parameter1: Double
    public let parameter2: Double
}
```

- `point` — 2D intersection coordinate.
- `parameter1` / `parameter2` — parameters on the first and second curves at the intersection.

---

### `Curve2DProjection`

Struct representing a projection of a point onto a 2D curve.

```swift
public struct Curve2DProjection: Sendable {
    public let point:     SIMD2<Double>
    public let parameter: Double
    public let distance:  Double
}
```

- `point` — nearest point on the curve.
- `parameter` — curve parameter at that point.
- `distance` — distance from the queried point to the curve.

---

### `Curve2DExtremaResult`

Struct representing a distance extremum between two 2D curves.

```swift
public struct Curve2DExtremaResult: Sendable {
    public let pointOnCurve1: SIMD2<Double>
    public let pointOnCurve2: SIMD2<Double>
    public let parameter1:    Double
    public let parameter2:    Double
    public let distance:      Double
}
```

---

### `intersections(with:tolerance:)`

Finds all intersection points between this curve and another.

```swift
public func intersections(with other: Curve2D, tolerance: Double = 1e-6) -> [Curve2DIntersection]
```

Capped at 128 results.

- **Parameters:** `other` — the curve to intersect with; `tolerance` — intersection tolerance (default `1e-6`).
- **Returns:** Array of `Curve2DIntersection` values (may be empty).
- **OCCT:** `Geom2dAPI_InterCurveCurve`.
- **Example:**
  ```swift
  if let c1 = Curve2D.circle(center: .zero, radius: 5),
     let c2 = Curve2D.circle(center: SIMD2(3, 0), radius: 5) {
      let pts = c1.intersections(with: c2)
      // pts.count == 2 for overlapping circles
  }
  ```

---

### `selfIntersections(tolerance:)`

Finds all self-intersection points of this curve.

```swift
public func selfIntersections(tolerance: Double = 1e-6) -> [Curve2DIntersection]
```

Capped at 128 results.

- **Parameters:** `tolerance` — intersection tolerance (default `1e-6`).
- **Returns:** Array of `Curve2DIntersection` values (may be empty).
- **OCCT:** `Geom2dAPI_InterCurveCurve` self-intersection mode.
- **Example:**
  ```swift
  if let figure8 = makeFigureEightCurve() {
      let si = figure8.selfIntersections()
  }
  ```

---

### `project(point:)`

Projects a point onto this curve, returning the single nearest projection.

```swift
public func project(point p: SIMD2<Double>) -> Curve2DProjection?
```

- **Parameters:** `p` — 2D point to project.
- **Returns:** Nearest `Curve2DProjection`, or `nil` on failure (negative distance sentinel from bridge).
- **OCCT:** `Geom2dAPI_ProjectPointOnCurve`.
- **Example:**
  ```swift
  if let circle = Curve2D.circle(center: .zero, radius: 5),
     let proj = circle.project(point: SIMD2(3, 4)) {
      print(proj.parameter, proj.distance)  // distance ≈ 0 (point is on the circle)
  }
  ```

---

### `allProjections(of:)`

Projects a point onto this curve, returning all projection solutions.

```swift
public func allProjections(of p: SIMD2<Double>) -> [Curve2DProjection]
```

Capped at 64 results. Useful when there are multiple equidistant points (e.g. projecting the center onto a circle).

- **Parameters:** `p` — 2D point to project.
- **Returns:** Array of `Curve2DProjection` values (may be empty).
- **OCCT:** `Geom2dAPI_ProjectPointOnCurve` (all solutions).
- **Example:**
  ```swift
  if let circle = Curve2D.circle(center: .zero, radius: 5) {
      let projs = circle.allProjections(of: .zero)
      // all points on the circle are equidistant
  }
  ```

---

### `minDistance(to:)`

Finds the minimum distance between this curve and another.

```swift
public func minDistance(to other: Curve2D) -> Curve2DExtremaResult?
```

- **Parameters:** `other` — the curve to measure distance to.
- **Returns:** `Curve2DExtremaResult` for the closest pair of points, or `nil` on failure.
- **OCCT:** `Geom2dAPI_ExtremaCurveCurve` (minimum solution).
- **Example:**
  ```swift
  if let c1 = Curve2D.circle(center: .zero, radius: 3),
     let c2 = Curve2D.circle(center: SIMD2(10, 0), radius: 3),
     let ex = c1.minDistance(to: c2) {
      print(ex.distance)  // ≈ 4.0
  }
  ```

---

### `allExtrema(with:)`

Finds all distance extrema (local min and max distances) between this curve and another.

```swift
public func allExtrema(with other: Curve2D) -> [Curve2DExtremaResult]
```

Capped at 64 results.

- **Parameters:** `other` — the curve to compute extrema against.
- **Returns:** Array of `Curve2DExtremaResult` values (may be empty).
- **OCCT:** `Geom2dAPI_ExtremaCurveCurve` (all solutions).
- **Example:**
  ```swift
  if let c1 = Curve2D.circle(center: .zero, radius: 3),
     let c2 = Curve2D.circle(center: SIMD2(10, 0), radius: 3) {
      let extrema = c1.allExtrema(with: c2)
      // extrema.count == 2 (closest and farthest pair of points)
  }
  ```

---

## Batch Evaluation (v0.28.0)

---

### `evaluateGrid(_:)`

Evaluates the curve at multiple parameter values in a single call.

```swift
public func evaluateGrid(_ parameters: [Double]) -> [SIMD2<Double>]
```

Uses OCCT's optimised grid evaluator; faster than calling `point(at:)` repeatedly for dense sampling.

- **Parameters:** `parameters` — array of parameter values.
- **Returns:** Array of 2D points corresponding to each parameter; empty if `parameters` is empty.
- **OCCT:** `Geom2dAdaptor_Curve::Value` via bridge buffer.
- **Example:**
  ```swift
  if let circle = Curve2D.circle(center: .zero, radius: 5) {
      let params = stride(from: 0.0, through: 2 * .pi, by: 0.01).map { $0 }
      let points = circle.evaluateGrid(params)
  }
  ```

---

### `evaluateGridD1(_:)`

Evaluates the curve and its first derivative at multiple parameter values in a single call.

```swift
public func evaluateGridD1(_ parameters: [Double]) -> [(point: SIMD2<Double>, tangent: SIMD2<Double>)]
```

- **Parameters:** `parameters` — array of parameter values.
- **Returns:** Array of `(point, tangent)` tuples; empty if `parameters` is empty.
- **OCCT:** `Geom2dAdaptor_Curve::D1` via bridge buffer.
- **Example:**
  ```swift
  if let circle = Curve2D.circle(center: .zero, radius: 5) {
      let params = [0.0, .pi / 2, .pi, 3 * .pi / 2]
      let results = circle.evaluateGridD1(params)
      for r in results { print(r.point, r.tangent) }
  }
  ```

---

## Extrema 2D

Elementary 2D curve–curve and point–curve distance solvers (`Extrema_ExtElC2d`, `Extrema_ExtPElC2d`, `Extrema_ExtCC2d`).

---

### `Extrema2DResult`

Struct representing a single distance extremum between two 2D elements.

```swift
public struct Extrema2DResult: Sendable {
    public let squareDistance: Double
    public var distance: Double { squareDistance.squareRoot() }
    public let param1:  Double
    public let param2:  Double
    public let point1:  SIMD2<Double>
    public let point2:  SIMD2<Double>
}
```

- `squareDistance` — squared distance (avoids sqrt cost).
- `distance` — computed square root of `squareDistance`.
- `param1` / `param2` — parameters on the first and second elements.
- `point1` / `point2` — closest points on each element.

---

### `Extrema2d.distanceBetweenLines(line1Point:line1Dir:line2Point:line2Dir:tolerance:)`

Computes the distance between two 2D lines.

```swift
public static func distanceBetweenLines(
    line1Point: SIMD2<Double>, line1Dir: SIMD2<Double>,
    line2Point: SIMD2<Double>, line2Dir: SIMD2<Double>,
    tolerance: Double = 1e-6
) -> (isParallel: Bool, results: [Extrema2DResult])
```

When lines are parallel, `isParallel` is `true` and one result with the perpendicular distance is returned.

- **Returns:** `(isParallel, results)` — when parallel: one result with distance; when intersecting: one result with distance zero.
- **OCCT:** `Extrema_ExtElC2d` (line–line).
- **Example:**
  ```swift
  let r = Extrema2d.distanceBetweenLines(
      line1Point: .zero, line1Dir: SIMD2(1, 0),
      line2Point: SIMD2(0, 5), line2Dir: SIMD2(1, 0))
  // r.isParallel == true, r.results.first?.distance ≈ 5
  ```

---

### `Extrema2d.distanceBetweenLineAndCircle(linePoint:lineDir:circleCenter:circleRadius:tolerance:)`

Computes distance extrema between a 2D line and a 2D circle.

```swift
public static func distanceBetweenLineAndCircle(
    linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
    circleCenter: SIMD2<Double>, circleRadius: Double,
    tolerance: Double = 1e-6
) -> [Extrema2DResult]
```

- **Returns:** Array of extrema results (min and/or max distance points; may be empty on failure).
- **OCCT:** `Extrema_ExtElC2d` (line–circle).
- **Example:**
  ```swift
  let extrema = Extrema2d.distanceBetweenLineAndCircle(
      linePoint: SIMD2(0, 10), lineDir: SIMD2(1, 0),
      circleCenter: .zero, circleRadius: 5)
  ```

---

### `Extrema2d.distanceFromPointToCircle(point:circleCenter:circleRadius:tolerance:)`

Returns the closest and farthest points on a 2D circle from a given point.

```swift
public static func distanceFromPointToCircle(
    point: SIMD2<Double>,
    circleCenter: SIMD2<Double>, circleRadius: Double,
    tolerance: Double = 1e-6
) -> [Extrema2DResult]
```

- **Returns:** Array of up to 2 results (min and max distance to the circle).
- **OCCT:** `Extrema_ExtPElC2d` (point–circle).
- **Example:**
  ```swift
  let extrema = Extrema2d.distanceFromPointToCircle(
      point: SIMD2(10, 0), circleCenter: .zero, circleRadius: 5)
  // extrema[0].distance ≈ 5 (near), extrema[1].distance ≈ 15 (far)
  ```

---

### `Extrema2d.distanceFromPointToLine(point:linePoint:lineDir:tolerance:)`

Returns the closest point on a 2D line from a given point.

```swift
public static func distanceFromPointToLine(
    point: SIMD2<Double>,
    linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
    tolerance: Double = 1e-6
) -> [Extrema2DResult]
```

- **Returns:** Array with one result (the foot of the perpendicular from the point to the line).
- **OCCT:** `Extrema_ExtPElC2d` (point–line).
- **Example:**
  ```swift
  let r = Extrema2d.distanceFromPointToLine(
      point: SIMD2(3, 4),
      linePoint: .zero, lineDir: SIMD2(1, 0))
  // r.first?.distance ≈ 4
  ```

---

### `Extrema2d.distanceBetweenCurves(_:first1:last1:_:first2:last2:)`

Finds all distance extrema between two arbitrary 2D curves within given parameter ranges.

```swift
public static func distanceBetweenCurves(
    _ c1: Curve2D, first1: Double, last1: Double,
    _ c2: Curve2D, first2: Double, last2: Double
) -> [Extrema2DResult]
```

Capped at 32 results.

- **Parameters:** `c1`/`c2` — the two curves; `first1`/`last1` — parameter range on `c1`; `first2`/`last2` — parameter range on `c2`.
- **Returns:** Array of `Extrema2DResult` values for all local extrema (may be empty).
- **OCCT:** `Extrema_ExtCC2d`.
- **Example:**
  ```swift
  if let c1 = Curve2D.circle(center: .zero, radius: 3),
     let c2 = Curve2D.circle(center: SIMD2(8, 0), radius: 2) {
      let ex = Extrema2d.distanceBetweenCurves(c1, first1: 0, last1: 2 * .pi,
                                               c2, first2: 0, last2: 2 * .pi)
  }
  ```

---

## Geom2dLProp: Curvature Inflection/Extrema

Higher-resolution curvature feature detection via `Geom2dLProp_NumericCurInf2d`.

---

### `CurInfType`

Enum classifying a curvature feature point.

```swift
public enum CurInfType: Int32, Sendable {
    case curvatureMinimum = 0
    case curvatureMaximum = 1
    case inflection       = 2
}
```

---

### `CurInfPoint`

Struct returned by `curvatureExtremaDetailed()` and `inflectionPointsDetailed()`.

```swift
public struct CurInfPoint: Sendable {
    public let parameter: Double
    public let type:      CurInfType
}
```

---

### `curvatureExtremaDetailed()`

Finds local curvature extrema with min/max type classification.

```swift
public func curvatureExtremaDetailed() -> [CurInfPoint]
```

Unlike `curvatureExtrema()` (which returns `Curve2DSpecialPoint`), this returns `CurInfPoint` values using the `CurInfType` enum. Capped at 64 results.

- **Returns:** Array of `CurInfPoint` with `.curvatureMinimum` or `.curvatureMaximum` type.
- **OCCT:** `Geom2dLProp_NumericCurInf2d::PerformCurExt`.
- **Example:**
  ```swift
  if let spline = Curve2D.interpolate(points: pts, startTangent: t1, endTangent: t2) {
      for pt in spline.curvatureExtremaDetailed() {
          print(pt.parameter, pt.type)
      }
  }
  ```

---

### `inflectionPointsDetailed()`

Finds inflection points with type information.

```swift
public func inflectionPointsDetailed() -> [CurInfPoint]
```

Like `inflectionPoints()` but returns `CurInfPoint` values (all with `.inflection` type) rather than bare `Double` parameters. Capped at 64 results.

- **Returns:** Array of `CurInfPoint` (all `.inflection`).
- **OCCT:** `Geom2dLProp_NumericCurInf2d::PerformInf`.
- **Example:**
  ```swift
  if let spline = Curve2D.interpolate(points: pts, startTangent: t1, endTangent: t2) {
      let infl = spline.inflectionPointsDetailed()
  }
  ```

---

## IntAna2d Analytical Intersections

Exact (closed-form) intersection between elementary 2D curves. All methods return `[Intersection2DPoint]`.

---

### `Intersection2DPoint`

Struct representing an analytical 2D intersection result.

```swift
public struct Intersection2DPoint: Sendable {
    public let point:  SIMD2<Double>
    public let param1: Double
    public let param2: Double
}
```

- `point` — 2D coordinates of the intersection.
- `param1` / `param2` — parameters on each input element at the intersection.

---

### `IntAna2d.intersectLines(line1Point:line1Dir:line2Point:line2Dir:)`

Intersects two 2D lines analytically.

```swift
public static func intersectLines(
    line1Point: SIMD2<Double>, line1Dir: SIMD2<Double>,
    line2Point: SIMD2<Double>, line2Dir: SIMD2<Double>
) -> [Intersection2DPoint]
```

Returns 0 results for parallel lines, 1 result for a transverse intersection.

- **Returns:** Array of `Intersection2DPoint` (0 or 1 elements).
- **OCCT:** `IntAna2d_AnaIntersection` (line–line).
- **Example:**
  ```swift
  let pts = IntAna2d.intersectLines(
      line1Point: .zero, line1Dir: SIMD2(1, 0),
      line2Point: .zero, line2Dir: SIMD2(0, 1))
  // pts.count == 1, pts[0].point ≈ (0, 0)
  ```

---

### `IntAna2d.intersectLineCircle(linePoint:lineDir:circleCenter:circleRadius:)`

Intersects a 2D line and a circle analytically.

```swift
public static func intersectLineCircle(
    linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
    circleCenter: SIMD2<Double>, circleRadius: Double
) -> [Intersection2DPoint]
```

Returns 0, 1 (tangent), or 2 intersection points.

- **Returns:** Array of 0–2 `Intersection2DPoint` values.
- **OCCT:** `IntAna2d_AnaIntersection` (line–circle).
- **Example:**
  ```swift
  let pts = IntAna2d.intersectLineCircle(
      linePoint: SIMD2(0, -10), lineDir: SIMD2(0, 1),
      circleCenter: .zero, circleRadius: 5)
  // pts.count == 2 (chord through circle)
  ```

---

### `IntAna2d.intersectCircles(center1:radius1:center2:radius2:)`

Intersects two 2D circles analytically.

```swift
public static func intersectCircles(
    center1: SIMD2<Double>, radius1: Double,
    center2: SIMD2<Double>, radius2: Double
) -> [Intersection2DPoint]
```

Returns 0 (disjoint or concentric), 1 (tangent), or 2 intersection points.

- **Returns:** Array of 0–2 `Intersection2DPoint` values.
- **OCCT:** `IntAna2d_AnaIntersection` (circle–circle).
- **Example:**
  ```swift
  let pts = IntAna2d.intersectCircles(
      center1: .zero, radius1: 5,
      center2: SIMD2(6, 0), radius2: 5)
  // pts.count == 2
  ```

---

## ShapeCustom\_Curve2d & Approx\_Curve2d (v0.52.0)

Curve simplification, linearity detection, and BSpline approximation from `ShapeCustom_Curve2d` and `Approx_Curve2d`.

---

### `isLinear(tolerance:)`

Checks whether this 2D BSpline curve has nearly collinear control points.

```swift
public func isLinear(tolerance: Double = 1e-6) -> (isLinear: Bool, deviation: Double)?
```

- **Parameters:** `tolerance` — maximum allowed deviation from a straight line.
- **Returns:** Tuple `(isLinear, deviation)` where `deviation` is the actual maximum deviation, or `nil` if the curve is not a BSpline.
- **OCCT:** `ShapeCustom_Curve2d::IsLinear`.
- **Example:**
  ```swift
  if let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)),
     let bsp = seg.toBSpline(),
     let check = bsp.isLinear() {
      print(check.isLinear, check.deviation)  // true, ≈ 0
  }
  ```

---

### `convertToLine(first:last:tolerance:)`

Converts a nearly-linear 2D curve to a line within the given parameter range.

```swift
public func convertToLine(
    first: Double, last: Double, tolerance: Double = 1e-3
) -> (line: Curve2D, newFirst: Double, newLast: Double, deviation: Double)?
```

Returns the equivalent line curve along with reparametrized bounds, or `nil` if the curve is not within tolerance of a line.

- **Parameters:** `first`/`last` — parameter range to check; `tolerance` — deviation tolerance.
- **Returns:** Tuple `(line, newFirst, newLast, deviation)`, or `nil` if not linear within tolerance.
- **OCCT:** `ShapeCustom_Curve2d::ConvertToLine`.
- **Example:**
  ```swift
  if let bsp = someCurve.toBSpline(),
     let result = bsp.convertToLine(first: 0, last: 1) {
      let line = result.line
  }
  ```

---

### `simplifyBSpline(tolerance:)`

Removes unnecessary knots from a 2D BSpline in place.

```swift
@discardableResult
public func simplifyBSpline(tolerance: Double = 1e-6) -> Bool
```

Mutates the receiver. Returns `true` if any knots were removed.

- **Parameters:** `tolerance` — maximum allowed shape deviation after removal.
- **Returns:** `true` if simplification occurred.
- **OCCT:** `ShapeCustom_Curve2d::SimplifyBSpline`.
- **Example:**
  ```swift
  if let bsp = someCurve.toBSpline() {
      bsp.simplifyBSpline(tolerance: 1e-4)
  }
  ```

---

### `approximated(first:last:toleranceU:toleranceV:maxDegree:maxSegments:)`

Approximates this 2D curve as a BSpline over a given parameter range.

```swift
public func approximated(
    first: Double, last: Double,
    toleranceU: Double = 1e-6, toleranceV: Double = 1e-6,
    maxDegree: Int = 8, maxSegments: Int = 100
) -> Curve2D?
```

Distinct from the instance method `approximated(tolerance:continuity:maxSegments:maxDegree:)` (which takes continuity as a parameter). This overload uses `Approx_Curve2d` and accepts separate U/V tolerances.

- **Parameters:** `first`/`last` — parameter range; `toleranceU`/`toleranceV` — approximation tolerances; `maxDegree` — maximum polynomial degree (default 8); `maxSegments` — maximum number of segments (default 100).
- **Returns:** Approximated BSpline `Curve2D`, or `nil` on failure.
- **OCCT:** `Approx_Curve2d`.
- **Example:**
  ```swift
  if let approx = someCurve.approximated(first: 0, last: 1, toleranceU: 1e-4) {
      print(approx.degree)
  }
  ```

---

## v0.115.0: Interpolation expansion, trim, length

---

### `interpolate(points:startTangent:endTangent:)`

Interpolates a 2D BSpline through a sequence of points with prescribed endpoint tangents.

```swift
public static func interpolate(
    points: [SIMD2<Double>],
    startTangent: SIMD2<Double>,
    endTangent: SIMD2<Double>
) -> Curve2D?
```

- **Parameters:** `points` — interpolation points; `startTangent`/`endTangent` — tangent directions at the first and last point.
- **Returns:** Interpolated BSpline, or `nil` on failure.
- **OCCT:** `Geom2dAPI_Interpolate` (with tangent constraints).
- **Example:**
  ```swift
  let pts: [SIMD2<Double>] = [.zero, SIMD2(5, 3), SIMD2(10, 0)]
  if let curve = Curve2D.interpolate(
      points: pts,
      startTangent: SIMD2(1, 0),
      endTangent: SIMD2(1, 0)) {
      print(curve.domain)
  }
  ```

---

### `interpolatePeriodic(points:)`

Interpolates a closed (periodic) 2D BSpline through a sequence of points.

```swift
public static func interpolatePeriodic(points: [SIMD2<Double>]) -> Curve2D?
```

- **Parameters:** `points` — interpolation points (do not repeat the first point at the end; the bridge closes the curve automatically).
- **Returns:** Periodic BSpline, or `nil` on failure.
- **OCCT:** `Geom2dAPI_Interpolate` (periodic).
- **Example:**
  ```swift
  let pts: [SIMD2<Double>] = [SIMD2(5, 0), SIMD2(0, 5), SIMD2(-5, 0), SIMD2(0, -5)]
  if let loop = Curve2D.interpolatePeriodic(points: pts) {
      print(loop.isClosed)
  }
  ```

---

### `approximate(points:degMin:degMax:continuity:tolerance:)`

Approximates (fits) a 2D BSpline through a set of points with degree and continuity control.

```swift
public static func approximate(
    points: [SIMD2<Double>],
    degMin: Int = 3, degMax: Int = 8,
    continuity: Int = 2, tolerance: Double = 1e-3
) -> Curve2D?
```

- **Parameters:** `points` — sample points to approximate; `degMin`/`degMax` — degree range; `continuity` — desired continuity (0=C0, 1=C1, 2=C2); `tolerance` — maximum fitting error.
- **Returns:** Approximated BSpline, or `nil` on failure.
- **OCCT:** `Geom2dAPI_PointsToBSpline`.
- **Example:**
  ```swift
  let pts = (0..<20).map { i -> SIMD2<Double> in
      let t = Double(i) / 19 * 2 * .pi
      return SIMD2(cos(t) * 5, sin(t) * 3)
  }
  if let ellipseApprox = Curve2D.approximate(points: pts) {
      print(ellipseApprox.degree)
  }
  ```

---

### `arcLength(from:to:)`

Computes the arc length of this curve between two parameter values.

```swift
public func arcLength(from u1: Double, to u2: Double) -> Double
```

- **Parameters:** `u1`/`u2` — parameter range.
- **Returns:** Arc length value (always non-negative when `u1 ≤ u2`).
- **OCCT:** `GeomAdaptor_Curve` + `GCPnts_AbscissaPoint::Length`.
- **Example:**
  ```swift
  if let circle = Curve2D.circle(center: .zero, radius: 5) {
      let halfCircumference = circle.arcLength(from: 0, to: .pi)  // ≈ 15.71
  }
  ```

---

### `splitAtContinuity(continuity:tolerance:maxSegments:)`

Splits this curve at discontinuities of the requested continuity level.

```swift
public func splitAtContinuity(
    continuity: Int = 1, tolerance: Double = 1e-6,
    maxSegments: Int = 32
) -> [Curve2D]
```

- **Parameters:** `continuity` — 0=C0, 1=C1, 2=C2; `tolerance` — detection tolerance; `maxSegments` — upper bound on returned segments.
- **Returns:** Array of sub-curves (one per continuous segment); may be empty if the curve has no discontinuities or the split fails.
- **OCCT:** `Geom2dConvert::C0BSplineToArrayOfC1BSplineCurve` and related splitting utilities.
- **Example:**
  ```swift
  if let composite = Curve2D.join([seg1, seg2, seg3]) {
      let pieces = composite.splitAtContinuity(continuity: 1)
  }
  ```

---

## v0.80.0: Extrema, gce factories, GeomTools persistence

Local extrema search, factory construction from `gce_Make*` classes, and serialization via `GeomTools_Curve2dSet`.

---

### `LocalExtrema2dResult`

Struct returned by `locateExtremaCC(range1:other:range2:seedU:seedV:)`.

```swift
public struct LocalExtrema2dResult: Sendable {
    public let isDone:         Bool
    public let squareDistance: Double
    public let point1:         SIMD2<Double>
    public let param1:         Double
    public let point2:         SIMD2<Double>
    public let param2:         Double
}
```

- `isDone` — `true` if a local extremum was found near the seed parameters.
- `squareDistance` — squared distance at the local extremum.
- `point1`/`point2` — closest points on each curve.
- `param1`/`param2` — parameters at those points.

---

### `locateExtremaCC(range1:other:range2:seedU:seedV:)`

Finds a local curve–curve extremum near given seed parameters using `Extrema_LocateExtCC2d`.

```swift
public func locateExtremaCC(
    range1: ClosedRange<Double>? = nil,
    other: Curve2D,
    range2: ClosedRange<Double>? = nil,
    seedU: Double, seedV: Double
) -> LocalExtrema2dResult
```

When `range1`/`range2` are `nil`, the curve's full `domain` is used. Useful for finding a specific local minimum when the approximate location is known.

- **Parameters:** `range1`/`range2` — optional parameter ranges on `self` and `other`; `seedU`/`seedV` — initial parameter guesses on `self` and `other`.
- **Returns:** `LocalExtrema2dResult` (check `isDone` before using distance/point fields).
- **OCCT:** `Extrema_LocateExtCC2d`.
- **Example:**
  ```swift
  if let c1 = Curve2D.circle(center: .zero, radius: 3),
     let c2 = Curve2D.circle(center: SIMD2(8, 0), radius: 2) {
      let r = c1.locateExtremaCC(other: c2, seedU: 0, seedV: .pi)
      if r.isDone { print(r.squareDistance.squareRoot()) }
  }
  ```

---

### `circleFromCenterRadius(center:radius:)`

Creates a 2D circle from a center point and radius using `gce_MakeCirc2d`.

```swift
public static func circleFromCenterRadius(center: SIMD2<Double>, radius: Double) -> Curve2D?
```

- **Parameters:** `center` — center point; `radius` — radius.
- **Returns:** `Curve2D` (circle), or `nil` on failure (e.g. radius ≤ 0).
- **OCCT:** `gce_MakeCirc2d` (center + radius constructor).
- **Example:**
  ```swift
  if let c = Curve2D.circleFromCenterRadius(center: SIMD2(1, 2), radius: 4) {
      print(c.circleProperties.radius)  // 4.0
  }
  ```

---

### `circleThrough3Points(_:_:_:)`

Creates a 2D circle through three points using `gce_MakeCirc2d`.

```swift
public static func circleThrough3Points(
    _ p1: SIMD2<Double>, _ p2: SIMD2<Double>, _ p3: SIMD2<Double>
) -> Curve2D?
```

- **Parameters:** `p1`, `p2`, `p3` — three non-collinear points.
- **Returns:** `Curve2D` (circle), or `nil` if points are collinear or coincident.
- **OCCT:** `gce_MakeCirc2d` (3-point constructor).
- **Example:**
  ```swift
  if let c = Curve2D.circleThrough3Points(SIMD2(5,0), SIMD2(0,5), SIMD2(-5,0)) {
      print(c.circleProperties.center)  // ≈ (0, 0)
  }
  ```

---

### `lineFrom2Points(_:_:)`

Creates a 2D line through two points using `gce_MakeLin2d`.

```swift
public static func lineFrom2Points(_ p1: SIMD2<Double>, _ p2: SIMD2<Double>) -> Curve2D?
```

- **Parameters:** `p1`, `p2` — two distinct points.
- **Returns:** `Curve2D` (infinite line), or `nil` if points coincide.
- **OCCT:** `gce_MakeLin2d` (2-point constructor).
- **Example:**
  ```swift
  if let line = Curve2D.lineFrom2Points(SIMD2(0, 0), SIMD2(1, 1)) {
      print(line.lineProperties.direction)  // ≈ (0.707, 0.707)
  }
  ```

---

### `lineFromEquation(a:b:c:)`

Creates a 2D line from the equation `Ax + By + C = 0` using `gce_MakeLin2d`.

```swift
public static func lineFromEquation(a: Double, b: Double, c: Double) -> Curve2D?
```

- **Parameters:** `a`, `b`, `c` — line equation coefficients.
- **Returns:** `Curve2D` (infinite line), or `nil` on failure (e.g. `a == 0 && b == 0`).
- **OCCT:** `gce_MakeLin2d` (equation constructor).
- **Example:**
  ```swift
  // y = 2 → 0·x + 1·y − 2 = 0
  if let line = Curve2D.lineFromEquation(a: 0, b: 1, c: -2) {
      print(line.lineProperties.location)  // ≈ (0, 2)
  }
  ```

---

### `ellipseFromCenterDir(center:direction:majorRadius:minorRadius:)`

Creates a 2D ellipse from center, major-axis direction, and semi-radii using `gce_MakeElips2d`.

```swift
public static func ellipseFromCenterDir(
    center: SIMD2<Double>, direction: SIMD2<Double>,
    majorRadius: Double, minorRadius: Double
) -> Curve2D?
```

- **Parameters:** `center` — center point; `direction` — unit direction of the major axis; `majorRadius`/`minorRadius` — semi-axes.
- **Returns:** `Curve2D` (ellipse), or `nil` if radii are non-positive.
- **OCCT:** `gce_MakeElips2d`.
- **Example:**
  ```swift
  if let e = Curve2D.ellipseFromCenterDir(
      center: .zero, direction: SIMD2(1, 0),
      majorRadius: 5, minorRadius: 3) {
      print(e.ellipseProperties.majorRadius)
  }
  ```

---

### `hyperbolaFromCenterDir(center:direction:majorRadius:minorRadius:)`

Creates a 2D hyperbola from center, direction, and semi-radii using `gce_MakeHypr2d`.

```swift
public static func hyperbolaFromCenterDir(
    center: SIMD2<Double>, direction: SIMD2<Double>,
    majorRadius: Double, minorRadius: Double
) -> Curve2D?
```

- **Parameters:** `center` — center; `direction` — unit direction of the real axis; `majorRadius`/`minorRadius` — real and imaginary semi-axes.
- **Returns:** `Curve2D` (hyperbola), or `nil` on failure.
- **OCCT:** `gce_MakeHypr2d`.
- **Example:**
  ```swift
  if let h = Curve2D.hyperbolaFromCenterDir(
      center: .zero, direction: SIMD2(1, 0),
      majorRadius: 4, minorRadius: 3) {
      print(h.hyperbolaProperties.eccentricity)
  }
  ```

---

### `parabolaFromCenterDir(center:direction:focal:)`

Creates a 2D parabola from center, axis direction, and focal distance using `gce_MakeParab2d`.

```swift
public static func parabolaFromCenterDir(
    center: SIMD2<Double>, direction: SIMD2<Double>,
    focal: Double
) -> Curve2D?
```

- **Parameters:** `center` — vertex of the parabola; `direction` — axis direction; `focal` — focal distance.
- **Returns:** `Curve2D` (parabola), or `nil` on failure.
- **OCCT:** `gce_MakeParab2d`.
- **Example:**
  ```swift
  if let p = Curve2D.parabolaFromCenterDir(
      center: .zero, direction: SIMD2(1, 0), focal: 2) {
      print(p.parabolaProperties.focal)  // 2.0
  }
  ```

---

### `serializeCurves(_:)`

Serializes an array of 2D curves to a string using `GeomTools_Curve2dSet`.

```swift
public static func serializeCurves(_ curves: [Curve2D]) -> String?
```

The resulting string can be stored to disk or passed across process boundaries, then deserialized with `deserializeCurves(_:)`.

- **Parameters:** `curves` — array of curves to serialize.
- **Returns:** Serialized string, or `nil` on failure.
- **OCCT:** `GeomTools_Curve2dSet::Write`.
- **Example:**
  ```swift
  if let c = Curve2D.circle(center: .zero, radius: 5),
     let data = Curve2D.serializeCurves([c]) {
      try? data.write(toFile: "/tmp/curves.dat", atomically: true, encoding: .utf8)
  }
  ```

---

### `deserializeCurves(_:)`

Deserializes an array of 2D curves from a string produced by `serializeCurves(_:)`.

```swift
public static func deserializeCurves(_ data: String) -> [Curve2D]?
```

- **Parameters:** `data` — serialized curve string.
- **Returns:** Array of restored `Curve2D` values, or `nil` if the string is invalid or empty.
- **OCCT:** `GeomTools_Curve2dSet::Read`.
- **Example:**
  ```swift
  if let data = try? String(contentsOfFile: "/tmp/curves.dat", encoding: .utf8),
     let curves = Curve2D.deserializeCurves(data) {
      print(curves.count)
  }
  ```

---

## FairCurve

Energy-minimising curves (`FairCurve_Batten`, `FairCurve_MinimalVariation`) that model the elastic behaviour of a physical spline.

---

### `FairCurveCode`

Enum indicating the convergence status of a fair-curve computation.

```swift
public enum FairCurveCode: Int32, Sendable {
    case ok               = 0
    case notConverged     = 1
    case infiniteSliding  = 2
    case nullHeight       = 3
}
```

---

### `fairCurveBatten(p1:p2:height:slope:angle1:angle2:constraintOrder1:constraintOrder2:freeSliding:)`

Creates a fair curve (batten) of minimal bending energy between two 2D points.

```swift
public static func fairCurveBatten(
    p1: SIMD2<Double>, p2: SIMD2<Double>,
    height: Double = 1.0, slope: Double = 0.0,
    angle1: Double = 0.0, angle2: Double = 0.0,
    constraintOrder1: Int = 1, constraintOrder2: Int = 1,
    freeSliding: Bool = true
) -> (curve: Curve2D, code: FairCurveCode)?
```

`constraintOrder` controls what is constrained at each endpoint: 0 = position only, 1 = position + tangent, 2 = position + tangent + curvature.

- **Parameters:** `p1`/`p2` — endpoints; `height` — cross-section height; `slope` — slope parameter; `angle1`/`angle2` — tangent angle constraints (radians); `constraintOrder1`/`constraintOrder2` — constraint orders; `freeSliding` — whether the batten can slide freely.
- **Returns:** `(curve, code)` tuple, or `nil` on internal failure. Check `code == .ok` before trusting the curve.
- **OCCT:** `FairCurve_Batten::Compute`.
- **Example:**
  ```swift
  if let result = Curve2D.fairCurveBatten(
      p1: .zero, p2: SIMD2(10, 0),
      height: 0.5, angle1: .pi / 6, angle2: -.pi / 6) {
      if result.code == .ok {
          print(result.curve.domain)
      }
  }
  ```
- **Note:** Returns `nil` (not `.notConverged`) only when the bridge itself fails; `.notConverged` is returned inside the tuple with a partially-computed curve.

---

### `fairCurveMinimalVariation(p1:p2:height:slope:angle1:angle2:constraintOrder1:constraintOrder2:freeSliding:physicalRatio:curvature1:curvature2:)`

Creates a fair curve with minimal curvature variation between two 2D points.

```swift
public static func fairCurveMinimalVariation(
    p1: SIMD2<Double>, p2: SIMD2<Double>,
    height: Double = 1.0, slope: Double = 0.0,
    angle1: Double = 0.0, angle2: Double = 0.0,
    constraintOrder1: Int = 1, constraintOrder2: Int = 1,
    freeSliding: Bool = true,
    physicalRatio: Double = 0.0,
    curvature1: Double = 0.0, curvature2: Double = 0.0
) -> (curve: Curve2D, code: FairCurveCode)?
```

`physicalRatio` blends between pure batten (0) and minimal-variation (1) behaviour. Curvature constraints are active only when `constraintOrder >= 2`.

- **Parameters:** `p1`/`p2` — endpoints; `height`/`slope` — physical parameters; `angle1`/`angle2` — tangent angles; `constraintOrder1`/`constraintOrder2` — constraint orders; `freeSliding`; `physicalRatio` — 0–1 blend; `curvature1`/`curvature2` — endpoint curvatures (used when order ≥ 2).
- **Returns:** `(curve, code)` tuple, or `nil` on internal failure.
- **OCCT:** `FairCurve_MinimalVariation::Compute`.
- **Example:**
  ```swift
  if let result = Curve2D.fairCurveMinimalVariation(
      p1: .zero, p2: SIMD2(10, 0),
      physicalRatio: 0.5) {
      if result.code == .ok {
          let pts = result.curve.evaluateGrid([0, 0.25, 0.5, 0.75, 1.0])
      }
  }
  ```

---

## Point2D Integration

Bridge between `Curve2D` and the `Point2D` type for point-based construction and projection.

---

### `pointAt(_:)`

Evaluates the curve at parameter `t`, returning a `Point2D`.

```swift
public func pointAt(_ t: Double) -> Point2D?
```

- **Parameters:** `t` — curve parameter.
- **Returns:** `Point2D` at parameter `t`, or `nil` on failure.
- **OCCT:** `Geom2d_Curve::Value` via `Point2D` bridge.
- **Example:**
  ```swift
  if let circle = Curve2D.circle(center: .zero, radius: 5),
     let pt = circle.pointAt(0) {
      print(pt)
  }
  ```

---

### `segment(from:to:)` _(Point2D overload)_

Creates a line segment between two `Point2D` instances.

```swift
public static func segment(from p1: Point2D, to p2: Point2D) -> Curve2D?
```

Distinct from `segment(from:to:)` taking `SIMD2<Double>` parameters.

- **Parameters:** `p1`/`p2` — `Point2D` endpoints.
- **Returns:** `Curve2D` (trimmed line segment), or `nil` on failure.
- **OCCT:** `GCE2d_MakeSegment`.
- **Example:**
  ```swift
  if let a = someEdge.startPoint2D,
     let b = someEdge.endPoint2D,
     let seg = Curve2D.segment(from: a, to: b) {
      print(seg.domain)
  }
  ```

---

### `project(_:)` _(Point2D overload)_

Projects a `Point2D` onto this curve.

```swift
public func project(_ point: Point2D) -> (parameter: Double, distance: Double)?
```

- **Parameters:** `point` — the `Point2D` to project.
- **Returns:** `(parameter, distance)` tuple, or `nil` on failure (negative distance sentinel).
- **OCCT:** `Geom2dAPI_ProjectPointOnCurve`.
- **Example:**
  ```swift
  if let circle = Curve2D.circle(center: .zero, radius: 5),
     let pt = circle.pointAt(.pi / 4),
     let proj = circle.project(pt) {
      print(proj.parameter, proj.distance)  // distance ≈ 0
  }
  ```
