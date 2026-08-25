---
title: Shape. Geometry Recognition & Polygon/Triangulation Data
parent: API Reference
---

# Shape. Geometry Recognition & Polygon/Triangulation Data

This page documents the geometry-utility and polygon/triangulation public API from `Sources/OCCTSwift/Shape.swift`. It covers coordinate-system helpers, curve/surface construction utilities, 2D constraint solvers, shape modification tools, and the full polygon and triangulation layer. See the main [Shape](Shape.md) page for the core B-Rep API.

## Topics

- [Axis2Placement](#axis2placement) · [ShapeConstruct_Curve extensions](#shapeconstruct_curve-extensions) · [Bisector utilities](#bisector-utilities) · [GeomLib_Tool, Parameter Finding](#geomlib_tool--parameter-finding) · [GeomLib_IsPlanarSurface](#geomlib_isplanarsurface) · [GeomLib_CheckBSplineCurve / Check2dBSplineCurve](#geomlib_checkbsplinecurve--check2dbsplinecurve) · [GeomLib_Interpolate](#geomlib_interpolate) · [GccAna_Circ2d2TanRad](#gccana_circ2d2tanrad) · [GccAna_Circ2dTanCen](#gccana_circ2dtancen) · [GccAna_Lin2d2Tan](#gccana_lin2d2tan) · [Approx_SameParameter](#approx_sameparameter) · [ShapeUpgrade Curve Splitting](#shapeupgrade-curve-splitting) · [Shape Modifications](#shape-modifications) · [Surface Splitting](#surface-splitting) · [Curve/Surface Recognition](#curvesurface-recognition) · [Polygon2D](#polygon2d) · [Triangulation](#triangulation) · [Polygon3D](#polygon3d) · [PolygonOnTriangulation](#polygonontriangulation) · [Mesh Node Merging](#mesh-node-merging)

---

## Axis2Placement

A standalone Swift class wrapping `Geom_Axis2Placement`, a right-handed 3D coordinate system with an origin, a main (Z) direction, and an X direction. Used to define placement frames for geometry factories.

### `Axis2Placement.init(origin:normal:xDirection:)`

Creates a right-handed 3D axis placement.

```swift
public init(origin: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>)
```

- **Parameters:** `origin`, origin point; `normal`, main (Z) direction; `xDirection`, X direction (must not be parallel to `normal`).
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

- **Parameters:** `dir`, new main direction.
- **OCCT:** `Geom_Axis2Placement::SetDirection` via `OCCTAxis2PlacementSetDirection`.

---

### `setXDirection(_:)`

Sets the X direction in place.

```swift
public func setXDirection(_ dir: SIMD3<Double>)
```

- **Parameters:** `dir`, new X direction (must not be parallel to the main direction).
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

- **Parameters:** `first`, start parameter; `last`, end parameter; `precision`, geometric tolerance.
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

- **Parameters:** `start`, desired start point; `end`, desired end point.
- **Returns:** `true` on success.
- **OCCT:** `ShapeConstruct_Curve::AdjustCurve` via `OCCTShapeConstructAdjustCurve3D`.

---

### `Curve2D.convertSegmentToBSpline(first:last:precision:)`

Converts a segment of this 2D curve to a BSpline using `ShapeConstruct_Curve`.

```swift
public func convertSegmentToBSpline(first: Double, last: Double,
                                     precision: Double = 1e-6) -> Curve2D?
```

- **Parameters:** `first`, start parameter; `last`, end parameter; `precision`, geometric tolerance.
- **Returns:** New `Curve2D` as a BSpline, or `nil` on failure.
- **OCCT:** `ShapeConstruct_Curve::ConvertToBSpline` via `OCCTShapeConstructConvertToBSpline2D`.

---

### `Curve2D.adjustEndpoints(start:end:)`

Adjusts the 2D curve endpoints to match given 2D points.

```swift
public func adjustEndpoints(start: (Double, Double), end: (Double, Double)) -> Bool
```

- **Parameters:** `start`, desired start point as `(x, y)`; `end`, desired end point as `(x, y)`.
- **Returns:** `true` on success.
- **OCCT:** `ShapeConstruct_Curve::AdjustCurve2d` via `OCCTShapeConstructAdjustCurve2D`.

---

## Bisector utilities

Free-function bisector utilities and their associated value types.

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

#### `BisectorIntersection.x`

X coordinate of the intersection point.

```swift
public let x: Double
```

#### `BisectorIntersection.y`

Y coordinate of the intersection point.

```swift
public let y: Double
```

#### `BisectorIntersection.paramOnFirst`

Parameter of the intersection point along the bisector of `(a, b)` (`IntRes2d_IntersectionPoint::ParamOnFirst()`).

```swift
public let paramOnFirst: Double
```

#### `BisectorIntersection.paramOnSecond`

Parameter of the intersection point along the bisector of `(c, d)` (`IntRes2d_IntersectionPoint::ParamOnSecond()`).

```swift
public let paramOnSecond: Double
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

The bisector of `(a, b)` is intersected with the bisector of `(c, d)`. Where the two pairs span a triangle **and each pair is ordered so that its half-line points at the circumcentre**, that crossing is the circumcentre. The ordering is a real condition rather than a formality: of the four ways to order the two pairs in the example below, one returns the circumcentre and three return an empty array, for the half-line reason set out next.

Each bisector is a **half-line**, not a full line: it starts at its pair's midpoint and runs along one of the two perpendicular directions, the one OCCT selects from the sector the bridge supplies. So reversing a pair, passing `b, a` where you passed `a, b`, flips which way that half-line points, and a crossing that was found becomes an empty result.

An empty result therefore has **four** causes, and they are not distinguished in the return value:

1. One of the pairs is **too close together** to yield a bisector, and the call is refused. The threshold is not machine epsilon: measured, a separation of `1e-9` still gives a crossing and `1e-10` does not. Two different mechanisms refuse, at very different separations. From about `1e-10` down it is `GccAna_NoSolution`, raised inside `Bisector_Bisec::Perform` because the bisector construction has no solution to return. The perpendicular's own normalisation only refuses from about `1e-162`, where the squared component underflows to zero, and an exactly coincident pair reaches that one first. So a caller meeting this in practice meets `GccAna_NoSolution`, not a zero-length direction. Both figures come from the fixture in `Scripts/repro/1050-bisector-domain/occt_1050_limits.mm`, which builds its pair at the origin; treat them as the order of magnitude to expect rather than as constants.
2. The two bisectors are parallel and distinct, and never cross.
3. They cross, but on the dead side of one of the half-lines.
4. They **coincide**, overlapping along their whole length. OCCT reports this as an intersection segment; the function now returns the segment's endpoints (the shared midpoint and the point at infinity / `Precision::Infinite()`). Reversing one pair flips a ray and turns the same input into a single point. Fixed in [#1070](https://github.com/SecondMouseAU/OCCTSwift/issues/1070).

That list is closed **over the geometry**: either a bisector does not exist (1), or both do, and then the two underlying lines are parallel-distinct (2), identical (4), or cross at exactly one point, which either lies on both kept rays or does not (3). It assumes the call returns a result at all, which is a separate condition: a non-finite or near-`1e300` coordinate does not return in bounded time ([#1085](https://github.com/SecondMouseAU/OCCTSwift/issues/1085), pre-existing and not specific to this function's domain).

Each bisector is searched over **its own full parameter range**, which is `[0, Precision::Infinite()]`, so a crossing is found wherever the bisector actually reaches. Until [#1050](https://github.com/SecondMouseAU/OCCTSwift/issues/1050) the search was clamped to a fixed `[-100, 100]` window unrelated to the caller's points, and a crossing past parameter 100 came back empty, indistinguishable from a genuine miss.

That range ends rather than being unbounded, and the ending is worth knowing because it fails the same way: `Precision::Infinite()` is `2e100`, and a crossing past parameter `2e100` still comes back as an empty array with no way to tell it from a genuine miss. Measured, a crossing at `2e100` is found and one at `5e100` is not. The threshold moved from 100 to 2e100; it did not go away. Nothing at CAD scale approaches it, which is why this is a note rather than an open defect.

A distant crossing is computed accurately but is **ill-conditioned in the input**, and the difference matters. Against a closed-form solve of the same four points, the returned crossing is correct to about 1e-16 relative at every distance measured, out to parameter 1e10. What is fragile is the input: a crossing that far away means two nearly parallel bisectors, so perturbing a coordinate by one part in 1e16 moves the crossing by hundreds of units. Feed such a case exact inputs, or treat the answer as a direction rather than a position; re-deriving the points from rounded values will not give you the same crossing back.

- **Parameters:** `a`, `b`, first point pair; `c`, `d`, second point pair, all as `(x, y)`.
- **Returns:** Array of intersection points. Two distinct half-lines meet at most once, so this is empty or holds a single point; coincident half-lines return two points (the segment endpoints); see the four causes above for what empty means.
- **OCCT:** `Bisector_Bisec` (its point-point `Perform`) / `Bisector_Inter` via `OCCTBisectorInterPointPoint`.
- **Example:** the circumcentre of the triangle `(0,0) (4,0) (2,3)`, and the three orderings of the same two pairs that return nothing.
  ```swift
  let hits = bisectorIntersections(a: (0, 0), b: (4, 0),
                                    c: (4, 0), d: (2, 3))
  // hits[0] is the circumcentre, (2, 0.8333333333)

  // The same two pairs, reordered. Each reversal flips a half-line away from the crossing.
  bisectorIntersections(a: (4, 0), b: (0, 0), c: (4, 0), d: (2, 3))  // []
  bisectorIntersections(a: (0, 0), b: (4, 0), c: (2, 3), d: (4, 0))  // []
  bisectorIntersections(a: (4, 0), b: (0, 0), c: (2, 3), d: (4, 0))  // []
  ```

- **Example:** coincident bisectors (same pair twice) return the segment endpoints.
  ```swift
  let coincident = bisectorIntersections(a: (0, 0), b: (4, 0),
                                          c: (0, 0), d: (4, 0))
  // coincident.count == 2
  // coincident[0] is the shared midpoint (2, 0), paramOnFirst == 0
  // coincident[1] is at infinity (Precision::Infinite()), paramOnFirst > 1e99
  ```

- **Example:** a crossing far from the four points, which the pre-#1050 window discarded.
  ```swift
  // Bisector of (0,0)-(0,10) runs along -x from (0,5); bisector of
  // (-155,0)-(-145,0) runs along +y from (-150,0). They meet at (-150, 5).
  let far = bisectorIntersections(a: (0, 0), b: (0, 10),
                                   c: (-155, 0), d: (-145, 0))
  // far[0].x == -150, far[0].y == 5, far[0].paramOnFirst == 150
  ```

---

## GeomLib_Tool. Parameter Finding

Extensions on `Curve3D`, `Surface`, and `Curve2D` for locating parameter values corresponding to 3D/2D points.

### `Curve3D.parameterOf(point:maxDistance:)`

Finds the parameter of a 3D point on this curve.

```swift
public func parameterOf(point: SIMD3<Double>, maxDistance: Double = 1.0) -> Double?
```

- **Parameters:** `point`, 3D point to locate; `maxDistance`, maximum allowed distance from the curve.
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

- **Parameters:** `point`, 3D point to locate; `maxDistance`, maximum allowed distance from the surface.
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

- **Parameters:** `point`, 2D point to locate; `maxDistance`, maximum allowed distance from the curve.
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

- **Parameters:** `tolerance`, planarity tolerance.
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

- **Parameters:** `tolerance`, planarity tolerance.
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

- **Parameters:** `tolerance`, positional tolerance; `angularTolerance`, angular tolerance in radians.
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

- **Parameters:** `fixFirst`, fix the start tangent; `fixLast`, fix the end tangent; `tolerance`, positional tolerance; `angularTolerance`, angular tolerance.
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

- **Parameters:** `tolerance`, positional tolerance; `angularTolerance`, angular tolerance.
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

- **Parameters:** `fixFirst`, fix the start tangent; `fixLast`, fix the end tangent; `tolerance`, positional tolerance; `angularTolerance`, angular tolerance.
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

- **Parameters:** `degree`, polynomial degree; `points`, interpolation points; `parameters`, parameter values corresponding to each point.
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

- **Parameters:** `l1Origin`, `l1Direction`, first line (point + direction); `l2Origin`, `l2Direction`, second line; `radius`, required circle radius; `tolerance`, geometric tolerance.
- **Returns:** Array of up to four `Circle2DSolution` values (may be empty if no solution exists).
- **OCCT:** `GccAna_Circ2d2TanRad` (Lin+Lin variant) via `OCCTGccAnaCirc2d2TanRadLineLin`.
- **Note:** `radius` is the radius of the circles to find, and it must be positive (#553). Asked
  for zero, `GccAna_Circ2d2TanRad` obliges and returns solution circles of radius zero. A
  non-positive radius returns an empty array.
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

- **Parameters:** `p1`, `p2`, two points to pass through; `radius`, required circle radius; `tolerance`, geometric tolerance.
- **Returns:** Array of up to two `Circle2DSolution` values.
- **OCCT:** `GccAna_Circ2d2TanRad` (Pnt+Pnt variant) via `OCCTGccAnaCirc2d2TanRadPntPnt`.
- **Note:** `radius` is the radius of the circles to find, and it must be positive; zero would ask
  for a solution circle that is a point (#553). A non-positive radius returns an empty array, as
  does a radius too small to reach both points.
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

- **Parameters:** `point`, a point on the circle; `center`, the required circle centre.
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

- **Parameters:** `lineOrigin`, a point on the line; `lineDirection`, line direction; `center`, required circle centre.
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

- **Parameters:** `p1`, `p2`, two points; `tolerance`, geometric tolerance.
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

- **Parameters:** `circleCenter`, `circleRadius`, the circle; `point`, point the line must pass through; `tolerance`, geometric tolerance.
- **Returns:** Array of up to two `Line2DSolution` values (one if the point lies on the circle).
- **OCCT:** `GccAna_Lin2d2Tan` (Circ+Pnt variant) via `OCCTGccAnaLin2d2TanCircPnt`.
- **Note:** `circleRadius` must be positive (#553). With a radius of zero the solver returns the
  single line through the centre twice; the point/point entry points answer that question once.
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

| Field | Meaning |
|---|---|
| `isSameParameter` | `true` if the curves already share the same parameterisation within `tolerance` |
| `toleranceReached` | Maximum distance between the 3D curve and the surface-evaluated 2D curve |

#### `SameParameterResult.toleranceReached`

Maximum distance actually measured between the 3D curve and the surface-evaluated 2D curve.

---

### `Curve3D.checkSameParameter(curve2D:surface:tolerance:)`

Checks if a 2D curve on a surface has the same parameterisation as this 3D curve.

```swift
public func checkSameParameter(curve2D: Curve2D, surface: Surface,
                                tolerance: Double = 1e-6) -> SameParameterResult?
```

- **Parameters:** `curve2D`, the 2D curve; `surface`, the surface; `tolerance`, parameterisation tolerance.
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

- **Parameters:** `criterion`, a `ParametricContinuity` raw value: 0=C0, 1=C1, 2=C2, 3=C3, and anything above asks for CN (split at every break); `tolerance`, geometric tolerance.
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

- **Parameters:** `criterion`, a `ParametricContinuity` raw value: 0=C0, 1=C1, 2=C2, 3=C3, and anything above asks for CN (split at every break); `tolerance`, geometric tolerance.
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

- **Parameters:** `tolerance`, positional approximation tolerance; `angleTolerance`, angular tolerance in radians.
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

- **Parameters:** `shape`, input shape; `a11`…`a34`, row-major 3×4 transformation matrix coefficients.
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

- **Parameters:** `shape`, input shape; `a11`…`a34`, row-major 3×4 matrix.
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

- **Parameters:** `shape`, shape to copy; `copyGeometry`, whether to copy underlying geometry; `copyMesh`, whether to copy cached triangulations.
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
                                                continuity3d: ParametricContinuity = .c1,
                                                continuity2d: ParametricContinuity = .c1,
                                                maxDegree: Int = 5,
                                                maxSegments: Int = 20,
                                                priorityDegree: Bool = true,
                                                convertRational: Bool = false) -> Shape?
```

- **Parameters:** `approxSurface`/`approxCurve3d`/`approxCurve2d`, which geometry types to process; `tol3d`/`tol2d`, tolerances; `continuity3d`/`continuity2d`, required continuity, `.c2` being the practical maximum (`.c3` fails the whole call); `maxDegree`, maximum polynomial degree; `maxSegments`, maximum segment count; `priorityDegree`, `true` = reduce degree first, `false` = reduce segments first; `convertRational`, convert rational BSplines to non-rational.
- **Returns:** Restricted shape, or `nil` on failure.
- **OCCT:** `ShapeCustom_BSplineRestriction` driven through `BRepTools_Modifier` via `OCCTShapeBSplineRestrictionAdvanced`, the same mechanism `Shape.bsplineRestriction(...)` reaches through the static `ShapeCustom::BSplineRestriction` helper, and since #490 both read the continuity the same way. The continuity is a ceiling, not a guarantee, through either: OCCT silently reduces what it delivers when the requested one cannot meet `tol3d` within `maxDegree` (#570). This entry point used to read it as a `GeomAbs_Shape` ordinal (`1`=G1, `2`=C1), so the same integer asked for a different continuity through each, and four of the seven values that reading offered failed the whole call. A deprecated `Int` overload remains for source compatibility; it now decodes as `ParametricContinuity` too.

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

- **Parameters:** `extrusionMode`, convert extrusion surfaces; `revolutionMode`, convert revolution surfaces; `offsetMode`, convert offset surfaces; `planeMode`, convert planes.
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

### `Surface.SplitResult`

Split-count result shared by `splitSurfaceByContinuity(criterion:tolerance:)`, `splitByAngle(_:)`
and `splitByArea(parts:intoSquares:)` below.

```swift
public struct SplitResult: Sendable {
    public let uSplitCount: Int
    public let vSplitCount: Int
}
```

- `uSplitCount`/`vSplitCount`: number of splits introduced in each parametric direction.

#### `SplitResult.vSplitCount`

---

### `Surface.splitSurfaceByContinuity(criterion:tolerance:)`

Splits this surface at continuity breaks.

```swift
public func splitSurfaceByContinuity(criterion: Int, tolerance: Double) -> SplitResult?
```

- **Parameters:** `criterion`, a `ParametricContinuity` raw value: 0=C0, 1=C1, 2=C2, 3=C3, above asks for CN; `tolerance`, geometric tolerance.
- **Returns:** `SplitResult` with U and V split counts, or `nil` if no splits are found.
- **OCCT:** `ShapeUpgrade_SplitSurfaceContinuity` via `OCCTSplitSurfaceContinuity`, the same class `Surface.splitByContinuity(criterion:tolerance:)` wraps. Before #490 this entry point read `criterion` as a `GeomAbs_Shape` ordinal while its sibling read it as a parametric continuity, so `criterion: 2` asked for C1 through one and C2 through the other.

---

### `Surface.splitByAngle(_:)`

Splits this surface where the normal varies by more than a maximum angle.

```swift
public func splitByAngle(_ maxAngle: Double) -> SplitResult?
```

- **Parameters:** `maxAngle`, maximum allowed normal deviation in radians.
- **Returns:** `SplitResult`, or `nil` if no splits are needed.
- **OCCT:** `ShapeUpgrade_SplitSurfaceAngle` via `OCCTSplitSurfaceAngle`.

---

### `Surface.splitByArea(parts:intoSquares:)`

Splits this surface into approximately equal-area parts.

```swift
public func splitByArea(parts: Int, intoSquares: Bool = false) -> SplitResult?
```

- **Parameters:** `parts`, desired number of parts; `intoSquares`, if `true`, target square patches.
- **Returns:** `SplitResult`, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_SplitSurfaceArea` via `OCCTSplitSurfaceArea`.

---

## Curve/Surface Recognition

Types and extensions for recognising and converting geometry to analytical (canonical) forms.

Every spelling below reaches one bridge entry point per OCCT converter class, and they share one
contract (#492):

- **An already-analytical input converts.** A circle recognised as a circle is a success, not a
  rejection, and reports `gap == 0` exactly. That is how you tell it apart from a fit.
- **The result is independent of the input.** No returned curve or surface shares state with the
  geometry it was recognised from, so an in-place transform on one never moves the other.
- **Failure is one outcome.** An unrecognisable input, and bounds OCCT rejects, both return `nil`.

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
`newFirst`/`newLast` are expressed in the **recognised** curve's own parameterisation, not the
input's: a BSpline circle examined over `[π/2, 3π/2]` reports a range starting at 0 on the
`Geom_Circle` it returns.

---

#### `CurveToAnalyticalResult.newLast`

---

### `Curve3D.toAnalytical(tolerance:)`

Attempts to convert this curve to an analytical form over its whole domain.

```swift
public func toAnalytical(tolerance: Double = 1e-4) -> Curve3D?
```

- **Parameters:** `tolerance`, recognition tolerance.
- **Returns:** The recognised curve, or `nil` if no analytical form is recognised.
- **OCCT:** `GeomConvert_CurveToAnaCurve` via `OCCTGeomConvertCurveToAnalytical`.
- **Example:**
  ```swift
  let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
  if let analytical = circle.toBSpline()?.toAnalytical(tolerance: 1e-4) {
      print(analytical.curveKind)   // .circle
  }
  ```

---

### `Curve3D.toAnalyticalWithGap(tolerance:)`

Attempts to convert this curve to an analytical form over its whole domain, reporting the deviation.
The full-range spelling of `toAnalytical(tolerance:first:last:)`, and the curve counterpart of
`Surface.toAnalyticalWithGap(tolerance:)`.

```swift
public func toAnalyticalWithGap(tolerance: Double = 1e-4) -> CurveToAnalyticalResult?
```

- **Parameters:** `tolerance`, recognition tolerance.
- **Returns:** `CurveToAnalyticalResult` with the recognised curve, its range and the gap, or `nil`.
- **OCCT:** `GeomConvert_CurveToAnaCurve` via `OCCTGeomConvertCurveToAnalytical`.
- **Example:**
  ```swift
  let bspline = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!.toBSpline()!
  if let r = bspline.toAnalyticalWithGap(tolerance: 1e-4) {
      print(r.gap)   // how far the BSpline strayed from the circle
  }
  ```

---

### `Curve3D.toAnalytical(tolerance:first:last:)`

Attempts to convert this curve to an analytical form (line, circle, ellipse, etc.) over a chosen
parameter range, so a curve that is a circle along part of its domain can be recognised there even
when the whole domain is not.

```swift
public func toAnalytical(tolerance: Double, first: Double, last: Double) -> CurveToAnalyticalResult?
```

- **Parameters:** `tolerance`, recognition tolerance; `first`, `last`, parameter range to examine.
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

- **Parameters:** `points`, array of 3D points; `tolerance`, collinearity tolerance.
- **Returns:** `(isLinear, deviation)`, `isLinear` indicates collinearity; `deviation` is the maximum perpendicular distance from the best-fit line.
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

- **Parameters:** `tolerance`, recognition tolerance.
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

- **Parameters:** `tolerance`, recognition tolerance; `uMin`, `uMax`, `vMin`, `vMax`, UV parameter bounds to consider.
- **Returns:** `SurfaceToAnalyticalResult`, or `nil` on failure. Inverted bounds (`uMin > uMax`) are rejected rather than normalised.
- **OCCT:** `GeomConvert_SurfToAnaSurf` (bounded variant) via `OCCTGeomConvertSurfToAnalyticalBounded`.
- **Example:**
  ```swift
  let d = bsplineSurface.domain
  if let r = bsplineSurface.toAnalyticalWithGap(tolerance: 1e-4,
                                                uMin: d.uMin, uMax: (d.uMin + d.uMax) / 2,
                                                vMin: d.vMin, vMax: d.vMax) {
      print(r.surface.surfaceKind)
  }
  ```

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

`Polygon2D` is a standalone Swift class wrapping `Poly_Polygon2D`, a sequence of 2D points used to represent a parametric-space polygon on a face.

### `Polygon2D.create(points:)`

Creates a 2D polygon from an array of 2D points.

```swift
public static func create(points: [SIMD2<Double>]) -> Polygon2D?
```

- **Parameters:** `points`, ordered sequence of 2D points.
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

- **Parameters:** `index`, 0-based node index.
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

`Triangulation` wraps `Poly_Triangulation`, a 3D mesh defined by node positions and triangle vertex indices. Used as input to `BRepGraph.createTriangulationRep(_:)` for populating the cached mesh tier of a graph. Triangle indices are 0-based on the Swift boundary; the bridge converts to OCCT's 1-based representation internally.

### `Triangulation.create(nodes:triangles:)`

Creates a triangulation from node positions and triangle vertex indices.

```swift
public static func create(nodes: [SIMD3<Double>], triangles: [Int]) -> Triangulation?
```

- **Parameters:** `nodes`, 3D node positions; `triangles`, triangle vertex indices, 0-based, three per triangle (`triangles.count` must be a multiple of 3).
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

- **Parameters:** `index`, 0-based node index.
- **Returns:** Node position, or `nil` if out of range.
- **OCCT:** `Poly_Triangulation::Node` via `OCCTPolyTriangulationNode`.

---

### `Triangulation.triangle(at:)`

Returns the three 0-based vertex indices for a triangle.

```swift
public func triangle(at index: Int) -> (Int, Int, Int)?
```

- **Parameters:** `index`, 0-based triangle index.
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

`Polygon3D` wraps `Poly_Polygon3D`, a sequence of 3D points with optional curve parameters, used to represent an edge approximation in 3D space.

### `Polygon3D.create(points:)`

Creates a 3D polygon from an array of 3D points.

```swift
public static func create(points: [SIMD3<Double>]) -> Polygon3D?
```

- **Parameters:** `points`, ordered sequence of 3D points.
- **Returns:** `Polygon3D`, or `nil` on failure.
- **OCCT:** `Poly_Polygon3D` via `OCCTPolyPolygon3DCreate`.

---

### `Polygon3D.create(points:parameters:)`

Creates a 3D polygon with curve parameters.

```swift
public static func create(points: [SIMD3<Double>], parameters: [Double]) -> Polygon3D?
```

- **Parameters:** `points`, ordered 3D points; `parameters`, corresponding curve parameter values (must have the same count as `points`).
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

- **Parameters:** `index`, 0-based node index.
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

- **Parameters:** `index`, 0-based index.
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

`PolygonOnTriangulation` wraps `Poly_PolygonOnTriangulation`, a polygon defined as a sequence of indices into a shared `Triangulation`, with optional curve parameters. Used to associate an edge's 2D approximation with a face triangulation.

### `PolygonOnTriangulation.create(nodeIndices:)`

Creates a polygon from node indices into a triangulation.

```swift
public static func create(nodeIndices: [Int32]) -> PolygonOnTriangulation?
```

- **Parameters:** `nodeIndices`, array of 0-based node indices into the associated triangulation.
- **Returns:** `PolygonOnTriangulation`, or `nil` on failure.
- **OCCT:** `Poly_PolygonOnTriangulation` via `OCCTPolyPolygonOnTriCreate`.

---

### `PolygonOnTriangulation.create(nodeIndices:parameters:)`

Creates a polygon from node indices with curve parameters.

```swift
public static func create(nodeIndices: [Int32], parameters: [Double]) -> PolygonOnTriangulation?
```

- **Parameters:** `nodeIndices`, 0-based node indices; `parameters`, corresponding curve parameter values.
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

- **Parameters:** `position`, 0-based position in the polygon's node sequence.
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

- **Parameters:** `index`, 0-based index.
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

- **Parameters:** `nodeIndices`, replacement node index array (same count as `nodeCount`).
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

- **Parameters:** `params`, replacement parameter array.
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

- **Parameters:** `shape`: a shape that has been triangulated (e.g., via `Shape.mesh(linearDeflection:angularDeflection:)`); `smoothAngle`: normal-smoothing angle threshold in radians; `mergeTolerance`: distance threshold for merging nodes (0 = positional identity only).
- **Returns:** `MergedMeshData` with interleaved vertex, normal, and index arrays, or `nil` if the shape has no triangulation or the output would exceed 1 000 000 vertices / 3 000 000 indices.
- **OCCT:** a per-occurrence `TopExp_Explorer(TopAbs_FACE)` walk (the shared
  `occtForEachOrientedFace` helper) feeding each face's `BRep_Tool::Triangulation` into
  `Poly_MergeNodesTool::AddTriangulation` (via `OCCTPolyMergeNodes`). Not `BRep_Builder`, which this
  entry used to name and which is not called here. The walk is deliberately per-occurrence rather
  than deduplicated (#613): a face shared by two solids is added once per owner, each wound outward
  for that owner. (#808)
- **Example:**
  ```swift
  let shape = Shape.box(width: 10, height: 10, depth: 10)!
  _ = shape.mesh(linearDeflection: 0.1)
  if let mesh = mergedMeshNodes(from: shape, smoothAngle: .pi / 6) {
      // Upload mesh.vertices and mesh.indices to a Metal vertex buffer
      print(mesh.vertexCount, mesh.triangleCount)
  }
  ```
