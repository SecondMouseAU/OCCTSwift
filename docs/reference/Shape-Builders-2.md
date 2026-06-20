---
title: Shape — Builders & Boolean Internals II
parent: API Reference
---

# Shape — Builders & Boolean Internals II

Continuation of the low-level builder and algorithm wrappers on `Shape` — covering GeomFill sweep/evolved-section, projection, offset, iso-curve evaluation, parameter transfer, boolean section/feature removal, shape build/extend/upgrade utilities, 2D vector math, topological transition analysis, GeomFill trihedrons, 2D polygon interference, analytical 2D circle construction, IntTools intersection, BOPAlgo builders, BRepFeat split/hole/glue, LocOpe split/glue, and 2D chamfer/fillet APIs.

See also: **[Shape](Shape.md)** (index).

## Topics

- [GeomFill\_Sweep](#geomfill_sweep) · [GeomFill\_EvolvedSection](#geomfill_evolvedsection) · [ProjLib\_ComputeApprox](#projlib_computeapprox) · [BRepOffset\_Offset](#brepoffset_offset) · [Adaptor3d\_IsoCurve](#adaptor3d_isocurve) · [ShapeAnalysis\_TransferParametersProj](#shapeanalysis_transferparametersrproj) · [BOPAlgo\_RemoveFeatures](#bopalgo_removefeatures) · [BOPAlgo\_Section](#bopalgo_section) · [ShapeBuild\_Edge](#shapebuild_edge) · [ShapeBuild\_Vertex](#shapebuild_vertex) · [ShapeExtend\_Explorer](#shapeextend_explorer) · [ShapeUpgrade\_FaceDivide](#shapeupgrade_facedivide) · [ShapeUpgrade\_WireDivide](#shapeupgrade_wiredivide) · [ShapeUpgrade\_EdgeDivide](#shapeupgrade_edgedivide) · [ShapeUpgrade\_ClosedEdgeDivide](#shapeupgrade_closededgedivide) · [ShapeUpgrade\_FixSmallCurves](#shapeupgrade_fixsmallcurves) · [ShapeUpgrade\_FixSmallBezierCurves](#shapeupgrade_fixsmallbeziercurves) · [ShapeUpgrade\_ConvertCurve3dToBezier](#shapeupgrade_convertcurve3dtobezier) · [ShapeUpgrade\_ConvertSurfaceToBezierBasis](#shapeupgrade_convertsurfacetobezierbasis) · [2D Vector/Direction Utilities & LProp](#2d-vectordirection-utilities--lprop) · [TopTrans Surface Transition](#toptrans-surface-transition) · [TopTrans Curve Transition](#toptrans-curve-transition) · [GeomFill Trihedrons](#geomfill-trihedrons) · [Polygon Interference](#polygon-interference) · [GccAna\_Circ2d3Tan](#gccana_circ2d3tan) · [IntTools](#inttools) · [BOPAlgo Builder](#bopalgo-builder) · [BOPTools](#boptools) · [IntTools\_BeanFaceIntersector](#inttools_beanfaceintersector) · [BOPAlgo\_WireSplitter](#bopalgo_wiresplitter) · [BRepFeat\_SplitShape](#brepfeat_splitshape) · [BRepFeat\_MakeCylindricalHole](#brepfeat_makecylindricalhole) · [BRepFeat\_Gluer](#brepfeat_gluer) · [LocOpe\_WiresOnShape + LocOpe\_Spliter](#locope_wiresonshape--locope_spliter) · [LocOpe\_Gluer](#locope_gluer) · [ChFi2d\_Builder](#chfi2d_builder) · [ChFi2d\_ChamferAPI](#chfi2d_chamferapi) · [ChFi2d\_FilletAPI](#chfi2d_filletapi) · [FilletSurf\_Builder](#filletsorf_builder)

---

## GeomFill\_Sweep

### `Shape.geomFillSweep(path:section:)`

Sweep a section edge along a path edge to create a surface face.

```swift
public static func geomFillSweep(path: Shape, section: Shape) -> Shape?
```

- **Parameters:** `path` — edge defining the sweep path. `section` — edge defining the cross-section profile.
- **Returns:** A `Shape` wrapping the swept face, or `nil` on failure.
- **OCCT:** `GeomFill_Sweep`
- **Example:**
  ```swift
  if let face = Shape.geomFillSweep(path: pathEdge, section: sectionEdge) {
      // face is a swept surface
  }
  ```

---

## GeomFill\_EvolvedSection

### `evolvedSectionInfo()`

Get evolved section info for an edge curve.

```swift
public func evolvedSectionInfo() -> EvolvedSectionInfo
```

- **Returns:** `EvolvedSectionInfo` with `nbPoles`, `nbKnots`, `degree`, and `isRational`.
- **OCCT:** `GeomFill_EvolvedSection`
- **Example:**
  ```swift
  let info = edge.evolvedSectionInfo()
  print(info.degree, info.isRational)
  ```

---

## ProjLib\_ComputeApprox

### `projectOntoSurface(_:tolerance:)`

Project this edge's 3D curve onto a face's surface, returning an edge-on-surface.

```swift
public func projectOntoSurface(_ face: Shape, tolerance: Double = 1e-3) -> Shape?
```

- **Parameters:** `face` — target face. `tolerance` — approximation tolerance.
- **Returns:** Projected edge as shape, or `nil` on failure.
- **OCCT:** `ProjLib_ComputeApprox`
- **Example:**
  ```swift
  if let proj = edge.projectOntoSurface(face) { }
  ```

---

### `projectOntoPolarSurface(_:tolerance:)`

Project this edge's 3D curve onto a polar surface (sphere, torus).

```swift
public func projectOntoPolarSurface(_ face: Shape, tolerance: Double = 1e-3) -> Shape?
```

- **Parameters:** `face` — polar face. `tolerance` — approximation tolerance.
- **Returns:** Projected edge as shape, or `nil` on failure.
- **OCCT:** `ProjLib_ComputeApproxOnPolarSurface`
- **Example:**
  ```swift
  if let proj = edge.projectOntoPolarSurface(sphereFace) { }
  ```

---

## BRepOffset\_Offset

### `offsetFace(distance:)`

Offset a face by a distance, creating a new offset face.

```swift
public func offsetFace(distance: Double) -> Shape?
```

- **Parameters:** `distance` — signed offset amount; positive moves along the face normal.
- **Returns:** Offset face, or `nil` on failure.
- **OCCT:** `BRepOffset_Offset`
- **Example:**
  ```swift
  if let off = face.offsetFace(distance: 2.0) { }
  ```

---

## Adaptor3d\_IsoCurve

### `uIsoCurvePoints(u:count:)`

Evaluate sample points along a U-iso curve on a face.

```swift
public func uIsoCurvePoints(u: Double, count: Int = 20) -> [SIMD3<Double>]
```

- **Parameters:** `u` — U parameter value. `count` — number of sample points.
- **Returns:** Array of 3D points along the iso curve.
- **OCCT:** `Adaptor3d_IsoCurve` (iso kind 0 = U)
- **Example:**
  ```swift
  let pts = face.uIsoCurvePoints(u: 0.5, count: 50)
  ```

---

### `vIsoCurvePoints(v:count:)`

Evaluate sample points along a V-iso curve on a face.

```swift
public func vIsoCurvePoints(v: Double, count: Int = 20) -> [SIMD3<Double>]
```

- **Parameters:** `v` — V parameter value. `count` — number of sample points.
- **Returns:** Array of 3D points along the iso curve.
- **OCCT:** `Adaptor3d_IsoCurve` (iso kind 1 = V)
- **Example:**
  ```swift
  let pts = face.vIsoCurvePoints(v: 0.25)
  ```

---

### `uIsoCurveEdge(u:vMin:vMax:)`

Extract a U-iso curve from a face as an edge.

```swift
public func uIsoCurveEdge(u: Double, vMin: Double, vMax: Double) -> Shape?
```

- **Parameters:** `u` — U parameter. `vMin`/`vMax` — V parameter range for the edge.
- **Returns:** Edge shape representing the iso curve, or `nil` on failure.
- **OCCT:** `Adaptor3d_IsoCurve`
- **Example:**
  ```swift
  if let e = face.uIsoCurveEdge(u: 0.5, vMin: 0, vMax: 1) { }
  ```

---

### `vIsoCurveEdge(v:uMin:uMax:)`

Extract a V-iso curve from a face as an edge.

```swift
public func vIsoCurveEdge(v: Double, uMin: Double, uMax: Double) -> Shape?
```

- **Parameters:** `v` — V parameter. `uMin`/`uMax` — U parameter range for the edge.
- **Returns:** Edge shape representing the iso curve, or `nil` on failure.
- **OCCT:** `Adaptor3d_IsoCurve`
- **Example:**
  ```swift
  if let e = face.vIsoCurveEdge(v: 0.5, uMin: 0, uMax: 1) { }
  ```

---

## ShapeAnalysis\_TransferParametersProj

### `transferParameterToFace(_:face:)`

Transfer a parameter from edge to face coordinate system via projection.

```swift
public func transferParameterToFace(_ param: Double, face: Shape) -> Double
```

- **Parameters:** `param` — edge parameter. `face` — face to transfer into.
- **Returns:** Corresponding parameter in the face's coordinate system.
- **OCCT:** `ShapeAnalysis_TransferParametersProj` (toFace = true)
- **Example:**
  ```swift
  let faceParam = edge.transferParameterToFace(0.5, face: face)
  ```

---

### `transferParameterFromFace(_:face:)`

Transfer a parameter from face to edge coordinate system via projection.

```swift
public func transferParameterFromFace(_ param: Double, face: Shape) -> Double
```

- **Parameters:** `param` — face parameter. `face` — face to transfer from.
- **Returns:** Corresponding parameter in the edge's coordinate system.
- **OCCT:** `ShapeAnalysis_TransferParametersProj` (toFace = false)
- **Example:**
  ```swift
  let edgeParam = edge.transferParameterFromFace(0.5, face: face)
  ```

---

## BOPAlgo\_RemoveFeatures

### `removeFeatures(faces:)`

Remove features (faces) from a solid shape, healing the result.

```swift
public func removeFeatures(faces: [Shape]) -> Shape?
```

- **Parameters:** `faces` — array of face shapes to remove (e.g. fillets, boss faces, holes).
- **Returns:** Healed shape with features removed, or `nil` on failure.
- **OCCT:** `BOPAlgo_RemoveFeatures`
- **Example:**
  ```swift
  let faces = solid.subShapes(ofType: .face)
  if let cleaned = solid.removeFeatures(faces: [faces[2]]) { }
  ```

---

## BOPAlgo\_Section

### `section(with:)`

Compute section (intersection curves/vertices) between this shape and tools.

```swift
public func section(with tools: [Shape]) -> Shape?
```

- **Parameters:** `tools` — tool shapes to intersect with this shape.
- **Returns:** Compound of intersection edges and vertices, or `nil` on failure.
- **OCCT:** `BOPAlgo_Section`
- **Example:**
  ```swift
  if let sect = solid.section(with: [plane]) { }
  ```

---

### `Shape.section(shapes:)`

Compute section between multiple shapes (static variant).

```swift
public static func section(shapes: [Shape]) -> Shape?
```

- **Parameters:** `shapes` — at least 2 shapes; all are treated as equal arguments.
- **Returns:** Compound of intersection edges and vertices, or `nil` on failure (requires ≥ 2 shapes).
- **OCCT:** `BOPAlgo_Section`
- **Example:**
  ```swift
  if let sect = Shape.section(shapes: [box, sphere]) { }
  ```

---

## ShapeBuild\_Edge

### `copyEdge(sharePCurves:)`

Copy an edge, optionally sharing its PCurves with the original.

```swift
public func copyEdge(sharePCurves: Bool = true) -> Shape?
```

- **Parameters:** `sharePCurves` — if `true`, the copy shares PCurves with the original edge.
- **Returns:** Copied edge as shape, or `nil` on failure.
- **OCCT:** `ShapeBuild_Edge::Copy`
- **Example:**
  ```swift
  if let copy = edge.copyEdge() { }
  ```

---

### `copyEdgeReplacingVertices(startVertex:endVertex:)`

Copy an edge, replacing its start and/or end vertices.

```swift
public func copyEdgeReplacingVertices(startVertex: Shape?, endVertex: Shape?) -> Shape?
```

- **Parameters:** `startVertex` — new start vertex, or `nil` to keep original. `endVertex` — new end vertex, or `nil` to keep original.
- **Returns:** Edge with replaced vertices, or `nil` on failure.
- **OCCT:** `ShapeBuild_Edge::CopyReplaceVertices`
- **Example:**
  ```swift
  if let e = edge.copyEdgeReplacingVertices(startVertex: v1, endVertex: nil) { }
  ```

---

### `setEdgeRange3d(first:last:)`

Set the 3D parameter range on this edge shape.

```swift
public func setEdgeRange3d(first: Double, last: Double)
```

- **Parameters:** `first` — start parameter. `last` — end parameter.
- **OCCT:** `ShapeBuild_Edge::SetRange3d`
- **Example:**
  ```swift
  edge.setEdgeRange3d(first: 0, last: 1)
  ```

---

### `buildEdgeCurve3d()`

Rebuild the 3D curve of an edge from its PCurves.

```swift
@discardableResult
public func buildEdgeCurve3d() -> Bool
```

- **Returns:** `true` if the curve was rebuilt successfully.
- **OCCT:** `ShapeBuild_Edge::BuildCurve3d`
- **Example:**
  ```swift
  edge.buildEdgeCurve3d()
  ```

---

### `removeEdgeCurve3d()`

Remove the 3D curve from this edge.

```swift
public func removeEdgeCurve3d()
```

- **OCCT:** `ShapeBuild_Edge::RemoveCurve3d`
- **Example:**
  ```swift
  edge.removeEdgeCurve3d()
  ```

---

### `copyEdgeRanges(from:)`

Copy parameter ranges from another edge to this edge.

```swift
public func copyEdgeRanges(from source: Shape)
```

- **Parameters:** `source` — edge from which to copy ranges.
- **OCCT:** `ShapeBuild_Edge::CopyRanges`
- **Example:**
  ```swift
  edge.copyEdgeRanges(from: sourceEdge)
  ```

---

### `copyEdgePCurves(from:)`

Copy PCurves from another edge to this edge.

```swift
public func copyEdgePCurves(from source: Shape)
```

- **Parameters:** `source` — edge from which to copy PCurves.
- **OCCT:** `ShapeBuild_Edge::CopyPCurves`
- **Example:**
  ```swift
  edge.copyEdgePCurves(from: sourceEdge)
  ```

---

### `removeEdgePCurve(onFace:)`

Remove the PCurve from this edge for a given face.

```swift
public func removeEdgePCurve(onFace face: Shape)
```

- **Parameters:** `face` — the face whose PCurve should be removed from this edge.
- **OCCT:** `ShapeBuild_Edge::RemovePCurve`
- **Example:**
  ```swift
  edge.removeEdgePCurve(onFace: face)
  ```

---

### `reassignEdgePCurve(from:to:)`

Reassign a PCurve from one face to another.

```swift
@discardableResult
public func reassignEdgePCurve(from oldFace: Shape, to newFace: Shape) -> Bool
```

- **Parameters:** `oldFace` — face that currently holds the PCurve. `newFace` — destination face.
- **Returns:** `true` if reassignment succeeded.
- **OCCT:** `ShapeBuild_Edge::ReassignPCurve`
- **Example:**
  ```swift
  edge.reassignEdgePCurve(from: oldFace, to: newFace)
  ```

---

## ShapeBuild\_Vertex

### `combineVertex(with:tolFactor:)`

Combine this vertex shape with another at their average position.

```swift
public func combineVertex(with other: Shape, tolFactor: Double = 1.0001) -> Shape?
```

- **Parameters:** `other` — vertex to combine with. `tolFactor` — tolerance scale factor.
- **Returns:** Combined vertex as shape, or `nil` on failure.
- **OCCT:** `ShapeBuild_Vertex::CombineVertex`
- **Example:**
  ```swift
  if let v = v1.combineVertex(with: v2) { }
  ```

---

### `Shape.combineVertices(point1:tol1:point2:tol2:tolFactor:)`

Create a vertex by combining two 3D points with tolerances.

```swift
public static func combineVertices(
    point1: SIMD3<Double>, tol1: Double,
    point2: SIMD3<Double>, tol2: Double,
    tolFactor: Double = 1.0001
) -> Shape?
```

- **Parameters:** `point1`/`tol1` — first point and its tolerance. `point2`/`tol2` — second point and its tolerance. `tolFactor` — scale factor applied to the combined tolerance.
- **Returns:** Combined vertex, or `nil` on failure.
- **OCCT:** `ShapeBuild_Vertex::CombineVertex` (from points)
- **Example:**
  ```swift
  if let v = Shape.combineVertices(point1: .zero, tol1: 1e-7, point2: SIMD3(0,0,0.001), tol2: 1e-7) { }
  ```

---

## ShapeExtend\_Explorer

### `ShapeFilterType`

Shape type enum for filtering compounds.

```swift
public enum ShapeFilterType: Int32, Sendable {
    case compound = 0, compsolid = 1, solid = 2, shell = 3
    case face = 4, wire = 5, edge = 6, vertex = 7
}
```

Matches `TopAbs_ShapeEnum` values used by `ShapeExtend_Explorer`.

---

### `sortedCompound(type:explore:)`

Filter this compound, extracting only sub-shapes of the specified type.

```swift
public func sortedCompound(type: ShapeFilterType, explore: Bool = true) -> Shape?
```

- **Parameters:** `type` — target shape type. `explore` — if `true`, recurse into sub-compounds.
- **Returns:** Compound of matching sub-shapes, or `nil` on failure.
- **OCCT:** `ShapeExtend_Explorer::SortedCompound`
- **Example:**
  ```swift
  if let faces = compound.sortedCompound(type: .face) { }
  ```

---

### `predominantShapeType(lookInsideCompounds:)`

Get the predominant shape type in this compound.

```swift
public func predominantShapeType(lookInsideCompounds: Bool = true) -> ShapeFilterType
```

- **Parameters:** `lookInsideCompounds` — if `true`, inspect sub-compounds.
- **Returns:** The most-common `ShapeFilterType` found.
- **OCCT:** `ShapeExtend_Explorer::ShapeType`
- **Example:**
  ```swift
  let t = compound.predominantShapeType()
  ```

---

## ShapeUpgrade\_FaceDivide

### `divideFace()`

Divide a face using surface segmentation.

```swift
public func divideFace() -> Shape?
```

- **Returns:** Divided shape, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_FaceDivide`
- **Example:**
  ```swift
  if let divided = face.divideFace() { }
  ```

---

## ShapeUpgrade\_WireDivide

### `divideWire(onFace:)`

Divide a wire on a face.

```swift
public func divideWire(onFace face: Shape) -> Shape?
```

- **Parameters:** `face` — face the wire lies on.
- **Returns:** Divided wire as shape, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_WireDivide`
- **Example:**
  ```swift
  if let w = wire.divideWire(onFace: face) { }
  ```

---

## ShapeUpgrade\_EdgeDivide

### `EdgeDivideResult`

Result of an edge divide analysis.

```swift
public struct EdgeDivideResult: Sendable {
    public let hasCurve2d: Bool
    public let hasCurve3d: Bool
}
```

---

### `analyzeEdgeDivide(onFace:)`

Analyze an edge for potential division on a face.

```swift
public func analyzeEdgeDivide(onFace face: Shape) -> EdgeDivideResult?
```

- **Parameters:** `face` — face context for the edge.
- **Returns:** Analysis result indicating 2D/3D curve presence, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_EdgeDivide::Compute`
- **Example:**
  ```swift
  if let r = edge.analyzeEdgeDivide(onFace: face) {
      print(r.hasCurve3d)
  }
  ```

---

## ShapeUpgrade\_ClosedEdgeDivide

### `canDivideClosedEdge(onFace:)`

Check if a closed (seam) edge can be divided on a face.

```swift
public func canDivideClosedEdge(onFace face: Shape) -> Bool
```

- **Parameters:** `face` — face context.
- **Returns:** `true` if the edge is closed and divisible.
- **OCCT:** `ShapeUpgrade_ClosedEdgeDivide::Compute`
- **Example:**
  ```swift
  if edge.canDivideClosedEdge(onFace: face) { }
  ```

---

## ShapeUpgrade\_FixSmallCurves

### `fixSmallCurves(tolerance:)`

Fix small curves in this shape.

```swift
public func fixSmallCurves(tolerance: Double = 1e-6) -> Shape?
```

- **Parameters:** `tolerance` — threshold below which curves are considered small.
- **Returns:** Fixed shape, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_FixSmallCurves`
- **Example:**
  ```swift
  if let fixed = shape.fixSmallCurves() { }
  ```

---

## ShapeUpgrade\_FixSmallBezierCurves

### `fixSmallBezierCurves(tolerance:)`

Fix small Bezier curves in this shape.

```swift
public func fixSmallBezierCurves(tolerance: Double = 1e-6) -> Shape?
```

- **Parameters:** `tolerance` — detection threshold.
- **Returns:** Fixed shape, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_FixSmallBezierCurves`
- **Example:**
  ```swift
  if let fixed = shape.fixSmallBezierCurves() { }
  ```

---

## ShapeUpgrade\_ConvertCurve3dToBezier

### `convertCurves3dToBezier(lineMode:circleMode:conicMode:)`

Convert 3D curves in this shape to Bezier representation.

```swift
public func convertCurves3dToBezier(lineMode: Bool = true, circleMode: Bool = true,
                                     conicMode: Bool = true) -> Shape?
```

- **Parameters:** `lineMode` — convert line segments. `circleMode` — convert circles. `conicMode` — convert other conics.
- **Returns:** Shape with Bezier curves, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_ConvertCurve3dToBezier`
- **Example:**
  ```swift
  if let bez = shape.convertCurves3dToBezier(lineMode: false) { }
  ```

---

## ShapeUpgrade\_ConvertSurfaceToBezierBasis

### `convertSurfacesToBezier(planeMode:revolutionMode:extrusionMode:bsplineMode:)`

Convert surfaces in this shape to Bezier patches.

```swift
public func convertSurfacesToBezier(planeMode: Bool = true, revolutionMode: Bool = true,
                                     extrusionMode: Bool = true, bsplineMode: Bool = true) -> Shape?
```

- **Parameters:** `planeMode` — convert planes. `revolutionMode` — convert revolution surfaces. `extrusionMode` — convert extrusions. `bsplineMode` — convert BSpline surfaces.
- **Returns:** Shape with Bezier surfaces, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_ConvertSurfaceToBezierBasis`
- **Example:**
  ```swift
  if let bez = shape.convertSurfacesToBezier(bsplineMode: false) { }
  ```

---

## 2D Vector/Direction Utilities & LProp

### `Shape.vector2DAngle(a:b:)`

Signed angle between two 2D vectors, in radians (range −π to π).

```swift
public static func vector2DAngle(a: SIMD2<Double>, b: SIMD2<Double>) -> Double
```

- **OCCT:** `gp_Vec2d::Angle`
- **Example:**
  ```swift
  let angle = Shape.vector2DAngle(a: SIMD2(1, 0), b: SIMD2(0, 1))  // π/2
  ```

---

### `Shape.vector2DCross(a:b:)`

Cross product of two 2D vectors (scalar Z component).

```swift
public static func vector2DCross(a: SIMD2<Double>, b: SIMD2<Double>) -> Double
```

- **OCCT:** `gp_Vec2d::Crossed`
- **Example:**
  ```swift
  let z = Shape.vector2DCross(a: SIMD2(1, 0), b: SIMD2(0, 1))  // 1.0
  ```

---

### `Shape.vector2DDot(a:b:)`

Dot product of two 2D vectors.

```swift
public static func vector2DDot(a: SIMD2<Double>, b: SIMD2<Double>) -> Double
```

- **OCCT:** `gp_Vec2d::Dot`
- **Example:**
  ```swift
  let d = Shape.vector2DDot(a: SIMD2(1, 0), b: SIMD2(0.5, 0.5))
  ```

---

### `Shape.vector2DMagnitude(_:)`

Magnitude of a 2D vector.

```swift
public static func vector2DMagnitude(_ v: SIMD2<Double>) -> Double
```

- **OCCT:** `gp_Vec2d::Magnitude`
- **Example:**
  ```swift
  let m = Shape.vector2DMagnitude(SIMD2(3, 4))  // 5.0
  ```

---

### `Shape.vector2DNormalized(_:)`

Return a normalized copy of a 2D vector.

```swift
public static func vector2DNormalized(_ v: SIMD2<Double>) -> SIMD2<Double>
```

- **OCCT:** `gp_Vec2d::Normalized`
- **Example:**
  ```swift
  let n = Shape.vector2DNormalized(SIMD2(3, 4))
  ```

---

### `Shape.direction2DNormalized(_:)`

Create a normalized 2D direction from components.

```swift
public static func direction2DNormalized(_ v: SIMD2<Double>) -> SIMD2<Double>
```

- **OCCT:** `gp_Dir2d` constructor (normalizes on construction)
- **Example:**
  ```swift
  let d = Shape.direction2DNormalized(SIMD2(1, 1))
  ```

---

### `Shape.direction2DAngle(a:b:)`

Signed angle between two 2D directions, in radians.

```swift
public static func direction2DAngle(a: SIMD2<Double>, b: SIMD2<Double>) -> Double
```

- **OCCT:** `gp_Dir2d::Angle`
- **Example:**
  ```swift
  let angle = Shape.direction2DAngle(a: SIMD2(1, 0), b: SIMD2(0, 1))
  ```

---

### `Shape.direction2DCross(a:b:)`

Cross product of two 2D directions.

```swift
public static func direction2DCross(a: SIMD2<Double>, b: SIMD2<Double>) -> Double
```

- **OCCT:** `gp_Dir2d::Crossed`
- **Example:**
  ```swift
  let z = Shape.direction2DCross(a: SIMD2(1, 0), b: SIMD2(0, 1))
  ```

---

### `CurvaturePointType`

Type of a special curvature point found by LProp analysis.

```swift
public enum CurvaturePointType: Int32 {
    case inflection = 0
    case minimumCurvature = 1
    case maximumCurvature = 2
}
```

---

### `CurvatureSpecialPoint`

A special point on a curve at a given parameter.

```swift
public struct CurvatureSpecialPoint {
    public let parameter: Double
    public let type: CurvaturePointType
}
```

---

### `Shape.analyticCurvaturePoints(curveType:first:last:)`

Compute curvature special points (inflections, min/max curvature) for an analytic curve type.

```swift
public static func analyticCurvaturePoints(curveType: Int32, first: Double,
                                            last: Double) -> [CurvatureSpecialPoint]
```

- **Parameters:** `curveType` — 0=Line, 1=Circle, 2=Ellipse, 3=Hyperbola, 4=Parabola. `first`/`last` — parameter domain.
- **Returns:** Array of special points; empty if none found.
- **OCCT:** `LProp_AnalyticCurInf`
- **Example:**
  ```swift
  let pts = Shape.analyticCurvaturePoints(curveType: 2, first: 0, last: .pi)
  ```

---

## TopTrans Surface Transition

### `TopologicalState`

OCCT `TopAbs_State` mapping.

```swift
public enum TopologicalState: Int32, Sendable {
    case `in` = 0, out = 1, on = 2, unknown = 3
}
```

---

### `SurfaceTransitionResult`

Result of a surface or curve transition analysis.

```swift
public struct SurfaceTransitionResult: Sendable {
    public let stateBefore: TopologicalState
    public let stateAfter: TopologicalState
}
```

---

### `Shape.surfaceTransition(tangent:normal:surfaceNormal:tolerance:surfaceOrientation:boundaryOrientation:)`

Analyze topological state before and after a curve crosses a surface boundary.

```swift
public static func surfaceTransition(
    tangent: SIMD3<Double>, normal: SIMD3<Double>,
    surfaceNormal: SIMD3<Double>, tolerance: Double = 1e-6,
    surfaceOrientation: Int = 0, boundaryOrientation: Int = 0
) -> SurfaceTransitionResult
```

- **Parameters:** `tangent` — curve tangent at crossing. `normal` — boundary normal. `surfaceNormal` — normal of the crossed surface. `tolerance` — angular tolerance. `surfaceOrientation`/`boundaryOrientation` — 0=FORWARD, 1=REVERSED.
- **Returns:** States before and after the surface crossing.
- **OCCT:** `TopTrans_SurfaceTransition`
- **Example:**
  ```swift
  let r = Shape.surfaceTransition(tangent: t, normal: n, surfaceNormal: sn)
  ```

---

### `Shape.surfaceTransitionWithCurvature(...)`

Extended surface transition analysis that accounts for surface curvature.

```swift
public static func surfaceTransitionWithCurvature(
    tangent: SIMD3<Double>, normal: SIMD3<Double>,
    maxDirection: SIMD3<Double>, minDirection: SIMD3<Double>,
    maxCurvature: Double, minCurvature: Double,
    surfaceNormal: SIMD3<Double>,
    surfaceMaxDirection: SIMD3<Double>, surfaceMinDirection: SIMD3<Double>,
    surfaceMaxCurvature: Double, surfaceMinCurvature: Double,
    tolerance: Double = 1e-6,
    surfaceOrientation: Int = 0, boundaryOrientation: Int = 0
) -> SurfaceTransitionResult
```

- **Parameters:** Principal curvature directions and magnitudes for both the boundary and the surface at the crossing point, plus tangent and normals.
- **Returns:** States before and after.
- **OCCT:** `TopTrans_SurfaceTransition` (with curvature)
- **Example:**
  ```swift
  let r = Shape.surfaceTransitionWithCurvature(
      tangent: t, normal: n,
      maxDirection: md, minDirection: nd,
      maxCurvature: k1, minCurvature: k2,
      surfaceNormal: sn,
      surfaceMaxDirection: smd, surfaceMinDirection: snd,
      surfaceMaxCurvature: sk1, surfaceMinCurvature: sk2)
  ```

---

## TopTrans Curve Transition

### `Shape.curveTransition(tangent:boundaryTangent:boundaryNormal:curvature:tolerance:surfaceOrientation:boundaryOrientation:)`

Analyze topological state before and after a curve crosses a boundary element.

```swift
public static func curveTransition(
    tangent: SIMD3<Double>,
    boundaryTangent: SIMD3<Double>, boundaryNormal: SIMD3<Double>,
    curvature: Double = 0.0, tolerance: Double = 1e-6,
    surfaceOrientation: Int = 0, boundaryOrientation: Int = 0
) -> SurfaceTransitionResult
```

- **Parameters:** `tangent` — curve tangent. `boundaryTangent`/`boundaryNormal` — boundary element geometry. `curvature` — boundary curvature (0 for straight boundary).
- **Returns:** `SurfaceTransitionResult` with before/after states.
- **OCCT:** `TopTrans_CurveTransition`
- **Example:**
  ```swift
  let r = Shape.curveTransition(tangent: t, boundaryTangent: bt, boundaryNormal: bn)
  ```

---

### `Shape.curveTransitionWithCurvature(tangent:curveNormal:curveCurvature:boundaryTangent:boundaryNormal:surfaceCurvature:tolerance:surfaceOrientation:boundaryOrientation:)`

Curve transition analysis accounting for boundary curve curvature.

```swift
public static func curveTransitionWithCurvature(
    tangent: SIMD3<Double>,
    curveNormal: SIMD3<Double>, curveCurvature: Double,
    boundaryTangent: SIMD3<Double>, boundaryNormal: SIMD3<Double>,
    surfaceCurvature: Double, tolerance: Double = 1e-6,
    surfaceOrientation: Int = 0, boundaryOrientation: Int = 0
) -> SurfaceTransitionResult
```

- **Returns:** `SurfaceTransitionResult` with before/after states.
- **OCCT:** `TopTrans_CurveTransition` (with curvature)
- **Example:**
  ```swift
  let r = Shape.curveTransitionWithCurvature(
      tangent: t, curveNormal: cn, curveCurvature: kc,
      boundaryTangent: bt, boundaryNormal: bn, surfaceCurvature: ks)
  ```

---

## GeomFill Trihedrons

### `frenetTrihedron(at:)`

Evaluate a Frenet trihedron on an edge at a parameter.

```swift
public func frenetTrihedron(at param: Double) -> (tangent: SIMD3<Double>, normal: SIMD3<Double>, binormal: SIMD3<Double>)?
```

- **Parameters:** `param` — curve parameter.
- **Returns:** Tuple of tangent, normal, binormal, or `nil` if the trihedron cannot be computed (e.g. inflection point).
- **OCCT:** `GeomFill_Frenet`
- **Example:**
  ```swift
  if let f = edge.frenetTrihedron(at: 0.5) {
      print(f.tangent, f.normal, f.binormal)
  }
  ```

---

### `constantBiNormalTrihedron(at:biNormal:)`

Evaluate a constant-binormal trihedron on an edge at a parameter.

```swift
public func constantBiNormalTrihedron(at param: Double, biNormal: SIMD3<Double>) -> (tangent: SIMD3<Double>, normal: SIMD3<Double>, binormal: SIMD3<Double>)?
```

- **Parameters:** `param` — curve parameter. `biNormal` — fixed binormal direction.
- **Returns:** Trihedron tuple, or `nil` on failure.
- **OCCT:** `GeomFill_ConstantBiNormal`
- **Example:**
  ```swift
  if let f = edge.constantBiNormalTrihedron(at: 0.5, biNormal: SIMD3(0, 0, 1)) { }
  ```

---

### `Shape.fixedTrihedron(tangent:normal:at:)`

Evaluate a fixed (constant) trihedron at any parameter.

```swift
public static func fixedTrihedron(tangent: SIMD3<Double>, normal: SIMD3<Double>, at param: Double = 0) -> (tangent: SIMD3<Double>, normal: SIMD3<Double>, binormal: SIMD3<Double>)
```

- **Parameters:** `tangent`/`normal` — fixed trihedron directions. `param` — parameter (unused geometrically; for API consistency).
- **Returns:** Trihedron tuple (binormal = tangent × normal).
- **OCCT:** `GeomFill_Fixed`
- **Example:**
  ```swift
  let f = Shape.fixedTrihedron(tangent: SIMD3(1,0,0), normal: SIMD3(0,1,0))
  ```

---

### `darbouxTrihedron(onFace:at:)`

Evaluate a Darboux trihedron on an edge lying on a face.

```swift
public func darbouxTrihedron(onFace face: Shape, at param: Double) -> (tangent: SIMD3<Double>, normal: SIMD3<Double>, binormal: SIMD3<Double>)?
```

- **Parameters:** `face` — the supporting face. `param` — curve parameter.
- **Returns:** Darboux frame (tangent, surface normal, binormal), or `nil` on failure.
- **OCCT:** `GeomFill_Darboux`
- **Example:**
  ```swift
  if let f = edge.darbouxTrihedron(onFace: face, at: 0.5) { }
  ```

---

## Polygon Interference

### `PolygonIntersection`

Result of 2D polygon interference computation.

```swift
public struct PolygonIntersection: Sendable {
    public let points: [SIMD2<Double>]
}
```

---

### `Shape.polygonInterference(poly1:poly2:)`

Compute intersection points between two 2D polylines.

```swift
public static func polygonInterference(
    poly1: [SIMD2<Double>], poly2: [SIMD2<Double>]
) -> PolygonIntersection
```

- **Parameters:** `poly1`/`poly2` — ordered arrays of 2D vertices defining each polyline.
- **Returns:** `PolygonIntersection` with intersection points (may be empty).
- **OCCT:** `Intf_InterferencePolygon2d`
- **Example:**
  ```swift
  let result = Shape.polygonInterference(poly1: pts1, poly2: pts2)
  ```

---

### `Shape.polygonSelfInterference(polygon:)`

Compute self-intersection points of a 2D polyline.

```swift
public static func polygonSelfInterference(
    polygon: [SIMD2<Double>]
) -> PolygonIntersection
```

- **Parameters:** `polygon` — ordered 2D vertices.
- **Returns:** Self-intersection points.
- **OCCT:** `Intf_InterferencePolygon2d` (self-interference mode)
- **Example:**
  ```swift
  let result = Shape.polygonSelfInterference(polygon: pts)
  ```

---

## GccAna\_Circ2d3Tan

### `Circle2DSolution`

A circle solution from a GccAna tangency solver.

```swift
public struct Circle2DSolution: Sendable {
    public let centerX: Double
    public let centerY: Double
    public let radius: Double
}
```

---

### `Shape.circleThrough3Points(p1:p2:p3:tolerance:)`

Find circles through 3 points (circumscribed circle).

```swift
public static func circleThrough3Points(
    p1: SIMD2<Double>, p2: SIMD2<Double>, p3: SIMD2<Double>,
    tolerance: Double = 1e-6
) -> [Circle2DSolution]
```

- **Returns:** Array of circle solutions (typically 0 or 1).
- **OCCT:** `GccAna_Circ2d3Tan` (3 points)
- **Example:**
  ```swift
  let sols = Shape.circleThrough3Points(p1: SIMD2(0,0), p2: SIMD2(1,0), p3: SIMD2(0,1))
  ```

---

### `Shape.circleTangent3Lines(l1Point:l1Dir:l2Point:l2Dir:l3Point:l3Dir:tolerance:)`

Find circles tangent to 3 lines.

```swift
public static func circleTangent3Lines(
    l1Point: SIMD2<Double>, l1Dir: SIMD2<Double>,
    l2Point: SIMD2<Double>, l2Dir: SIMD2<Double>,
    l3Point: SIMD2<Double>, l3Dir: SIMD2<Double>,
    tolerance: Double = 1e-6
) -> [Circle2DSolution]
```

- **Returns:** Array of up to 8 tangent circles.
- **OCCT:** `GccAna_Circ2d3Tan` (3 lines)
- **Example:**
  ```swift
  let sols = Shape.circleTangent3Lines(
      l1Point: .zero, l1Dir: SIMD2(1,0),
      l2Point: SIMD2(0,1), l2Dir: SIMD2(1,0),
      l3Point: .zero, l3Dir: SIMD2(0,1))
  ```

---

### `Shape.circleTangent3Circles(c1Center:c1Radius:c2Center:c2Radius:c3Center:c3Radius:tolerance:)`

Find circles tangent to 3 circles (Apollonius problem).

```swift
public static func circleTangent3Circles(
    c1Center: SIMD2<Double>, c1Radius: Double,
    c2Center: SIMD2<Double>, c2Radius: Double,
    c3Center: SIMD2<Double>, c3Radius: Double,
    tolerance: Double = 1e-6
) -> [Circle2DSolution]
```

- **Returns:** Array of up to 8 solution circles.
- **OCCT:** `GccAna_Circ2d3Tan` (3 circles)
- **Example:**
  ```swift
  let sols = Shape.circleTangent3Circles(
      c1Center: SIMD2(-2,0), c1Radius: 1,
      c2Center: SIMD2(2,0), c2Radius: 1,
      c3Center: SIMD2(0,2), c3Radius: 1)
  ```

---

### `Shape.circleTangent2CirclesPoint(c1Center:c1Radius:c2Center:c2Radius:point:tolerance:)`

Find circles tangent to 2 circles and passing through 1 point.

```swift
public static func circleTangent2CirclesPoint(
    c1Center: SIMD2<Double>, c1Radius: Double,
    c2Center: SIMD2<Double>, c2Radius: Double,
    point: SIMD2<Double>, tolerance: Double = 1e-6
) -> [Circle2DSolution]
```

- **OCCT:** `GccAna_Circ2d3Tan` (2 circles + point)
- **Example:**
  ```swift
  let sols = Shape.circleTangent2CirclesPoint(
      c1Center: .zero, c1Radius: 1,
      c2Center: SIMD2(3,0), c2Radius: 1,
      point: SIMD2(1.5, 2))
  ```

---

### `Shape.circleTangentCircle2Points(circleCenter:circleRadius:p1:p2:tolerance:)`

Find circles tangent to 1 circle and passing through 2 points.

```swift
public static func circleTangentCircle2Points(
    circleCenter: SIMD2<Double>, circleRadius: Double,
    p1: SIMD2<Double>, p2: SIMD2<Double>, tolerance: Double = 1e-6
) -> [Circle2DSolution]
```

- **OCCT:** `GccAna_Circ2d3Tan` (circle + 2 points)
- **Example:**
  ```swift
  let sols = Shape.circleTangentCircle2Points(
      circleCenter: .zero, circleRadius: 1,
      p1: SIMD2(3,0), p2: SIMD2(0,3))
  ```

---

### `Shape.circleTangent2LinesPoint(l1Point:l1Dir:l2Point:l2Dir:point:tolerance:)`

Find circles tangent to 2 lines and passing through 1 point.

```swift
public static func circleTangent2LinesPoint(
    l1Point: SIMD2<Double>, l1Dir: SIMD2<Double>,
    l2Point: SIMD2<Double>, l2Dir: SIMD2<Double>,
    point: SIMD2<Double>, tolerance: Double = 1e-6
) -> [Circle2DSolution]
```

- **OCCT:** `GccAna_Circ2d3Tan` (2 lines + point)
- **Example:**
  ```swift
  let sols = Shape.circleTangent2LinesPoint(
      l1Point: .zero, l1Dir: SIMD2(1,0),
      l2Point: .zero, l2Dir: SIMD2(0,1),
      point: SIMD2(2,2))
  ```

---

## IntTools

### `CommonPartType`

Type of an edge-edge or edge-face intersection common part.

```swift
public enum CommonPartType: Int32, Sendable {
    case vertex = 0
    case edge = 1
}
```

---

### `CommonPart`

A single intersection common part from IntTools.

```swift
public struct CommonPart: Sendable {
    public let type: CommonPartType
    public let param1Range: (first: Double, last: Double)
    public let param2Range: (first: Double, last: Double)
    public let point: SIMD3<Double>
}
```

---

### `edgeEdgeIntersection(with:)`

Intersect two edges to find common vertices and edge overlaps.

```swift
public func edgeEdgeIntersection(with other: Shape) -> [CommonPart]?
```

- **Parameters:** `other` — second edge.
- **Returns:** Array of common parts, or `nil` if intersection failed.
- **OCCT:** `IntTools_EdgeEdge`
- **Example:**
  ```swift
  if let parts = e1.edgeEdgeIntersection(with: e2) {
      for p in parts { print(p.type, p.point) }
  }
  ```

---

### `edgeFaceIntersection(with:)`

Intersect an edge with a face to find common vertices and edge overlaps.

```swift
public func edgeFaceIntersection(with face: Shape) -> [CommonPart]?
```

- **Parameters:** `face` — face to intersect with.
- **Returns:** Array of common parts, or `nil` on failure.
- **OCCT:** `IntTools_EdgeFace`
- **Example:**
  ```swift
  if let parts = edge.edgeFaceIntersection(with: face) { }
  ```

---

### `FaceFaceCurve`

An intersection curve from a face-face intersection.

```swift
public struct FaceFaceCurve: Sendable {
    public let start: SIMD3<Double>?
    public let end: SIMD3<Double>?
}
```

---

### `FaceFacePoint`

An intersection point from a face-face intersection.

```swift
public struct FaceFacePoint: Sendable {
    public let pointOnFace1: SIMD3<Double>
    public let pointOnFace2: SIMD3<Double>
}
```

---

### `FaceFaceResult`

Result of a face-face intersection.

```swift
public struct FaceFaceResult: Sendable {
    public let curves: [FaceFaceCurve]
    public let points: [FaceFacePoint]
    public let isTangent: Bool
}
```

---

### `faceFaceIntersection(with:tolerance:)`

Intersect two faces to find intersection curves and points.

```swift
public func faceFaceIntersection(with other: Shape, tolerance: Double = 1e-7) -> FaceFaceResult?
```

- **Parameters:** `other` — second face. `tolerance` — approximation tolerance.
- **Returns:** `FaceFaceResult`, or `nil` on failure.
- **OCCT:** `IntTools_FaceFace`
- **Example:**
  ```swift
  if let r = f1.faceFaceIntersection(with: f2) {
      print(r.curves.count, r.isTangent)
  }
  ```

---

### `classifyPoint2d(u:v:tolerance:)`

Classify a UV point relative to a face boundary in parameter space.

```swift
public func classifyPoint2d(u: Double, v: Double, tolerance: Double = 1e-7) -> OCCTSwift.PointClassification
```

- **Parameters:** `u`/`v` — UV coordinates. `tolerance` — classification tolerance.
- **Returns:** `.inside`, `.onBoundary`, `.outside`, or `.unknown`.
- **OCCT:** `IntTools_FClass2d::Perform`
- **Example:**
  ```swift
  let c = face.classifyPoint2d(u: 0.5, v: 0.5)
  ```

---

### `isHole(tolerance:)`

Check if a face represents a hole (inner-wire orientation).

```swift
public func isHole(tolerance: Double = 1e-7) -> Bool
```

- **Returns:** `true` if the face is classified as a hole.
- **OCCT:** `IntTools_FClass2d` (IsHole query)
- **Example:**
  ```swift
  if face.isHole() { }
  ```

---

## BOPAlgo Builder

### `buildFaces(from:)`

Build faces from edges that lie on this face's surface.

```swift
public func buildFaces(from edges: [Shape]) -> [Shape]?
```

- **Parameters:** `edges` — edge shapes on this face's surface.
- **Returns:** Array of result face shapes, or `nil` on failure.
- **OCCT:** `BOPAlgo_BuilderFace`
- **Example:**
  ```swift
  if let faces = face.buildFaces(from: edges) { }
  ```

---

### `Shape.buildSolids(from:)`

Build solids from a closed set of faces.

```swift
public static func buildSolids(from faces: [Shape]) -> [Shape]?
```

- **Parameters:** `faces` — face shapes forming closed volumes.
- **Returns:** Array of result solid shapes, or `nil` on failure.
- **OCCT:** `BOPAlgo_BuilderSolid`
- **Example:**
  ```swift
  if let solids = Shape.buildSolids(from: faces) { }
  ```

---

### `splitShell()`

Split a shell into connected components.

```swift
public func splitShell() -> [Shape]?
```

- **Returns:** Array of shell shapes (one per connected component), or `nil` on failure.
- **OCCT:** `BOPAlgo_ShellSplitter`
- **Example:**
  ```swift
  if let shells = shell.splitShell() { }
  ```

---

### `edgesToWires(tolerance:)`

Connect a compound of edges into wires.

```swift
public func edgesToWires(tolerance: Double = 1e-7) -> Shape?
```

- **Parameters:** `tolerance` — edge connection tolerance.
- **Returns:** Compound of wires, or `nil` on failure.
- **OCCT:** `BOPAlgo_Tools::EdgesToWires`
- **Example:**
  ```swift
  if let wires = edgeCompound.edgesToWires() { }
  ```

---

### `wiresToFaces(tolerance:)`

Build planar faces from a compound of wires.

```swift
public func wiresToFaces(tolerance: Double = 1e-7) -> Shape?
```

- **Parameters:** `tolerance` — face building tolerance.
- **Returns:** Compound of faces, or `nil` on failure.
- **OCCT:** `BOPAlgo_Tools::WiresToFaces`
- **Example:**
  ```swift
  if let faces = wireCompound.wiresToFaces() { }
  ```

---

## BOPTools

### `Shape.normalOnEdge(edge:face:)`

Get the normal to a face at an edge location.

```swift
public static func normalOnEdge(edge: Shape, face: Shape) -> SIMD3<Double>?
```

- **Parameters:** `edge` — edge on the face. `face` — containing face.
- **Returns:** Unit normal direction, or `nil` on failure.
- **OCCT:** `BOPTools_AlgoTools3D::GetNormalToFaceOnEdge`
- **Example:**
  ```swift
  if let n = Shape.normalOnEdge(edge: e, face: f) { }
  ```

---

### `pointInFace()`

Find a point strictly inside this face.

```swift
public func pointInFace() -> SIMD3<Double>?
```

- **Returns:** A 3D point in the interior of this face, or `nil` on failure.
- **OCCT:** `BOPTools_AlgoTools3D::PointInFace`
- **Example:**
  ```swift
  if let pt = face.pointInFace() { }
  ```

---

### `isEmpty`

Check if this shape has no sub-shapes.

```swift
public var isEmpty: Bool { get }
```

- **OCCT:** `BOPTools_AlgoTools3D::IsEmptyShape`
- **Example:**
  ```swift
  if shape.isEmpty { }
  ```

---

### `isOpenShell`

Check if this shell is open (not all edges shared by two faces).

```swift
public var isOpenShell: Bool { get }
```

- **OCCT:** `BOPTools_AlgoTools::IsOpenShell`
- **Example:**
  ```swift
  if shell.isOpenShell { }
  ```

---

## IntTools\_BeanFaceIntersector

### `BeanFaceIntersection`

Result of an edge-face coincidence check.

```swift
public struct BeanFaceIntersection: Sendable {
    public let ranges: [(first: Double, last: Double)]
    public let minSquareDistance: Double
}
```

---

### `Shape.beanFaceIntersect(edge:face:)`

Find coincident parameter ranges where an edge lies on a face surface.

```swift
public static func beanFaceIntersect(edge: Shape, face: Shape) -> BeanFaceIntersection?
```

- **Parameters:** `edge` — edge curve to test. `face` — face surface to test against.
- **Returns:** Ranges of coincidence and minimum squared distance, or `nil` on failure.
- **OCCT:** `IntTools_BeanFaceIntersector`
- **Example:**
  ```swift
  if let r = Shape.beanFaceIntersect(edge: e, face: f) {
      print(r.ranges.count, r.minSquareDistance)
  }
  ```

---

## BOPAlgo\_WireSplitter

### `Shape.makeWire(from:)`

Assemble edges into a connected wire using BOPAlgo_WireSplitter.

```swift
public static func makeWire(from edges: [Shape]) -> Shape?
```

- **Parameters:** `edges` — array of edge shapes to connect.
- **Returns:** Result wire as shape, or `nil` on failure.
- **OCCT:** `BOPAlgo_WireSplitter::MakeWire`
- **Example:**
  ```swift
  if let wire = Shape.makeWire(from: [e1, e2, e3]) { }
  ```

---

## BRepFeat\_SplitShape

### `splitByEdge(_:onFace:)`

Split this shape by adding an edge to a face.

```swift
public func splitByEdge(_ edge: Shape, onFace face: Shape) -> Shape?
```

- **Parameters:** `edge` — edge to add as a split line. `face` — face the edge lies on.
- **Returns:** Result shape with the split face, or `nil` on failure.
- **OCCT:** `BRepFeat_SplitShape`
- **Example:**
  ```swift
  if let split = solid.splitByEdge(e, onFace: face) { }
  ```

---

### `splitByWire(_:onFace:)`

Split this shape by adding a wire to a face.

```swift
public func splitByWire(_ wire: Shape, onFace face: Shape) -> Shape?
```

- **Parameters:** `wire` — wire to split along. `face` — face the wire lies on.
- **Returns:** Result shape with split face, or `nil` on failure.
- **OCCT:** `BRepFeat_SplitShape`
- **Example:**
  ```swift
  if let split = solid.splitByWire(w, onFace: face) { }
  ```

---

### `SplitShapeResult`

Result of a multi-pair split-shape operation.

```swift
public struct SplitShapeResult: Sendable {
    public let shape: Shape
    public let leftFaces: [Shape]
    public let rightFaces: [Shape]
}
```

---

### `splitWithSides(edgesOnFaces:)`

Split this shape with multiple edge-on-face pairs, returning left/right face classifications.

```swift
public func splitWithSides(edgesOnFaces: [(edge: Shape, face: Shape)]) -> SplitShapeResult?
```

- **Parameters:** `edgesOnFaces` — array of `(edge, face)` pairs; each edge is added to the corresponding face.
- **Returns:** Split result with the resulting shape and left/right face arrays, or `nil` on failure.
- **OCCT:** `BRepFeat_SplitShape` with `Left()`/`Right()` queries
- **Example:**
  ```swift
  if let r = solid.splitWithSides(edgesOnFaces: [(edge: e, face: f)]) {
      print(r.leftFaces.count, r.rightFaces.count)
  }
  ```

---

## BRepFeat\_MakeCylindricalHole

### `cylindricalHole(axisOrigin:axisDirection:radius:)`

Drill a through cylindrical hole in this shape.

```swift
public func cylindricalHole(axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>, radius: Double) -> Shape?
```

- **Parameters:** `axisOrigin` — hole axis origin. `axisDirection` — hole axis direction. `radius` — hole radius.
- **Returns:** Shape with hole, or `nil` on failure.
- **OCCT:** `BRepFeat_MakeCylindricalHole::Perform`
- **Example:**
  ```swift
  if let holed = solid.cylindricalHole(axisOrigin: .zero, axisDirection: SIMD3(0,0,1), radius: 5) { }
  ```

---

### `cylindricalHoleBlind(axisOrigin:axisDirection:radius:depth:)`

Drill a blind cylindrical hole to a specified depth.

```swift
public func cylindricalHoleBlind(axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>, radius: Double, depth: Double) -> Shape?
```

- **Parameters:** `depth` — hole depth from entry face.
- **Returns:** Shape with blind hole, or `nil` on failure.
- **OCCT:** `BRepFeat_MakeCylindricalHole::PerformBlind`
- **Example:**
  ```swift
  if let holed = solid.cylindricalHoleBlind(axisOrigin: .zero, axisDirection: SIMD3(0,0,1), radius: 5, depth: 10) { }
  ```

---

### `cylindricalHoleThruNext(axisOrigin:axisDirection:radius:)`

Drill a cylindrical hole through to the next face encountered.

```swift
public func cylindricalHoleThruNext(axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>, radius: Double) -> Shape?
```

- **Returns:** Shape with hole stopping at the first inner face, or `nil` on failure.
- **OCCT:** `BRepFeat_MakeCylindricalHole::PerformThruNext`
- **Example:**
  ```swift
  if let holed = solid.cylindricalHoleThruNext(axisOrigin: .zero, axisDirection: SIMD3(0,1,0), radius: 3) { }
  ```

---

### `CylindricalHoleStatus`

Status result for a cylindrical hole operation.

```swift
public enum CylindricalHoleStatus: Int32, Sendable {
    case noError = 0
    case invalidPlacement = 1
    case holeTooLong = 2
    case unknown = 3
}
```

---

### `cylindricalHoleStatus(axisOrigin:axisDirection:radius:)`

Check whether a cylindrical hole can be drilled without modifying the shape.

```swift
public func cylindricalHoleStatus(axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>, radius: Double) -> CylindricalHoleStatus
```

- **Returns:** A `CylindricalHoleStatus` indicating feasibility.
- **OCCT:** `BRepFeat_MakeCylindricalHole` (status query)
- **Example:**
  ```swift
  let s = solid.cylindricalHoleStatus(axisOrigin: .zero, axisDirection: SIMD3(0,0,1), radius: 5)
  if s == .noError { }
  ```

---

## BRepFeat\_Gluer

### `glue(_:facePairs:)`

Glue another shape onto this shape by binding matching face pairs.

```swift
public func glue(_ gluedShape: Shape, facePairs: [(base: Shape, glued: Shape)]) -> Shape?
```

- **Parameters:** `gluedShape` — shape to merge onto this one. `facePairs` — matching face pairs: `base` from this shape, `glued` from `gluedShape`.
- **Returns:** Glued result shape, or `nil` on failure.
- **OCCT:** `BRepFeat_Gluer`
- **Example:**
  ```swift
  if let r = base.glue(toAttach, facePairs: [(base: bf, glued: gf)]) { }
  ```

---

## LocOpe\_WiresOnShape + LocOpe\_Spliter

### `LocOpeSplitResult`

Result of a `LocOpe_Spliter` operation.

```swift
public struct LocOpeSplitResult: Sendable {
    public let shape: Shape
    public let directLeftFaces: [Shape]
}
```

---

### `locOpeSplit(wiresOnFaces:)`

Split this shape by projecting wires onto specific faces using `LocOpe_Spliter`.

```swift
public func locOpeSplit(wiresOnFaces: [(wire: Shape, face: Shape)]) -> LocOpeSplitResult?
```

- **Parameters:** `wiresOnFaces` — pairs binding each wire to the face it lies on.
- **Returns:** Split result with direct-left faces, or `nil` on failure.
- **OCCT:** `LocOpe_WiresOnShape` + `LocOpe_Spliter`
- **Example:**
  ```swift
  if let r = solid.locOpeSplit(wiresOnFaces: [(wire: w, face: f)]) {
      print(r.directLeftFaces.count)
  }
  ```

---

### `locOpeSplitAuto(wires:)`

Split this shape by automatically projecting wires onto faces.

```swift
public func locOpeSplitAuto(wires: [Shape]) -> Shape?
```

- **Parameters:** `wires` — wires to project and split by; faces are determined automatically.
- **Returns:** Result shape, or `nil` on failure.
- **OCCT:** `LocOpe_WiresOnShape::BindAll` + `LocOpe_Spliter`
- **Example:**
  ```swift
  if let r = solid.locOpeSplitAuto(wires: [w]) { }
  ```

---

## LocOpe\_Gluer

### `locOpeGlue(_:facePairs:edgePairs:)`

Glue another shape onto this shape using `LocOpe_Gluer` with optional edge binding.

```swift
public func locOpeGlue(_ gluedShape: Shape,
                       facePairs: [(base: Shape, glued: Shape)],
                       edgePairs: [(base: Shape, glued: Shape)] = []) -> Shape?
```

- **Parameters:** `gluedShape` — shape to glue. `facePairs` — at least one required matching face pair. `edgePairs` — optional edge pairs for precise alignment.
- **Returns:** Result shape, or `nil` on failure (including empty `facePairs`).
- **OCCT:** `LocOpe_Gluer`
- **Example:**
  ```swift
  if let r = base.locOpeGlue(toGlue, facePairs: [(base: bf, glued: gf)]) { }
  ```

---

## ChFi2d\_Builder

All `ChFi2d_Builder` methods operate exclusively on **planar faces**, not solids. Extract the target face first if working from a solid.

### `addFillet2d(vertexIndex:radius:)`

Add a 2D fillet at a vertex on a planar face.

```swift
public func addFillet2d(vertexIndex: Int, radius: Double) -> Shape?
```

- **Parameters:** `vertexIndex` — 0-based vertex index. `radius` — fillet radius.
- **Returns:** Result face with fillet, or `nil` if the shape is not a planar face.
- **OCCT:** `ChFi2d_Builder::AddFillet`
- **Example:**
  ```swift
  let face = solid.subShapes(ofType: .face)[0]
  if let filleted = face.addFillet2d(vertexIndex: 0, radius: 1.0) { }
  ```

---

### `addChamfer2d(edge1Index:edge2Index:d1:d2:)`

Add a 2D chamfer between two edges on a planar face.

```swift
public func addChamfer2d(edge1Index: Int, edge2Index: Int, d1: Double, d2: Double) -> Shape?
```

- **Parameters:** `edge1Index`/`edge2Index` — 0-based edge indices. `d1`/`d2` — chamfer distances on each edge.
- **Returns:** Result face with chamfer, or `nil` on failure.
- **OCCT:** `ChFi2d_Builder::AddChamfer`
- **Example:**
  ```swift
  if let ch = face.addChamfer2d(edge1Index: 0, edge2Index: 1, d1: 1.0, d2: 1.0) { }
  ```

---

### `addChamfer2dAngle(edgeIndex:vertexIndex:distance:angle:)`

Add a 2D chamfer defined by distance and angle on a planar face.

```swift
public func addChamfer2dAngle(edgeIndex: Int, vertexIndex: Int, distance: Double, angle: Double) -> Shape?
```

- **Parameters:** `edgeIndex` — reference edge. `vertexIndex` — vertex to chamfer. `distance` — distance on the edge. `angle` — chamfer angle in radians.
- **Returns:** Result face with chamfer, or `nil` on failure.
- **OCCT:** `ChFi2d_Builder::AddChamfer` (distance + angle)
- **Example:**
  ```swift
  if let ch = face.addChamfer2dAngle(edgeIndex: 0, vertexIndex: 1, distance: 1.0, angle: .pi/4) { }
  ```

---

### `modifyFillet2d(originalFace:filletEdgeIndex:newRadius:)`

Modify an existing fillet radius on a face.

```swift
public func modifyFillet2d(originalFace: Shape, filletEdgeIndex: Int, newRadius: Double) -> Shape?
```

- **Parameters:** `originalFace` — face before the fillet was added. `filletEdgeIndex` — 0-based index of the fillet edge in `self`. `newRadius` — new fillet radius.
- **Returns:** Result face with modified fillet, or `nil` on failure.
- **OCCT:** `ChFi2d_Builder::ModifyFillet`
- **Example:**
  ```swift
  if let modified = filletedFace.modifyFillet2d(originalFace: original, filletEdgeIndex: 0, newRadius: 2.0) { }
  ```

---

### `removeFillet2d(originalFace:filletEdgeIndex:)`

Remove a fillet from a face, restoring the original corner.

```swift
public func removeFillet2d(originalFace: Shape, filletEdgeIndex: Int) -> Shape?
```

- **Parameters:** `originalFace` — face before the fillet. `filletEdgeIndex` — 0-based fillet edge index in `self`.
- **Returns:** Face with fillet removed, or `nil` on failure.
- **OCCT:** `ChFi2d_Builder::RemoveFillet`
- **Example:**
  ```swift
  if let r = filletedFace.removeFillet2d(originalFace: original, filletEdgeIndex: 0) { }
  ```

---

### `removeChamfer2d(originalFace:chamferEdgeIndex:)`

Remove a chamfer from a face.

```swift
public func removeChamfer2d(originalFace: Shape, chamferEdgeIndex: Int) -> Shape?
```

- **Parameters:** `originalFace` — face before the chamfer. `chamferEdgeIndex` — 0-based chamfer edge index in `self`.
- **Returns:** Face with chamfer removed, or `nil` on failure.
- **OCCT:** `ChFi2d_Builder::RemoveChamfer`
- **Example:**
  ```swift
  if let r = chamferedFace.removeChamfer2d(originalFace: original, chamferEdgeIndex: 0) { }
  ```

---

## ChFi2d\_ChamferAPI

### `Chamfer2DEdgeResult`

Result of a standalone 2D chamfer between two edges.

```swift
public struct Chamfer2DEdgeResult: Sendable {
    public let chamferEdge: Shape
    public let modifiedEdge1: Shape
    public let modifiedEdge2: Shape
}
```

---

### `Shape.chamfer2dEdges(edge1:edge2:d1:d2:)`

Create a chamfer between two linear edges using `ChFi2d_ChamferAPI`.

```swift
public static func chamfer2dEdges(edge1: Shape, edge2: Shape, d1: Double, d2: Double) -> Chamfer2DEdgeResult?
```

- **Parameters:** `edge1`/`edge2` — linear edges sharing a vertex. `d1`/`d2` — chamfer distances on each edge.
- **Returns:** `Chamfer2DEdgeResult` with chamfer edge and trimmed originals, or `nil` on failure.
- **OCCT:** `ChFi2d_ChamferAPI`
- **Example:**
  ```swift
  if let r = Shape.chamfer2dEdges(edge1: e1, edge2: e2, d1: 1.0, d2: 1.0) {
      let chamfer = r.chamferEdge
  }
  ```

---

## ChFi2d\_FilletAPI

### `Fillet2DEdgeResult`

Result of a standalone 2D fillet between two edges.

```swift
public struct Fillet2DEdgeResult: Sendable {
    public let filletEdge: Shape
    public let modifiedEdge1: Shape
    public let modifiedEdge2: Shape
    public let solutionCount: Int
}
```

---

### `Shape.fillet2dEdges(edge1:edge2:planeNormal:radius:nearPoint:)`

Create a fillet between two edges in a plane using `ChFi2d_FilletAPI`.

```swift
public static func fillet2dEdges(edge1: Shape, edge2: Shape,
                                 planeNormal: SIMD3<Double>,
                                 radius: Double,
                                 nearPoint: SIMD3<Double>) -> Fillet2DEdgeResult?
```

- **Parameters:** `edge1`/`edge2` — edges to fillet. `planeNormal` — normal of the plane containing the edges. `radius` — fillet radius. `nearPoint` — point near the desired fillet location, used to select among multiple solutions.
- **Returns:** `Fillet2DEdgeResult` with the fillet arc, trimmed edges, and solution count, or `nil` on failure.
- **OCCT:** `ChFi2d_FilletAPI` (selects analytical or iterative algorithm automatically)
- **Example:**
  ```swift
  if let r = Shape.fillet2dEdges(
      edge1: e1, edge2: e2,
      planeNormal: SIMD3(0, 0, 1),
      radius: 2.0,
      nearPoint: SIMD3(1, 1, 0)) {
      print(r.solutionCount)
  }
  ```

---

## FilletSurf\_Builder

### `FilletSurfaceInfo`

Geometry information for one computed fillet surface.

```swift
public struct FilletSurfaceInfo: Sendable {
    public let surface: Surface
    public let supportFace1: Shape
    public let supportFace2: Shape
    public let tolerance: Double
    public let firstParameter: Double
    public let lastParameter: Double
    public let startStatus: Int
    public let endStatus: Int
}
```

---

### `FilletSurfaceResult`

Result of `FilletSurf_Builder` computation.

```swift
public struct FilletSurfaceResult: Sendable {
    public let surfaces: [FilletSurfaceInfo]
    public let status: Int  // 0=ok, 1=notOk, 2=partial
}
```

---

### `filletSurfaces(edges:radius:)`

Compute fillet surface geometry on this shape without modifying its topology.

```swift
public func filletSurfaces(edges: [Shape], radius: Double) -> FilletSurfaceResult?
```

- **Parameters:** `edges` — edges to fillet. `radius` — fillet radius.
- **Returns:** `FilletSurfaceResult` with NURBS fillet surfaces and support faces, or `nil` on total failure. `status == 1` with an empty `surfaces` array also maps to `nil`.
- **OCCT:** `FilletSurf_Builder`
- **Note:** Returns raw surface geometry only — does not produce a new solid. Use `Shape.fillet(edges:radius:)` to produce a filleted solid.
- **Example:**
  ```swift
  if let r = solid.filletSurfaces(edges: [e1, e2], radius: 1.0) {
      for info in r.surfaces {
          print(info.surface, info.tolerance)
      }
  }
  ```
