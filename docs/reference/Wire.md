---
title: Wire
parent: API Reference
---

# Wire

A `Wire` is a connected sequence of edges (curves) — the Swift analog of OCCT's `TopoDS_Wire`. Wires serve two distinct roles: **2D profiles** (closed planar cross-sections for extrusion, lofting, or sweeping) and **3D paths** (open or closed spine curves along which profiles are swept). Obtain a wire by calling one of the static factory methods or by extracting wire sub-shapes from a `Shape`.

## Topics

- [Initializers](#initializers) · [2D Profiles](#2d-profiles-for-extrusionsweep) · [3D Paths](#3d-paths-for-pipe-sweep) · [NURBS Curves](#nurbs-curves) · [Wire From Edges](#wire-from-edges) · [Wire From Curve2D](#wire-from-curve2d-on-plane) · [Wire Composition](#wire-composition) · [Curve Analysis](#curve-analysis) · [Curve Interpolation](#curve-interpolation) · [CAM Operations](#cam-operations) · [Convenience Extensions](#convenience-extensions) · [2D Fillet](#2d-fillet) · [2D Chamfer](#2d-chamfer) · [Helix Curves](#helix-curves) · [Wire Explorer](#wire-explorer) · [Wire Edge Access](#wire-edge-access) · [Wire Topology Analysis](#wire-topology-analysis)

---

## Initializers

### `Wire.init?(_ shape:)`

Constructs a `Wire` by extracting the wire topology from a `Shape`. Returns `nil` if the shape is null or wraps a non-wire topology type.

```swift
public convenience init?(_ shape: Shape)
```

Inverse of `Shape.fromWire(_:)`. Use when you have a wire-typed `Shape` (e.g. from `Shape.wires` or `Shape.subShapes(ofType: .wire)`) and need the typed `Wire` object. Round-trips cleanly with `Shape.fromWire(_:)`.

- **Parameters:** `shape` — a `Shape` wrapping a `TopoDS_Wire`.
- **Returns:** `nil` if `shape` is null or not wire-typed.
- **OCCT:** `TopoDS::Wire` — casts the underlying `TopoDS_Shape` to `TopoDS_Wire` after checking `ShapeType() == TopAbs_WIRE`.
- **Example:**
  ```swift
  if let wire = Wire(someShape) {
      let len = wire.length
  }
  ```

---

## 2D Profiles (for Extrusion/Sweep)

### `Wire.rectangle(width:height:)`

Creates a rectangular profile centred at the origin in the XY plane.

```swift
public static func rectangle(width: Double, height: Double) -> Wire?
```

Corners are at `(±width/2, ±height/2, 0)`. Both dimensions must exceed `Precision::Confusion()` (~1e-7).

- **Parameters:** `width` — X dimension; `height` — Y dimension.
- **Returns:** Closed 4-edge rectangular wire, or `nil` if either dimension ≤ 0 or construction fails.
- **OCCT:** `BRepBuilderAPI_MakeEdge` + `BRepBuilderAPI_MakeWire` — four straight edges assembled into a wire.
- **Example:**
  ```swift
  if let rect = Wire.rectangle(width: 10, height: 5) {
      let box = Shape.extrude(profile: rect, direction: SIMD3(0, 0, 1), length: 20)
  }
  ```

---

### `Wire.circle(origin:normal:radius:)`

Creates a full closed circular wire.

```swift
public static func circle(
    origin: SIMD3<Double> = .zero,
    normal: SIMD3<Double> = SIMD3(0, 0, 1),
    radius: Double
) -> Wire?
```

The circle lies in the plane perpendicular to `normal` passing through `origin`. The default produces a unit circle in the XY plane at the origin.

- **Parameters:** `origin` — centre point; `normal` — plane normal; `radius` — circle radius (must be > 0).
- **Returns:** Closed single-edge circular wire, or `nil` on failure.
- **OCCT:** `gp_Circ` + `BRepBuilderAPI_MakeEdge` + `BRepBuilderAPI_MakeWire`.
- **Example:**
  ```swift
  if let circle = Wire.circle(origin: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1), radius: 3) {
      let cyl = Shape.extrude(profile: circle, direction: SIMD3(0, 0, 1), length: 10)
  }
  ```

---

### `Wire.polygon(_:closed:)`

Creates a polygon wire from 2D points in the XY plane.

```swift
public static func polygon(_ points: [SIMD2<Double>], closed: Bool = true) -> Wire?
```

Points are connected in order with straight-line edges. Pass `closed: true` (the default) to add a closing edge from the last point back to the first, producing a profile suitable for extrusion.

- **Parameters:** `points` — 2D vertex positions (minimum 2); `closed` — whether to close the polygon.
- **Returns:** Polygonal wire, or `nil` if fewer than 2 points or OCCT construction fails (e.g. degenerate/coincident points).
- **OCCT:** `BRepBuilderAPI_MakeEdge` + `BRepBuilderAPI_MakeWire` — one linear edge per consecutive pair of points.
- **Example:**
  ```swift
  let railProfile = Wire.polygon([
      SIMD2(0, 0),
      SIMD2(2.5, 0),
      SIMD2(2.5, 0.8),
      SIMD2(1.8, 0.8),
      SIMD2(1.8, 6.5),
      SIMD2(1.0, 7.0),
      SIMD2(0, 7.0),
      SIMD2(0, 0.8),
  ])
  ```
- **Note:** Returns `nil` if any two consecutive points are coincident (degenerate edge).

---

### `Wire.polygon3D(_:closed:)`

Creates a polygon wire from 3D points with straight-line edges.

```swift
public static func polygon3D(_ points: [SIMD3<Double>], closed: Bool = true) -> Wire?
```

Uses `BRepBuilderAPI_MakePolygon` for fast construction of rectilinear wires in 3D space. Prefer `polygon(_:closed:)` for 2D planar profiles.

- **Parameters:** `points` — 3D vertex positions (minimum 2); `closed` — whether to close the polygon.
- **Returns:** Wire shape, or `nil` if fewer than 2 points or construction fails.
- **OCCT:** `BRepBuilderAPI_MakePolygon` — optimised builder for rectilinear polygon wires.
- **Example:**
  ```swift
  let square = Wire.polygon3D([
      SIMD3(0, 0, 0), SIMD3(10, 0, 0),
      SIMD3(10, 10, 0), SIMD3(0, 10, 0)
  ], closed: true)
  ```

---

## 3D Paths (for Pipe Sweep)

### `Wire.line(from:to:)`

Creates a straight line segment in 3D space.

```swift
public static func line(from start: SIMD3<Double>, to end: SIMD3<Double>) -> Wire?
```

Returns `nil` if `start` and `end` are within 1e-10 of each other (degenerate edge).

- **Parameters:** `from` — start point; `to` — end point.
- **Returns:** Single-edge wire, or `nil` if degenerate.
- **OCCT:** `BRepBuilderAPI_MakeEdge(p1, p2)` + `BRepBuilderAPI_MakeWire`.
- **Example:**
  ```swift
  if let spine = Wire.line(from: .zero, to: SIMD3(100, 0, 0)) {
      let pipe = Shape.pipe(profile: Wire.circle(radius: 5)!, path: spine)
  }
  ```

---

### `Wire.arc(center:radius:startAngle:endAngle:normal:)`

Creates a circular arc in 3D space from centre, radius, and angles.

```swift
public static func arc(
    center: SIMD3<Double>,
    radius: Double,
    startAngle: Double,
    endAngle: Double,
    normal: SIMD3<Double> = SIMD3(0, 0, 1)
) -> Wire?
```

Angles are in radians, measured from the X direction rotated into the plane defined by `normal`. The arc sweeps from `startAngle` to `endAngle` in the direction implied by `normal` (right-hand rule).

- **Parameters:** `center` — arc centre; `radius` — arc radius (must be > 0); `startAngle`/`endAngle` — angular bounds in radians; `normal` — plane normal (default Z-up).
- **Returns:** Single-arc-edge wire, or `nil` if `radius ≤ 0` or angles are coincident.
- **OCCT:** `Geom_Circle` + `Geom_TrimmedCurve` + `BRepBuilderAPI_MakeEdge` + `BRepBuilderAPI_MakeWire`.
- **Example:**
  ```swift
  let curve = Wire.arc(
      center: SIMD3(0, 0, 0),
      radius: 500,
      startAngle: 0,
      endAngle: .pi / 2,
      normal: SIMD3(0, 1, 0)
  )
  ```
- **Note:** When the bend axis is not a canonical world axis, prefer `arc(start:midpoint:end:)` to avoid X-direction ambiguity.

---

### `Wire.arc(start:midpoint:end:)`

Creates a circular arc wire through three specified points.

```swift
public static func arc(
    start: SIMD3<Double>,
    midpoint: SIMD3<Double>,
    end: SIMD3<Double>
) -> Wire?
```

Uses OCCT's `GC_MakeArcOfCircle` to derive the centre and radius from the three points. The `midpoint` resolves the curvature direction. This avoids the X-direction ambiguity of the angle-based `arc(center:radius:startAngle:endAngle:normal:)` constructor.

- **Parameters:** `start` — first endpoint; `midpoint` — a point on the arc; `end` — second endpoint.
- **Returns:** Single-arc-edge wire, or `nil` if the three points are collinear or coincident.
- **OCCT:** `GC_MakeArcOfCircle` + `BRepBuilderAPI_MakeEdge` + `BRepBuilderAPI_MakeWire`.
- **Example:**
  ```swift
  if let arc = Wire.arc(
      start: SIMD3(0, 0, 0),
      midpoint: SIMD3(5, 5, 0),
      end: SIMD3(10, 0, 0)
  ) {
      let len = arc.length
  }
  ```

---

### `Wire.path(_:closed:)`

Creates a 3D path wire from an array of 3D points connected by straight-line edges.

```swift
public static func path(_ points: [SIMD3<Double>], closed: Bool = false) -> Wire?
```

For a smooth interpolated path, use `interpolate(through:)` or `bspline(_:)` instead.

- **Parameters:** `points` — 3D waypoints (minimum 2); `closed` — if `true`, adds an edge from last to first point.
- **Returns:** Straight-segment wire, or `nil` if fewer than 2 points or construction fails.
- **OCCT:** `BRepBuilderAPI_MakeEdge` + `BRepBuilderAPI_MakeWire` — one linear edge per consecutive pair.
- **Example:**
  ```swift
  if let path = Wire.path([
      SIMD3(0, 0, 0), SIMD3(50, 0, 0), SIMD3(100, 50, 0)
  ]) {
      let swept = Shape.sweep(profile: Wire.circle(radius: 2)!, along: path)
  }
  ```

---

### `Wire.bspline(_:)`

Creates a smooth B-spline wire approximated through control points.

```swift
public static func bspline(_ controlPoints: [SIMD3<Double>]) -> Wire?
```

The resulting curve passes *near* the control points (it is an approximation, not an interpolation). For a curve that passes exactly through every point, use `interpolate(through:)`.

- **Parameters:** `controlPoints` — 3D control points (minimum 2).
- **Returns:** Smooth B-spline wire, or `nil` if fewer than 2 points or `GeomAPI_PointsToBSpline` fails.
- **OCCT:** `GeomAPI_PointsToBSpline` → `Geom_BSplineCurve` + `BRepBuilderAPI_MakeEdge` + `BRepBuilderAPI_MakeWire`.
- **Example:**
  ```swift
  let easement = Wire.bspline([
      SIMD3(0, 0, 0),
      SIMD3(50, 0, 0),
      SIMD3(100, 10, 0),
      SIMD3(150, 30, 0),
      SIMD3(180, 50, 0)
  ])
  ```

---

## NURBS Curves

### `Wire.nurbs(poles:weights:knots:multiplicities:degree:)`

Creates a NURBS (Non-Uniform Rational B-Spline) curve with full explicit control.

```swift
public static func nurbs(
    poles: [SIMD3<Double>],
    weights: [Double]? = nil,
    knots: [Double],
    multiplicities: [Int32]? = nil,
    degree: Int32
) -> Wire?
```

Passes directly to `Geom_BSplineCurve`. Provides exact representation of conic sections (circles, ellipses) and is the standard for CAD data exchange. When `weights` is `nil`, all weights default to 1.0 (non-rational B-spline). When `multiplicities` is `nil`, all knot multiplicities default to 1.

- **Parameters:**
  - `poles` — control points (minimum 2).
  - `weights` — per-pole weights (`nil` = uniform 1.0).
  - `knots` — distinct knot values (minimum 2).
  - `multiplicities` — per-knot multiplicity (`nil` = all 1).
  - `degree` — curve degree (1 = linear, 2 = quadratic, 3 = cubic; must be ≥ 1).
- **Returns:** NURBS wire, or `nil` if parameters are invalid.
- **OCCT:** `Geom_BSplineCurve` constructor + `BRepBuilderAPI_MakeEdge` + `BRepBuilderAPI_MakeWire`.
- **Example:**
  ```swift
  // Rational quadratic B-spline — can represent exact quarter-circle arcs
  let poles = [SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(2, 0, 0)]
  let weights = [1.0, 0.707, 1.0]
  let knots = [0.0, 1.0]
  let mults: [Int32] = [3, 3]
  if let arc = Wire.nurbs(poles: poles, weights: weights,
                          knots: knots, multiplicities: mults, degree: 2) {
      let len = arc.length
  }
  ```

---

### `Wire.nurbsUniform(poles:weights:degree:)`

Creates a NURBS curve with an automatically-generated clamped uniform knot vector.

```swift
public static func nurbsUniform(
    poles: [SIMD3<Double>],
    weights: [Double]? = nil,
    degree: Int32
) -> Wire?
```

Simplified NURBS creation: the bridge computes the clamped uniform knot vector automatically. The curve starts at the first control point and ends at the last. Requires at least `degree + 1` control points.

- **Parameters:** `poles` — control points (minimum `degree + 1`); `weights` — per-pole weights (`nil` = 1.0); `degree` — curve degree (≥ 1).
- **Returns:** NURBS wire, or `nil` if `poles.count < degree + 1` or construction fails.
- **OCCT:** `Geom_BSplineCurve` + `BRepBuilderAPI_MakeEdge` + `BRepBuilderAPI_MakeWire` (knot/multiplicity arrays computed internally).
- **Example:**
  ```swift
  let controlPolygon: [SIMD3<Double>] = [
      SIMD3(0, 0, 0), SIMD3(10, 5, 0),
      SIMD3(20, 0, 0), SIMD3(30, 5, 0), SIMD3(40, 0, 0)
  ]
  if let curve = Wire.nurbsUniform(poles: controlPolygon, degree: 3) {
      let len = curve.length
  }
  ```

---

### `Wire.cubicBSpline(poles:)`

Creates a cubic (degree-3) non-rational B-spline wire.

```swift
public static func cubicBSpline(poles: [SIMD3<Double>]) -> Wire?
```

Shorthand for `nurbsUniform(poles:weights:degree:)` with `degree = 3` and uniform weights. Cubic B-splines offer C² continuity (smooth curvature) and good local control. Requires at least 4 control points.

- **Parameters:** `poles` — control points (minimum 4).
- **Returns:** Cubic B-spline wire, or `nil` if fewer than 4 poles or construction fails.
- **OCCT:** Delegates to `OCCTWireCreateNURBSUniform` → `Geom_BSplineCurve` (degree 3, uniform weights).
- **Example:**
  ```swift
  let transitionPoles: [SIMD3<Double>] = [
      SIMD3(0, 0, 0), SIMD3(20, 0, 0),
      SIMD3(40, 2, 0), SIMD3(60, 8, 0),
      SIMD3(80, 20, 0), SIMD3(90, 30, 0)
  ]
  if let easement = Wire.cubicBSpline(poles: transitionPoles) {
      let swept = Shape.sweep(profile: Wire.circle(radius: 1)!, along: easement)
  }
  ```

---

## Wire From Edges

### `Wire.wireFromEdges(_:)`

Creates a wire by assembling individual edges in order.

```swift
public static func wireFromEdges(_ edges: [Edge]) -> Wire?
```

Edges should be geometrically connectable (shared vertices or within tolerance). OCCT connects them during construction.

- **Parameters:** `edges` — array of `Edge` objects (minimum 1).
- **Returns:** Connected wire, or `nil` if the array is empty or `BRepLib_MakeWire` fails.
- **OCCT:** `BRepLib_MakeWire` — adds each `TopoDS_Edge` in order and connects within tolerance.
- **Example:**
  ```swift
  let edges = shape.edges()
  if let wire = Wire.wireFromEdges(Array(edges.prefix(3))) {
      let len = wire.length
  }
  ```

---

## Wire From Curve2D on Plane

### `Wire.fromCurve2D(_:origin:normal:xAxis:)`

Creates a 3D wire by embedding a 2D curve into a geometric plane without discretisation.

```swift
public static func fromCurve2D(_ curve: Curve2D,
                               origin: SIMD3<Double> = .zero,
                               normal: SIMD3<Double> = SIMD3(0, 0, 1),
                               xAxis:  SIMD3<Double> = SIMD3(1, 0, 0)) -> Wire?
```

Lifts the exact parametric representation of a `Curve2D` into 3D space, preserving the original curve geometry. The 2D U axis maps to `xAxis`; the 2D V axis maps to `normal × xAxis`. The resulting wire is suitable for sweep/extrude/loft operations.

- **Parameters:**
  - `curve` — any `Curve2D` (segment, arc, B-spline, etc.).
  - `origin` — where the 2D origin maps in 3D.
  - `normal` — outward normal of the plane (default: Z axis = XY plane).
  - `xAxis` — 3D direction the 2D X axis maps to (default: X axis).
- **Returns:** 3D wire on the specified plane, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_MakeEdge(Geom2d_Curve, Geom_Plane)` + `BRepLib::BuildCurves3d` + `BRepBuilderAPI_MakeWire`.
- **Example:**
  ```swift
  let arc = Curve2D.arcOfCircle(center: .zero, radius: 10,
                                startAngle: 0, endAngle: .pi)!
  if let wire3D = Wire.fromCurve2D(arc,
                                   origin: SIMD3(0, 0, 5),
                                   normal: SIMD3(0, 0, 1),
                                   xAxis:  SIMD3(1, 0, 0)) {
      // use as profile for Shape.pipeShell(spine:profile:)
  }
  ```

---

## Wire Composition

### `Wire.join(_:)`

Joins multiple wires into a single connected wire.

```swift
public static func join(_ wires: [Wire]) -> Wire?
```

Wires should be geometrically connected (end of one near the start of the next). OCCT attempts to connect them within tolerance. The result contains all edges from all input wires.

- **Parameters:** `wires` — array of wires to join (minimum 1).
- **Returns:** Combined wire, or `nil` if the array is empty or `BRepBuilderAPI_MakeWire` fails.
- **OCCT:** `BRepBuilderAPI_MakeWire::Add(TopoDS_Wire)` — adds each wire to the builder in order.
- **Example:**
  ```swift
  let s1 = Wire.line(from: .zero, to: SIMD3(100, 0, 0))!
  let arc = Wire.arc(center: SIMD3(100, 50, 0), radius: 50,
                     startAngle: -.pi/2, endAngle: 0)!
  let s2 = Wire.line(from: SIMD3(150, 50, 0), to: SIMD3(150, 200, 0))!
  if let path = Wire.join([s1, arc, s2]) {
      let swept = Shape.pipe(profile: Wire.circle(radius: 5)!, path: path)
  }
  ```

---

## Curve Analysis

The following members are declared in the `Wire` extension for curve analysis (v0.9.0). All parametric queries take a **normalised parameter** in `[0, 1]` where 0 = wire start and 1 = wire end, mapped linearly across the OCCT parameter range via `BRepAdaptor_CompCurve`.

---

### `curveInfo`

Returns comprehensive curve information in a single call.

```swift
public var curveInfo: CurveInfo? { get }
```

Encapsulates length, closure/periodicity status, and the start/end 3D points. More efficient than calling `length`, `point(at:0)`, and `point(at:1)` separately.

- **Returns:** `CurveInfo` struct, or `nil` if the wire is degenerate or OCCT fails.
- **OCCT:** `BRepAdaptor_CompCurve` + `GCPnts_AbscissaPoint::Length`.
- **Example:**
  ```swift
  if let info = Wire.circle(radius: 5)?.curveInfo {
      print(info.length, info.isClosed)  // ≈ 31.4, true
  }
  ```

---

### `length`

Returns the total arc length of the wire.

```swift
public var length: Double? { get }
```

- **Returns:** Length in model units, or `nil` if measurement fails. Returns `nil` (not 0) for degenerate wires.
- **OCCT:** `BRepAdaptor_CompCurve` + `GCPnts_AbscissaPoint::Length`.
- **Example:**
  ```swift
  let len = Wire.line(from: .zero, to: SIMD3(10, 0, 0))?.length  // 10.0
  ```

---

### `point(at:)`

Returns the 3D position on the wire at a normalised parameter.

```swift
public func point(at parameter: Double) -> SIMD3<Double>?
```

- **Parameters:** `parameter` — value in `[0, 1]` (0 = start, 1 = end).
- **Returns:** 3D position, or `nil` on failure.
- **OCCT:** `BRepAdaptor_CompCurve::Value(actualParam)`.
- **Example:**
  ```swift
  if let arc = Wire.arc(center: .zero, radius: 10, startAngle: 0, endAngle: .pi) {
      let mid = arc.point(at: 0.5)  // midpoint of the arc
  }
  ```

---

### `tangent(at:)`

Returns the unit tangent vector at a normalised parameter.

```swift
public func tangent(at parameter: Double) -> SIMD3<Double>?
```

- **Parameters:** `parameter` — value in `[0, 1]`.
- **Returns:** Normalised tangent vector in the direction of travel, or `nil` on failure.
- **OCCT:** `BRepAdaptor_CompCurve::D1` — first derivative, then normalised.
- **Example:**
  ```swift
  let line = Wire.line(from: .zero, to: SIMD3(10, 0, 0))
  let t = line?.tangent(at: 0.5)  // SIMD3(1, 0, 0)
  ```

---

### `curvature(at:)`

Returns the curvature (1/radius) at a normalised parameter.

```swift
public func curvature(at parameter: Double) -> Double?
```

A straight line has curvature 0; a circle of radius R has curvature 1/R.

- **Parameters:** `parameter` — value in `[0, 1]`.
- **Returns:** Curvature value ≥ 0, or `nil` on failure.
- **OCCT:** `BRepAdaptor_CompCurve::D2` — uses the formula κ = |d1 × d2| / |d1|³.
- **Example:**
  ```swift
  let circle = Wire.circle(radius: 10)
  let k = circle?.curvature(at: 0.5)  // ≈ 0.1 (1/10)
  ```

---

### `curvePoint(at:)`

Returns position, unit tangent, curvature, and principal normal in a single call.

```swift
public func curvePoint(at parameter: Double) -> CurvePoint?
```

More efficient than calling `point(at:)`, `tangent(at:)`, and `curvature(at:)` separately when multiple values are needed. The `normal` field is `nil` when curvature is 0 (straight segment).

- **Parameters:** `parameter` — value in `[0, 1]`.
- **Returns:** `CurvePoint` struct (position, tangent, curvature, optional normal), or `nil` on failure.
- **OCCT:** `BRepAdaptor_CompCurve::D2` — position and both derivatives in one call.
- **Example:**
  ```swift
  if let cp = Wire.circle(radius: 5)?.curvePoint(at: 0.25) {
      print(cp.position, cp.tangent, cp.curvature)
  }
  ```

---

### `offset3D(distance:direction:)`

Translates the entire wire in 3D space along a direction.

```swift
public func offset3D(distance: Double, direction: SIMD3<Double>) -> Wire?
```

This is a rigid translation (not a parallel-curve offset). Use `offset(by:joinType:)` for planar parallel-curve offsetting.

- **Parameters:** `distance` — translation magnitude; `direction` — direction vector (normalised internally).
- **Returns:** Translated wire, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_Transform` with a `gp_Trsf` translation.
- **Example:**
  ```swift
  let bottom = Wire.circle(radius: 5)!
  if let top = bottom.offset3D(distance: 10, direction: SIMD3(0, 0, 1)) {
      // top is a circle at Z=10
      let lofted = Shape.loft(profiles: [bottom, top])
  }
  ```

---

## Curve Interpolation

### `Wire.interpolate(through:closed:tolerance:)`

Creates a smooth B-spline wire that passes exactly through all specified points.

```swift
public static func interpolate(
    through points: [SIMD3<Double>],
    closed: Bool = false,
    tolerance: Double = 1e-6
) -> Wire?
```

Unlike `bspline(_:)` (which approximates), the interpolated curve passes through every point. Produces a `Geom_BSplineCurve` via `GeomAPI_Interpolate`.

- **Parameters:** `points` — points the curve must pass through (minimum 2); `closed` — periodic (closed) curve; `tolerance` — interpolation precision.
- **Returns:** Interpolated B-spline wire, or `nil` on failure.
- **OCCT:** `GeomAPI_Interpolate` + `BRepBuilderAPI_MakeEdge` + `BRepBuilderAPI_MakeWire`.
- **Example:**
  ```swift
  let waypoints: [SIMD3<Double>] = [
      SIMD3(0, 0, 0), SIMD3(10, 5, 0),
      SIMD3(20, 0, 0), SIMD3(30, 5, 0)
  ]
  if let path = Wire.interpolate(through: waypoints) {
      let len = path.length
  }
  ```

---

### `Wire.interpolate(through:startTangent:endTangent:tolerance:)`

Creates a smooth interpolating B-spline wire with constrained end tangents.

```swift
public static func interpolate(
    through points: [SIMD3<Double>],
    startTangent: SIMD3<Double>,
    endTangent: SIMD3<Double>,
    tolerance: Double = 1e-6
) -> Wire?
```

Useful for ensuring smooth connections with adjacent curves — the wire enters at `startTangent` and exits at `endTangent`. The result is always open (not closed), since tangent constraints are applied at both endpoints.

- **Parameters:** `points` — points the curve must pass through (minimum 2); `startTangent` — desired tangent direction at `points[0]`; `endTangent` — desired tangent direction at `points.last`; `tolerance` — interpolation precision.
- **Returns:** Interpolated B-spline wire, or `nil` on failure.
- **OCCT:** `GeomAPI_Interpolate::Load(startTangent, endTangent)` + `Perform()` + `BRepBuilderAPI_MakeEdge`.
- **Example:**
  ```swift
  let points: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(10, 10, 0)]
  if let curve = Wire.interpolate(
      through: points,
      startTangent: SIMD3(1, 0, 0),
      endTangent: SIMD3(0, 1, 0)
  ) {
      let len = curve.length
  }
  ```

---

## CAM Operations

### `JoinType`

Join-style enum for wire offset corner treatment.

```swift
public enum JoinType: Int32 {
    case arc = 0
    case intersection = 1
}
```

- `arc` — corners are rounded with arcs.
- `intersection` — edges are extended to their intersection (sharp corners).

---

### `offset(by:joinType:)`

Offsets the wire by a distance to produce a parallel curve in the plane.

```swift
public func offset(by distance: Double, joinType: JoinType = .arc) -> Wire?
```

Positive distance expands outward; negative contracts inward. The wire must be planar. Internally creates a `BRepBuilderAPI_MakeFace` from the wire, then calls `BRepOffsetAPI_MakeOffset`. Only the outermost contour of the result is returned; inner contours (holes) are discarded.

- **Parameters:** `distance` — offset magnitude (positive = outward, negative = inward); `joinType` — corner handling style.
- **Returns:** Offset wire, or `nil` if the wire is non-planar, the offset degenerates, or `BRepOffsetAPI_MakeOffset` fails.
- **OCCT:** `BRepOffsetAPI_MakeOffset` with `GeomAbs_Arc` or `GeomAbs_Intersection`.
- **Example:**
  ```swift
  let contour = Wire.rectangle(width: 40, height: 40)!
  let toolRadius = 3.0
  if let toolPath = contour.offset(by: toolRadius) {
      // toolPath is where the tool centre travels around the outside
  }
  if let pocketPath = contour.offset(by: -toolRadius) {
      // pocketPath keeps the tool inside the pocket boundary
  }
  ```
- **Note:** Non-planar wires will return `nil` because `BRepBuilderAPI_MakeFace` requires planarity.

---

## Convenience Extensions

### `Wire.railProfile(headWidth:headHeight:webThickness:baseWidth:baseHeight:totalHeight:)`

Creates a simplified rail cross-section profile.

```swift
public static func railProfile(
    headWidth: Double,
    headHeight: Double,
    webThickness: Double,
    baseWidth: Double,
    baseHeight: Double,
    totalHeight: Double
) -> Wire?
```

Builds a closed 12-vertex polygon representing a symmetric I-rail cross section (base foot, vertical web, head). Delegates to `polygon(_:closed:)`. For precise profiles matching published standards, use `polygon(_:closed:)` with exact dimensions.

- **Parameters:** `headWidth` — width of the head (running surface); `headHeight` — height of the head; `webThickness` — web vertical thickness; `baseWidth` — base foot width; `baseHeight` — base foot height; `totalHeight` — total height from base bottom to head top.
- **Returns:** Closed wire, or `nil` if `polygon` construction fails.
- **OCCT:** Delegates to `BRepBuilderAPI_MakeEdge` + `BRepBuilderAPI_MakeWire` via `polygon(_:closed:)`.
- **Example:**
  ```swift
  if let rail = Wire.railProfile(
      headWidth: 14, headHeight: 10,
      webThickness: 5, baseWidth: 25,
      baseHeight: 6, totalHeight: 50
  ) {
      let extruded = Shape.extrude(profile: rail, direction: SIMD3(1, 0, 0), length: 1000)
  }
  ```

---

## 2D Fillet

### `filleted2D(vertexIndex:radius:)`

Applies a 2D fillet (circular arc) to a specific vertex of a planar wire.

```swift
public func filleted2D(vertexIndex: Int, radius: Double) -> Wire?
```

Creates a face from the wire, applies `ChFi2d_Builder::AddFillet` at the indexed vertex, and returns the outer wire of the resulting face. Vertex indices are 0-based in traversal order.

- **Parameters:** `vertexIndex` — 0-based vertex index; `radius` — fillet radius (must be > 0).
- **Returns:** Wire with the corner replaced by an arc, or `nil` on failure.
- **OCCT:** `ChFi2d_Builder::AddFillet` + `BRepTools::OuterWire`.
- **Example:**
  ```swift
  if let rect = Wire.rectangle(width: 10, height: 5) {
      let rounded = rect.filleted2D(vertexIndex: 0, radius: 1.0)
  }
  ```
- **Note:** The wire must be planar. Returns `nil` if `radius` is too large to fit, or if the vertex index is out of range.

---

### `filletedAll2D(radius:)`

Applies 2D fillets to all vertices of a planar wire.

```swift
public func filletedAll2D(radius: Double) -> Wire?
```

Attempts to fillet every vertex with the given radius. If some vertices cannot be filleted (radius too large for adjacent edge lengths), `ChFi2d_Builder` may return the partially-filleted or original wire rather than `nil`.

- **Parameters:** `radius` — fillet radius for all corners.
- **Returns:** Wire with rounded corners, or `nil` on failure.
- **OCCT:** `ChFi2d_Builder::AddFillet` applied to each vertex in the `TopTools_IndexedMapOfShape`.
- **Example:**
  ```swift
  if let rect = Wire.rectangle(width: 10, height: 5) {
      let rounded = rect.filletedAll2D(radius: 1.0)
  }
  ```

---

## 2D Chamfer

### `chamfered2D(vertexIndex:distance1:distance2:)`

Applies a 2D chamfer (straight cut) to a specific vertex of a planar wire.

```swift
public func chamfered2D(vertexIndex: Int, distance1: Double, distance2: Double) -> Wire?
```

Creates a straight line that cuts across the corner, set back `distance1` along one adjacent edge and `distance2` along the other. Uses `ChFi2d_Builder::AddChamfer`.

- **Parameters:** `vertexIndex` — 0-based vertex index; `distance1` — setback along the first edge; `distance2` — setback along the second edge.
- **Returns:** Wire with the corner replaced by a chamfer edge, or `nil` on failure.
- **OCCT:** `ChFi2d_Builder::AddChamfer` + `BRepTools::OuterWire`.
- **Example:**
  ```swift
  if let rect = Wire.rectangle(width: 10, height: 5) {
      let chamfered = rect.chamfered2D(vertexIndex: 0, distance1: 1.0, distance2: 1.0)
  }
  ```
- **Note:** Asymmetric chamfers (`distance1 ≠ distance2`) are supported. Returns `nil` if either distance exceeds adjacent edge length.

---

### `chamferedAll2D(distance:)`

Applies symmetric 2D chamfers to all vertices of a planar wire.

```swift
public func chamferedAll2D(distance: Double) -> Wire?
```

Applies equal `distance1 == distance2 == distance` chamfers to each adjacent-edge pair. If some corners cannot be chamfered, the builder may return a partially-chamfered result.

- **Parameters:** `distance` — chamfer setback on both edges at each corner.
- **Returns:** Wire with chamfered corners, or `nil` on failure.
- **OCCT:** `ChFi2d_Builder::AddChamfer` applied to each adjacent edge pair.
- **Example:**
  ```swift
  if let rect = Wire.rectangle(width: 10, height: 5) {
      let chamfered = rect.chamferedAll2D(distance: 1.0)
  }
  ```

---

## Helix Curves

### `Wire.helix(origin:axis:radius:pitch:turns:clockwise:)`

Creates a constant-radius helical wire.

```swift
public static func helix(
    origin: SIMD3<Double> = .zero,
    axis: SIMD3<Double> = SIMD3(0, 0, 1),
    radius: Double,
    pitch: Double,
    turns: Double,
    clockwise: Bool = false
) -> Wire?
```

All of `radius`, `pitch`, and `turns` must be > 0. The default winding is counter-clockwise when viewed from the positive axis direction.

- **Parameters:** `origin` — axis base point; `axis` — helix axis direction; `radius` — helix radius; `pitch` — axial distance per turn; `turns` — number of full turns; `clockwise` — winding direction.
- **Returns:** Helical wire, or `nil` if any of radius/pitch/turns ≤ 0 or construction fails.
- **OCCT:** `HelixBRep_BuilderHelix::SetParameters` + `Perform`.
- **Example:**
  ```swift
  if let spring = Wire.helix(radius: 5, pitch: 2, turns: 10) {
      let coil = Shape.pipe(profile: Wire.circle(radius: 0.5)!, path: spring)
  }
  ```

---

### `Wire.helixTapered(origin:axis:startRadius:endRadius:pitch:turns:clockwise:)`

Creates a tapered (conical) helical wire where the radius varies linearly.

```swift
public static func helixTapered(
    origin: SIMD3<Double> = .zero,
    axis: SIMD3<Double> = SIMD3(0, 0, 1),
    startRadius: Double,
    endRadius: Double,
    pitch: Double,
    turns: Double,
    clockwise: Bool = false
) -> Wire?
```

All of `startRadius`, `endRadius`, `pitch`, and `turns` must be > 0.

- **Parameters:** `origin` — axis base point; `axis` — helix axis direction; `startRadius` — radius at the start; `endRadius` — radius at the end; `pitch` — axial distance per turn; `turns` — number of turns; `clockwise` — winding direction.
- **Returns:** Tapered helical wire, or `nil` if any required value ≤ 0 or construction fails.
- **OCCT:** `HelixBRep_BuilderHelix::SetParameters` (overload with start/end diameter) + `Perform`.
- **Example:**
  ```swift
  if let cone = Wire.helixTapered(startRadius: 10, endRadius: 2, pitch: 3, turns: 5) {
      let len = cone.length
  }
  ```

---

## Wire Explorer

Members in this section provide ordered traversal of a wire's edges via OCCT's `BRepTools_WireExplorer`, which visits edges in connected sequence.

---

### `orderedEdgeCount`

The number of edges in this wire in ordered traversal sequence.

```swift
public var orderedEdgeCount: Int { get }
```

- **OCCT:** `BRepTools_WireExplorer` — counts edges by iterating the explorer.
- **Example:**
  ```swift
  let rect = Wire.rectangle(width: 10, height: 5)!
  #expect(rect.orderedEdgeCount == 4)
  ```

---

### `orderedEdgePointCount(at:)`

Returns the number of discretised points for an edge at a given ordered index.

```swift
public func orderedEdgePointCount(at index: Int) -> Int
```

- **Parameters:** `index` — 0-based edge index in traversal order.
- **Returns:** Point count, or 0 if the index is out of range.
- **OCCT:** `BRepTools_WireExplorer` + `GCPnts_TangentialDeflection` with 0.01 rad angular and 0.1 chord deflection.
- **Example:**
  ```swift
  let count = wire.orderedEdgePointCount(at: 0)
  ```

---

### `orderedEdgePoints(at:maxPoints:)`

Returns the discretised 3D points of an edge by its ordered traversal index.

```swift
public func orderedEdgePoints(at index: Int, maxPoints: Int? = nil) -> [SIMD3<Double>]?
```

When `maxPoints` is `nil`, allocates a buffer sized to all discretised points (no truncation). When provided, limits the returned array to `maxPoints` elements.

- **Parameters:** `index` — 0-based edge index; `maxPoints` — optional upper limit on returned points.
- **Returns:** Array of 3D points along the edge, or `nil` if the index is out of range or the edge is degenerate.
- **OCCT:** `BRepTools_WireExplorer` + `BRepAdaptor_Curve` + `GCPnts_TangentialDeflection`.
- **Example:**
  ```swift
  let rect = Wire.rectangle(width: 10, height: 5)!
  for i in 0..<rect.orderedEdgeCount {
      if let pts = rect.orderedEdgePoints(at: i) {
          // pts are the discretised points of edge i
      }
  }
  #expect(rect.orderedEdgePoints(at: 99) == nil)
  ```

---

## Wire Edge Access

### `edges()`

Returns all edges of this wire as typed `Edge` objects.

```swift
public func edges() -> [Edge]
```

Converts the wire to a `Shape` via `Shape.fromWire(_:)`, then calls `shape.edges()`. Returns an empty array if conversion fails.

- **Returns:** Array of `Edge` objects, or `[]` if the wire cannot be converted.
- **OCCT:** Pure-Swift delegation to `Shape.edges()`.
- **Example:**
  ```swift
  let edges = Wire.rectangle(width: 10, height: 5)!.edges()
  #expect(edges.count == 4)
  ```

---

### `allEdgePolylines(deflection:maxPointsPerEdge:)`

Returns all edges as discretised polylines.

```swift
public func allEdgePolylines(
    deflection: Double = 0.1,
    maxPointsPerEdge: Int = 1000
) -> [[SIMD3<Double>]]
```

Convenience wrapper: converts to `Shape`, then calls `shape.allEdgePolylines(deflection:maxPointsPerEdge:)`.

- **Parameters:** `deflection` — maximum chord deviation; `maxPointsPerEdge` — maximum points per edge.
- **Returns:** Array of polylines (one per edge), or `[]` on failure.
- **OCCT:** Delegates to `Shape.allEdgePolylines`.
- **Example:**
  ```swift
  let polylines = Wire.circle(radius: 5)!.allEdgePolylines(deflection: 0.05)
  ```

---

### `edgePolyline(at:deflection:maxPoints:)`

Returns a single edge's polyline by index.

```swift
public func edgePolyline(
    at index: Int,
    deflection: Double = 0.1,
    maxPoints: Int = 1000
) -> [SIMD3<Double>]?
```

Convenience wrapper: converts to `Shape`, then calls `shape.edgePolyline(at:deflection:maxPoints:)`.

- **Parameters:** `index` — 0-based edge index; `deflection` — chord deviation; `maxPoints` — point limit.
- **Returns:** Polyline for the edge, or `nil` if index is out of range.
- **OCCT:** Delegates to `Shape.edgePolyline`.
- **Example:**
  ```swift
  if let pts = Wire.rectangle(width: 10, height: 5)!.edgePolyline(at: 0) {
      // pts are the discretised points of the first edge
  }
  ```

---

### `bounds`

The axis-aligned bounding box of the wire.

```swift
public var bounds: (min: SIMD3<Double>, max: SIMD3<Double>) { get }
```

Converts to `Shape` via `Shape.fromWire(_:)`, then returns `shape.bounds`. Returns `(.zero, .zero)` if conversion fails.

- **Returns:** Tuple of min and max corners of the AABB.
- **OCCT:** Delegates to `Shape.bounds` (uses `BRepBndLib::Add`).
- **Example:**
  ```swift
  let bb = Wire.rectangle(width: 10, height: 5)!.bounds
  // bb.min ≈ SIMD3(-5, -2.5, 0), bb.max ≈ SIMD3(5, 2.5, 0)
  ```

---

## Wire Topology Analysis

### `analyze(tolerance:)`

Analyses wire topology for potential issues: closure, gaps, self-intersections, and edge ordering.

```swift
public func analyze(tolerance: Double = 1e-6) -> WireAnalysis?
```

Wraps `ShapeAnalysis_Wire` to detect: whether the wire is closed, whether small or degenerate edges exist, 3D gaps between consecutive edges, self-intersections, and whether edges are in connected order.

- **Parameters:** `tolerance` — analysis precision (default 1e-6).
- **Returns:** `WireAnalysis` struct, or `nil` if analysis fails.
- **OCCT:** `ShapeAnalysis_Wire` — `CheckClosed`, `CheckSmall`, `CheckGaps3d`, `CheckSelfIntersection`, `CheckOrder`, `MinDistance3d`, `MaxDistance3d`.
- **Example:**
  ```swift
  let rect = Wire.rectangle(width: 10, height: 5)!
  if let a = rect.analyze() {
      #expect(a.edgeCount == 4)
      #expect(a.isClosed)
      #expect(!a.hasSelfIntersection)
  }
  ```
