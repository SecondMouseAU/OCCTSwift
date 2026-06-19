---
title: Surface — Analysis
parent: API Reference
---

# Surface — Analysis

This page covers the analysis and query members of `Surface`: curvature/normal analysis at a point, singularity detection, surface-to-surface and curve-to-surface extrema, point/curve projection onto a surface, surface–surface and curve–surface intersection, and batch UV evaluation. For factory methods, B-spline/Bezier construction, and operations see the main `Surface` page.

## Topics

- [Local Properties](#local-properties) · [LocalAnalysis](#localanalysis) · [Surface Singularity Analysis](#surface-singularity-analysis-v0370) · [Surface Extrema](#surface-extrema) · [ShapeAnalysis\_Surface Expansion](#shapeanalysis_surface-expansion-v0490) · [Curve Projection](#curve-projection-v0220) · [Surface Intersection & Conversion](#surface-intersection--conversion-v0300) · [Surface-Surface Intersection](#surface-surface-intersection-v0350) · [Curve-Surface Intersection](#curve-surface-intersection-v0350) · [Batch Evaluation](#batch-evaluation-v0290)

---

## Local Properties

Differential geometry queries evaluated at a parametric point `(u, v)` on the surface, backed by `GeomLProp_SLProps`.

---

### `gaussianCurvature(atU:v:)`

Returns the Gaussian curvature at `(u, v)`.

```swift
public func gaussianCurvature(atU u: Double, v: Double) -> Double
```

The Gaussian curvature is the product of the two principal curvatures (`kMin × kMax`). Positive on a convex surface, negative in a saddle region, zero on a developable surface.

- **Parameters:** `u` — U parameter; `v` — V parameter.
- **Returns:** Gaussian curvature value (signed); `0` if `GeomLProp_SLProps` cannot compute derivatives at that point.
- **OCCT:** `GeomLProp_SLProps::GaussianCurvature`.
- **Example:**
  ```swift
  if let sphere = Surface.sphere(radius: 5) {
      let k = sphere.gaussianCurvature(atU: 0, v: 0)  // ≈ 0.04 (1/R²)
  }
  ```

---

### `meanCurvature(atU:v:)`

Returns the mean curvature at `(u, v)`.

```swift
public func meanCurvature(atU u: Double, v: Double) -> Double
```

The mean curvature is the arithmetic mean of the two principal curvatures: `(kMin + kMax) / 2`. Zero on a minimal surface (e.g., a flat plane in its own parameter domain).

- **Parameters:** `u` — U parameter; `v` — V parameter.
- **Returns:** Mean curvature value (signed).
- **OCCT:** `GeomLProp_SLProps::MeanCurvature`.
- **Example:**
  ```swift
  if let cyl = Surface.cylinder(radius: 10, height: 50) {
      let h = cyl.meanCurvature(atU: 0, v: 0.5)  // ≈ 0.05 (1/(2R))
  }
  ```

---

### `PrincipalCurvatures`

Struct returned by `principalCurvatures(atU:v:)`.

```swift
public struct PrincipalCurvatures: Sendable {
    public let kMin: Double
    public let kMax: Double
    public let dirMin: SIMD3<Double>
    public let dirMax: SIMD3<Double>
}
```

- `kMin` / `kMax` — minimum and maximum principal curvatures.
- `dirMin` / `dirMax` — corresponding principal curvature directions in 3D.

---

### `principalCurvatures(atU:v:)`

Returns the principal curvatures and their directions at `(u, v)`.

```swift
public func principalCurvatures(atU u: Double, v: Double) -> PrincipalCurvatures?
```

Uses `GeomLProp_SLProps` to extract both principal curvature values and the orthogonal surface directions along which they act. Returns `nil` if the point is singular or derivatives cannot be computed.

- **Parameters:** `u` — U parameter; `v` — V parameter.
- **Returns:** `PrincipalCurvatures` struct, or `nil` at a singular or degenerate point.
- **OCCT:** `GeomLProp_SLProps::CurvatureDirections` + `MinCurvature` + `MaxCurvature`.
- **Example:**
  ```swift
  if let srf = Surface.sphere(radius: 5),
     let pc  = srf.principalCurvatures(atU: 0, v: 0) {
      print(pc.kMin, pc.kMax)  // both ≈ 0.2 (1/R) for a sphere
  }
  ```

---

## LocalAnalysis

Continuity analysis between two surfaces at a shared junction, backed by `LocalAnalysis_SurfaceContinuity`.

---

### `ContinuityAnalysis`

Struct returned by `continuityWith(_:u1:v1:u2:v2:order:)`.

```swift
public struct ContinuityAnalysis: Sendable {
    public let status: Int
    public let c0Value: Double
    public let g1Angle: Double
    public let c1UAngle: Double
    public let c1VAngle: Double
    public let flags: Int
    public var isC0: Bool { flags & 1  != 0 }
    public var isG1: Bool { flags & 2  != 0 }
    public var isC1: Bool { flags & 4  != 0 }
    public var isG2: Bool { flags & 8  != 0 }
    public var isC2: Bool { flags & 16 != 0 }
}
```

- `status` — raw `GeomAbs_Shape` continuity status code.
- `c0Value` — positional gap distance at the junction.
- `g1Angle` — angle between surface normals at the junction (radians).
- `c1UAngle` / `c1VAngle` — angles between first derivatives in U and V directions.
- `flags` — bitmask: bit 0 = C0, bit 1 = G1, bit 2 = C1, bit 3 = G2, bit 4 = C2.
- Computed boolean helpers `isC0` … `isC2` decode the bitmask.

---

### `continuityWith(_:u1:v1:u2:v2:order:)`

Analyses the continuity between this surface at `(u1, v1)` and another surface at `(u2, v2)`.

```swift
public func continuityWith(
    _ other: Surface,
    u1: Double, v1: Double,
    u2: Double, v2: Double,
    order: Int = 4
) -> ContinuityAnalysis?
```

`order` controls the maximum continuity level tested: 0 = C0, 1 = G1, 2 = C1, 3 = G2, 4 = C2. Use this to verify that two adjacent surface patches meet smoothly at a shared seam.

- **Parameters:** `other` — the second surface; `u1`/`v1` — parameters on this surface; `u2`/`v2` — parameters on `other`; `order` — maximum order to check (0–4, default 4).
- **Returns:** `ContinuityAnalysis`, or `nil` if `LocalAnalysis_SurfaceContinuity` fails (e.g. degenerate point, invalid order).
- **OCCT:** `LocalAnalysis_SurfaceContinuity`.
- **Example:**
  ```swift
  if let a = ContinuityAnalysis(
         s1.continuityWith(s2, u1: u1, v1: v1, u2: u2, v2: v2)
     ) {
      print(a.isG1, a.g1Angle)
  }
  // safe unwrap form:
  if let ca = s1.continuityWith(s2, u1: 0, v1: 0, u2: 0, v2: 0) {
      print(ca.isC1)
  }
  ```

---

## Surface Singularity Analysis (v0.37.0)

Degenerate-region detection backed by `ShapeAnalysis_Surface`.

---

### `singularityCount(tolerance:)`

Returns the number of singularities (poles or degenerate regions) on this surface.

```swift
public func singularityCount(tolerance: Double = 1e-6) -> Int
```

A singularity is a parameter value at which the surface normal vanishes (e.g., the poles of a sphere or the apex of a cone). Returns 0 when the surface has no degenerate regions within the given tolerance.

- **Parameters:** `tolerance` — detection precision (default `1e-6`).
- **Returns:** Count of singularities; 0 if none found.
- **OCCT:** `ShapeAnalysis_Surface` singularity methods.
- **Example:**
  ```swift
  if let sphere = Surface.sphere(radius: 5) {
      let n = sphere.singularityCount()  // 2 — north and south poles
  }
  ```

---

### `isDegenerated(at:tolerance:)`

Returns `true` if the given 3D point lies at a degenerate region of the surface.

```swift
public func isDegenerated(at point: SIMD3<Double>, tolerance: Double = 1e-6) -> Bool
```

- **Parameters:** `point` — 3D point to test; `tolerance` — degeneration precision.
- **Returns:** `true` if the point is within `tolerance` of a degenerate region.
- **OCCT:** `ShapeAnalysis_Surface` degeneration check.
- **Example:**
  ```swift
  if let sphere = Surface.sphere(radius: 5) {
      let atPole = sphere.isDegenerated(at: SIMD3(0, 0, 5))
  }
  ```

---

### `hasSingularities(tolerance:)`

Returns `true` if the surface has any singularities within the given tolerance.

```swift
public func hasSingularities(tolerance: Double = 1e-6) -> Bool
```

Convenience wrapper over `singularityCount(tolerance:)`.

- **Parameters:** `tolerance` — detection precision (default `1e-6`).
- **Returns:** `true` when `singularityCount(tolerance:) > 0`.
- **OCCT:** Delegates to `ShapeAnalysis_Surface` via `singularityCount`.
- **Example:**
  ```swift
  if let cone = Surface.cone(radius: 5, height: 10, halfAngle: .pi / 6) {
      print(cone.hasSingularities())  // true — apex is singular
  }
  ```

---

## Surface Extrema

Minimum-distance computation between two surfaces, backed by `GeomAPI_ExtremaSurfaceSurface`.

---

### `SurfaceExtremaResult`

Struct returned by `extrema(to:uvBounds1:uvBounds2:)`.

```swift
public struct SurfaceExtremaResult {
    public let distance: Double
    public let point1:   SIMD3<Double>
    public let point2:   SIMD3<Double>
    public let uv1:      SIMD2<Double>
    public let uv2:      SIMD2<Double>
}
```

- `distance` — minimum distance between the two surfaces.
- `point1` / `point2` — nearest points on the first and second surface respectively.
- `uv1` / `uv2` — UV parameters on each surface at the nearest point.

---

### `extrema(to:uvBounds1:uvBounds2:)`

Computes the minimum distance between this surface and another.

```swift
public func extrema(
    to other: Surface,
    uvBounds1: (uMin: Double, uMax: Double, vMin: Double, vMax: Double)? = nil,
    uvBounds2: (uMin: Double, uMax: Double, vMin: Double, vMax: Double)? = nil
) -> SurfaceExtremaResult?
```

When `uvBounds1` or `uvBounds2` is `nil`, the bridge substitutes `(0, 1, 0, 1)` — valid for surfaces already in the unit parameter domain; supply explicit bounds for surfaces with other parameter ranges. Returns `nil` when no extrema are found.

- **Parameters:** `other` — the second surface; `uvBounds1` — optional UV bounds restricting the search on this surface; `uvBounds2` — optional UV bounds on `other`.
- **Returns:** `SurfaceExtremaResult`, or `nil` if `GeomAPI_ExtremaSurfaceSurface` finds no solution.
- **OCCT:** `GeomAPI_ExtremaSurfaceSurface`.
- **Example:**
  ```swift
  if let s1 = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)),
     let s2 = Surface.plane(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1)),
     let ex = s1.extrema(to: s2) {
      print(ex.distance)  // ≈ 10.0
  }
  ```
- **Note:** Infinite (untrimmed) surfaces need explicit `uvBounds` to bound the search; otherwise the solver may fail or return a nonsensical result.

---

## ShapeAnalysis\_Surface Expansion (v0.49.0)

UV parameter recovery via `ShapeAnalysis_Surface::ValueOfUV` and `NextValueOfUV`.

---

### `UVProjection`

Struct returned by `valueOfUV(point:precision:)` and `nextValueOfUV(previousUV:point:precision:)`.

```swift
public struct UVProjection: Sendable {
    public let uv:  SIMD2<Double>
    public let gap: Double
}
```

- `uv` — surface UV parameters at the closest surface point.
- `gap` — distance between the input 3D point and the surface evaluated at `uv`. A nonzero gap means the input point was not exactly on the surface.

---

### `valueOfUV(point:precision:)`

Projects a 3D point onto the surface and returns UV parameters.

```swift
public func valueOfUV(point: SIMD3<Double>, precision: Double = 1e-6) -> UVProjection
```

Suitable for a one-off query when no hint is available. For sequential queries along a path, `nextValueOfUV(previousUV:point:precision:)` is faster.

- **Parameters:** `point` — 3D point to project; `precision` — projection precision (default `1e-6`).
- **Returns:** `UVProjection` (never `nil`; a non-zero `gap` indicates the point was off-surface).
- **OCCT:** `ShapeAnalysis_Surface::ValueOfUV`.
- **Example:**
  ```swift
  if let srf = Surface.sphere(radius: 5) {
      let proj = srf.valueOfUV(point: SIMD3(0, 0, 5))
      print(proj.uv, proj.gap)
  }
  ```

---

### `nextValueOfUV(previousUV:point:precision:)`

Projects a 3D point using a previously found UV as a starting hint.

```swift
public func nextValueOfUV(
    previousUV: SIMD2<Double>,
    point:      SIMD3<Double>,
    precision:  Double = 1e-6
) -> UVProjection
```

More efficient than `valueOfUV(point:precision:)` when projecting a sequence of closely-spaced points (e.g. sampling along a curve on the surface). The previous result is used as the initial guess, reducing solver iterations.

- **Parameters:** `previousUV` — UV result from the prior point; `point` — new 3D point to project; `precision` — projection precision (default `1e-6`).
- **Returns:** `UVProjection` for `point`.
- **OCCT:** `ShapeAnalysis_Surface::NextValueOfUV`.
- **Example:**
  ```swift
  if let srf = Surface.sphere(radius: 5) {
      var prev = srf.valueOfUV(point: SIMD3(5, 0, 0)).uv
      for pt in samplePoints {
          let p = srf.nextValueOfUV(previousUV: prev, point: pt)
          prev = p.uv
      }
  }
  ```

---

## Curve Projection (v0.22.0)

Project curves and points onto surfaces, returning UV-space or 3D curves. Backed by `GeomProjLib` and `GeomAPI_ProjectPointOnSurf`.

---

### `SurfaceProjection`

Struct returned by `projectPoint(_:)`.

```swift
public struct SurfaceProjection: Sendable {
    public let u:        Double
    public let v:        Double
    public let distance: Double
}
```

- `u` / `v` — surface UV parameters at the closest point.
- `distance` — 3D distance from the input point to the surface.

---

### `projectCurve(_:tolerance:)`

Projects a 3D curve onto this surface, returning a 2D parametric (UV) curve.

```swift
public func projectCurve(_ curve: Curve3D, tolerance: Double = 1e-4) -> Curve2D?
```

Uses `GeomProjLib::Curve2d` for analytic (normal) projection. The resulting `Curve2D` is in the surface's UV parameter space and is suitable for defining pcurves or trimming boundaries.

- **Parameters:** `curve` — the 3D curve to project; `tolerance` — projection tolerance (default `1e-4`).
- **Returns:** 2D UV-space curve, or `nil` if the projection fails (e.g. curve not projectable onto the surface within tolerance).
- **OCCT:** `GeomProjLib::Curve2d`.
- **Example:**
  ```swift
  if let srf  = Surface.cylinder(radius: 10, height: 50),
     let line = Curve3D.line(from: SIMD3(10, 0, 0), to: SIMD3(10, 0, 50)),
     let uv   = srf.projectCurve(line) {
      // uv is the isoline in cylinder UV space
  }
  ```

---

### `projectCurveSegments(_:tolerance:)`

Projects a 3D curve onto this surface, returning multiple UV-space segments.

```swift
public func projectCurveSegments(_ curve: Curve3D, tolerance: Double = 1e-4) -> [Curve2D]
```

Uses `ProjLib_CompProjectedCurve`, which handles cases where the curve projection crosses surface seams or boundaries and maps to disconnected UV segments. Returns an empty array on failure.

- **Parameters:** `curve` — the 3D curve to project; `tolerance` — projection tolerance (default `1e-4`).
- **Returns:** Array of 2D UV curves (may be empty if projection fails or the curve does not intersect the surface domain).
- **OCCT:** `ProjLib_CompProjectedCurve`.
- **Example:**
  ```swift
  if let srf    = Surface.sphere(radius: 10),
     let spiral = Curve3D.helix(radius: 10, pitch: 2, turns: 3) {
      let segs = srf.projectCurveSegments(spiral)
      // segs may contain multiple UV segments when the helix crosses the seam
  }
  ```

---

### `projectCurve3D(_:)`

Projects a 3D curve onto this surface, returning a 3D curve that lies on the surface.

```swift
public func projectCurve3D(_ curve: Curve3D) -> Curve3D?
```

Uses `GeomProjLib::Project` for normal projection. The result is a 3D curve — unlike `projectCurve(_:tolerance:)`, it is not in UV space.

- **Parameters:** `curve` — the 3D curve to project.
- **Returns:** 3D curve lying on the surface, or `nil` on failure.
- **OCCT:** `GeomProjLib::Project`.
- **Example:**
  ```swift
  if let srf  = Surface.sphere(radius: 10),
     let line = Curve3D.line(from: SIMD3(0, 0, -20), to: SIMD3(0, 0, 20)),
     let onSrf = srf.projectCurve3D(line) {
      // onSrf is the meridian arc on the sphere
  }
  ```

---

### `projectPoint(_:)`

Projects a 3D point onto this surface and returns the closest UV parameters and distance.

```swift
public func projectPoint(_ point: SIMD3<Double>) -> SurfaceProjection?
```

Uses `GeomAPI_ProjectPointOnSurf` to find the nearest surface point. Returns `nil` if the projection fails (e.g. the surface is degenerate).

- **Parameters:** `point` — 3D point to project.
- **Returns:** `SurfaceProjection` with `u`, `v`, and `distance`, or `nil` on failure.
- **OCCT:** `GeomAPI_ProjectPointOnSurf`.
- **Example:**
  ```swift
  if let srf  = Surface.sphere(radius: 5),
     let proj = srf.projectPoint(SIMD3(3, 4, 0)) {
      print(proj.u, proj.v, proj.distance)  // distance ≈ 0 (point is on the sphere)
  }
  ```

---

## Surface Intersection & Conversion (v0.30.0)

---

### `intersections(with:tolerance:maxCurves:)`

Intersects this surface with another and returns the intersection curves.

```swift
public func intersections(with other: Surface, tolerance: Double = 1e-6, maxCurves: Int = 50) -> [Curve3D]
```

Returns an empty array when the surfaces do not intersect. This is the earlier (v0.30.0) intersection method; see also `intersectionCurves(with:tolerance:)` added in v0.35.0.

- **Parameters:** `other` — the second surface; `tolerance` — intersection tolerance (default `1e-6`); `maxCurves` — upper bound on the number of returned curves (default 50).
- **Returns:** Array of 3D intersection curves (may be empty).
- **OCCT:** `GeomAPI_IntSS`.
- **Example:**
  ```swift
  if let plane  = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)),
     let sphere = Surface.sphere(radius: 5) {
      let curves = plane.intersections(with: sphere)
      // curves contains the great circle where the plane cuts the sphere
  }
  ```

---

### `toAnalytical(tolerance:)`

Converts a freeform surface to an analytic surface if it can be recognised as one.

```swift
public func toAnalytical(tolerance: Double = 1e-4) -> Surface?
```

Recognises planes, cylinders, cones, spheres, and tori within the given tolerance. Returns the analytic surface type. Useful after fitting operations that produce a B-spline approximation of a canonical shape.

- **Parameters:** `tolerance` — recognition tolerance (default `1e-4`).
- **Returns:** The equivalent analytic `Surface`, or `nil` if the surface is not recognisable as a standard type.
- **OCCT:** `GeomConvert_ApproxSurface` recognition path (canonical-surface detection).
- **Example:**
  ```swift
  if let bspSphere = someFittedSurface.toAnalytical() {
      // bspSphere is now a Geom_SphericalSurface if recognised
  }
  ```

---

## Surface-Surface Intersection (v0.35.0)

---

### `intersectionCurves(with:tolerance:)`

Computes intersection curves between this surface and another.

```swift
public func intersectionCurves(with other: Surface, tolerance: Double = 1e-6) -> [Curve3D]
```

Uses `GeomAPI_IntSS` with a fixed internal cap of 64 curves. This is the v0.35.0 counterpart to `intersections(with:tolerance:maxCurves:)`; both call the same underlying algorithm but with different buffer sizes and naming.

- **Parameters:** `other` — the surface to intersect with; `tolerance` — intersection tolerance (default `1e-6`).
- **Returns:** Array of 3D intersection curves (empty if no intersection).
- **OCCT:** `GeomAPI_IntSS`.
- **Example:**
  ```swift
  if let cyl1 = Surface.cylinder(radius: 5, height: 20),
     let cyl2 = Surface.cylinder(radius: 5, height: 20) {
      let curves = cyl1.intersectionCurves(with: cyl2)
  }
  ```

---

## Curve-Surface Intersection (v0.35.0)

---

### `CurveSurfaceIntersection`

Public struct representing a single curve–surface intersection point.

```swift
public struct CurveSurfaceIntersection: Sendable {
    public var point:           SIMD3<Double>
    public var surfaceUV:       SIMD2<Double>
    public var curveParameter:  Double
}
```

- `point` — 3D coordinates of the intersection.
- `surfaceUV` — surface UV parameters at the intersection.
- `curveParameter` — parameter along the curve at the intersection.

---

### `Curve3D.intersections(with:)`

Computes the intersection points between a curve and a surface.

```swift
// declared in extension Curve3D:
public func intersections(with surface: Surface) -> [CurveSurfaceIntersection]
```

Returns all intersection points (tangent and transverse) up to an internal cap of 64. Returns an empty array when the curve does not pierce the surface.

- **Parameters:** `surface` — the surface to intersect with.
- **Returns:** Array of `CurveSurfaceIntersection` values (may be empty).
- **OCCT:** `GeomAPI_IntCS`.
- **Example:**
  ```swift
  if let line = Curve3D.line(from: SIMD3(0, 0, -10), to: SIMD3(0, 0, 10)),
     let srf  = Surface.sphere(radius: 5) {
      let hits = line.intersections(with: srf)
      // hits.count == 2 for a line passing through a sphere
      for h in hits {
          print(h.point, h.curveParameter)
      }
  }
  ```

---

## Batch Evaluation (v0.29.0)

---

### `evaluateGrid(uParameters:vParameters:)`

Evaluates the surface at a grid of UV parameters in a single call.

```swift
public func evaluateGrid(uParameters: [Double], vParameters: [Double]) -> [[SIMD3<Double>]]
```

Returns a 2D array indexed `[vIndex][uIndex]` — V is the outer index. This is significantly faster than individual `point(atU:v:)` calls when building a dense mesh or sampling a parameter grid.

- **Parameters:** `uParameters` — array of U parameter values; `vParameters` — array of V parameter values.
- **Returns:** 2D array of 3D positions of size `[vParameters.count][uParameters.count]`, or empty if either input is empty or the evaluated count mismatches.
- **OCCT:** `Geom_Surface::D0` called per grid point via the bridge buffer.
- **Example:**
  ```swift
  if let srf = Surface.sphere(radius: 5) {
      let us = stride(from: 0.0, through: Double.pi * 2, by: 0.1).map { $0 }
      let vs = stride(from: -.pi / 2, through: .pi / 2, by: 0.1).map { $0 }
      let grid = srf.evaluateGrid(uParameters: us, vParameters: vs)
      // grid[i][j] is the 3D point at (us[j], vs[i])
  }
  ```
- **Note:** Result is empty (not a partial result) if the internal buffer fill count does not match `uParameters.count × vParameters.count`.
