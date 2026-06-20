---
title: Document — Geometry Constructors & Pipe Shells
parent: API Reference
---

# Document — Geometry Constructors & Pipe Shells

This page covers geometry construction and analysis utilities added across v0.105.0–v0.106.0 (lines 7634–8728 of `Document.swift`): 2D parabola constructors, uniform arc-length sampling, curve/surface concatenation and knot splitting, bounding-box extensions, geometric property helpers, shape reshaping, pipe-shell sweeping, directory/file access, quadric intersections, XCAF explorer queries, Unicode utilities, and shape-analysis diagnostics. For the core document lifecycle, shape tools, and STEP/IGES I/O see the main [Document](Document.md) page.

## Topics

- [GC_MakeParabola2d](#gc_makeparabola2d) · [GCPnts_UniformAbscissa](#gcpnts_uniformabscissa) · [GeomConvert CompCurveToBSplineCurve](#geomconvert-compculvetobsplinecurve) · [Geom2dConvert CompCurveToBSplineCurve](#geom2dconvert-compcurvetobsplinecurve) · [GeomConvert BSplineSurfaceKnotSplitting](#geomconvert-bsplinesurfaceknotsplitting) · [Geom2dConvert BSplineCurveKnotSplitting](#geom2dconvert-bsplinecurveknotsplitting) · [BndLib extras](#bndlib-extras) · [GProp Torus](#gprop-torus) · [BRepTools_ReShape](#breptools_reshape) · [BRepTools_Substitution](#breptools_substitution) · [BRepLib_MakeVertex](#breplib_makevertex) · [BRepFill_PipeShell](#brepfill_pipeshell) · [OSD_Directory](#osd_directory) · [IntAna Cone-Sphere extensions](#intana-cone-sphere-extensions) · [XCAFPrs_DocumentExplorer extensions](#xcafprs_documentexplorer-extensions) · [Resource_Unicode](#resource_unicode) · [GProp weighted point sets](#gprop-weighted-point-sets) · [Draft info types](#draft-info-types) · [GeomLib_LogSample](#geomlib_logsample) · [GC_MakeConicalSurface](#gc_makeconicalsurface) · [GC_MakeCylindricalSurface](#gc_makecylindricalsurface) · [GC_MakeTrimmedCone](#gc_maketrimmedcone) · [GC_MakeTrimmedCylinder](#gc_maketrimmedcylinder) · [BRepLib_MakeEdge2d extensions](#breplib_makeedge2d-extensions) · [ShapeAnalysis_Wire](#shapeanalysis_wire) · [ShapeAnalysis_Edge](#shapeanalysis_edge) · [OSD_DirectoryIterator](#osd_directoryiterator) · [OSD_FileIterator](#osd_fileiterator) · [BRepFill_PipeShell extensions](#brepfill_pipeshell-extensions)

---

## GC_MakeParabola2d

Two-dimensional parabola constructors extending `Curve2D` via `GCE2d_MakeParabola`.

### `Curve2D.gceParabola(center:direction:focalDistance:)`

Create a 2D parabola from an axis (center + direction) and focal distance.

```swift
public static func gceParabola(center: SIMD2<Double>, direction: SIMD2<Double>,
                                focalDistance: Double) -> Curve2D?
```

- **Parameters:** `center` — origin of the parabola axis; `direction` — X-direction of the axis; `focalDistance` — distance from vertex to focus.
- **Returns:** A `Curve2D` wrapping a `Geom2d_Parabola`, or `nil` if construction fails.
- **OCCT:** `GCE2d_MakeParabola`
- **Example:**
  ```swift
  if let p = Curve2D.gceParabola(center: .zero, direction: SIMD2(1, 0), focalDistance: 2.0) {
      // p represents y² = 8x in the local axis frame
  }
  ```

---

### `Curve2D.gceParabola(directrixPoint:directrixDirection:focus:)`

Create a 2D parabola from a directrix line and a focus point.

```swift
public static func gceParabola(directrixPoint: SIMD2<Double>, directrixDirection: SIMD2<Double>,
                                focus: SIMD2<Double>) -> Curve2D?
```

- **Parameters:** `directrixPoint` — a point on the directrix; `directrixDirection` — direction of the directrix; `focus` — the focus point.
- **Returns:** A `Curve2D` wrapping a `Geom2d_Parabola`, or `nil` on failure.
- **OCCT:** `GCE2d_MakeParabola` (directrix-focus constructor)
- **Example:**
  ```swift
  if let p = Curve2D.gceParabola(directrixPoint: SIMD2(-2, 0),
                                   directrixDirection: SIMD2(0, 1),
                                   focus: SIMD2(2, 0)) {
      // parabola with vertex at origin
  }
  ```

---

## GCPnts_UniformAbscissa

Uniformly sample an edge by point count or arc distance. These are extensions on `Shape` (applied to edge shapes) wrapping `GCPnts_UniformAbscissa`.

### `Shape.uniformAbscissa(pointCount:)`

Uniformly sample an edge by point count; returns parameter values.

```swift
public func uniformAbscissa(pointCount: Int) -> [Double]?
```

- **Parameters:** `pointCount` — number of sample points.
- **Returns:** Array of curve parameter values, or `nil` if the edge is invalid or sampling fails.
- **OCCT:** `GCPnts_UniformAbscissa` (by number of points)
- **Example:**
  ```swift
  if let edge = Shape.makeVertex(at: .zero),
     let params = edge.uniformAbscissa(pointCount: 10) {
      print(params.count) // up to 10
  }
  ```

---

### `Shape.uniformAbscissa(distance:)`

Uniformly sample an edge by arc distance; returns parameter values.

```swift
public func uniformAbscissa(distance: Double) -> [Double]?
```

- **Parameters:** `distance` — arc-length step between consecutive sample points.
- **Returns:** Array of curve parameter values, or `nil` on failure.
- **OCCT:** `GCPnts_UniformAbscissa` (by chord/arc length)
- **Example:**
  ```swift
  if let params = someEdgeShape.uniformAbscissa(distance: 1.0) {
      // params spaced 1.0 unit apart along the edge
  }
  ```

---

### `Shape.uniformAbscissa(pointCount:u1:u2:)`

Uniformly sample an edge by point count within a parameter range.

```swift
public func uniformAbscissa(pointCount: Int, u1: Double, u2: Double) -> [Double]?
```

- **Parameters:** `pointCount` — number of points; `u1`, `u2` — parameter range on the underlying curve.
- **Returns:** Array of parameter values, or `nil` on failure.
- **OCCT:** `GCPnts_UniformAbscissa` (range variant, by count)
- **Example:**
  ```swift
  if let params = edge.uniformAbscissa(pointCount: 5, u1: 0.0, u2: .pi) {
      // 5 evenly-spaced parameters between 0 and π
  }
  ```

---

### `Shape.uniformAbscissa(distance:u1:u2:)`

Uniformly sample an edge by arc distance within a parameter range.

```swift
public func uniformAbscissa(distance: Double, u1: Double, u2: Double) -> [Double]?
```

- **Parameters:** `distance` — arc-length step; `u1`, `u2` — parameter range.
- **Returns:** Array of parameter values, or `nil` on failure.
- **OCCT:** `GCPnts_UniformAbscissa` (range variant, by distance)
- **Example:**
  ```swift
  if let params = edge.uniformAbscissa(distance: 0.5, u1: 0.0, u2: 2.0) {
      // sampling at 0.5-unit intervals from u=0 to u=2
  }
  ```

---

## GeomConvert CompCurveToBSplineCurve

### `Curve3D.concatenate(_:tolerance:)`

Concatenate multiple bounded 3D curves into a single composite BSpline.

```swift
public static func concatenate(_ curves: [Curve3D], tolerance: Double = 1e-4) -> Curve3D?
```

- **Parameters:** `curves` — ordered list of bounded `Curve3D` segments; `tolerance` — continuity tolerance at join points.
- **Returns:** A `Curve3D` wrapping a `Geom_BSplineCurve`, or `nil` if the list is empty or concatenation fails.
- **OCCT:** `GeomConvert_CompCurveToBSplineCurve`
- **Example:**
  ```swift
  if let line = Curve3D.line(from: SIMD3(0,0,0), to: SIMD3(1,0,0)),
     let arc  = Curve3D.arc(center: SIMD3(1,0,0), radius: 1, startAngle: 0, endAngle: .pi/2),
     let joined = Curve3D.concatenate([line, arc]) {
      // single BSpline spanning both segments
  }
  ```

---

## Geom2dConvert CompCurveToBSplineCurve

### `Curve2D.concatenate(_:tolerance:)`

Concatenate multiple bounded 2D curves into a single composite BSpline.

```swift
public static func concatenate(_ curves: [Curve2D], tolerance: Double = 1e-4) -> Curve2D?
```

- **Parameters:** `curves` — ordered list of bounded `Curve2D` segments; `tolerance` — continuity tolerance at join points.
- **Returns:** A `Curve2D` wrapping a `Geom2d_BSplineCurve`, or `nil` if the list is empty or concatenation fails.
- **OCCT:** `Geom2dConvert_CompCurveToBSplineCurve`
- **Example:**
  ```swift
  if let merged = Curve2D.concatenate([seg1, seg2], tolerance: 1e-5) {
      // one BSpline in 2D
  }
  ```

---

## GeomConvert BSplineSurfaceKnotSplitting

Extensions on `Surface` wrapping `GeomConvert_BSplineSurfaceKnotSplitting`.

### `Surface.bsplineKnotSplitsU(continuity:)`

Number of U-direction knot split points required to achieve the specified continuity.

```swift
public func bsplineKnotSplitsU(continuity: Int) -> Int
```

- **Parameters:** `continuity` — desired continuity order (0 = C0, 1 = C1, …).
- **Returns:** Count of U split indices.
- **OCCT:** `GeomConvert_BSplineSurfaceKnotSplitting::NbUSplits`
- **Example:**
  ```swift
  let n = bsplineSurf.bsplineKnotSplitsU(continuity: 1)
  ```

---

### `Surface.bsplineKnotSplitsV(continuity:)`

Number of V-direction knot split points required to achieve the specified continuity.

```swift
public func bsplineKnotSplitsV(continuity: Int) -> Int
```

- **Parameters:** `continuity` — desired continuity order.
- **Returns:** Count of V split indices.
- **OCCT:** `GeomConvert_BSplineSurfaceKnotSplitting::NbVSplits`
- **Example:**
  ```swift
  let n = bsplineSurf.bsplineKnotSplitsV(continuity: 1)
  ```

---

### `Surface.bsplineKnotSplitValues(continuity:)`

Retrieve both U and V knot-split index arrays.

```swift
public func bsplineKnotSplitValues(continuity: Int) -> (uSplits: [Int32], vSplits: [Int32])
```

- **Parameters:** `continuity` — desired continuity order.
- **Returns:** Tuple of U-split and V-split knot index arrays (1-based OCCT knot indices).
- **OCCT:** `GeomConvert_BSplineSurfaceKnotSplitting::Splitting`
- **Example:**
  ```swift
  let (uIdx, vIdx) = bsplineSurf.bsplineKnotSplitValues(continuity: 1)
  ```

---

## Geom2dConvert BSplineCurveKnotSplitting

Extensions on `Curve2D` wrapping `Geom2dConvert_BSplineCurveKnotSplitting`.

### `Curve2D.bsplineKnotSplits(continuity:)`

Number of knot split points required to achieve the specified continuity for a 2D BSpline curve.

```swift
public func bsplineKnotSplits(continuity: Int) -> Int
```

- **Parameters:** `continuity` — desired continuity order.
- **Returns:** Count of split indices.
- **OCCT:** `Geom2dConvert_BSplineCurveKnotSplitting::NbSplits`
- **Example:**
  ```swift
  let n = curve2d.bsplineKnotSplits(continuity: 1)
  ```

---

### `Curve2D.bsplineKnotSplitValues(continuity:)`

Retrieve the knot-split index array for a 2D BSpline curve.

```swift
public func bsplineKnotSplitValues(continuity: Int) -> [Int32]
```

- **Parameters:** `continuity` — desired continuity order.
- **Returns:** Array of knot split indices, or empty if none.
- **OCCT:** `Geom2dConvert_BSplineCurveKnotSplitting::Splitting`
- **Example:**
  ```swift
  let splits = curve2d.bsplineKnotSplitValues(continuity: 2)
  ```

---

## BndLib extras

Analytic bounding-box extensions on `BndLib` covering conic curves and arcs.

### `BndLib.ellipse(center:normal:xDirection:majorRadius:minorRadius:tolerance:)`

Axis-aligned bounding box of a full 3D ellipse.

```swift
public static func ellipse(center: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>,
                            majorRadius: Double, minorRadius: Double, tolerance: Double = 0) -> AnalyticBounds
```

- **Parameters:** `center` — ellipse center; `normal` — plane normal; `xDirection` — major-axis direction; `majorRadius`, `minorRadius` — semi-axes; `tolerance` — optional inflation.
- **Returns:** `AnalyticBounds` with `min` and `max` corners.
- **OCCT:** `BndLib_Add3dCurve` (ellipse overload)
- **Example:**
  ```swift
  let b = BndLib.ellipse(center: .zero, normal: SIMD3(0,0,1), xDirection: SIMD3(1,0,0),
                          majorRadius: 3, minorRadius: 2)
  ```

---

### `BndLib.cone(center:axis:semiAngle:refRadius:vmin:vmax:tolerance:)`

Axis-aligned bounding box of a cone segment.

```swift
public static func cone(center: SIMD3<Double>, axis: SIMD3<Double>,
                         semiAngle: Double, refRadius: Double,
                         vmin: Double, vmax: Double, tolerance: Double = 0) -> AnalyticBounds
```

- **Parameters:** `center` — cone apex reference point; `axis` — cone axis direction; `semiAngle` — half-angle in radians; `refRadius` — radius at `center`; `vmin`, `vmax` — axial parameter range; `tolerance` — optional inflation.
- **Returns:** `AnalyticBounds`.
- **OCCT:** `BndLib_AddSurface` (cone overload)
- **Example:**
  ```swift
  let b = BndLib.cone(center: .zero, axis: SIMD3(0,0,1),
                       semiAngle: .pi/6, refRadius: 0, vmin: 0, vmax: 5)
  ```

---

### `BndLib.circleArc(center:normal:radius:u1:u2:tolerance:)`

Axis-aligned bounding box of a circular arc.

```swift
public static func circleArc(center: SIMD3<Double>, normal: SIMD3<Double>,
                               radius: Double, u1: Double, u2: Double, tolerance: Double = 0) -> AnalyticBounds
```

- **Parameters:** `center` — circle center; `normal` — plane normal; `radius` — circle radius; `u1`, `u2` — parameter range (radians); `tolerance` — optional inflation.
- **Returns:** `AnalyticBounds`.
- **OCCT:** `BndLib_Add3dCurve` (circle-arc overload)
- **Example:**
  ```swift
  let b = BndLib.circleArc(center: .zero, normal: SIMD3(0,0,1),
                             radius: 5, u1: 0, u2: .pi)
  ```

---

### `BndLib.ellipseArc(center:normal:xDirection:majorRadius:minorRadius:u1:u2:tolerance:)`

Axis-aligned bounding box of an ellipse arc.

```swift
public static func ellipseArc(center: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>,
                               majorRadius: Double, minorRadius: Double,
                               u1: Double, u2: Double, tolerance: Double = 0) -> AnalyticBounds
```

- **Parameters:** `center`, `normal`, `xDirection` — axis placement; `majorRadius`, `minorRadius` — semi-axes; `u1`, `u2` — parameter range (radians); `tolerance` — optional inflation.
- **Returns:** `AnalyticBounds`.
- **OCCT:** `BndLib_Add3dCurve` (ellipse-arc overload)
- **Example:**
  ```swift
  let b = BndLib.ellipseArc(center: .zero, normal: SIMD3(0,0,1), xDirection: SIMD3(1,0,0),
                              majorRadius: 4, minorRadius: 2, u1: 0, u2: .pi/2)
  ```

---

### `BndLib.parabolaArc(center:normal:xDirection:focalDistance:u1:u2:tolerance:)`

Axis-aligned bounding box of a parabola arc.

```swift
public static func parabolaArc(center: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>,
                                focalDistance: Double,
                                u1: Double, u2: Double, tolerance: Double = 0) -> AnalyticBounds
```

- **Parameters:** `center`, `normal`, `xDirection` — axis placement; `focalDistance` — vertex-to-focus distance; `u1`, `u2` — parameter range; `tolerance` — optional inflation.
- **Returns:** `AnalyticBounds`.
- **OCCT:** `BndLib_Add3dCurve` (parabola-arc overload)
- **Example:**
  ```swift
  let b = BndLib.parabolaArc(center: .zero, normal: SIMD3(0,0,1), xDirection: SIMD3(1,0,0),
                               focalDistance: 2, u1: -2, u2: 2)
  ```

---

### `BndLib.hyperbolaArc(center:normal:xDirection:majorRadius:minorRadius:u1:u2:tolerance:)`

Axis-aligned bounding box of a hyperbola arc.

```swift
public static func hyperbolaArc(center: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>,
                                 majorRadius: Double, minorRadius: Double,
                                 u1: Double, u2: Double, tolerance: Double = 0) -> AnalyticBounds
```

- **Parameters:** `center`, `normal`, `xDirection` — axis placement; `majorRadius`, `minorRadius` — semi-axes; `u1`, `u2` — parameter range; `tolerance` — optional inflation.
- **Returns:** `AnalyticBounds`.
- **OCCT:** `BndLib_Add3dCurve` (hyperbola-arc overload)
- **Example:**
  ```swift
  let b = BndLib.hyperbolaArc(center: .zero, normal: SIMD3(0,0,1), xDirection: SIMD3(1,0,0),
                                majorRadius: 3, minorRadius: 2, u1: -1, u2: 1)
  ```

---

## GProp Torus

Closed-form torus geometric properties on `GeometryProperties`.

### `GeometryProperties.torusSurfaceArea(majorRadius:minorRadius:)`

Exact surface area of a full torus: 4π² R r.

```swift
public static func torusSurfaceArea(majorRadius: Double, minorRadius: Double) -> Double
```

- **Parameters:** `majorRadius` — distance from torus center to tube center; `minorRadius` — tube radius.
- **Returns:** Surface area in square units.
- **OCCT:** `GProp_PEquation` / `GProp_GProps` torus formulas
- **Example:**
  ```swift
  let area = GeometryProperties.torusSurfaceArea(majorRadius: 5, minorRadius: 1)
  // ≈ 197.39
  ```

---

### `GeometryProperties.torusVolume(majorRadius:minorRadius:)`

Exact volume of a full torus: 2π² R r².

```swift
public static func torusVolume(majorRadius: Double, minorRadius: Double) -> Double
```

- **Parameters:** `majorRadius` — major radius; `minorRadius` — tube radius.
- **Returns:** Volume in cubic units.
- **OCCT:** `GProp_GProps` torus formulas
- **Example:**
  ```swift
  let vol = GeometryProperties.torusVolume(majorRadius: 5, minorRadius: 1)
  // ≈ 98.70
  ```

---

## BRepTools_ReShape

`ReShapeContext` records removals and replacements of sub-shapes and then applies them in bulk to a target shape. Wraps `BRepTools_ReShape`.

### `ReShapeContext.init()`

Create an empty reshape context.

```swift
public init()
```

- **OCCT:** `BRepTools_ReShape::BRepTools_ReShape`
- **Example:**
  ```swift
  let ctx = ReShapeContext()
  ```

---

### `ReShapeContext.clear()`

Remove all recorded modifications.

```swift
public func clear()
```

- **OCCT:** `BRepTools_ReShape::Clear`
- **Example:**
  ```swift
  ctx.clear()
  ```

---

### `ReShapeContext.remove(_:)`

Record removal of a shape from the result.

```swift
public func remove(_ shape: Shape)
```

- **Parameters:** `shape` — the sub-shape to delete.
- **OCCT:** `BRepTools_ReShape::Remove`
- **Example:**
  ```swift
  ctx.remove(edgeToDelete)
  ```

---

### `ReShapeContext.replace(_:with:)`

Record replacement of one shape with another.

```swift
public func replace(_ oldShape: Shape, with newShape: Shape)
```

- **Parameters:** `oldShape` — shape to replace; `newShape` — the replacement.
- **OCCT:** `BRepTools_ReShape::Replace`
- **Example:**
  ```swift
  ctx.replace(oldEdge, with: newEdge)
  ```

---

### `ReShapeContext.isRecorded(_:)`

Check whether a shape has been registered for removal or replacement.

```swift
public func isRecorded(_ shape: Shape) -> Bool
```

- **Parameters:** `shape` — the shape to query.
- **Returns:** `true` if the shape appears in the context.
- **OCCT:** `BRepTools_ReShape::IsRecorded`
- **Example:**
  ```swift
  if ctx.isRecorded(someEdge) { /* ... */ }
  ```

---

### `ReShapeContext.apply(to:)`

Apply all recorded modifications and return the rebuilt shape.

```swift
public func apply(to shape: Shape) -> Shape?
```

- **Parameters:** `shape` — the top-level shape to rebuild.
- **Returns:** The reshaped result, or `nil` on failure.
- **OCCT:** `BRepTools_ReShape::Apply`
- **Example:**
  ```swift
  if let result = ctx.apply(to: solid) {
      // result has the recorded changes applied
  }
  ```

---

### `ReShapeContext.value(for:)`

Retrieve the replacement value recorded for a specific shape.

```swift
public func value(for shape: Shape) -> Shape?
```

- **Parameters:** `shape` — the original shape.
- **Returns:** The recorded replacement, or `nil` if none.
- **OCCT:** `BRepTools_ReShape::Value`
- **Example:**
  ```swift
  if let replacement = ctx.value(for: oldEdge) {
      print("will replace with \(replacement)")
  }
  ```

---

## BRepTools_Substitution

Sub-shape substitution on `Shape`, wrapping `BRepTools_Substitution`.

### `Shape.substitute(oldSubShape:newSubShapes:)`

Replace a sub-shape with one or more new shapes. Pass an empty array to remove the sub-shape.

```swift
public func substitute(oldSubShape: Shape, newSubShapes: [Shape]) -> Shape?
```

- **Parameters:** `oldSubShape` — the sub-shape to replace; `newSubShapes` — replacement shapes (empty = removal).
- **Returns:** A new `Shape` with the substitution applied, or `nil` on failure.
- **OCCT:** `BRepTools_Substitution::Substitute` + `BRepTools_Substitution::Build`
- **Example:**
  ```swift
  if let rebuilt = solid.substitute(oldSubShape: oldFace, newSubShapes: [newFace]) {
      // rebuilt has oldFace replaced by newFace
  }
  ```

---

### `Shape.substitutionIsCopied(subshape:)`

Check whether a sub-shape was copied (not merely referenced) during substitution.

```swift
public func substitutionIsCopied(subshape: Shape) -> Bool
```

- **Parameters:** `subshape` — the sub-shape to query.
- **Returns:** `true` if the sub-shape was copied.
- **OCCT:** `BRepTools_Substitution::IsCopied`
- **Example:**
  ```swift
  let copied = solid.substitutionIsCopied(subshape: anEdge)
  ```

---

## BRepLib_MakeVertex

### `Shape.makeVertex(at:)`

Create a vertex `Shape` at a given 3D point using `BRepLib_MakeVertex`.

```swift
public static func makeVertex(at point: SIMD3<Double>) -> Shape?
```

- **Parameters:** `point` — 3D coordinates of the vertex.
- **Returns:** A `TopoDS_Vertex` wrapped as `Shape`, or `nil` on failure.
- **OCCT:** `BRepLib_MakeVertex`
- **Example:**
  ```swift
  if let v = Shape.makeVertex(at: SIMD3(1, 2, 3)) {
      // v is a vertex shape
  }
  ```

---

## BRepFill_PipeShell

`PipeShellBuilder` sweeps one or more profiles along a spine wire with fine-grained control over trihedron, tolerances, and transition mode. Wraps `BRepFill_PipeShell`.

### `PipeShellTransition`

Transition mode between consecutive spine segments.

```swift
public enum PipeShellTransition: Int32, Sendable {
    case modified = 0
    case right = 1
    case round = 2
}
```

- **OCCT:** `BRepFill_TransitionStyle`

---

### `PipeShellBuilder.init?(spine:)`

Create a pipe-shell builder from a spine wire.

```swift
public init?(spine: Shape)
```

- **Parameters:** `spine` — a wire `Shape` used as the sweep path.
- **Returns:** `nil` if `spine` is not a valid wire or construction fails.
- **OCCT:** `BRepFill_PipeShell::BRepFill_PipeShell`
- **Example:**
  ```swift
  if let pipe = PipeShellBuilder(spine: spineWire) {
      pipe.add(profile: profileWire)
      pipe.build()
  }
  ```

---

### `PipeShellBuilder.setFrenet(_:)`

Use the Frenet trihedron to orient the profile along the spine.

```swift
public func setFrenet(_ frenet: Bool = true)
```

- **Parameters:** `frenet` — `true` to enable Frenet mode (default).
- **OCCT:** `BRepFill_PipeShell::SetMode(Standard_Boolean)`
- **Example:**
  ```swift
  pipe.setFrenet(true)
  ```

---

### `PipeShellBuilder.setDiscrete()`

Use a discrete (piecewise constant) trihedron mode.

```swift
public func setDiscrete()
```

- **OCCT:** `BRepFill_PipeShell::SetDiscreteMode`
- **Example:**
  ```swift
  pipe.setDiscrete()
  ```

---

### `PipeShellBuilder.setFixed(binormal:)`

Fix the binormal direction of the trihedron.

```swift
public func setFixed(binormal: SIMD3<Double>)
```

- **Parameters:** `binormal` — world-space binormal direction.
- **OCCT:** `BRepFill_PipeShell::SetMode(gp_Dir)`
- **Example:**
  ```swift
  pipe.setFixed(binormal: SIMD3(0, 0, 1))
  ```

---

### `PipeShellBuilder.add(profile:)`

Add a profile wire or vertex at the current (default) position on the spine.

```swift
public func add(profile: Shape)
```

- **Parameters:** `profile` — the cross-sectional profile (`TopoDS_Wire` or `TopoDS_Vertex`).
- **OCCT:** `BRepFill_PipeShell::Add`
- **Example:**
  ```swift
  pipe.add(profile: circleWire)
  ```

---

### `PipeShellBuilder.add(profile:atVertex:)`

Add a profile at a specific vertex on the spine.

```swift
public func add(profile: Shape, atVertex vertex: Shape)
```

- **Parameters:** `profile` — the cross-sectional profile; `vertex` — a `TopoDS_Vertex` on the spine.
- **OCCT:** `BRepFill_PipeShell::Add` (vertex-pinned overload)
- **Example:**
  ```swift
  pipe.add(profile: smallCircle, atVertex: spineStart)
  pipe.add(profile: largeCircle, atVertex: spineEnd)
  ```

---

### `PipeShellBuilder.setLaw(profile:law:)`

Attach a scaling law to a profile so the section varies along the spine.

```swift
public func setLaw(profile: Shape, law: LawFunction)
```

- **Parameters:** `profile` — the cross-section profile; `law` — a `LawFunction` driving scale or parameter evolution.
- **OCCT:** `BRepFill_PipeShell::SetLaw`
- **Example:**
  ```swift
  pipe.setLaw(profile: profileWire, law: scalingLaw)
  ```

---

### `PipeShellBuilder.setTolerance(tol3d:boundTol:tolAngular:)`

Set approximation tolerances.

```swift
public func setTolerance(tol3d: Double, boundTol: Double, tolAngular: Double)
```

- **Parameters:** `tol3d` — 3D approximation tolerance; `boundTol` — boundary tolerance; `tolAngular` — angular tolerance (radians).
- **OCCT:** `BRepFill_PipeShell::SetTolerance`
- **Example:**
  ```swift
  pipe.setTolerance(tol3d: 1e-4, boundTol: 1e-4, tolAngular: 1e-3)
  ```

---

### `PipeShellBuilder.setTransition(_:)`

Set the transition mode between consecutive spine segments.

```swift
public func setTransition(_ mode: PipeShellTransition)
```

- **Parameters:** `mode` — `.modified`, `.right`, or `.round`.
- **OCCT:** `BRepFill_PipeShell::SetTransition`
- **Example:**
  ```swift
  pipe.setTransition(.round)
  ```

---

### `PipeShellBuilder.build()`

Perform the sweep computation.

```swift
@discardableResult
public func build() -> Bool
```

- **Returns:** `true` if the build succeeded.
- **OCCT:** `BRepFill_PipeShell::Build`
- **Example:**
  ```swift
  guard pipe.build() else { /* handle failure */ }
  ```

---

### `PipeShellBuilder.shape`

The resulting swept shape.

```swift
public var shape: Shape? { get }
```

- **Returns:** The swept shell or solid, or `nil` if `build()` has not been called or failed.
- **OCCT:** `BRepFill_PipeShell::Shape`
- **Example:**
  ```swift
  if let result = pipe.shape {
      // use result
  }
  ```

---

### `PipeShellBuilder.makeSolid()`

Close the pipe shell into a solid by capping the open ends.

```swift
@discardableResult
public func makeSolid() -> Bool
```

- **Returns:** `true` if solid construction succeeded.
- **OCCT:** `BRepFill_PipeShell::MakeSolid`
- **Example:**
  ```swift
  pipe.build()
  pipe.makeSolid()
  ```

---

### `PipeShellBuilder.error`

Approximation error of the swept surface.

```swift
public var error: Double { get }
```

- **Returns:** Maximum deviation between the exact surface and the B-Spline approximation.
- **OCCT:** `BRepFill_PipeShell::ErrorOnSurface`
- **Example:**
  ```swift
  print("error:", pipe.error)
  ```

---

### `PipeShellBuilder.isReady`

Whether the builder has enough profiles to begin sweeping.

```swift
public var isReady: Bool { get }
```

- **Returns:** `true` when at least one profile has been added and the builder is configured.
- **OCCT:** `BRepFill_PipeShell::IsReady`
- **Example:**
  ```swift
  guard pipe.isReady else { /* add profile first */ }
  ```

---

## OSD_Directory

File-system directory operations via `OSD_Directory`. All members are on the `DirectoryUtils` enum.

### `DirectoryUtils.exists(_:)`

Check whether a directory exists at the given path.

```swift
public static func exists(_ path: String) -> Bool
```

- **Parameters:** `path` — file-system path.
- **OCCT:** `OSD_Directory::Exists`
- **Example:**
  ```swift
  if DirectoryUtils.exists("/tmp/mydir") { /* ... */ }
  ```

---

### `DirectoryUtils.create(_:)`

Create a directory at the given path.

```swift
@discardableResult
public static func create(_ path: String) -> Bool
```

- **Parameters:** `path` — file-system path to create.
- **Returns:** `true` on success.
- **OCCT:** `OSD_Directory::Build`
- **Example:**
  ```swift
  DirectoryUtils.create("/tmp/output")
  ```

---

### `DirectoryUtils.buildTemporary()`

Create a uniquely named temporary directory and return its path.

```swift
public static func buildTemporary() -> String?
```

- **Returns:** The path of the created temporary directory, or `nil` on failure.
- **OCCT:** `OSD_Directory::BuildTemporary`
- **Example:**
  ```swift
  if let tmp = DirectoryUtils.buildTemporary() {
      print("temp dir:", tmp)
  }
  ```

---

### `DirectoryUtils.remove(_:)`

Remove a directory at the given path.

```swift
@discardableResult
public static func remove(_ path: String) -> Bool
```

- **Parameters:** `path` — file-system path.
- **Returns:** `true` on success.
- **OCCT:** `OSD_Directory::Remove`
- **Example:**
  ```swift
  DirectoryUtils.remove("/tmp/mydir")
  ```

---

## IntAna Cone-Sphere extensions

Analytical intersection of a Z-axis cone with a sphere, extending `QuadricIntersection`.

### `QuadricIntersection.coneSphere(semiAngle:refRadius:sphereCenter:sphereRadius:tolerance:)`

Compute the number of intersection curves between a Z-axis cone and a sphere.

```swift
public static func coneSphere(semiAngle: Double, refRadius: Double,
                               sphereCenter: SIMD3<Double>, sphereRadius: Double,
                               tolerance: Double = 1e-6) -> Int?
```

- **Parameters:** `semiAngle` — cone half-angle (radians); `refRadius` — cone radius at its reference plane; `sphereCenter`, `sphereRadius` — sphere definition; `tolerance` — intersection tolerance.
- **Returns:** Number of intersection curves (0, 1, or 2), or `nil` on error (e.g. identical surfaces).
- **OCCT:** `IntAna_QuadQuadGeo` (cone-sphere)
- **Example:**
  ```swift
  if let n = QuadricIntersection.coneSphere(semiAngle: .pi/4, refRadius: 0,
                                             sphereCenter: SIMD3(0,0,5), sphereRadius: 3) {
      print("curves:", n)
  }
  ```

---

### `QuadricIntersection.coneSpherePoints(semiAngle:refRadius:sphereCenter:sphereRadius:tolerance:curveIndex:sampleCount:)`

Sample points along a specific cone-sphere intersection curve.

```swift
public static func coneSpherePoints(semiAngle: Double, refRadius: Double,
                                     sphereCenter: SIMD3<Double>, sphereRadius: Double,
                                     tolerance: Double = 1e-6,
                                     curveIndex: Int, sampleCount: Int) -> [SIMD3<Double>]
```

- **Parameters:** `curveIndex` — 0-based index of the intersection curve; `sampleCount` — number of points to evaluate; other parameters as in `coneSphere`.
- **Returns:** Array of up to `sampleCount` 3D points on the intersection curve.
- **OCCT:** `IntAna_Curve::Value`
- **Example:**
  ```swift
  let pts = QuadricIntersection.coneSpherePoints(semiAngle: .pi/4, refRadius: 0,
                                                  sphereCenter: SIMD3(0,0,5), sphereRadius: 3,
                                                  curveIndex: 0, sampleCount: 32)
  ```

---

### `QuadricIntersection.coneSphereIsOpen(semiAngle:refRadius:sphereCenter:sphereRadius:tolerance:curveIndex:)`

Check whether a cone-sphere intersection curve is open (has finite parameter domain).

```swift
public static func coneSphereIsOpen(semiAngle: Double, refRadius: Double,
                                     sphereCenter: SIMD3<Double>, sphereRadius: Double,
                                     tolerance: Double = 1e-6, curveIndex: Int) -> Bool
```

- **Parameters:** Same geometry as `coneSphere`; `curveIndex` — 0-based curve index.
- **Returns:** `true` if the intersection curve is open.
- **OCCT:** `IntAna_Curve::IsOpen`
- **Example:**
  ```swift
  let open = QuadricIntersection.coneSphereIsOpen(semiAngle: .pi/4, refRadius: 0,
                                                   sphereCenter: SIMD3(0,0,5), sphereRadius: 3,
                                                   curveIndex: 0)
  ```

---

### `QuadricIntersection.coneSphereDomain(semiAngle:refRadius:sphereCenter:sphereRadius:tolerance:curveIndex:)`

Retrieve the valid parameter domain of a cone-sphere intersection curve.

```swift
public static func coneSphereDomain(semiAngle: Double, refRadius: Double,
                                     sphereCenter: SIMD3<Double>, sphereRadius: Double,
                                     tolerance: Double = 1e-6, curveIndex: Int) -> ClosedRange<Double>
```

- **Parameters:** Same geometry as `coneSphere`; `curveIndex` — 0-based curve index.
- **Returns:** `first...last` parameter range.
- **OCCT:** `IntAna_Curve::Domain`
- **Example:**
  ```swift
  let domain = QuadricIntersection.coneSphereDomain(semiAngle: .pi/4, refRadius: 0,
                                                     sphereCenter: SIMD3(0,0,5), sphereRadius: 3,
                                                     curveIndex: 0)
  print(domain) // e.g. 0.0...6.28
  ```

---

## XCAFPrs_DocumentExplorer extensions

Per-node queries on the flat explorer index maintained by `XCAFPrs_DocumentExplorer`. These extend `Document`.

### `Document.explorerDepth(at:)`

Nesting depth of an explorer node.

```swift
public func explorerDepth(at index: Int) -> Int
```

- **Parameters:** `index` — 0-based node index in the flat explorer list.
- **Returns:** Depth (0 = root).
- **OCCT:** `XCAFPrs_DocumentExplorer::Current().Depth`
- **Example:**
  ```swift
  let depth = doc.explorerDepth(at: 0)
  ```

---

### `Document.explorerIsAssembly(at:)`

Whether an explorer node represents an assembly (has children).

```swift
public func explorerIsAssembly(at index: Int) -> Bool
```

- **Parameters:** `index` — 0-based node index.
- **Returns:** `true` if the node is an assembly.
- **OCCT:** `XCAFPrs_DocumentExplorer::Current` + `XCAFDoc_ShapeTool::IsAssembly`
- **Example:**
  ```swift
  if doc.explorerIsAssembly(at: 2) { /* nested assembly */ }
  ```

---

### `Document.explorerLocation(at:)`

Location matrix for an explorer node as a flat row-major 3×4 array.

```swift
public func explorerLocation(at index: Int) -> [Double]
```

- **Parameters:** `index` — 0-based node index.
- **Returns:** 12-element array representing the 3×4 affine transformation matrix (columns: 3 rotation columns + 1 translation column, row-major).
- **OCCT:** `XCAFPrs_DocumentExplorer::Current().Location`
- **Example:**
  ```swift
  let mat = doc.explorerLocation(at: 1)
  let tx = mat[9], ty = mat[10], tz = mat[11] // translation
  ```

---

## Resource_Unicode

Global Unicode encoding format control and conversion utilities via `Resource_Unicode`.

### `UnicodeFormat`

Encoding identifier used by `UnicodeUtils`.

```swift
public enum UnicodeFormat: Int32, Sendable {
    case sjis = 0
    case euc  = 1
    case gb   = 2
    case ansi = 3
}
```

- **OCCT:** `Resource_Unicode::SetFormat` format constants

---

### `UnicodeUtils.setFormat(_:)`

Set the global multi-byte encoding format used for `Resource_Unicode` conversions.

```swift
public static func setFormat(_ format: UnicodeFormat)
```

- **Parameters:** `format` — encoding to use (SJIS, EUC, GB, or ANSI).
- **OCCT:** `Resource_Unicode::SetFormat`
- **Example:**
  ```swift
  UnicodeUtils.setFormat(.sjis)
  ```

---

### `UnicodeUtils.format`

Read the current global encoding format.

```swift
public static var format: UnicodeFormat { get }
```

- **Returns:** The currently active `UnicodeFormat`.
- **OCCT:** `Resource_Unicode::GetFormat`
- **Example:**
  ```swift
  let fmt = UnicodeUtils.format
  ```

---

### `UnicodeUtils.convertToUnicode(_:)`

Convert a multi-byte string (in the current format) to UTF-8.

```swift
public static func convertToUnicode(_ input: String) -> String?
```

- **Parameters:** `input` — string in the current multi-byte encoding.
- **Returns:** UTF-8 string, or `nil` on conversion failure.
- **OCCT:** `Resource_Unicode::ConvertUnicodeToSJIS` / `ConvertUnicodeToEUC` / etc.
- **Example:**
  ```swift
  if let utf8 = UnicodeUtils.convertToUnicode(sjisString) { /* ... */ }
  ```

---

### `UnicodeUtils.convertFromUnicode(_:maxSize:)`

Convert a UTF-8 string to the current multi-byte encoding.

```swift
public static func convertFromUnicode(_ utf8Input: String, maxSize: Int = 4096) -> String?
```

- **Parameters:** `utf8Input` — UTF-8 encoded source; `maxSize` — output buffer capacity in bytes.
- **Returns:** String in the current encoding, or `nil` on failure.
- **OCCT:** `Resource_Unicode::ConvertSJISToUnicode` / `ConvertEUCToUnicode` / etc. (inverse path)
- **Example:**
  ```swift
  if let encoded = UnicodeUtils.convertFromUnicode("テスト") { /* ... */ }
  ```

---

## GProp weighted point sets

Centroid and barycentre computation on discrete point sets, extending `GeometryProperties`.

### `GeometryProperties.weightedCentroid(points:weights:)`

Compute the weighted centroid of a point set.

```swift
public static func weightedCentroid(points: [SIMD3<Double>], weights: [Double]) -> (mass: Double, centroid: SIMD3<Double>)
```

- **Parameters:** `points` — array of 3D points; `weights` — per-point scalar weights (must be same length as `points`).
- **Returns:** Tuple of total mass (sum of weights) and the weighted centroid position.
- **OCCT:** `GProp_PEquation` / `GProp_GProps` point-set weighted mass properties
- **Example:**
  ```swift
  let pts = [SIMD3<Double>(0,0,0), SIMD3(2,0,0)]
  let (mass, center) = GeometryProperties.weightedCentroid(points: pts, weights: [1.0, 3.0])
  // center.x ≈ 1.5
  ```

---

### `GeometryProperties.barycentre(_:)`

Compute the unweighted barycentre (arithmetic mean) of a point set.

```swift
public static func barycentre(_ points: [SIMD3<Double>]) -> SIMD3<Double>
```

- **Parameters:** `points` — array of 3D points.
- **Returns:** The average position.
- **OCCT:** `GProp_PEquation::Barycentre`
- **Example:**
  ```swift
  let c = GeometryProperties.barycentre([SIMD3(0,0,0), SIMD3(4,0,0)])
  // c == SIMD3(2, 0, 0)
  ```

---

## Draft info types

Diagnostic queries on the default-constructed internal OCCT `Draft` info objects (`Draft_EdgeInfo`, `Draft_FaceInfo`, `Draft_VertexInfo`). All members are on the `DraftInfo` enum.

### `DraftInfo.edgeInfoNewGeometry`

Default `Draft_EdgeInfo::NewGeometry` flag value.

```swift
public static var edgeInfoNewGeometry: Bool { get }
```

- **OCCT:** `Draft_EdgeInfo::NewGeometry`
- **Example:**
  ```swift
  let flag = DraftInfo.edgeInfoNewGeometry
  ```

---

### `DraftInfo.faceInfoNewGeometry`

Default `Draft_FaceInfo::NewGeometry` flag value.

```swift
public static var faceInfoNewGeometry: Bool { get }
```

- **OCCT:** `Draft_FaceInfo::NewGeometry`
- **Example:**
  ```swift
  let flag = DraftInfo.faceInfoNewGeometry
  ```

---

### `DraftInfo.vertexInfoGeometry`

Geometry point of a default `Draft_VertexInfo`.

```swift
public static var vertexInfoGeometry: SIMD3<Double> { get }
```

- **OCCT:** `Draft_VertexInfo::Geometry`
- **Example:**
  ```swift
  let pt = DraftInfo.vertexInfoGeometry
  ```

---

### `DraftInfo.edgeInfoSetTangent(direction:)`

Set the tangent on a default `Draft_EdgeInfo` and report success.

```swift
public static func edgeInfoSetTangent(direction: SIMD3<Double>) -> Bool
```

- **Parameters:** `direction` — tangent direction vector.
- **Returns:** `true` if the tangent was accepted.
- **OCCT:** `Draft_EdgeInfo::SetNewGeometry` / tangent setter
- **Example:**
  ```swift
  _ = DraftInfo.edgeInfoSetTangent(direction: SIMD3(0, 0, 1))
  ```

---

### `DraftInfo.faceInfoFromSurface(_:)`

Populate a `Draft_FaceInfo` from a `Surface` and check the root-face result.

```swift
public static func faceInfoFromSurface(_ surface: Surface) -> Bool
```

- **Parameters:** `surface` — the surface to probe.
- **Returns:** `true` if the RootFace check passes.
- **OCCT:** `Draft_FaceInfo` + `RootFace`
- **Example:**
  ```swift
  if DraftInfo.faceInfoFromSurface(mySurface) { /* ... */ }
  ```

---

### `DraftInfo.vertexInfoAddParameter(_:)`

Add a parameter to a default `Draft_VertexInfo` and retrieve it back.

```swift
public static func vertexInfoAddParameter(_ param: Double) -> Double
```

- **Parameters:** `param` — the parameter value to insert.
- **Returns:** The parameter retrieved from the info object (round-trip check).
- **OCCT:** `Draft_VertexInfo::AddParam` / `Parameter`
- **Example:**
  ```swift
  let p = DraftInfo.vertexInfoAddParameter(0.5)
  ```

---

## GeomLib_LogSample

### `LogSample.sample(from:to:count:)`

Compute logarithmically spaced parameter values in [a, b].

```swift
public static func sample(from a: Double, to b: Double, count n: Int) -> [Double]
```

- **Parameters:** `a` — start of interval; `b` — end of interval; `n` — number of sample points.
- **Returns:** Array of `n` logarithmically spaced values, or empty if `n ≤ 0`.
- **OCCT:** `GeomLib_LogSample`
- **Example:**
  ```swift
  let params = LogSample.sample(from: 0.01, to: 10.0, count: 20)
  ```

---

## GC_MakeConicalSurface

Conical `Surface` constructors wrapping `GC_MakeConicalSurface`.

### `Surface.gcConicalSurface(center:normal:semiAngle:radius:)`

Create a conical surface from axis placement and cone parameters.

```swift
public static func gcConicalSurface(center: SIMD3<Double>, normal: SIMD3<Double>,
                                     semiAngle: Double, radius: Double) -> Surface?
```

- **Parameters:** `center` — origin on the cone axis; `normal` — axis direction; `semiAngle` — half-angle in radians; `radius` — reference radius at `center`.
- **Returns:** A `Surface` wrapping `Geom_ConicalSurface`, or `nil` on failure.
- **OCCT:** `GC_MakeConicalSurface`
- **Example:**
  ```swift
  if let cone = Surface.gcConicalSurface(center: .zero, normal: SIMD3(0,0,1),
                                          semiAngle: .pi/6, radius: 0) {
      // infinite conical surface
  }
  ```

---

### `Surface.gcConicalSurface2Pts(p1:p2:r1:r2:)`

Create a conical surface through two circles defined by two points and radii.

```swift
public static func gcConicalSurface2Pts(p1: SIMD3<Double>, p2: SIMD3<Double>,
                                         r1: Double, r2: Double) -> Surface?
```

- **Parameters:** `p1`, `p2` — axial positions of the two reference circles; `r1`, `r2` — respective radii.
- **Returns:** A `Surface` wrapping `Geom_ConicalSurface`, or `nil` on failure.
- **OCCT:** `GC_MakeConicalSurface` (two-point-two-radius constructor)
- **Example:**
  ```swift
  if let cone = Surface.gcConicalSurface2Pts(p1: .zero, p2: SIMD3(0,0,5),
                                              r1: 1, r2: 3) { /* ... */ }
  ```

---

### `Surface.gcConicalSurface4Pts(p1:p2:p3:p4:)`

Create a conical surface through four points (two on each base circle).

```swift
public static func gcConicalSurface4Pts(p1: SIMD3<Double>, p2: SIMD3<Double>,
                                         p3: SIMD3<Double>, p4: SIMD3<Double>) -> Surface?
```

- **Parameters:** `p1`, `p2` — two points on the first circle; `p3`, `p4` — two points on the second circle.
- **Returns:** A `Surface` wrapping `Geom_ConicalSurface`, or `nil` on failure.
- **OCCT:** `GC_MakeConicalSurface` (four-point constructor)
- **Example:**
  ```swift
  if let cone = Surface.gcConicalSurface4Pts(p1: SIMD3(1,0,0), p2: SIMD3(-1,0,0),
                                              p3: SIMD3(2,0,5), p4: SIMD3(-2,0,5)) { /* ... */ }
  ```

---

## GC_MakeCylindricalSurface

Cylindrical `Surface` constructors wrapping `GC_MakeCylindricalSurface`.

### `Surface.gcCylindricalSurface(center:normal:radius:)`

Create a cylindrical surface from an axis placement and radius.

```swift
public static func gcCylindricalSurface(center: SIMD3<Double>, normal: SIMD3<Double>,
                                          radius: Double) -> Surface?
```

- **Parameters:** `center` — origin on the cylinder axis; `normal` — axis direction; `radius` — cylinder radius.
- **Returns:** A `Surface` wrapping `Geom_CylindricalSurface`, or `nil` on failure.
- **OCCT:** `GC_MakeCylindricalSurface`
- **Example:**
  ```swift
  if let cyl = Surface.gcCylindricalSurface(center: .zero, normal: SIMD3(0,0,1), radius: 5) {
      // infinite cylinder
  }
  ```

---

### `Surface.gcCylindricalSurface3Pts(p1:p2:p3:)`

Create a cylindrical surface through three points.

```swift
public static func gcCylindricalSurface3Pts(p1: SIMD3<Double>, p2: SIMD3<Double>,
                                              p3: SIMD3<Double>) -> Surface?
```

- **Parameters:** `p1`, `p2`, `p3` — three points on the cylinder.
- **Returns:** A `Surface` wrapping `Geom_CylindricalSurface`, or `nil` on failure.
- **OCCT:** `GC_MakeCylindricalSurface` (three-point constructor)
- **Example:**
  ```swift
  if let cyl = Surface.gcCylindricalSurface3Pts(p1: SIMD3(5,0,0),
                                                  p2: SIMD3(-5,0,0),
                                                  p3: SIMD3(0,5,3)) { /* ... */ }
  ```

---

### `Surface.gcCylindricalSurfaceFromCircle(center:normal:radius:)`

Create a cylindrical surface from a circle definition (center, normal, radius).

```swift
public static func gcCylindricalSurfaceFromCircle(center: SIMD3<Double>, normal: SIMD3<Double>,
                                                   radius: Double) -> Surface?
```

- **Parameters:** `center`, `normal`, `radius` — circle parameters that define the cylinder's directrix.
- **Returns:** A `Surface` wrapping `Geom_CylindricalSurface`, or `nil` on failure.
- **OCCT:** `GC_MakeCylindricalSurface` (circle constructor)
- **Example:**
  ```swift
  if let cyl = Surface.gcCylindricalSurfaceFromCircle(center: .zero,
                                                       normal: SIMD3(0,0,1), radius: 3) { /* ... */ }
  ```

---

### `Surface.gcCylindricalSurfaceParallel(center:normal:radius:distance:)`

Create a cylindrical surface concentric with an existing one, offset by a distance.

```swift
public static func gcCylindricalSurfaceParallel(center: SIMD3<Double>, normal: SIMD3<Double>,
                                                  radius: Double, distance: Double) -> Surface?
```

- **Parameters:** `center`, `normal`, `radius` — reference cylinder; `distance` — radial offset.
- **Returns:** A `Surface` wrapping `Geom_CylindricalSurface`, or `nil` on failure.
- **OCCT:** `GC_MakeCylindricalSurface` (parallel/offset constructor)
- **Example:**
  ```swift
  if let outer = Surface.gcCylindricalSurfaceParallel(center: .zero, normal: SIMD3(0,0,1),
                                                       radius: 5, distance: 2) {
      // outer cylinder at r=7
  }
  ```

---

### `Surface.gcCylindricalSurfaceAxis(point:direction:radius:)`

Create a cylindrical surface from an axis defined by a point and direction plus a radius.

```swift
public static func gcCylindricalSurfaceAxis(point: SIMD3<Double>, direction: SIMD3<Double>,
                                              radius: Double) -> Surface?
```

- **Parameters:** `point` — any point on the axis; `direction` — axis direction; `radius` — cylinder radius.
- **Returns:** A `Surface` wrapping `Geom_CylindricalSurface`, or `nil` on failure.
- **OCCT:** `GC_MakeCylindricalSurface` (axis constructor)
- **Example:**
  ```swift
  if let cyl = Surface.gcCylindricalSurfaceAxis(point: SIMD3(1,0,0),
                                                  direction: SIMD3(0,0,1), radius: 4) { /* ... */ }
  ```

---

## GC_MakeTrimmedCone

Trimmed conical `Surface` constructors wrapping `GC_MakeTrimmedCone`.

### `Surface.gcTrimmedCone2Pts(p1:p2:r1:r2:)`

Create a trimmed cone from two axial points and radii.

```swift
public static func gcTrimmedCone2Pts(p1: SIMD3<Double>, p2: SIMD3<Double>,
                                      r1: Double, r2: Double) -> Surface?
```

- **Parameters:** `p1`, `p2` — positions of the base circles; `r1`, `r2` — respective radii.
- **Returns:** A bounded `Surface` wrapping `Geom_ConicalSurface`, or `nil` on failure.
- **OCCT:** `GC_MakeTrimmedCone`
- **Example:**
  ```swift
  if let tc = Surface.gcTrimmedCone2Pts(p1: .zero, p2: SIMD3(0,0,10), r1: 2, r2: 5) { /* ... */ }
  ```

---

### `Surface.gcTrimmedCone4Pts(p1:p2:p3:p4:)`

Create a trimmed cone through four points.

```swift
public static func gcTrimmedCone4Pts(p1: SIMD3<Double>, p2: SIMD3<Double>,
                                      p3: SIMD3<Double>, p4: SIMD3<Double>) -> Surface?
```

- **Parameters:** `p1`, `p2` — two points on the first circle; `p3`, `p4` — two points on the second circle.
- **Returns:** A bounded `Surface` wrapping `Geom_ConicalSurface`, or `nil` on failure.
- **OCCT:** `GC_MakeTrimmedCone` (four-point constructor)
- **Example:**
  ```swift
  if let tc = Surface.gcTrimmedCone4Pts(p1: SIMD3(2,0,0), p2: SIMD3(-2,0,0),
                                          p3: SIMD3(5,0,8), p4: SIMD3(-5,0,8)) { /* ... */ }
  ```

---

## GC_MakeTrimmedCylinder

Trimmed cylindrical `Surface` constructors wrapping `GC_MakeTrimmedCylinder`.

### `Surface.gcTrimmedCylinderCircle(center:normal:radius:height:)`

Create a trimmed cylinder from a circle definition and height.

```swift
public static func gcTrimmedCylinderCircle(center: SIMD3<Double>, normal: SIMD3<Double>,
                                            radius: Double, height: Double) -> Surface?
```

- **Parameters:** `center`, `normal`, `radius` — directrix circle; `height` — axial extent.
- **Returns:** A bounded `Surface` wrapping `Geom_CylindricalSurface`, or `nil` on failure.
- **OCCT:** `GC_MakeTrimmedCylinder`
- **Example:**
  ```swift
  if let tc = Surface.gcTrimmedCylinderCircle(center: .zero, normal: SIMD3(0,0,1),
                                               radius: 5, height: 10) { /* ... */ }
  ```

---

### `Surface.gcTrimmedCylinderAxis(point:direction:radius:height:)`

Create a trimmed cylinder from an axis, radius, and height.

```swift
public static func gcTrimmedCylinderAxis(point: SIMD3<Double>, direction: SIMD3<Double>,
                                          radius: Double, height: Double) -> Surface?
```

- **Parameters:** `point` — origin on the axis; `direction` — axis direction; `radius` — cylinder radius; `height` — axial extent.
- **Returns:** A bounded `Surface` wrapping `Geom_CylindricalSurface`, or `nil` on failure.
- **OCCT:** `GC_MakeTrimmedCylinder` (axis constructor)
- **Example:**
  ```swift
  if let tc = Surface.gcTrimmedCylinderAxis(point: .zero, direction: SIMD3(0,0,1),
                                              radius: 3, height: 8) { /* ... */ }
  ```

---

### `Surface.gcTrimmedCylinder3Pts(p1:p2:p3:)`

Create a trimmed cylinder through three points.

```swift
public static func gcTrimmedCylinder3Pts(p1: SIMD3<Double>, p2: SIMD3<Double>,
                                          p3: SIMD3<Double>) -> Surface?
```

- **Parameters:** `p1`, `p2`, `p3` — three points on the cylinder surface.
- **Returns:** A bounded `Surface` wrapping `Geom_CylindricalSurface`, or `nil` on failure.
- **OCCT:** `GC_MakeTrimmedCylinder` (three-point constructor)
- **Example:**
  ```swift
  if let tc = Surface.gcTrimmedCylinder3Pts(p1: SIMD3(5,0,0),
                                              p2: SIMD3(-5,0,0),
                                              p3: SIMD3(0,5,4)) { /* ... */ }
  ```

---

## BRepLib_MakeEdge2d extensions

2D edge construction from analytic curves, extending `Shape`.

### `Shape.edge2dFullCircle(center:direction:radius:)`

Create a 2D edge from a full circle.

```swift
public static func edge2dFullCircle(center: SIMD2<Double>, direction: SIMD2<Double>,
                                     radius: Double) -> Shape?
```

- **Parameters:** `center` — circle center in 2D; `direction` — X-axis direction; `radius` — radius.
- **Returns:** A `Shape` wrapping a closed `TopoDS_Edge` in 2D, or `nil` on failure.
- **OCCT:** `BRepLib_MakeEdge2d` (circle overload)
- **Example:**
  ```swift
  if let e = Shape.edge2dFullCircle(center: .zero, direction: SIMD2(1,0), radius: 3) { /* ... */ }
  ```

---

### `Shape.edge2dEllipse(center:direction:majorRadius:minorRadius:)`

Create a 2D edge from a full ellipse.

```swift
public static func edge2dEllipse(center: SIMD2<Double>, direction: SIMD2<Double>,
                                  majorRadius: Double, minorRadius: Double) -> Shape?
```

- **Parameters:** `center` — center in 2D; `direction` — major-axis direction; `majorRadius`, `minorRadius` — semi-axes.
- **Returns:** A closed 2D edge, or `nil` on failure.
- **OCCT:** `BRepLib_MakeEdge2d` (ellipse overload)
- **Example:**
  ```swift
  if let e = Shape.edge2dEllipse(center: .zero, direction: SIMD2(1,0),
                                  majorRadius: 4, minorRadius: 2) { /* ... */ }
  ```

---

### `Shape.edge2dEllipseArc(center:direction:majorRadius:minorRadius:u1:u2:)`

Create a 2D edge from an ellipse arc.

```swift
public static func edge2dEllipseArc(center: SIMD2<Double>, direction: SIMD2<Double>,
                                     majorRadius: Double, minorRadius: Double,
                                     u1: Double, u2: Double) -> Shape?
```

- **Parameters:** `center`, `direction`, `majorRadius`, `minorRadius` — ellipse definition; `u1`, `u2` — parameter range (radians).
- **Returns:** A 2D edge arc, or `nil` on failure.
- **OCCT:** `BRepLib_MakeEdge2d` (ellipse-arc overload)
- **Example:**
  ```swift
  if let e = Shape.edge2dEllipseArc(center: .zero, direction: SIMD2(1,0),
                                     majorRadius: 4, minorRadius: 2,
                                     u1: 0, u2: .pi/2) { /* ... */ }
  ```

---

### `Shape.edge2dFromCurve(_:)`

Create a 2D edge spanning the full domain of a `Curve2D`.

```swift
public static func edge2dFromCurve(_ curve: Curve2D) -> Shape?
```

- **Parameters:** `curve` — a bounded `Curve2D`.
- **Returns:** A `Shape` wrapping a 2D `TopoDS_Edge`, or `nil` on failure.
- **OCCT:** `BRepLib_MakeEdge2d` (curve overload)
- **Example:**
  ```swift
  if let e = Shape.edge2dFromCurve(myParabola) { /* ... */ }
  ```

---

### `Shape.edge2dFromCurve(_:u1:u2:)`

Create a 2D edge from a `Curve2D` with an explicit parameter range.

```swift
public static func edge2dFromCurve(_ curve: Curve2D, u1: Double, u2: Double) -> Shape?
```

- **Parameters:** `curve` — a `Curve2D`; `u1`, `u2` — parameter range to trim to.
- **Returns:** A 2D edge, or `nil` on failure.
- **OCCT:** `BRepLib_MakeEdge2d` (curve + range overload)
- **Example:**
  ```swift
  if let e = Shape.edge2dFromCurve(mySpline, u1: 0.2, u2: 0.8) { /* ... */ }
  ```

---

## ShapeAnalysis_Wire

Wire quality checks using `ShapeAnalysis_Wire`. All members are static on the `SAWireAnalysis` enum. Each check returns `true` when a problem is detected.

### `SAWireAnalysis.checkOrder(wire:face:precision:)`

Check whether wire edges are correctly ordered on a face.

```swift
public static func checkOrder(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool
```

- **Parameters:** `wire` — the wire to analyse; `face` — the supporting face; `precision` — tolerance.
- **Returns:** `true` if the edge order is incorrect.
- **OCCT:** `ShapeAnalysis_Wire::CheckOrder`
- **Example:**
  ```swift
  if SAWireAnalysis.checkOrder(wire: w, face: f) { print("order problem") }
  ```

---

### `SAWireAnalysis.checkConnected(wire:face:precision:)`

Check whether wire edges are topologically connected.

```swift
public static func checkConnected(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckConnected`

---

### `SAWireAnalysis.checkSmall(wire:face:precision:)`

Check for edges shorter than `precision` (small/degenerate geometry).

```swift
public static func checkSmall(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckSmall`

---

### `SAWireAnalysis.checkDegenerated(wire:face:precision:)`

Check for degenerate edges in the wire.

```swift
public static func checkDegenerated(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckDegenerated`

---

### `SAWireAnalysis.checkClosed(wire:face:precision:)`

Check whether the wire is properly closed.

```swift
public static func checkClosed(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckClosed`

---

### `SAWireAnalysis.checkSelfIntersection(wire:face:precision:)`

Check for self-intersecting edges or edge pairs.

```swift
public static func checkSelfIntersection(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckSelfIntersection`

---

### `SAWireAnalysis.checkGaps3d(wire:face:precision:)`

Check for gaps between consecutive edge endpoints in 3D.

```swift
public static func checkGaps3d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckGaps3d`

---

### `SAWireAnalysis.checkGaps2d(wire:face:precision:)`

Check for gaps between consecutive edge endpoints in 2D (parametric space).

```swift
public static func checkGaps2d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckGaps2d`

---

### `SAWireAnalysis.checkEdgeCurves(wire:face:precision:)`

Check consistency between 3D curves and parametric curves for all edges.

```swift
public static func checkEdgeCurves(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckEdgeCurves`

---

### `SAWireAnalysis.checkLacking(wire:face:precision:)`

Check for missing (lacking) edges that would be needed to close the wire.

```swift
public static func checkLacking(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckLacking`

---

### `SAWireAnalysis.edgeCount(wire:face:precision:)`

Number of edges in the wire as seen by `ShapeAnalysis_Wire`.

```swift
public static func edgeCount(wire: Shape, face: Shape, precision: Double = 1e-6) -> Int
```

- **Returns:** Edge count.
- **OCCT:** `ShapeAnalysis_Wire::NbEdges`
- **Example:**
  ```swift
  let n = SAWireAnalysis.edgeCount(wire: w, face: f)
  ```

---

### `SAWireAnalysis.minDistance3d(wire:face:precision:)`

Minimum 3D gap distance between consecutive edges.

```swift
public static func minDistance3d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Double
```

- **OCCT:** `ShapeAnalysis_Wire::MinDistance3d`

---

### `SAWireAnalysis.maxDistance3d(wire:face:precision:)`

Maximum 3D gap distance between consecutive edges.

```swift
public static func maxDistance3d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Double
```

- **OCCT:** `ShapeAnalysis_Wire::MaxDistance3d`

---

### `SAWireAnalysis.minDistance2d(wire:face:precision:)`

Minimum 2D gap distance between consecutive edges in parametric space.

```swift
public static func minDistance2d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Double
```

- **OCCT:** `ShapeAnalysis_Wire::MinDistance2d`

---

### `SAWireAnalysis.maxDistance2d(wire:face:precision:)`

Maximum 2D gap distance between consecutive edges in parametric space.

```swift
public static func maxDistance2d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Double
```

- **OCCT:** `ShapeAnalysis_Wire::MaxDistance2d`

---

### `SAWireAnalysis.checkConnectedEdge(wire:face:precision:edgeIndex:)`

Check connectivity of a specific edge (1-based index).

```swift
public static func checkConnectedEdge(wire: Shape, face: Shape, precision: Double = 1e-6,
                                       edgeIndex: Int) -> Bool
```

- **Parameters:** `edgeIndex` — 1-based edge index.
- **Returns:** `true` if that edge has a connectivity problem.
- **OCCT:** `ShapeAnalysis_Wire::CheckConnected` (per-edge)

---

### `SAWireAnalysis.checkSmallEdge(wire:face:precision:edgeIndex:)`

Check whether a specific edge (1-based) is too small.

```swift
public static func checkSmallEdge(wire: Shape, face: Shape, precision: Double = 1e-6,
                                   edgeIndex: Int) -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckSmall` (per-edge)

---

### `SAWireAnalysis.checkDegeneratedEdge(wire:face:precision:edgeIndex:)`

Check whether a specific edge (1-based) is degenerate.

```swift
public static func checkDegeneratedEdge(wire: Shape, face: Shape, precision: Double = 1e-6,
                                          edgeIndex: Int) -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckDegenerated` (per-edge)

---

### `SAWireAnalysis.checkGap3dEdge(wire:face:precision:edgeIndex:)`

Check for a 3D gap at a specific edge (1-based).

```swift
public static func checkGap3dEdge(wire: Shape, face: Shape, precision: Double = 1e-6,
                                   edgeIndex: Int) -> Bool
```

- **OCCT:** `ShapeAnalysis_Wire::CheckGaps3d` (per-edge)

---

### `SAWireAnalysis.checkOuterBound(face:precision:)`

Check whether the face has a correctly oriented outer-bound wire.

```swift
public static func checkOuterBound(face: Shape, precision: Double = 1e-6) -> Bool
```

- **Parameters:** `face` — the face to check (wire argument is the face's outer wire).
- **Returns:** `true` if the outer-bound check fails.
- **OCCT:** `ShapeAnalysis_Wire::CheckOuterBound`
- **Example:**
  ```swift
  if SAWireAnalysis.checkOuterBound(face: myFace) { print("outer bound problem") }
  ```

---

## ShapeAnalysis_Edge

Per-edge analysis utilities using `ShapeAnalysis_Edge`. All members are static on the `EdgeAnalysis` enum.

### `EdgeAnalysis.hasCurve3d(_:)`

Check whether an edge has a 3D curve representation.

```swift
public static func hasCurve3d(_ edge: Shape) -> Bool
```

- **OCCT:** `ShapeAnalysis_Edge::HasCurve3d`
- **Example:**
  ```swift
  if EdgeAnalysis.hasCurve3d(e) { /* ... */ }
  ```

---

### `EdgeAnalysis.isClosed3d(_:)`

Check whether the edge's 3D curve is closed.

```swift
public static func isClosed3d(_ edge: Shape) -> Bool
```

- **OCCT:** `ShapeAnalysis_Edge::IsClosed3d`

---

### `EdgeAnalysis.hasPCurve(_:face:)`

Check whether an edge has a parametric curve (PCurve) on a given face.

```swift
public static func hasPCurve(_ edge: Shape, face: Shape) -> Bool
```

- **Parameters:** `edge` — the edge; `face` — the supporting face.
- **OCCT:** `ShapeAnalysis_Edge::HasPCurve`

---

### `EdgeAnalysis.isSeam(_:face:)`

Check whether an edge is a seam edge on the given face.

```swift
public static func isSeam(_ edge: Shape, face: Shape) -> Bool
```

- **OCCT:** `ShapeAnalysis_Edge::IsSeam`

---

### `EdgeAnalysis.checkSameParameter(_:)`

Verify the same-parameter property and report maximum deviation.

```swift
public static func checkSameParameter(_ edge: Shape) -> (ok: Bool, maxDeviation: Double)
```

- **Returns:** `ok` is `true` when the edge is within tolerance; `maxDeviation` is the worst observed deviation.
- **OCCT:** `ShapeAnalysis_Edge::CheckSameParameter`
- **Example:**
  ```swift
  let (ok, dev) = EdgeAnalysis.checkSameParameter(e)
  ```

---

### `EdgeAnalysis.checkVerticesWithCurve3d(_:precision:)`

Verify that vertex positions match the curve 3D endpoints.

```swift
public static func checkVerticesWithCurve3d(_ edge: Shape, precision: Double = 1e-6) -> Bool
```

- **Returns:** `true` if check passes.
- **OCCT:** `ShapeAnalysis_Edge::CheckVerticesWithCurve3d`

---

### `EdgeAnalysis.checkVerticesWithPCurve(_:face:precision:)`

Verify that vertex positions match the PCurve endpoints on a face.

```swift
public static func checkVerticesWithPCurve(_ edge: Shape, face: Shape,
                                            precision: Double = 1e-6) -> Bool
```

- **OCCT:** `ShapeAnalysis_Edge::CheckVerticesWithPCurve`

---

### `EdgeAnalysis.checkCurve3dWithPCurve(_:face:)`

Verify consistency between the 3D curve and the PCurve on a face.

```swift
public static func checkCurve3dWithPCurve(_ edge: Shape, face: Shape) -> Bool
```

- **OCCT:** `ShapeAnalysis_Edge::CheckCurve3dWithPCurve`

---

### `EdgeAnalysis.firstVertex(_:)`

3D position of the edge's first vertex.

```swift
public static func firstVertex(_ edge: Shape) -> SIMD3<Double>
```

- **OCCT:** `ShapeAnalysis_Edge::FirstVertex` + `BRep_Tool::Pnt`
- **Example:**
  ```swift
  let start = EdgeAnalysis.firstVertex(myEdge)
  ```

---

### `EdgeAnalysis.lastVertex(_:)`

3D position of the edge's last vertex.

```swift
public static func lastVertex(_ edge: Shape) -> SIMD3<Double>
```

- **OCCT:** `ShapeAnalysis_Edge::LastVertex` + `BRep_Tool::Pnt`
- **Example:**
  ```swift
  let end = EdgeAnalysis.lastVertex(myEdge)
  ```

---

### `EdgeAnalysis.checkVertexTolerance(_:face:)`

Verify vertex tolerances on a face edge and return tolerance values.

```swift
public static func checkVertexTolerance(_ edge: Shape, face: Shape) -> (ok: Bool, toler1: Double, toler2: Double)
```

- **Returns:** `ok` when within tolerance; `toler1`, `toler2` — first and last vertex tolerance values.
- **OCCT:** `ShapeAnalysis_Edge::CheckVertexTolerance`
- **Example:**
  ```swift
  let (ok, t1, t2) = EdgeAnalysis.checkVertexTolerance(e, face: f)
  ```

---

### `EdgeAnalysis.checkOverlapping(_:_:)`

Detect whether two edges overlap and report the overlap tolerance.

```swift
public static func checkOverlapping(_ edge1: Shape, _ edge2: Shape) -> (overlapping: Bool, tolerance: Double)
```

- **Returns:** `overlapping` is `true` when the edges share geometry; `tolerance` is the detected overlap distance.
- **OCCT:** `ShapeAnalysis_Edge::CheckOverlapping`
- **Example:**
  ```swift
  let (over, tol) = EdgeAnalysis.checkOverlapping(e1, e2)
  ```

---

### `EdgeAnalysis.boundUV(_:face:)`

UV bounds of an edge on a face in parametric space.

```swift
public static func boundUV(_ edge: Shape, face: Shape) -> (uFirst: Double, vFirst: Double, uLast: Double, vLast: Double)?
```

- **Returns:** Tuple of `(uFirst, vFirst, uLast, vLast)`, or `nil` if the edge has no PCurve on the face.
- **OCCT:** `ShapeAnalysis_Edge::GetEndTangent2d` / `BRep_Tool::CurveOnSurface`
- **Example:**
  ```swift
  if let uv = EdgeAnalysis.boundUV(e, face: f) {
      print("u range:", uv.uFirst, "...", uv.uLast)
  }
  ```

---

### `EdgeAnalysis.endTangent2d(_:face:atEnd:)`

2D endpoint and tangent direction of an edge in the face's parametric space.

```swift
public static func endTangent2d(_ edge: Shape, face: Shape,
                                 atEnd: Bool) -> (point: SIMD2<Double>, tangent: SIMD2<Double>)?
```

- **Parameters:** `atEnd` — `false` for the start, `true` for the end.
- **Returns:** Tuple of 2D position and tangent, or `nil` if unavailable.
- **OCCT:** `ShapeAnalysis_Edge::GetEndTangent2d`
- **Example:**
  ```swift
  if let (pt, tan) = EdgeAnalysis.endTangent2d(e, face: f, atEnd: false) {
      // pt is the 2D start position
  }
  ```

---

### `EdgeAnalysis.checkPCurveRange(_:face:first:last:)`

Verify that a PCurve parameter range is valid on the face.

```swift
public static func checkPCurveRange(_ edge: Shape, face: Shape,
                                     first: Double, last: Double) -> Bool
```

- **Parameters:** `first`, `last` — the parameter range to check against the face's natural bounds.
- **Returns:** `true` if the range is valid.
- **OCCT:** `ShapeAnalysis_Edge::CheckPCurveRange`
- **Example:**
  ```swift
  let ok = EdgeAnalysis.checkPCurveRange(e, face: f, first: 0, last: 1)
  ```

---

## OSD_DirectoryIterator

Directory listing using `OSD_DirectoryIterator`. All members are static on the `DirectoryIterator` enum.

### `DirectoryIterator.count(path:mask:)`

Count the directories matching `mask` inside `path`.

```swift
public static func count(path: String, mask: String = "*") -> Int
```

- **Parameters:** `path` — directory to search; `mask` — glob-style name filter.
- **Returns:** Number of matching sub-directories.
- **OCCT:** `OSD_DirectoryIterator`
- **Example:**
  ```swift
  let n = DirectoryIterator.count(path: "/tmp", mask: "occt*")
  ```

---

### `DirectoryIterator.name(path:mask:index:)`

Name of the directory at a specific index in the filtered listing.

```swift
public static func name(path: String, mask: String = "*", index: Int) -> String?
```

- **Parameters:** `path`, `mask` — as for `count`; `index` — 0-based index.
- **Returns:** Directory name, or `nil` if the index is out of range.
- **OCCT:** `OSD_DirectoryIterator::Values`
- **Example:**
  ```swift
  if let first = DirectoryIterator.name(path: "/tmp", index: 0) {
      print(first)
  }
  ```

---

### `DirectoryIterator.list(path:mask:maxCount:)`

List all directory names matching a mask (up to `maxCount`).

```swift
public static func list(path: String, mask: String = "*", maxCount: Int = 1000) -> [String]
```

- **Parameters:** `path`, `mask` — search location and filter; `maxCount` — result cap.
- **Returns:** Array of directory name strings.
- **OCCT:** `OSD_DirectoryIterator`
- **Example:**
  ```swift
  let dirs = DirectoryIterator.list(path: "/tmp")
  ```

---

## OSD_FileIterator

File listing using `OSD_FileIterator`. All members are static on the `FileIterator` enum.

### `FileIterator.count(path:mask:)`

Count files matching `mask` inside `path`.

```swift
public static func count(path: String, mask: String = "*") -> Int
```

- **Parameters:** `path` — directory to search; `mask` — glob-style name filter.
- **Returns:** Number of matching files.
- **OCCT:** `OSD_FileIterator`
- **Example:**
  ```swift
  let n = FileIterator.count(path: "/tmp", mask: "*.step")
  ```

---

### `FileIterator.name(path:mask:index:)`

Name of the file at a specific index in the filtered listing.

```swift
public static func name(path: String, mask: String = "*", index: Int) -> String?
```

- **Parameters:** `path`, `mask` — location and filter; `index` — 0-based index.
- **Returns:** File name, or `nil` if out of range.
- **OCCT:** `OSD_FileIterator::Values`
- **Example:**
  ```swift
  if let f = FileIterator.name(path: "/tmp", mask: "*.step", index: 0) {
      print(f)
  }
  ```

---

### `FileIterator.list(path:mask:maxCount:)`

List all file names matching a mask (up to `maxCount`).

```swift
public static func list(path: String, mask: String = "*", maxCount: Int = 1000) -> [String]
```

- **Parameters:** `path`, `mask` — search location and filter; `maxCount` — result cap.
- **Returns:** Array of file name strings.
- **OCCT:** `OSD_FileIterator`
- **Example:**
  ```swift
  let files = FileIterator.list(path: "/tmp", mask: "*.brep")
  ```

---

## BRepFill_PipeShell extensions

Additional approximation controls and cap accessors added to `PipeShellBuilder` (v0.106.0 extensions).

### `PipeShellBuilder.setMaxDegree(_:)`

Set the maximum polynomial degree for the BSpline approximation of the swept surface.

```swift
public func setMaxDegree(_ maxDeg: Int)
```

- **Parameters:** `maxDeg` — maximum BSpline degree (OCCT default is 11).
- **OCCT:** `BRepFill_PipeShell::SetMaxDegree`
- **Example:**
  ```swift
  pipe.setMaxDegree(7)
  ```

---

### `PipeShellBuilder.setMaxSegments(_:)`

Set the maximum number of BSpline segments in the swept surface approximation.

```swift
public func setMaxSegments(_ maxSeg: Int)
```

- **Parameters:** `maxSeg` — maximum segment count.
- **OCCT:** `BRepFill_PipeShell::SetMaxSegments`
- **Example:**
  ```swift
  pipe.setMaxSegments(100)
  ```

---

### `PipeShellBuilder.setForceApproxC1(_:)`

Force C1 continuity in the BSpline approximation.

```swift
public func setForceApproxC1(_ force: Bool)
```

- **Parameters:** `force` — `true` to enforce C1 even at the cost of additional segments.
- **OCCT:** `BRepFill_PipeShell::SetForceApproxC1`
- **Example:**
  ```swift
  pipe.setForceApproxC1(true)
  ```

---

### `PipeShellBuilder.setBuildHistory(_:)`

Enable or disable shape history tracking during the sweep.

```swift
public func setBuildHistory(_ enabled: Bool)
```

History is **disabled by default** to avoid a segfault in `BRepFill_PipeShell::BuildHistory` when using closed spine+profile combinations (OCCT bug). Enable only when `generated`/`modified`/`isDeleted` queries on the result are required.

- **Parameters:** `enabled` — `true` to enable history.
- **OCCT:** `BRepFill_PipeShell::SetBuildHistory`
- **Note:** Enabling history on closed spine/profile geometries can trigger an OCCT segfault — use with caution.
- **Example:**
  ```swift
  pipe.setBuildHistory(false) // safe default
  ```

---

### `PipeShellBuilder.errorOnSurface`

Approximation error of the generated surface (distinct from `error` which covers the overall result).

```swift
public var errorOnSurface: Double { get }
```

- **OCCT:** `BRepFill_PipeShell::ErrorOnSurface`
- **Example:**
  ```swift
  print("surface error:", pipe.errorOnSurface)
  ```

---

### `PipeShellBuilder.firstShape`

The start-cap shape of the pipe shell (the face at the beginning of the spine).

```swift
public var firstShape: Shape? { get }
```

- **Returns:** The first section `Shape`, or `nil` if `build()` has not succeeded.
- **OCCT:** `BRepFill_PipeShell::FirstShape`
- **Example:**
  ```swift
  if let cap = pipe.firstShape { /* use start cap */ }
  ```

---

### `PipeShellBuilder.lastShape`

The end-cap shape of the pipe shell (the face at the end of the spine).

```swift
public var lastShape: Shape? { get }
```

- **Returns:** The last section `Shape`, or `nil` if `build()` has not succeeded.
- **OCCT:** `BRepFill_PipeShell::LastShape`
- **Example:**
  ```swift
  if let cap = pipe.lastShape { /* use end cap */ }
  ```
