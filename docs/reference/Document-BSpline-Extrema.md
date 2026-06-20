---
title: Document — BSpline/Bezier Methods & Extrema
parent: API Reference
---

# Document — BSpline/Bezier Methods & Extrema

This page covers lines 8729–9929 of `Sources/OCCTSwift/Document.swift` (v0.106–v0.109): topology-flag extensions on `Shape`, continuity properties on `Curve3D`/`Curve2D`/`Surface`, the BSpline and Bezier nested namespaces on those types, `BRepTools`/`BRepLib` utilities, `MakeFace` convenience factories, `SewingBuilder`, `HatchBuilder`, edge/face/vertex extraction, the full `Extrema` family (`ExtremaElC`, `ExtremaElCS`, `ExtremaElSS`, `ExtremaPointCurve`, `ExtremaPointSurface`), and the `TrigRoots` solver.

See the [Document index page](Document.md) for the full split-chunk table of contents.

## Topics

- [Shape Topology Extensions](#shape-topology-extensions) · [Curve3D/Curve2D/Surface Continuity](#curve3dcurve2dsurface-continuity) · [Geom_BSplineCurve Methods](#geom_bsplinecurve-methods) · [Geom_BSplineSurface Methods](#geom_bsplinesurface-methods) · [Geom2d_BSplineCurve Methods](#geom2d_bsplinecurve-methods) · [Bezier Curve Methods](#bezier-curve-methods) · [BRepTools/BRepLib Utilities](#breptools-breplib-utilities) · [MakeFace Extras](#makeface-extras) · [Sewing](#sewing) · [Hatch_Hatcher](#hatch_hatcher) · [Edge/Face Extraction](#edgeface-extraction) · [Extrema Elementary Distances](#extrema-elementary-distances) · [math_TrigonometricFunctionRoots](#math_trigonometricfunctionroots)

---

## Shape Topology Extensions

Extensions on `Shape` exposing `TopoDS_Shape` orientation flags and topology identity checks (v0.106.0).

### `Shape.Orientation`

Orientation enumeration mirroring `TopAbs_Orientation`.

```swift
public enum Orientation: Int32, Sendable {
    case forward = 0
    case reversed = 1
    case `internal` = 2
    case external = 3
}
```

- **OCCT:** `TopAbs_Orientation`.

---

### `orientation`

Read the current orientation of the shape.

```swift
public var orientation: Orientation
```

- **Returns:** One of `.forward`, `.reversed`, `.internal`, `.external`; defaults to `.forward` if the raw value is unrecognised.
- **OCCT:** `TopoDS_Shape::Orientation`.
- **Example:**
  ```swift
  if let box = Shape.box(width: 10, height: 10, depth: 10) {
      print(box.orientation) // .forward
  }
  ```

---

### `setOrientation(_:)`

Mutate the orientation flag of the shape in-place.

```swift
public func setOrientation(_ orient: Orientation)
```

- **Parameters:** `orient` — new orientation.
- **OCCT:** `TopoDS_Shape::Orientation(TopAbs_Orientation)`.

---

### `reversed`

Return a copy of the shape with reversed orientation.

```swift
public var reversed: Shape?
```

- **Returns:** A new `Shape` with `.reversed` orientation, or `nil` on failure.
- **OCCT:** `TopoDS_Shape::Reversed`.
- **Example:**
  ```swift
  if let box = Shape.box(width: 5, height: 5, depth: 5),
     let r = box.reversed {
      // r.orientation == .reversed
  }
  ```

---

### `complemented`

Return a copy of the shape with complemented (toggled) orientation.

```swift
public var complemented: Shape?
```

- **Returns:** A new `Shape` with toggled orientation, or `nil` on failure.
- **OCCT:** `TopoDS_Shape::Complemented`.

---

### `composed(with:)`

Return a copy of the shape with orientation composed with the given value.

```swift
public func composed(with orient: Orientation) -> Shape?
```

- **Parameters:** `orient` — orientation to compose with.
- **Returns:** A new composed `Shape`, or `nil` on failure.
- **OCCT:** `TopoDS_Shape::Composed`.

---

### `isFree`

Whether the shape's `Free` flag is set.

```swift
public var isFree: Bool
```

- **OCCT:** `TopoDS_Shape::Free`.

---

### `isModified`

Whether the shape's `Modified` flag is set.

```swift
public var isModified: Bool
```

- **OCCT:** `TopoDS_Shape::Modified`.

---

### `isChecked`

Whether the shape's `Checked` flag is set.

```swift
public var isChecked: Bool
```

- **OCCT:** `TopoDS_Shape::Checked`.

---

### `isOrientable`

Whether the shape's `Orientable` flag is set.

```swift
public var isOrientable: Bool
```

- **OCCT:** `TopoDS_Shape::Orientable`.

---

### `isInfinite`

Whether the shape's `Infinite` flag is set.

```swift
public var isInfinite: Bool
```

- **OCCT:** `TopoDS_Shape::Infinite`.

---

### `isConvex`

Whether the shape's `Convex` flag is set.

```swift
public var isConvex: Bool
```

- **OCCT:** `TopoDS_Shape::Convex`.

---

### `isEmptyShape`

Whether the shape has a null underlying `TShape`.

```swift
public var isEmptyShape: Bool
```

- **OCCT:** `TopoDS_Shape::IsNull`.

---

### `isPartner(with:)`

Test whether two shapes share the same underlying `TShape` (same geometry, potentially different location/orientation).

```swift
public func isPartner(with other: Shape) -> Bool
```

- **Parameters:** `other` — shape to compare.
- **OCCT:** `TopoDS_Shape::IsPartner`.

---

### `isEqual(to:)`

Test full topological equality: same `TShape`, same location, same orientation.

```swift
public func isEqual(to other: Shape) -> Bool
```

- **Parameters:** `other` — shape to compare.
- **OCCT:** `TopoDS_Shape::IsEqual`.

---

### `nbChildren`

Number of direct child sub-shapes.

```swift
public var nbChildren: Int
```

- **OCCT:** `TopoDS_Iterator` child count.

---

### `hashCode`

Hash code of the shape.

```swift
public var hashCode: Int
```

- **OCCT:** `TopoDS_Shape::HashCode`.

---

## Curve3D/Curve2D/Surface Continuity

Continuity integer accessors added to `Curve3D`, `Curve2D`, and `Surface` (v0.106.0). The integer encodes the `GeomAbs_Shape` enum: 0 = C0, 1 = C1, 2 = C2, 3 = C3, 4 = CN, 5 = G1, 6 = G2.

### `Curve3D.continuity`

Global geometric continuity of the 3D curve.

```swift
public var continuity: Int
```

- **OCCT:** `Geom_Curve::Continuity`.
- **Example:**
  ```swift
  if let c = Curve3D.makeCircle(center: .zero, normal: SIMD3(0,0,1), radius: 5) {
      print(c.continuity) // 4 (CN — infinitely differentiable)
  }
  ```

---

### `Curve2D.continuity`

Global geometric continuity of the 2D curve.

```swift
public var continuity: Int
```

- **OCCT:** `Geom2d_Curve::Continuity`.

---

### `Surface.continuity`

Global geometric continuity of the surface.

```swift
public var continuity: Int
```

- **OCCT:** `Geom_Surface::Continuity`.

---

### `Surface.nBounds`

Number of contiguous spans in the U and V parametric directions.

```swift
public var nBounds: (uSpans: Int, vSpans: Int)
```

- **Returns:** A tuple `(uSpans, vSpans)` reporting how many knot intervals exist in each direction. Always `(1, 1)` for analytic surfaces.
- **OCCT:** `Geom_Surface::NbUPoles`/`NbVPoles` count derivation (bridge-specific).

---

## Geom_BSplineCurve Methods

`Curve3D.BSpline` is a nested struct exposing low-level knot/pole manipulation for `Geom_BSplineCurve`-backed curves (v0.107.0). Access via `curve.bspline`. All members silently return zero/false/empty if the curve is not a BSpline.

### `Curve3D.BSpline.knotCount`

Number of distinct knot values.

```swift
public var knotCount: Int
```

- **OCCT:** `Geom_BSplineCurve::NbKnots`.

---

### `Curve3D.BSpline.poleCount`

Number of control points.

```swift
public var poleCount: Int
```

- **OCCT:** `Geom_BSplineCurve::NbPoles`.

---

### `Curve3D.BSpline.degree`

Polynomial degree of the curve.

```swift
public var degree: Int
```

- **OCCT:** `Geom_BSplineCurve::Degree`.

---

### `Curve3D.BSpline.isRational`

Whether the BSpline is rational (has non-uniform weights).

```swift
public var isRational: Bool
```

- **OCCT:** `Geom_BSplineCurve::IsRational`.

---

### `Curve3D.BSpline.knots`

All distinct knot parameter values.

```swift
public var knots: [Double]
```

- **Returns:** Array of length `knotCount`, or empty if not a BSpline.
- **OCCT:** `Geom_BSplineCurve::Knots`.

---

### `Curve3D.BSpline.multiplicities`

Multiplicity of each knot.

```swift
public var multiplicities: [Int]
```

- **Returns:** Array of length `knotCount`, or empty if not a BSpline.
- **OCCT:** `Geom_BSplineCurve::Multiplicities`.

---

### `Curve3D.BSpline.pole(at:)`

Get the 3D position of a control point (1-based index).

```swift
public func pole(at index: Int) -> SIMD3<Double>
```

- **Parameters:** `index` — 1-based pole index (1 … `poleCount`).
- **Returns:** The control point coordinates; returns the zero vector if out-of-range.
- **OCCT:** `Geom_BSplineCurve::Pole`.
- **Example:**
  ```swift
  let p = curve.bspline.pole(at: 1)
  ```

---

### `Curve3D.BSpline.setPole(at:to:)`

Reposition a control point.

```swift
@discardableResult
public func setPole(at index: Int, to point: SIMD3<Double>) -> Bool
```

- **Parameters:** `index` — 1-based index; `point` — new position.
- **Returns:** `true` on success.
- **OCCT:** `Geom_BSplineCurve::SetPole`.

---

### `Curve3D.BSpline.weight(at:)`

Get the rational weight at a control point (1-based index).

```swift
public func weight(at index: Int) -> Double
```

- **Parameters:** `index` — 1-based index.
- **Returns:** Weight value; 1.0 for non-rational curves or out-of-range index.
- **OCCT:** `Geom_BSplineCurve::Weight`.

---

### `Curve3D.BSpline.setWeight(at:to:)`

Set the rational weight at a control point.

```swift
@discardableResult
public func setWeight(at index: Int, to weight: Double) -> Bool
```

- **Parameters:** `index` — 1-based index; `weight` — new weight (must be positive).
- **OCCT:** `Geom_BSplineCurve::SetWeight`.

---

### `Curve3D.BSpline.insertKnot(u:multiplicity:tolerance:)`

Insert a knot at parameter `u` with given multiplicity, blending the existing curve.

```swift
@discardableResult
public func insertKnot(u: Double, multiplicity: Int = 1, tolerance: Double = 1e-6) -> Bool
```

- **Parameters:** `u` — parameter value; `multiplicity` — desired multiplicity (default 1); `tolerance` — knot merging tolerance.
- **Returns:** `true` on success.
- **OCCT:** `Geom_BSplineCurve::InsertKnot`.

---

### `Curve3D.BSpline.removeKnot(at:multiplicity:tolerance:)`

Reduce or remove a knot at a 1-based index down to `multiplicity` (0 to remove entirely).

```swift
@discardableResult
public func removeKnot(at index: Int, multiplicity: Int, tolerance: Double) -> Bool
```

- **Parameters:** `index` — 1-based knot index; `multiplicity` — target multiplicity; `tolerance` — geometric tolerance for the removal.
- **Returns:** `true` if removal was geometrically within tolerance.
- **OCCT:** `Geom_BSplineCurve::RemoveKnot`.

---

### `Curve3D.BSpline.segment(u1:u2:)`

Restrict the BSpline to the sub-interval `[u1, u2]` in-place.

```swift
@discardableResult
public func segment(u1: Double, u2: Double) -> Bool
```

- **Parameters:** `u1`, `u2` — parameter bounds (must be within the current domain).
- **Returns:** `true` on success.
- **OCCT:** `Geom_BSplineCurve::Segment`.

---

### `Curve3D.BSpline.increaseDegree(to:)`

Elevate the polynomial degree to at least `degree` without changing the curve shape.

```swift
@discardableResult
public func increaseDegree(to degree: Int) -> Bool
```

- **Parameters:** `degree` — target degree (no-op if already ≥ current degree).
- **Returns:** `true` on success.
- **OCCT:** `Geom_BSplineCurve::IncreaseDegree`.

---

### `Curve3D.BSpline.resolution(tolerance3d:)`

Compute the parametric resolution corresponding to a 3D Euclidean tolerance.

```swift
public func resolution(tolerance3d: Double) -> Double
```

- **Parameters:** `tolerance3d` — 3D distance tolerance.
- **Returns:** Equivalent parametric tolerance.
- **OCCT:** `Geom_BSplineCurve::Resolution`.

---

### `Curve3D.BSpline.setPeriodic(_:)`

Make the BSpline periodic or non-periodic.

```swift
@discardableResult
public func setPeriodic(_ periodic: Bool) -> Bool
```

- **Parameters:** `periodic` — `true` to make periodic, `false` to make non-periodic.
- **Returns:** `true` on success.
- **OCCT:** `Geom_BSplineCurve::SetPeriodic` / `SetNotPeriodic`.

---

### `Curve3D.bspline`

Entry point into BSpline-specific operations on a `Curve3D`.

```swift
public var bspline: BSpline
```

- **Note:** All `BSpline` members silently no-op or return zero/false/empty when the underlying curve is not a `Geom_BSplineCurve`.

---

## Geom_BSplineSurface Methods

`Surface.BSpline` is a nested struct for `Geom_BSplineSurface`-backed surfaces (v0.107.0). Access via `surface.bsplineSurface`.

### `Surface.BSpline.nbUKnots`

Number of distinct knots in the U direction.

```swift
public var nbUKnots: Int
```

- **OCCT:** `Geom_BSplineSurface::NbUKnots`.

---

### `Surface.BSpline.nbVKnots`

Number of distinct knots in the V direction.

```swift
public var nbVKnots: Int
```

- **OCCT:** `Geom_BSplineSurface::NbVKnots`.

---

### `Surface.BSpline.nbUPoles`

Number of control points in the U direction.

```swift
public var nbUPoles: Int
```

- **OCCT:** `Geom_BSplineSurface::NbUPoles`.

---

### `Surface.BSpline.nbVPoles`

Number of control points in the V direction.

```swift
public var nbVPoles: Int
```

- **OCCT:** `Geom_BSplineSurface::NbVPoles`.

---

### `Surface.BSpline.uDegree`

Polynomial degree in the U direction.

```swift
public var uDegree: Int
```

- **OCCT:** `Geom_BSplineSurface::UDegree`.

---

### `Surface.BSpline.vDegree`

Polynomial degree in the V direction.

```swift
public var vDegree: Int
```

- **OCCT:** `Geom_BSplineSurface::VDegree`.

---

### `Surface.BSpline.isURational`

Whether the surface is rational in the U direction.

```swift
public var isURational: Bool
```

- **OCCT:** `Geom_BSplineSurface::IsURational`.

---

### `Surface.BSpline.isVRational`

Whether the surface is rational in the V direction.

```swift
public var isVRational: Bool
```

- **OCCT:** `Geom_BSplineSurface::IsVRational`.

---

### `Surface.BSpline.pole(uIndex:vIndex:)`

Get the 3D position of a control point at the given (U, V) grid indices (1-based).

```swift
public func pole(uIndex: Int, vIndex: Int) -> SIMD3<Double>
```

- **Parameters:** `uIndex`, `vIndex` — 1-based indices into the pole grid.
- **Returns:** Control point position; returns zero vector for out-of-range indices.
- **OCCT:** `Geom_BSplineSurface::Pole`.

---

### `Surface.BSpline.setPole(uIndex:vIndex:to:)`

Reposition a control point in the pole grid.

```swift
@discardableResult
public func setPole(uIndex: Int, vIndex: Int, to point: SIMD3<Double>) -> Bool
```

- **OCCT:** `Geom_BSplineSurface::SetPole`.

---

### `Surface.BSpline.setWeight(uIndex:vIndex:to:)`

Set the rational weight at a pole grid position.

```swift
@discardableResult
public func setWeight(uIndex: Int, vIndex: Int, to weight: Double) -> Bool
```

- **OCCT:** `Geom_BSplineSurface::SetWeight`.

---

### `Surface.BSpline.insertUKnot(u:multiplicity:tolerance:)`

Insert a knot in the U direction.

```swift
@discardableResult
public func insertUKnot(u: Double, multiplicity: Int = 1, tolerance: Double = 1e-6) -> Bool
```

- **OCCT:** `Geom_BSplineSurface::InsertUKnot`.

---

### `Surface.BSpline.insertVKnot(v:multiplicity:tolerance:)`

Insert a knot in the V direction.

```swift
@discardableResult
public func insertVKnot(v: Double, multiplicity: Int = 1, tolerance: Double = 1e-6) -> Bool
```

- **OCCT:** `Geom_BSplineSurface::InsertVKnot`.

---

### `Surface.BSpline.segment(u1:u2:v1:v2:)`

Restrict the surface to a sub-domain `[u1,u2] × [v1,v2]` in-place.

```swift
@discardableResult
public func segment(u1: Double, u2: Double, v1: Double, v2: Double) -> Bool
```

- **OCCT:** `Geom_BSplineSurface::Segment`.

---

### `Surface.BSpline.increaseDegree(uDeg:vDeg:)`

Elevate the degree in both directions simultaneously.

```swift
@discardableResult
public func increaseDegree(uDeg: Int, vDeg: Int) -> Bool
```

- **OCCT:** `Geom_BSplineSurface::IncreaseDegree`.

---

### `Surface.BSpline.exchangeUV()`

Swap U and V parametric directions of the surface.

```swift
@discardableResult
public func exchangeUV() -> Bool
```

- **OCCT:** `Geom_BSplineSurface::ExchangeUV`.

---

### `Surface.bsplineSurface`

Entry point into BSpline-specific operations on a `Surface`.

```swift
public var bsplineSurface: BSpline
```

---

## Geom2d_BSplineCurve Methods

`Curve2D.BSpline` exposes `Geom2d_BSplineCurve` operations on 2D curves (v0.107.0). Access via `curve.bspline`.

### `Curve2D.BSpline.knotCount`

Number of distinct knot values.

```swift
public var knotCount: Int
```

- **OCCT:** `Geom2d_BSplineCurve::NbKnots`.

---

### `Curve2D.BSpline.poleCount`

Number of control points.

```swift
public var poleCount: Int
```

- **OCCT:** `Geom2d_BSplineCurve::NbPoles`.

---

### `Curve2D.BSpline.degree`

Polynomial degree.

```swift
public var degree: Int
```

- **OCCT:** `Geom2d_BSplineCurve::Degree`.

---

### `Curve2D.BSpline.isRational`

Whether the 2D BSpline is rational.

```swift
public var isRational: Bool
```

- **OCCT:** `Geom2d_BSplineCurve::IsRational`.

---

### `Curve2D.BSpline.pole(at:)`

Get a 2D control point at 1-based index.

```swift
public func pole(at index: Int) -> SIMD2<Double>
```

- **OCCT:** `Geom2d_BSplineCurve::Pole`.

---

### `Curve2D.BSpline.setPole(at:to:)`

Set a 2D control point at 1-based index.

```swift
@discardableResult
public func setPole(at index: Int, to point: SIMD2<Double>) -> Bool
```

- **OCCT:** `Geom2d_BSplineCurve::SetPole`.

---

### `Curve2D.BSpline.setWeight(at:to:)`

Set the rational weight at a 1-based control point index.

```swift
@discardableResult
public func setWeight(at index: Int, to weight: Double) -> Bool
```

- **OCCT:** `Geom2d_BSplineCurve::SetWeight`.

---

### `Curve2D.BSpline.insertKnot(u:multiplicity:tolerance:)`

Insert a knot at parameter `u`.

```swift
@discardableResult
public func insertKnot(u: Double, multiplicity: Int = 1, tolerance: Double = 1e-6) -> Bool
```

- **OCCT:** `Geom2d_BSplineCurve::InsertKnot`.

---

### `Curve2D.BSpline.removeKnot(at:multiplicity:tolerance:)`

Reduce a knot at a 1-based index to the given multiplicity.

```swift
@discardableResult
public func removeKnot(at index: Int, multiplicity: Int, tolerance: Double) -> Bool
```

- **OCCT:** `Geom2d_BSplineCurve::RemoveKnot`.

---

### `Curve2D.BSpline.segment(u1:u2:)`

Restrict the 2D BSpline to `[u1, u2]` in-place.

```swift
@discardableResult
public func segment(u1: Double, u2: Double) -> Bool
```

- **OCCT:** `Geom2d_BSplineCurve::Segment`.

---

### `Curve2D.BSpline.increaseDegree(to:)`

Elevate the degree without changing the curve shape.

```swift
@discardableResult
public func increaseDegree(to degree: Int) -> Bool
```

- **OCCT:** `Geom2d_BSplineCurve::IncreaseDegree`.

---

### `Curve2D.BSpline.resolution(tolerance:)`

Compute the parametric resolution for a given 2D tolerance.

```swift
public func resolution(tolerance: Double) -> Double
```

- **OCCT:** `Geom2d_BSplineCurve::Resolution`.

---

### `Curve2D.bspline`

Entry point into 2D BSpline operations on a `Curve2D`.

```swift
public var bspline: BSpline
```

---

## Bezier Curve Methods

`Curve3D.Bezier` exposes `Geom_BezierCurve` operations (v0.107.0). Access via `curve.bezier`.

### `Curve3D.Bezier.pole(at:)`

Get the 3D position of a Bezier control point at 1-based index.

```swift
public func pole(at index: Int) -> SIMD3<Double>
```

- **OCCT:** `Geom_BezierCurve::Pole`.

---

### `Curve3D.Bezier.setPole(at:to:)`

Set a Bezier control point at 1-based index.

```swift
@discardableResult
public func setPole(at index: Int, to point: SIMD3<Double>) -> Bool
```

- **OCCT:** `Geom_BezierCurve::SetPole`.

---

### `Curve3D.Bezier.setWeight(at:to:)`

Set the rational weight at a 1-based control point.

```swift
@discardableResult
public func setWeight(at index: Int, to weight: Double) -> Bool
```

- **OCCT:** `Geom_BezierCurve::SetWeight`.

---

### `Curve3D.Bezier.insertPoleAfter(index:point:)`

Insert a new control point after the given 1-based index, raising the degree by 1.

```swift
@discardableResult
public func insertPoleAfter(index: Int, point: SIMD3<Double>) -> Bool
```

- **Parameters:** `index` — insert position (1-based); `point` — position of the new pole.
- **OCCT:** `Geom_BezierCurve::InsertPoleAfter`.

---

### `Curve3D.Bezier.removePole(at:)`

Remove a control point at the given 1-based index, reducing the degree by 1.

```swift
@discardableResult
public func removePole(at index: Int) -> Bool
```

- **Note:** Requires degree ≥ 2.
- **OCCT:** `Geom_BezierCurve::RemovePole`.

---

### `Curve3D.Bezier.segment(u1:u2:)`

Restrict the Bezier to `[u1, u2]` in-place.

```swift
@discardableResult
public func segment(u1: Double, u2: Double) -> Bool
```

- **OCCT:** `Geom_BezierCurve::Segment`.

---

### `Curve3D.Bezier.increaseDegree(to:)`

Elevate the polynomial degree.

```swift
@discardableResult
public func increaseDegree(to degree: Int) -> Bool
```

- **OCCT:** `Geom_BezierCurve::Increase`.

---

### `Curve3D.Bezier.isRational`

Whether the Bezier is rational.

```swift
public var isRational: Bool
```

- **OCCT:** `Geom_BezierCurve::IsRational`.

---

### `Curve3D.Bezier.degree`

Polynomial degree.

```swift
public var degree: Int
```

- **OCCT:** `Geom_BezierCurve::Degree`.

---

### `Curve3D.Bezier.poleCount`

Number of control points.

```swift
public var poleCount: Int
```

- **OCCT:** `Geom_BezierCurve::NbPoles`.

---

### `Curve3D.bezier`

Entry point into Bezier-specific operations on a `Curve3D`.

```swift
public var bezier: Bezier
```

- **Note:** All members silently no-op or return zero/false when the underlying curve is not a `Geom_BezierCurve`.

---

## BRepTools/BRepLib Utilities

Low-level shape repair and edge parametrisation helpers (v0.107.0).

### `Shape.clean()`

Remove all triangulation/mesh tessellation data from the shape.

```swift
public func clean()
```

- **OCCT:** `BRepTools::Clean`.

---

### `Shape.cleanGeometry()`

Remove geometry (PCurves and the like) from the shape, leaving only topology.

```swift
public func cleanGeometry()
```

- **OCCT:** `BRepTools::CleanGeometry`.

---

### `Shape.removeUnusedPCurves()`

Strip PCurves that are no longer referenced by any face.

```swift
public func removeUnusedPCurves()
```

- **OCCT:** `BRepTools::RemoveUnusedPCurves`.

---

### `Shape.updateShape()`

Recompute internal BRep book-keeping after direct topology edits.

```swift
public func updateShape()
```

- **OCCT:** `BRep_Builder::UpdateVertex`/`UpdateEdge` (bridge-internal).

---

### `Shape.checkSameRange(edge:)`

Return `true` if the edge has consistent same-range parametrisation across all its PCurves.

```swift
public static func checkSameRange(edge: Shape) -> Bool
```

- **Parameters:** `edge` — a shape of type edge.
- **OCCT:** `BRepLib::CheckSameRange`.

---

### `Shape.sameRange(edge:tolerance:)`

Ensure same-range parametrisation, adjusting PCurves if needed.

```swift
@discardableResult
public static func sameRange(edge: Shape, tolerance: Double = 1e-6) -> Bool
```

- **Parameters:** `edge` — edge shape; `tolerance` — merge tolerance.
- **Returns:** `true` if the operation succeeded.
- **OCCT:** `BRepLib::SameRange`.

---

### `Shape.buildCurve3d(edge:tolerance:)`

Build (or rebuild) the 3D curve of an edge from its PCurves on adjacent faces.

```swift
@discardableResult
public static func buildCurve3d(edge: Shape, tolerance: Double = 1e-6) -> Bool
```

- **Returns:** `true` if a 3D curve was successfully built.
- **OCCT:** `BRepLib::BuildCurve3d`.

---

### `Shape.updateTolerances()`

Propagate tolerance up through all sub-shapes (vertices → edges → faces).

```swift
public func updateTolerances()
```

- **OCCT:** `BRepLib::UpdateTolerances`.

---

### `Shape.updateInnerTolerances()`

Update the inner tolerances of all sub-shapes without propagating outward.

```swift
public func updateInnerTolerances()
```

- **OCCT:** `BRepLib::UpdateTolerances` (inner variant).

---

### `Shape.updateEdgeTolerance(edge:tolerance:)`

Force the tolerance of a specific edge to the given value.

```swift
@discardableResult
public static func updateEdgeTolerance(edge: Shape, tolerance: Double) -> Bool
```

- **OCCT:** `BRepLib::UpdateEdgeTolerance`.

---

## MakeFace Extras

Convenience factories for faces bounded by analytic surfaces with explicit UV domain or wire boundaries (v0.107.0).

### `Shape.faceFromSphere(center:radius:uMin:uMax:vMin:vMax:)`

Create a bounded face on a sphere.

```swift
public static func faceFromSphere(
    center: SIMD3<Double> = .zero, radius: Double,
    uMin: Double, uMax: Double, vMin: Double, vMax: Double
) -> Shape?
```

- **Parameters:** `center` — sphere centre (default origin); `radius` — sphere radius; `uMin`/`uMax` — longitude bounds [0, 2π]; `vMin`/`vMax` — latitude bounds [-π/2, π/2].
- **Returns:** A face shape, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_MakeFace(gp_Sphere, ...)`.
- **Example:**
  ```swift
  if let f = Shape.faceFromSphere(radius: 10, uMin: 0, uMax: .pi, vMin: -.pi/2, vMax: .pi/2) {
      // half-sphere face
  }
  ```

---

### `Shape.faceFromTorus(center:normal:majorRadius:minorRadius:uMin:uMax:vMin:vMax:)`

Create a bounded face on a torus.

```swift
public static func faceFromTorus(
    center: SIMD3<Double> = .zero, normal: SIMD3<Double> = SIMD3(0, 0, 1),
    majorRadius: Double, minorRadius: Double,
    uMin: Double, uMax: Double, vMin: Double, vMax: Double
) -> Shape?
```

- **OCCT:** `BRepBuilderAPI_MakeFace(gp_Torus, ...)`.

---

### `Shape.faceFromCone(center:normal:semiAngle:radius:uMin:uMax:vMin:vMax:)`

Create a bounded face on a cone.

```swift
public static func faceFromCone(
    center: SIMD3<Double> = .zero, normal: SIMD3<Double> = SIMD3(0, 0, 1),
    semiAngle: Double, radius: Double,
    uMin: Double, uMax: Double, vMin: Double, vMax: Double
) -> Shape?
```

- **Parameters:** `semiAngle` — half-angle of the cone in radians; `radius` — reference radius at the apex plane.
- **OCCT:** `BRepBuilderAPI_MakeFace(gp_Cone, ...)`.

---

### `Shape.faceFromSurface(_:wire:inside:)`

Create a face from a surface trimmed by a wire boundary.

```swift
public static func faceFromSurface(_ surface: Surface, wire: Shape, inside: Bool = true) -> Shape?
```

- **Parameters:** `surface` — the carrier surface; `wire` — outer boundary wire; `inside` — if `true` the face is on the interior side of the wire.
- **OCCT:** `BRepBuilderAPI_MakeFace(surface, wire, inside)`.

---

### `Shape.faceAddHole(face:wire:)`

Add an inner wire (hole) to an existing face.

```swift
public static func faceAddHole(face: Shape, wire: Shape) -> Shape?
```

- **Parameters:** `face` — the existing face; `wire` — hole boundary wire (must lie on the face surface).
- **Returns:** New face with the hole added, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_MakeFace::Add`.

---

### `Shape.faceCopy(_:)`

Shallow-copy a face shape.

```swift
public static func faceCopy(_ face: Shape) -> Shape?
```

- **OCCT:** `BRepBuilderAPI_MakeFace` copy constructor path.

---

## Sewing

`SewingBuilder` stitches shell fragments into a closed shell or solid by merging free boundary edges within a tolerance (v0.107.0).

### `SewingBuilder.init(tolerance:)`

Create a new sewing builder.

```swift
public init?(tolerance: Double = 1e-6)
```

- **Parameters:** `tolerance` — maximum gap between edges that will be merged.
- **Returns:** `nil` on allocation failure.
- **OCCT:** `BRepBuilderAPI_Sewing(tolerance)`.

---

### `SewingBuilder.deinit`

Release the underlying sewing context.

```swift
deinit
```

- **OCCT:** `OCCTSewingRelease`.

---

### `SewingBuilder.add(_:)`

Register a shape to be included in the sewing operation.

```swift
public func add(_ shape: Shape)
```

- **OCCT:** `BRepBuilderAPI_Sewing::Add`.

---

### `SewingBuilder.perform()`

Execute the sewing algorithm over all added shapes.

```swift
public func perform()
```

- **OCCT:** `BRepBuilderAPI_Sewing::Perform`.

---

### `SewingBuilder.result`

The sewn output shape after `perform()`.

```swift
public var result: Shape?
```

- **Returns:** The result shape, or `nil` if sewing has not been performed or failed.
- **OCCT:** `BRepBuilderAPI_Sewing::SewedShape`.
- **Example:**
  ```swift
  if let sew = SewingBuilder(tolerance: 1e-5) {
      sew.add(shell1)
      sew.add(shell2)
      sew.perform()
      if let sewn = sew.result {
          // sewn shell
      }
  }
  ```

---

### `SewingBuilder.nbFreeEdges`

Number of boundary edges that were not matched to another edge.

```swift
public var nbFreeEdges: Int
```

- **OCCT:** `BRepBuilderAPI_Sewing::NbFreeEdges`.

---

### `SewingBuilder.nbContigousEdges`

Number of edge pairs that were stitched (made contiguous).

```swift
public var nbContigousEdges: Int
```

- **OCCT:** `BRepBuilderAPI_Sewing::NbContigousEdges`.

---

### `SewingBuilder.nbDegeneratedShapes`

Number of degenerated shapes encountered during sewing.

```swift
public var nbDegeneratedShapes: Int
```

- **OCCT:** `BRepBuilderAPI_Sewing::NbDegeneratedShapes`.

---

## Hatch_Hatcher

`HatchBuilder` clips 2D hatch lines against a domain boundary and reports the resulting intervals (v0.107.0).

### `HatchBuilder.init(tolerance:)`

Create a hatcher with the given coincidence tolerance.

```swift
public init?(tolerance: Double = 1e-6)
```

- **OCCT:** `Hatch_Hatcher(tolerance)`.

---

### `HatchBuilder.deinit`

Release the underlying hatcher.

```swift
deinit
```

---

### `HatchBuilder.addXLine(_:)`

Add a vertical hatch line at parameter `x`.

```swift
public func addXLine(_ x: Double)
```

- **OCCT:** `Hatch_Hatcher::AddXLine`.

---

### `HatchBuilder.addYLine(_:)`

Add a horizontal hatch line at parameter `y`.

```swift
public func addYLine(_ y: Double)
```

- **OCCT:** `Hatch_Hatcher::AddYLine`.

---

### `HatchBuilder.trim(x1:y1:x2:y2:)`

Clip all hatch lines against the segment from `(x1, y1)` to `(x2, y2)`.

```swift
public func trim(x1: Double, y1: Double, x2: Double, y2: Double)
```

- **OCCT:** `Hatch_Hatcher::Trim`.
- **Example:**
  ```swift
  if let h = HatchBuilder(tolerance: 1e-6) {
      h.addXLine(5.0)
      h.trim(x1: 0, y1: 0, x2: 10, y2: 10)
      print(h.nbLines, h.nbIntervals(lineIndex: 1))
  }
  ```

---

### `HatchBuilder.nbLines`

Total number of hatch lines added.

```swift
public var nbLines: Int
```

- **OCCT:** `Hatch_Hatcher::NbLines`.

---

### `HatchBuilder.nbIntervals(lineIndex:)`

Number of trimmed intervals on a given hatch line (1-based).

```swift
public func nbIntervals(lineIndex: Int) -> Int
```

- **Parameters:** `lineIndex` — 1-based line index.
- **OCCT:** `Hatch_Hatcher::NbIntervals`.

---

## Edge/Face Extraction

Extensions on `Shape` for extracting low-level geometry from edge, face, and vertex sub-shapes (v0.107.0).

### `Shape.extractEdgeCurve3D()`

Extract the 3D curve and its parameter range from an edge shape.

```swift
public func extractEdgeCurve3D() -> (curve: Curve3D, first: Double, last: Double)?
```

- **Returns:** A tuple of the curve handle and parameter bounds, or `nil` if the edge has no 3D curve.
- **OCCT:** `BRep_Tool::Curve`.
- **Example:**
  ```swift
  for edge in shape.edges() {
      if let (c, t0, t1) = edge.extractEdgeCurve3D() {
          let pt = c.point(at: (t0 + t1) / 2)
      }
  }
  ```

---

### `Shape.extractEdgePCurve(onFace:)`

Extract the PCurve (2D curve on surface) of an edge relative to a face.

```swift
public func extractEdgePCurve(onFace face: Shape) -> (curve: Curve2D, first: Double, last: Double)?
```

- **Parameters:** `face` — the face on whose surface the PCurve lives.
- **Returns:** 2D curve and parameter bounds, or `nil` if none exists.
- **OCCT:** `BRep_Tool::CurveOnSurface`.

---

### `Shape.edgeTolerance`

Geometric tolerance stored on an edge shape.

```swift
public var edgeTolerance: Double
```

- **OCCT:** `BRep_Tool::Tolerance` (edge overload).

---

### `Shape.isEdgeDegenerated`

Whether the edge is degenerated (collapsed to a single point).

```swift
public var isEdgeDegenerated: Bool
```

- **OCCT:** `BRep_Tool::Degenerated`.

---

### `Shape.extractFaceSurface()`

Extract the carrier surface from a face shape.

```swift
public func extractFaceSurface() -> Surface?
```

- **Returns:** The face's `Geom_Surface`, or `nil` if the shape is not a face.
- **OCCT:** `BRep_Tool::Surface`.

---

### `Shape.faceTolerance`

Geometric tolerance stored on a face shape.

```swift
public var faceTolerance: Double
```

- **OCCT:** `BRep_Tool::Tolerance` (face overload).

---

### `Shape.faceWireCount`

Number of wire boundaries on a face shape.

```swift
public var faceWireCount: Int
```

- **OCCT:** `TopoDS_Face` wire iterator count.

---

### `Shape.vertexTolerance`

Geometric tolerance stored on a vertex shape.

```swift
public var vertexTolerance: Double
```

- **OCCT:** `BRep_Tool::Tolerance` (vertex overload).

---

### `Shape.vertexPoint`

3D point associated with a vertex shape.

```swift
public var vertexPoint: SIMD3<Double>
```

- **OCCT:** `BRep_Tool::Pnt`.

---

## Extrema Elementary Distances

Closed-form minimum/maximum distance computations between analytic geometry primitives (v0.109.0). All results are returned as `[ExtremaResult]` or `(isParallel: Bool, results: [ExtremaResult])` where relevant.

### `ExtremaResult`

Carrier value type for a single extremum solution.

```swift
public struct ExtremaResult: Sendable {
    public let squareDistance: Double
    public let point1: SIMD3<Double>
    public let point2: SIMD3<Double>
}
```

- `squareDistance` — squared Euclidean distance at this extremum.
- `point1` — closest/farthest point on the first geometric element.
- `point2` — closest/farthest point on the second geometric element.

---

### `ExtremaElC.lineToLine(line1Point:line1Dir:line2Point:line2Dir:tolerance:)`

Closed-form extrema between two infinite 3D lines.

```swift
public static func lineToLine(
    line1Point: SIMD3<Double>, line1Dir: SIMD3<Double>,
    line2Point: SIMD3<Double>, line2Dir: SIMD3<Double>,
    tolerance: Double = 1e-6
) -> (isParallel: Bool, results: [ExtremaResult])
```

- **Returns:** `isParallel` is `true` when the lines are parallel (infinitely many solutions — check this before using `results`); otherwise `results` holds 1–2 extrema.
- **OCCT:** `Extrema_ExtElC` (line–line).
- **Example:**
  ```swift
  let r = ExtremaElC.lineToLine(
      line1Point: .zero, line1Dir: SIMD3(1, 0, 0),
      line2Point: SIMD3(0, 5, 0), line2Dir: SIMD3(1, 0, 0)
  )
  if !r.isParallel, let e = r.results.first {
      print(sqrt(e.squareDistance)) // 5.0
  }
  ```

---

### `ExtremaElC.lineToCircle(linePoint:lineDir:circleCenter:circleNormal:radius:tolerance:)`

Closed-form extrema between a 3D line and a circle.

```swift
public static func lineToCircle(
    linePoint: SIMD3<Double>, lineDir: SIMD3<Double>,
    circleCenter: SIMD3<Double>, circleNormal: SIMD3<Double>, radius: Double,
    tolerance: Double = 1e-6
) -> [ExtremaResult]
```

- **OCCT:** `Extrema_ExtElC` (line–circle).

---

### `ExtremaElC.circleToCircle(center1:normal1:radius1:center2:normal2:radius2:)`

Closed-form extrema between two 3D circles.

```swift
public static func circleToCircle(
    center1: SIMD3<Double>, normal1: SIMD3<Double>, radius1: Double,
    center2: SIMD3<Double>, normal2: SIMD3<Double>, radius2: Double
) -> [ExtremaResult]
```

- **OCCT:** `Extrema_ExtElC` (circle–circle).

---

### `ExtremaElC.lineToEllipse(linePoint:lineDir:center:normal:xDir:majorRadius:minorRadius:tolerance:)`

Closed-form extrema between a 3D line and an ellipse.

```swift
public static func lineToEllipse(
    linePoint: SIMD3<Double>, lineDir: SIMD3<Double>,
    center: SIMD3<Double>, normal: SIMD3<Double>, xDir: SIMD3<Double>,
    majorRadius: Double, minorRadius: Double,
    tolerance: Double = 1e-6
) -> [ExtremaResult]
```

- **OCCT:** `Extrema_ExtElC` (line–ellipse).

---

### `ExtremaElCS.lineToPlane(linePoint:lineDir:planePoint:planeNormal:)`

Closed-form extrema between a line and a plane.

```swift
public static func lineToPlane(
    linePoint: SIMD3<Double>, lineDir: SIMD3<Double>,
    planePoint: SIMD3<Double>, planeNormal: SIMD3<Double>
) -> (isParallel: Bool, results: [ExtremaResult])
```

- **Returns:** `isParallel` is `true` when line lies in the plane; otherwise one extremum.
- **OCCT:** `Extrema_ExtElCS` (line–plane).

---

### `ExtremaElCS.lineToSphere(linePoint:lineDir:sphereCenter:sphereRadius:)`

Closed-form extrema between a line and a sphere.

```swift
public static func lineToSphere(
    linePoint: SIMD3<Double>, lineDir: SIMD3<Double>,
    sphereCenter: SIMD3<Double>, sphereRadius: Double
) -> [ExtremaResult]
```

- **OCCT:** `Extrema_ExtElCS` (line–sphere).

---

### `ExtremaElCS.lineToCylinder(linePoint:lineDir:cylCenter:cylAxis:cylRadius:)`

Closed-form extrema between a line and a cylinder.

```swift
public static func lineToCylinder(
    linePoint: SIMD3<Double>, lineDir: SIMD3<Double>,
    cylCenter: SIMD3<Double>, cylAxis: SIMD3<Double>, cylRadius: Double
) -> [ExtremaResult]
```

- **OCCT:** `Extrema_ExtElCS` (line–cylinder).

---

### `ExtremaElSS.planeToPlane(plane1Point:plane1Normal:plane2Point:plane2Normal:)`

Closed-form extrema between two planes.

```swift
public static func planeToPlane(
    plane1Point: SIMD3<Double>, plane1Normal: SIMD3<Double>,
    plane2Point: SIMD3<Double>, plane2Normal: SIMD3<Double>
) -> (isParallel: Bool, results: [ExtremaResult])
```

- **OCCT:** `Extrema_ExtElSS` (plane–plane).

---

### `ExtremaElSS.planeToSphere(planePoint:planeNormal:sphereCenter:sphereRadius:)`

Closed-form extrema between a plane and a sphere.

```swift
public static func planeToSphere(
    planePoint: SIMD3<Double>, planeNormal: SIMD3<Double>,
    sphereCenter: SIMD3<Double>, sphereRadius: Double
) -> [ExtremaResult]
```

- **OCCT:** `Extrema_ExtElSS` (plane–sphere).

---

### `ExtremaElSS.sphereToSphere(center1:radius1:center2:radius2:)`

Closed-form extrema between two spheres.

```swift
public static func sphereToSphere(
    center1: SIMD3<Double>, radius1: Double,
    center2: SIMD3<Double>, radius2: Double
) -> [ExtremaResult]
```

- **OCCT:** `Extrema_ExtElSS` (sphere–sphere).

---

### `ExtremaPointCurve.pointToLine(point:lineOrigin:lineDir:tolerance:)`

Closed-form nearest/farthest point from a 3D point to an infinite line.

```swift
public static func pointToLine(
    point: SIMD3<Double>,
    lineOrigin: SIMD3<Double>, lineDir: SIMD3<Double>,
    tolerance: Double = 1e-6
) -> [ExtremaResult]
```

- **OCCT:** `Extrema_ExtPElC` (point–line).

---

### `ExtremaPointCurve.pointToCircle(point:center:normal:radius:tolerance:)`

Closed-form nearest/farthest point from a 3D point to a circle.

```swift
public static func pointToCircle(
    point: SIMD3<Double>,
    center: SIMD3<Double>, normal: SIMD3<Double>, radius: Double,
    tolerance: Double = 1e-6
) -> [ExtremaResult]
```

- **OCCT:** `Extrema_ExtPElC` (point–circle).
- **Example:**
  ```swift
  let pts = ExtremaPointCurve.pointToCircle(
      point: SIMD3(0, 0, 5),
      center: .zero, normal: SIMD3(0, 0, 1), radius: 3
  )
  if let nearest = pts.min(by: { $0.squareDistance < $1.squareDistance }) {
      print(sqrt(nearest.squareDistance))
  }
  ```

---

### `ExtremaPointCurve.pointToEllipse(point:center:normal:xDir:majorRadius:minorRadius:tolerance:)`

Closed-form nearest/farthest point from a 3D point to an ellipse.

```swift
public static func pointToEllipse(
    point: SIMD3<Double>,
    center: SIMD3<Double>, normal: SIMD3<Double>, xDir: SIMD3<Double>,
    majorRadius: Double, minorRadius: Double,
    tolerance: Double = 1e-6
) -> [ExtremaResult]
```

- **OCCT:** `Extrema_ExtPElC` (point–ellipse).

---

### `ExtremaPointCurve.pointToParabola(point:center:normal:xDir:focal:tolerance:)`

Closed-form nearest/farthest point from a 3D point to a parabola.

```swift
public static func pointToParabola(
    point: SIMD3<Double>,
    center: SIMD3<Double>, normal: SIMD3<Double>, xDir: SIMD3<Double>,
    focal: Double,
    tolerance: Double = 1e-6
) -> [ExtremaResult]
```

- **Parameters:** `focal` — focal parameter of the parabola.
- **OCCT:** `Extrema_ExtPElC` (point–parabola).

---

### `ExtremaPointSurface.pointToPlane(point:planePoint:planeNormal:tolerance:)`

Closed-form nearest/farthest point from a 3D point to a plane.

```swift
public static func pointToPlane(
    point: SIMD3<Double>,
    planePoint: SIMD3<Double>, planeNormal: SIMD3<Double>,
    tolerance: Double = 1e-6
) -> [ExtremaResult]
```

- **OCCT:** `Extrema_ExtPElS` (point–plane).

---

### `ExtremaPointSurface.pointToSphere(point:center:radius:tolerance:)`

Closed-form nearest/farthest point from a 3D point to a sphere.

```swift
public static func pointToSphere(
    point: SIMD3<Double>,
    center: SIMD3<Double>, radius: Double,
    tolerance: Double = 1e-6
) -> [ExtremaResult]
```

- **OCCT:** `Extrema_ExtPElS` (point–sphere).

---

### `ExtremaPointSurface.pointToCylinder(point:center:axis:radius:tolerance:)`

Closed-form nearest/farthest point from a 3D point to a cylinder.

```swift
public static func pointToCylinder(
    point: SIMD3<Double>,
    center: SIMD3<Double>, axis: SIMD3<Double>, radius: Double,
    tolerance: Double = 1e-6
) -> [ExtremaResult]
```

- **OCCT:** `Extrema_ExtPElS` (point–cylinder).

---

### `ExtremaPointSurface.pointToCone(point:apex:axis:semiAngle:refRadius:tolerance:)`

Closed-form nearest/farthest point from a 3D point to a cone.

```swift
public static func pointToCone(
    point: SIMD3<Double>,
    apex: SIMD3<Double>, axis: SIMD3<Double>,
    semiAngle: Double, refRadius: Double,
    tolerance: Double = 1e-6
) -> [ExtremaResult]
```

- **Parameters:** `semiAngle` — cone half-angle in radians; `refRadius` — reference radius at the apex plane.
- **OCCT:** `Extrema_ExtPElS` (point–cone).

---

### `ExtremaPointSurface.pointToTorus(point:center:axis:majorRadius:minorRadius:tolerance:)`

Closed-form nearest/farthest point from a 3D point to a torus.

```swift
public static func pointToTorus(
    point: SIMD3<Double>,
    center: SIMD3<Double>, axis: SIMD3<Double>,
    majorRadius: Double, minorRadius: Double,
    tolerance: Double = 1e-6
) -> [ExtremaResult]
```

- **OCCT:** `Extrema_ExtPElS` (point–torus).

---

## math_TrigonometricFunctionRoots

`TrigRoots` solves equations of the form `A·cos(x) + B·sin(x) + C·cos(2x) + D·sin(2x) + E = 0` over a specified interval (v0.109.0).

### `TrigRoots.solve(A:B:C:D:E:from:to:)`

Find all roots of the trigonometric polynomial in `[inf, sup]`.

```swift
public static func solve(
    A: Double = 0, B: Double = 0, C: Double = 0, D: Double = 0, E: Double = 0,
    from inf: Double, to sup: Double
) -> [Double]
```

- **Parameters:** `A`–`E` — equation coefficients; `inf`/`sup` — parameter interval.
- **Returns:** Array of root values in `[inf, sup]`, or empty if no roots exist.
- **OCCT:** `math_TrigonometricFunctionRoots`.
- **Example:**
  ```swift
  // Solve sin(x) = 0 on [0, 2π]
  let roots = TrigRoots.solve(B: 1, from: 0, to: 2 * .pi)
  // roots ≈ [0.0, π, 2π]
  ```

---

### `TrigRoots.hasInfiniteRoots(A:B:C:D:E:from:to:)`

Check whether all values in `[inf, sup]` satisfy the equation (the equation is identically zero on the interval).

```swift
public static func hasInfiniteRoots(
    A: Double = 0, B: Double = 0, C: Double = 0, D: Double = 0, E: Double = 0,
    from inf: Double, to sup: Double
) -> Bool
```

- **Returns:** `true` if the equation is identically satisfied throughout `[inf, sup]`.
- **OCCT:** `math_TrigonometricFunctionRoots::InfiniteRoots`.
