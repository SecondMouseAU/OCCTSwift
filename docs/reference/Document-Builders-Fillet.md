---
title: Document — Builders, Fillet/Chamfer & glTF
parent: API Reference
---

# Document — Builders, Fillet/Chamfer & glTF

This page covers the v0.120–v0.126 additions to `Document.swift`: continuity/parameter extras on
`Curve3D`, `Curve2D`, and `Surface`; `gp_Vec` static helpers on `Shape`; BSpline mutation
completions on all three geometry types; the standalone `FilletBuilder` and `ChamferBuilder` classes
(`BRepFilletAPI_MakeFillet/MakeChamfer`); the `WireAnalyzer` class (`ShapeAnalysis_Wire`); and
glTF/GLB import and export on `Shape`, `Exporter`, and `Document`. See the main
[`Document`](Document.md) page for the XCAF core and assembly hierarchy.

## Topics

- [Final cleanup — IsCN, ReversedParameter, ParametricTransformation](#final-cleanup--iscn-reversedparameter-parametrictransformation)
- [BSpline completions](#bspline-completions)
- [FilletBuilder](#filletbuilder)
- [ChamferBuilder](#chamferbuilder)
- [ChamferBuilder completions](#chamferbuilder-completions)
- [FilletBuilder completions](#filletbuilder-completions)
- [WireAnalyzer](#wireanalyzer)
- [FilletBuilder completions (v0.126.0)](#filletbuilder-completions-v01260)
- [GLTF Import/Export](#gltf-importexport)

---

## Final cleanup — IsCN, ReversedParameter, ParametricTransformation

Extensions on `Curve3D`, `Curve2D`, and `Surface` exposing continuity checks, reversed-parameter
mappings, parametric-transformation scale factors, and Bezier/BSpline static limits.

### `Curve3D.continuityOrder`

The overall continuity order of this curve (0=C0, 1=C1, 2=C2, etc.).

```swift
public var continuityOrder: Int { get }
```

- **OCCT:** `Geom_Curve::Continuity` → `GeomAbs_Shape` mapped to an integer (via `OCCTCurve3DContinuity`).

---

### `Curve3D.isCN(_:)`

Check if this curve has at least Cn continuity.

```swift
public func isCN(_ n: Int) -> Bool
```

- **Parameters:** `n` — minimum continuity order required.
- **Returns:** `true` if the curve is at least Cn continuous.
- **OCCT:** `Geom_Curve::IsCN` (via `OCCTCurve3DIsCN`).
- **Example:**
  ```swift
  let curve: Curve3D = ...
  if curve.isCN(2) { print("C2 continuous") }
  ```

---

### `Curve3D.reversedParameter(_:)`

Get the parameter on the reversed curve corresponding to parameter `u` on this curve.

```swift
public func reversedParameter(_ u: Double) -> Double
```

- **Parameters:** `u` — parameter on the original curve.
- **Returns:** Corresponding parameter on the reversed curve.
- **OCCT:** `Geom_Curve::ReversedParameter` (via `OCCTCurve3DReversedParameter`).

---

### `Curve3D.parametricTransformation(rotation:translation:)`

Get the parametric transformation scale factor under a geometric transform.

```swift
public func parametricTransformation(rotation: [Double], translation: SIMD3<Double>) -> Double
```

- **Parameters:**
  - `rotation` — 3×3 rotation matrix in row-major order (9 elements).
  - `translation` — translation vector.
- **Returns:** Scale factor for parameter intervals under the transform; returns `1.0` if `rotation.count != 9`.
- **OCCT:** `Geom_Curve::ParametricTransformation` (via `OCCTCurve3DParametricTransformation`).

---

### `Curve3D.bezierResolution(tolerance3d:)`

Resolution for 3D Bezier curves: the parameter step corresponding to `tolerance3d` in 3D space.

```swift
public func bezierResolution(tolerance3d: Double) -> Double
```

- **Parameters:** `tolerance3d` — desired 3D tolerance.
- **OCCT:** `Geom_BezierCurve::Resolution` (via `OCCTCurve3DBezierResolution`).

---

### `Curve3D.bezierMaxDegree`

Maximum degree for 3D Bezier curves (static).

```swift
public static var bezierMaxDegree: Int { get }
```

- **OCCT:** `Geom_BezierCurve::MaxDegree` (via `OCCTCurve3DBezierMaxDegree`).

---

### `Curve2D.continuityOrder`

The overall continuity order of this 2D curve (0=C0, 1=C1, 2=C2, etc.).

```swift
public var continuityOrder: Int { get }
```

- **OCCT:** `Geom2d_Curve::Continuity` (via `OCCTCurve2DContinuity`).

---

### `Curve2D.isCN(_:)`

Check if this 2D curve has at least Cn continuity.

```swift
public func isCN(_ n: Int) -> Bool
```

- **Parameters:** `n` — minimum continuity order required.
- **OCCT:** `Geom2d_Curve::IsCN` (via `OCCTCurve2DIsCN`).

---

### `Curve2D.reversedParameter(_:)`

Get the parameter on the reversed 2D curve corresponding to parameter `u` on this curve.

```swift
public func reversedParameter(_ u: Double) -> Double
```

- **OCCT:** `Geom2d_Curve::ReversedParameter` (via `OCCTCurve2DReversedParameter`).

---

### `Curve2D.bezierMaxDegree`

Maximum degree for 2D Bezier curves (static).

```swift
public static var bezierMaxDegree: Int { get }
```

- **OCCT:** `Geom2d_BezierCurve::MaxDegree` (via `OCCTCurve2DBezierMaxDegree`).

---

### `Curve2D.bsplineMaxDegree`

Maximum degree for 2D BSpline curves (static).

```swift
public static var bsplineMaxDegree: Int { get }
```

- **OCCT:** `Geom2d_BSplineCurve::MaxDegree` (via `OCCTCurve2DBSplineMaxDegree`).

---

### `Surface.isCNu(_:)`

Check if this surface has at least Cn continuity in the U direction.

```swift
public func isCNu(_ n: Int) -> Bool
```

- **Parameters:** `n` — minimum continuity order required.
- **OCCT:** `Geom_Surface::IsCNu` (via `OCCTSurfaceIsCNu`).

---

### `Surface.isCNv(_:)`

Check if this surface has at least Cn continuity in the V direction.

```swift
public func isCNv(_ n: Int) -> Bool
```

- **OCCT:** `Geom_Surface::IsCNv` (via `OCCTSurfaceIsCNv`).

---

### `Surface.uReversed()`

Create a U-reversed copy of this surface.

```swift
public func uReversed() -> Surface?
```

- **Returns:** A new `Surface` with reversed U parameterization, or `nil` on failure.
- **OCCT:** `Geom_Surface::UReversed` (via `OCCTSurfaceUReversed`).

---

### `Surface.vReversed()`

Create a V-reversed copy of this surface.

```swift
public func vReversed() -> Surface?
```

- **Returns:** A new `Surface` with reversed V parameterization, or `nil` on failure.
- **OCCT:** `Geom_Surface::VReversed` (via `OCCTSurfaceVReversed`).

---

### `Surface.uReversedParameter(_:)`

Get the reversed U parameter value corresponding to `u` on the original surface.

```swift
public func uReversedParameter(_ u: Double) -> Double
```

- **OCCT:** `Geom_Surface::UReversedParameter` (via `OCCTSurfaceUReversedParameter`).

---

### `Surface.vReversedParameter(_:)`

Get the reversed V parameter value corresponding to `v` on the original surface.

```swift
public func vReversedParameter(_ v: Double) -> Double
```

- **OCCT:** `Geom_Surface::VReversedParameter` (via `OCCTSurfaceVReversedParameter`).

---

### `Surface.bsplineRemoveVKnot(index:mult:tolerance:)`

Remove a V knot from a BSpline surface, reducing its multiplicity to `mult`.

```swift
@discardableResult
public func bsplineRemoveVKnot(index: Int, mult: Int, tolerance: Double) -> Bool
```

- **Parameters:** `index` — 1-based V knot index; `mult` — target multiplicity; `tolerance` — geometric tolerance.
- **Returns:** `true` if the knot was successfully removed.
- **OCCT:** `Geom_BSplineSurface::RemoveVKnot` (via `OCCTSurfaceBSplineRemoveVKnot`).

---

### `Surface.bezierResolution(tolerance3d:)`

Resolution for Bezier surfaces: parameter steps in U and V corresponding to `tolerance3d` in 3D space.

```swift
public func bezierResolution(tolerance3d: Double) -> (u: Double, v: Double)
```

- **Returns:** Tuple of `(u, v)` parameter steps.
- **OCCT:** `Geom_BezierSurface::Resolution` (via `OCCTSurfaceBezierResolution`).

---

### `Surface.bezierMaxDegree`

Maximum degree for Bezier surfaces (static).

```swift
public static var bezierMaxDegree: Int { get }
```

- **OCCT:** `Geom_BezierSurface::MaxDegree` (via `OCCTSurfaceBezierMaxDegree`).

---

### `Surface.bsplineMaxDegree`

Maximum degree for BSpline surfaces (static).

```swift
public static var bsplineMaxDegree: Int { get }
```

- **OCCT:** `Geom_BSplineSurface::MaxDegree` (via `OCCTSurfaceBSplineMaxDegree`).

---

### `Shape.vecCrossMagnitude(_:_:)`

Compute the magnitude of the cross product of two 3D vectors.

```swift
public static func vecCrossMagnitude(_ v1: SIMD3<Double>, _ v2: SIMD3<Double>) -> Double
```

- **OCCT:** `gp_Vec::CrossMagnitude` (via `OCCTVecCrossMagnitude`).
- **Example:**
  ```swift
  let mag = Shape.vecCrossMagnitude(SIMD3(1, 0, 0), SIMD3(0, 1, 0))  // 1.0
  ```

---

### `Shape.vecCrossSquareMagnitude(_:_:)`

Compute the square magnitude of the cross product of two 3D vectors.

```swift
public static func vecCrossSquareMagnitude(_ v1: SIMD3<Double>, _ v2: SIMD3<Double>) -> Double
```

- **OCCT:** `gp_Vec::CrossSquareMagnitude` (via `OCCTVecCrossSquareMagnitude`).

---

### `Shape.dirIsOpposite(_:_:tolerance:)`

Check if two directions are opposite within angular tolerance (radians).

```swift
public static func dirIsOpposite(_ d1: SIMD3<Double>, _ d2: SIMD3<Double>,
                                 tolerance: Double = 1e-10) -> Bool
```

- **Parameters:** `d1`, `d2` — unit direction vectors; `tolerance` — angular tolerance in radians.
- **Returns:** `true` if the angle between `d1` and `d2` is within `tolerance` of π.
- **OCCT:** `gp_Dir::IsOpposite` (via `OCCTDirIsOpposite`).

---

### `Shape.dirIsNormal(_:_:tolerance:)`

Check if two directions are normal (perpendicular) within angular tolerance (radians).

```swift
public static func dirIsNormal(_ d1: SIMD3<Double>, _ d2: SIMD3<Double>,
                               tolerance: Double = 1e-10) -> Bool
```

- **Parameters:** `tolerance` — angular tolerance in radians.
- **Returns:** `true` if the angle between the two directions is within `tolerance` of π/2.
- **OCCT:** `gp_Dir::IsNormal` (via `OCCTDirIsNormal`).

---

## BSpline completions

BSpline mutation helpers added to `Surface`, `Curve3D`, and `Curve2D`.

### `Surface.bsplineSetUNotPeriodic()`

Remove U periodicity from a BSpline surface.

```swift
@discardableResult
public func bsplineSetUNotPeriodic() -> Bool
```

- **OCCT:** `Geom_BSplineSurface::SetUNotPeriodic` (via `OCCTSurfaceBSplineSetUNotPeriodic`).

---

### `Surface.bsplineSetVNotPeriodic()`

Remove V periodicity from a BSpline surface.

```swift
@discardableResult
public func bsplineSetVNotPeriodic() -> Bool
```

- **OCCT:** `Geom_BSplineSurface::SetVNotPeriodic` (via `OCCTSurfaceBSplineSetVNotPeriodic`).

---

### `Surface.bsplineSetUOrigin(index:)`

Set the origin knot index in the U direction on a periodic BSpline surface (1-based).

```swift
@discardableResult
public func bsplineSetUOrigin(index: Int) -> Bool
```

- **OCCT:** `Geom_BSplineSurface::SetUOrigin` (via `OCCTSurfaceBSplineSetUOrigin`).

---

### `Surface.bsplineSetVOrigin(index:)`

Set the origin knot index in the V direction on a periodic BSpline surface (1-based).

```swift
@discardableResult
public func bsplineSetVOrigin(index: Int) -> Bool
```

- **OCCT:** `Geom_BSplineSurface::SetVOrigin` (via `OCCTSurfaceBSplineSetVOrigin`).

---

### `Surface.bsplineIncreaseUMultiplicity(index:multiplicity:)`

Increase U multiplicity at a knot index to at least `multiplicity` (1-based).

```swift
@discardableResult
public func bsplineIncreaseUMultiplicity(index: Int, multiplicity: Int) -> Bool
```

- **OCCT:** `Geom_BSplineSurface::IncreaseUMultiplicity` (via `OCCTSurfaceBSplineIncreaseUMultiplicity`).

---

### `Surface.bsplineIncreaseVMultiplicity(index:multiplicity:)`

Increase V multiplicity at a knot index to at least `multiplicity` (1-based).

```swift
@discardableResult
public func bsplineIncreaseVMultiplicity(index: Int, multiplicity: Int) -> Bool
```

- **OCCT:** `Geom_BSplineSurface::IncreaseVMultiplicity` (via `OCCTSurfaceBSplineIncreaseVMultiplicity`).

---

### `Surface.bsplineInsertUKnots(_:multiplicities:tolerance:)`

Batch insert U knots with their multiplicities.

```swift
@discardableResult
public func bsplineInsertUKnots(_ knots: [Double], multiplicities: [Int], tolerance: Double = 1e-10) -> Bool
```

- **Parameters:** `knots` — sorted knot values to insert; `multiplicities` — corresponding multiplicities; `tolerance` — knot merging tolerance.
- **Returns:** `false` if either array is empty.
- **OCCT:** `Geom_BSplineSurface::InsertUKnots` (via `OCCTSurfaceBSplineInsertUKnots`).

---

### `Surface.bsplineInsertVKnots(_:multiplicities:tolerance:)`

Batch insert V knots with their multiplicities.

```swift
@discardableResult
public func bsplineInsertVKnots(_ knots: [Double], multiplicities: [Int], tolerance: Double = 1e-10) -> Bool
```

- **OCCT:** `Geom_BSplineSurface::InsertVKnots` (via `OCCTSurfaceBSplineInsertVKnots`).

---

### `Surface.bsplineMovePoint(u:v:to:uPoleRange:vPoleRange:)`

Move a BSpline surface to pass through a point at `(u, v)`, adjusting poles within the given ranges.

```swift
@discardableResult
public func bsplineMovePoint(u: Double, v: Double, to point: SIMD3<Double>,
                             uPoleRange: ClosedRange<Int>, vPoleRange: ClosedRange<Int>) -> Bool
```

- **Parameters:**
  - `u`, `v` — parameter at which the surface should pass through `point`.
  - `point` — target 3D point.
  - `uPoleRange`, `vPoleRange` — 1-based ranges of poles allowed to move.
- **OCCT:** `Geom_BSplineSurface::MovePoint` (via `OCCTSurfaceBSplineMovePoint`).

---

### `Surface.bsplineSetPoleCol(vIndex:poles:)`

Set an entire column of poles (all U poles at `vIndex`, 1-based).

```swift
@discardableResult
public func bsplineSetPoleCol(vIndex: Int, poles: [SIMD3<Double>]) -> Bool
```

- **Parameters:** `vIndex` — 1-based V index; `poles` — array of `NbUPoles` points.
- **OCCT:** `Geom_BSplineSurface::SetPoleCol` (via `OCCTSurfaceBSplineSetPoleCol`).

---

### `Surface.bsplineSetPoleRow(uIndex:poles:)`

Set an entire row of poles (all V poles at `uIndex`, 1-based).

```swift
@discardableResult
public func bsplineSetPoleRow(uIndex: Int, poles: [SIMD3<Double>]) -> Bool
```

- **Parameters:** `uIndex` — 1-based U index; `poles` — array of `NbVPoles` points.
- **OCCT:** `Geom_BSplineSurface::SetPoleRow` (via `OCCTSurfaceBSplineSetPoleRow`).

---

### `Surface.bsplineSetWeightCol(vIndex:weights:)`

Set a column of weights on a BSpline surface (`vIndex` 1-based, count = `NbUPoles`).

```swift
@discardableResult
public func bsplineSetWeightCol(vIndex: Int, weights: [Double]) -> Bool
```

- **OCCT:** `Geom_BSplineSurface::SetWeightCol` (via `OCCTSurfaceBSplineSetWeightCol`).

---

### `Surface.bsplineSetWeightRow(uIndex:weights:)`

Set a row of weights on a BSpline surface (`uIndex` 1-based, count = `NbVPoles`).

```swift
@discardableResult
public func bsplineSetWeightRow(uIndex: Int, weights: [Double]) -> Bool
```

- **OCCT:** `Geom_BSplineSurface::SetWeightRow` (via `OCCTSurfaceBSplineSetWeightRow`).

---

### `Surface.bsplineIncrementUMultiplicity(fromIndex:toIndex:step:)`

Increment U knot multiplicities in the range `[fromIndex, toIndex]` by `step` (1-based).

```swift
@discardableResult
public func bsplineIncrementUMultiplicity(fromIndex: Int, toIndex: Int, step: Int) -> Bool
```

- **OCCT:** `Geom_BSplineSurface::IncrementUMultiplicity` (via `OCCTSurfaceBSplineIncrementUMultiplicity`).

---

### `Surface.bsplineIncrementVMultiplicity(fromIndex:toIndex:step:)`

Increment V knot multiplicities in the range `[fromIndex, toIndex]` by `step` (1-based).

```swift
@discardableResult
public func bsplineIncrementVMultiplicity(fromIndex: Int, toIndex: Int, step: Int) -> Bool
```

- **OCCT:** `Geom_BSplineSurface::IncrementVMultiplicity` (via `OCCTSurfaceBSplineIncrementVMultiplicity`).

---

### `Surface.bsplineFirstUKnotIndex`

First U knot index of the BSpline surface.

```swift
public var bsplineFirstUKnotIndex: Int { get }
```

- **OCCT:** `Geom_BSplineSurface::FirstUKnotIndex` (via `OCCTSurfaceBSplineFirstUKnotIndex`).

---

### `Surface.bsplineLastUKnotIndex`

Last U knot index of the BSpline surface.

```swift
public var bsplineLastUKnotIndex: Int { get }
```

- **OCCT:** `Geom_BSplineSurface::LastUKnotIndex` (via `OCCTSurfaceBSplineLastUKnotIndex`).

---

### `Surface.bsplineFirstVKnotIndex`

First V knot index of the BSpline surface.

```swift
public var bsplineFirstVKnotIndex: Int { get }
```

- **OCCT:** `Geom_BSplineSurface::FirstVKnotIndex` (via `OCCTSurfaceBSplineFirstVKnotIndex`).

---

### `Surface.bsplineLastVKnotIndex`

Last V knot index of the BSpline surface.

```swift
public var bsplineLastVKnotIndex: Int { get }
```

- **OCCT:** `Geom_BSplineSurface::LastVKnotIndex` (via `OCCTSurfaceBSplineLastVKnotIndex`).

---

### `Surface.bsplineCheckAndSegment(u1:u2:v1:v2:uTolerance:vTolerance:)`

Validate parameter ranges and segment the BSpline surface to `[u1,u2] × [v1,v2]`.

```swift
@discardableResult
public func bsplineCheckAndSegment(u1: Double, u2: Double, v1: Double, v2: Double,
                                    uTolerance: Double = 1e-10, vTolerance: Double = 1e-10) -> Bool
```

- **OCCT:** `Geom_BSplineSurface::CheckAndSegment` (via `OCCTSurfaceBSplineCheckAndSegment`).

---

### `Curve3D.bsplineSetNotPeriodic()`

Remove periodicity from a 3D BSpline curve.

```swift
@discardableResult
public func bsplineSetNotPeriodic() -> Bool
```

- **OCCT:** `Geom_BSplineCurve::SetNotPeriodic` (via `OCCTCurve3DBSplineSetNotPeriodic`).

---

### `Curve3D.bsplineSetOrigin(index:)`

Set the origin knot index (1-based) on a periodic 3D BSpline curve.

```swift
@discardableResult
public func bsplineSetOrigin(index: Int) -> Bool
```

- **OCCT:** `Geom_BSplineCurve::SetOrigin` (via `OCCTCurve3DBSplineSetOrigin`).

---

### `Curve3D.bsplineIncreaseMultiplicity(index:multiplicity:)`

Increase the multiplicity of knot at `index` to at least `multiplicity` (1-based).

```swift
@discardableResult
public func bsplineIncreaseMultiplicity(index: Int, multiplicity: Int) -> Bool
```

- **OCCT:** `Geom_BSplineCurve::IncreaseMultiplicity` (via `OCCTCurve3DBSplineIncreaseMultiplicity`).

---

### `Curve3D.bsplineIncrementMultiplicity(from:to:step:)`

Increment multiplicity of all knots from `from` to `to` by `step` (1-based).

```swift
@discardableResult
public func bsplineIncrementMultiplicity(from: Int, to: Int, step: Int = 1) -> Bool
```

- **OCCT:** `Geom_BSplineCurve::IncrementMultiplicity` (via `OCCTCurve3DBSplineIncrementMultiplicity`).

---

### `Curve3D.bsplineSetKnots(_:)`

Set all knot values at once; count must match `NbKnots`.

```swift
@discardableResult
public func bsplineSetKnots(_ knots: [Double]) -> Bool
```

- **OCCT:** `Geom_BSplineCurve::SetKnots` (via `OCCTCurve3DBSplineSetKnots`).

---

### `Curve3D.bsplineReverse()`

Reverse the parameterization of this 3D BSpline curve in place.

```swift
@discardableResult
public func bsplineReverse() -> Bool
```

- **OCCT:** `Geom_BSplineCurve::Reverse` (via `OCCTCurve3DBSplineReverse`).

---

### `Curve3D.bsplineMovePointAndTangent(u:point:tangent:tolerance:poleRange:)`

Move the point and tangent at parameter `u` on a 3D BSpline curve, adjusting poles within `poleRange`.

```swift
@discardableResult
public func bsplineMovePointAndTangent(u: Double, point: SIMD3<Double>, tangent: SIMD3<Double>,
                                       tolerance: Double, poleRange: ClosedRange<Int>) -> Bool
```

- **Parameters:**
  - `u` — parameter value.
  - `point` — desired 3D position at `u`.
  - `tangent` — desired tangent direction at `u`.
  - `tolerance` — geometric tolerance.
  - `poleRange` — 1-based range of poles allowed to move.
- **OCCT:** `Geom_BSplineCurve::MovePointAndTangent` (via `OCCTCurve3DBSplineMovePointAndTangent`).

---

### `Curve2D.bsplineSetNotPeriodic()`

Remove periodicity from a 2D BSpline curve.

```swift
@discardableResult
public func bsplineSetNotPeriodic() -> Bool
```

- **OCCT:** `Geom2d_BSplineCurve::SetNotPeriodic` (via `OCCTCurve2DBSplineSetNotPeriodic`).

---

### `Curve2D.bsplineSetOrigin(index:)`

Set the origin knot index (1-based) on a periodic 2D BSpline curve.

```swift
@discardableResult
public func bsplineSetOrigin(index: Int) -> Bool
```

- **OCCT:** `Geom2d_BSplineCurve::SetOrigin` (via `OCCTCurve2DBSplineSetOrigin`).

---

### `Curve2D.bsplineIncreaseMultiplicity(index:multiplicity:)`

Increase the multiplicity of knot at `index` to at least `multiplicity` (1-based).

```swift
@discardableResult
public func bsplineIncreaseMultiplicity(index: Int, multiplicity: Int) -> Bool
```

- **OCCT:** `Geom2d_BSplineCurve::IncreaseMultiplicity` (via `OCCTCurve2DBSplineIncreaseMultiplicity`).

---

### `Curve2D.bsplineIncrementMultiplicity(from:to:step:)`

Increment multiplicity of all knots from `from` to `to` by `step` (1-based).

```swift
@discardableResult
public func bsplineIncrementMultiplicity(from: Int, to: Int, step: Int = 1) -> Bool
```

- **OCCT:** `Geom2d_BSplineCurve::IncrementMultiplicity` (via `OCCTCurve2DBSplineIncrementMultiplicity`).

---

### `Curve2D.bsplineSetKnots(_:)`

Set all knot values at once; count must match `NbKnots`.

```swift
@discardableResult
public func bsplineSetKnots(_ knots: [Double]) -> Bool
```

- **OCCT:** `Geom2d_BSplineCurve::SetKnots` (via `OCCTCurve2DBSplineSetKnots`).

---

### `Curve2D.bsplineReverse()`

Reverse the parameterization of this 2D BSpline curve in place.

```swift
@discardableResult
public func bsplineReverse() -> Bool
```

- **OCCT:** `Geom2d_BSplineCurve::Reverse` (via `OCCTCurve2DBSplineReverse`).

---

### `Curve2D.bsplineMovePointAndTangent(u:point:tangent:tolerance:poleRange:)`

Move the point and tangent at parameter `u` on a 2D BSpline curve.

```swift
@discardableResult
public func bsplineMovePointAndTangent(u: Double, point: SIMD2<Double>, tangent: SIMD2<Double>,
                                       tolerance: Double, poleRange: ClosedRange<Int>) -> Bool
```

- **Parameters:** `point` and `tangent` are 2D here (unlike the `Curve3D` variant).
- **OCCT:** `Geom2d_BSplineCurve::MovePointAndTangent` (via `OCCTCurve2DBSplineMovePointAndTangent`).

---

## FilletBuilder

Builder for applying rounded fillets to selected edges of a solid, wrapping `BRepFilletAPI_MakeFillet`.

### `FilletBuilder.init?(shape:)`

Create a fillet builder on the given shape.

```swift
public init?(shape: Shape)
```

- **Parameters:** `shape` — the solid or shell to fillet.
- **Returns:** `nil` if the bridge cannot initialise the builder for this shape.
- **OCCT:** `BRepFilletAPI_MakeFillet` (via `OCCTFilletBuilderCreate`).
- **Example:**
  ```swift
  guard let box = Shape.box(width: 20, height: 20, depth: 20),
        let builder = FilletBuilder(shape: box) else { return }
  for edge in box.edges() {
      _ = builder.addEdge(edge, radius: 2.0)
  }
  if let filleted = builder.build() {
      print("filleted shape valid:", filleted.isValid)
  }
  ```

---

### `FilletBuilder.addEdge(_:radius:)`

Add an edge with a constant fillet radius.

```swift
@discardableResult
public func addEdge(_ edge: Edge, radius: Double) -> Bool
```

- **Parameters:** `edge` — the edge to fillet; `radius` — constant fillet radius (> 0).
- **OCCT:** `BRepFilletAPI_MakeFillet::Add` (via `OCCTFilletBuilderAddEdge`).

---

### `FilletBuilder.addEdge(_:radius1:radius2:)`

Add an edge with an evolving fillet radius (`r1` at the start vertex, `r2` at the end vertex).

```swift
@discardableResult
public func addEdge(_ edge: Edge, radius1: Double, radius2: Double) -> Bool
```

- **OCCT:** `BRepFilletAPI_MakeFillet::Add` with two radii (via `OCCTFilletBuilderAddEdgeEvolving`).

---

### `FilletBuilder.build()`

Build the filleted result shape.

```swift
public func build() -> Shape?
```

- **Returns:** The filleted solid, or `nil` if no edges have been added or all contours failed.
- **Note:** Check `hasResult` first when a partial result is acceptable.
- **OCCT:** `BRepFilletAPI_MakeFillet::Shape` (via `OCCTFilletBuilderBuild`).

---

### `FilletBuilder.contourCount`

Number of contours registered in the builder.

```swift
public var contourCount: Int { get }
```

- **OCCT:** `BRepFilletAPI_MakeFillet::NbContours` (via `OCCTFilletBuilderNbContours`).

---

### `FilletBuilder.edgeCount(contour:)`

Number of edges in a contour (1-based index).

```swift
public func edgeCount(contour: Int) -> Int
```

- **OCCT:** `BRepFilletAPI_MakeFillet::NbEdges` (via `OCCTFilletBuilderNbEdges`).

---

### `FilletBuilder.hasResult`

Whether the builder has a result — may be a partial result even if some contours failed.

```swift
public var hasResult: Bool { get }
```

- **OCCT:** `BRepFilletAPI_MakeFillet::HasResult` (via `OCCTFilletBuilderHasResult`).

---

### `FilletBuilder.badShape`

The shape that caused failure (if any).

```swift
public var badShape: Shape? { get }
```

- **Returns:** The problematic sub-shape, or `nil` if no failure has been recorded.
- **OCCT:** `BRepFilletAPI_MakeFillet::BadShape` (via `OCCTFilletBuilderBadShape`).

---

### `FilletBuilder.faultyContourCount`

Number of faulty contours after a build attempt.

```swift
public var faultyContourCount: Int { get }
```

- **OCCT:** `BRepFilletAPI_MakeFillet::NbFaultyContours` (via `OCCTFilletBuilderNbFaultyContours`).

---

### `FilletBuilder.faultyVertexCount`

Number of faulty vertices after a build attempt.

```swift
public var faultyVertexCount: Int { get }
```

- **OCCT:** `BRepFilletAPI_MakeFillet::NbFaultyVertices` (via `OCCTFilletBuilderNbFaultyVertices`).

---

### `FilletBuilder.radius(contour:)`

Get the radius of a contour (1-based index).

```swift
public func radius(contour: Int) -> Double
```

- **OCCT:** `BRepFilletAPI_MakeFillet::GetFilletShape` / radius query (via `OCCTFilletBuilderGetRadius`).

---

### `FilletBuilder.length(contour:)`

Get the length of a contour (1-based index).

```swift
public func length(contour: Int) -> Double
```

- **OCCT:** `BRepFilletAPI_MakeFillet::Length` (via `OCCTFilletBuilderGetLength`).

---

### `FilletBuilder.isConstant(contour:)`

Whether a contour has a constant radius (1-based index).

```swift
public func isConstant(contour: Int) -> Bool
```

- **OCCT:** `BRepFilletAPI_MakeFillet::IsConstant` (via `OCCTFilletBuilderIsConstant`).

---

### `FilletBuilder.removeEdge(_:)`

Remove an edge from its contour.

```swift
@discardableResult
public func removeEdge(_ edge: Edge) -> Bool
```

- **OCCT:** `BRepFilletAPI_MakeFillet::Remove` (via `OCCTFilletBuilderRemoveEdge`).

---

### `FilletBuilder.reset()`

Reset all contours, clearing all registered edges.

```swift
public func reset()
```

- **OCCT:** `BRepFilletAPI_MakeFillet::Reset` (via `OCCTFilletBuilderReset`).

---

## ChamferBuilder

Builder for applying chamfers to selected edges of a solid, wrapping `BRepFilletAPI_MakeChamfer`.

### `ChamferBuilder.init?(shape:)`

Create a chamfer builder on the given shape.

```swift
public init?(shape: Shape)
```

- **OCCT:** `BRepFilletAPI_MakeChamfer` (via `OCCTChamferBuilderCreate`).
- **Example:**
  ```swift
  guard let box = Shape.box(width: 10, height: 10, depth: 10),
        let builder = ChamferBuilder(shape: box) else { return }
  for edge in box.edges() {
      _ = builder.addEdge(edge, distance: 1.0)
  }
  if let chamfered = builder.build() {
      print("valid:", chamfered.isValid)
  }
  ```

---

### `ChamferBuilder.addEdge(_:distance:)`

Add an edge with a symmetric chamfer distance.

```swift
@discardableResult
public func addEdge(_ edge: Edge, distance: Double) -> Bool
```

- **OCCT:** `BRepFilletAPI_MakeChamfer::Add` (via `OCCTChamferBuilderAddEdge`).

---

### `ChamferBuilder.addEdge(_:face:distance1:distance2:)`

Add an edge with two distances (requires a face for orientation).

```swift
@discardableResult
public func addEdge(_ edge: Edge, face: Face, distance1: Double, distance2: Double) -> Bool
```

- **Parameters:** `face` — adjacent face that determines which side gets `distance1`.
- **OCCT:** `BRepFilletAPI_MakeChamfer::Add` with two distances (via `OCCTChamferBuilderAddEdgeTwoDists`).

---

### `ChamferBuilder.addEdge(_:face:distance:angle:)`

Add an edge with a distance and angle (requires a face for orientation).

```swift
@discardableResult
public func addEdge(_ edge: Edge, face: Face, distance: Double, angle: Double) -> Bool
```

- **Parameters:** `angle` — chamfer angle in radians.
- **OCCT:** `BRepFilletAPI_MakeChamfer::AddDA` (via `OCCTChamferBuilderAddEdgeDistAngle`).

---

### `ChamferBuilder.build()`

Build the chamfered result shape.

```swift
public func build() -> Shape?
```

- **Returns:** The chamfered solid, or `nil` on failure.
- **OCCT:** `BRepFilletAPI_MakeChamfer::Shape` (via `OCCTChamferBuilderBuild`).

---

### `ChamferBuilder.contourCount`

Number of contours registered in the builder.

```swift
public var contourCount: Int { get }
```

- **OCCT:** `BRepFilletAPI_MakeChamfer::NbContours` (via `OCCTChamferBuilderNbContours`).

---

### `ChamferBuilder.isDistanceAngle(contour:)`

Whether a contour uses distance-angle mode (1-based index).

```swift
public func isDistanceAngle(contour: Int) -> Bool
```

- **OCCT:** `BRepFilletAPI_MakeChamfer::IsDistAngle` (via `OCCTChamferBuilderIsDistAngle`).

---

## ChamferBuilder completions

Additional inspection and mutation methods on `ChamferBuilder`.

### `ChamferBuilder.edgeCount(contour:)`

Number of edges in a contour (1-based index).

```swift
public func edgeCount(contour: Int) -> Int
```

- **OCCT:** `BRepFilletAPI_MakeChamfer::NbEdges` (via `OCCTChamferBuilderNbEdges`).

---

### `ChamferBuilder.getDistance(contour:)`

Get the symmetric chamfer distance for a contour (1-based).

```swift
public func getDistance(contour: Int) -> Double
```

- **Returns:** The distance, or `-1.0` if not set.
- **OCCT:** `BRepFilletAPI_MakeChamfer::GetDist` (via `OCCTChamferBuilderGetDist`).

---

### `ChamferBuilder.getDistances(contour:)`

Get the two distances for a contour (1-based).

```swift
public func getDistances(contour: Int) -> (d1: Double, d2: Double)
```

- **Returns:** Tuple of `(d1, d2)`; both `-1.0` if not set.
- **OCCT:** `BRepFilletAPI_MakeChamfer::GetDists` (via `OCCTChamferBuilderGetDists`).

---

### `ChamferBuilder.getDistAngle(contour:)`

Get the distance and angle for a contour (1-based).

```swift
public func getDistAngle(contour: Int) -> (distance: Double, angle: Double)
```

- **Returns:** Tuple of `(distance, angle)`; both `-1.0` if not set.
- **OCCT:** `BRepFilletAPI_MakeChamfer::GetDistAngle` (via `OCCTChamferBuilderGetDistAngle`).

---

### `ChamferBuilder.setDistance(_:contour:face:)`

Set symmetric distance on a contour (1-based, requires face for orientation).

```swift
@discardableResult
public func setDistance(_ dist: Double, contour: Int, face: Face) -> Bool
```

- **OCCT:** `BRepFilletAPI_MakeChamfer::SetDist` (via `OCCTChamferBuilderSetDist`).

---

### `ChamferBuilder.setDistances(_:_:contour:face:)`

Set two distances on a contour (1-based, requires face for orientation).

```swift
@discardableResult
public func setDistances(_ d1: Double, _ d2: Double, contour: Int, face: Face) -> Bool
```

- **OCCT:** `BRepFilletAPI_MakeChamfer::SetDists` (via `OCCTChamferBuilderSetDists`).

---

### `ChamferBuilder.setDistAngle(distance:angle:contour:face:)`

Set distance and angle on a contour (1-based, requires face for orientation).

```swift
@discardableResult
public func setDistAngle(distance: Double, angle: Double, contour: Int, face: Face) -> Bool
```

- **OCCT:** `BRepFilletAPI_MakeChamfer::SetDistAngle` (via `OCCTChamferBuilderSetDistAngle`).

---

### `ChamferBuilder.length(contour:)`

Length of a contour (1-based).

```swift
public func length(contour: Int) -> Double
```

- **OCCT:** `BRepFilletAPI_MakeChamfer::Length` (via `OCCTChamferBuilderLength`).

---

### `ChamferBuilder.removeEdge(_:)`

Remove the contour containing the given edge.

```swift
@discardableResult
public func removeEdge(_ edge: Edge) -> Bool
```

- **OCCT:** `BRepFilletAPI_MakeChamfer::Remove` (via `OCCTChamferBuilderRemoveEdge`).

---

### `ChamferBuilder.reset()`

Reset all contours, canceling the effects of a previous build.

```swift
public func reset()
```

- **OCCT:** `BRepFilletAPI_MakeChamfer::Reset` (via `OCCTChamferBuilderReset`).

---

### `ChamferBuilder.isClosed(contour:)`

Whether a contour (1-based) is closed.

```swift
public func isClosed(contour: Int) -> Bool
```

- **OCCT:** `BRepFilletAPI_MakeChamfer::Closed` (via `OCCTChamferBuilderClosed`).

---

### `ChamferBuilder.isClosedAndTangent(contour:)`

Whether a contour (1-based) is closed and tangent at closure.

```swift
public func isClosedAndTangent(contour: Int) -> Bool
```

- **OCCT:** `BRepFilletAPI_MakeChamfer::ClosedAndTangent` (via `OCCTChamferBuilderClosedAndTangent`).

---

### `ChamferBuilder.isSymmetric(contour:)`

Whether a contour (1-based) uses a symmetric (single-distance) chamfer.

```swift
public func isSymmetric(contour: Int) -> Bool
```

- **OCCT:** `BRepFilletAPI_MakeChamfer::IsSymmetric` (via `OCCTChamferBuilderIsSymmetric`).

---

### `ChamferBuilder.isTwoDistances(contour:)`

Whether a contour (1-based) uses the two-distance mode.

```swift
public func isTwoDistances(contour: Int) -> Bool
```

- **OCCT:** `BRepFilletAPI_MakeChamfer::IsTwoDists` (via `OCCTChamferBuilderIsTwoDists`).

---

### `ChamferBuilder.edge(contour:index:)`

Get edge `index` in contour `contour` (both 1-based) as a `Shape`.

```swift
public func edge(contour: Int, index: Int) -> Shape?
```

- **Returns:** The edge as a `Shape`, or `nil` if the indices are out of range.
- **OCCT:** `BRepFilletAPI_MakeChamfer::Edge` (via `OCCTChamferBuilderEdge`).

---

### `ChamferBuilder.firstVertex(contour:)`

Get the first vertex of a contour (1-based) as a `Shape`.

```swift
public func firstVertex(contour: Int) -> Shape?
```

- **OCCT:** `BRepFilletAPI_MakeChamfer::FirstVertex` (via `OCCTChamferBuilderFirstVertex`).

---

### `ChamferBuilder.lastVertex(contour:)`

Get the last vertex of a contour (1-based) as a `Shape`.

```swift
public func lastVertex(contour: Int) -> Shape?
```

- **OCCT:** `BRepFilletAPI_MakeChamfer::LastVertex` (via `OCCTChamferBuilderLastVertex`).

---

### `ChamferBuilder.contour(for:)`

Get the contour index for an edge (returns 0 if not found).

```swift
public func contour(for edge: Edge) -> Int
```

- **OCCT:** `BRepFilletAPI_MakeChamfer::Contour` (via `OCCTChamferBuilderContour`).

---

### `ChamferBuilder.abscissa(contour:vertex:)`

Curvilinear abscissa of a vertex on a contour (1-based).

```swift
public func abscissa(contour: Int, vertex: Shape) -> Double
```

- **OCCT:** `BRepFilletAPI_MakeChamfer::Abscissa` (via `OCCTChamferBuilderAbscissa`).

---

### `ChamferBuilder.relativeAbscissa(contour:vertex:)`

Relative abscissa (0–1) of a vertex on a contour (1-based).

```swift
public func relativeAbscissa(contour: Int, vertex: Shape) -> Double
```

- **OCCT:** `BRepFilletAPI_MakeChamfer::RelativeAbscissa` (via `OCCTChamferBuilderRelativeAbscissa`).

---

## FilletBuilder completions

Additional inspection and mutation methods on `FilletBuilder`.

### `FilletBuilder.setRadius(_:contour:edge:)`

Set a radius on a specific edge in a contour (1-based).

```swift
@discardableResult
public func setRadius(_ radius: Double, contour: Int, edge: Edge) -> Bool
```

- **OCCT:** `BRepFilletAPI_MakeFillet::SetRadius` on edge (via `OCCTFilletBuilderSetRadiusOnEdge`).

---

### `FilletBuilder.setRadius(_:contour:vertex:)`

Set a radius at a specific vertex in a contour (1-based).

```swift
@discardableResult
public func setRadius(_ radius: Double, contour: Int, vertex: Shape) -> Bool
```

- **OCCT:** `BRepFilletAPI_MakeFillet::SetRadius` at vertex (via `OCCTFilletBuilderSetRadiusAtVertex`).

---

### `FilletBuilder.setTwoRadii(_:_:contour:edgeInContour:)`

Set two evolving radii on a specific edge in a contour (both 1-based).

```swift
@discardableResult
public func setTwoRadii(_ r1: Double, _ r2: Double, contour: Int, edgeInContour: Int) -> Bool
```

- **OCCT:** `BRepFilletAPI_MakeFillet::SetRadius` two-radius variant (via `OCCTFilletBuilderSetTwoRadii`).

---

### `FilletBuilder.contour(for:)`

Get the contour index for an edge (returns 0 if not found).

```swift
public func contour(for edge: Edge) -> Int
```

- **OCCT:** `BRepFilletAPI_MakeFillet::Contour` (via `OCCTFilletBuilderContour`).

---

### `FilletBuilder.edge(contour:index:)`

Get edge `index` in contour `contour` (both 1-based) as a `Shape`.

```swift
public func edge(contour: Int, index: Int) -> Shape?
```

- **OCCT:** `BRepFilletAPI_MakeFillet::Edge` (via `OCCTFilletBuilderEdge`).

---

### `FilletBuilder.firstVertex(contour:)`

Get the first vertex of a contour (1-based) as a `Shape`.

```swift
public func firstVertex(contour: Int) -> Shape?
```

- **OCCT:** `BRepFilletAPI_MakeFillet::FirstVertex` (via `OCCTFilletBuilderFirstVertex`).

---

### `FilletBuilder.lastVertex(contour:)`

Get the last vertex of a contour (1-based) as a `Shape`.

```swift
public func lastVertex(contour: Int) -> Shape?
```

- **OCCT:** `BRepFilletAPI_MakeFillet::LastVertex` (via `OCCTFilletBuilderLastVertex`).

---

### `FilletBuilder.abscissa(contour:vertex:)`

Curvilinear abscissa of a vertex on a contour (1-based).

```swift
public func abscissa(contour: Int, vertex: Shape) -> Double
```

- **OCCT:** `BRepFilletAPI_MakeFillet::Abscissa` (via `OCCTFilletBuilderAbscissa`).

---

### `FilletBuilder.relativeAbscissa(contour:vertex:)`

Relative abscissa (0–1) of a vertex on a contour (1-based).

```swift
public func relativeAbscissa(contour: Int, vertex: Shape) -> Double
```

- **OCCT:** `BRepFilletAPI_MakeFillet::RelativeAbscissa` (via `OCCTFilletBuilderRelativeAbscissa`).

---

### `FilletBuilder.isClosedAndTangent(contour:)`

Whether a contour (1-based) is closed and tangent at its closure.

```swift
public func isClosedAndTangent(contour: Int) -> Bool
```

- **OCCT:** `BRepFilletAPI_MakeFillet::ClosedAndTangent` (via `OCCTFilletBuilderClosedAndTangent`).

---

### `FilletBuilder.isClosed(contour:)`

Whether a contour (1-based) is closed.

```swift
public func isClosed(contour: Int) -> Bool
```

- **OCCT:** `BRepFilletAPI_MakeFillet::Closed` (via `OCCTFilletBuilderClosed`).

---

### `FilletBuilder.surfaceCount`

Number of fillet surfaces computed after build.

```swift
public var surfaceCount: Int { get }
```

- **OCCT:** `BRepFilletAPI_MakeFillet::NbSurfaces` (via `OCCTFilletBuilderNbSurfaces`).

---

### `FilletBuilder.computedSurfaceCount(contour:)`

Number of computed fillet surfaces for a contour (1-based).

```swift
public func computedSurfaceCount(contour: Int) -> Int
```

- **OCCT:** `BRepFilletAPI_MakeFillet::NbComputedSurfaces` (via `OCCTFilletBuilderNbComputedSurfaces`).

---

### `FilletBuilder.stripeStatus(contour:)`

Error status for a contour (1-based), returned as `ChFiDS_ErrorStatus` encoded as `Int`.

```swift
public func stripeStatus(contour: Int) -> Int
```

- **Returns:** `0` = no error; other values correspond to `ChFiDS_ErrorStatus` enumerators.
- **OCCT:** `BRepFilletAPI_MakeFillet::StripeStatus` (via `OCCTFilletBuilderStripeStatus`).

---

### `FilletBuilder.faultyContour(index:)`

Get the faulty contour index for the i-th fault (1-based).

```swift
public func faultyContour(index: Int) -> Int
```

- **OCCT:** `BRepFilletAPI_MakeFillet::FaultyContour` (via `OCCTFilletBuilderFaultyContour`).

---

### `FilletBuilder.faultyVertex(index:)`

Get the faulty vertex for the i-th fault (1-based).

```swift
public func faultyVertex(index: Int) -> Shape?
```

- **OCCT:** `BRepFilletAPI_MakeFillet::FaultyVertex` (via `OCCTFilletBuilderFaultyVertex`).

---

## WireAnalyzer

Analyzer for wire geometry and topology, wrapping `ShapeAnalysis_Wire`.

### `WireAnalyzer.init?(wire:face:precision:)`

Create a wire analyzer from a wire shape, a face it lies on, and precision.

```swift
public init?(wire: Wire, face: Shape, precision: Double = 1e-7)
```

- **Parameters:**
  - `wire` — the wire to analyse.
  - `face` — the face context (used for 2D checks).
  - `precision` — geometric precision (default `1e-7`).
- **Returns:** `nil` if initialisation fails.
- **OCCT:** `ShapeAnalysis_Wire` (via `OCCTWireAnalyzerCreate`).
- **Example:**
  ```swift
  if let face = Shape.box(width: 10, height: 10, depth: 1)?.faces().first,
     let wire = Wire.rectangle(width: 5, height: 5),
     let analyzer = WireAnalyzer(wire: wire, face: face) {
      _ = analyzer.perform()
      print("self-intersects:", analyzer.checkSelfIntersection())
  }
  ```

---

### `WireAnalyzer.perform()`

Run all checks (order, small, connected, degenerated, self-intersection, lacking, closed).

```swift
public func perform() -> Bool
```

- **Returns:** `true` if all checks pass.
- **OCCT:** `ShapeAnalysis_Wire::Perform` (via `OCCTWireAnalyzerPerform`).

---

### `WireAnalyzer.checkOrder()`

Check edge ordering (each edge's start matches the previous edge's end).

```swift
public func checkOrder() -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckOrder` (via `OCCTWireAnalyzerCheckOrder`).

---

### `WireAnalyzer.checkConnected(edgeNum:)`

Check if edge `edgeNum` (1-based) is connected to the previous one.

```swift
public func checkConnected(edgeNum: Int) -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckConnected` (via `OCCTWireAnalyzerCheckConnected`).

---

### `WireAnalyzer.checkSmall(edgeNum:)`

Check if edge `edgeNum` (1-based) is degenerate-small (shorter than precision).

```swift
public func checkSmall(edgeNum: Int) -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckSmall` (via `OCCTWireAnalyzerCheckSmall`).

---

### `WireAnalyzer.checkDegenerated(edgeNum:)`

Check if edge `edgeNum` (1-based) is topologically degenerated.

```swift
public func checkDegenerated(edgeNum: Int) -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckDegenerated` (via `OCCTWireAnalyzerCheckDegenerated`).

---

### `WireAnalyzer.checkGap3d(edgeNum:)`

Check for a 3D gap at edge `edgeNum` (1-based; pass `0` to check all edges).

```swift
public func checkGap3d(edgeNum: Int = 0) -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckGap3d` (via `OCCTWireAnalyzerCheckGap3d`).

---

### `WireAnalyzer.checkGap2d(edgeNum:)`

Check for a 2D gap at edge `edgeNum` (1-based; pass `0` to check all edges).

```swift
public func checkGap2d(edgeNum: Int = 0) -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckGap2d` (via `OCCTWireAnalyzerCheckGap2d`).

---

### `WireAnalyzer.checkSeam(edgeNum:)`

Check if edge `edgeNum` (1-based) is a seam edge.

```swift
public func checkSeam(edgeNum: Int) -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckSeam` (via `OCCTWireAnalyzerCheckSeam`).

---

### `WireAnalyzer.checkLacking(edgeNum:)`

Check if edge `edgeNum` (1-based) is lacking (missing a 2D curve on the face).

```swift
public func checkLacking(edgeNum: Int) -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckLacking` (via `OCCTWireAnalyzerCheckLacking`).

---

### `WireAnalyzer.checkSelfIntersection()`

Check whether the wire self-intersects.

```swift
public func checkSelfIntersection() -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckSelfIntersection` (via `OCCTWireAnalyzerCheckSelfIntersection`).

---

### `WireAnalyzer.checkClosed()`

Check whether the wire is topologically closed.

```swift
public func checkClosed() -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckClosed` (via `OCCTWireAnalyzerCheckClosed`).

---

### `WireAnalyzer.minDistance3d`

The minimum 3D gap distance found across all checked edges.

```swift
public var minDistance3d: Double { get }
```

- **OCCT:** `ShapeAnalysis_Wire::MinDistance3d` (via `OCCTWireAnalyzerMinDistance3d`).

---

### `WireAnalyzer.maxDistance3d`

The maximum 3D gap distance found across all checked edges.

```swift
public var maxDistance3d: Double { get }
```

- **OCCT:** `ShapeAnalysis_Wire::MaxDistance3d` (via `OCCTWireAnalyzerMaxDistance3d`).

---

### `WireAnalyzer.edgeCount`

Number of edges in the wire.

```swift
public var edgeCount: Int { get }
```

- **OCCT:** `ShapeAnalysis_Wire::NbEdges` (via `OCCTWireAnalyzerNbEdges`).

---

### `WireAnalyzer.isLoaded`

Whether the wire is loaded into the analyzer.

```swift
public var isLoaded: Bool { get }
```

- **OCCT:** `ShapeAnalysis_Wire::IsLoaded` (via `OCCTWireAnalyzerIsLoaded`).

---

### `WireAnalyzer.isReady`

Whether the analyzer is ready (wire and face both loaded).

```swift
public var isReady: Bool { get }
```

- **OCCT:** `ShapeAnalysis_Wire::IsReady` (via `OCCTWireAnalyzerIsReady`).

---

## FilletBuilder completions (v0.126.0)

Advanced parameter and simulation controls for `FilletBuilder`.

### `FilletBuilder.setParams(tang:tesp:t2d:tApp3d:tApp2d:fleche:)`

Set fillet tolerances for the builder.

```swift
public func setParams(tang: Double, tesp: Double, t2d: Double,
                      tApp3d: Double, tApp2d: Double, fleche: Double)
```

- **Parameters:** `tang` — tangency tolerance; `tesp` — surface tolerance; `t2d` — 2D tolerance; `tApp3d` — 3D approximation tolerance; `tApp2d` — 2D approximation tolerance; `fleche` — sag for approximation.
- **OCCT:** `BRepFilletAPI_MakeFillet::SetParams` (via `OCCTFilletBuilderSetParams`).

---

### `FilletBuilder.setContinuity(_:angularTolerance:)`

Set the fillet surface continuity: `0`=C0, `1`=C1, `2`=C2.

```swift
public func setContinuity(_ internalContinuity: Int, angularTolerance: Double)
```

- **Parameters:** `internalContinuity` — target continuity class; `angularTolerance` — angular tolerance for the join.
- **OCCT:** `BRepFilletAPI_MakeFillet::SetContinuity` (via `OCCTFilletBuilderSetContinuity`).

---

### `FilletBuilder.setFilletShape(_:)`

Set the fillet shape type: `0`=Rational, `1`=QuasiAngular, `2`=Polynomial.

```swift
public func setFilletShape(_ filletShape: Int)
```

- **OCCT:** `BRepFilletAPI_MakeFillet::SetFilletShape` (via `OCCTFilletBuilderSetFilletShape`).

---

### `FilletBuilder.filletShape`

Get the current fillet shape type: `0`=Rational, `1`=QuasiAngular, `2`=Polynomial.

```swift
public var filletShape: Int { get }
```

- **OCCT:** `BRepFilletAPI_MakeFillet::GetFilletShape` (via `OCCTFilletBuilderGetFilletShape`).

---

### `FilletBuilder.resetContour(_:)`

Reset radius info on a specific contour (1-based).

```swift
public func resetContour(_ contourIndex: Int)
```

- **OCCT:** `BRepFilletAPI_MakeFillet::ResetContour` (via `OCCTFilletBuilderResetContour`).

---

### `FilletBuilder.simulate(contour:)`

Simulate filleting on a contour — computes cross-sections without building the final shape.

```swift
public func simulate(contour: Int)
```

- **Parameters:** `contour` — 1-based contour index.
- **OCCT:** `BRepFilletAPI_MakeFillet::Simulate` (via `OCCTFilletBuilderSimulate`).

---

### `FilletBuilder.simulatedSurfaceCount(contour:)`

Get the number of simulated surfaces for a contour (1-based) after `simulate(contour:)`.

```swift
public func simulatedSurfaceCount(contour: Int) -> Int
```

- **OCCT:** `BRepFilletAPI_MakeFillet::NbSimulatedSurf` (via `OCCTFilletBuilderNbSimulatedSurf`).
- **Example:**
  ```swift
  guard let box = Shape.box(width: 30, height: 30, depth: 30),
        let builder = FilletBuilder(shape: box) else { return }
  let edge = box.edges().first!
  _ = builder.addEdge(edge, radius: 3.0)
  builder.simulate(contour: 1)
  print("simulated sections:", builder.simulatedSurfaceCount(contour: 1))
  ```

---

## GLTF Import/Export

glTF/GLB import on `Shape` and `Document`, plus glTF/GLB export on `Exporter` and `Document`.

### `Shape.loadGLTF(fromPath:)`

Load a shape from a glTF or GLB file path.

```swift
public static func loadGLTF(fromPath path: String) -> Shape?
```

- **Parameters:** `path` — file system path to a `.gltf` or `.glb` file.
- **Returns:** The imported shape, or `nil` on failure.
- **OCCT:** `RWGltf_CafReader` (via `OCCTImportGLTF`).
- **Note:** Colors and materials are not preserved; use `Document.loadGLTF(fromPath:)` to retain those.

---

### `Shape.loadGLTF(from:)`

Load a shape from a glTF or GLB file URL.

```swift
public static func loadGLTF(from url: URL) -> Shape?
```

- **OCCT:** `RWGltf_CafReader` (via `OCCTImportGLTF`).
- **Example:**
  ```swift
  let url = URL(fileURLWithPath: "/tmp/model.glb")
  if let shape = Shape.loadGLTF(from: url) {
      print("loaded shape valid:", shape.isValid)
  }
  ```

---

### `Exporter.writeGLTF(shape:to:binary:deflection:)`

Export a shape to glTF or GLB format.

```swift
public static func writeGLTF(shape: Shape, to url: URL, binary: Bool = true, deflection: Double = 0.1) throws
```

- **Parameters:**
  - `shape` — shape to export (meshed internally by the bridge).
  - `url` — output file URL (`.gltf` or `.glb`).
  - `binary` — `true` writes binary GLB; `false` writes text glTF.
  - `deflection` — mesh linear deflection tolerance.
- **Throws:** `Exporter.ExportError.exportFailed` if writing fails.
- **OCCT:** `RWGltf_CafWriter` (via `OCCTExportGLTF`).
- **Example:**
  ```swift
  guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
  let out = URL(fileURLWithPath: "/tmp/box.glb")
  try Exporter.writeGLTF(shape: box, to: out, binary: true, deflection: 0.05)
  ```

---

### `Document.loadGLTF(fromPath:)`

Load a glTF or GLB file into an XDE document, preserving names, materials, and colors.

```swift
public static func loadGLTF(fromPath path: String) -> Document?
```

- **Parameters:** `path` — file system path to a `.gltf` or `.glb` file.
- **Returns:** A `Document` with the assembly hierarchy, or `nil` on failure.
- **OCCT:** `RWGltf_CafReader` into `TDocStd_Document` (via `OCCTDocumentLoadGLTF`).

---

### `Document.loadGLTF(from:)`

Load a glTF or GLB file URL into an XDE document.

```swift
public static func loadGLTF(from url: URL) -> Document?
```

- **OCCT:** `RWGltf_CafReader` (via `OCCTDocumentLoadGLTF`).
- **Example:**
  ```swift
  let url = URL(fileURLWithPath: "/tmp/model.glb")
  if let doc = Document.loadGLTF(from: url) {
      for node in doc.rootNodes {
          print(node.name ?? "<unnamed>")
      }
  }
  ```

---

### `Document.writeGLTF(to:binary:)`

Write this XDE document to glTF or GLB format.

```swift
public func writeGLTF(to url: URL, binary: Bool = true) -> Bool
```

- **Parameters:**
  - `url` — output file URL (`.gltf` or `.glb`).
  - `binary` — `true` writes binary GLB; `false` writes text glTF.
- **Returns:** `true` if the file was written successfully.
- **OCCT:** `RWGltf_CafWriter` (via `OCCTDocumentWriteGLTF`).
- **Example:**
  ```swift
  let doc = try Document.load(from: stepURL)
  let glb = URL(fileURLWithPath: "/tmp/out.glb")
  if doc.writeGLTF(to: glb) {
      print("exported GLB to", glb.path)
  }
  ```
