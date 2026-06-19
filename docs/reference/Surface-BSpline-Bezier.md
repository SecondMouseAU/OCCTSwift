---
title: Surface — BSpline & Bezier
parent: API Reference
---

# Surface — BSpline & Bezier

This page documents the freeform B-spline and Bézier pole, knot, weight, and degree accessors/mutators on `Surface`, as well as the utility methods for local evaluation, iso-curve extraction, and patch decomposition. See the main [Surface](Surface.md) page for construction, evaluation, and all other sections.

## Topics

- [BSpline/Bezier Queries](#bsplinebezier-queries) · [BSpline Deep Methods (v0.125.0)](#v01250-bspline-surface-deep-method-completion) · [Bezier Deep Methods (v0.125.0)](#v01250-bezier-surface-deep-method-completion) · [BSpline Completions (v0.126.0)](#bspline-surface-completions-v01260) · [Bezier Completions (v0.126.0)](#bezier-surface-completions-v01260) · [Bezier Completions (v0.127.0)](#v01270-bezier-surface-completions) · [Bezier Completions (v0.129.0)](#v01290-bezier-surface-completions) · [Surface to Bezier Patches (v0.36.0)](#surface-to-bezier-patches-v0360) · [BSpline Bezier Patch Grid (v0.40.0)](#bspline-bezier-patch-grid-v0400)

---

## BSpline/Bezier Queries

Generic pole, degree, and grid-count accessors that work on both `Geom_BSplineSurface` and `Geom_BezierSurface`. Return 0 / empty for surfaces of other types.

---

### `uPoleCount`

Number of control points in the U direction.

```swift
public var uPoleCount: Int { get }
```

- **Returns:** Pole count in U, or 0 if the surface is not BSpline/Bezier.
- **OCCT:** `Geom_BSplineSurface::NbUPoles` / `Geom_BezierSurface::NbUPoles`.
- **Example:**
  ```swift
  let n = surface.uPoleCount
  ```

---

### `vPoleCount`

Number of control points in the V direction.

```swift
public var vPoleCount: Int { get }
```

- **Returns:** Pole count in V, or 0 if the surface is not BSpline/Bezier.
- **OCCT:** `Geom_BSplineSurface::NbVPoles` / `Geom_BezierSurface::NbVPoles`.
- **Example:**
  ```swift
  let n = surface.vPoleCount
  ```

---

### `poles`

All control points as a 2D row-major array `[uRow][vCol]`.

```swift
public var poles: [[SIMD3<Double>]] { get }
```

- **Returns:** `[[SIMD3<Double>]]` of size `uPoleCount × vPoleCount`, or `[]` if not BSpline/Bezier or if the internal buffer read fails.
- **OCCT:** `Geom_BSplineSurface::Poles` / `Geom_BezierSurface::Poles` — row/column iteration over the internal `TColgp_Array2OfPnt`.
- **Example:**
  ```swift
  for (i, row) in surface.poles.enumerated() {
      for (j, pt) in row.enumerated() {
          print("P[\(i)][\(j)] =", pt)
      }
  }
  ```

---

### `uDegree`

Polynomial degree in the U direction.

```swift
public var uDegree: Int { get }
```

- **Returns:** Degree in U, or 0 for non-spline surfaces.
- **OCCT:** `Geom_BSplineSurface::UDegree` / `Geom_BezierSurface::UDegree`.
- **Example:**
  ```swift
  let deg = surface.uDegree  // e.g. 3 for cubic
  ```

---

### `vDegree`

Polynomial degree in the V direction.

```swift
public var vDegree: Int { get }
```

- **Returns:** Degree in V, or 0 for non-spline surfaces.
- **OCCT:** `Geom_BSplineSurface::VDegree` / `Geom_BezierSurface::VDegree`.
- **Example:**
  ```swift
  let deg = surface.vDegree
  ```

---

## v0.125.0: BSpline Surface Deep Method Completion

Low-level evaluation methods on `Geom_BSplineSurface` restricted to a specific knot span. All knot-span indices are 1-based and obtained from `bsplineLocateU`/`bsplineLocateV`.

---

### `bsplineLocalD0(u:v:fromUK1:toUK2:fromVK1:toVK2:)`

Point evaluation restricted to a knot span.

```swift
public func bsplineLocalD0(u: Double, v: Double, fromUK1: Int, toUK2: Int,
                            fromVK1: Int, toVK2: Int) -> SIMD3<Double>
```

- **Parameters:** `u`, `v` — parameter values; `fromUK1`/`toUK2` — U knot span indices (1-based); `fromVK1`/`toVK2` — V knot span indices (1-based).
- **Returns:** Point on the surface at `(u, v)`. Returns `SIMD3.zero` if the surface is not BSpline or evaluation fails.
- **OCCT:** `Geom_BSplineSurface::LocalD0`.
- **Example:**
  ```swift
  let (uk1, uk2) = surface.bsplineLocateU(u: 0.5, paramTol: 1e-9)
  let (vk1, vk2) = surface.bsplineLocateV(v: 0.5, paramTol: 1e-9)
  let pt = surface.bsplineLocalD0(u: 0.5, v: 0.5,
                                   fromUK1: uk1, toUK2: uk2,
                                   fromVK1: vk1, toVK2: vk2)
  ```

---

### `bsplineLocalD1(u:v:fromUK1:toUK2:fromVK1:toVK2:)`

Point and first partial derivatives restricted to a knot span.

```swift
public func bsplineLocalD1(u: Double, v: Double, fromUK1: Int, toUK2: Int,
                            fromVK1: Int, toVK2: Int)
    -> (point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>)
```

- **Parameters:** As `bsplineLocalD0`.
- **Returns:** Tuple of the surface point, dS/dU, and dS/dV. All components are zero-vectors on failure.
- **OCCT:** `Geom_BSplineSurface::LocalD1`.
- **Example:**
  ```swift
  let r = surface.bsplineLocalD1(u: 0.5, v: 0.5,
                                  fromUK1: uk1, toUK2: uk2,
                                  fromVK1: vk1, toVK2: vk2)
  print(r.point, r.d1u, r.d1v)
  ```

---

### `bsplineLocalD2(u:v:fromUK1:toUK2:fromVK1:toVK2:)`

Point, first, and second partial derivatives restricted to a knot span.

```swift
public func bsplineLocalD2(u: Double, v: Double, fromUK1: Int, toUK2: Int,
                            fromVK1: Int, toVK2: Int)
    -> (point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>,
        d2u: SIMD3<Double>, d2v: SIMD3<Double>, d2uv: SIMD3<Double>)
```

- **Returns:** Point plus d/dU, d/dV, d²/dU², d²/dV², d²/dUdV. All zero on failure.
- **OCCT:** `Geom_BSplineSurface::LocalD2`.
- **Example:**
  ```swift
  let r = surface.bsplineLocalD2(u: 0.5, v: 0.5,
                                  fromUK1: uk1, toUK2: uk2,
                                  fromVK1: vk1, toVK2: vk2)
  ```

---

### `bsplineLocalD3(u:v:fromUK1:toUK2:fromVK1:toVK2:)`

Point through third partial derivatives restricted to a knot span.

```swift
public func bsplineLocalD3(u: Double, v: Double, fromUK1: Int, toUK2: Int,
                            fromVK1: Int, toVK2: Int)
    -> (point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>,
        d2u: SIMD3<Double>, d2v: SIMD3<Double>, d2uv: SIMD3<Double>,
        d3u: SIMD3<Double>, d3v: SIMD3<Double>, d3uuv: SIMD3<Double>, d3uvv: SIMD3<Double>)
```

- **Returns:** 10-element tuple covering point and all partial derivatives through order 3. All zero on failure.
- **OCCT:** `Geom_BSplineSurface::LocalD3`.
- **Example:**
  ```swift
  let r = surface.bsplineLocalD3(u: 0.5, v: 0.5,
                                  fromUK1: uk1, toUK2: uk2,
                                  fromVK1: vk1, toVK2: vk2)
  ```

---

### `bsplineLocalDN(u:v:fromUK1:toUK2:fromVK1:toVK2:nu:nv:)`

Arbitrary-order partial derivative restricted to a knot span.

```swift
public func bsplineLocalDN(u: Double, v: Double, fromUK1: Int, toUK2: Int,
                            fromVK1: Int, toVK2: Int, nu: Int, nv: Int) -> SIMD3<Double>
```

- **Parameters:** `nu` — U derivative order; `nv` — V derivative order.
- **Returns:** The `(nu, nv)` partial derivative vector. Zero on failure.
- **OCCT:** `Geom_BSplineSurface::LocalDN`.
- **Example:**
  ```swift
  let d = surface.bsplineLocalDN(u: 0.5, v: 0.5,
                                  fromUK1: uk1, toUK2: uk2,
                                  fromVK1: vk1, toVK2: vk2, nu: 2, nv: 1)
  ```

---

### `bsplineLocalValue(u:v:fromUK1:toUK2:fromVK1:toVK2:)`

Point evaluation using `LocalValue` (alias of `LocalD0` in most OCCT versions).

```swift
public func bsplineLocalValue(u: Double, v: Double, fromUK1: Int, toUK2: Int,
                               fromVK1: Int, toVK2: Int) -> SIMD3<Double>
```

- **Returns:** Point on the surface at `(u, v)` within the knot span. Zero on failure.
- **OCCT:** `Geom_BSplineSurface::LocalValue`.
- **Example:**
  ```swift
  let pt = surface.bsplineLocalValue(u: 0.5, v: 0.5,
                                      fromUK1: uk1, toUK2: uk2,
                                      fromVK1: vk1, toVK2: vk2)
  ```

---

### `bsplineUIso(u:)`

Extracts the U isoparametric curve at parameter `u` from a BSpline surface.

```swift
public func bsplineUIso(u: Double) -> Curve3D?
```

- **Parameters:** `u` — U parameter value within the surface's U domain.
- **Returns:** The iso-curve as a `Curve3D`, or `nil` if the surface is not BSpline or extraction fails.
- **OCCT:** `Geom_BSplineSurface::UIso`.
- **Example:**
  ```swift
  if let iso = surface.bsplineUIso(u: 0.5) {
      let pt = iso.point(at: 0.0)
  }
  ```

---

### `bsplineVIso(v:)`

Extracts the V isoparametric curve at parameter `v` from a BSpline surface.

```swift
public func bsplineVIso(v: Double) -> Curve3D?
```

- **Parameters:** `v` — V parameter value within the surface's V domain.
- **Returns:** The iso-curve as a `Curve3D`, or `nil` on failure.
- **OCCT:** `Geom_BSplineSurface::VIso`.
- **Example:**
  ```swift
  if let iso = surface.bsplineVIso(v: 0.5) {
      let pt = iso.point(at: 0.0)
  }
  ```

---

### `bsplineLocateU(u:paramTol:)`

Finds the knot span indices bracketing U parameter `u`.

```swift
public func bsplineLocateU(u: Double, paramTol: Double) -> (i1: Int, i2: Int)
```

- **Parameters:** `u` — parameter value; `paramTol` — tolerance for knot coincidence.
- **Returns:** `(i1, i2)` — 1-based knot indices such that `UKnot(i1) ≤ u ≤ UKnot(i2)`. Both are 0 on failure.
- **OCCT:** `Geom_BSplineSurface::LocateU`.
- **Example:**
  ```swift
  let (i1, i2) = surface.bsplineLocateU(u: 0.5, paramTol: 1e-9)
  ```

---

### `bsplineLocateV(v:paramTol:)`

Finds the knot span indices bracketing V parameter `v`.

```swift
public func bsplineLocateV(v: Double, paramTol: Double) -> (i1: Int, i2: Int)
```

- **Parameters:** `v` — parameter value; `paramTol` — tolerance for knot coincidence.
- **Returns:** `(i1, i2)` 1-based knot indices. Both 0 on failure.
- **OCCT:** `Geom_BSplineSurface::LocateV`.
- **Example:**
  ```swift
  let (j1, j2) = surface.bsplineLocateV(v: 0.5, paramTol: 1e-9)
  ```

---

### `bsplineUKnot(index:)`

Returns the U knot value at the given 1-based index.

```swift
public func bsplineUKnot(index: Int) -> Double
```

- **Parameters:** `index` — 1-based knot index.
- **Returns:** Knot value, or 0.0 on failure.
- **OCCT:** `Geom_BSplineSurface::UKnot`.
- **Example:**
  ```swift
  let k = surface.bsplineUKnot(index: 1)
  ```

---

### `bsplineVKnot(index:)`

Returns the V knot value at the given 1-based index.

```swift
public func bsplineVKnot(index: Int) -> Double
```

- **Parameters:** `index` — 1-based knot index.
- **Returns:** Knot value, or 0.0 on failure.
- **OCCT:** `Geom_BSplineSurface::VKnot`.
- **Example:**
  ```swift
  let k = surface.bsplineVKnot(index: 1)
  ```

---

### `bsplineUMultiplicity(index:)`

Returns the U knot multiplicity at the given 1-based index.

```swift
public func bsplineUMultiplicity(index: Int) -> Int
```

- **Parameters:** `index` — 1-based knot index.
- **Returns:** Multiplicity (≥ 1), or 0 on failure.
- **OCCT:** `Geom_BSplineSurface::UMultiplicity`.
- **Example:**
  ```swift
  let m = surface.bsplineUMultiplicity(index: 1)
  ```

---

### `bsplineVMultiplicity(index:)`

Returns the V knot multiplicity at the given 1-based index.

```swift
public func bsplineVMultiplicity(index: Int) -> Int
```

- **Parameters:** `index` — 1-based knot index.
- **Returns:** Multiplicity (≥ 1), or 0 on failure.
- **OCCT:** `Geom_BSplineSurface::VMultiplicity`.
- **Example:**
  ```swift
  let m = surface.bsplineVMultiplicity(index: 1)
  ```

---

### `bsplineUKnotDistribution`

Knot distribution type in the U direction.

```swift
public var bsplineUKnotDistribution: Int { get }
```

- **Returns:** Integer code: 0 = NonUniform, 1 = Uniform, 2 = QuasiUniform, 3 = PiecewiseBezier. 0 also on failure.
- **OCCT:** `Geom_BSplineSurface::UKnotDistribution` — returns a `GeomAbs_BSplKnotDistribution` enum cast to `Int32`.
- **Example:**
  ```swift
  let dist = surface.bsplineUKnotDistribution  // 3 = PiecewiseBezier
  ```

---

### `bsplineVKnotDistribution`

Knot distribution type in the V direction.

```swift
public var bsplineVKnotDistribution: Int { get }
```

- **Returns:** Same codes as `bsplineUKnotDistribution`.
- **OCCT:** `Geom_BSplineSurface::VKnotDistribution`.
- **Example:**
  ```swift
  let dist = surface.bsplineVKnotDistribution
  ```

---

### `bsplinePoles`

All control points of a BSpline surface as a flat array in row-major order.

```swift
public var bsplinePoles: [SIMD3<Double>] { get }
```

Iterates the internal `TColgp_Array2OfPnt` in (U-row, V-col) order. Total count = `NbUPoles × NbVPoles`.

- **Returns:** Flat array of `uPoleCount × vPoleCount` points, or `[]` if not BSpline or pole count is 0.
- **OCCT:** `Geom_BSplineSurface::Poles`.
- **Example:**
  ```swift
  let flat = surface.bsplinePoles
  ```

---

### `bsplineBounds`

Parameter domain of a BSpline surface.

```swift
public var bsplineBounds: (u1: Double, u2: Double, v1: Double, v2: Double) { get }
```

- **Returns:** The `(u1, u2, v1, v2)` parameter range. All zeros on failure.
- **OCCT:** `Geom_BSplineSurface::Bounds`.
- **Example:**
  ```swift
  let b = surface.bsplineBounds
  // e.g. (0.0, 1.0, 0.0, 1.0)
  ```

---

### `bsplineIsUClosed`

Whether the BSpline surface is closed in U.

```swift
public var bsplineIsUClosed: Bool { get }
```

- **OCCT:** `Geom_BSplineSurface::IsUClosed`.
- **Example:**
  ```swift
  if surface.bsplineIsUClosed { /* cylindrical topology */ }
  ```

---

### `bsplineIsVClosed`

Whether the BSpline surface is closed in V.

```swift
public var bsplineIsVClosed: Bool { get }
```

- **OCCT:** `Geom_BSplineSurface::IsVClosed`.
- **Example:**
  ```swift
  if surface.bsplineIsVClosed { }
  ```

---

## v0.125.0: Bezier Surface Deep Method Completion

---

### `bezierUIso(u:)`

Extracts the U isoparametric curve at `u` from a Bezier surface.

```swift
public func bezierUIso(u: Double) -> Curve3D?
```

- **Parameters:** `u` — U parameter (domain `[0, 1]` for Bezier surfaces).
- **Returns:** Iso-curve as `Curve3D`, or `nil` on failure.
- **OCCT:** `Geom_BezierSurface::UIso`.
- **Example:**
  ```swift
  if let iso = surface.bezierUIso(u: 0.5) { }
  ```

---

### `bezierVIso(v:)`

Extracts the V isoparametric curve at `v` from a Bezier surface.

```swift
public func bezierVIso(v: Double) -> Curve3D?
```

- **Parameters:** `v` — V parameter (domain `[0, 1]`).
- **Returns:** Iso-curve as `Curve3D`, or `nil` on failure.
- **OCCT:** `Geom_BezierSurface::VIso`.
- **Example:**
  ```swift
  if let iso = surface.bezierVIso(v: 0.5) { }
  ```

---

### `bezierIsUClosed`

Whether the Bezier surface is closed in U.

```swift
public var bezierIsUClosed: Bool { get }
```

- **OCCT:** `Geom_BezierSurface::IsUClosed`.
- **Example:**
  ```swift
  let closed = surface.bezierIsUClosed
  ```

---

### `bezierIsVClosed`

Whether the Bezier surface is closed in V.

```swift
public var bezierIsVClosed: Bool { get }
```

- **OCCT:** `Geom_BezierSurface::IsVClosed`.
- **Example:**
  ```swift
  let closed = surface.bezierIsVClosed
  ```

---

### `bezierIsUPeriodic`

Whether the Bezier surface is periodic in U.

```swift
public var bezierIsUPeriodic: Bool { get }
```

- **OCCT:** `Geom_BezierSurface::IsUPeriodic`. Bezier surfaces are never periodic; always returns `false`.
- **Example:**
  ```swift
  let p = surface.bezierIsUPeriodic  // always false
  ```

---

### `bezierIsVPeriodic`

Whether the Bezier surface is periodic in V.

```swift
public var bezierIsVPeriodic: Bool { get }
```

- **OCCT:** `Geom_BezierSurface::IsVPeriodic`. Always `false` for Bezier surfaces.
- **Example:**
  ```swift
  let p = surface.bezierIsVPeriodic
  ```

---

### `bezierContinuity`

Continuity class of the Bezier surface.

```swift
public var bezierContinuity: Int { get }
```

- **Returns:** Integer code: 0 = C0, 1 = C1, 2 = C2, 3 = C3, 4 = CN. Bezier surfaces are CN by construction (returns 4).
- **OCCT:** `Geom_BezierSurface::Continuity`.
- **Example:**
  ```swift
  let c = surface.bezierContinuity  // 4 (CN)
  ```

---

### `bezierIsCNu(_:)`

Whether the Bezier surface is at least CN-continuous in U.

```swift
public func bezierIsCNu(_ n: Int) -> Bool
```

- **Parameters:** `n` — desired continuity order.
- **Returns:** `true` for any `n` (Bezier surfaces are infinitely differentiable).
- **OCCT:** `Geom_BezierSurface::IsCNu`.
- **Example:**
  ```swift
  let ok = surface.bezierIsCNu(3)  // true
  ```

---

### `bezierIsCNv(_:)`

Whether the Bezier surface is at least CN-continuous in V.

```swift
public func bezierIsCNv(_ n: Int) -> Bool
```

- **Parameters:** `n` — desired continuity order.
- **Returns:** `true` for any `n`.
- **OCCT:** `Geom_BezierSurface::IsCNv`.
- **Example:**
  ```swift
  let ok = surface.bezierIsCNv(2)  // true
  ```

---

### `bezierPoles`

All control points of a Bezier surface as a flat row-major array.

```swift
public var bezierPoles: [SIMD3<Double>] { get }
```

- **Returns:** Flat array of `bezierNbUPoles × bezierNbVPoles` points, or `[]` on failure.
- **OCCT:** `Geom_BezierSurface::Poles`.
- **Example:**
  ```swift
  let pts = surface.bezierPoles
  ```

---

### `bezierWeights`

All weights of a rational Bezier surface as a flat row-major array.

```swift
public var bezierWeights: [Double]? { get }
```

- **Returns:** Flat array of `bezierNbUPoles × bezierNbVPoles` weights, or `nil` if the surface is non-rational or not Bezier.
- **OCCT:** `Geom_BezierSurface::Weights`.
- **Example:**
  ```swift
  if let w = surface.bezierWeights {
      print("rational, first weight:", w[0])
  }
  ```

---

### `bezierBounds`

Parameter domain of a Bezier surface.

```swift
public var bezierBounds: (u1: Double, u2: Double, v1: Double, v2: Double) { get }
```

- **Returns:** `(0.0, 1.0, 0.0, 1.0)` for standard Bezier surfaces. All zeros on failure.
- **OCCT:** `Geom_BezierSurface::Bounds`.
- **Example:**
  ```swift
  let b = surface.bezierBounds
  ```

---

### `bezierNbUPoles`

Number of U poles (rows) for a Bezier surface.

```swift
public var bezierNbUPoles: Int { get }
```

- **OCCT:** `Geom_BezierSurface::NbUPoles`.
- **Example:**
  ```swift
  let n = surface.bezierNbUPoles
  ```

---

### `bezierNbVPoles`

Number of V poles (columns) for a Bezier surface.

```swift
public var bezierNbVPoles: Int { get }
```

- **OCCT:** `Geom_BezierSurface::NbVPoles`.
- **Example:**
  ```swift
  let n = surface.bezierNbVPoles
  ```

---

### `bezierUDegree`

U degree of a Bezier surface (= `bezierNbUPoles - 1`).

```swift
public var bezierUDegree: Int { get }
```

- **OCCT:** `Geom_BezierSurface::UDegree`.
- **Example:**
  ```swift
  let d = surface.bezierUDegree
  ```

---

### `bezierVDegree`

V degree of a Bezier surface (= `bezierNbVPoles - 1`).

```swift
public var bezierVDegree: Int { get }
```

- **OCCT:** `Geom_BezierSurface::VDegree`.
- **Example:**
  ```swift
  let d = surface.bezierVDegree
  ```

---

## BSpline Surface Completions (v0.126.0)

---

### `bsplineUMultiplicities`

All U knot multiplicities as a flat array.

```swift
public var bsplineUMultiplicities: [Int] { get }
```

- **Returns:** Array of length `NbUKnots`, or `[]` on failure.
- **OCCT:** `Geom_BSplineSurface::UMultiplicity` called per knot index.
- **Example:**
  ```swift
  let mults = surface.bsplineUMultiplicities
  ```

---

### `bsplineVMultiplicities`

All V knot multiplicities as a flat array.

```swift
public var bsplineVMultiplicities: [Int] { get }
```

- **Returns:** Array of length `NbVKnots`, or `[]` on failure.
- **OCCT:** `Geom_BSplineSurface::VMultiplicity` called per knot index.
- **Example:**
  ```swift
  let mults = surface.bsplineVMultiplicities
  ```

---

### `bsplineUReverse()`

Reverses the U parameter direction of the BSpline surface in place.

```swift
@discardableResult
public func bsplineUReverse() -> Bool
```

- **Returns:** `true` on success, `false` if the surface is not BSpline or the call throws.
- **OCCT:** `Geom_BSplineSurface::UReverse`.
- **Example:**
  ```swift
  surface.bsplineUReverse()
  ```

---

### `bsplineVReverse()`

Reverses the V parameter direction of the BSpline surface in place.

```swift
@discardableResult
public func bsplineVReverse() -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `Geom_BSplineSurface::VReverse`.
- **Example:**
  ```swift
  surface.bsplineVReverse()
  ```

---

### `bsplinePeriodicNormalization(u:v:)`

Normalises U, V parameters for a periodic BSpline surface (maps them into the fundamental period).

```swift
public func bsplinePeriodicNormalization(u: inout Double, v: inout Double) -> Bool
```

- **Parameters:** `u`, `v` — parameter values; modified in place.
- **Returns:** `true` on success, `false` if the surface is not BSpline or the call throws.
- **OCCT:** `Geom_BSplineSurface::PeriodicNormalization`.
- **Example:**
  ```swift
  var u = 3.5, v = -0.2
  surface.bsplinePeriodicNormalization(u: &u, v: &v)
  ```

---

## Bezier Surface Completions (v0.126.0)

---

### `bezierInsertPoleColAfter(_:poles:)`

Inserts a new column of poles after the given column index in a Bezier surface.

```swift
@discardableResult
public func bezierInsertPoleColAfter(_ colIndex: Int, poles: [SIMD3<Double>]) -> Bool
```

- **Parameters:** `colIndex` — 1-based column index after which to insert; `poles` — new pole column (`poles.count` must equal `bezierNbUPoles`).
- **Returns:** `true` on success.
- **OCCT:** `Geom_BezierSurface::InsertPoleColAfter`.
- **Example:**
  ```swift
  let newCol = Array(repeating: SIMD3<Double>(1, 0, 0), count: surface.bezierNbUPoles)
  surface.bezierInsertPoleColAfter(1, poles: newCol)
  ```

---

### `bezierInsertPoleRowAfter(_:poles:)`

Inserts a new row of poles after the given row index in a Bezier surface.

```swift
@discardableResult
public func bezierInsertPoleRowAfter(_ rowIndex: Int, poles: [SIMD3<Double>]) -> Bool
```

- **Parameters:** `rowIndex` — 1-based row index; `poles` — new pole row (`poles.count` must equal `bezierNbVPoles`).
- **Returns:** `true` on success.
- **OCCT:** `Geom_BezierSurface::InsertPoleRowAfter`.
- **Example:**
  ```swift
  let newRow = Array(repeating: SIMD3<Double>(0, 1, 0), count: surface.bezierNbVPoles)
  surface.bezierInsertPoleRowAfter(1, poles: newRow)
  ```

---

### `bezierRemovePoleCol(_:)`

Removes a column of poles from a Bezier surface (1-based index).

```swift
@discardableResult
public func bezierRemovePoleCol(_ colIndex: Int) -> Bool
```

- **Parameters:** `colIndex` — 1-based column index to remove.
- **Returns:** `true` on success. The surface must have at least 2 columns.
- **OCCT:** `Geom_BezierSurface::RemovePoleCol`.
- **Example:**
  ```swift
  surface.bezierRemovePoleCol(1)
  ```

---

### `bezierRemovePoleRow(_:)`

Removes a row of poles from a Bezier surface (1-based index).

```swift
@discardableResult
public func bezierRemovePoleRow(_ rowIndex: Int) -> Bool
```

- **Parameters:** `rowIndex` — 1-based row index to remove. The surface must have at least 2 rows.
- **Returns:** `true` on success.
- **OCCT:** `Geom_BezierSurface::RemovePoleRow`.
- **Example:**
  ```swift
  surface.bezierRemovePoleRow(1)
  ```

---

### `bezierIncreaseDegree(uDeg:vDeg:)`

Increases the degree of a Bezier surface in U and/or V.

```swift
@discardableResult
public func bezierIncreaseDegree(uDeg: Int, vDeg: Int) -> Bool
```

- **Parameters:** `uDeg` — new U degree (must be ≥ current U degree); `vDeg` — new V degree.
- **Returns:** `true` on success.
- **OCCT:** `Geom_BezierSurface::Increase`.
- **Note:** Degree can only increase, never decrease.
- **Example:**
  ```swift
  surface.bezierIncreaseDegree(uDeg: 4, vDeg: 4)
  ```

---

### `bezierUReverse()`

Reverses the U parameter direction of a Bezier surface in place.

```swift
@discardableResult
public func bezierUReverse() -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `Geom_BezierSurface::UReverse`.
- **Example:**
  ```swift
  surface.bezierUReverse()
  ```

---

### `bezierVReverse()`

Reverses the V parameter direction of a Bezier surface in place.

```swift
@discardableResult
public func bezierVReverse() -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `Geom_BezierSurface::VReverse`.
- **Example:**
  ```swift
  surface.bezierVReverse()
  ```

---

## v0.127.0: Bezier Surface Completions

---

### `bezierSetPoleColWeights(vIndex:poles:weights:)`

Sets a full column of poles with associated weights on a Bezier surface.

```swift
@discardableResult
public func bezierSetPoleColWeights(vIndex: Int, poles: [SIMD3<Double>], weights: [Double]) -> Bool
```

- **Parameters:** `vIndex` — 1-based V (column) index; `poles` — new pole positions (`count == bezierNbUPoles`); `weights` — corresponding weights (same count).
- **Returns:** `true` on success. Returns `false` if `poles.count != weights.count`.
- **OCCT:** `Geom_BezierSurface::SetPoleCol(vIndex, poles, weights)`.
- **Example:**
  ```swift
  let poles = Array(repeating: SIMD3<Double>(0, 0, 1), count: surface.bezierNbUPoles)
  let weights = Array(repeating: 1.0, count: surface.bezierNbUPoles)
  surface.bezierSetPoleColWeights(vIndex: 1, poles: poles, weights: weights)
  ```

---

### `bezierSetPoleRowWeights(uIndex:poles:weights:)`

Sets a full row of poles with associated weights on a Bezier surface.

```swift
@discardableResult
public func bezierSetPoleRowWeights(uIndex: Int, poles: [SIMD3<Double>], weights: [Double]) -> Bool
```

- **Parameters:** `uIndex` — 1-based U (row) index; `poles` — new pole positions (`count == bezierNbVPoles`); `weights` — corresponding weights.
- **Returns:** `true` on success. Returns `false` if counts mismatch.
- **OCCT:** `Geom_BezierSurface::SetPoleRow(uIndex, poles, weights)`.
- **Example:**
  ```swift
  let poles = Array(repeating: SIMD3<Double>(0, 1, 0), count: surface.bezierNbVPoles)
  let weights = Array(repeating: 1.0, count: surface.bezierNbVPoles)
  surface.bezierSetPoleRowWeights(uIndex: 1, poles: poles, weights: weights)
  ```

---

## v0.129.0: Bezier Surface Completions

---

### `bezierInsertPoleColBefore(_:poles:)`

Inserts a new column of poles before the given column index in a Bezier surface.

```swift
@discardableResult
public func bezierInsertPoleColBefore(_ colIndex: Int, poles: [SIMD3<Double>]) -> Bool
```

- **Parameters:** `colIndex` — 1-based column index before which to insert; `poles` — new pole column (`poles.count` must equal `bezierNbUPoles`).
- **Returns:** `true` on success.
- **OCCT:** `Geom_BezierSurface::InsertPoleColBefore`.
- **Example:**
  ```swift
  let newCol = Array(repeating: SIMD3<Double>.zero, count: surface.bezierNbUPoles)
  surface.bezierInsertPoleColBefore(1, poles: newCol)
  ```

---

### `bezierInsertPoleRowBefore(_:poles:)`

Inserts a new row of poles before the given row index in a Bezier surface.

```swift
@discardableResult
public func bezierInsertPoleRowBefore(_ rowIndex: Int, poles: [SIMD3<Double>]) -> Bool
```

- **Parameters:** `rowIndex` — 1-based row index before which to insert; `poles.count` must equal `bezierNbVPoles`.
- **Returns:** `true` on success.
- **OCCT:** `Geom_BezierSurface::InsertPoleRowBefore`.
- **Example:**
  ```swift
  let newRow = Array(repeating: SIMD3<Double>.zero, count: surface.bezierNbVPoles)
  surface.bezierInsertPoleRowBefore(1, poles: newRow)
  ```

---

### `bezierSetPoleCol(vIndex:poles:)`

Sets a column of poles (without changing weights) on a Bezier surface.

```swift
@discardableResult
public func bezierSetPoleCol(vIndex: Int, poles: [SIMD3<Double>]) -> Bool
```

- **Parameters:** `vIndex` — 1-based V (column) index; `poles` — new positions (count must equal `bezierNbUPoles`).
- **Returns:** `true` on success.
- **OCCT:** `Geom_BezierSurface::SetPoleCol(vIndex, poles)`.
- **Example:**
  ```swift
  let col = Array(repeating: SIMD3<Double>(0, 0, 2), count: surface.bezierNbUPoles)
  surface.bezierSetPoleCol(vIndex: 2, poles: col)
  ```

---

### `bezierSetPoleRow(uIndex:poles:)`

Sets a row of poles (without changing weights) on a Bezier surface.

```swift
@discardableResult
public func bezierSetPoleRow(uIndex: Int, poles: [SIMD3<Double>]) -> Bool
```

- **Parameters:** `uIndex` — 1-based U (row) index; `poles` — new positions (count must equal `bezierNbVPoles`).
- **Returns:** `true` on success.
- **OCCT:** `Geom_BezierSurface::SetPoleRow(uIndex, poles)`.
- **Example:**
  ```swift
  let row = Array(repeating: SIMD3<Double>(0, 0, 2), count: surface.bezierNbVPoles)
  surface.bezierSetPoleRow(uIndex: 1, poles: row)
  ```

---

### `bezierSetWeightCol(vIndex:weights:)`

Sets a column of weights on a Bezier surface.

```swift
@discardableResult
public func bezierSetWeightCol(vIndex: Int, weights: [Double]) -> Bool
```

- **Parameters:** `vIndex` — 1-based V (column) index; `weights` — new weight values (count must equal `bezierNbUPoles`).
- **Returns:** `true` on success.
- **OCCT:** `Geom_BezierSurface::SetWeightCol`.
- **Example:**
  ```swift
  let w = Array(repeating: 2.0, count: surface.bezierNbUPoles)
  surface.bezierSetWeightCol(vIndex: 1, weights: w)
  ```

---

### `bezierSetWeightRow(uIndex:weights:)`

Sets a row of weights on a Bezier surface.

```swift
@discardableResult
public func bezierSetWeightRow(uIndex: Int, weights: [Double]) -> Bool
```

- **Parameters:** `uIndex` — 1-based U (row) index; `weights` — new weight values (count must equal `bezierNbVPoles`).
- **Returns:** `true` on success.
- **OCCT:** `Geom_BezierSurface::SetWeightRow`.
- **Example:**
  ```swift
  let w = Array(repeating: 0.5, count: surface.bezierNbVPoles)
  surface.bezierSetWeightRow(uIndex: 2, weights: w)
  ```

---

## Surface to Bezier Patches (v0.36.0)

---

### `toBezierPatches()`

Decomposes this surface into an unordered flat array of Bezier patches.

```swift
public func toBezierPatches() -> [Surface]
```

Converts to BSpline first if necessary (via `GeomConvert::SurfaceToBSplineSurface`), then decomposes into a grid of Bezier patches. The grid is iterated U-major (U varies in the outer loop, V in the inner loop). Up to 256 patches are returned.

- **Returns:** Array of `Surface` objects (each wrapping a `Geom_BezierSurface`), or `[]` if conversion fails.
- **OCCT:** `GeomConvert::SurfaceToBSplineSurface` + `GeomConvert_BSplineSurfaceToBezierSurface::Patch`.
- **Note:** Grid dimensions are not returned. Use `toBezierPatchGrid()` instead when you need `(uCount, vCount)`.
- **Example:**
  ```swift
  let patches = surface.toBezierPatches()
  for patch in patches {
      let poles = patch.bezierPoles
  }
  ```

---

## BSpline Bezier Patch Grid (v0.40.0)

---

### `BezierPatchGrid`

Result type returned by `toBezierPatchGrid()`, describing the decomposed patch layout.

```swift
public struct BezierPatchGrid {
    public let uCount: Int      // Number of patches in U direction
    public let vCount: Int      // Number of patches in V direction
    public let patches: [Surface] // Patches in row-major order (U varies faster)
}
```

Access individual patches with `patches[u * grid.vCount + v]` (0-based).

---

### `toBezierPatchGrid()`

Decomposes this BSpline surface into a structured grid of Bezier patches.

```swift
public func toBezierPatchGrid() -> BezierPatchGrid?
```

Returns the patches together with their U/V grid dimensions. Only works on `Geom_BSplineSurface` instances; returns `nil` for other surface types or on failure. Up to 256 patches are supported.

- **Returns:** `BezierPatchGrid` with `uCount`, `vCount`, and all patches in row-major order, or `nil` if the surface is not BSpline or decomposition fails.
- **OCCT:** `GeomConvert_BSplineSurfaceToBezierSurface::NbUPatches`, `NbVPatches`, `Patch`.
- **Example:**
  ```swift
  if let grid = surface.toBezierPatchGrid() {
      print("Grid:", grid.uCount, "×", grid.vCount)
      for u in 0..<grid.uCount {
          for v in 0..<grid.vCount {
              let patch = grid.patches[u * grid.vCount + v]
              print("  patch poles:", patch.bezierNbUPoles, "×", patch.bezierNbVPoles)
          }
      }
  }
  ```
