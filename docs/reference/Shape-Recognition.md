---
title: Shape — Geometry Recognition & Polygon/Triangulation Data
parent: API Reference
---

# Shape — Geometry Recognition & Polygon/Triangulation Data

This page documents the geometry-utility and polygon/triangulation public API from `Sources/OCCTSwift/Shape.swift` (lines 11078–12192). It covers coordinate-system helpers, curve/surface construction utilities, 2D constraint solvers, shape modification tools, and the full polygon and triangulation layer. See the main [Shape](Shape.md) page for the core B-Rep API.

## Topics

- [Axis2Placement](#axis2placement) · [ShapeConstruct_Curve extensions](#shapeconstruct_curve-extensions) · [Bisector utilities](#bisector-utilities) · [GeomLib_Tool — Parameter Finding](#geomlib_tool--parameter-finding) · [GeomLib_IsPlanarSurface](#geomlib_isplanarsurface) · [GeomLib_CheckBSplineCurve / Check2dBSplineCurve](#geomlib_checkbsplinecurve--check2dbsplinecurve) · [GeomLib_Interpolate](#geomlib_interpolate) · [GccAna_Circ2d2TanRad](#gccana_circ2d2tanrad) · [GccAna_Circ2dTanCen](#gccana_circ2dtancen) · [GccAna_Lin2d2Tan](#gccana_lin2d2tan) · [Approx_SameParameter](#approx_sameparameter) · [ShapeUpgrade Curve Splitting](#shapeupgrade-curve-splitting) · [Shape Modifications](#shape-modifications) · [Surface Splitting](#surface-splitting) · [Curve/Surface Recognition](#curvesurface-recognition) · [Polygon2D](#polygon2d) · [Triangulation](#triangulation) · [Polygon3D](#polygon3d) · [PolygonOnTriangulation](#polygonontriangulation) · [Mesh Node Merging](#mesh-node-merging)

---

## Axis2Placement

A standalone Swift class wrapping `Geom_Axis2Placement` — a right-handed 3D coordinate system with an origin, a main (Z) direction, and an X direction. Used to define placement frames for geometry factories.

### `Axis2Placement.init(origin:normal:xDirection:)`

Creates a right-handed 3D axis placement.

```swift
public init(origin: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>)
```

- **Parameters:** `origin` — origin point; `normal` — main (Z) direction; `xDirection` — X direction (must not be parallel to `normal`).
- **OCCT:** `Geom_Axis2Placement(gp_Pnt, gp_Dir main, gp_Dir xDir)` via `OCCTAxis2PlacementCreate`.
- **Example:**
  ```swift
  let ax = Axis2Placement(origin: SIMD3(0, 0, 10),
                           normal: SIMD3(0, 0, 1),
                           xDirection: SIMD3(1, 0, 0))
  ```

---

### `location`

The origin of this placement.

```swift
public var location: SIMD3<Double> { get }
```

- **Returns:** The origin point.
- **OCCT:** `Geom_Axis2Placement::Location` via `OCCTAxis2PlacementLocation`.

---

### `mainDirection`

The main (Z) direction of this placement.

```swift
public var mainDirection: SIMD3<Double> { get }
```

- **Returns:** The main axis direction.
- **OCCT:** `Geom_Axis2Placement::Direction` via `OCCTAxis2PlacementDirection`.

---

### `xDirection`

The X direction of this placement.

```swift
public var xDirection: SIMD3<Double> { get }
```

- **Returns:** The X-axis direction.
- **OCCT:** `Geom_Axis2Placement::XDirection` via `OCCTAxis2PlacementXDirection`.

---

### `yDirection`

The Y direction of this placement (computed from main × X).

```swift
public var yDirection: SIMD3<Double> { get }
```

- **Returns:** The Y-axis direction.
- **OCCT:** `Geom_Axis2Placement::YDirection` via `OCCTAxis2PlacementYDirection`.

---

### `setDirection(_:)`

Sets the main (Z) direction in place.

```swift
public func setDirection(_ dir: SIMD3<Double>)
```

- **Parameters:** `dir` — new main direction.
- **OCCT:** `Geom_Axis2Placement::SetDirection` via `OCCTAxis2PlacementSetDirection`.

---

### `setXDirection(_:)`

Sets the X direction in place.

```swift
public func setXDirection(_ dir: SIMD3<Double>)
```

- **Parameters:** `dir` — new X direction (must not be parallel to the main direction).
- **OCCT:** `Geom_Axis2Placement::SetXDirection` via `OCCTAxis2PlacementSetXDirection`.

---

## ShapeConstruct_Curve extensions

Extensions on `Curve3D` and `Curve2D` that expose `ShapeConstruct_Curve` utilities for B-Spline conversion and endpoint adjustment.

### `Curve3D.convertSegmentToBSpline(first:last:precision:)`

Converts a segment of this 3D curve to a BSpline using `ShapeConstruct_Curve`.

```swift
public func convertSegmentToBSpline(first: Double, last: Double,
                                     precision: Double = 1e-6) -> Curve3D?
```

- **Parameters:** `first` — start parameter; `last` — end parameter; `precision` — geometric tolerance.
- **Returns:** New `Curve3D` as a BSpline, or `nil` on failure.
- **OCCT:** `ShapeConstruct_Curve::ConvertToBSpline` via `OCCTShapeConstructConvertToBSpline3D`.
- **Example:**
  ```swift
  if let bsp = curve.convertSegmentToBSpline(first: 0, last: 1) {
      print(bsp.degree)
  }
  ```

---

### `Curve3D.adjustEndpoints(start:end:)`

Adjusts the 3D curve endpoints to match given 3D points.

```swift
public func adjustEndpoints(start: SIMD3<Double>, end: SIMD3<Double>) -> Bool
```

- **Parameters:** `start` — desired start point; `end` — desired end point.
- **Returns:** `true` on success.
- **OCCT:** `ShapeConstruct_Curve::AdjustCurve` via `OCCTShapeConstructAdjustCurve3D`.

---

### `Curve2D.convertSegmentToBSpline(first:last:precision:)`

Converts a segment of this 2D curve to a BSpline using `ShapeConstruct_Curve`.

```swift
public func convertSegmentToBSpline(first: Double, last: Double,
                                     precision: Double = 1e-6) -> Curve2D?
```

- **Parameters:** `first` — start parameter; `last` — end parameter; `precision` — geometric tolerance.
- **Returns:** New `Curve2D` as a BSpline, or `nil` on failure.
- **OCCT:** `ShapeConstruct_Curve::ConvertToBSpline` via `OCCTShapeConstructConvertToBSpline2D`.

---

### `Curve2D.adjustEndpoints(start:end:)`

Adjusts the 2D curve endpoints to match given 2D points.

```swift
public func adjustEndpoints(start: (Double, Double), end: (Double, Double)) -> Bool
```

- **Parameters:** `start` — desired start point as `(x, y)`; `end` — desired end point as `(x, y)`.
- **Returns:** `true` on success.
- **OCCT:** `ShapeConstruct_Curve::AdjustCurve2d` via `OCCTShapeConstructAdjustCurve2D`.

---

## Bisector utilities

Free-function bisector utilities and their associated value types.

### `BisectorPoint`

Point on a bisector curve with parameter and distance information.

```swift
public struct BisectorPoint {
    public let paramOnC1: Double
    public let paramOnC2: Double
    public let paramOnBis: Double
    public let distance: Double
    public let x: Double
    public let y: Double
    public let isInfinite: Bool
}
```

---

### `BisectorIntersection`

Result of a bisector-vs-bisector intersection computation.

```swift
public struct BisectorIntersection {
    public let x: Double
    public let y: Double
    public let paramOnFirst: Double
    public let paramOnSecond: Double
}
```

---

### `bisectorIntersections(a:b:c:d:)`

Computes intersections between the perpendicular bisectors of two point pairs.

```swift
public func bisectorIntersections(
    a: (Double, Double), b: (Double, Double),
    c: (Double, Double), d: (Double, Double)
) -> [BisectorIntersection]
```

The bisector of `(a, b)` is intersected with the bisector of `(c, d)`. The result is the circumcenter when the two pairs form a triangle.

- **Parameters:** `a`, `b` — first point pair; `c`, `d` — second point pair, all as `(x, y)`.
- **Returns:** Array of intersection points (zero, one, or two).
- **OCCT:** `Bisector_BisecCC` / `Bisector_Inter` via `OCCTBisectorInterPointPoint`.
- **Example:**
  ```swift
  let hits = bisectorIntersections(a: (0, 0), b: (4, 0),
                                    c: (4, 0), d: (2, 3))
  // hits[0] is the circumcenter of the triangle
  ```

---

## GeomLib_Tool — Parameter Finding

Extensions on `Curve3D`, `Surface`, and `Curve2D` for locating parameter values corresponding to 3D/2D points.

### `Curve3D.parameterOf(point:maxDistance:)`

Finds the parameter of a 3D point on this curve.

```swift
public func parameterOf(point: SIMD3<Double>, maxDistance: Double = 1.0) -> Double?
```

- **Parameters:** `point` — 3D point to locate; `maxDistance` — maximum allowed distance from the curve.
- **Returns:** Parameter value, or `nil` if the point lies farther than `maxDistance` from the curve.
- **OCCT:** `GeomLib_Tool::Parameter` via `OCCTGeomLibToolParameter3D`.
- **Example:**
  ```swift
  if let t = curve.parameterOf(point: SIMD3(1, 2, 3), maxDistance: 0.01) {
      let pt = curve.point(at: t)
  }
  ```

---

### `Surface.parametersOf(point:maxDistance:)`

Finds the UV parameters of a 3D point on this surface.

```swift
public func parametersOf(point: SIMD3<Double>, maxDistance: Double = 1.0) -> (u: Double, v: Double)?
```

- **Parameters:** `point` — 3D point to locate; `maxDistance` — maximum allowed distance from the surface.
- **Returns:** `(u, v)` parameter tuple, or `nil` if the point lies farther than `maxDistance`.
- **OCCT:** `GeomLib_Tool::Parameters` via `OCCTGeomLibToolParametersSurface`.
- **Example:**
  ```swift
  let s = Surface.sphere(center: .zero, radius: 5)!
  if let uv = s.parametersOf(point: SIMD3(5, 0, 0), maxDistance: 0.1) {
      print(uv.u, uv.v)
  }
  ```

---

### `Curve2D.parameterOf(point:maxDistance:)`

Finds the parameter of a 2D point on this curve.

```swift
public func parameterOf(point: SIMD2<Double>, maxDistance: Double = 1.0) -> Double?
```

- **Parameters:** `point` — 2D point to locate; `maxDistance` — maximum allowed distance from the curve.
- **Returns:** Parameter value, or `nil` if the point is too far from the curve.
- **OCCT:** `GeomLib_Tool::Parameter` via `OCCTGeomLibToolParameter2D`.

---

## GeomLib_IsPlanarSurface

Extensions on `Surface` for planarity testing.

### `Surface.isPlanar(tolerance:)`

Checks if this surface is planar within a given tolerance.

```swift
public func isPlanar(tolerance: Double = 1e-7) -> Bool
```

- **Parameters:** `tolerance` — planarity tolerance.
- **Returns:** `true` if the surface is planar within `tolerance`.
- **OCCT:** `GeomLib_IsPlanarSurface::IsPlanar` via `OCCTGeomLibIsPlanarSurface`.
- **Example:**
  ```swift
  let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
  print(plane.isPlanar())  // true
  ```

---

### `Surface.planarPlane(tolerance:)`

Returns the underlying plane parameters if this surface is planar.

```swift
public func planarPlane(tolerance: Double = 1e-7) -> (origin: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>)?
```

- **Parameters:** `tolerance` — planarity tolerance.
- **Returns:** Tuple of `(origin, normal, xDirection)` if planar, `nil` otherwise.
- **OCCT:** `GeomLib_IsPlanarSurface::Plane` via `OCCTGeomLibPlanarSurfacePlane`.
- **Example:**
  ```swift
  if let plane = surface.planarPlane() {
      print(plane.normal)
  }
  ```

---

## GeomLib_CheckBSplineCurve / Check2dBSplineCurve

Extensions on `Curve3D` and `Curve2D` for detecting and fixing reversed end tangents on BSpline curves.

### `Curve3D.checkBSplineTangents(tolerance:angularTolerance:)`

Checks if this BSpline curve has reversed end tangents.

```swift
public func checkBSplineTangents(tolerance: Double = 0.01,
                                  angularTolerance: Double = 0.1) -> (fixFirst: Bool, fixLast: Bool)?
```

- **Parameters:** `tolerance` — positional tolerance; `angularTolerance` — angular tolerance in radians.
- **Returns:** `(fixFirst, fixLast)` indicating which ends need fixing, or `nil` if not a BSpline or check failed.
- **OCCT:** `GeomLib_CheckBSplineCurve` via `OCCTGeomLibCheckBSpline3D`.

---

### `Curve3D.fixBSplineTangents(fixFirst:fixLast:tolerance:angularTolerance:)`

Fixes reversed end tangents on a BSpline curve.

```swift
public func fixBSplineTangents(fixFirst: Bool, fixLast: Bool,
                                tolerance: Double = 0.01,
                                angularTolerance: Double = 0.1) -> Curve3D?
```

- **Parameters:** `fixFirst` — fix the start tangent; `fixLast` — fix the end tangent; `tolerance` — positional tolerance; `angularTolerance` — angular tolerance.
- **Returns:** New `Curve3D` with corrected tangents, or `nil` on failure.
- **OCCT:** `GeomLib_CheckBSplineCurve::FixTangent` via `OCCTGeomLibFixBSpline3D`.
- **Example:**
  ```swift
  if let flags = curve.checkBSplineTangents(),
     (flags.fixFirst || flags.fixLast) {
      let fixed = curve.fixBSplineTangents(fixFirst: flags.fixFirst, fixLast: flags.fixLast)
  }
  ```

---

### `Curve2D.checkBSplineTangents(tolerance:angularTolerance:)`

Checks if this 2D BSpline curve has reversed end tangents.

```swift
public func checkBSplineTangents(tolerance: Double = 0.01,
                                  angularTolerance: Double = 0.1) -> (fixFirst: Bool, fixLast: Bool)?
```

- **Parameters:** `tolerance` — positional tolerance; `angularTolerance` — angular tolerance.
- **Returns:** `(fixFirst, fixLast)` flags, or `nil` if not a BSpline or check failed.
- **OCCT:** `GeomLib_Check2dBSplineCurve` via `OCCTGeomLibCheckBSpline2D`.

---

### `Curve2D.fixBSplineTangents(fixFirst:fixLast:tolerance:angularTolerance:)`

Fixes reversed end tangents on a 2D BSpline curve.

```swift
public func fixBSplineTangents(fixFirst: Bool, fixLast: Bool,
                                tolerance: Double = 0.01,
                                angularTolerance: Double = 0.1) -> Curve2D?
```

- **Parameters:** `fixFirst` — fix the start tangent; `fixLast` — fix the end tangent; `tolerance` — positional tolerance; `angularTolerance` — angular tolerance.
- **Returns:** Fixed `Curve2D`, or `nil` on failure.
- **OCCT:** `GeomLib_Check2dBSplineCurve::FixTangent` via `OCCTGeomLibFixBSpline2D`.

---

## GeomLib_Interpolate

### `Curve3D.polynomialInterpolation(degree:points:parameters:)`

Creates a BSpline curve by polynomial interpolation of 3D points at given parameters.

```swift
public static func polynomialInterpolation(degree: Int, points: [SIMD3<Double>],
                                            parameters: [Double]) -> Curve3D?
```

`points` and `parameters` must have equal counts (≥ 2). The parameter values define how the polynomial fits progress along the curve.

- **Parameters:** `degree` — polynomial degree; `points` — interpolation points; `parameters` — parameter values corresponding to each point.
- **Returns:** Interpolated BSpline `Curve3D`, or `nil` if counts mismatch or interpolation fails.
- **OCCT:** `GeomLib_Interpolate` via `OCCTGeomLibInterpolate`.
- **Example:**
  ```swift
  let pts: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(5,3,0), SIMD3(10,0,0)]
  let params: [Double] = [0, 0.5, 1]
  if let c = Curve3D.polynomialInterpolation(degree: 2, points: pts, parameters: params) {
      let pt = c.point(at: 0.25)
  }
  ```

---

## GccAna_Circ2d2TanRad

Free functions and supporting types for computing 2D circles tangent to two lines or through two points with a given radius.

### `Circle2DSolution`

A 2D circle solution returned by circle construction functions.

```swift
public struct Circle2DSolution: Sendable {
    public let center: SIMD2<Double>
    public let radius: Double
}
```

---

### `circlesTangentToLines(_:_:_:_:radius:tolerance:)`

Finds circles tangent to two 2D lines with a given radius.

```swift
public func circlesTangentToLines(_ l1Origin: SIMD2<Double>, _ l1Direction: SIMD2<Double>,
                                   _ l2Origin: SIMD2<Double>, _ l2Direction: SIMD2<Double>,
                                   radius: Double, tolerance: Double = 1e-6) -> [Circle2DSolution]
```

- **Parameters:** `l1Origin`, `l1Direction` — first line (point + direction); `l2Origin`, `l2Direction` — second line; `radius` — required circle radius; `tolerance` — geometric tolerance.
- **Returns:** Array of up to four `Circle2DSolution` values (may be empty if no solution exists).
- **OCCT:** `GccAna_Circ2d2TanRad` (Lin+Lin variant) via `OCCTGccAnaCirc2d2TanRadLineLin`.
- **Example:**
  ```swift
  let circles = circlesTangentToLines(SIMD2(0,0), SIMD2(1,0),
                                       SIMD2(0,0), SIMD2(0,1),
                                       radius: 3)
  ```

---

### `circlesThroughPointsWithRadius(_:_:radius:tolerance:)`

Finds circles passing through two 2D points with a given radius.

```swift
public func circlesThroughPointsWithRadius(_ p1: SIMD2<Double>, _ p2: SIMD2<Double>,
                                            radius: Double,
                                            tolerance: Double = 1e-6) -> [Circle2DSolution]
```

- **Parameters:** `p1`, `p2` — two points to pass through; `radius` — required circle radius; `tolerance` — geometric tolerance.
- **Returns:** Array of up to two `Circle2DSolution` values.
- **OCCT:** `GccAna_Circ2d2TanRad` (Pnt+Pnt variant) via `OCCTGccAnaCirc2d2TanRadPntPnt`.
- **Example:**
  ```swift
  let circles = circlesThroughPointsWithRadius(SIMD2(-3, 0), SIMD2(3, 0), radius: 5)
  ```

---

## GccAna_Circ2dTanCen

Free functions for computing 2D circles with a given centre.

### `circleThroughPointCentered(point:center:)`

Finds the circle centered at a given point that passes through another point.

```swift
public func circleThroughPointCentered(point: SIMD2<Double>,
                                        center: SIMD2<Double>) -> Circle2DSolution?
```

- **Parameters:** `point` — a point on the circle; `center` — the required circle centre.
- **Returns:** A `Circle2DSolution`, or `nil` if no solution exists.
- **OCCT:** `GccAna_Circ2dTanCen` (Pnt+Pnt variant) via `OCCTGccAnaCirc2dTanCenPntPnt`.
- **Example:**
  ```swift
  if let c = circleThroughPointCentered(point: SIMD2(5, 0), center: .zero) {
      print(c.radius)  // 5.0
  }
  ```

---

### `circleTangentToLineCentered(lineOrigin:lineDirection:center:)`

Finds the circle centred at a given point that is tangent to a line.

```swift
public func circleTangentToLineCentered(lineOrigin: SIMD2<Double>,
                                         lineDirection: SIMD2<Double>,
                                         center: SIMD2<Double>) -> Circle2DSolution?
```

- **Parameters:** `lineOrigin` — a point on the line; `lineDirection` — line direction; `center` — required circle centre.
- **Returns:** A `Circle2DSolution`, or `nil` if no solution exists.
- **OCCT:** `GccAna_Circ2dTanCen` (Lin+Pnt variant) via `OCCTGccAnaCirc2dTanCenLinPnt`.
- **Example:**
  ```swift
  if let c = circleTangentToLineCentered(lineOrigin: SIMD2(0, 3),
                                          lineDirection: SIMD2(1, 0),
                                          center: SIMD2(2, 0)) {
      print(c.radius)  // 3.0
  }
  ```

---

## GccAna_Lin2d2Tan

Free functions and supporting types for 2D line construction.

### `Line2DSolution`

A 2D line solution returned by line construction functions.

```swift
public struct Line2DSolution: Sendable {
    public let origin: SIMD2<Double>
    public let direction: SIMD2<Double>
}
```

---

### `lineThroughPoints(_:_:tolerance:)`

Finds the line passing through two 2D points.

```swift
public func lineThroughPoints(_ p1: SIMD2<Double>, _ p2: SIMD2<Double>,
                               tolerance: Double = 1e-6) -> Line2DSolution?
```

- **Parameters:** `p1`, `p2` — two points; `tolerance` — geometric tolerance.
- **Returns:** A `Line2DSolution`, or `nil` if the points coincide within tolerance.
- **OCCT:** `GccAna_Lin2d2Tan` (Pnt+Pnt variant) via `OCCTGccAnaLin2d2TanPntPnt`.
- **Example:**
  ```swift
  if let line = lineThroughPoints(SIMD2(0, 0), SIMD2(1, 1)) {
      print(line.direction)
  }
  ```

---

### `linesTangentToCircleThroughPoint(circleCenter:circleRadius:point:tolerance:)`

Finds lines tangent to a circle and passing through a given point.

```swift
public func linesTangentToCircleThroughPoint(circleCenter: SIMD2<Double>,
                                              circleRadius: Double,
                                              point: SIMD2<Double>,
                                              tolerance: Double = 1e-6) -> [Line2DSolution]
```

- **Parameters:** `circleCenter`, `circleRadius` — the circle; `point` — point the line must pass through; `tolerance` — geometric tolerance.
- **Returns:** Array of up to two `Line2DSolution` values (one if the point lies on the circle).
- **OCCT:** `GccAna_Lin2d2Tan` (Circ+Pnt variant) via `OCCTGccAnaLin2d2TanCircPnt`.
- **Example:**
  ```swift
  let tangents = linesTangentToCircleThroughPoint(circleCenter: .zero,
                                                   circleRadius: 3,
                                                   point: SIMD2(5, 0))
  ```

---

## Approx_SameParameter

### `SameParameterResult`

Result of a same-parameterisation check between a 3D curve and a 2D curve on a surface.

```swift
public struct SameParameterResult: Sendable {
    public let isSameParameter: Bool
    public let toleranceReached: Double
}
```

`toleranceReached` is the maximum distance between the 3D curve and the surface-evaluated 2D curve.

---

### `Curve3D.checkSameParameter(curve2D:surface:tolerance:)`

Checks if a 2D curve on a surface has the same parameterisation as this 3D curve.

```swift
public func checkSameParameter(curve2D: Curve2D, surface: Surface,
                                tolerance: Double = 1e-6) -> SameParameterResult?
```

- **Parameters:** `curve2D` — the 2D curve; `surface` — the surface; `tolerance` — parameterisation tolerance.
- **Returns:** `SameParameterResult`, or `nil` if the check fails.
- **OCCT:** `Approx_SameParameter` via `OCCTApproxSameParameter`.
- **Example:**
  ```swift
  if let r = curve3d.checkSameParameter(curve2D: pcurve, surface: face.surface!) {
      print(r.isSameParameter, r.toleranceReached)
  }
  ```

---

## ShapeUpgrade Curve Splitting

Extensions on `Curve3D` and `Curve2D` for splitting by continuity and converting to Bezier or arc/segment decompositions.

### `Curve3D.splitByContinuity(criterion:tolerance:)`

Splits this 3D curve at continuity breaks.

```swift
public func splitByContinuity(criterion: Int = 2, tolerance: Double = 1e-6) -> [Curve3D]
```

- **Parameters:** `criterion` — continuity criterion: 0=C0, 1=C1, 2=C2, 3=C3, 4=CN; `tolerance` — geometric tolerance.
- **Returns:** Array of `Curve3D` segments; may be a single-element array if no breaks are found.
- **OCCT:** `ShapeUpgrade_SplitCurve3dContinuity` via `OCCTSplitCurve3dContinuity`.
- **Example:**
  ```swift
  let segments = curve.splitByContinuity(criterion: 1)
  ```

---

### `Curve2D.splitByContinuity(criterion:tolerance:)`

Splits this 2D curve at continuity breaks.

```swift
public func splitByContinuity(criterion: Int = 2, tolerance: Double = 1e-6) -> [Curve2D]
```

- **Parameters:** `criterion` — continuity criterion: 0=C0, 1=C1, 2=C2, 3=C3, 4=CN; `tolerance` — geometric tolerance.
- **Returns:** Array of `Curve2D` segments.
- **OCCT:** `ShapeUpgrade_SplitCurve2dContinuity` via `OCCTSplitCurve2dContinuity`.

---

### `Curve2D.convertToBezierSegments()`

Converts this 2D curve to Bezier segments via `ShapeUpgrade`.

```swift
public func convertToBezierSegments() -> [Curve2D]
```

- **Returns:** Array of `Curve2D` Bezier segments. Returns an empty array on failure.
- **OCCT:** `ShapeUpgrade_ConvertCurve2dToBezier` via `OCCTConvertCurve2dToBezier`.

---

### `Curve2D.approxArcsAndSegments(tolerance:angleTolerance:)`

Approximates this 2D curve as a sequence of arcs and line segments.

```swift
public func approxArcsAndSegments(tolerance: Double, angleTolerance: Double) -> [Curve2D]
```

- **Parameters:** `tolerance` — positional approximation tolerance; `angleTolerance` — angular tolerance in radians.
- **Returns:** Array of `Curve2D` arcs and segments. Returns an empty array on failure.
- **OCCT:** `Geom2dConvert_ApproxArcsSegments` via `OCCTGeom2dConvertApproxArcsSegments`.

---

## Shape Modifications

`Shape` extension methods wrapping `BRepTools` modification helpers.

### `Shape.trsfModification(_:a11:a12:a13:a14:a21:a22:a23:a24:a31:a32:a33:a34:)`

Applies a 3×4 affine transformation matrix to a shape via `BRepTools_TrsfModification`.

```swift
public static func trsfModification(_ shape: Shape,
                                      a11: Double, a12: Double, a13: Double, a14: Double,
                                      a21: Double, a22: Double, a23: Double, a24: Double,
                                      a31: Double, a32: Double, a33: Double, a34: Double) -> Shape?
```

The matrix is specified row-major. Supports uniform scaling and rotation but not non-uniform scaling; use `gtrsfModification` for general affine transforms.

- **Parameters:** `shape` — input shape; `a11`…`a34` — row-major 3×4 transformation matrix coefficients.
- **Returns:** Transformed shape, or `nil` on failure.
- **OCCT:** `BRepTools_TrsfModification` via `OCCTShapeTrsfModification`.
- **Example:**
  ```swift
  // Translate by (10, 0, 0)
  if let moved = Shape.trsfModification(box,
                                         a11: 1, a12: 0, a13: 0, a14: 10,
                                         a21: 0, a22: 1, a23: 0, a24: 0,
                                         a31: 0, a32: 0, a33: 1, a34: 0) {
      // use moved
  }
  ```

---

### `Shape.gtrsfModification(_:a11:a12:a13:a14:a21:a22:a23:a24:a31:a32:a33:a34:)`

Applies a general (non-uniform) 3×4 transformation matrix via `BRepTools_GTrsfModification`.

```swift
public static func gtrsfModification(_ shape: Shape,
                                       a11: Double, a12: Double, a13: Double, a14: Double,
                                       a21: Double, a22: Double, a23: Double, a24: Double,
                                       a31: Double, a32: Double, a33: Double, a34: Double) -> Shape?
```

Supports non-uniform scaling. Convert the shape to NURBS first for non-affine transforms to ensure geometry validity.

- **Parameters:** `shape` — input shape; `a11`…`a34` — row-major 3×4 matrix.
- **Returns:** Transformed shape, or `nil` on failure.
- **OCCT:** `BRepTools_GTrsfModification` via `OCCTShapeGTrsfModification`.

---

### `Shape.deepCopy(_:copyGeometry:copyMesh:)`

Creates a deep copy of a shape via `BRepTools_CopyModification`.

```swift
public static func deepCopy(_ shape: Shape,
                              copyGeometry: Bool = true,
                              copyMesh: Bool = true) -> Shape?
```

- **Parameters:** `shape` — shape to copy; `copyGeometry` — whether to copy underlying geometry; `copyMesh` — whether to copy cached triangulations.
- **Returns:** Independent deep copy, or `nil` on failure.
- **OCCT:** `BRepTools_CopyModification` via `OCCTShapeCopyModification`.
- **Example:**
  ```swift
  if let copy = Shape.deepCopy(original) {
      // Modifications to copy do not affect original
  }
  ```

---

### `Shape.bsplineRestrictionAdvanced(_:approxSurface:approxCurve3d:approxCurve2d:tol3d:tol2d:continuity3d:continuity2d:maxDegree:maxSegments:priorityDegree:convertRational:)`

Restricts BSpline degree and segment count in a shape with fine-grained control.

```swift
public static func bsplineRestrictionAdvanced(_ shape: Shape,
                                                approxSurface: Bool = true,
                                                approxCurve3d: Bool = true,
                                                approxCurve2d: Bool = true,
                                                tol3d: Double = 0.01,
                                                tol2d: Double = 0.01,
                                                continuity3d: Int = 2,
                                                continuity2d: Int = 2,
                                                maxDegree: Int = 5,
                                                maxSegments: Int = 20,
                                                priorityDegree: Bool = true,
                                                convertRational: Bool = false) -> Shape?
```

- **Parameters:** `approxSurface`/`approxCurve3d`/`approxCurve2d` — which geometry types to process; `tol3d`/`tol2d` — tolerances; `continuity3d`/`continuity2d` — required continuity (0=C0…6=CN); `maxDegree` — maximum polynomial degree; `maxSegments` — maximum segment count; `priorityDegree` — `true` = reduce degree first, `false` = reduce segments first; `convertRational` — convert rational BSplines to non-rational.
- **Returns:** Restricted shape, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_ConvertSurfaceToBSplineSurface` / `ShapeUpgrade_BSplineRestriction` via `OCCTShapeBSplineRestrictionAdvanced`.

---

### `Shape.convertToBSplineAdvanced(_:extrusionMode:revolutionMode:offsetMode:planeMode:)`

Converts surfaces in a shape to BSpline with per-type control.

```swift
public static func convertToBSplineAdvanced(_ shape: Shape,
                                              extrusionMode: Bool = true,
                                              revolutionMode: Bool = true,
                                              offsetMode: Bool = true,
                                              planeMode: Bool = false) -> Shape?
```

- **Parameters:** `extrusionMode` — convert extrusion surfaces; `revolutionMode` — convert revolution surfaces; `offsetMode` — convert offset surfaces; `planeMode` — convert planes.
- **Returns:** Shape with BSpline surfaces, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_ConvertSurfaceToBSplineSurface` via `OCCTShapeConvertToBSplineAdvanced`.

---

## Surface Splitting

`Surface` extension for splitting surfaces by continuity, angle, or area.

### `Surface.SplitResult`

Result of a surface splitting operation.

```swift
public struct SplitResult: Sendable {
    public let uSplitCount: Int
    public let vSplitCount: Int
}
```

---

### `Surface.splitSurfaceByContinuity(criterion:tolerance:)`

Splits this surface at continuity breaks.

```swift
public func splitSurfaceByContinuity(criterion: Int, tolerance: Double) -> SplitResult?
```

- **Parameters:** `criterion` — continuity criterion: 0=C0, 1=G1, 2=C1, 3=G2, 4=C2, 5=C3, 6=CN; `tolerance` — geometric tolerance.
- **Returns:** `SplitResult` with U and V split counts, or `nil` if no splits are found.
- **OCCT:** `ShapeUpgrade_SplitSurface` / continuity variant via `OCCTSplitSurfaceContinuity`.

---

### `Surface.splitByAngle(_:)`

Splits this surface where the normal varies by more than a maximum angle.

```swift
public func splitByAngle(_ maxAngle: Double) -> SplitResult?
```

- **Parameters:** `maxAngle` — maximum allowed normal deviation in radians.
- **Returns:** `SplitResult`, or `nil` if no splits are needed.
- **OCCT:** `ShapeUpgrade_SplitSurfaceAngle` via `OCCTSplitSurfaceAngle`.

---

### `Surface.splitByArea(parts:intoSquares:)`

Splits this surface into approximately equal-area parts.

```swift
public func splitByArea(parts: Int, intoSquares: Bool = false) -> SplitResult?
```

- **Parameters:** `parts` — desired number of parts; `intoSquares` — if `true`, target square patches.
- **Returns:** `SplitResult`, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_SplitSurfaceArea` via `OCCTSplitSurfaceArea`.

---

## Curve/Surface Recognition

Types and extensions for recognising and converting geometry to analytical (canonical) forms.

### `CurveToAnalyticalResult`

Result of converting a 3D curve to its analytical form.

```swift
public struct CurveToAnalyticalResult: Sendable {
    public let curve: Curve3D
    public let newFirst: Double
    public let newLast: Double
    public let gap: Double
}
```

`gap` is the maximum deviation between the original and the recognized analytical curve.

---

### `Curve3D.toAnalytical(tolerance:first:last:)`

Attempts to convert this curve to an analytical form (line, circle, ellipse, etc.).

```swift
public func toAnalytical(tolerance: Double, first: Double, last: Double) -> CurveToAnalyticalResult?
```

- **Parameters:** `tolerance` — recognition tolerance; `first`, `last` — parameter range to examine.
- **Returns:** `CurveToAnalyticalResult` with the simplified curve and gap, or `nil` if no analytical form is recognised.
- **OCCT:** `GeomConvert_CurveToAnaCurve` via `OCCTGeomConvertCurveToAnalytical`.
- **Example:**
  ```swift
  if let r = bsplineCurve.toAnalytical(tolerance: 1e-4, first: 0, last: 1) {
      print(r.curve.curveKind, r.gap)
  }
  ```

---

### `Curve3D.arePointsLinear(_:tolerance:)`

Checks whether a set of 3D points are collinear within a tolerance.

```swift
public static func arePointsLinear(_ points: [SIMD3<Double>],
                                    tolerance: Double) -> (isLinear: Bool, deviation: Double)
```

- **Parameters:** `points` — array of 3D points; `tolerance` — collinearity tolerance.
- **Returns:** `(isLinear, deviation)` — `isLinear` indicates collinearity; `deviation` is the maximum perpendicular distance from the best-fit line.
- **OCCT:** `GeomConvert_ConvType::IsLinear` via `OCCTGeomConvertIsLinear`.
- **Example:**
  ```swift
  let pts: [SIMD3<Double>] = [.zero, SIMD3(1,0,0), SIMD3(2,0,0)]
  let (linear, dev) = Curve3D.arePointsLinear(pts, tolerance: 1e-6)
  // linear == true, dev ≈ 0
  ```

---

### `SurfaceToAnalyticalResult`

Result of converting a surface to its analytical form.

```swift
public struct SurfaceToAnalyticalResult: Sendable {
    public let surface: Surface
    public let gap: Double
}
```

---

### `Surface.toAnalyticalWithGap(tolerance:)`

Attempts to convert this surface to an analytical form.

```swift
public func toAnalyticalWithGap(tolerance: Double) -> SurfaceToAnalyticalResult?
```

- **Parameters:** `tolerance` — recognition tolerance.
- **Returns:** `SurfaceToAnalyticalResult` with the simplified surface and deviation, or `nil` if no analytical form is recognised.
- **OCCT:** `GeomConvert_SurfToAnaSurf` via `OCCTGeomConvertSurfToAnalytical`.
- **Example:**
  ```swift
  if let r = bsplineSurface.toAnalyticalWithGap(tolerance: 1e-5) {
      print(r.surface.surfaceKind, r.gap)
  }
  ```

---

### `Surface.toAnalyticalWithGap(tolerance:uMin:uMax:vMin:vMax:)`

Attempts to convert this surface to an analytical form within UV bounds.

```swift
public func toAnalyticalWithGap(tolerance: Double,
                                  uMin: Double, uMax: Double,
                                  vMin: Double, vMax: Double) -> SurfaceToAnalyticalResult?
```

- **Parameters:** `tolerance` — recognition tolerance; `uMin`, `uMax`, `vMin`, `vMax` — UV parameter bounds to consider.
- **Returns:** `SurfaceToAnalyticalResult`, or `nil` on failure.
- **OCCT:** `GeomConvert_SurfToAnaSurf` (bounded variant) via `OCCTGeomConvertSurfToAnalyticalBounded`.

---

### `Surface.isCanonical`

Whether this surface is already in a canonical (analytical) form.

```swift
public var isCanonical: Bool { get }
```

- **Returns:** `true` if the surface is a plane, sphere, cylinder, cone, or torus rather than a BSpline.
- **OCCT:** `GeomConvert_ConvType::IsCanonical` via `OCCTGeomConvertIsCanonical`.

---

## Polygon2D

`Polygon2D` is a standalone Swift class wrapping `Poly_Polygon2D` — a sequence of 2D points used to represent a parametric-space polygon on a face.

### `Polygon2D.create(points:)`

Creates a 2D polygon from an array of 2D points.

```swift
public static func create(points: [SIMD2<Double>]) -> Polygon2D?
```

- **Parameters:** `points` — ordered sequence of 2D points.
- **Returns:** `Polygon2D`, or `nil` on failure.
- **OCCT:** `Poly_Polygon2D` via `OCCTPolyPolygon2DCreate`.
- **Example:**
  ```swift
  if let poly = Polygon2D.create(points: [SIMD2(0,0), SIMD2(1,0), SIMD2(0.5,1)]) {
      print(poly.nodeCount)  // 3
  }
  ```

---

### `Polygon2D.nodeCount`

The number of nodes in this polygon.

```swift
public var nodeCount: Int { get }
```

- **OCCT:** `Poly_Polygon2D::NbNodes` via `OCCTPolyPolygon2DNbNodes`.

---

### `Polygon2D.node(at:)`

Returns the 2D point at a given 0-based index.

```swift
public func node(at index: Int) -> SIMD2<Double>?
```

- **Parameters:** `index` — 0-based node index.
- **Returns:** `SIMD2<Double>` position, or `nil` if the index is out of range.
- **OCCT:** `Poly_Polygon2D::Nodes` via `OCCTPolyPolygon2DNode`.

---

### `Polygon2D.nodes()`

Returns all nodes.

```swift
public func nodes() -> [SIMD2<Double>]
```

- **Returns:** Array of all 2D node positions in sequence order.

---

### `Polygon2D.deflection`

The deflection value associated with this polygon.

```swift
public var deflection: Double { get set }
```

- **OCCT:** `Poly_Polygon2D::Deflection` / `SetDeflection` via `OCCTPolyPolygon2DDeflection` / `OCCTPolyPolygon2DSetDeflection`.

---

### `Polygon2D.copy()`

Creates a deep copy of this polygon.

```swift
public func copy() -> Polygon2D?
```

- **Returns:** Independent copy, or `nil` on failure.
- **OCCT:** `Poly_Polygon2D::Copy` via `OCCTPolyPolygon2DCopy`.

---

## Triangulation

`Triangulation` wraps `Poly_Triangulation` — a 3D mesh defined by node positions and triangle vertex indices. Used as input to `TopologyGraph.createTriangulationRep(_:)` for populating the cached mesh tier of a graph. Triangle indices are 0-based on the Swift boundary; the bridge converts to OCCT's 1-based representation internally.

### `Triangulation.create(nodes:triangles:)`

Creates a triangulation from node positions and triangle vertex indices.

```swift
public static func create(nodes: [SIMD3<Double>], triangles: [Int]) -> Triangulation?
```

- **Parameters:** `nodes` — 3D node positions; `triangles` — triangle vertex indices, 0-based, three per triangle (`triangles.count` must be a multiple of 3).
- **Returns:** `Triangulation`, or `nil` if inputs are empty, `triangles.count` is not a multiple of 3, or any index is out of range.
- **OCCT:** `Poly_Triangulation(nbNodes, nbTriangles)` via `OCCTPolyTriangulationCreate`.
- **Example:**
  ```swift
  let nodes: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(1,0,0), SIMD3(0,1,0)]
  if let tri = Triangulation.create(nodes: nodes, triangles: [0, 1, 2]) {
      print(tri.triangleCount)  // 1
  }
  ```

---

### `Triangulation.nodeCount`

The number of nodes.

```swift
public var nodeCount: Int { get }
```

- **OCCT:** `Poly_Triangulation::NbNodes` via `OCCTPolyTriangulationNbNodes`.

---

### `Triangulation.triangleCount`

The number of triangles.

```swift
public var triangleCount: Int { get }
```

- **OCCT:** `Poly_Triangulation::NbTriangles` via `OCCTPolyTriangulationNbTriangles`.

---

### `Triangulation.node(at:)`

Returns the 3D position of a node at a given 0-based index.

```swift
public func node(at index: Int) -> SIMD3<Double>?
```

- **Parameters:** `index` — 0-based node index.
- **Returns:** Node position, or `nil` if out of range.
- **OCCT:** `Poly_Triangulation::Node` via `OCCTPolyTriangulationNode`.

---

### `Triangulation.triangle(at:)`

Returns the three 0-based vertex indices for a triangle.

```swift
public func triangle(at index: Int) -> (Int, Int, Int)?
```

- **Parameters:** `index` — 0-based triangle index.
- **Returns:** Tuple of three 0-based node indices, or `nil` if out of range.
- **OCCT:** `Poly_Triangulation::Triangle` via `OCCTPolyTriangulationTriangle`.
- **Example:**
  ```swift
  if let (n0, n1, n2) = tri.triangle(at: 0) {
      let p0 = tri.node(at: n0)
  }
  ```

---

### `Triangulation.deflection`

The deflection value of this triangulation.

```swift
public var deflection: Double { get set }
```

- **OCCT:** `Poly_Triangulation::Deflection` / `SetDeflection` via `OCCTPolyTriangulationDeflection` / `OCCTPolyTriangulationSetDeflection`.

---

## Polygon3D

`Polygon3D` wraps `Poly_Polygon3D` — a sequence of 3D points with optional curve parameters, used to represent an edge approximation in 3D space.

### `Polygon3D.create(points:)`

Creates a 3D polygon from an array of 3D points.

```swift
public static func create(points: [SIMD3<Double>]) -> Polygon3D?
```

- **Parameters:** `points` — ordered sequence of 3D points.
- **Returns:** `Polygon3D`, or `nil` on failure.
- **OCCT:** `Poly_Polygon3D` via `OCCTPolyPolygon3DCreate`.

---

### `Polygon3D.create(points:parameters:)`

Creates a 3D polygon with curve parameters.

```swift
public static func create(points: [SIMD3<Double>], parameters: [Double]) -> Polygon3D?
```

- **Parameters:** `points` — ordered 3D points; `parameters` — corresponding curve parameter values (must have the same count as `points`).
- **Returns:** `Polygon3D` with parameters, or `nil` on failure.
- **OCCT:** `Poly_Polygon3D` (parameterised overload) via `OCCTPolyPolygon3DCreateWithParams`.
- **Example:**
  ```swift
  let pts: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(5,0,0), SIMD3(10,0,0)]
  let params: [Double] = [0, 0.5, 1]
  if let poly = Polygon3D.create(points: pts, parameters: params) {
      print(poly.hasParameters)  // true
  }
  ```

---

### `Polygon3D.nodeCount`

The number of nodes.

```swift
public var nodeCount: Int { get }
```

- **OCCT:** `Poly_Polygon3D::NbNodes` via `OCCTPolyPolygon3DNbNodes`.

---

### `Polygon3D.node(at:)`

Returns the 3D position at a given 0-based node index.

```swift
public func node(at index: Int) -> SIMD3<Double>?
```

- **Parameters:** `index` — 0-based node index.
- **Returns:** Node position, or `nil` if out of range.
- **OCCT:** `Poly_Polygon3D::Nodes` via `OCCTPolyPolygon3DNode`.

---

### `Polygon3D.nodes()`

Returns all nodes.

```swift
public func nodes() -> [SIMD3<Double>]
```

- **Returns:** Array of all 3D node positions in sequence order.

---

### `Polygon3D.hasParameters`

Whether this polygon has curve parameters.

```swift
public var hasParameters: Bool { get }
```

- **OCCT:** `Poly_Polygon3D::HasParameters` via `OCCTPolyPolygon3DHasParameters`.

---

### `Polygon3D.parameter(at:)`

Returns the curve parameter at a given 0-based index.

```swift
public func parameter(at index: Int) -> Double
```

- **Parameters:** `index` — 0-based index.
- **Returns:** The curve parameter value. Returns 0 if `hasParameters` is `false`.
- **OCCT:** `Poly_Polygon3D::Parameter` via `OCCTPolyPolygon3DParameter`.

---

### `Polygon3D.deflection`

The deflection value of this polygon.

```swift
public var deflection: Double { get set }
```

- **OCCT:** `Poly_Polygon3D::Deflection` / `SetDeflection` via `OCCTPolyPolygon3DDeflection` / `OCCTPolyPolygon3DSetDeflection`.

---

## PolygonOnTriangulation

`PolygonOnTriangulation` wraps `Poly_PolygonOnTriangulation` — a polygon defined as a sequence of indices into a shared `Triangulation`, with optional curve parameters. Used to associate an edge's 2D approximation with a face triangulation.

### `PolygonOnTriangulation.create(nodeIndices:)`

Creates a polygon from node indices into a triangulation.

```swift
public static func create(nodeIndices: [Int32]) -> PolygonOnTriangulation?
```

- **Parameters:** `nodeIndices` — array of 0-based node indices into the associated triangulation.
- **Returns:** `PolygonOnTriangulation`, or `nil` on failure.
- **OCCT:** `Poly_PolygonOnTriangulation` via `OCCTPolyPolygonOnTriCreate`.

---

### `PolygonOnTriangulation.create(nodeIndices:parameters:)`

Creates a polygon from node indices with curve parameters.

```swift
public static func create(nodeIndices: [Int32], parameters: [Double]) -> PolygonOnTriangulation?
```

- **Parameters:** `nodeIndices` — 0-based node indices; `parameters` — corresponding curve parameter values.
- **Returns:** `PolygonOnTriangulation` with parameters, or `nil` on failure.
- **OCCT:** `Poly_PolygonOnTriangulation` (parameterised overload) via `OCCTPolyPolygonOnTriCreateWithParams`.
- **Example:**
  ```swift
  if let poly = PolygonOnTriangulation.create(nodeIndices: [0, 5, 12],
                                               parameters: [0, 0.5, 1]) {
      print(poly.nodeCount)  // 3
  }
  ```

---

### `PolygonOnTriangulation.nodeCount`

The number of nodes referenced by this polygon.

```swift
public var nodeCount: Int { get }
```

- **OCCT:** `Poly_PolygonOnTriangulation::NbNodes` via `OCCTPolyPolygonOnTriNbNodes`.

---

### `PolygonOnTriangulation.nodeIndex(at:)`

Returns the triangulation node index at a given 0-based position.

```swift
public func nodeIndex(at position: Int) -> Int
```

- **Parameters:** `position` — 0-based position in the polygon's node sequence.
- **Returns:** 0-based index into the associated triangulation's node array.
- **OCCT:** `Poly_PolygonOnTriangulation::Node` via `OCCTPolyPolygonOnTriNode`.

---

### `PolygonOnTriangulation.hasParameters`

Whether this polygon has curve parameters.

```swift
public var hasParameters: Bool { get }
```

- **OCCT:** `Poly_PolygonOnTriangulation::HasParameters` via `OCCTPolyPolygonOnTriHasParameters`.

---

### `PolygonOnTriangulation.parameter(at:)`

Returns the curve parameter at a given 0-based index.

```swift
public func parameter(at index: Int) -> Double
```

- **Parameters:** `index` — 0-based index.
- **Returns:** The curve parameter value. Returns 0 if `hasParameters` is `false`.
- **OCCT:** `Poly_PolygonOnTriangulation::Parameter` via `OCCTPolyPolygonOnTriParameter`.

---

### `PolygonOnTriangulation.deflection`

The deflection value of this polygon.

```swift
public var deflection: Double { get set }
```

- **OCCT:** `Poly_PolygonOnTriangulation::Deflection` / `SetDeflection` via `OCCTPolyPolygonOnTriDeflection` / `OCCTPolyPolygonOnTriSetDeflection`.

---

### `PolygonOnTriangulation.copy()`

Creates a deep copy of this polygon.

```swift
public func copy() -> PolygonOnTriangulation?
```

- **Returns:** Independent copy, or `nil` on failure.
- **OCCT:** `Poly_PolygonOnTriangulation::Copy` via `OCCTPolyPolygonOnTriCopy`.

---

### `PolygonOnTriangulation.setNodes(_:)`

Overwrites the node-index array in place.

```swift
@discardableResult
public func setNodes(_ nodeIndices: [Int32]) -> Bool
```

The supplied array must have the same length as `nodeCount`.

- **Parameters:** `nodeIndices` — replacement node index array (same count as `nodeCount`).
- **Returns:** `true` on success, `false` on size mismatch.
- **OCCT:** `Poly_PolygonOnTriangulation::ChangeNodeArray` via `OCCTPolyPolygonOnTriSetNodes`.

---

### `PolygonOnTriangulation.setParameters(_:)`

Overwrites the parameter array in place.

```swift
@discardableResult
public func setParameters(_ params: [Double]) -> Bool
```

Requires `hasParameters == true` and the array length must equal `nodeCount`.

- **Parameters:** `params` — replacement parameter array.
- **Returns:** `true` on success, `false` if `hasParameters` is `false` or lengths mismatch.
- **OCCT:** `Poly_PolygonOnTriangulation::ChangeParameterArray` via `OCCTPolyPolygonOnTriSetParameters`.

---

## Mesh Node Merging

### `MergedMeshData`

Output of merging triangulation nodes across all faces of a meshed shape.

```swift
public struct MergedMeshData: Sendable {
    public let vertices: [SIMD3<Float>]
    public let normals: [SIMD3<Float>]
    public let indices: [UInt32]
    public let triangleCount: Int
    public let vertexCount: Int
}
```

Normals are computed per merged vertex using the `smoothAngle` threshold.

---

### `mergedMeshNodes(from:smoothAngle:mergeTolerance:)`

Merges nodes from all face triangulations of a meshed shape into a single indexed mesh suitable for GPU upload.

```swift
public func mergedMeshNodes(from shape: Shape,
                              smoothAngle: Double,
                              mergeTolerance: Double = 0.0) -> MergedMeshData?
```

- **Parameters:** `shape` — a shape that has been triangulated (e.g., via `Mesh.from(shape:)`); `smoothAngle` — normal-smoothing angle threshold in radians; `mergeTolerance` — distance threshold for merging nodes (0 = positional identity only).
- **Returns:** `MergedMeshData` with interleaved vertex, normal, and index arrays, or `nil` if the shape has no triangulation or the output would exceed 1 000 000 vertices / 3 000 000 indices.
- **OCCT:** `BRep_Builder` face iteration + `Poly_Triangulation` via `OCCTPolyMergeNodes`.
- **Example:**
  ```swift
  let shape = Shape.box(dx: 10, dy: 10, dz: 10)!
  _ = Mesh.from(shape: shape, deflection: 0.1)
  if let mesh = mergedMeshNodes(from: shape, smoothAngle: .pi / 6) {
      // Upload mesh.vertices and mesh.indices to a Metal vertex buffer
      print(mesh.vertexCount, mesh.triangleCount)
  }
  ```
