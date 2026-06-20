---
title: Shape — Healing, Recognition & Feature Ops
parent: API Reference
---

# Shape — Healing, Recognition & Feature Ops

This page covers geometry repair, shape upgrade, point classification, proximity, wedge and half-space primitives, sub-shape manipulation, periodic shapes, draft, non-uniform scale, shell/vertex creation, offset, edge fusion, volume building, canonical recognition, wireframe fixing, boolean validation, splits, multi-tool booleans, feature operations, and per-input boolean history for [`Shape`](Shape.md). For core creation, transforms, and mesh operations see the main `Shape` page (todo).

## Topics

- [Advanced Healing](#advanced-healing) · [Point Classification](#point-classification) · [Shape Proximity](#shape-proximity) · [Wedge Primitive](#wedge-primitive) · [NURBS Conversion](#nurbs-conversion) · [Fast Sewing](#fast-sewing) · [Normal Projection](#normal-projection) · [Half-Space](#half-space) · [Sub-Shape Replacement](#sub-shape-replacement) · [Periodic Shapes](#periodic-shapes) · [Draft from Shape](#draft-from-shape) · [Non-Uniform Scale](#non-uniform-scale) · [Shell & Vertex Creation](#shell--vertex-creation) · [Simple Offset](#simple-offset) · [Middle Path](#middle-path) · [Fuse Edges](#fuse-edges) · [Volume from Faces](#volume-from-faces) · [Shape Contents](#shape-contents) · [Canonical Recognition](#canonical-recognition) · [Find Surface](#find-surface) · [Fix Wireframe](#fix-wireframe) · [Remove Internal Wires](#remove-internal-wires) · [Contiguous Edges](#contiguous-edges) · [Quilt Faces](#quilt-faces) · [Fix Small Faces](#fix-small-faces) · [Remove Locations](#remove-locations) · [Revolution from Curve](#revolution-from-curve) · [Linear Rib Feature](#linear-rib-feature) · [Revolution Form Feature](#revolution-form-feature) · [Draft Prism Feature](#draft-prism-feature) · [Revolution Feature](#revolution-feature) · [Face from Surface](#face-from-surface) · [Edges to Faces](#edges-to-faces) · [Shape-to-Shape Section](#shape-to-shape-section) · [Boolean Pre-Validation](#boolean-pre-validation) · [Split Shape by Wire](#split-shape-by-wire) · [Split by Angle](#split-by-angle) · [Drop Small Edges](#drop-small-edges) · [Multi-Tool Boolean Fuse](#multi-tool-boolean-fuse) · [Multi-Offset Wire](#multi-offset-wire) · [Cylindrical Projection](#cylindrical-projection) · [Same Parameter](#same-parameter) · [Conical Projection](#conical-projection) · [Encode Regularity](#encode-regularity) · [Update Tolerances](#update-tolerances) · [Divide by Number](#divide-by-number) · [Boolean with History](#boolean-with-history)

---

## Advanced Healing

### `GeometricContinuity`

Target continuity level for shape divide operations.

```swift
public enum GeometricContinuity: Int32, Sendable {
    case c0 = 0
    case c1 = 1
    case c2 = 2
    case c3 = 3
}
```

Pass to `divided(at:)` to split a shape at discontinuities of the specified geometric continuity.

---

### `divided(at:)`

Divide a shape at continuity discontinuities.

```swift
public func divided(at continuity: GeometricContinuity) -> Shape?
```

Splits the shape wherever its underlying geometry drops below the requested continuity class.

- **Parameters:** `continuity` — target minimum continuity; the shape is split at any face/edge boundary that does not meet this standard.
- **Returns:** Divided shape, or nil on failure.
- **OCCT:** `ShapeUpgrade_ShapeDivideContinuity` (via `OCCTShapeDivide`).
- **Example:**
  ```swift
  if let divided = myShape.divided(at: .c1) {
      // faces now have at least C1 continuity boundaries
  }
  ```

---

### `directFaces()`

Convert geometry to direct faces (canonical surfaces).

```swift
public func directFaces() -> Shape?
```

Applies `ShapeCustom_DirectModification` to replace indirect or offset surface references with direct canonical geometry, normalising outward face normals.

- **Returns:** Shape with canonical surfaces, or nil on failure.
- **OCCT:** `ShapeCustom_DirectModification` (via `OCCTShapeDirectFaces`).
- **Example:**
  ```swift
  if let direct = imported.directFaces() {
      // surfaces are now stored directly, not via references
  }
  ```

---

### `scaledGeometry(factor:)`

Scale shape geometry by a factor.

```swift
public func scaledGeometry(factor: Double) -> Shape?
```

Unlike `scaled(by:)` which applies a topological `gp_Trsf`, this modifies the underlying curve and surface pole coordinates directly.

- **Parameters:** `factor` — uniform scale factor applied to all geometry definitions.
- **Returns:** Scaled shape, or nil on failure.
- **OCCT:** `ShapeCustom_TrsfModification` (via `OCCTShapeScaleGeometry`).
- **Example:**
  ```swift
  if let mmShape = inchShape.scaledGeometry(factor: 25.4) {
      // geometry converted from inches to millimetres
  }
  ```

---

### `bsplineRestriction(surfaceTolerance:curveTolerance:maxDegree:maxSegments:)`

Convert BSpline surfaces to their closest analytical form.

```swift
public func bsplineRestriction(surfaceTolerance: Double = 0.01,
                               curveTolerance: Double = 0.01,
                               maxDegree: Int = 9,
                               maxSegments: Int = 10000) -> Shape?
```

Attempts to simplify BSpline surfaces to planes, cylinders, cones, spheres, or tori within the supplied tolerances. Surfaces that cannot be recognised remain as BSplines with degree and segment count capped at the supplied limits.

- **Parameters:**
  - `surfaceTolerance` — maximum allowable deviation for surface approximation (default 0.01).
  - `curveTolerance` — maximum allowable deviation for curve approximation (default 0.01).
  - `maxDegree` — maximum BSpline degree to allow (default 9).
  - `maxSegments` — maximum number of BSpline segments (default 10000).
- **Returns:** Shape with restricted BSplines, or nil on failure.
- **OCCT:** `ShapeCustom_BSplineRestriction` (via `OCCTShapeBSplineRestriction`).
- **Example:**
  ```swift
  if let simplified = imported.bsplineRestriction(surfaceTolerance: 0.001, curveTolerance: 0.001) {
      print(simplified.contents.faces)
  }
  ```

---

### `sweptToElementary()`

Convert swept surfaces to elementary (canonical) surfaces.

```swift
public func sweptToElementary() -> Shape?
```

Recognises surfaces of extrusion and revolution that degenerate into planes, cylinders, cones, spheres, or tori, and replaces them with the exact canonical form.

- **Returns:** Shape with elementary surfaces, or nil on failure.
- **OCCT:** `ShapeCustom_SweptToElementary` (via `OCCTShapeSweptToElementary`).
- **Example:**
  ```swift
  if let canonical = swept.sweptToElementary() {
      // cylindrical extrusion is now a true Geom_CylindricalSurface
  }
  ```

---

### `revolutionToElementary()`

Convert surfaces of revolution to elementary surfaces.

```swift
public func revolutionToElementary() -> Shape?
```

Similar to `sweptToElementary()` but targets only surfaces of revolution.

- **Returns:** Shape with elementary surfaces, or nil on failure.
- **OCCT:** `ShapeCustom_SweptToElementary` (via `OCCTShapeRevolutionToElementary`).
- **Example:**
  ```swift
  if let canonical = importedRevol.revolutionToElementary() { }
  ```

---

### `convertedToBSpline()`

Convert all surfaces to BSpline representation.

```swift
public func convertedToBSpline() -> Shape?
```

Replaces every analytic and swept surface with an equivalent BSpline/NURBS form. Useful for export to systems that only handle polynomial geometry.

- **Returns:** Shape with BSpline surfaces, or nil on failure.
- **OCCT:** `ShapeCustom_BSplineRestriction` / `BRepBuilderAPI_NurbsConvert` (via `OCCTShapeConvertToBSpline`).
- **Example:**
  ```swift
  if let bspline = solid.convertedToBSpline() {
      // all faces backed by Geom_BSplineSurface
  }
  ```

---

### `sewn(tolerance:)`

Sew disconnected faces in this shape together.

```swift
public func sewn(tolerance: Double = 1e-6) -> Shape?
```

Applies `BRepBuilderAPI_Sewing` to merge near-coincident edges and produce a closed shell or solid.

- **Parameters:** `tolerance` — sewing tolerance; edges closer than this distance are merged (default 1e-6).
- **Returns:** Sewn shape, or nil on failure.
- **OCCT:** `BRepBuilderAPI_Sewing` (via `OCCTShapeSewSingle`).
- **Example:**
  ```swift
  if let shell = faceCompound.sewn(tolerance: 1e-4) { }
  ```

---

### `upgraded(tolerance:)`

Upgrade shape: sew + make solid + heal pipeline.

```swift
public func upgraded(tolerance: Double = 1e-6) -> Shape?
```

Applies a complete upgrade pipeline: sewing of disconnected faces, an attempt to build a solid from the resulting shells, and a final `ShapeFix_Shape` healing pass.

- **Parameters:** `tolerance` — tolerance used for sewing and healing (default 1e-6).
- **Returns:** Upgraded shape, or nil on failure.
- **OCCT:** `BRepBuilderAPI_Sewing` + `BRepBuilderAPI_MakeSolid` + `ShapeFix_Shape` (via `OCCTShapeUpgrade`).
- **Example:**
  ```swift
  if let solid = roughImport.upgraded(tolerance: 0.01) {
      #expect(solid.isValid)
  }
  ```

---

## Point Classification

### `PointClassification`

Classification of a point relative to a shape or face.

```swift
public enum PointClassification: Int32, Sendable {
    case inside    = 0   // TopAbs_IN
    case outside   = 1   // TopAbs_OUT
    case onBoundary = 2  // TopAbs_ON
    case unknown   = 3   // TopAbs_UNKNOWN
}
```

---

### `Shape.classify(point:tolerance:)`

Classify a point relative to this solid.

```swift
public func classify(point: SIMD3<Double>, tolerance: Double = 1e-6) -> PointClassification
```

Determines whether a 3D point is inside, outside, or on the boundary of this shape. The shape should be a closed solid for reliable results.

- **Parameters:**
  - `point` — the 3D world-space point to classify.
  - `tolerance` — boundary-detection tolerance (default 1e-6).
- **Returns:** `.inside`, `.outside`, `.onBoundary`, or `.unknown`.
- **OCCT:** `BRepClass3d_SolidClassifier` (via `OCCTClassifyPointInSolid`).
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  let result = box.classify(point: SIMD3(5, 5, 5))
  #expect(result == .inside)
  ```

---

### `Face.classify(point:tolerance:)`

Classify a point relative to this face using a 3D point.

```swift
public func classify(point: SIMD3<Double>, tolerance: Double = 1e-6) -> PointClassification
```

Projects the 3D point to the face's surface and tests whether the resulting UV coordinate lies inside the face boundary.

- **Parameters:**
  - `point` — 3D point to classify.
  - `tolerance` — boundary-detection tolerance (default 1e-6).
- **Returns:** `.inside`, `.outside`, `.onBoundary`, or `.unknown`.
- **OCCT:** `BRepClass_FaceClassifier` (via `OCCTClassifyPointOnFace`).
- **Example:**
  ```swift
  let face: Face = ...
  let cls = face.classify(point: SIMD3(1, 1, 0))
  ```

---

### `Face.classify(u:v:tolerance:)`

Classify a point relative to this face using UV parameters.

```swift
public func classify(u: Double, v: Double, tolerance: Double = 1e-6) -> PointClassification
```

Tests the given parametric UV coordinate directly against the face boundary — faster than the 3D overload when UV is already known.

- **Parameters:**
  - `u` — U parameter on the face's surface.
  - `v` — V parameter on the face's surface.
  - `tolerance` — boundary-detection tolerance (default 1e-6).
- **Returns:** `.inside`, `.outside`, `.onBoundary`, or `.unknown`.
- **OCCT:** `BRepClass_FaceClassifier` (via `OCCTClassifyPointOnFaceUV`).
- **Example:**
  ```swift
  let face: Face = ...
  let cls = face.classify(u: 0.5, v: 0.5)
  ```

---

## Shape Proximity

### `FaceProximityPair`

A pair of face indices detected as near-miss (within tolerance).

```swift
public struct FaceProximityPair: Sendable {
    public let face1Index: Int
    public let face2Index: Int
}
```

Each instance identifies one pair of faces — one from `self`, one from `other` — that lie within the supplied tolerance. Indices refer to the face-iteration order of the respective shape.

---

### `proximityFaces(with:tolerance:deflection:)`

Detect face pairs between this shape and another that are within tolerance.

```swift
public func proximityFaces(with other: Shape, tolerance: Double, deflection: Double = 0.1) -> [FaceProximityPair]
```

Triangulates both shapes and tests proximity using `BRepExtrema_ShapeProximity`.

- **Parameters:**
  - `other` — the second shape to test against.
  - `tolerance` — maximum gap distance for a pair to be reported.
  - `deflection` — linear mesh deflection for proximity triangulation (default 0.1 mm).
- **Returns:** Array of `FaceProximityPair`; may be empty.
- **OCCT:** `BRepExtrema_ShapeProximity` (via `OCCTShapeProximity`).
- **Example:**
  ```swift
  let pairs = partA.proximityFaces(with: partB, tolerance: 0.5)
  for p in pairs {
      print("face \(p.face1Index) ↔ face \(p.face2Index)")
  }
  ```

---

### `selfIntersects`

Check if this shape self-intersects.

```swift
public var selfIntersects: Bool { get }
```

- **Returns:** `true` if the shape has self-intersecting faces.
- **OCCT:** `BOPAlgo_CheckerSI` (via `OCCTShapeSelfIntersects`).
- **Example:**
  ```swift
  if shape.selfIntersects {
      // apply healing before booleans
  }
  ```

---

## Wedge Primitive

### `Shape.wedge(dx:dy:dz:ltx:)`

Create a wedge (tapered box).

```swift
public static func wedge(dx: Double, dy: Double, dz: Double, ltx: Double) -> Shape?
```

A wedge is a box whose top face is narrowed in the X direction. When `ltx == dx` the result is a regular box; when `ltx == 0` the result is a pyramid.

- **Parameters:**
  - `dx` — width in X.
  - `dy` — height in Y.
  - `dz` — depth in Z.
  - `ltx` — width of the top face in X (0 to dx).
- **Returns:** Wedge solid, or nil if parameters are invalid (any dimension ≤ 0 or `ltx` < 0).
- **OCCT:** `BRepPrimAPI_MakeWedge` (via `OCCTShapeCreateWedge`).
- **Example:**
  ```swift
  if let wedge = Shape.wedge(dx: 10, dy: 5, dz: 8, ltx: 4) { }
  ```

---

### `Shape.wedge(dx:dy:dz:xmin:zmin:xmax:zmax:)`

Create an advanced wedge with custom top-face bounds.

```swift
public static func wedge(dx: Double, dy: Double, dz: Double,
                         xmin: Double, zmin: Double,
                         xmax: Double, zmax: Double) -> Shape?
```

- **Parameters:**
  - `dx`, `dy`, `dz` — box dimensions.
  - `xmin`, `zmin`, `xmax`, `zmax` — top face bounds within the XZ plane of the box.
- **Returns:** Wedge solid, or nil on failure.
- **OCCT:** `BRepPrimAPI_MakeWedge` (via `OCCTShapeCreateWedgeAdvanced`).
- **Example:**
  ```swift
  if let w = Shape.wedge(dx: 10, dy: 5, dz: 8, xmin: 2, zmin: 1, xmax: 8, zmax: 7) { }
  ```

---

### `Shape.wedge(at:direction:dx:dy:dz:ltx:)`

Create an oriented wedge at an arbitrary origin along an arbitrary direction.

```swift
public static func wedge(
    at origin: SIMD3<Double>,
    direction: SIMD3<Double>,
    dx: Double, dy: Double, dz: Double,
    ltx: Double
) -> Shape?
```

- **Parameters:**
  - `origin` — corner point of the wedge.
  - `direction` — axis direction for the wedge height (normalised internally).
  - `dx`, `dy`, `dz` — dimensions in the local frame.
  - `ltx` — width of top face in X (0 to dx).
- **Returns:** Wedge solid, or nil on failure.
- **OCCT:** `BRepPrimAPI_MakeWedge` (via `OCCTShapeCreateWedgeOriented`).
- **Example:**
  ```swift
  if let w = Shape.wedge(at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, 1),
                         dx: 10, dy: 5, dz: 8, ltx: 4) { }
  ```

---

## NURBS Conversion

### `convertedToNURBS()`

Convert all curves and surfaces to NURBS representation.

```swift
public func convertedToNURBS() -> Shape?
```

Ensures uniform polynomial representation before export or for algorithms that require NURBS geometry (e.g. certain CAM kernels).

- **Returns:** Shape with all geometry as NURBS, or nil on failure.
- **OCCT:** `BRepBuilderAPI_NurbsConvert` (via `OCCTShapeConvertToNURBS`).
- **Example:**
  ```swift
  if let nurbs = solid.convertedToNURBS() {
      // export to a NURBS-only format
  }
  ```

---

## Fast Sewing

### `fastSewn(tolerance:)`

Sew faces using the fast sewing algorithm.

```swift
public func fastSewn(tolerance: Double = 1e-6) -> Shape?
```

Faster than `sewn(tolerance:)` for large models with many faces, but handles fewer edge cases (non-manifold topology, very irregular gaps).

- **Parameters:** `tolerance` — sewing tolerance (default 1e-6).
- **Returns:** Sewn shape, or nil on failure.
- **OCCT:** `BRepBuilderAPI_FastSewing` (via `OCCTShapeFastSewn`).
- **Example:**
  ```swift
  if let shell = largeFaceSoup.fastSewn(tolerance: 1e-4) { }
  ```

---

## Normal Projection

### `normalProjection(of:tolerance3D:tolerance2D:maxDegree:maxSegments:)`

Project a wire or edge onto this shape along surface normals.

```swift
public func normalProjection(of wireOrEdge: Shape,
                              tolerance3D: Double = 1e-4,
                              tolerance2D: Double = 1e-5,
                              maxDegree: Int = 14,
                              maxSegments: Int = 16) -> Shape?
```

Projects `wireOrEdge` onto `self` along the normal of the nearest surface face, producing a wire that lies exactly on the surface. The result is approximated as BSplines within the given tolerances.

- **Parameters:**
  - `wireOrEdge` — the wire or edge `Shape` to project.
  - `tolerance3D` — 3D approximation tolerance (default 1e-4).
  - `tolerance2D` — 2D (parametric) approximation tolerance (default 1e-5).
  - `maxDegree` — maximum BSpline degree for the result (default 14).
  - `maxSegments` — maximum BSpline segments (default 16).
- **Returns:** Projected shape (compound of wires), or nil on failure.
- **OCCT:** `BRepOffsetAPI_NormalProjection` (via `OCCTShapeNormalProjection`).
- **Example:**
  ```swift
  let logo: Shape = ...  // a planar wire
  if let onSurface = cylinder.normalProjection(of: logo) { }
  ```

---

## Half-Space

### `Shape.halfSpace(face:referencePoint:)`

Create a half-space solid from a face.

```swift
public static func halfSpace(face: Shape, referencePoint: SIMD3<Double>) -> Shape?
```

A half-space is an infinite solid bounded by the dividing face. The reference point indicates which side of the face is considered "solid."

- **Parameters:**
  - `face` — a `Shape` containing the dividing face.
  - `referencePoint` — a point on the desired solid side of the face.
- **Returns:** Half-space solid, or nil on failure.
- **OCCT:** `BRepPrimAPI_MakeHalfSpace` (via `OCCTShapeCreateHalfSpace`).
- **Example:**
  ```swift
  let plane = Shape.face(from: Surface.plane(origin: .zero, normal: SIMD3(0,0,1))!,
                         uRange: -100...100, vRange: -100...100)!
  if let upper = Shape.halfSpace(face: plane, referencePoint: SIMD3(0, 0, 1)) { }
  ```

---

## Sub-Shape Replacement

### `replacingSubShape(_:with:)`

Replace a sub-shape within this shape.

```swift
public func replacingSubShape(_ oldSubShape: Shape, with newSubShape: Shape) -> Shape?
```

- **Parameters:**
  - `oldSubShape` — the sub-shape to replace (face, edge, vertex, etc.).
  - `newSubShape` — the replacement sub-shape of the same type.
- **Returns:** Modified shape, or nil on failure.
- **OCCT:** `BRepTools_ReShape` (via `OCCTShapeReplaceSubShape`).
- **Example:**
  ```swift
  if let modified = compound.replacingSubShape(oldFace, with: newFace) { }
  ```

---

### `removingSubShape(_:)`

Remove a sub-shape from this shape.

```swift
public func removingSubShape(_ subShape: Shape) -> Shape?
```

- **Parameters:** `subShape` — the sub-shape to remove.
- **Returns:** Modified shape, or nil on failure.
- **OCCT:** `BRepTools_ReShape` (via `OCCTShapeRemoveSubShape`).
- **Example:**
  ```swift
  if let cleaned = compound.removingSubShape(unwantedFace) { }
  ```

---

## Periodic Shapes

### `makePeriodic(xPeriod:yPeriod:zPeriod:)`

Make this shape periodic in one or more directions.

```swift
public func makePeriodic(xPeriod: Double? = nil,
                          yPeriod: Double? = nil,
                          zPeriod: Double? = nil) -> Shape?
```

- **Parameters:**
  - `xPeriod` — period in X, or nil for no periodicity in X.
  - `yPeriod` — period in Y, or nil for no periodicity in Y.
  - `zPeriod` — period in Z, or nil for no periodicity in Z.
- **Returns:** Periodic shape, or nil on failure.
- **OCCT:** `BOPAlgo_MakePeriodic` (via `OCCTShapeMakePeriodic`).
- **Example:**
  ```swift
  if let lattice = cell.makePeriodic(xPeriod: 5.0, yPeriod: 5.0) { }
  ```

---

### `repeated(xPeriod:xCount:yPeriod:yCount:zPeriod:zCount:)`

Repeat this shape periodically in one or more directions.

```swift
public func repeated(xPeriod: Double? = nil, xCount: Int = 0,
                      yPeriod: Double? = nil, yCount: Int = 0,
                      zPeriod: Double? = nil, zCount: Int = 0) -> Shape?
```

- **Parameters:**
  - `xPeriod` — period in X (nil = no repetition in X).
  - `xCount` — number of repetitions along X.
  - `yPeriod`, `yCount` — period and count in Y.
  - `zPeriod`, `zCount` — period and count in Z.
- **Returns:** Repeated shape, or nil on failure.
- **OCCT:** `BOPAlgo_MakePeriodic` (via `OCCTShapeRepeat`).
- **Example:**
  ```swift
  if let grid = cell.repeated(xPeriod: 5, xCount: 4, yPeriod: 5, yCount: 3) { }
  ```

---

## Draft from Shape

### `draft(direction:angle:length:)`

Create a draft shell by sweeping this shape along a direction with a taper angle.

```swift
public func draft(direction: SIMD3<Double>, angle: Double, length: Double) -> Shape?
```

- **Parameters:**
  - `direction` — draft direction vector.
  - `angle` — taper angle in radians.
  - `length` — maximum draft length.
- **Returns:** Draft shell shape, or nil on failure.
- **OCCT:** `BRepOffsetAPI_MakeDraft` (via `OCCTShapeMakeDraft`).
- **Example:**
  ```swift
  if let drafted = profile.draft(direction: SIMD3(0, 0, -1), angle: 0.05, length: 20) { }
  ```

---

## Non-Uniform Scale

### `nonUniformScaled(sx:sy:sz:)`

Scale this shape non-uniformly along each axis.

```swift
public func nonUniformScaled(sx: Double, sy: Double, sz: Double) -> Shape?
```

Unlike `scaled(by:)` (uniform), this applies independent scale factors per axis using a general affine transform.

- **Parameters:**
  - `sx` — scale factor along X.
  - `sy` — scale factor along Y.
  - `sz` — scale factor along Z.
- **Returns:** Scaled shape, or nil on failure.
- **OCCT:** `BRepBuilderAPI_GTransform` (via `OCCTShapeNonUniformScale`).
- **Example:**
  ```swift
  if let stretched = shape.nonUniformScaled(sx: 2, sy: 1, sz: 0.5) { }
  ```

---

## Shell & Vertex Creation

### `Shape.shell(from:)` *(Surface overload)*

Create a shell from a parametric surface.

```swift
public static func shell(from surface: Surface) -> Shape?
```

Converts a `Surface` to a topological shell shape (a single face inside a shell, no trimming).

- **Parameters:** `surface` — the parametric surface to convert.
- **Returns:** Shell shape, or nil on failure.
- **OCCT:** `BRepBuilderAPI_MakeShell` (via `OCCTShapeCreateShellFromSurface`).
- **Example:**
  ```swift
  let cyl = Surface.cylinder(radius: 5, height: 10)!
  if let shell = Shape.shell(from: cyl) { }
  ```

---

### `Shape.vertex(at:)`

Create a vertex shape at a point.

```swift
public static func vertex(at point: SIMD3<Double>) -> Shape?
```

- **Parameters:** `point` — the 3D position of the vertex.
- **Returns:** Vertex-type `Shape`, or nil on failure.
- **OCCT:** `BRepBuilderAPI_MakeVertex` (via `OCCTShapeCreateVertex`).
- **Example:**
  ```swift
  if let v = Shape.vertex(at: SIMD3(1, 2, 3)) { }
  ```

---

## Simple Offset

### `simpleOffset(by:)`

Create a simple surface-level offset of this shape.

```swift
public func simpleOffset(by distance: Double) -> Shape?
```

Moves each face by a constant distance without filleting intersections. Faster than `offset(by:)` for thin-wall shell operations where sharp offset corners are acceptable.

- **Parameters:** `distance` — offset distance; positive moves outward.
- **Returns:** Offset shape, or nil on failure.
- **OCCT:** `BRepOffset_SimpleOffset` (via `OCCTShapeSimpleOffset`).
- **Example:**
  ```swift
  if let thick = sheet.simpleOffset(by: 1.5) { }
  ```

---

## Middle Path

### `middlePath(start:end:)`

Extract the middle (spine) path from a pipe-like shape.

```swift
public func middlePath(start startShape: Shape, end endShape: Shape) -> Shape?
```

Given the two end faces or wires of a pipe-like solid, computes the medial spine wire running through the centre. Useful for reverse-engineering sweep parameters from imported geometry.

- **Parameters:**
  - `startShape` — one end of the pipe (face or wire shape).
  - `endShape` — the other end of the pipe (face or wire shape).
- **Returns:** Middle path wire, or nil on failure.
- **OCCT:** `BRepOffsetAPI_MiddlePath` (via `OCCTShapeMiddlePath`).
- **Example:**
  ```swift
  if let spine = pipeSolid.middlePath(start: capA, end: capB) { }
  ```

---

## Fuse Edges

### `fusedEdges()`

Merge connected edges that lie on the same curve.

```swift
public func fusedEdges() -> Shape?
```

Removes unnecessary edge splits introduced by boolean operations or sewing, simplifying topology for downstream algorithms and display.

- **Returns:** Shape with fused edges, or nil on failure.
- **OCCT:** `ShapeUpgrade_UnifySameDomain` / `BRepAlgo_FaceRestrictor` (via `OCCTShapeFuseEdges`).
- **Example:**
  ```swift
  if let clean = boolResult.fusedEdges() { }
  ```

---

## Volume from Faces

### `Shape.makeVolume(from:)`

Create a solid volume from a set of overlapping faces/shells.

```swift
public static func makeVolume(from shapes: [Shape]) -> Shape?
```

Closes open geometry or creates solids from imported face soups by computing the volume enclosed by the input faces.

- **Parameters:** `shapes` — array of face or shell shapes.
- **Returns:** Solid shape, or nil on failure.
- **OCCT:** `BOPAlgo_MakerVolume` (via `OCCTShapeMakeVolume`).
- **Example:**
  ```swift
  if let solid = Shape.makeVolume(from: [bottom, sides, top]) { }
  ```

---

### `Shape.makeConnected(_:)`

Connect separate shapes by making them share common geometry.

```swift
public static func makeConnected(_ shapes: [Shape]) -> Shape?
```

Makes shapes share geometry at coincident boundaries. Particularly useful for finite element mesh preparation where shapes must be conformally connected.

- **Parameters:** `shapes` — array of shapes to connect.
- **Returns:** Connected compound shape, or nil on failure.
- **OCCT:** `BOPAlgo_MakeConnected` (via `OCCTShapeMakeConnected`).
- **Example:**
  ```swift
  if let mesh = Shape.makeConnected([block1, block2, block3]) { }
  ```

---

## Shape Contents

### `ShapeContents`

Census of sub-shape counts in a shape.

```swift
public struct ShapeContents: Sendable {
    public let solids:    Int
    public let shells:    Int
    public let faces:     Int
    public let wires:     Int
    public let edges:     Int
    public let vertices:  Int
    public let freeEdges: Int
    public let freeWires: Int
    public let freeFaces: Int
}
```

---

### `contents`

Get a census of sub-shape counts in this shape.

```swift
public var contents: ShapeContents { get }
```

Reports topology complexity metrics: counts of solids, shells, faces, wires, edges, vertices, and free (unconnected) elements.

- **Returns:** A `ShapeContents` struct populated from `BRepTools` traversal.
- **OCCT:** `BRepTools` iteration (via `OCCTShapeGetContents`).
- **Example:**
  ```swift
  let c = solid.contents
  print("faces: \(c.faces), freeEdges: \(c.freeEdges)")
  ```

---

## Canonical Recognition

### `CanonicalForm`

Recognised canonical geometric form.

```swift
public struct CanonicalForm: Sendable {
    public enum FormType: Int32, Sendable {
        case unknown = 0, plane = 1, cylinder = 2, cone = 3, sphere = 4
        case line = 5, circle = 6, ellipse = 7
    }
    public let type:      FormType
    public let origin:    SIMD3<Double>
    public let direction: SIMD3<Double>
    public let radius:    Double
    public let radius2:   Double
    public let gap:       Double
}
```

- `origin` and `direction` define the axis or normal of the recognised form.
- `radius` is the primary radius; `radius2` is the secondary radius (used for ellipses and cones).
- `gap` reports the fitting residual.

---

### `recognizeCanonical(tolerance:)`

Recognise canonical geometric forms in this shape.

```swift
public func recognizeCanonical(tolerance: Double = 1e-4) -> CanonicalForm?
```

Identifies whether the shape's geometry matches a canonical form (plane, cylinder, cone, sphere, line, circle, ellipse) within the supplied tolerance.

- **Parameters:** `tolerance` — recognition tolerance (default 1e-4).
- **Returns:** A `CanonicalForm` describing the recognised form, or nil if none is found.
- **OCCT:** `ShapeAnalysis_Curve` / `BRepGProp` recognition (via `OCCTShapeRecognizeCanonical`).
- **Example:**
  ```swift
  if let form = face.recognizeCanonical() {
      switch form.type {
      case .cylinder: print("radius: \(form.radius)")
      default: break
      }
  }
  ```

---

## Find Surface

### `findSurface(tolerance:)`

Find the underlying surface of a shape (edges or wire).

```swift
public func findSurface(tolerance: Double = -1) -> Surface?
```

Determines the best-fit surface for a set of edges or a wire. Useful for reconstructing faces from imported wireframes.

- **Parameters:** `tolerance` — surface-fitting tolerance; pass -1 to use an automatic value (default).
- **Returns:** The best-fit `Surface`, or nil if none could be determined.
- **OCCT:** `BRepBuilderAPI_FindPlane` / `GeomPlate` (via `OCCTShapeFindSurface`).
- **Example:**
  ```swift
  if let surface = wireFrame.findSurface() {
      print(surface.surfaceKind)
  }
  ```

---

## Fix Wireframe

### `fixedWireframe(tolerance:)`

Fix wireframe issues (small edges, gaps).

```swift
public func fixedWireframe(tolerance: Double = 1e-4) -> Shape?
```

Applies `ShapeFix_Wireframe` to close small gaps and remove degenerate edges in the shape's wires.

- **Parameters:** `tolerance` — fixing tolerance (default 1e-4).
- **Returns:** Shape with fixed wireframe, or nil on failure.
- **OCCT:** `ShapeFix_Wireframe` (via `OCCTShapeFixWireframe`).
- **Example:**
  ```swift
  if let fixed = imported.fixedWireframe(tolerance: 0.01) { }
  ```

---

## Remove Internal Wires

### `removingInternalWires(minArea:)`

Remove internal wires (holes) smaller than a minimum area.

```swift
public func removingInternalWires(minArea: Double) -> Shape?
```

Drops holes in faces whose area is below `minArea`. Useful for cleaning up small artefact holes from boolean or import operations.

- **Parameters:** `minArea` — minimum area threshold; holes smaller than this are removed.
- **Returns:** Shape with small holes removed, or nil on failure.
- **OCCT:** `ShapeFix_Shape` / hole-removal pass (via `OCCTShapeRemoveInternalWires`).
- **Example:**
  ```swift
  if let clean = sheet.removingInternalWires(minArea: 0.25) { }
  ```

---

## Contiguous Edges

### `contiguousEdgeCount(tolerance:)`

Find pairs of edges that are coincident within tolerance.

```swift
public func contiguousEdgeCount(tolerance: Double = 1e-6) -> Int
```

Returns the count of edge pairs that are geometrically coincident (within `tolerance`) but not yet sewn. Useful as a pre-sewing diagnostic.

- **Parameters:** `tolerance` — contiguity tolerance (default 1e-6).
- **Returns:** Number of contiguous (but unsewn) edge pairs found.
- **OCCT:** `BRepBuilderAPI_Sewing` probe (via `OCCTShapeFindContiguousEdges`).
- **Example:**
  ```swift
  let gaps = faceSoup.contiguousEdgeCount(tolerance: 0.01)
  print("\(gaps) sewable edge pairs found")
  ```

---

## Quilt Faces

### `Shape.quilt(_:)`

Quilt multiple shapes (faces/shells) together into a single shell.

```swift
public static func quilt(_ shapes: [Shape]) -> Shape?
```

Joins faces that share common edges into a connected shell by identifying and merging coincident edge pairs.

- **Parameters:** `shapes` — array of face or shell shapes to quilt.
- **Returns:** Quilted shell, or nil on failure.
- **OCCT:** `BRepBuilderAPI_Sewing` (via `OCCTShapeQuilt`).
- **Example:**
  ```swift
  if let shell = Shape.quilt([top, bottom, left, right, front, back]) { }
  ```

---

## Fix Small Faces

### `fixingSmallFaces(tolerance:)`

Fix small faces by removing or merging them.

```swift
public func fixingSmallFaces(tolerance: Double = 1e-4) -> Shape?
```

Applies `ShapeFix_FixSmallFace` to identify and remove degenerate or very small faces that can cause issues in boolean and meshing operations.

- **Parameters:** `tolerance` — precision tolerance for identifying small faces (default 1e-4).
- **Returns:** Shape with small faces removed, or nil on failure.
- **OCCT:** `ShapeFix_FixSmallFace` (via `OCCTShapeFixSmallFaces`).
- **Example:**
  ```swift
  if let clean = boolResult.fixingSmallFaces(tolerance: 0.001) { }
  ```

---

## Remove Locations

### `removingLocations()`

Remove all location transforms, baking them into the geometry.

```swift
public func removingLocations() -> Shape?
```

Converts a shape with nested `TopLoc_Location` transforms (as set by assembly placement) into an equivalent shape with all geometry coordinates in the global frame.

- **Returns:** Shape with locations removed (geometry in world coordinates), or nil on failure.
- **OCCT:** `BRepBuilderAPI_Copy` with location removal (via `OCCTShapeRemoveLocations`).
- **Example:**
  ```swift
  if let flat = assemblyShape.removingLocations() {
      // all faces/edges now have identity location
  }
  ```

---

## Revolution from Curve

### `Shape.revolution(meridian:axisOrigin:axisDirection:angle:)`

Create a solid of revolution by revolving a meridian curve.

```swift
public static func revolution(meridian: Curve3D,
                              axisOrigin: SIMD3<Double> = .zero,
                              axisDirection: SIMD3<Double> = SIMD3<Double>(0, 0, 1),
                              angle: Double = 2 * .pi) -> Shape?
```

Unlike `Shape.revolution(profile:...)` which takes a wire, this revolves a `Geom_Curve` (e.g. a BSpline or arc) directly around the specified axis.

- **Parameters:**
  - `meridian` — the curve to revolve.
  - `axisOrigin` — origin of the revolution axis (default `.zero`).
  - `axisDirection` — direction of the revolution axis (default Z+).
  - `angle` — revolution angle in radians (default full revolution, 2π).
- **Returns:** Revolved shape, or nil on failure.
- **OCCT:** `BRepPrimAPI_MakeRevol` (via `OCCTShapeCreateRevolutionFromCurve`).
- **Example:**
  ```swift
  let arc = Curve3D.arc(center: .zero, radius: 5, startAngle: 0, endAngle: .pi)!
  if let solid = Shape.revolution(meridian: arc, axisDirection: SIMD3(0, 1, 0)) { }
  ```

---

## Linear Rib Feature

### `addingLinearRib(profile:direction:draftDirection:fuse:)`

Add a linear rib feature to a shape.

```swift
public func addingLinearRib(profile: Wire,
                            direction: SIMD3<Double>,
                            draftDirection: SIMD3<Double>,
                            fuse: Bool = true) -> Shape?
```

Creates a rib (reinforcement) or slot by extruding a wire profile in a given direction against the base shape.

- **Parameters:**
  - `profile` — wire profile of the rib.
  - `direction` — extrusion direction of the rib.
  - `draftDirection` — secondary direction controlling draft angle.
  - `fuse` — `true` to add material (rib); `false` to remove material (slot).
- **Returns:** Shape with rib/slot added, or nil on failure.
- **OCCT:** `BRepFeat_MakeLinearForm` (via `OCCTShapeAddLinearRib`).
- **Example:**
  ```swift
  if let ribbed = body.addingLinearRib(profile: ribWire,
                                       direction: SIMD3(0, 0, 1),
                                       draftDirection: SIMD3(1, 0, 0)) { }
  ```

---

## Revolution Form Feature

### `addingRevolutionForm(profile:axisOrigin:axisDirection:height1:height2:fuse:)`

Add a revolution form (revolved rib or groove) to a shape.

```swift
public func addingRevolutionForm(profile: Wire,
                                 axisOrigin: SIMD3<Double>,
                                 axisDirection: SIMD3<Double>,
                                 height1: Double, height2: Double,
                                 fuse: Bool = true) -> Shape?
```

Similar to `addingLinearRib`, but the rib profile follows a rotational path around the given axis — useful for knurling and annular ribs.

- **Parameters:**
  - `profile` — wire profile of the rib.
  - `axisOrigin` — origin of the revolution axis.
  - `axisDirection` — direction of the revolution axis.
  - `height1` — height on one side of the profile.
  - `height2` — height on the other side.
  - `fuse` — `true` for rib (add material); `false` for groove (remove material).
- **Returns:** Shape with revolution form, or nil on failure.
- **OCCT:** `BRepFeat_MakeRevolutionForm` (via `OCCTShapeAddRevolutionForm`).
- **Example:**
  ```swift
  if let knurled = shaft.addingRevolutionForm(profile: profileWire,
                                              axisOrigin: .zero,
                                              axisDirection: SIMD3(0, 0, 1),
                                              height1: 2, height2: 2) { }
  ```

---

## Draft Prism Feature

### `addingDraftPrism(profile:sketchFaceIndex:draftAngle:height:fuse:)`

Add a draft prism (tapered extrusion) to a shape.

```swift
public func addingDraftPrism(profile: Wire, sketchFaceIndex: Int,
                             draftAngle: Double, height: Double,
                             fuse: Bool = true) -> Shape?
```

Creates a boss or pocket with draft angle (taper), commonly used in injection mould design.

- **Parameters:**
  - `profile` — wire profile to extrude.
  - `sketchFaceIndex` — 0-based index of the face on which the profile sits.
  - `draftAngle` — draft angle in degrees.
  - `height` — extrusion height.
  - `fuse` — `true` to add material (boss); `false` to cut (pocket).
- **Returns:** Shape with draft prism, or nil on failure.
- **OCCT:** `BRepFeat_MakeDPrism` (via `OCCTShapeDraftPrism`).
- **Example:**
  ```swift
  if let boss = mould.addingDraftPrism(profile: bossWire, sketchFaceIndex: 0,
                                       draftAngle: 2.0, height: 15) { }
  ```

---

### `addingDraftPrismThruAll(profile:sketchFaceIndex:draftAngle:fuse:)`

Add a draft prism that extends through the entire shape.

```swift
public func addingDraftPrismThruAll(profile: Wire, sketchFaceIndex: Int,
                                    draftAngle: Double,
                                    fuse: Bool = true) -> Shape?
```

Like `addingDraftPrism` but the extrusion continues until it exits the opposite side of the shape.

- **Parameters:**
  - `profile` — wire profile to extrude.
  - `sketchFaceIndex` — 0-based index of the sketch face.
  - `draftAngle` — draft angle in degrees.
  - `fuse` — `true` to add material; `false` to cut.
- **Returns:** Shape with through-all draft prism, or nil on failure.
- **OCCT:** `BRepFeat_MakeDPrism` (via `OCCTShapeDraftPrismThruAll`).
- **Example:**
  ```swift
  if let pocket = mould.addingDraftPrismThruAll(profile: holeWire,
                                                sketchFaceIndex: 2,
                                                draftAngle: 1.5, fuse: false) { }
  ```

---

## Revolution Feature

### `addingRevolvedFeature(profile:sketchFaceIndex:axisOrigin:axisDirection:angle:fuse:)`

Add a revolved feature (boss or pocket) to a shape.

```swift
public func addingRevolvedFeature(profile: Wire, sketchFaceIndex: Int,
                                  axisOrigin: SIMD3<Double>,
                                  axisDirection: SIMD3<Double>,
                                  angle: Double = 360,
                                  fuse: Bool = true) -> Shape?
```

Revolves a profile around an axis to add or remove material — the parametric solid modelling equivalent of a lathe operation.

- **Parameters:**
  - `profile` — wire profile to revolve.
  - `sketchFaceIndex` — 0-based index of the face on which the profile sits.
  - `axisOrigin` — origin of the revolution axis.
  - `axisDirection` — direction of the revolution axis.
  - `angle` — revolution angle in degrees (default 360).
  - `fuse` — `true` to add material (boss); `false` to cut (pocket).
- **Returns:** Shape with revolved feature, or nil on failure.
- **OCCT:** `BRepFeat_MakeRevol` (via `OCCTShapeRevolFeature`).
- **Example:**
  ```swift
  if let groove = shaft.addingRevolvedFeature(profile: grooveWire, sketchFaceIndex: 0,
                                              axisOrigin: .zero,
                                              axisDirection: SIMD3(0, 0, 1),
                                              angle: 360, fuse: false) { }
  ```

---

### `addingRevolvedFeatureThruAll(profile:sketchFaceIndex:axisOrigin:axisDirection:fuse:)`

Add a revolved feature that revolves through 360 degrees.

```swift
public func addingRevolvedFeatureThruAll(profile: Wire, sketchFaceIndex: Int,
                                         axisOrigin: SIMD3<Double>,
                                         axisDirection: SIMD3<Double>,
                                         fuse: Bool = true) -> Shape?
```

Convenience overload that always performs a full 360° revolution.

- **Parameters:**
  - `profile`, `sketchFaceIndex`, `axisOrigin`, `axisDirection` — same as above.
  - `fuse` — `true` to add; `false` to cut.
- **Returns:** Shape with through-all revolved feature, or nil on failure.
- **OCCT:** `BRepFeat_MakeRevol` (via `OCCTShapeRevolFeatureThruAll`).
- **Example:**
  ```swift
  if let annularSlot = disc.addingRevolvedFeatureThruAll(profile: slotWire,
                                                         sketchFaceIndex: 0,
                                                         axisOrigin: .zero,
                                                         axisDirection: SIMD3(0, 0, 1),
                                                         fuse: false) { }
  ```

---

## Face from Surface

### `Shape.face(from:uRange:vRange:tolerance:)`

Create a face from a surface with specific UV parameter bounds.

```swift
public static func face(from surface: Surface,
                        uRange: ClosedRange<Double>,
                        vRange: ClosedRange<Double>,
                        tolerance: Double = 1e-6) -> Shape?
```

- **Parameters:**
  - `surface` — the parametric surface.
  - `uRange` — U parameter range (uMin...uMax).
  - `vRange` — V parameter range (vMin...vMax).
  - `tolerance` — tolerance for face creation (default 1e-6).
- **Returns:** Face shape, or nil on failure.
- **OCCT:** `BRepBuilderAPI_MakeFace` (via `OCCTShapeCreateFaceFromSurface`).
- **Example:**
  ```swift
  let cyl = Surface.cylinder(radius: 5, height: 10)!
  if let face = Shape.face(from: cyl, uRange: 0...(.pi), vRange: 0...10) { }
  ```

---

### `Shape.face(from:boundary:)`

Create a face from a surface bounded by a 3D wire.

```swift
public static func face(from surface: Surface, boundary: Wire) -> Shape?
```

Tries two strategies in order:
1. **Exact:** if the wire genuinely lies on the surface (edges have or admit pcurves), builds the face directly with `ShapeFix_Face` to project pcurves.
2. **Fallback:** projects the wire's ordered points onto the surface UV and trims by that polygon — same path as `Surface.toFace(uvBoundary:)`.

If you already have the boundary in UV space, call `Surface.toFace(uvBoundary:)` directly for efficiency.

- **Parameters:**
  - `surface` — the parametric surface to trim.
  - `boundary` — a closed wire on (or near) the surface.
- **Returns:** Trimmed face shape, or nil on failure. A boundary crossing a periodic seam (e.g. the u = 0/2π seam of a cylinder) is not handled by the projection fallback.
- **OCCT:** `BRepBuilderAPI_MakeFace` + `ShapeFix_Face` (via `OCCTShapeCreateFaceFromSurfaceWire`).
- **Example:**
  ```swift
  let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
  let boundary: Wire = ...   // a closed planar wire
  if let face = Shape.face(from: plane, boundary: boundary) { }
  ```

---

## Edges to Faces

### `Shape.facesFromEdges(_:onlyPlanar:)`

Reconstruct faces from a compound of loose edges.

```swift
public static func facesFromEdges(_ compound: Shape, onlyPlanar: Bool = true) -> Shape?
```

Takes a shape containing edges, builds closed wires from them, and creates faces from those wires.

- **Parameters:**
  - `compound` — shape containing the edges to assemble.
  - `onlyPlanar` — if `true`, only creates planar faces (default `true`).
- **Returns:** Compound of faces, or nil on failure.
- **OCCT:** `BRepBuilderAPI_MakeFace` + wire recovery (via `OCCTShapeEdgesToFaces`).
- **Example:**
  ```swift
  if let faces = Shape.facesFromEdges(edgeCompound, onlyPlanar: false) { }
  ```

---

## Shape-to-Shape Section

### `section(_:)`

Compute the intersection curves/edges between two shapes.

```swift
public func section(_ other: Shape) -> Shape?
```

Returns the intersection geometry (edges/wires) where the two shapes meet. Useful for contact curves, trim boundaries, and interference analysis.

- **Parameters:** `other` — the second shape to intersect with.
- **Returns:** Shape containing intersection edges, or nil on failure.
- **OCCT:** `BRepAlgoAPI_Section` (via `OCCTShapeSection`).
- **Example:**
  ```swift
  let plane = Shape.box(width: 100, height: 100, depth: 0.1)!
  if let crossSection = solid.section(plane) { }
  ```

---

### `section(with:)` *(deprecated)*

```swift
@available(*, deprecated, renamed: "section(_:)",
           message: "Use section(_:) to match subtracting(_:) and Set convention")
public func section(with other: Shape) -> Shape?
```

Deprecated alias for `section(_:)`. Use `section(_:)` instead.

---

## Boolean Pre-Validation

### `isValidForBoolean`

Check whether this shape is valid for boolean operations.

```swift
public var isValidForBoolean: Bool { get }
```

- **Returns:** `true` if the shape passes the OCCT boolean readiness check.
- **OCCT:** `BRepAlgoAPI_Check` (via `OCCTShapeBooleanCheck`).
- **Example:**
  ```swift
  guard shape.isValidForBoolean else { return }
  let result = shape.union(other)
  ```

---

### `isValidForBoolean(with:)`

Check whether two shapes are valid for boolean operations with each other.

```swift
public func isValidForBoolean(with other: Shape) -> Bool
```

- **Parameters:** `other` — the second shape to check compatibility with.
- **Returns:** `true` if both shapes are suitable for boolean operations together.
- **OCCT:** `BRepAlgoAPI_Check` (via `OCCTShapeBooleanCheck`).
- **Example:**
  ```swift
  guard partA.isValidForBoolean(with: partB) else { return }
  ```

---

## Split Shape by Wire

### `splittingFace(with:faceIndex:)`

Split a face by imprinting a wire onto it.

```swift
public func splittingFace(with wire: Wire, faceIndex: Int) -> Shape?
```

The wire is projected/imprinted onto the specified face, dividing it into multiple faces. Useful for mesh preparation and feature line imprinting.

- **Parameters:**
  - `wire` — wire to imprint onto the face.
  - `faceIndex` — 0-based index of the face to split.
- **Returns:** Shape with the face split by the wire, or nil on failure.
- **OCCT:** `BRepAlgoAPI_Splitter` (via `OCCTShapeSplitByWire`).
- **Example:**
  ```swift
  if let split = plate.splittingFace(with: splitWire, faceIndex: 0) { }
  ```

---

## Split by Angle

### `splitByAngle(_:)`

Split surfaces that span more than a specified angle.

```swift
public func splitByAngle(_ maxAngleDegrees: Double) -> Shape?
```

Useful for export to systems that cannot handle full 360° surfaces (e.g. splitting a full cylinder into quarter-cylinders).

- **Parameters:** `maxAngleDegrees` — maximum surface angular span in degrees (e.g. 90 for quarter-turns).
- **Returns:** Shape with surfaces split at angle boundaries, or nil on failure.
- **OCCT:** `ShapeUpgrade_ShapeSplitAngle` (via `OCCTShapeSplitByAngle`).
- **Example:**
  ```swift
  if let split = fullCylinder.splitByAngle(90) {
      // cylinder is now 4 quarter-cylindrical faces
  }
  ```

---

## Drop Small Edges

### `droppingSmallEdges(tolerance:)`

Remove degenerate/tiny edges from a shape.

```swift
public func droppingSmallEdges(tolerance: Double = 1e-6) -> Shape?
```

Useful for cleaning up imported geometry with tolerance issues where very short edges prevent boolean or meshing operations.

- **Parameters:** `tolerance` — tolerance below which edges are considered small and removed (default 1e-6).
- **Returns:** Shape with small edges removed, or nil on failure.
- **OCCT:** `ShapeFix_Wireframe` small-edge removal (via `OCCTShapeDropSmallEdges`).
- **Example:**
  ```swift
  if let clean = imported.droppingSmallEdges(tolerance: 0.001) { }
  ```

---

## Multi-Tool Boolean Fuse

### `Shape.fuseAll(_:)`

Fuse multiple shapes simultaneously.

```swift
public static func fuseAll(_ shapes: [Shape]) -> Shape?
```

More robust than sequential pairwise `union(with:)` calls — processes all intersections at once, avoiding intermediate tolerance accumulation. Requires at least two shapes.

- **Parameters:** `shapes` — array of shapes to fuse (must have ≥ 2 elements).
- **Returns:** Fused shape, or nil on failure.
- **OCCT:** `BRepAlgoAPI_Fuse` multi-tool mode (via `OCCTShapeFuseMulti`).
- **Example:**
  ```swift
  if let merged = Shape.fuseAll([a, b, c, d]) { }
  ```

---

## Multi-Offset Wire

### `multiOffsetWires(offsets:joinType:)`

Generate multiple parallel offset wires from a planar face boundary.

```swift
public func multiOffsetWires(offsets: [Double],
                             joinType: OffsetJoinType = .arc) -> [Wire]
```

More efficient than calling `Wire.offset` multiple times, and produces consistent results for CNC toolpath generation.

- **Parameters:**
  - `offsets` — array of offset distances (positive = outward, negative = inward).
  - `joinType` — how to join offset segments (default `.arc`).
- **Returns:** Array of offset `Wire`s (may be empty on failure or empty input).
- **OCCT:** `BRepOffsetAPI_MakeOffset` (via `OCCTWireMultiOffset`).
- **Example:**
  ```swift
  let paths = faceBoundary.multiOffsetWires(offsets: [-0.5, -1.0, -1.5])
  // paths[0] is the innermost wire, [2] is outermost
  ```

### `OffsetJoinType`

Join type for offset operations.

```swift
public enum OffsetJoinType: Int32, Sendable {
    case arc          = 0   // fill gaps with pipe arcs and spheres (smooth)
    case tangent      = 1   // tangent extension of faces
    case intersection = 2   // extend and intersect adjacent faces (sharp edges)
}
```

---

## Cylindrical Projection

### `Shape.projectWire(_:onto:direction:)` *(Shape overload)*

Project a wire/edge shape onto another shape along a direction (cylindrical projection).

```swift
public static func projectWire(_ wire: Shape, onto target: Shape,
                               direction: SIMD3<Double>) -> Shape?
```

Parallel-ray projection (like an orthographic shadow) — each point on `wire` is projected along `direction` until it hits `target`.

- **Parameters:**
  - `wire` — wire or edge `Shape` to project.
  - `target` — target shape to project onto.
  - `direction` — projection direction (rays are parallel).
- **Returns:** Compound of projected wires, or nil on failure.
- **OCCT:** `BRepOffsetAPI_NormalProjection` with direction (via `OCCTShapeProjectWire`).
- **Example:**
  ```swift
  if let projected = Shape.projectWire(logoShape, onto: cylinder,
                                       direction: SIMD3(1, 0, 0)) { }
  ```

---

### `Shape.projectWire(_:onto:direction:)` *(Wire overload)*

Project a Wire onto another shape along a direction (cylindrical projection).

```swift
public static func projectWire(_ wire: Wire, onto target: Shape,
                               direction: SIMD3<Double>) -> Shape?
```

Convenience overload accepting a `Wire` directly; internally converts it to a `Shape` then delegates to the `Shape` overload.

- **Parameters:** Same as the `Shape` overload but `wire` is a `Wire`.
- **Returns:** Compound of projected wires, or nil on failure.
- **OCCT:** `BRepOffsetAPI_NormalProjection` (via `OCCTShapeProjectWire`).
- **Example:**
  ```swift
  if let projected = Shape.projectWire(logoWire, onto: surface, direction: SIMD3(0, 0, -1)) { }
  ```

---

## Same Parameter

### `sameParameter(tolerance:)`

Enforce same-parameter consistency on the shape.

```swift
public func sameParameter(tolerance: Double = 1e-6) -> Shape?
```

Ensures 3D and 2D (pcurve) representations of edges are consistent in their parametrisation. Important after importing geometry or performing complex operations that may desynchronise 3D/2D curves.

- **Parameters:** `tolerance` — tolerance for the same-parameter check (default 1e-6).
- **Returns:** Fixed shape, or nil on failure.
- **OCCT:** `BRepLib::SameParameter` (via `OCCTShapeSameParameter`).
- **Example:**
  ```swift
  if let fixed = imported.sameParameter(tolerance: 1e-5) { }
  ```

---

## Conical Projection

### `Shape.projectWireConical(_:onto:eye:)` *(Shape overload)*

Project a wire/edge shape onto another shape from a point (conical projection).

```swift
public static func projectWireConical(_ wire: Shape, onto target: Shape,
                                      eye: SIMD3<Double>) -> Shape?
```

Unlike cylindrical projection (parallel rays), conical projection fans rays out from a point source — like a spotlight or perspective camera.

- **Parameters:**
  - `wire` — wire or edge `Shape` to project.
  - `target` — target shape to project onto.
  - `eye` — point source of the projection rays.
- **Returns:** Compound of projected wires, or nil on failure.
- **OCCT:** `BRepOffsetAPI_NormalProjection` with point source (via `OCCTShapeProjectWireConical`).
- **Example:**
  ```swift
  if let shadow = Shape.projectWireConical(outlineShape, onto: ground,
                                           eye: SIMD3(0, 0, 100)) { }
  ```

---

### `Shape.projectWireConical(_:onto:eye:)` *(Wire overload)*

Project a Wire onto another shape from a point (conical projection).

```swift
public static func projectWireConical(_ wire: Wire, onto target: Shape,
                                      eye: SIMD3<Double>) -> Shape?
```

Convenience overload accepting a `Wire` directly.

- **Parameters:** Same as the `Shape` overload but `wire` is a `Wire`.
- **Returns:** Compound of projected wires, or nil on failure.
- **OCCT:** `BRepOffsetAPI_NormalProjection` (via `OCCTShapeProjectWireConical`).
- **Example:**
  ```swift
  if let shadow = Shape.projectWireConical(outline, onto: floor, eye: lightPos) { }
  ```

---

## Encode Regularity

### `encodingRegularity(toleranceDegrees:)`

Mark smooth (G1-continuous) edges as "regular."

```swift
public func encodingRegularity(toleranceDegrees: Double = 1e-10) -> Shape?
```

Downstream algorithms (e.g. offset, draft) can skip regular edges for better performance. The angular tolerance controls what counts as smooth.

- **Parameters:** `toleranceDegrees` — angular tolerance in degrees; edges whose dihedral angle deviates less than this from 180° are marked regular (default 1e-10, effectively exact smoothness).
- **Returns:** Shape with regularity encoded, or nil on failure.
- **OCCT:** `BRepLib::EncodeRegularity` (via `OCCTShapeEncodeRegularity`).
- **Example:**
  ```swift
  if let encoded = fillet.encodingRegularity(toleranceDegrees: 0.01) { }
  ```

---

## Update Tolerances

### `updatingTolerances(verifyFaces:)`

Recalculate and update geometric tolerances on the shape.

```swift
public func updatingTolerances(verifyFaces: Bool = true) -> Shape?
```

- **Parameters:** `verifyFaces` — whether to verify and correct face tolerances (default `true`).
- **Returns:** Shape with updated tolerances, or nil on failure.
- **OCCT:** `BRepLib::UpdateTolerances` (via `OCCTShapeUpdateTolerances`).
- **Example:**
  ```swift
  if let tightened = result.updatingTolerances() { }
  ```

---

## Divide by Number

### `dividedByNumber(_:)`

Split faces into approximately the specified number of patches.

```swift
public func dividedByNumber(_ parts: Int) -> Shape?
```

Subdivides each face into approximately `parts` parametric patches. Useful for mesh preparation and parametric surface subdivision. Requires `parts > 1`.

- **Parameters:** `parts` — approximate number of patches per face.
- **Returns:** Shape with divided faces, or nil if `parts ≤ 1` or on failure.
- **OCCT:** `ShapeUpgrade_ShapeDivideArea` (via `OCCTShapeDivideByNumber`).
- **Example:**
  ```swift
  if let subdivided = face.dividedByNumber(4) { }
  ```

---

## Boolean with History

### `BooleanResult`

Result of a boolean operation with shape tracking.

```swift
public struct BooleanResult: Sendable {
    public let shape: Shape
    public let modifiedFaces: [Shape]
}
```

- `shape` — the result of the boolean operation.
- `modifiedFaces` — faces in the result that are modifications of faces from the first operand.

---

### `fuseWithHistory(_:)`

Fuse this shape with another and track which faces were modified.

```swift
public func fuseWithHistory(_ other: Shape) -> BooleanResult?
```

- **Parameters:** `other` — shape to fuse with.
- **Returns:** `BooleanResult` with result shape and modified-face tracking, or nil on failure.
- **OCCT:** `BRepAlgoAPI_Fuse` with history (via `OCCTShapeFuseWithHistory`).
- **Example:**
  ```swift
  if let result = base.fuseWithHistory(tool) {
      print("\(result.modifiedFaces.count) faces modified")
  }
  ```

---

### `ShapeHistoryRecord`

Per-input-subshape history for a boolean operation.

```swift
public struct ShapeHistoryRecord: Sendable {
    public let modified:   [Shape]
    public let generated:  [Shape]
    public let isDeleted:  Bool
}
```

- `modified` — output sub-shapes that are modifications of the tracked input (one face may split into several).
- `generated` — output sub-shapes generated from the input but not replacing it (e.g. fillet faces generated from an edge).
- `isDeleted` — `true` if the input was deleted with no replacement.

---

### `ShapeHistoryRef`

Retained handle to a boolean operation's builder, queryable for per-input history.

```swift
public final class ShapeHistoryRef: @unchecked Sendable
```

Used by tools that need to track selection IDs across boolean / split mutations (e.g. parametric editors that replay features). Released automatically when the reference is deallocated.

#### `record(of:)`

Look up the post-mutation history of one input sub-shape.

```swift
public func record(of inputSubShape: Shape) -> ShapeHistoryRecord
```

- **Parameters:** `inputSubShape` — any face, edge, or vertex from an original input shape.
- **Returns:** `ShapeHistoryRecord` describing what happened to that sub-shape.
- **OCCT:** `BRepAlgoAPI_BuilderAlgo::Modified` / `Generated` / `IsDeleted` (via `OCCTBooleanHistoryModified`, `OCCTBooleanHistoryGenerated`, `OCCTBooleanHistoryIsDeleted`).
- **Example:**
  ```swift
  if let (result, history) = base.unionWithFullHistory(tool) {
      let record = history.record(of: someFace)
      print("deleted: \(record.isDeleted), modified into \(record.modified.count) faces")
  }
  ```

---

### `unionWithFullHistory(_:)`

Boolean union with full per-input-subshape history.

```swift
public func unionWithFullHistory(_ other: Shape) -> (result: Shape, history: ShapeHistoryRef)?
```

- **Parameters:** `other` — shape to union with.
- **Returns:** Tuple of result shape and queryable `ShapeHistoryRef`, or nil on failure.
- **OCCT:** `BRepAlgoAPI_Fuse` (via `OCCTBooleanUnionWithHistory`).
- **Example:**
  ```swift
  if let (result, history) = a.unionWithFullHistory(b) {
      let record = history.record(of: aFace)
  }
  ```

---

### `subtractedWithFullHistory(_:)`

Boolean subtract with full per-input-subshape history.

```swift
public func subtractedWithFullHistory(_ tool: Shape) -> (result: Shape, history: ShapeHistoryRef)?
```

- **Parameters:** `tool` — shape to subtract from `self`.
- **Returns:** Tuple of result shape and history, or nil on failure.
- **OCCT:** `BRepAlgoAPI_Cut` (via `OCCTBooleanSubtractWithHistory`).
- **Example:**
  ```swift
  if let (result, history) = body.subtractedWithFullHistory(pocket) { }
  ```

---

### `intersectionWithFullHistory(_:)`

Boolean intersect with full per-input-subshape history.

```swift
public func intersectionWithFullHistory(_ other: Shape) -> (result: Shape, history: ShapeHistoryRef)?
```

- **Parameters:** `other` — shape to intersect with.
- **Returns:** Tuple of result shape and history, or nil on failure.
- **OCCT:** `BRepAlgoAPI_Common` (via `OCCTBooleanIntersectWithHistory`).
- **Example:**
  ```swift
  if let (result, history) = shapeA.intersectionWithFullHistory(shapeB) { }
  ```

---

### `splitWithFullHistory(by:)`

Split `self` by `tool` with full per-input-subshape history.

```swift
public func splitWithFullHistory(by tool: Shape) -> (pieces: [Shape], history: ShapeHistoryRef)?
```

The top-level children of the compound result are returned as individual pieces. Query history per input sub-shape via `history.record(of:)`.

- **Parameters:** `tool` — shape to split with (acts as a cutting tool).
- **Returns:** Tuple of pieces array and history, or nil on failure.
- **OCCT:** `BRepAlgoAPI_Splitter` (via `OCCTBooleanSplitWithHistory`).
- **Example:**
  ```swift
  if let (pieces, history) = solid.splitWithFullHistory(by: plane) {
      print("\(pieces.count) pieces")
  }
  ```

---

### `filletedWithFullHistory(radius:edges:)`

Apply a uniform-radius fillet to the given edges with history tracking.

```swift
public func filletedWithFullHistory(radius: Double, edges: [Int])
    -> (result: Shape, history: ShapeHistoryRef)?
```

- **Parameters:**
  - `radius` — fillet radius.
  - `edges` — 0-based edge indices to fillet.
- **Returns:** Result shape and history, or nil on failure or empty edge list.
- **OCCT:** `BRepFilletAPI_MakeFillet` (via `OCCTShapeHistoryFromFilletEdges`).
- **Example:**
  ```swift
  if let (result, history) = box.filletedWithFullHistory(radius: 2, edges: [0, 1, 2]) { }
  ```

---

### `filletedWithFullHistory(edge:startRadius:endRadius:)`

Variable-radius fillet on a single edge with history tracking.

```swift
public func filletedWithFullHistory(edge: Int, startRadius: Double, endRadius: Double)
    -> (result: Shape, history: ShapeHistoryRef)?
```

Radius varies linearly from `startRadius` (at the edge's first parameter) to `endRadius` (at last).

- **Parameters:**
  - `edge` — 0-based edge index.
  - `startRadius` — radius at the start of the edge.
  - `endRadius` — radius at the end of the edge.
- **Returns:** Result shape and history, or nil on failure.
- **OCCT:** `BRepFilletAPI_MakeFillet` variable-radius (via `OCCTShapeHistoryFromFilletEdgeVariable`).
- **Example:**
  ```swift
  if let (result, _) = body.filletedWithFullHistory(edge: 3, startRadius: 1, endRadius: 3) { }
  ```

---

### `chamferedWithFullHistory(distance:edges:)`

Apply a uniform chamfer to the given edges with history tracking.

```swift
public func chamferedWithFullHistory(distance: Double, edges: [Int])
    -> (result: Shape, history: ShapeHistoryRef)?
```

- **Parameters:**
  - `distance` — chamfer distance.
  - `edges` — 0-based edge indices to chamfer.
- **Returns:** Result shape and history, or nil on failure or empty edge list.
- **OCCT:** `BRepFilletAPI_MakeChamfer` (via `OCCTShapeHistoryFromChamferEdges`).
- **Example:**
  ```swift
  if let (chamfered, history) = part.chamferedWithFullHistory(distance: 1, edges: [4, 5]) { }
  ```

---

### `shelledWithFullHistory(facesToRemove:thickness:tolerance:)`

Shell / hollow a shape with history tracking.

```swift
public func shelledWithFullHistory(facesToRemove: [Int], thickness: Double, tolerance: Double = 1e-3)
    -> (result: Shape, history: ShapeHistoryRef)?
```

Removes the listed faces and offsets the remaining shell inward by `thickness` (negative = outward). Returns per-face history.

- **Parameters:**
  - `facesToRemove` — 0-based indices of faces to remove (become openings).
  - `thickness` — wall thickness; positive = inward offset.
  - `tolerance` — offset tolerance (default 1e-3).
- **Returns:** Result shape and history, or nil on failure or empty face list.
- **OCCT:** `BRepOffsetAPI_MakeThickSolid` (via `OCCTShapeHistoryFromShell`).
- **Example:**
  ```swift
  if let (hollow, history) = block.shelledWithFullHistory(facesToRemove: [0], thickness: 2) { }
  ```

---

### `defeaturedWithFullHistory(faces:)`

Defeature: remove given faces by reconnecting surrounding topology, with history.

```swift
public func defeaturedWithFullHistory(faces: [Int])
    -> (result: Shape, history: ShapeHistoryRef)?
```

History reports each removed face as deleted and surrounding faces as modified.

- **Parameters:** `faces` — 0-based indices of faces to remove.
- **Returns:** Result shape and history, or nil on failure or empty face list.
- **OCCT:** `BRepAlgoAPI_Defeaturing` (via `OCCTShapeHistoryFromDefeature`).
- **Example:**
  ```swift
  if let (defeatured, history) = cad.defeaturedWithFullHistory(faces: [12, 13]) { }
  ```
