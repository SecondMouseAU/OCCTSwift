---
title: Shape — Advanced Sweeps & API Completions
parent: API Reference
---

# Shape — Advanced Sweeps & API Completions

This page documents the advanced sweep, fill, proximity, and B-Rep query members of `Shape`
from the v0.79.0–v0.128.0 range. For the primary `Shape` type overview, constructors, and
boolean/transform/topology operations see the main **Shape** page (forthcoming as `Shape.md`).

## Topics

- [CoherentTriangulation](#coherenttriangulation) · [BRepFill_Evolved](#brepfill_evolved) · [BRepFill_OffsetAncestors](#brepfill_offsetancestors) · [BRepExtrema_DistanceSS](#brepextrema_distancess) · [BRepGProp_VinertGK](#brepgprop_vinertgk) · [GeomFill_Profiler](#geomfill_profiler) · [GeomFill_Stretch](#geomfill_stretch) · [GeomFill_LocationDraft](#geomfill_locationdraft) · [GeomFill_GuideTrihedronAC](#geomfill_guidetrihedronac) · [GeomFill_GuideTrihedronPlan](#geomfill_guidetrihedronplan) · [GeomFill_SectionPlacement](#geomfill_sectionplacement) · [BRepFill_NSections](#brepfill_nsections) · [GeomFill_AppSurf](#geomfill_appsurf) · [ShapeFix_ComposeShell](#shapefix_composeshell) · [Transform, Boolean & Shape Query expansions (v0.115.0)](#transform-boolean--shape-query-expansions-v01150) · [ThruSections builder](#thrusections-builder-v01150) · [ShapeFixer builder](#shapefixer-builder-v01150) · [BRep_Tool completions v0.126.0](#brep_tool-completions-v01260) · [Section with plane/surface & polygon queries v0.127.0](#section-with-planesurface--brep_tool-polygon-queries-v01270) · [BRep_Tool completions v0.128.0](#brep_tool-completions-v01280)

---

## CoherentTriangulation

Mutable coherent triangulation for mesh editing operations, wrapping `Poly_CoherentTriangulation`.

### `CoherentTriangulation.create()`

Creates an empty coherent triangulation.

```swift
public static func create() -> CoherentTriangulation
```

- **Returns:** A new empty `CoherentTriangulation`.
- **OCCT:** `Poly_CoherentTriangulation` (default constructor).
- **Example:**
  ```swift
  let ct = CoherentTriangulation.create()
  ```

---

### `CoherentTriangulation.createFromMesh(_:deflection:)`

Creates a coherent triangulation from the triangulation of the first face of a meshed shape.

```swift
public static func createFromMesh(_ shape: Shape, deflection: Double = 0.1) -> CoherentTriangulation?
```

- **Parameters:** `shape` — a `Shape` that has already been meshed. `deflection` — linear deflection used for auto-triangulation if the shape is not yet meshed; default `0.1`.
- **Returns:** A `CoherentTriangulation` populated from the face's triangulation, or `nil` if the shape has no triangulation.
- **OCCT:** `Poly_CoherentTriangulation`, `BRep_Tool::Triangulation`.
- **Example:**
  ```swift
  let box = Shape.box(dx: 10, dy: 10, dz: 10)!
  if let ct = CoherentTriangulation.createFromMesh(box) {
      print(ct.triangleCount)
  }
  ```

---

### `setNode(x:y:z:)`

Adds a node at the given coordinates.

```swift
public func setNode(x: Double, y: Double, z: Double) -> Int
```

- **Returns:** The 0-based index of the newly created node.
- **OCCT:** `Poly_CoherentTriangulation::SetNode`.
- **Example:**
  ```swift
  let ct = CoherentTriangulation.create()
  let i0 = ct.setNode(x: 0, y: 0, z: 0)
  ```

---

### `addTriangle(_:_:_:)`

Adds a triangle from three 0-based node indices.

```swift
@discardableResult
public func addTriangle(_ n0: Int, _ n1: Int, _ n2: Int) -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `Poly_CoherentTriangulation::AddTriangle`.
- **Example:**
  ```swift
  let ok = ct.addTriangle(0, 1, 2)
  ```

---

### `removeTriangle(at:)`

Removes a triangle by its 0-based index.

```swift
@discardableResult
public func removeTriangle(at index: Int) -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `Poly_CoherentTriangulation::RemoveTriangle`.

---

### `triangleCount`

Number of triangles in the coherent triangulation.

```swift
public var triangleCount: Int { get }
```

- **OCCT:** `Poly_CoherentTriangulation::NTriangles`.

---

### `computeLinks()`

Computes edge links between adjacent triangles.

```swift
public func computeLinks() -> Int
```

- **Returns:** The number of links computed.
- **OCCT:** `Poly_CoherentTriangulation::ComputeLinks`.

---

### `linkCount`

Number of edge links. Call `computeLinks()` first.

```swift
public var linkCount: Int { get }
```

- **OCCT:** `Poly_CoherentTriangulation::NLinks`.

---

### `setDeflection(_:)`

Sets the deflection value on the triangulation.

```swift
public func setDeflection(_ value: Double)
```

- **OCCT:** `Poly_CoherentTriangulation::SetDeflection`.

---

### `deflection`

The current deflection value of the triangulation.

```swift
public var deflection: Double { get }
```

- **OCCT:** `Poly_CoherentTriangulation::Deflection`.

---

### `removeDegenerated(tolerance:)`

Removes degenerated triangles whose area is below the given tolerance.

```swift
@discardableResult
public func removeDegenerated(tolerance: Double) -> Bool
```

- **Returns:** `true` if any degenerated triangles were removed.
- **OCCT:** `Poly_CoherentTriangulation::RemoveDegenerated`.

---

### `getResult()`

Converts the coherent triangulation back to standard node/triangle counts.

```swift
public func getResult() -> (nodeCount: Int, triangleCount: Int)?
```

- **Returns:** A tuple of `(nodeCount, triangleCount)`, or `nil` on failure.
- **OCCT:** `Poly_CoherentTriangulation`.

---

### `nodeCoords(at:)`

Gets the coordinates of a node by its 1-based index (after calling `getResult()`).

```swift
public func nodeCoords(at index: Int) -> (x: Double, y: Double, z: Double)?
```

- **Returns:** The `(x, y, z)` coordinates of the node, or `nil` if the index is out of range.
- **OCCT:** `Poly_CoherentTriangulation`.

---

## BRepFill_Evolved

### `Shape.evolved(spineFace:profileWire:axisOrigin:axisNormal:axisXDir:joinType:makeSolid:)`

Creates an evolved shape by sweeping a 2D wire profile along the boundary of a planar face.

```swift
public static func evolved(spineFace: Shape, profileWire: Shape,
                            axisOrigin: SIMD3<Double> = SIMD3(0, 0, 0),
                            axisNormal: SIMD3<Double> = SIMD3(0, 0, 1),
                            axisXDir: SIMD3<Double> = SIMD3(1, 0, 0),
                            joinType: Int = 0, makeSolid: Bool = false) -> Shape?
```

- **Parameters:**
  - `spineFace` — planar face whose boundary edges define the sweep path.
  - `profileWire` — 2D wire cross-section to sweep.
  - `axisOrigin`, `axisNormal`, `axisXDir` — coordinate system of the profile plane; defaults to the XY plane at the origin.
  - `joinType` — join strategy between adjacent sweep segments: `0`=Arc (round), `1`=Tangent, `2`=Intersection.
  - `makeSolid` — `true` to cap the result into a solid.
- **Returns:** The evolved `Shape`, or `nil` if the operation fails.
- **OCCT:** `BRepFill_Evolved`.
- **Example:**
  ```swift
  let face = Shape.box(dx: 20, dy: 10, dz: 1)!
  let profile = Wire.rectangle(width: 2, height: 2)!.asShape
  if let evo = Shape.evolved(spineFace: face, profileWire: profile) {
      print(evo.isValid)
  }
  ```

---

## BRepFill_OffsetAncestors

Traces the ancestry of edges in an offset wire back to the original face edges. Wraps `BRepFill_OffsetAncestors`.

### `OffsetAncestors.create(face:offset:joinType:)`

Creates an offset-ancestors tracker for a face offset by the given distance.

```swift
public static func create(face: Shape, offset: Double, joinType: Int = 0) -> OffsetAncestors?
```

- **Parameters:**
  - `face` — the source face.
  - `offset` — signed offset distance.
  - `joinType` — `0`=Arc, `1`=Tangent, `2`=Intersection.
- **Returns:** An `OffsetAncestors` instance, or `nil` if the operation fails.
- **OCCT:** `BRepFill_OffsetAncestors`.

---

### `isDone`

Whether the offset and ancestry computation succeeded.

```swift
public var isDone: Bool { get }
```

- **OCCT:** `BRepFill_OffsetAncestors::IsDone`.

---

### `hasAncestor(_:)`

Checks if an offset edge has a recorded ancestor.

```swift
public func hasAncestor(_ edge: Shape) -> Bool
```

- **OCCT:** `BRepFill_OffsetAncestors::HasAncestor`.

---

### `ancestor(of:)`

Returns the original edge that gave rise to the given offset edge.

```swift
public func ancestor(of edge: Shape) -> Shape?
```

- **Returns:** The ancestor `Shape`, or `nil` if the edge has no recorded ancestor.
- **OCCT:** `BRepFill_OffsetAncestors::Ancestor`.
- **Example:**
  ```swift
  if let oa = OffsetAncestors.create(face: myFace, offset: 2.0), oa.isDone {
      for edge in offsetWireEdges {
          if let orig = oa.ancestor(of: edge) { print("traced") }
      }
  }
  ```

---

## BRepExtrema_DistanceSS

### `distanceSS(to:deflection:)`

Computes the minimum distance between two sub-shapes using Gauss-point sampling.

```swift
public func distanceSS(to other: Shape, deflection: Double = 100.0) -> DistanceSSResult
```

- **Parameters:**
  - `other` — the second shape.
  - `deflection` — sampling deflection; smaller values give finer sampling at a performance cost; default `100.0`.
- **Returns:** A `DistanceSSResult` containing `.distance`, `.point1`, `.point2`, `.solutionCount`, and `.isDone`.
- **OCCT:** `BRepExtrema_DistanceSS`.
- **Example:**
  ```swift
  let a = Shape.box(dx: 5, dy: 5, dz: 5)!
  let b = Shape.box(dx: 5, dy: 5, dz: 5)!.translated(x: 10, y: 0, z: 0)!
  let r = a.distanceSS(to: b)
  if r.isDone { print(r.distance) }
  ```

---

### `DistanceSSResult`

Result struct returned by `distanceSS(to:deflection:)`.

```swift
public struct DistanceSSResult {
    public let distance: Double
    public let point1: SIMD3<Double>
    public let point2: SIMD3<Double>
    public let solutionCount: Int
    public let isDone: Bool
}
```

---

## BRepGProp_VinertGK

### `vinertGK(location:tolerance:computeCG:)`

Computes volume inertia properties of a face using Gauss-Kronrod numerical integration.

```swift
public func vinertGK(location: SIMD3<Double> = SIMD3(0, 0, 0),
                     tolerance: Double = 0.001, computeCG: Bool = true) -> VinertGKResult
```

- **Parameters:**
  - `location` — the reference point for inertia computation; defaults to the origin.
  - `tolerance` — relative integration error bound; default `0.001`.
  - `computeCG` — whether to compute the centre of gravity; default `true`.
- **Returns:** A `VinertGKResult` with `.mass`, `.errorReached`, `.absoluteError`, and `.center`.
- **OCCT:** `BRepGProp_VinertGK`.
- **Note:** This method operates on a face shape. The `.mass` field is the signed volume contribution.
- **Example:**
  ```swift
  let face = Shape.box(dx: 10, dy: 10, dz: 10)!.faces.first!
  let gi = face.vinertGK()
  print(gi.mass, gi.center)
  ```

---

### `VinertGKResult`

Result struct returned by `vinertGK(location:tolerance:computeCG:)`.

```swift
public struct VinertGKResult {
    public let mass: Double
    public let errorReached: Double
    public let absoluteError: Double
    public let center: SIMD3<Double>
}
```

---

## GeomFill_Profiler

`CurveProfiler` homogenizes a set of `Curve3D` values into a single compatible BSpline representation, which is a prerequisite for multi-section surface operations. Wraps `GeomFill_Profiler`.

### `CurveProfiler.create()`

Creates a new, empty curve profiler.

```swift
public static func create() -> CurveProfiler
```

- **OCCT:** `GeomFill_Profiler`.

---

### `addCurve(_:)`

Adds a curve to the profiler.

```swift
public func addCurve(_ curve: Curve3D)
```

- **OCCT:** `GeomFill_Profiler::AddCurve`.

---

### `perform(tolerance:)`

Performs the homogenization of all added curves.

```swift
@discardableResult
public func perform(tolerance: Double = 1e-6) -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `GeomFill_Profiler::Perform`.

---

### `degree`

Degree of the resulting homogenized BSpline curves.

```swift
public var degree: Int { get }
```

- **OCCT:** `GeomFill_Profiler::Degree`.

---

### `poleCount`

Number of poles per homogenized curve.

```swift
public var poleCount: Int { get }
```

- **OCCT:** `GeomFill_Profiler::NbPoles`.

---

### `knotCount`

Number of knots in the homogenized representation.

```swift
public var knotCount: Int { get }
```

- **OCCT:** `GeomFill_Profiler::NbKnots`.

---

### `isPeriodic`

Whether the homogenized curves are periodic.

```swift
public var isPeriodic: Bool { get }
```

- **OCCT:** `GeomFill_Profiler::IsPeriodic`.

---

### `poles(curveIndex:)`

Returns the poles for a specific curve (1-based index) after `perform()`.

```swift
public func poles(curveIndex: Int) -> [SIMD3<Double>]
```

- **Parameters:** `curveIndex` — 1-based index of the curve.
- **Returns:** An array of 3D pole positions, or empty if not computed or index is out of range.
- **OCCT:** `GeomFill_Profiler::Poles`.

---

### `knotsAndMults()`

Returns the knot vector and multiplicities of the homogenized representation.

```swift
public func knotsAndMults() -> (knots: [Double], mults: [Int])
```

- **Returns:** A tuple of parallel arrays; empty arrays on failure or before `perform()`.
- **OCCT:** `GeomFill_Profiler::Knots`, `GeomFill_Profiler::Mults`.
- **Example:**
  ```swift
  let profiler = CurveProfiler.create()
  profiler.addCurve(c1)
  profiler.addCurve(c2)
  if profiler.perform() {
      let (knots, mults) = profiler.knotsAndMults()
      print(knots)
  }
  ```

---

## GeomFill_Stretch

### `Surface.stretchFill(p1:p2:p3:p4:)`

Creates a BSpline surface by stretch-filling from four ordered boundary point arrays.

```swift
public static func stretchFill(p1: [SIMD3<Double>], p2: [SIMD3<Double>],
                                p3: [SIMD3<Double>], p4: [SIMD3<Double>]) -> StretchFillResult?
```

- **Parameters:** `p1`–`p4` — four boundary polylines, all of equal length ≥ 2. The order is: bottom, right, top, left (or equivalent opposing boundary pairs).
- **Returns:** A `StretchFillResult` containing pole grid dimensions and the flat pole array, or `nil` if the arrays have mismatched lengths, are too short, or the algorithm fails.
- **OCCT:** `GeomFill_Stretch`.
- **Example:**
  ```swift
  let p1: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(10,0,0)]
  let p2: [SIMD3<Double>] = [SIMD3(10,0,0), SIMD3(10,10,0)]
  let p3: [SIMD3<Double>] = [SIMD3(10,10,0), SIMD3(0,10,0)]
  let p4: [SIMD3<Double>] = [SIMD3(0,10,0), SIMD3(0,0,0)]
  if let r = Surface.stretchFill(p1: p1, p2: p2, p3: p3, p4: p4) {
      print(r.nbUPoles, r.nbVPoles)
  }
  ```

---

### `StretchFillResult`

Result struct returned by `Surface.stretchFill(p1:p2:p3:p4:)`.

```swift
public struct StretchFillResult {
    public let nbUPoles: Int
    public let nbVPoles: Int
    public let isRational: Bool
    public let poles: [SIMD3<Double>]
}
```

The `poles` array is laid out in row-major order: `poles[i * nbVPoles + j]` gives the pole at `(i, j)`.

---

## GeomFill_LocationDraft

`LocationDraft` implements a draft-angle location law for pipe/sweep operations. It positions a profile along a path while applying a specified taper angle. Wraps `GeomFill_LocationDraft`.

### `LocationDraft.create(direction:angle:)`

Creates a draft location law with a draft direction and angle.

```swift
public static func create(direction: SIMD3<Double>, angle: Double) -> LocationDraft
```

- **Parameters:** `direction` — the draft direction vector. `angle` — draft angle in radians.
- **OCCT:** `GeomFill_LocationDraft`.

---

### `setCurve(_:)`

Sets the sweep path curve on the location law.

```swift
@discardableResult
public func setCurve(_ curve: Curve3D) -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `GeomFill_LocationDraft::SetCurve`.

---

### `evaluate(at:)`

Evaluates the location frame (rotation matrix + translation) at a path parameter.

```swift
public func evaluate(at param: Double) -> (matrix: [Double], translation: SIMD3<Double>)?
```

- **Returns:** A tuple where `matrix` is a flat 9-element row-major 3×3 rotation matrix and `translation` is the origin offset, or `nil` on failure.
- **OCCT:** `GeomFill_LocationDraft::D0`.

---

### `setAngle(_:)`

Updates the draft angle (radians).

```swift
public func setAngle(_ angle: Double)
```

- **OCCT:** `GeomFill_LocationDraft::SetAngle`.

---

### `direction`

The current draft direction vector.

```swift
public var direction: SIMD3<Double> { get }
```

- **OCCT:** `GeomFill_LocationDraft::Direction`.
- **Example:**
  ```swift
  let ld = LocationDraft.create(direction: SIMD3(0, 0, 1), angle: 0.1)
  ld.setCurve(spine)
  if let frame = ld.evaluate(at: 0.5) {
      print(frame.translation)
  }
  ```

---

## GeomFill_GuideTrihedronAC

`GuideTrihedronAC` computes an arc-length-corrected Frenet-like trihedron along a sweep path guided by an auxiliary curve. Wraps `GeomFill_GuideTrihedronAC`.

### `GuideTrihedronAC.create(guideCurve:)`

Creates a guide trihedron law using an arc-length correction guide.

```swift
public static func create(guideCurve: Curve3D) -> GuideTrihedronAC
```

- **Parameters:** `guideCurve` — the guide curve that influences the trihedron orientation.
- **OCCT:** `GeomFill_GuideTrihedronAC`.

---

### `setCurve(_:)` (GuideTrihedronAC)

Sets the sweep path curve.

```swift
@discardableResult
public func setCurve(_ curve: Curve3D) -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `GeomFill_GuideTrihedronAC::SetCurve`.

---

### `evaluate(at:)` (GuideTrihedronAC)

Evaluates the trihedron frame at the given path parameter.

```swift
public func evaluate(at param: Double) -> (tangent: SIMD3<Double>, normal: SIMD3<Double>, binormal: SIMD3<Double>)?
```

- **Returns:** The tangent, normal, and binormal vectors at `param`, or `nil` on failure.
- **OCCT:** `GeomFill_GuideTrihedronAC::D0`.
- **Example:**
  ```swift
  let gta = GuideTrihedronAC.create(guideCurve: guide)
  gta.setCurve(spine)
  if let frame = gta.evaluate(at: 0.0) {
      print(frame.tangent)
  }
  ```

---

## GeomFill_GuideTrihedronPlan

`GuideTrihedronPlan` computes a planar guide trihedron for sweep operations, keeping the profile in planes normal to the guide. Wraps `GeomFill_GuideTrihedronPlan`.

### `GuideTrihedronPlan.create(guideCurve:)`

Creates a planar guide trihedron law from a guide curve.

```swift
public static func create(guideCurve: Curve3D) -> GuideTrihedronPlan
```

- **OCCT:** `GeomFill_GuideTrihedronPlan`.

---

### `setCurve(_:)` (GuideTrihedronPlan)

Sets the sweep path curve.

```swift
@discardableResult
public func setCurve(_ curve: Curve3D) -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `GeomFill_GuideTrihedronPlan::SetCurve`.

---

### `evaluate(at:)` (GuideTrihedronPlan)

Evaluates the trihedron frame at the given path parameter.

```swift
public func evaluate(at param: Double) -> (tangent: SIMD3<Double>, normal: SIMD3<Double>, binormal: SIMD3<Double>)?
```

- **Returns:** The tangent, normal, and binormal vectors at `param`, or `nil` on failure.
- **OCCT:** `GeomFill_GuideTrihedronPlan::D0`.

---

## GeomFill_SectionPlacement

### `Curve3D.sectionPlacement(section:direction:draftAngle:tolerance:)`

Places a section curve optimally onto a path curve using a draft location law, returning the closest-approach parameters and geometry.

```swift
public func sectionPlacement(section: Curve3D,
                              direction: SIMD3<Double> = SIMD3(0, 0, 1),
                              draftAngle: Double = 0,
                              tolerance: Double = 1e-3) -> SectionPlacementResult
```

Called on the path curve (`self`).

- **Parameters:**
  - `section` — the profile curve to place.
  - `direction` — draft direction; defaults to +Z.
  - `draftAngle` — taper angle in radians; default `0`.
  - `tolerance` — positional tolerance; default `1e-3`.
- **Returns:** A `SectionPlacementResult` (always returned; check `.isDone`).
- **OCCT:** `GeomFill_SectionPlacement`.
- **Example:**
  ```swift
  let r = spine.sectionPlacement(section: profile)
  if r.isDone { print(r.parameterOnPath, r.distance) }
  ```

---

### `SectionPlacementResult`

Result struct returned by `sectionPlacement(section:direction:draftAngle:tolerance:)`.

```swift
public struct SectionPlacementResult {
    public let parameterOnPath: Double
    public let parameterOnSection: Double
    public let distance: Double
    public let angle: Double
    public let isDone: Bool
}
```

---

## BRepFill_NSections

`NSections` encodes an N-section law describing how a set of wire cross-sections varies along a sweep or loft. Wraps `BRepFill_NSections`.

### `NSections.create(wires:)`

Creates an N-section law from an array of wire shapes.

```swift
public static func create(wires: [Shape]) -> NSections?
```

- **Parameters:** `wires` — two or more wire shapes representing the cross-section sequence.
- **Returns:** An `NSections` instance, or `nil` on failure.
- **OCCT:** `BRepFill_NSections`.

---

### `lawCount`

Number of section laws (one per wire pair interval).

```swift
public var lawCount: Int { get }
```

- **OCCT:** `BRepFill_NSections::NbLaw`.

---

### `isConstant`

Whether the section is constant (all wires are identical).

```swift
public var isConstant: Bool { get }
```

- **OCCT:** `BRepFill_NSections::IsConstant`.

---

### `isVertex`

Whether the section degenerates to a point vertex.

```swift
public var isVertex: Bool { get }
```

- **OCCT:** `BRepFill_NSections::IsVertex`.
- **Example:**
  ```swift
  if let ns = NSections.create(wires: [w1, w2, w3]) {
      print(ns.lawCount, ns.isConstant)
  }
  ```

---

## GeomFill_AppSurf

### `Surface.appSurf(curves:degMin:degMax:tol3d:tol2d:)`

Approximates a BSpline surface from a sequence of section curves.

```swift
public static func appSurf(curves: [Curve3D], degMin: Int = 3, degMax: Int = 8,
                            tol3d: Double = 1e-3, tol2d: Double = 1e-3) -> AppSurfResult?
```

- **Parameters:**
  - `curves` — ordered section curves to interpolate/approximate.
  - `degMin`, `degMax` — minimum and maximum allowed BSpline degree.
  - `tol3d`, `tol2d` — 3D and 2D fitting tolerances.
- **Returns:** An `AppSurfResult` on success, or `nil` if the algorithm fails.
- **OCCT:** `GeomFill_AppSurf`.
- **Example:**
  ```swift
  if let r = Surface.appSurf(curves: [c1, c2, c3]) {
      print(r.uDegree, r.vDegree, r.nbUPoles, r.nbVPoles)
  }
  ```

---

### `AppSurfResult`

Result struct returned by `Surface.appSurf(curves:degMin:degMax:tol3d:tol2d:)`.

```swift
public struct AppSurfResult {
    public let uDegree: Int
    public let vDegree: Int
    public let nbUPoles: Int
    public let nbVPoles: Int
    public let nbUKnots: Int
    public let nbVKnots: Int
    public let isDone: Bool
}
```

---

## ShapeFix_ComposeShell

### `composeShell(precision:)`

Splits a face into sub-faces using a composite surface grid, repairing topology at the seams.

```swift
public func composeShell(precision: Double = 1e-6) -> Shape?
```

- **Returns:** A `Shape` containing the repaired/split faces, or `nil` on failure.
- **OCCT:** `ShapeFix_ComposeShell`.
- **Example:**
  ```swift
  if let fixed = myFace.composeShell() {
      print(fixed.isValid)
  }
  ```

---

## Transform, Boolean & Shape Query expansions (v0.115.0)

### `transformed(matrix:)`

Applies a general affine transformation (rotation + translation) described by a 12-element matrix.

```swift
public func transformed(matrix: [Double]) -> Shape?
```

`matrix` must have exactly 12 elements in row-major 3×4 layout:
`[r00, r01, r02, r10, r11, r12, r20, r21, r22, tx, ty, tz]`.

- **Returns:** The transformed `Shape`, or `nil` if `matrix.count != 12`.
- **OCCT:** `BRepBuilderAPI_Transform`, `gp_Trsf`.
- **Example:**
  ```swift
  // Identity rotation, translate by (5, 0, 0)
  let m: [Double] = [1,0,0, 0,1,0, 0,0,1, 5,0,0]
  if let moved = box.transformed(matrix: m) { print(moved.isValid) }
  ```

---

### `gTransformed(matrix:)`

Applies a general affine transformation supporting non-uniform scaling.

```swift
public func gTransformed(matrix: [Double]) -> Shape?
```

`matrix` must have exactly 12 elements, row-major 3×4:
`[r00, r01, r02, tx, r10, r11, r12, ty, r20, r21, r22, tz]`.

- **Returns:** The transformed `Shape`, or `nil` if `matrix.count != 12`.
- **OCCT:** `BRepBuilderAPI_GTransform`, `gp_GTrsf`.
- **Note:** The layout convention differs slightly from `transformed(matrix:)` — each row is `[r_i0, r_i1, r_i2, t_i]`.

---

### `section(with:tolerance:)`

Computes a boolean section with a fuzzy tolerance.

```swift
public func section(with other: Shape, tolerance: Double) -> Shape?
```

- **Parameters:** `other` — the tool shape. `tolerance` — fuzzy coincidence tolerance.
- **Returns:** A `Shape` containing the intersection edges/wires, or `nil` on failure.
- **OCCT:** `BRepAlgoAPI_Section` with fuzzy value.

---

### `split(tools:tolerance:)`

Splits this shape by multiple tool shapes simultaneously.

```swift
public func split(tools: [Shape], tolerance: Double = 0) -> Shape?
```

- **Parameters:** `tools` — array of splitting shapes. `tolerance` — fuzzy tolerance; default `0`.
- **Returns:** The split compound `Shape`, or `nil` on failure.
- **OCCT:** `BRepAlgoAPI_Splitter`.

---

### `BooleanHistoryResult`

Result struct for boolean operations with change-history flags.

```swift
public struct BooleanHistoryResult: Sendable {
    public let shape: Shape
    public let hasDeleted: Bool
    public let hasModified: Bool
    public let hasGenerated: Bool
}
```

---

### `subtractedWithHistory(_:tolerance:)`

Performs a boolean subtraction and returns change-history flags alongside the result shape.

```swift
public func subtractedWithHistory(_ tool: Shape, tolerance: Double = 0) -> BooleanHistoryResult?
```

- **Returns:** A `BooleanHistoryResult`, or `nil` on failure.
- **OCCT:** `BRepAlgoAPI_Cut` with history builder.
- **Example:**
  ```swift
  if let r = solid.subtractedWithHistory(hole) {
      print(r.hasModified, r.shape.isValid)
  }
  ```

---

### `defeature(faces:tolerance:)`

Removes specified faces from the shape (defeaturing).

```swift
public func defeature(faces: [Shape], tolerance: Double = 0) -> Shape?
```

- **Parameters:** `faces` — the face shapes to remove. `tolerance` — fuzzy tolerance; default `0`.
- **Returns:** The defeatured `Shape`, or `nil` on failure.
- **OCCT:** `BRepAlgoAPI_Defeaturing`.

---

### `triangulationNodeCount`

Number of triangulation nodes on a face.

```swift
public var triangulationNodeCount: Int32 { get }
```

- **OCCT:** `BRep_Tool::Triangulation` → `Poly_Triangulation::NbNodes`.

---

### `triangulationTriangleCount`

Number of triangles in the face triangulation.

```swift
public var triangulationTriangleCount: Int32 { get }
```

- **OCCT:** `Poly_Triangulation::NbTriangles`.

---

### `triangulationDeflection`

The deflection value stored on the face triangulation.

```swift
public var triangulationDeflection: Double { get }
```

- **OCCT:** `Poly_Triangulation::Deflection`.

---

### `triangulationNode(at:)`

Returns the 3D coordinates of a triangulation node by its 1-based index.

```swift
public func triangulationNode(at index: Int32) -> SIMD3<Double>
```

- **OCCT:** `Poly_Triangulation::Node`.

---

### `triangulationTriangle(at:)`

Returns the three 1-based node indices of a triangle by its 1-based index.

```swift
public func triangulationTriangle(at index: Int32) -> (Int32, Int32, Int32)
```

- **OCCT:** `Poly_Triangulation::Triangle`.

---

### `triangulationHasNormals`

Whether the face triangulation stores per-node normals.

```swift
public var triangulationHasNormals: Bool { get }
```

- **OCCT:** `Poly_Triangulation::HasNormals`.

---

### `triangulationNormal(at:)`

Returns the normal vector at a triangulation node by its 1-based index.

```swift
public func triangulationNormal(at index: Int32) -> SIMD3<Double>
```

- **OCCT:** `Poly_Triangulation::Normal`.

---

### `triangulationHasUVNodes`

Whether the face triangulation stores per-node UV coordinates.

```swift
public var triangulationHasUVNodes: Bool { get }
```

- **OCCT:** `Poly_Triangulation::HasUVNodes`.

---

### `triangulationUVNode(at:)`

Returns the UV coordinates of a triangulation node by its 1-based index.

```swift
public func triangulationUVNode(at index: Int32) -> SIMD2<Double>
```

- **OCCT:** `Poly_Triangulation::UVNode`.

---

### `edgeParameterAtArcLength(_:from:)`

Finds the curve parameter on this edge at the given arc length from a start parameter.

```swift
public func edgeParameterAtArcLength(_ arcLength: Double, from startParam: Double) -> Double
```

- **OCCT:** `GCPnts_AbscissaPoint`.

---

### `edgeArcLength`

The total arc length of this edge.

```swift
public var edgeArcLength: Double { get }
```

- **OCCT:** `GCPnts_AbscissaPoint` / `BRepAdaptor_Curve`.

---

### `edgeArcLength(from:to:)`

Computes the arc length of this edge between two parameter values.

```swift
public func edgeArcLength(from u1: Double, to u2: Double) -> Double
```

- **OCCT:** `GCPnts_AbscissaPoint`.

---

### `edgeParameterAtFraction(_:)`

Returns the curve parameter at a fractional position (0–1) along the total edge length.

```swift
public func edgeParameterAtFraction(_ fraction: Double) -> Double
```

- **OCCT:** `GCPnts_AbscissaPoint`.

---

### `edgeAdaptorDomain`

The parameter domain `[first, last]` of the edge curve via `BRepAdaptor_Curve`.

```swift
public var edgeAdaptorDomain: ClosedRange<Double> { get }
```

- **OCCT:** `BRepAdaptor_Curve::FirstParameter`, `LastParameter`.

---

### `edgeAdaptorValue(at:)`

Evaluates the edge curve at a parameter, returning the 3D point.

```swift
public func edgeAdaptorValue(at param: Double) -> SIMD3<Double>
```

- **OCCT:** `BRepAdaptor_Curve::Value`.

---

### `edgeAdaptorCurveType`

The curve type of the edge as a `GeomAbs_CurveType` integer (`0`=Line, `1`=Circle, etc.).

```swift
public var edgeAdaptorCurveType: Int32 { get }
```

- **OCCT:** `BRepAdaptor_Curve::GetType`.

---

### `faceAdaptorBounds`

The UV parameter bounds of a face surface via `BRepAdaptor_Surface`.

```swift
public var faceAdaptorBounds: (uMin: Double, uMax: Double, vMin: Double, vMax: Double) { get }
```

- **OCCT:** `BRepAdaptor_Surface::FirstUParameter`, `LastUParameter`, `FirstVParameter`, `LastVParameter`.

---

### `faceAdaptorValue(u:v:)`

Evaluates the face surface at (u, v), returning the 3D point.

```swift
public func faceAdaptorValue(u: Double, v: Double) -> SIMD3<Double>
```

- **OCCT:** `BRepAdaptor_Surface::Value`.

---

### `faceAdaptorSurfaceType`

The surface type of the face as a `GeomAbs_SurfaceType` integer (`0`=Plane, `1`=Cylinder, etc.).

```swift
public var faceAdaptorSurfaceType: Int32 { get }
```

- **OCCT:** `BRepAdaptor_Surface::GetType`.

---

### `obbVolume`

Volume of the oriented bounding box (OBB) of this shape.

```swift
public var obbVolume: Double { get }
```

- **OCCT:** `Bnd_OBB` via `BRepBndLib::AddOBB`.

---

### `maxEdgeTolerance`

Maximum tolerance across all edges in this shape.

```swift
public var maxEdgeTolerance: Double { get }
```

- **OCCT:** `BRep_Tool::MaxTolerance` / `ShapeAnalysis_ShapeTolerance`.

---

### `maxFaceTolerance`

Maximum tolerance across all faces in this shape.

```swift
public var maxFaceTolerance: Double { get }
```

- **OCCT:** `ShapeAnalysis_ShapeTolerance`.

---

### `maxVertexTolerance`

Maximum tolerance across all vertices in this shape.

```swift
public var maxVertexTolerance: Double { get }
```

- **OCCT:** `ShapeAnalysis_ShapeTolerance`.

---

### `hasFreeEdges`

Whether this shape contains free (non-shared) edges.

```swift
public var hasFreeEdges: Bool { get }
```

- **OCCT:** `ShapeAnalysis_FreeBounds` or `BRepCheck_Analyzer`.

---

### `hasFreeWires`

Whether this shape contains free (non-shared) wires.

```swift
public var hasFreeWires: Bool { get }
```

- **OCCT:** `ShapeAnalysis_FreeBounds`.

---

### `hasFreeFaces`

Whether this shape contains free (non-shared) faces.

```swift
public var hasFreeFaces: Bool { get }
```

- **OCCT:** `ShapeAnalysis_FreeBounds`.

---

### `boundingDiagonal`

Length of the axis-aligned bounding box diagonal.

```swift
public var boundingDiagonal: Double { get }
```

- **OCCT:** `BRepBndLib::Add`, `Bnd_Box::CornerMin`/`CornerMax`.

---

### `centroid`

Volumetric centroid of this shape.

```swift
public var centroid: SIMD3<Double> { get }
```

- **OCCT:** `GProp_GProps` via `BRepGProp::VolumeProperties`.

---

### `totalEdgeLength`

Sum of arc lengths of all edges in this shape.

```swift
public var totalEdgeLength: Double { get }
```

- **OCCT:** `BRepGProp::LinearProperties`, `GProp_GProps::Mass`.

---

## ThruSections builder (v0.115.0)

`ThruSectionsBuilder` drives `BRepOffsetAPI_ThruSections` through a builder pattern, providing full control over smoothing, degree, and continuity before building.

### `ThruSectionsBuilder.init(isSolid:isRuled:precision:)`

Creates a loft builder.

```swift
public init(isSolid: Bool = true, isRuled: Bool = false, precision: Double = 1e-6)
```

- **Parameters:**
  - `isSolid` — `true` (default) caps the ends to produce a solid; `false` gives a shell.
  - `isRuled` — `true` uses ruled (linear) surfaces between sections; `false` (default) uses BSpline.
  - `precision` — 3D tolerance; default `1e-6`.
- **OCCT:** `BRepOffsetAPI_ThruSections`.
- **Note:** Mixing closed and open profiles causes a SIGSEGV inside OCCT (`BRepFill_CompatibleWires`). A source patch shipped with this xcframework guards the iterator; still, ensure all profiles have the same open/closed status.

---

### `addWire(_:)` (ThruSectionsBuilder)

Adds a wire profile as the next cross-section.

```swift
public func addWire(_ wire: Shape)
```

- **OCCT:** `BRepOffsetAPI_ThruSections::AddWire`.

---

### `addVertex(_:)` (ThruSectionsBuilder)

Adds a vertex (degenerate point) as a tip section.

```swift
public func addVertex(_ vertex: Shape)
```

- **OCCT:** `BRepOffsetAPI_ThruSections::AddVertex`.

---

### `setSmoothing(_:)`

Enables or disables smoothing of the loft surface.

```swift
public func setSmoothing(_ smoothing: Bool)
```

- **OCCT:** `BRepOffsetAPI_ThruSections::SetSmoothing`.

---

### `setMaxDegree(_:)`

Sets the maximum BSpline degree used for the loft.

```swift
public func setMaxDegree(_ maxDeg: Int)
```

- **OCCT:** `BRepOffsetAPI_ThruSections::SetMaxDegree`.

---

### `setContinuity(_:)` (ThruSectionsBuilder)

Sets the desired continuity of the lofted surface.

```swift
public func setContinuity(_ continuity: Int)
```

- **Parameters:** `continuity` — `0`=C0, `1`=C1, `2`=C2.
- **OCCT:** `BRepOffsetAPI_ThruSections::SetContinuity`.

---

### `build()` (ThruSectionsBuilder)

Executes the loft algorithm.

```swift
@discardableResult
public func build() -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `BRepOffsetAPI_ThruSections::Build`.

---

### `shape` (ThruSectionsBuilder)

The result shape after a successful `build()`.

```swift
public var shape: Shape? { get }
```

- **Returns:** The lofted `Shape`, or `nil` if `build()` has not been called or failed.
- **OCCT:** `BRepOffsetAPI_ThruSections::Shape`.
- **Example:**
  ```swift
  let builder = ThruSectionsBuilder(isSolid: true)
  builder.addWire(bottomWire)
  builder.addWire(topWire)
  builder.setSmoothing(true)
  if builder.build(), let loft = builder.shape {
      print(loft.isValid)
  }
  ```

---

## ShapeFixer builder (v0.115.0)

`ShapeFixer` provides configurable shape repair via `ShapeFix_Shape`, exposing precision, tolerance bounds, and per-fix status reporting.

### `ShapeFixer.init(shape:)`

Creates a fixer for the given shape.

```swift
public init(shape: Shape)
```

- **OCCT:** `ShapeFix_Shape`.

---

### `setPrecision(_:)` (ShapeFixer)

Sets the working precision for repair algorithms.

```swift
public func setPrecision(_ precision: Double)
```

- **OCCT:** `ShapeFix_Root::SetPrecision`.

---

### `setMaxTolerance(_:)`

Sets the upper bound on tolerances that the fixer may assign.

```swift
public func setMaxTolerance(_ maxTol: Double)
```

- **OCCT:** `ShapeFix_Root::SetMaxTolerance`.

---

### `setMinTolerance(_:)`

Sets the lower bound on tolerances that the fixer may assign.

```swift
public func setMinTolerance(_ minTol: Double)
```

- **OCCT:** `ShapeFix_Root::SetMinTolerance`.

---

### `perform()` (ShapeFixer)

Runs all applicable shape-fixing algorithms.

```swift
@discardableResult
public func perform() -> Bool
```

- **Returns:** `true` if any fix was applied.
- **OCCT:** `ShapeFix_Shape::Perform`.

---

### `shape` (ShapeFixer)

The repaired shape after `perform()`.

```swift
public var shape: Shape? { get }
```

- **Returns:** The fixed `Shape`, or `nil` if `perform()` has not been called or produced nothing.
- **OCCT:** `ShapeFix_Shape::Shape`.

---

### `status(_:)`

Queries the fix result status.

```swift
public func status(_ type: Int) -> Bool
```

- **Parameters:** `type` — `1`=OK (no fix needed), `2`=DONE (fix applied), `3`=FAIL (fix attempted but failed).
- **Returns:** `true` if the queried status flag is set.
- **OCCT:** `ShapeFix_Shape::Status`.
- **Example:**
  ```swift
  let fixer = ShapeFixer(shape: badShape)
  fixer.setPrecision(1e-4)
  fixer.perform()
  if let fixed = fixer.shape { print(fixer.status(2)) } // true = something was fixed
  ```

---

## BRep_Tool completions (v0.126.0)

### `Shape.curveOnSurface(edge:face:)`

Returns the 2D parametric curve (pcurve) of an edge on a face, with its parameter range.

```swift
public static func curveOnSurface(edge: Shape, face: Shape) -> (curve: Curve2D, first: Double, last: Double)?
```

- **Returns:** A tuple of the 2D `Curve2D` and its `first`/`last` parameter range, or `nil` if no pcurve exists.
- **OCCT:** `BRep_Tool::CurveOnSurface`.

---

### `Shape.hasContinuity(edge:face1:face2:)`

Checks whether an edge has recorded continuity regularity between two adjacent faces.

```swift
public static func hasContinuity(edge: Shape, face1: Shape, face2: Shape) -> Bool
```

- **OCCT:** `BRep_Tool::HasContinuity`.

---

### `Shape.continuity(edge:face1:face2:)`

Returns the continuity order of an edge between two faces as a `GeomAbs_Shape` integer.

```swift
public static func continuity(edge: Shape, face1: Shape, face2: Shape) -> Int
```

- **Returns:** `GeomAbs_Shape` integer: `0`=C0, `1`=G1, `2`=C1, `3`=G2, `4`=C2, `5`=C3, `6`=CN.
- **OCCT:** `BRep_Tool::Continuity`.

---

### `Shape.hasAnyContinuity(edge:)`

Checks whether an edge has any recorded continuity on any pair of its surfaces.

```swift
public static func hasAnyContinuity(edge: Shape) -> Bool
```

- **OCCT:** `BRep_Tool::HasContinuity` (any-surface overload).

---

### `Shape.maxContinuity(edge:)`

Returns the maximum continuity of an edge across all surface pairs it belongs to.

```swift
public static func maxContinuity(edge: Shape) -> Int
```

- **Returns:** The highest `GeomAbs_Shape` integer found.
- **OCCT:** `BRep_Tool::MaxContinuity`.

---

### `Shape.isDegenerated(edge:)`

Returns `true` if the edge is degenerated (collapsed to a point in 3D).

```swift
public static func isDegenerated(edge: Shape) -> Bool
```

- **OCCT:** `BRep_Tool::Degenerated`.

---

### `Shape.naturalRestriction(face:)`

Returns the value of the `NaturalRestriction` flag on a face.

```swift
public static func naturalRestriction(face: Shape) -> Bool
```

A face with natural restriction uses the full parameter domain of its surface as its boundary without additional wire loops.

- **OCCT:** `BRep_Tool::NaturalRestriction`.

---

### `Shape.rangeOnFace(edge:face:)`

Returns the parameter range of an edge's pcurve on a given face.

```swift
public static func rangeOnFace(edge: Shape, face: Shape) -> (first: Double, last: Double)?
```

- **Returns:** The `(first, last)` parameter range, or `nil` if no pcurve exists.
- **OCCT:** `BRep_Tool::Range`.

---

### `Shape.parameterOnFace(vertex:edge:face:)`

Returns the parameter of a vertex on the pcurve of an edge on a face.

```swift
public static func parameterOnFace(vertex: Shape, edge: Shape, face: Shape) -> Double?
```

- **Returns:** The parameter value, or `nil` on failure.
- **OCCT:** `BRep_Tool::Parameter`.

---

### `Shape.parametersOnFace(vertex:face:)`

Returns the UV parameters of a vertex on a face.

```swift
public static func parametersOnFace(vertex: Shape, face: Shape) -> (u: Double, v: Double)?
```

- **Returns:** The `(u, v)` parameter pair, or `nil` if the vertex does not lie on the face.
- **OCCT:** `BRep_Tool::Parameters`.

---

### `Shape.uvPoints(edge:face:)`

Returns the UV coordinates at both endpoints of an edge on a face.

```swift
public static func uvPoints(edge: Shape, face: Shape) -> (firstU: Double, firstV: Double, lastU: Double, lastV: Double)?
```

- **Returns:** Four UV values describing the start and end 2D positions, or `nil` on failure.
- **OCCT:** `BRep_Tool::UVPoints`.

---

### `maxTolerance(subShapeType:)`

Returns the maximum tolerance of all sub-shapes of the specified type within this shape.

```swift
public func maxTolerance(subShapeType: Int) -> Double
```

- **Parameters:** `subShapeType` — OCCT `TopAbs_ShapeEnum` integer: `4`=FACE, `6`=EDGE, `7`=VERTEX.
- **OCCT:** `BRep_Tool::MaxTolerance` / `ShapeAnalysis_ShapeTolerance`.

---

## Section with plane/surface & BRep_Tool Polygon queries (v0.127.0)

### `sectionWithPlane(normal:origin:)`

Computes the section (intersection edges) of this shape with a plane.

```swift
public func sectionWithPlane(normal: SIMD3<Double>, origin: SIMD3<Double>) -> Shape?
```

- **Parameters:** `normal` — outward normal of the cutting plane. `origin` — any point on the plane.
- **Returns:** A `Shape` containing the section edges/wires, or `nil` on failure.
- **OCCT:** `BRepAlgoAPI_Section` with an internal `gp_Pln`.
- **Example:**
  ```swift
  if let section = solid.sectionWithPlane(normal: SIMD3(0,0,1), origin: SIMD3(0,0,5)) {
      print(section.edges.count)
  }
  ```

---

### `sectionWithSurface(_:)`

Computes the section (intersection curves) of this shape with an arbitrary surface.

```swift
public func sectionWithSurface(_ surface: Surface) -> Shape?
```

- **Returns:** A `Shape` containing the section edges, or `nil` on failure.
- **OCCT:** `BRepAlgoAPI_Section` with a `Geom_Surface` tool.

---

### `Shape.curveOnPlane(edge:surface:)`

Returns the 2D projection of an edge onto a planar surface, with parameter range.

```swift
public static func curveOnPlane(edge: Shape, surface: Surface) -> (curve: Curve2D, first: Double, last: Double)?
```

- **Returns:** A `Curve2D` and its parameter range, or `nil` if projection fails.
- **OCCT:** `BRep_Tool::CurveOnPlane`.

---

### `Shape.polygon3D(edge:)`

Returns the 3D polygon of a meshed edge (discrete approximation from triangulation).

```swift
public static func polygon3D(edge: Shape) -> [SIMD3<Double>]?
```

The shape must have been meshed (`mesh(deflection:)`) before calling this.

- **Returns:** An ordered array of 3D points along the edge, or `nil` if no polygon is stored.
- **OCCT:** `BRep_Tool::Polygon3D`, `Poly_Polygon3D::Nodes`.

---

### `Shape.polygonOnTriangulation(edge:)`

Returns the triangulation-node indices of a meshed edge as a 1-based index array.

```swift
public static func polygonOnTriangulation(edge: Shape) -> [Int]?
```

The shape must have been meshed first.

- **Returns:** An array of 1-based indices into the parent face's `Poly_Triangulation`, or `nil` if not available.
- **OCCT:** `BRep_Tool::PolygonOnTriangulation`, `Poly_PolygonOnTriangulation::Nodes`.

---

## BRep_Tool completions (v0.128.0)

### `Shape.isClosedOnFace(edge:face:)`

Checks whether an edge is topologically closed on a face (i.e., the edge has two pcurves on the face with opposing orientations).

```swift
public static func isClosedOnFace(edge: Shape, face: Shape) -> Bool
```

- **OCCT:** `BRep_Tool::IsClosed`.

---

### `Shape.polygonOnSurface(edge:face:)`

Returns the 2D polygon (UV) of a meshed edge on a face.

```swift
public static func polygonOnSurface(edge: Shape, face: Shape) -> [SIMD2<Double>]?
```

The shape must have been meshed first.

- **Returns:** An ordered array of 2D UV points, or `nil` if not available.
- **OCCT:** `BRep_Tool::PolygonOnSurface`, `Poly_Polygon2D::Nodes`.

---

### `Shape.setUVPoints(edge:face:first:last:)`

Sets the UV endpoint coordinates of an edge on a face (updates the stored 2D boundary).

```swift
@discardableResult
public static func setUVPoints(edge: Shape, face: Shape,
                                first: SIMD2<Double>, last: SIMD2<Double>) -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `BRep_Tool::UVPoints` (setter overload via `BRep_Builder`).
- **Example:**
  ```swift
  let ok = Shape.setUVPoints(edge: e, face: f,
                              first: SIMD2(0, 0), last: SIMD2(1, 0))
  ```
