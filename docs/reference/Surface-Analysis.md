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
- **Returns:** Gaussian curvature value (signed); `0` if `GeomLProp_SLProps::IsCurvatureDefined()` is false at that point (a cone apex, a sphere pole).
- **OCCT:** `GeomLProp_SLProps::GaussianCurvature` (order 2, `Precision::Confusion()`).
- **See also:** [`curvatures(u:v:)`](Surface.md) returns this and `meanCurvature(atU:v:)` together from a single evaluation. All three share one `GeomLProp_SLProps` construction, so they agree exactly — including on whether curvature is defined at all (#405).
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
- **Returns:** Mean curvature value (signed); `0` if `GeomLProp_SLProps::IsCurvatureDefined()` is false at that point.
- **OCCT:** `GeomLProp_SLProps::MeanCurvature` (order 2, `Precision::Confusion()`).
- **See also:** [`curvatures(u:v:)`](Surface.md) returns this and `gaussianCurvature(atU:v:)` together from a single evaluation, sharing one `GeomLProp_SLProps` construction (#405).
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
    public let order: ContinuityClass
    public let measured: Set<ContinuityClass>
    public let c0Value: Double
    public let g1Angle: Double
    public let c1UAngle: Double
    public let c1VAngle: Double
    public let flags: Int
    public func holds(_ continuity: ContinuityClass) -> Bool?
    public var isC0: Bool? { holds(.c0) }
    public var isG1: Bool? { holds(.g1) }
    public var isC1: Bool? { holds(.c1) }
    public var isG2: Bool? { holds(.g2) }
    public var isC2: Bool? { holds(.c2) }
}
```

- `order` — the class the junction was analysed at, i.e. the request after saturation. `LocalAnalysis_SurfaceContinuity::ContinuityStatus()` echoes its constructor argument, so this is never a finding; it exists to tell you where a saturated request landed.
- `measured` — the classes this `order` actually evaluated. Each order runs one branch: `.c0` measures C0; `.g1` measures C0 and G1; `.c1` measures C0 and C1; `.g2` measures C0, G1 and G2; `.c2` measures C0, C1 and C2. **No order measures all five.**
- `c0Value` — positional gap distance at the junction.
- `g1Angle` — angle between surface normals at the junction (radians), or `-1` if G1 was not measured or does not hold.
- `c1UAngle` / `c1VAngle` — angles between first derivatives in U and V directions, or `-1`.
- `flags` — bitmask: bit 0 = C0, bit 1 = G1, bit 2 = C1, bit 3 = G2, bit 4 = C2, masked to `measured`.
- `holds(_:)` returns `nil` for a class outside `measured`, which is what separates "does not hold" from "never asked". Prefer it to `flags`.

> Before #495 the `is*` helpers were non-optional and read straight off the bitmask, so a class the order never computed answered `true` from an uninitialised member — a 90° crease analysed at `.c0` reported `isC2 == true`, with `c2Angle == 0.0` alongside it.

---

### `continuityWith(_:u1:v1:u2:v2:order:)`

Analyses the continuity between this surface at `(u1, v1)` and another surface at `(u2, v2)`.

```swift
public func continuityWith(
    _ other: Surface,
    u1: Double, v1: Double,
    u2: Double, v2: Double,
    order: ContinuityClass = .c2
) -> ContinuityAnalysis?
```

`order` **selects** the analysis rather than capping it — see `measured` above. `.c2` is the strictest class `LocalAnalysis_SurfaceContinuity` implements, so `.c3` and `.cN` saturate to it.

- **Parameters:** `other` — the second surface; `u1`/`v1` — parameters on this surface; `u2`/`v2` — parameters on `other`; `order` — the class to measure (default `.c2`).
- **Returns:** `ContinuityAnalysis`, or `nil` if `LocalAnalysis_SurfaceContinuity` fails.
- **OCCT:** `LocalAnalysis_SurfaceContinuity`.
- **Note:** the `.c2` branch needs a non-zero second derivative in both U and V on both surfaces. A plane has none in either direction and a cylinder has none along its axis, so the default order returns `nil` for both — ask for `.c1` or `.g1` on planar or ruled geometry.
- **Example:**
  ```swift
  // Tangency is its own question: the .c2 default never computes G1.
  if let a = s1.continuityWith(s2, u1: 0, v1: 0, u2: 0, v2: 0, order: .g1) {
      print(a.holds(.g1), a.g1Angle)   // Optional(true), 0.0
      print(a.holds(.c1))              // nil — .g1 does not measure C1
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

### `uvFromIso(_:precision:)` (#266)

Refine a `(u, v)` for a 3D point by projecting it onto the surface's iso-lines — more robust near
degeneracies than plain `projectPoint(_:)`. Returns the parameters and the 3D gap (a very large gap
means the projection effectively failed).

```swift
public func uvFromIso(_ point: SIMD3<Double>, precision: Double = 1e-6)
    -> (u: Double, v: Double, gap: Double)?
```

- **OCCT:** `ShapeAnalysis_Surface::UVFromIso`.

---

### `singularity(_:precision:)` (#266)

Full detail of singularity `index` (**0-based**, `0..<singularityCount(...)`) — the pole point, the
degenerate iso-line's 2D endpoints + parameters, and its direction. Complements
`singularityCount(tolerance:)` (count only).

```swift
public struct Singularity: Sendable {
    public let point: SIMD3<Double>       // 3D pole
    public let firstUV, lastUV: SIMD2<Double>
    public let firstParameter, lastParameter: Double
    public let isUIso: Bool               // degenerate iso is U-iso (else V-iso)
    public let precision: Double
}
public func singularity(_ index: Int, precision: Double = 1e-6) -> Singularity?
```

- **OCCT:** `ShapeAnalysis_Surface::Singularity`.
- **Example:**
  ```swift
  if let apex = cone.singularity(0) { print("apex at", apex.point) }
  ```

---

### `projectDegenerated(_:neighbour:precision:)` (#266)

Resolve the indeterminate 2D coordinate of a point lying in a singularity (e.g. a cone apex), taking
the well-defined coordinate from a `neighbour` 2D point.

```swift
public func projectDegenerated(_ point: SIMD3<Double>, neighbour: SIMD2<Double>,
                               precision: Double = 1e-6) -> SIMD2<Double>?
```

- **OCCT:** `ShapeAnalysis_Surface::ProjectDegenerated`.

---

### `projectPoint(_:uDomain:vDomain:precision:)` (#266)

Project a 3D point onto the surface **restricted to a U/V domain** (`SetDomain`) — disambiguates
projection on periodic or self-overlapping surfaces. Returns the `(u, v)` and the 3D gap.

```swift
public func projectPoint(_ point: SIMD3<Double>, uDomain: ClosedRange<Double>,
                         vDomain: ClosedRange<Double>, precision: Double = 1e-6)
    -> (uv: SIMD2<Double>, gap: Double)?
```

- **OCCT:** `ShapeAnalysis_Surface::SetDomain` + `ValueOfUV` + `Gap`.

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
public func evaluateGrid(uParameters: [Double], vParameters: [Double]) -> SurfaceGrid
```

Returns a `SurfaceGrid` (see [Surface.md](Surface.md#surfacegrid)) indexed `.at(u:v:)` — the same
type `drawMesh(uCount:vCount:)` returns, so the two can never disagree on index order the way
their old raw `[[SIMD3<Double>]]` returns could ([#404](https://github.com/SecondMouseAU/OCCTSwift/issues/404)).
This is significantly faster than individual `point(atU:v:)` calls when building a dense mesh or
sampling a parameter grid.

- **Parameters:** `uParameters` — array of U parameter values; `vParameters` — array of V parameter values.
- **Returns:** A `SurfaceGrid` of size `uParameters.count × vParameters.count`, or an empty grid if
  either input is empty or the evaluated count mismatches.
- **OCCT:** `GeomGridEval_Surface::EvaluateGrid` via `OCCTSurfaceEvaluateGrid`.
- **Example:**
  ```swift
  if let srf = Surface.sphere(radius: 5) {
      let us = stride(from: 0.0, through: Double.pi * 2, by: 0.1).map { $0 }
      let vs = stride(from: -.pi / 2, through: .pi / 2, by: 0.1).map { $0 }
      let grid = srf.evaluateGrid(uParameters: us, vParameters: vs)
      let p = grid.at(u: 2, v: 0)  // point at (us[2], vs[0])
  }
  ```
- **Note:** Result is empty (not a partial result) if the internal buffer fill count does not match `uParameters.count × vParameters.count`.

---

### `evaluateGridD1(uParameters:vParameters:)`

Evaluates the surface *and its first partial derivatives* at a grid of UV parameters in a single
call, the D1 counterpart of `evaluateGrid`, using the same batch `GeomGridEval_Surface` evaluator
rather than one `evalD1(u:v:)` call per sample.

```swift
public func evaluateGridD1(uParameters: [Double], vParameters: [Double]) -> SurfaceGridD1
```

Returns a `SurfaceGridD1` (see [Surface.md](Surface.md#surfacegridd1)) indexed `.at(u:v:)`. Added
by [#486](https://github.com/SecondMouseAU/OCCTSwift/issues/486), which finished for the D1 path
what #404 had done for D0: the deprecated `gridEvalD1(uParams:vParams:)` returned a flat
`[(point:, d1u:, d1v:)]` array with no stated major order, over a bridge function whose D0 sibling
disagreed with `evaluateGrid` about exactly that.

- **Parameters:** `uParameters`: array of U parameter values; `vParameters`: array of V parameter values.
- **Returns:** A `SurfaceGridD1` of size `uParameters.count × vParameters.count`, or an empty grid
  if either input is empty or the evaluation fails.
- **OCCT:** `GeomGridEval_Surface::EvaluateGridD1` via `OCCTSurfaceEvaluateGridD1`.
- **Example:**
  ```swift
  if let srf = Surface.sphere(radius: 5) {
      let grid = srf.evaluateGridD1(uParameters: [0, 1, 2], vParameters: [0, 0.5])
      let sample = grid.at(u: 1, v: 0)
      let normal = simd_normalize(simd_cross(sample.d1u, sample.d1v))
  }
  ```
