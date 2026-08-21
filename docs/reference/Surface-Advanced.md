---
title: Surface. Advanced Construction
parent: API Reference
---

# Surface. Advanced Construction

This page covers the higher-level surface construction APIs: energy-minimising plate and NLPlate
surfaces, Bezier and BSpline fills, face-from-surface conversions, constrained geometry factories,
and GeomTools persistence. For the core `Surface` type (properties, analytic primitives, swept
surfaces, evaluation), see the main Surface page.

## Topics

- [Advanced Plate Surfaces](#advanced-plate-surfaces-v0230) · [Bezier Surface Fill](#bezier-surface-fill-v0310) · [BSpline Fill from Boundary Curves](#bspline-fill-from-boundary-curves-v0430) · [Face from Surface](#face-from-surface-v0330) · [Constrained Construction, Knot Splitting, Conversions](#constrained-geometry-construction-knot-splitting-conversions-v0500) · [LocalAnalysis](#localanalysis) · [GeomFill NSections](#geomfill_nsections-v0680) · [NLPlate G2/G3, IncrementalSolve, GeomFill_Generator](#nlplate-g2g3-incrementalsolve-geomfill_generator-v0690) · [Extrema, gce Factories, GeomTools Persistence](#extrema-gce-factories-geomtools-persistence-v0800)

---

## Advanced Plate Surfaces (v0.23.0)

### `Surface.plateThrough(_:degree:tolerance:)`

Creates a plate surface (parametric BSpline) that passes through a set of unordered 3D points.

```swift
public static func plateThrough(
    _ points: [SIMD3<Double>],
    degree: Int = 3,
    tolerance: Double = 0.01
) -> Surface?
```

Unlike the grid-based `fromPointGrid`, the points need no ordering or row/column counts, suitable
for scattered probe data, feature points, or any unstructured point set. See also the
[Surfaces from Points](../guides/cookbook/surfaces-from-points.md) cookbook page.

- **Parameters:** `points`, 3D point cloud (minimum 3); `degree`, maximum polynomial degree; `tolerance`, approximation tolerance.
- **Returns:** BSpline surface, or `nil` if fewer than 3 points or `GeomPlate_MakeApprox` fails.
- **OCCT:** `GeomPlate_BuildPlateSurface` + `GeomPlate_PointConstraint` + `GeomPlate_MakeApprox`.
- **Example:**
  ```swift
  let points: [SIMD3<Double>] = [
      SIMD3(0, 0, 0), SIMD3(10, 0, 1), SIMD3(10, 10, 2),
      SIMD3(0, 10, 1), SIMD3(5, 5, 3),
  ]
  if let plate = Surface.plateThrough(points, degree: 3, tolerance: 0.01) {
      let face = plate.toFace()
  }
  ```

#### What `tolerance` means here (#571)

`tolerance` bounds the distance between the fitted BSpline and the plate at the plate's own
constraint points, and the approximator subdivides into more Bezier patches until it is met. Before
#571 it could not be met: five of the six plate entry points capped the approximation at a single
patch, which is the one value that stops `AdvApp2Var_ApproxAFunc2Var` from acting on its own error
criterion, so a violated tolerance and a satisfied one produced the same surface. A 25-point wavy
plate asked for `tolerance: 0.01` came back deviating `0.072`.

Verify it rather than assume it, the fit is a least-squares approximation, not an interpolation,
and a plate that genuinely cannot be fitted still returns its best effort:

```swift
let points: [SIMD3<Double>] = (0..<5).flatMap { i in
    (0..<5).map { j in
        SIMD3(Double(i) * 4, Double(j) * 4,
              4 * sin(Double(i) * 1.3) * cos(Double(j) * 1.1))
    }
}
if let plate = Surface.plateThrough(points, degree: 3, tolerance: 0.01) {
    let worst = points.compactMap { plate.projectPoint($0)?.distance }.max() ?? 0
    print(worst)                // 0.0032, inside tolerance
    print(plate.uPoleCount)     // 16, more than one degree-8 patch, so it did subdivide
}
```

`uPoleCount <= degreeCap + 1` (9 at the default cap of 8) means the fit never subdivided.

---

### `nlPlateDeformed(constraints:resolutionOrder:tolerance:)`

Deforms this surface to pass through target positions using the non-linear plate solver (NLPlate G0, position-only constraints).

```swift
public func nlPlateDeformed(
    constraints: [(uv: SIMD2<Double>, target: SIMD3<Double>)],
    resolutionOrder: Int = 4,
    tolerance: Double = 1e-3
) -> Surface?
```

Each constraint pins the surface at a (u, v) parameter to a desired 3D location. The solver
computes a displacement field on the existing surface; the result preserves the original shape
except where pulled by the constraints.

- **Parameters:** `constraints`, array of `(uv, target)` pairs (non-empty); `resolutionOrder`, the plate's resolution order, 2 through 9; `tolerance`, approximation tolerance.
- **Returns:** New deformed surface, or `nil` if the array is empty, `resolutionOrder` is outside `2...9`, or the solver fails.
- **OCCT:** `NLPlate_NLPlate` + `NLPlate_HPG0Constraint` + `GeomPlate_MakeApprox`.
- **Example:**
  ```swift
  let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
  if let bumped = plane.nlPlateDeformed(
      constraints: [(uv: SIMD2(0, 0), target: SIMD3(0, 0, 5))],
      resolutionOrder: 4, tolerance: 1e-3
  ) {
      let face = bumped.toFace()
  }
  ```
- **Note:** Distinct from fitting a fresh surface to a point set, the existing parametrisation is preserved.

---

### `nlPlateDeformedG1(constraints:resolutionOrder:tolerance:)`

Deforms this surface with position and tangent constraints (NLPlate G0+G1).

```swift
public func nlPlateDeformedG1(
    constraints: [(uv: SIMD2<Double>, target: SIMD3<Double>,
                   tangentU: SIMD3<Double>, tangentV: SIMD3<Double>)],
    resolutionOrder: Int = 4,
    tolerance: Double = 1e-3
) -> Surface?
```

Extends `nlPlateDeformed` by also constraining the partial derivatives (tangent vectors) in
the U and V directions at each constraint point. Use to enforce tangency continuity at the
constrained locations.

- **Parameters:** `constraints`, array of `(uv, target, tangentU, tangentV)` tuples (non-empty); `resolutionOrder`, the plate's resolution order, 2 through 9; `tolerance`, approximation tolerance.
- **Returns:** New deformed surface, or `nil` if the array is empty, `resolutionOrder` is outside `2...9`, or the solver fails.
- **OCCT:** `NLPlate_NLPlate` + `NLPlate_HPG1Constraint` + `GeomPlate_MakeApprox`.
- **Example:**
  ```swift
  if let shaped = plane.nlPlateDeformedG1(
      constraints: [(
          uv: SIMD2(0.5, 0.5),
          target: SIMD3(5, 5, 2),
          tangentU: SIMD3(1, 0, 0),
          tangentV: SIMD3(0, 1, 0)
      )],
      resolutionOrder: 4, tolerance: 1e-3
  ) {
      let face = shaped.toFace()
  }
  ```

---

## Bezier Surface Fill (v0.31.0)

### `BezierFillStyle`

Filling style for Bezier surface construction from boundary curves.

```swift
public enum BezierFillStyle: Int32, Sendable {
    case stretch = 0
    case coons   = 1
    case curved  = 2
}
```

Case meanings, from `GeomFill_FillingStyle`:

---

#### `BezierFillStyle.stretch`

The style with the flattest patches.

#### `BezierFillStyle.coons`

A rounded style of patch, with less depth than `curved`.

#### `BezierFillStyle.curved`

The style with the most rounded patches.

---

### `Surface.bezierFill(_:_:_:_:style:)`

Creates a Bezier surface by filling 4 Bezier boundary curves.

```swift
public static func bezierFill(
    _ c1: Curve3D, _ c2: Curve3D, _ c3: Curve3D, _ c4: Curve3D,
    style: BezierFillStyle = .stretch
) -> Surface?
```

The four curves must be Bezier curves forming a closed boundary (connected end-to-end in order).

- **Parameters:** `c1`–`c4`, four Bezier boundary curves in order; `style`, fill style.
- **Returns:** Bezier surface, or `nil` if any curve is not Bezier or the fill fails.
- **OCCT:** `GeomFill_BezierCurves` (4-curve constructor).
- **Example:**
  ```swift
  // c1..c4 are Bezier curves forming a closed boundary
  if let surf = Surface.bezierFill(c1, c2, c3, c4, style: .coons) {
      let face = surf.toFace()
  }
  ```

---

### `Surface.bezierFill(_:_:style:)`

Creates a Bezier surface by filling 2 Bezier boundary curves as opposite edges.

```swift
public static func bezierFill(
    _ c1: Curve3D, _ c2: Curve3D,
    style: BezierFillStyle = .stretch
) -> Surface?
```

- **Parameters:** `c1`, `c2`, two opposing Bezier boundary curves; `style`, fill style.
- **Returns:** Bezier surface, or `nil` on failure.
- **OCCT:** `GeomFill_BezierCurves` (2-curve constructor).
- **Example:**
  ```swift
  if let surf = Surface.bezierFill(bottom, top, style: .coons) {
      let face = surf.toFace()
  }
  ```

---

## BSpline Fill from Boundary Curves (v0.43.0)

### `Surface.FillStyle`

Filling style for BSpline surface construction from boundary curves.

```swift
public enum FillStyle: Int32, Sendable {
    case stretch = 0
    case coons   = 1
    case curved  = 2
}
```

| Case | Meaning |
|---|---|
| `stretch` | Flattest result: minimal curvature between the boundaries. |
| `coons` | Coons-style blending: moderate curvature. |
| `curved` | Most curved result: maximum curvature. |

*(Per-case anchors below, for cross-reference; the table above has the actual meaning of each.)*

#### `curved`

---

### `Surface.bsplineFill(curve1:curve2:style:)`

Creates a BSpline surface spanning between 2 boundary curves.

```swift
public static func bsplineFill(
    curve1: Curve3D,
    curve2: Curve3D,
    style: FillStyle = .coons
) -> Surface?
```

Both curves must be BSpline (created via `Curve3D.bspline` or `Curve3D.interpolate`). The result
spans from `curve1` to `curve2` in the V direction. See also the
[Gordon Surfaces](../guides/cookbook/gordon-surfaces.md) cookbook for the full fill-vs-Gordon
decision guide.

- **Parameters:** `curve1`, `curve2`, BSpline boundary curves; `style`, fill style.
- **Returns:** BSpline surface, or `nil` if either curve is not BSpline or fill fails.
- **OCCT:** `GeomFill_BSplineCurves` (2-curve constructor).
- **Example:**
  ```swift
  guard let c1 = Curve3D.interpolate(points: [SIMD3(0,0,0), SIMD3(5,0,2), SIMD3(10,0,0)]),
        let c2 = Curve3D.interpolate(points: [SIMD3(0,5,0), SIMD3(5,5,3), SIMD3(10,5,0)])
  else { return }
  if let surf = Surface.bsplineFill(curve1: c1, curve2: c2, style: .coons) {
      let face = surf.toFace()
  }
  ```

---

### `Surface.bsplineFill(curves:style:)`

Creates a BSpline surface bounded by 4 boundary curves.

```swift
public static func bsplineFill(
    curves: (Curve3D, Curve3D, Curve3D, Curve3D),
    style: FillStyle = .coons
) -> Surface?
```

The four curves must be BSpline and connected end-to-end in order (bottom, right, top, left).

- **Parameters:** `curves`, four BSpline boundary curves in order; `style`, fill style.
- **Returns:** BSpline surface, or `nil` on failure.
- **OCCT:** `GeomFill_BSplineCurves` (4-curve constructor).
- **Example:**
  ```swift
  // Four BSpline curves forming a closed loop
  if let surf = Surface.bsplineFill(curves: (bottom, right, top, left), style: .coons) {
      let face = surf.toFace()
  }
  ```

---

## Face from Surface (v0.33.0)

### `toFace(tolerance:)`

Creates a face from this surface using its full parameter domain.

```swift
public func toFace(tolerance: Double = 1e-6) -> Shape?
```

Delegates to `Shape.face(from:uRange:vRange:tolerance:)` with the full `domain.uMin...uMax` and
`domain.vMin...vMax` ranges. The standard way to convert a parametric `Surface` to a renderable
or sewable `Shape`.

- **Parameters:** `tolerance`, face creation tolerance.
- **Returns:** Face shape covering the surface's full UV domain, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_MakeFace` (via `Shape.face`).
- **Example:**
  ```swift
  if let surf = Surface.plateThrough(pts), let face = surf.toFace() {
      let mesh = face.mesh(linearDeflection: 0.1, angularDeflection: 0.3)
  }
  ```

---

### `toFace(uRange:vRange:tolerance:)`

Creates a face from this surface with specific UV parameter bounds.

```swift
public func toFace(
    uRange: ClosedRange<Double>,
    vRange: ClosedRange<Double>,
    tolerance: Double = 1e-6
) -> Shape?
```

Use to cut out a rectangular UV sub-patch of the surface. For a non-rectangular region, use
`toFace(uvBoundary:)`.

- **Parameters:** `uRange`, U parameter range; `vRange`, V parameter range; `tolerance`, tolerance.
- **Returns:** Face shape, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_MakeFace` (via `Shape.face`).
- **Example:**
  ```swift
  if let face = surf.toFace(uRange: 0.0...0.5, vRange: 0.0...1.0) {
      // half of the surface in U
  }
  ```

---

### `toFace(uvBoundary:)`

Creates a face trimmed to a non-rectangular region defined by a closed boundary polygon in UV space.

```swift
public func toFace(uvBoundary: [SIMD2<Double>]) -> Shape?
```

Each segment of the polygon becomes a 2D edge carrying a pcurve on the surface, so the face
footprint follows the polygon exactly, unlike `toFace(uRange:vRange:)`, which only makes
rectangular UV patches. Ideal for reconstructing a fitted analytic surface trimmed to the
real boundary of a region.

- **Parameters:** `uvBoundary`, closed polygon of (u, v) points (minimum 3; the closing segment is implicit).
- **Returns:** The trimmed face, or `nil` if fewer than 3 points or construction fails.
- **OCCT:** `OCCTShapeCreateFaceFromSurfaceUVPolygon` → `BRepBuilderAPI_MakeFace` with pcurve-backed edges.
- **Example:**
  ```swift
  // Triangle trimmed from a BSpline surface in UV space
  let boundary = [SIMD2(0.1, 0.1), SIMD2(0.9, 0.1), SIMD2(0.5, 0.8)]
  if let face = surf.toFace(uvBoundary: boundary) {
      let mesh = face.mesh(linearDeflection: 0.1, angularDeflection: 0.3)
  }
  ```

---

## Constrained Geometry Construction, Knot Splitting, Conversions (v0.50.0)

### `Surface.conicalSurface(origin:direction:semiAngle:radius:)`

Creates an infinite conical surface from an axis placement, semi-angle, and base radius.

```swift
public static func conicalSurface(
    origin: SIMD3<Double> = .zero,
    direction: SIMD3<Double> = SIMD3(0, 0, 1),
    semiAngle: Double,
    radius: Double
) -> Surface?
```

- **Parameters:** `origin`, apex axis origin; `direction`, axis direction; `semiAngle`, half-angle in radians (must be in (0, π/2)); `radius`, base radius at the origin.
- **Returns:** Conical surface, or `nil` if `semiAngle` is out of range or construction fails.
- **OCCT:** `Geom_ConicalSurface` with `gp_Ax3`.
- **Example:**
  ```swift
  if let cone = Surface.conicalSurface(semiAngle: .pi / 6, radius: 5) {
      let face = cone.toFace(uRange: 0...2 * .pi, vRange: 0...20)
  }
  ```

---

### `Surface.conicalSurface(point1:point2:r1:r2:)`

Creates a conical surface passing through two points with specified radii.

```swift
public static func conicalSurface(
    point1: SIMD3<Double>,
    point2: SIMD3<Double>,
    r1: Double,
    r2: Double
) -> Surface?
```

The axis runs from `point1` to `point2`. The cone is defined by radius `r1` at `point1` and `r2`
at `point2`.

- **Parameters:** `point1`, first axis point; `point2`, second axis point; `r1`, radius at `point1`; `r2`, radius at `point2`.
- **Returns:** Conical surface, or `nil` on failure.
- **OCCT:** `Geom_ConicalSurface` derived from the two-point-radii geometry.
- **Example:**
  ```swift
  if let cone = Surface.conicalSurface(
      point1: SIMD3(0, 0, 0), point2: SIMD3(0, 0, 10),
      r1: 5, r2: 2
  ) {
      let face = cone.toFace(uRange: 0...2 * .pi, vRange: 0...10)
  }
  ```

---

### `Surface.cylindricalSurface(origin:direction:radius:)`

Creates a cylindrical surface from an axis and radius.

```swift
public static func cylindricalSurface(
    origin: SIMD3<Double> = .zero,
    direction: SIMD3<Double> = SIMD3(0, 0, 1),
    radius: Double
) -> Surface?
```

- **Parameters:** `origin`, axis base point; `direction`, axis direction; `radius`, cylinder radius.
- **Returns:** Cylindrical surface, or `nil` on failure.
- **OCCT:** `Geom_CylindricalSurface` with `gp_Ax3`.
- **Example:**
  ```swift
  if let cyl = Surface.cylindricalSurface(radius: 5) {
      let face = cyl.toFace(uRange: 0...2 * .pi, vRange: 0...20)
  }
  ```

---

### `Surface.cylindricalSurface(point1:point2:point3:)`

Creates a cylindrical surface through three points.

```swift
public static func cylindricalSurface(
    point1: SIMD3<Double>,
    point2: SIMD3<Double>,
    point3: SIMD3<Double>
) -> Surface?
```

The axis passes through `point1` and `point2`; the radius is the distance from `point3` to
the axis.

- **Parameters:** `point1`, first axis point; `point2`, second axis point; `point3`, point defining the radius.
- **Returns:** Cylindrical surface, or `nil` on failure.
- **OCCT:** `Geom_CylindricalSurface` from the three-point geometry.
- **Example:**
  ```swift
  if let cyl = Surface.cylindricalSurface(
      point1: SIMD3(0, 0, 0),
      point2: SIMD3(0, 0, 10),
      point3: SIMD3(5, 0, 0)
  ) {
      let face = cyl.toFace(uRange: 0...2 * .pi, vRange: 0...10)
  }
  ```

---

### `Surface.planeFromPoints(_:_:_:)`

Creates a plane surface through three points. Canonical implementation for the 3-point
constructor pair, `planeFrom3Points(p1:p2:p3:)` (below) is a labeled-argument spelling and
delegates here (#421); a ground-truth check against the pinned OCCT headers confirmed
`GC_MakePlane` and `gce_MakePln`'s 3-point overloads agree on every case tried (well-separated,
collinear, and coincident points).

```swift
public static func planeFromPoints(
    _ point1: SIMD3<Double>,
    _ point2: SIMD3<Double>,
    _ point3: SIMD3<Double>
) -> Surface?
```

- **Parameters:** `point1`, `point2`, `point3`, three non-collinear points.
- **Returns:** Plane surface, or `nil` if points are collinear (including coincident).
- **OCCT:** `GC_MakePlane(gp_Pnt, gp_Pnt, gp_Pnt)`.
- **Example:**
  ```swift
  if let plane = Surface.planeFromPoints(
      SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(0, 10, 0)
  ) {
      let face = plane.toFace(uRange: 0...10, vRange: 0...10)
  }
  ```

---

### `Surface.planeFromPointNormal(point:normal:)`

Creates a plane surface from a point and normal direction. Canonical implementation for the
point+normal constructor pair, [`Surface.plane(origin:normal:)`](Surface.md) is an
unlabeled-positional spelling and delegates here (#421).

```swift
public static func planeFromPointNormal(
    point: SIMD3<Double>,
    normal: SIMD3<Double>
) -> Surface?
```

- **Parameters:** `point`, a point on the plane; `normal`, plane normal direction.
- **Returns:** Plane surface, or `nil` if `normal` has zero (or near-zero) length.
- **OCCT:** `GC_MakePlane(gp_Pnt, gp_Dir)`.
- **Example:**
  ```swift
  if let plane = Surface.planeFromPointNormal(
      point: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1)
  ) {
      let face = plane.toFace(uRange: -10...10, vRange: -10...10)
  }
  ```

---

### `Surface.trimmedCone(point1:point2:r1:r2:)`

Creates a trimmed (bounded) conical surface between two endpoints with specified radii.

```swift
public static func trimmedCone(
    point1: SIMD3<Double>,
    point2: SIMD3<Double>,
    r1: Double,
    r2: Double
) -> Surface?
```

Unlike `conicalSurface`, the result is a `Geom_RectangularTrimmedSurface` already bounded to the
axial extent between `point1` and `point2`.

- **Parameters:** `point1`, base centre (with radius `r1`); `point2`, top centre (with radius `r2`); `r1`, `r2`, respective radii.
- **Returns:** Bounded trimmed conical surface, or `nil` on failure.
- **OCCT:** `GC_MakeTrimmedCone`.
- **Example:**
  ```swift
  if let cone = Surface.trimmedCone(
      point1: SIMD3(0, 0, 0), point2: SIMD3(0, 0, 10),
      r1: 5, r2: 2
  ) {
      let face = cone.toFace()
  }
  ```

---

### `Surface.trimmedCylinder(origin:direction:radius:height:)`

Creates a trimmed (bounded) cylindrical surface from axis, radius, and height.

```swift
public static func trimmedCylinder(
    origin: SIMD3<Double> = .zero,
    direction: SIMD3<Double> = SIMD3(0, 0, 1),
    radius: Double,
    height: Double
) -> Surface?
```

- **Parameters:** `origin`, base centre; `direction`, axis direction; `radius`, cylinder radius; `height`, axial height (negative = downward).
- **Returns:** Bounded trimmed cylindrical surface, or `nil` on failure.
- **OCCT:** `GC_MakeTrimmedCylinder`.
- **Example:**
  ```swift
  if let cyl = Surface.trimmedCylinder(radius: 5, height: 20) {
      let face = cyl.toFace()
  }
  ```

---

### `knotSplitting(uContinuity:vContinuity:)`

Analyses where a BSpline surface would need to be split to achieve a given continuity level.

```swift
public func knotSplitting(
    uContinuity: ParametricContinuity = .c1,
    vContinuity: ParametricContinuity = .c1
) -> KnotSplitResult
```

Returns the number of U and V splits needed, the actual U/V parameter values at each split, and
the knot-table indices those parameters were read from; does not modify the surface. Each
direction's own first and last knots are always included, so a direction that never drops below
the requested continuity reports exactly those two rather than nothing.

- **Parameters:** `uContinuity`: minimum continuity to require of each U patch; `vContinuity`:
  the same against the V degree and V knots.
- **Returns:** `KnotSplitResult` with `uSplitCount`/`vSplitCount`, `uSplitParams`/`vSplitParams`
  (ascending, bounded by the surface's own U/V domain) and `uSplitIndices`/`vSplitIndices`
  (1-based into the surface's own knot tables, so
  `uSplitParams[i] == bsplineUKnot(index: uSplitIndices[i])`).
- **OCCT:** `GeomConvert_BSplineSurfaceKnotSplitting`, the sole wrapper of it, since #562 deleted
  the second family (`bsplineKnotSplitsU`/`bsplineKnotSplitsV`/`bsplineKnotSplitValues`) that also
  drove it. The indices are what that family carried and this call previously discarded.
- **Continuity range (#480):** the continuity is a *derivative order*, and a knot splits only when
  `degree - multiplicity < continuity`. So the meaningful range is `0...degree` and it saturates
  there. A bicubic surface with simple interior knots is already C2 at every interior knot, which
  means `.c0`, `.c1` and `.c2` all report just the two bounding curves per direction and `.c3` is
  the order that reports the interior ones. On a degree-4-or-higher surface `.c3` is the strictest
  question this vocabulary can ask; [`toBezierPatches()`](Surface.md) is the dedicated API for the
  every-knot split at the far end of that ladder.
- **Example:**
  ```swift
  // Where does the surface actually kink? (multiplicity == degree)
  let kinks = surf.knotSplitting()

  // Every interior knot of a bicubic surface.
  let result = surf.knotSplitting(uContinuity: .c3, vContinuity: .c3)
  print("U splits needed:", result.uSplitCount, result.uSplitParams)
  print("V splits needed:", result.vSplitCount, result.vSplitParams)

  // The raw knot indices, and the identity that ties them to the parameters.
  print(result.uSplitIndices.map { surf.bsplineUKnot(index: $0) } == result.uSplitParams)  // true
  ```

---

### `Surface.joinBezierPatches(_:rows:cols:)`

Joins a rectangular grid of Bezier surface patches into a single BSpline surface.

```swift
public static func joinBezierPatches(
    _ patches: [Surface],
    rows: Int,
    cols: Int
) -> Surface?
```

Adjacent patches must share boundary curves. The `patches` array is row-major (`patches[v * cols + u]`).

Every patch must be non-rational in both directions. `GeomConvert_CompBezierSurfacesToBSplineSurface`
has no rational path at all: its own precondition against rational input is compiled out by this
project's Release kernel, so without this check it would silently join the *polynomial* surface
through a rational patch's control net (dropping its weights) and report success (#725). Weights are
never clamped or dropped: a rational patch is refused outright, not silently approximated.

- **Parameters:** `patches`, 2D array of Bezier surfaces (row-major order; must equal `rows * cols`); `rows`, patch row count; `cols`, patch column count.
- **Returns:** Combined BSpline surface, or `nil` if the count doesn't match `rows * cols`, any patch is rational in either direction, or joining fails.
- **OCCT:** `GeomConvert_CompBezierSurfacesToBSplineSurface`.
- **Example:**
  ```swift
  // Assume patches is a 2×2 grid of Bezier surfaces
  if let combined = Surface.joinBezierPatches(patches, rows: 2, cols: 2) {
      let face = combined.toFace()
  }
  ```

---

### `Surface.AnalyticalConversion`

Result of trying to recognise an analytical surface from a BSpline/Bezier surface.

```swift
public struct AnalyticalConversion {
    public let surface: Surface
    public let gap: Double
}
```

| Field | Meaning |
|---|---|
| `surface` | The recognised analytical surface (plane, cylinder, cone, sphere, or torus) |
| `gap` | Maximum deviation between `surface` and the original surface |

#### `Surface.AnalyticalConversion.gap`

Maximum deviation between the recognised analytical surface and the original BSpline/Bezier surface.

---

### `convertToAnalytical(tolerance:)`

Tries to recognise this BSpline or Bezier surface as a plane, cylinder, cone, sphere, or torus.

```swift
public func convertToAnalytical(tolerance: Double = 1e-4) -> AnalyticalConversion?
```

- **Parameters:** `tolerance`, recognition tolerance.
- **Returns:** `AnalyticalConversion` with the recognised surface and its `gap` (max deviation), or `nil` if not recognisable.
- **OCCT:** `ShapeCustom_Surface::ConvertToAnalytical`.
- **Example:**
  ```swift
  if let result = surf.convertToAnalytical(tolerance: 1e-4) {
      print("recognised surface, gap:", result.gap)
  }
  ```

---

### `Surface.SweptProperties`

Accessor for the direction and basis curve of a swept surface (extrusion or revolution). Obtained via `Surface.sweptProperties` (see [Surface Analytic Types](Surface-Analytic-Types.md)); documented separately here because `Surface-Advanced.md` is this struct's assigned reference page for its internal storage.

```swift
public struct SweptProperties: @unchecked Sendable {
    public var direction: SIMD3<Double> { get }
    public var basisCurve: Curve3D? { get }
}
```

```swift
```
---
### `splitByContinuity(criterion:tolerance:)`

Analyses and splits a BSpline surface at continuity breaks.

```swift
public func splitByContinuity(criterion: Int = 2, tolerance: Double = 1e-6) -> ContinuitySplitResult
```

- **Parameters:** `criterion`, continuity level (0=C0, 1=C1, 2=C2, 3=C3); `tolerance`, tolerance for continuity checking.
- **Returns:** `ContinuitySplitResult` with `wasSplit`, `alreadyMeetsCriterion`, `uSplitCount`, and `vSplitCount`.
- **OCCT:** `BSplSLib::SplitByContinuity`.
- **Example:**
  ```swift
  let r = surf.splitByContinuity(criterion: 2)
  if r.alreadyMeetsCriterion {
      print("surface is already C2")
  } else {
      print("needs \(r.uSplitCount) U splits and \(r.vSplitCount) V splits")
  }
  ```

---

#### `Surface.ContinuitySplitResult`

```swift
public struct ContinuitySplitResult {
    public let wasSplit: Bool
    public let alreadyMeetsCriterion: Bool
    public let uSplitCount: Int
    public let vSplitCount: Int
}
```

#### `ContinuitySplitResult.wasSplit`

Whether the surface was actually split.

#### `ContinuitySplitResult.alreadyMeetsCriterion`

Whether the surface already met the requested continuity, so no split was needed.

#### `ContinuitySplitResult.uSplitCount`

Number of split values found along U.

#### `ContinuitySplitResult.vSplitCount`

Number of split values found along V.

- **Parameters:** `criterion`, continuity level (0=C0, 1=C1, 2=C2, 3=C3); `tolerance`, tolerance for continuity checking.
- **Returns:** `ContinuitySplitResult` with `wasSplit`, `alreadyMeetsCriterion`, `uSplitCount`, and `vSplitCount`.
- **OCCT:** `BSplSLib::SplitByContinuity`.
- **Example:**
  ```swift
  let r = surf.splitByContinuity(criterion: 2)
  if r.alreadyMeetsCriterion {
      print("surface is already C2")
  } else {
      print("needs \(r.uSplitCount) U splits and \(r.vSplitCount) V splits")
  }
  ```

---

## LocalAnalysis

### `continuityWith(_:u1:v1:u2:v2:order:)`

Analyses the geometric continuity between this surface at (u1, v1) and another surface at (u2, v2).

```swift
public func continuityWith(
    _ other: Surface,
    u1: Double, v1: Double,
    u2: Double, v2: Double,
    order: ContinuityClass = .c2
) -> ContinuityAnalysis?
```

`order` selects which classes are measured, not just a ceiling, one branch of
`LocalAnalysis_SurfaceContinuity` runs per call, and `ContinuityAnalysis.holds(_:)` reports `nil`
for anything outside it. See [Surface-Analysis](Surface-Analysis.md#continuityanalysis) for the
per-order measured sets and the `.c2`/second-derivative caveat.

- **Parameters:** `other`, second surface; `u1`, `v1`, UV parameters on this surface; `u2`, `v2`, UV parameters on `other`; `order`, the class to measure (default `.c2`).
- **Returns:** `ContinuityAnalysis`, or `nil` if analysis fails.
- **OCCT:** `LocalAnalysis_SurfaceContinuity`.
- **Example:**
  ```swift
  if let ca = surf1.continuityWith(surf2, u1: 1.0, v1: 0.5, u2: 0.0, v2: 0.5, order: .g1) {
      #expect(ca.holds(.g1) == true)
      print("C0 gap:", ca.c0Value, "G1 angle:", ca.g1Angle)
  }
  ```

---

```swift
```
---
## GeomFill_NSections (v0.68.0)

### `Surface.nSections(curves:params:)`

Creates a BSpline surface by lofting through N section curves at specified parameter values.

```swift
public static func nSections(curves: [Curve3D], params: [Double]) -> Surface?
```

`curves` and `params` must have the same length (minimum 2). The `params` array assigns a V
parameter to each section, typically in `0...1` order.

- **Parameters:** `curves`, section curves (minimum 2); `params`, V parameter for each section (same count as `curves`).
- **Returns:** BSpline surface, or `nil` if counts don't match or `GeomFill_NSections` fails.
- **OCCT:** `GeomFill_NSections`.
- **Example:**
  ```swift
  guard let c1 = Curve3D.interpolate(points: [SIMD3(0,0,0), SIMD3(5,0,0), SIMD3(10,0,0)]),
        let c2 = Curve3D.interpolate(points: [SIMD3(0,5,2), SIMD3(5,5,4), SIMD3(10,5,2)])
  else { return }
  if let surf = Surface.nSections(curves: [c1, c2], params: [0, 1]) {
      let face = surf.toFace()
  }
  ```

---

### `Surface.nSectionsInfo(curves:params:)`

Queries the pole count, knot count, and degree that `nSections` would produce, without building
the surface.

```swift
public static func nSectionsInfo(
    curves: [Curve3D],
    params: [Double]
) -> (poleCount: Int, knotCount: Int, degree: Int)?
```

- **Parameters:** `curves`, section curves (minimum 2); `params`, V parameters (same count).
- **Returns:** Tuple of `(poleCount, knotCount, degree)`, or `nil` on failure.
- **OCCT:** `GeomFill_NSections` (introspection without surface extraction).
- **Example:**
  ```swift
  if let info = Surface.nSectionsInfo(curves: [c1, c2], params: [0, 1]) {
      print("poles:", info.poleCount, "degree:", info.degree)
  }
  ```

---

## NLPlate G2/G3, IncrementalSolve, GeomFill_Generator (v0.69.0)

### `nlPlateDeformedG2(constraints:tolerance:)`

Deforms this surface with position, tangent, and curvature constraints (NLPlate G0+G2).

```swift
public func nlPlateDeformedG2(
    constraints: [(uv: SIMD2<Double>, target: SIMD3<Double>,
                   tangentU: SIMD3<Double>, tangentV: SIMD3<Double>,
                   curvatureUU: SIMD3<Double>, curvatureUV: SIMD3<Double>, curvatureVV: SIMD3<Double>)],
    tolerance: Double = 1e-3
) -> Surface?
```

Extends `nlPlateDeformedG1` by also constraining the second derivatives (curvature tensors) at
each point. Produces curvature-continuous deformations. Each constraint carries 20 doubles.

There is no iteration count. `NLPlate_NLPlate::Solve2(ord, InitialConsraintOrder)` takes none, and
neither does `Solve()`. `IncrementalSolve` does, but it is a different solver rather than a bound
on this one, and it is wrapped separately as
[`nlPlateDeformedIncremental(constraints:maxOrder:initConstraintOrder:nbIncrements:)`](#nlplatedeformedincrementalconstraintsmaxorderinitconstraintordernbincrements).

- **Parameters:** `constraints`, array of constraint tuples (non-empty); `tolerance`, approximation tolerance.
- **Returns:** New deformed surface, or `nil` on failure.
- **OCCT:** `NLPlate_NLPlate` + `NLPlate_HPG2Constraint` + `GeomPlate_MakeApprox`.
- **Example:**
  ```swift
  if let deformed = surf.nlPlateDeformedG2(constraints: [(
      uv: SIMD2(0.5, 0.5), target: SIMD3(5, 5, 3),
      tangentU: SIMD3(1, 0, 0), tangentV: SIMD3(0, 1, 0),
      curvatureUU: .zero, curvatureUV: .zero, curvatureVV: .zero
  )]) {
      let face = deformed.toFace()
  }
  ```

---

### `nlPlateDeformedG3(constraints:tolerance:)`

Deforms this surface with G0+G1+G2+G3 constraints (position, tangent, curvature, and third-order derivatives).

```swift
public func nlPlateDeformedG3(
    constraints: [(uv: SIMD2<Double>, target: SIMD3<Double>,
                   tangentU: SIMD3<Double>, tangentV: SIMD3<Double>,
                   curvatureUU: SIMD3<Double>, curvatureUV: SIMD3<Double>, curvatureVV: SIMD3<Double>,
                   d3UUU: SIMD3<Double>, d3UUV: SIMD3<Double>, d3UVV: SIMD3<Double>, d3VVV: SIMD3<Double>)],
    tolerance: Double = 1e-3
) -> Surface?
```

The highest-order NLPlate constraint set: 32 doubles per constraint (uv + target + 3 first
derivatives + 3 second derivatives + 4 third derivatives). Achieves G3-continuous deformations.

There is no iteration count, for the same reason as `nlPlateDeformedG2(constraints:tolerance:)`.

- **Parameters:** `constraints`, G0+G1+G2+G3 constraint tuples (non-empty); `tolerance`, approximation tolerance.
- **Returns:** New deformed surface, or `nil` on failure.
- **OCCT:** `NLPlate_NLPlate` + `NLPlate_HPG3Constraint` + `GeomPlate_MakeApprox`.
- **Example:**
  ```swift
  if let deformed = surf.nlPlateDeformedG3(constraints: [(
      uv: SIMD2(0.5, 0.5),
      target: SIMD3(5, 5, 3),
      tangentU: SIMD3(1, 0, 0), tangentV: SIMD3(0, 1, 0),
      curvatureUU: .zero, curvatureUV: .zero, curvatureVV: .zero,
      d3UUU: .zero, d3UUV: .zero, d3UVV: .zero, d3VVV: .zero
  )]) {
      let face = deformed.toFace()
  }
  ```

---

### `nlPlateDeformedIncremental(constraints:maxOrder:initConstraintOrder:nbIncrements:)`

Deforms this surface with G0 constraints using the incremental NLPlate solver strategy.

```swift
public func nlPlateDeformedIncremental(
    constraints: [(uv: SIMD2<Double>, target: SIMD3<Double>)],
    maxOrder: Int = 2,
    initConstraintOrder: Int = 1,
    nbIncrements: Int = 4
) -> Surface?
```

Progressively adds constraints for better convergence on challenging constraint sets where the
standard `nlPlateDeformed` may not converge well.

- **Parameters:** `constraints`, G0 constraint pairs (non-empty); `maxOrder`, maximum polynomial order; `initConstraintOrder`, initial constraint order; `nbIncrements`, number of increments.
- **Returns:** New deformed surface, or `nil` on failure.
- **OCCT:** `NLPlate_NLPlate::IncrementalSolve` + `GeomPlate_MakeApprox`.
- **Example:**
  ```swift
  if let deformed = surf.nlPlateDeformedIncremental(
      constraints: [(uv: SIMD2(0.5, 0.5), target: SIMD3(5, 5, 3))],
      nbIncrements: 6
  ) {
      let face = deformed.toFace()
  }
  ```

---

### `nlPlateDerivative(constraints:u:v:iu:iv:)`

Evaluates the partial derivative of the NLPlate G0 displacement field at a UV point.

```swift
public func nlPlateDerivative(
    constraints: [(uv: SIMD2<Double>, target: SIMD3<Double>)],
    u: Double, v: Double,
    iu: Int = 1, iv: Int = 0
) -> SIMD3<Double>?
```

Solves the NLPlate problem with the given G0 constraints and returns the (iu, iv)-th partial
derivative at (u, v) without approximating the surface.

- **Parameters:** `constraints`, G0 constraint pairs; `u`, `v`, evaluation parameters; `iu`, `iv`, derivative orders in U and V.
- **Returns:** Derivative vector, or `nil` on failure.
- **OCCT:** `NLPlate_NLPlate::Evaluate`.
- **Example:**
  ```swift
  if let d = surf.nlPlateDerivative(
      constraints: [(uv: SIMD2(0.5, 0.5), target: SIMD3(5, 5, 2))],
      u: 0.5, v: 0.5, iu: 1, iv: 0
  ) {
      print("dU displacement at (0.5, 0.5):", d)
  }
  ```

---

### `Surface.generatedFromSections(curves:tolerance:)`

Generates a ruled/lofted surface from a sequence of section curves using linear interpolation in V.

```swift
public static func generatedFromSections(
    curves: [Curve3D],
    tolerance: Double = 1e-6
) -> Surface?
```

Uses `GeomFill_Generator` (linear V-direction interpolation), which is simpler and faster than
`nSections` but less flexible, the V blending is always linear between consecutive sections.

- **Parameters:** `curves`, section curves (minimum 2); `tolerance`, parametric tolerance.
- **Returns:** Generated surface, or `nil` if fewer than 2 curves or `GeomFill_Generator` fails.
- **OCCT:** `GeomFill_Generator`.
- **Example:**
  ```swift
  guard let c1 = Curve3D.interpolate(points: [SIMD3(0,0,0), SIMD3(10,0,0)]),
        let c2 = Curve3D.interpolate(points: [SIMD3(0,5,3), SIMD3(10,5,3)])
  else { return }
  if let surf = Surface.generatedFromSections(curves: [c1, c2]) {
      let face = surf.toFace()
  }
  ```

---

### `Surface.degeneratedBoundaryValue(point:first:last:parameter:)`

Evaluates a degenerated boundary (a boundary that has collapsed to a single point) at a parameter.

```swift
public static func degeneratedBoundaryValue(
    point: SIMD3<Double>,
    first: Double = 0,
    last: Double = 1,
    parameter: Double
) -> SIMD3<Double>
```

Returns `point` regardless of `parameter`, models the apex of a cone or any other degenerate
pole boundary.

- **Parameters:** `point`, the degenerate point; `first`, `last`, parameter range; `parameter`, evaluation parameter.
- **Returns:** The degenerate point (always equal to `point`).
- **OCCT:** `GeomFill_DegeneratedBound::Value`.
- **Example:**
  ```swift
  let apex = Surface.degeneratedBoundaryValue(
      point: SIMD3(0, 0, 10), first: 0, last: 1, parameter: 0.5
  )
  // apex == SIMD3(0, 0, 10)
  ```

---

### `Surface.isDegeneratedBoundary(point:first:last:)`

Returns `true`, always, for degenerated boundaries defined by a single point.

```swift
public static func isDegeneratedBoundary(
    point: SIMD3<Double>,
    first: Double = 0,
    last: Double = 1
) -> Bool
```

- **Parameters:** `point`, the degenerate point; `first`, `last`, parameter range.
- **Returns:** Always `true`.
- **OCCT:** `GeomFill_DegeneratedBound::IsDegenerated`.
- **Note:** Provided for API completeness when working with `GeomFill` boundary objects.

---

### `boundaryWithSurfaceEvaluate(curve2d:first:last:parameter:)`

Evaluates a boundary-with-surface (a 2D curve on this surface) at a parameter, returning the 3D point and surface normal.

```swift
public func boundaryWithSurfaceEvaluate(
    curve2d: Curve2D,
    first: Double,
    last: Double,
    parameter: Double
) -> (point: SIMD3<Double>, normal: SIMD3<Double>)?
```

- **Parameters:** `curve2d`, a 2D curve lying on this surface; `first`, `last`, parameter range of the 2D curve; `parameter`, evaluation parameter.
- **Returns:** Tuple of `(point, normal)` at the boundary parameter, or `nil` on failure.
- **OCCT:** `GeomFill_BoundWithSurf::Value` + normal from the host surface.
- **Example:**
  ```swift
  if let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(1, 0)),
     let (pt, n) = surf.boundaryWithSurfaceEvaluate(curve2d: seg, first: 0, last: 1, parameter: 0.5) {
      print("boundary point:", pt, "normal:", n)
  }
  ```

---

### `Surface.averagePlane(points:boundaryPointCount:tolerance:)`

Computes the average plane through a set of 3D points.

```swift
public static func averagePlane(
    points: [SIMD3<Double>],
    boundaryPointCount: Int? = nil,
    tolerance: Double = 1e-3
) -> AveragePlaneResult?
```

Returns the plane normal, origin, and UV bounding box. Also handles the collinear case, returning
`isLine == true` with a line origin and direction.

- **Parameters:** `points`, 3D points (minimum 3); `boundaryPointCount`, number of boundary points used for orientation (defaults to all points); `tolerance`, planarity check tolerance.
- **Returns:** `AveragePlaneResult`, or `nil` if the point set is degenerate.
- **OCCT:** `GeomPlate_BuildAveragePlane`.
- **Example:**
  ```swift
  let pts: [SIMD3<Double>] = [.zero, SIMD3(10,0,0), SIMD3(0,10,0), SIMD3(10,10,0.1)]
  if let result = Surface.averagePlane(points: pts) {
      if result.isPlane { print("normal:", result.normal) }
  }
  ```

---

#### `Surface.AveragePlaneResult.lineOrigin`

A point on the fitted line; meaningful only when `isLine` is `true` (the input points are collinear rather than planar).

#### `Surface.AveragePlaneResult.lineDirection`

Unit direction of the fitted line; meaningful only when `isLine` is `true`.

- **Parameters:** `points`, 3D points (minimum 3); `boundaryPointCount`, number of boundary points used for orientation (defaults to all points); `tolerance`, planarity check tolerance.
- **Returns:** `AveragePlaneResult`, or `nil` if the point set is degenerate.
- **OCCT:** `GeomPlate_BuildAveragePlane`.
- **Example:**
  ```swift
  let pts: [SIMD3<Double>] = [.zero, SIMD3(10,0,0), SIMD3(0,10,0), SIMD3(10,10,0.1)]
  if let result = Surface.averagePlane(points: pts) {
      if result.isPlane { print("normal:", result.normal) }
  }
  ```

---

## Extrema, gce Factories, GeomTools Persistence (v0.80.0)

### `extremaPS(point:)`

Computes point-to-surface extrema (nearest/farthest points).

```swift
public func extremaPS(point: SIMD3<Double>) -> PointSurfaceExtrema
```

- **Parameters:** `point`, the query point.
- **Returns:** `PointSurfaceExtrema` with `isDone` and `count` (number of extremum solutions).
- **OCCT:** `Extrema_ExtPS`.
- **Example:**
  ```swift
  let e = surf.extremaPS(point: SIMD3(5, 5, 10))
  if e.isDone {
      for i in 1...e.count {
          let p = surf.extremaPSPoint(point: SIMD3(5, 5, 10), index: i)
          print("dist²:", p.squareDistance, "uv:", p.u, p.v)
      }
  }
  ```

---

### `extremaPSPoint(point:index:)`

Returns the Nth extremum from a point-surface extrema computation (1-based).

```swift
public func extremaPSPoint(point: SIMD3<Double>, index: Int) -> ExtremaPointOnSurface
```

- **Parameters:** `point`, the query point; `index`, 1-based extremum index.
- **Returns:** `ExtremaPointOnSurface` with `squareDistance`, `point`, `u`, and `v`.
- **OCCT:** `Extrema_ExtPS::Point` / `SquareDistance`.
- **Note:** Call `extremaPS(point:)` first to confirm `isDone` and obtain the valid `count`.

---

### `extremaSS(other:)`

Computes surface-to-surface extrema.

```swift
public func extremaSS(other: Surface) -> SurfaceSurfaceExtrema
```

- **Parameters:** `other`, the second surface.
- **Returns:** `SurfaceSurfaceExtrema` with `isDone`, `isParallel`, and `count`.
- **OCCT:** `Extrema_ExtSS`.
- **Example:**
  ```swift
  let e = surf1.extremaSS(other: surf2)
  if e.isDone, !e.isParallel {
      for i in 1...e.count {
          let pair = surf1.extremaSSPoint(other: surf2, index: i)
          print("dist²:", pair.squareDistance)
      }
  }
  ```

---

### `extremaSSPoint(other:index:)`

Returns the Nth extremum pair from a surface-surface extrema computation.

```swift
public func extremaSSPoint(other: Surface, index: Int) -> Curve3D.ExtremaPointPair
```

- **Parameters:** `other`, the second surface; `index`, 1-based extremum index.
- **Returns:** `Curve3D.ExtremaPointPair` with `squareDistance`, `point1`, `param1`, `point2`, `param2`.
- **OCCT:** `Extrema_ExtSS::Points` / `SquareDistance`.

---

### `Surface.coneFrom2PointsRadii(p1:p2:radius1:radius2:)`

Creates a conical surface from 2 axis points and 2 radii. Equivalent to
`conicalSurface(point1:point2:r1:r2:)`: as of #420 both call the same
`GC_MakeConicalSurface` construction, kept as a separate `gce_Make`-style
entry point.

```swift
public static func coneFrom2PointsRadii(
    p1: SIMD3<Double>,
    p2: SIMD3<Double>,
    radius1: Double,
    radius2: Double
) -> Surface?
```

- **Parameters:** `p1`, `p2`, axis points; `radius1`, radius at `p1`; `radius2`, radius at `p2`.
- **Returns:** Conical surface, or `nil` on failure.
- **OCCT:** `GC_MakeConicalSurface(gp_Pnt, gp_Pnt, Standard_Real, Standard_Real)`.
- **Example:**
  ```swift
  if let cone = Surface.coneFrom2PointsRadii(
      p1: .zero, p2: SIMD3(0, 0, 10), radius1: 5, radius2: 2
  ) {
      let face = cone.toFace()
  }
  ```

---

### `Surface.cylinderFrom3Points(p1:p2:p3:)`

Creates a cylindrical surface from 3 points. Equivalent to
`cylindricalSurface(point1:point2:point3:)`: as of #420 both call the same
`GC_MakeCylindricalSurface` construction, kept as a separate `gce_Make`-style
entry point.

```swift
public static func cylinderFrom3Points(
    p1: SIMD3<Double>,
    p2: SIMD3<Double>,
    p3: SIMD3<Double>
) -> Surface?
```

The axis passes through `p1` and `p2`; `p3` defines the radius (its distance to the axis).

- **Parameters:** `p1`, `p2`, axis points; `p3`, radius-defining point.
- **Returns:** Cylindrical surface, or `nil` on failure.
- **OCCT:** `GC_MakeCylindricalSurface(gp_Pnt, gp_Pnt, gp_Pnt)`.
- **Example:**
  ```swift
  if let cyl = Surface.cylinderFrom3Points(
      p1: .zero, p2: SIMD3(0, 0, 10), p3: SIMD3(5, 0, 0)
  ) {
      let face = cyl.toFace(uRange: 0...2 * .pi, vRange: 0...10)
  }
  ```

---

### `Surface.planeFromEquation(a:b:c:d:)`

Creates a plane surface from the equation Ax + By + Cz + D = 0.

```swift
public static func planeFromEquation(
    a: Double, b: Double, c: Double, d: Double
) -> Surface?
```

- **Parameters:** `a`, `b`, `c`, normal direction coefficients; `d`, plane offset.
- **Returns:** Plane surface, or `nil` on failure.
- **OCCT:** `gce_MakePln(Standard_Real, Standard_Real, Standard_Real, Standard_Real)`.
- **Example:**
  ```swift
  // XY plane at Z = 5: 0x + 0y + 1z - 5 = 0
  if let plane = Surface.planeFromEquation(a: 0, b: 0, c: 1, d: -5) {
      let face = plane.toFace(uRange: -10...10, vRange: -10...10)
  }
  ```

---

### `Surface.planeFrom3Points(p1:p2:p3:)`

Creates a plane surface from 3 points. A labeled-argument spelling of `planeFromPoints(_:_:_:)`
(above) and delegates to it (#421).

```swift
public static func planeFrom3Points(
    p1: SIMD3<Double>,
    p2: SIMD3<Double>,
    p3: SIMD3<Double>
) -> Surface?
```

- **Parameters:** `p1`, `p2`, `p3`, three non-collinear points.
- **Returns:** Plane surface, or `nil` if points are collinear (including coincident).
- **OCCT:** `GC_MakePlane(gp_Pnt, gp_Pnt, gp_Pnt)` (via `planeFromPoints`).
- **Example:**
  ```swift
  if let plane = Surface.planeFrom3Points(
      p1: .zero, p2: SIMD3(10, 0, 0), p3: SIMD3(0, 10, 0)
  ) {
      let face = plane.toFace(uRange: 0...10, vRange: 0...10)
  }
  ```

---

### `Surface.serializeSurfaces(_:)`

Serialises an array of surfaces to a string using `GeomTools_SurfaceSet`.

```swift
public static func serializeSurfaces(_ surfaces: [Surface]) -> String?
```

The produced string can be stored and later restored with `deserializeSurfaces(_:)`. Uses OCCT's
native binary-text stream format.

- **Parameters:** `surfaces`, array of surfaces to serialise.
- **Returns:** Serialised string, or `nil` on failure.
- **OCCT:** `GeomTools_SurfaceSet::Write`.
- **Example:**
  ```swift
  if let data = Surface.serializeSurfaces([surf1, surf2]) {
      // save data to disk
      if let restored = Surface.deserializeSurfaces(data) {
          print("restored \(restored.count) surfaces")
      }
  }
  ```

---

### `Surface.deserializeSurfaces(_:)`

Deserialises surfaces from a string produced by `serializeSurfaces(_:)`.

```swift
public static func deserializeSurfaces(_ data: String) -> [Surface]?
```

- **Parameters:** `data`, string produced by `serializeSurfaces(_:)`.
- **Returns:** Array of restored surfaces, or `nil` if parsing fails or the string is empty.
- **OCCT:** `GeomTools_SurfaceSet::Read`.
- **Example:**
  ```swift
  if let surfaces = Surface.deserializeSurfaces(savedData) {
      for s in surfaces {
          let face = s.toFace()
      }
  }
  ```
