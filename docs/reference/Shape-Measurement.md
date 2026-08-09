---
title: Shape — Measurement, Sub-Shapes & Local Operations
parent: API Reference
---

# Shape — Measurement, Sub-Shapes & Local Operations

This page covers the measurement, decomposition, healing, and local-operation APIs on `Shape`, declared in `Shape.swift`. For the core primitives, Boolean operations, and transforms, see the main **[Shape](Shape.md)** page.

## Topics

- [Sub-Shape Extraction](#sub-shape-extraction-v0380) · [Fuse and Blend](#fuse-and-blend-v0380) · [Multi-Edge Evolving Fillet](#multi-edge-evolving-fillet-v0380) · [Per-Face Variable Offset](#per-face-variable-offset-v0380) · [Free Boundary Analysis](#free-boundary-analysis-v0390) · [Pipe Feature](#pipe-feature-v0390) · [Semi-Infinite Extrusion](#semi-infinite-extrusion-v0390) · [Prism Until Face](#prism-until-face-v0390) · [Inertia Properties](#inertia-properties-v0400) · [Extended Distance](#extended-distance-v0400) · [Find Surface](#find-surface-v0400) · [Shape Surgery](#shape-surgery-v0410) · [Plane Detection](#plane-detection-v0410) · [Closed Edge Splitting](#closed-edge-splitting-v0410) · [Geometry Conversion](#geometry-conversion-v0410) · [Face Restriction](#face-restriction-v0410) · [Solid Construction / 2D Fillet / Point Cloud](#solid-construction-2d-fillet-and-point-cloud-v0420) · [Face Subdivision](#face-subdivision-v0430) · [Curve-on-Surface Check](#curve-on-surface-check) · [Edge Connection](#edge-connection) · [Self-Intersection Detection](#self-intersection-detection-v0450) · [Bezier Conversion](#bezier-conversion) · [Edge Concavity Analysis](#edge-concavity-analysis-v0460) · [Geometric Edge Selection](#geometric-edge-selection-v121) · [Local Prism / Volume Inertia](#local-prism-and-volume-inertia-v0460) · [Local Revolution](#local-revolution-v0470) · [Draft Prism](#draft-prism-v0470) · [Constrained Filling](#constrained-filling-v0470) · [Shape Validity Checking](#shape-validity-checking-v0470) · [Local Operations / Validation / Fixing / Extrema](#local-operations-validation-fixing-and-extrema-v0480) · [ShapeAnalysis FreeBoundsProperties](#shapeanalysis-freeboundsproperties) · [Internal Storage](#internal-storage)

---

## Sub-Shape Extraction (v0.38.0)

Every accessor in this section, plus `subShapeCount(ofType:)`, `subShapes(ofType:)`, `faceCount`,
`edgeCount` and `vertexCount` elsewhere, reads **one** enumeration: `TopExp::MapShapes` into a
`TopTools_IndexedMapOfShape`, in `TopExp_Explorer` order, one entry per **distinct** sub-shape.
"Distinct" is `TopoDS_Shape::IsSame`: same underlying geometry *and* same placement, orientation
ignored. So a sub-shape reachable from two parents is counted once, while two *placements* of one
body are counted twice (instanced assemblies are not collapsed). A shape is its own sub-shape when
it is of the requested type. (#502)

### `solidCount`

Number of distinct solid sub-shapes in this shape.

```swift
public var solidCount: Int { get }
```

- **OCCT:** `TopExp::MapShapes` with `TopAbs_SOLID` (via `OCCTShapeGetSubShapeCount`).
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  print(box.solidCount)                             // 1, a solid is its own sub-shape
  print(Shape.compound([box, box])!.solidCount)     // 1, one body, listed twice
  print(Shape.compound([box, box.translated(by: SIMD3(50, 0, 0))!])!.solidCount)  // 2
  ```

---

### `solids`

Extract all distinct solid sub-shapes, in enumeration order.

```swift
public var solids: [Shape] { get }
```

- **Returns:** Array of solid sub-shapes; empty if none.
- **OCCT:** `TopExp::MapShapes` with `TopAbs_SOLID`.
- **Example:**
  ```swift
  let compound = Shape.compound([box1, box2])!
  let all = compound.solids  // [box1, box2]
  ```

---

### `shellCount`

Number of distinct shell sub-shapes. A shell reused by two solids counts once.

```swift
public var shellCount: Int { get }
```

- **OCCT:** `TopExp::MapShapes` with `TopAbs_SHELL`.
- **Example:**
  ```swift
  let hollow = Shape.box(origin: .zero, width: 20, height: 20, depth: 20)!
      .subtracting(Shape.box(origin: SIMD3(6, 6, 6), width: 8, height: 8, depth: 8)!)!
  print(hollow.shellCount)  // 2, the outer boundary and the cavity
  ```

---

### `outerShell`

The outer shell of this solid.

```swift
public var outerShell: Shape? { get }
```

For a solid with internal voids (multiple shells), returns the shell bounding the outer body, distinguishing it from inner void shells.

Answers only for a shape that denotes exactly **one** solid: a solid, or a compound/compsolid wrapping a single solid. A container holding two or more solids has no single outer shell to name, so it returns `nil` rather than one arbitrary member's shell — use [`outerShells`](#outershells) there.

- **Returns:** The outer shell, or `nil` if the shape does not denote exactly one solid, or has no shell.
- **OCCT:** `BRepClass3d::OuterShell`.
- **Example:**
  ```swift
  if let outer = hollowSolid.outerShell {
      print(outer.faceCount)
  }

  // Two bodies in one compound: nil, not the first body's shell.
  let a = Shape.box(origin: .zero, width: 10, height: 10, depth: 10)!
  let b = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10)!
  print(Shape.compound([a, b])!.outerShell == nil)   // true
  ```

---

### `outerShells`

The outer shell of every solid in this shape, in exploration order.

```swift
public var outerShells: [Shape] { get }
```

The multi-body counterpart of [`outerShell`](#outershell): one shell per solid. Empty for a shape with no solids. Equivalent to `solids.compactMap(\.outerShell)`, in a single traversal.

These shells drop internal void walls by design. To measure against the complete boundary of a multi-body part — cavities included — use `Shape.compound(subShapes(ofType: .face))`.

- **Returns:** One outer shell per solid; empty if the shape has no solids.
- **OCCT:** `BRepClass3d::OuterShell` per solid.
- **Example:**
  ```swift
  let a = Shape.box(origin: .zero, width: 10, height: 10, depth: 10)!
  let b = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10)!
  let part = Shape.compound([a, b])!
  print(part.outerShells.count)              // 2
  print(part.outerShells.map(\.faceCount))   // [6, 6]
  ```

---

### `innerShells`

Inner (void / cavity) shells of this solid — every shell except `outerShell`.

```swift
public var innerShells: [Shape] { get }
```

Follows the same single-solid rule as [`outerShell`](#outershell): a container holding two or more solids reports no cavities of its own. For a multi-body part, take each solid separately with `solids.flatMap(\.innerShells)`.

- **Returns:** Empty for a solid with no internal voids, for a non-solid, or for a container of two or more solids.
- **OCCT:** `OCCTShapeInnerShells`.
- **Example:**
  ```swift
  let cavities = part.innerShells
  print("cavity count: \(cavities.count)")
  ```

---

### `shells`

Extract all shell sub-shapes.

```swift
public var shells: [Shape] { get }
```

- **Returns:** Array of all shell sub-shapes (inner and outer), in enumeration order.
- **OCCT:** `TopExp::MapShapes` with `TopAbs_SHELL`. Use `outerShell` / `innerShells` to tell the
  boundary from the cavities; this accessor puts no meaning on the order.

---

### `wireCount`

Number of distinct wire sub-shapes. A wire used to build two faces counts once.

```swift
public var wireCount: Int { get }
```

- **OCCT:** `TopExp::MapShapes` with `TopAbs_WIRE`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 5, depth: 3)!
  print(box.wireCount)  // 6, one boundary wire per face
  ```

---

### `wires`

Extract all distinct wire sub-shapes, in enumeration order.

```swift
public var wires: [Shape] { get }
```

- **Returns:** Array of wire sub-shapes; empty if none.
- **OCCT:** `TopExp::MapShapes` with `TopAbs_WIRE`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 5, depth: 3)!
  print(box.wires.compactMap(Wire.init).count)  // 6, as typed Wire objects
  ```

---

## Fuse and Blend (v0.38.0)

### `fusedAndBlended(with:radius:)`

Fuse with another shape and fillet the intersection edges.

```swift
public func fusedAndBlended(with other: Shape, radius: Double) -> Shape?
```

- **Parameters:**
  - `other` — Shape to fuse with.
  - `radius` — Fillet radius applied to intersection edges after fusion.
- **Returns:** Fused and filleted shape, or `nil` on failure.
- **OCCT:** `BRepAlgoAPI_Fuse` + `BRepFilletAPI_MakeFillet`.
- **Example:**
  ```swift
  if let result = boxA.fusedAndBlended(with: boxB, radius: 2.0) {
      print(result.isValid)
  }
  ```

---

### `cutAndBlended(with:radius:)`

Cut another shape from this shape and fillet the intersection edges.

```swift
public func cutAndBlended(with other: Shape, radius: Double) -> Shape?
```

- **Parameters:**
  - `other` — Shape to cut from this shape.
  - `radius` — Fillet radius applied to intersection edges after cutting.
- **Returns:** Cut and filleted shape, or `nil` on failure.
- **OCCT:** `BRepAlgoAPI_Cut` + `BRepFilletAPI_MakeFillet`.

---

## Multi-Edge Evolving Fillet (v0.38.0)

### `EvolvingFilletEdge`

Describes an evolving radius along an edge for filleting.

```swift
public struct EvolvingFilletEdge: Sendable {
    public var edgeIndex: Int
    public var radiusPoints: [(parameter: Double, radius: Double)]
    public init(edge: Edge, radiusPoints: [(parameter: Double, radius: Double)])
}
```

- `edgeIndex` — 0-based edge index, as reported by `Edge.index`. **This was 1-based until #520**,
  the one edge index in the fillet family that was; `init(edgeIndex:radiusPoints:)` is now
  `unavailable` rather than silently reinterpreted, so an old call site fails to build with an
  explanation instead of quietly filleting the neighbouring edge. Build the spec from the `Edge`
  itself, or assign `edgeIndex` after re-checking the index you pass.
- `radiusPoints` — Array of `(parameter, radius)` pairs defining the radius evolution along the
  edge. Parameters are relative: `0.0` is the start of the edge, `1.0` its end. Every radius must
  be positive, and the parameters must lie in `0...1` and strictly increase.

| Field | Meaning |
|---|---|
| `edgeIndex` | 0-based index of the edge to fillet, per `Edge.index`. |
| `radiusPoints` | `(parameter, radius)` pairs defining the radius law along the edge. |

---

#### `EvolvingFilletEdge.radiusPoints`

> OCCT stretches the law across the whole edge, so a profile cannot fillet part of one and leave
> the rest alone. With one or two points the parameters are ignored entirely (a single point is a
> constant radius); with three or more only the *relative* spacing of the interior points survives,
> because OCCT renormalises the first parameter to 0 and the last to 1.

---

### `filletEvolving(_:)`

Apply evolving-radius fillets to multiple edges simultaneously.

```swift
public func filletEvolving(_ edges: [EvolvingFilletEdge]) -> Shape?
```

- **Parameters:** `edges` — Array of edge specifications with radius evolution; must not be empty.
- **Returns:** Filleted shape, or `nil` on failure. Every edge is filleted or none is: an
  `edgeIndex` naming no edge of this shape returns `nil` rather than filleting the rest, and so
  does a non-positive radius, a parameter outside `0...1`, a non-increasing parameter sequence, or
  an empty `radiusPoints` (#520).
- **Contours and slots:** each edge's law is applied to that edge's own slot within its own contour.
  OCCT groups tangent-continuous edges into a single contour, but a contour holds one law *per
  edge*, so two edges of one tangent chain can each carry a different law. An edge OCCT declines to
  fillet (a free-boundary edge of an open shell) is skipped, matching
  [`blendedEdges(_:)`](#blendededges_); a request in which it declines every edge returns `nil`.
  Naming the same edge twice writes its slot twice and the later law wins (#612).
- **OCCT:** `BRepFilletAPI_MakeFillet` with evolving law (via `OCCTShapeFilletEvolving`), with the
  contour and the index within it resolved per edge by `Contour(E)` / `NbEdges(IC)` / `Edge(IC, J)`.
- **Example:**
  ```swift
  let spec = EvolvingFilletEdge(edge: box.edges()[0], radiusPoints: [(0.0, 1.0), (1.0, 3.0)])
  if let filled = box.filletEvolving([spec]) {
      print(filled.isValid)
  }

  // A rounded slot — two straight sides joined by two semicircular ends, extruded. Its whole
  // top rim is one tangent-continuous contour, and each edge of it still carries its own law.
  let profile = Wire.join([
      Wire.line(from: SIMD3(-10, -8, 0), to: SIMD3(10, -8, 0))!,
      Wire.arc(start: SIMD3(10, -8, 0), midpoint: SIMD3(18, 0, 0), end: SIMD3(10, 8, 0))!,
      Wire.line(from: SIMD3(10, 8, 0), to: SIMD3(-10, 8, 0))!,
      Wire.arc(start: SIMD3(-10, 8, 0), midpoint: SIMD3(-18, 0, 0), end: SIMD3(-10, -8, 0))!,
  ])!
  let slot = Shape.face(from: profile)!.extruded(by: SIMD3(0, 0, 20))!
  let rim = slot.edges()
  slot.filletEvolving([
      EvolvingFilletEdge(edge: rim[3], radiusPoints: [(0.0, 1.0), (1.0, 3.0)]),
      EvolvingFilletEdge(edge: rim[6], radiusPoints: [(0.0, 5.0), (1.0, 5.0)]),
  ])
  ```

---

### `filletEvolvingWithReport(_:)`

`filletEvolving(_:)`, also reporting which requested edges OCCT declined (#639): the entry point
the Cluster B census named directly. Filleting an open shell's whole edge list skips the edges OCCT
declines, with nothing that says which or how many.

```swift
public func filletEvolvingWithReport(_ edges: [EvolvingFilletEdge]) -> FilletResult?
```

- **Parameters:** same as `filletEvolving(_:)`.
- **Returns:** a [`Shape.FilletResult`](Shape-Features#shapefilletresult), or `nil` on failure under
  the same conditions as `filletEvolving(_:)`. `declinedEdgeIndices` is keyed by
  `EvolvingFilletEdge.edgeIndex`.
- **OCCT:** `BRepFilletAPI_MakeFillet` with evolving law (via `OCCTShapeFilletEvolving`), reading
  `Contour(edge)` for each requested edge after `Add()` and before `Build()`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  let faces = box.faces().dropFirst().compactMap { Shape.fromFace($0) }
  let shell = Shape.sew(shapes: Array(faces))!
  let laws = shell.edges().map { EvolvingFilletEdge(edge: $0, radiusPoints: [(0.0, 1.0), (1.0, 1.0)]) }
  if let report = shell.filletEvolvingWithReport(laws) {
      print(report.declinedEdgeIndices.count, "of", laws.count, "edges declined")
  }
  ```

---

## Per-Face Variable Offset (v0.38.0)

### `offsetPerFace(defaultOffset:faceOffsets:tolerance:joinType:)`

Offset a shape with different distances per face.

```swift
public func offsetPerFace(defaultOffset: Double,
                           faceOffsets: [Int: Double],
                           tolerance: Double = 1e-3,
                           joinType: OffsetJoinType = .arc) -> Shape?
```

- **Parameters:**
  - `defaultOffset` — Default offset distance applied to all faces not listed in `faceOffsets`.
  - `faceOffsets` — Dictionary mapping 0-based face indices — as `Face.index` and `face(at:)` use —
    to custom offset distances. A key outside `0..<faceCount` fails the call.
  - `tolerance` — Offset tolerance.
  - `joinType` — Join strategy for offset gaps (`.arc` or `.intersection`).
- **Returns:** Offset shape, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakeThickSolid` (via `OCCTShapeOffsetPerFace`).
- **Example:**
  ```swift
  if let result = solid.offsetPerFace(defaultOffset: 1.0,
                                       faceOffsets: [0: 2.0, 2: 0.5]) {
      print(result.isValid)
  }
  ```
- **Note:** #541 moved the keys off 1-based, and made an out-of-range key fail the call. It used to
  be skipped, which returned a shape offset by the default everywhere and looked exactly like a
  successful run — the same silent success #497 fixed for defeaturing.

---

## Free Boundary Analysis (v0.39.0)

### `FreeBoundsResult`

Result of free boundary analysis.

```swift
public struct FreeBoundsResult: Sendable {
    public let wires: Shape
    public let closedCount: Int
    public let openCount: Int
}
```

- `wires` — Compound shape containing all free boundary wires.
- `closedCount` — Number of closed free boundary wires.
- `openCount` — Number of open free boundary wires.

---

### `freeBounds(sewingTolerance:)`

Analyze free boundary wires (open edges not shared by two faces).

```swift
public func freeBounds(sewingTolerance: Double = 1e-6) -> FreeBoundsResult?
```

Free boundaries indicate gaps in a shell. A watertight shell has no free boundaries.

- **Note:** Unlike `Shape.sectionWiresAtZ(_:tolerance:)`, this method is unaffected by OCCT 8.0.1's `ConnectEdgesToWires` INTERNAL/EXTERNAL skip (OCCT#1408). This method's constructor does reach that same skip, in its own chainage step, so the reason is not that the call graph avoids it. What keeps the result unchanged is upstream: the edges this method feeds in come from `BRepBuilderAPI_Sewing::FreeEdge`, and in every case measured that sewing stage never produced an `.internal`/`.external` free edge for the skip to act on.

  `freeBoundsClosedCount(tolerance:)`, `freeBoundsClosedWires(tolerance:)` and `freeBoundsOpenWires(tolerance:)` share this reasoning unconditionally: each always builds `ShapeAnalysis_FreeBounds` with the `(shape, tolerance, ...)` sewing constructor no matter what value is passed, so there is no other branch to consider for them.

  `freeBoundsAnalysis(tolerance:)`, [`FreeBoundsProperties`](Document-Mesh-Fixing.md#freeboundsproperties) and the four accessors built on it (`closedFreeBoundInfo(tolerance:index:)`, `openFreeBoundInfo(tolerance:index:)`, `closedFreeBoundWire(tolerance:index:)`, `openFreeBoundWire(tolerance:index:)`) are different: `ShapeAnalysis_FreeBoundsProperties::DispatchBounds()` picks the sewing constructor only when its tolerance is greater than 0; at 0 or below it picks `ShapeAnalysis_FreeBounds(shape, splitClosed, splitOpen)` instead, a constructor with no sewing stage at all, which takes its edges from `ShapeAnalysis_Shell::CheckOrientedShells`/`FreeEdges()` and reaches the same `ConnectEdgesToWires` skip by a different route. This is measured directly, not assumed from the sewing case above: the `.internal` exclusion holds on this branch too, and a FORWARD control on the same fixture confirms the two branches are not just trivially agreeing on everything. The sewing branch chains a FORWARD loop entirely inside one face into one closed wire together with that face's outer boundary (3 closed, 0 open); the shared-topology branch returns the same loop's four edges unchained (2 closed, 4 open). What is not measured, and not claimed, is *why* the INTERNAL loop is absent on the shared-topology branch: that constructor defaults `checkinternaledges` to `false`, so the internal edges may never reach `FreeEdges()` as candidates at all, rather than being collected and then dropped by the same skip the sewing branch's chainage step hits. Both would produce the same observable result, which is the only thing measured here. See `Issue655FreeBoundsInternalOrientationTests` (`OCCTShapeHealingTests`) for both fixtures. See [#655](https://github.com/SecondMouseAU/OCCTSwift/issues/655).
- **Parameters:** `sewingTolerance` — Tolerance for grouping free edges into wires.
- **Returns:** Free bounds result, or `nil` if no free boundaries are found.
- **OCCT:** `ShapeAnalysis_FreeBounds`.
- **Example:**
  ```swift
  if let fb = shell.freeBounds() {
      print("open gaps: \(fb.openCount)")
  }
  ```

---

### `fixedFreeBounds(sewingTolerance:closingTolerance:)`

Fix free boundary wires by closing gaps.

```swift
public func fixedFreeBounds(sewingTolerance: Double = 1e-6,
                             closingTolerance: Double = 1e-4) -> (shape: Shape, fixedCount: Int)?
```

- **Parameters:**
  - `sewingTolerance` — Tolerance for sewing free edges.
  - `closingTolerance` — Maximum distance to close a gap.
- **Returns:** Tuple of `(fixed shape, number of wires fixed)`, or `nil` on failure.
- **OCCT:** `ShapeFix_Shape` / `ShapeAnalysis_FreeBounds` (via `OCCTShapeFixFreeBounds`).

---

## Pipe Feature (v0.39.0)

### `pipeFeature(profile:sketchFaceIndex:spine:fuse:)`

Create a pipe feature by sweeping a profile along a spine, fused with or cut from this shape.

```swift
public func pipeFeature(profile: Shape, sketchFaceIndex: Int,
                        spine: Wire, fuse: Bool = true) -> Shape?
```

- **Parameters:**
  - `profile` — Profile shape (face) to sweep along the spine.
  - `sketchFaceIndex` — 0-based index of the face on this shape where the profile sits.
  - `spine` — Wire defining the sweep path.
  - `fuse` — If `true`, adds material; if `false`, removes material.
- **Returns:** Modified shape, or `nil` on failure.
- **OCCT:** `BRepFeat_MakePipe` (via `OCCTShapePipeFeatureFromProfile`).

---

## Semi-Infinite Extrusion (v0.39.0)

### `extrudedSemiInfinite(direction:infinite:)`

Extrude a shape semi-infinitely in a direction.

```swift
public func extrudedSemiInfinite(direction: SIMD3<Double>, infinite: Bool = false) -> Shape?
```

Creates a solid that extends infinitely in one direction from the profile. Useful for half-spaces and trimming operations.

- **Parameters:**
  - `direction` — Direction of extrusion.
  - `infinite` — If `true`, extrude in both directions (fully infinite); if `false`, extrude in one direction (semi-infinite).
- **Returns:** Extruded shape, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeHalfSpace` / `BRepBuilderAPI_MakeSolid` (via `OCCTShapeExtrudeSemiInfinite`).

---

## Prism Until Face (v0.39.0)

### `prismUntilFace(profile:sketchFaceIndex:direction:fuse:untilFaceIndex:)`

Extrude a profile until it reaches a target face, with automatic fuse/cut.

```swift
public func prismUntilFace(profile: Shape, sketchFaceIndex: Int,
                           direction: SIMD3<Double>, fuse: Bool = true,
                           untilFaceIndex: Int? = nil) -> Shape?
```

Uses `BRepFeat_MakePrism` which handles the until-face computation more robustly than a simple extrusion + Boolean.

- **Parameters:**
  - `profile` — Profile face to extrude.
  - `sketchFaceIndex` — 0-based face index on this shape where the profile sits.
  - `direction` — Extrusion direction.
  - `fuse` — If `true`, adds material; if `false`, removes material.
  - `untilFaceIndex` — 0-based face index on this shape where extrusion stops. Pass `nil` for thru-all.
- **Returns:** Modified shape, or `nil` on failure.
- **OCCT:** `BRepFeat_MakePrism` (via `OCCTShapePrismUntilFace`).

---

## Inertia Properties (v0.40.0)

### `InertiaProperties`

Volume-based (or surface-area-based) inertia properties.

```swift
public struct InertiaProperties {
    public let mass: Double
    public let centerOfMass: SIMD3<Double>
    public let inertiaMatrix: [Double]
    public let principalMoments: SIMD3<Double>
    public let principalAxes: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)
    public let hasSymmetryAxis: Bool
    public let hasSymmetryPoint: Bool
}
```

- `mass` — Volume (for `inertiaProperties()`) or surface area (for `surfaceInertiaProperties()`).
- `inertiaMatrix` — 9-element row-major 3×3 inertia tensor `[Ixx, Ixy, Ixz, Iyx, Iyy, Iyz, Izx, Izy, Izz]`.
- `principalAxes` — Three unit vectors for the principal axes of inertia.

---

#### `InertiaProperties.inertiaMatrix`

9-element row-major 3x3 inertia tensor `[Ixx, Ixy, Ixz, Iyx, Iyy, Iyz, Izx, Izy, Izz]`, taken about the center of mass.

#### `InertiaProperties.principalMoments`

The three principal moments of inertia (`Ixx`, `Iyy`, `Izz` of `GProp_PrincipalProps::Moments`) in the principal-axis frame.

#### `InertiaProperties.hasSymmetryAxis`

`true` when the shape has an axis of symmetry (`GProp_PrincipalProps::HasSymmetryAxis`, checked to relative tolerance `1e-10`). When it does, the second and third principal axes are undefined: any axis through the center of mass parallel to a combination of those two eigenvectors is equally a principal axis.

#### `InertiaProperties.hasSymmetryPoint`

`true` when the shape has a point of symmetry (`GProp_PrincipalProps::HasSymmetryPoint`, checked to relative tolerance `1e-10`). When it does, every axis through the center of mass is a principal axis.

---

### `inertiaProperties()`

Compute volume-based inertia properties.

```swift
public func inertiaProperties() -> InertiaProperties?
```

- **Returns:** Inertia properties, or `nil` when the shape has no closed volume (a face, wire, edge,
  vertex or open shell) or computation fails.
- **OCCT:** `BRepGProp::VolumeProperties` with `OnlyClosed = true` plus a `Mass()` test (via
  `OCCTShapeInertiaProperties`).
- **Every field is an artefact outside the volume domain, not merely a zero** (#609): the centre of
  mass is the shape's location origin, the principal axes are the identity basis that `math_Jacobi`
  returns for a zero matrix, and both symmetry flags read `true` because all three moments are equal
  at zero. Use `surfaceInertiaProperties()` for a sheet body.
- **Example:**
  ```swift
  if let props = solid.inertiaProperties() {
      print("volume: \(props.mass)")
      print("center of mass: \(props.centerOfMass)")
  }
  ```

---

### `surfaceInertiaProperties()`

Compute surface-area-based inertia properties.

```swift
public func surfaceInertiaProperties() -> InertiaProperties?
```

The `mass` field contains total surface area rather than volume.

- **Returns:** Inertia properties, or `nil` when the shape has no faces (a wire, edge or vertex) or
  computation fails. Unlike the volume sibling this answers for a face or an open shell, since an
  area integral is well defined over any set of faces.
- **OCCT:** `BRepGProp::SurfaceProperties` plus a `Mass()` test (via
  `OCCTShapeSurfaceInertiaProperties`).

---

## Extended Distance (v0.40.0)

### `DistanceSolution`

A closest-point solution between two shapes.

```swift
public struct DistanceSolution {
    public let point1: SIMD3<Double>
    public let point2: SIMD3<Double>
    public let distance: Double
}
```

| Field | Meaning |
|---|---|
| `point1` | Closest point on the first shape (`self`) for this solution. |
| `point2` | Closest point on the second shape (`other`) for this solution. |
| `distance` | Distance between `point1` and `point2`. |

*(Per-field anchors below, for cross-reference; the table above has the actual meaning of each.)*

#### `point2`

---

### `allDistanceSolutions(to:maxSolutions:)`

Compute all distance extrema solutions between this shape and another.

```swift
public func allDistanceSolutions(to other: Shape, maxSolutions: Int = 32) -> [DistanceSolution]?
```

Returns all extremal point pairs (not just the minimum). Useful for finding multiple closest/farthest point pairs.

- **Parameters:**
  - `other` — The other shape.
  - `maxSolutions` — Output *capacity*, clamped into `0...Sampling.maximumSampleCount`
    (10,000,000); 0 or less returns an empty array — **not** `nil`, as it did before #622 (#622).
- **Returns:** Array of distance solutions, or `nil` on failure.
- **OCCT:** `BRepExtrema_DistShapeShape` (via `OCCTShapeAllDistanceSolutions`).
- **Example:**
  ```swift
  if let solutions = shapeA.allDistanceSolutions(to: shapeB) {
      let min = solutions.min(by: { $0.distance < $1.distance })
      print("minimum distance: \(min?.distance ?? 0)")
  }
  ```

---

### `isInside(_:)`

Check if this shape is fully contained inside another shape.

```swift
public func isInside(_ container: Shape) -> Bool?
```

- **Parameters:** `container` — The potential container shape.
- **Returns:** `true` if this shape is inside the container; `nil` on failure.
- **OCCT:** `BRepExtrema_DistShapeShape` inner solution detection (via `OCCTShapeIsInnerDistance`).

---

### `DistanceSupportType`

Support type for a distance solution point.

```swift
public enum DistanceSupportType: Int32, Sendable {
    case vertex = 0
    case onEdge = 1
    case inFace = 2
}
```

---

#### `DistanceSupportType.onEdge`

The solution point lies on the interior of an edge (not at a vertex).

#### `DistanceSupportType.inFace`

The solution point lies on the interior of a face (not on its boundary).

---

### `DistanceSolutionDetail`

Detailed parametric info for a distance solution.

```swift
public struct DistanceSolutionDetail: Sendable {
    public let supportType1: DistanceSupportType
    public let supportType2: DistanceSupportType
    public let paramEdge1: Double
    public let paramEdge2: Double
    public let paramFaceUV1: (u: Double, v: Double)
    public let paramFaceUV2: (u: Double, v: Double)
}
```

| Field | Meaning |
|---|---|
| `paramEdge1` | Curve parameter of the closest point on `self`'s support, when `supportType1 == .onEdge`; meaningless otherwise. |
| `paramEdge2` | Curve parameter of the closest point on `other`'s support, when `supportType2 == .onEdge`; meaningless otherwise. |
| `paramFaceUV1` | Surface UV parameters of the closest point on `self`'s support, when `supportType1 == .inFace`; meaningless otherwise. |
| `paramFaceUV2` | Surface UV parameters of the closest point on `other`'s support, when `supportType2 == .inFace`; meaningless otherwise. |

#### `Shape.DistanceSolutionDetail.paramFaceUV2`

---

### `distanceSolutionDetail(to:solutionIndex:)`

Get detailed parametric info for a specific distance solution.

```swift
public func distanceSolutionDetail(to other: Shape, solutionIndex: Int) -> DistanceSolutionDetail?
```

Returns the support type (vertex/edge/face) and parametric location for each closest point. Use in conjunction with `allDistanceSolutions(to:)` to obtain the solution index.

- **Parameters:**
  - `other` — The other shape.
  - `solutionIndex` — 0-based index into the solutions returned by `allDistanceSolutions(to:)`.
- **Returns:** Detail struct, or `nil` on failure.
- **OCCT:** `BRepExtrema_DistShapeShape` (via `OCCTShapeDistanceSolutionDetail`).

---

## Find Surface (v0.40.0)

### `findSurfaceEx(tolerance:onlyPlane:)`

Find the underlying geometric surface shared by a shape's edges.

```swift
public func findSurfaceEx(tolerance: Double = 1e-6, onlyPlane: Bool = false) -> Surface?
```

Analyzes the edges of a shape to determine if they lie on a common geometric surface.

- **Parameters:**
  - `tolerance` — Tolerance for surface detection.
  - `onlyPlane` — If `true`, only look for planar surfaces.
- **Returns:** The underlying surface, or `nil` if none found.
- **OCCT:** `BRepLib_FindSurface` (via `OCCTShapeFindSurfaceEx`).
- **Example:**
  ```swift
  if let surf = wire.findSurfaceEx(onlyPlane: true) {
      print(surf.surfaceKind)  // .plane
  }
  ```

---

## Shape Surgery (v0.41.0)

### `removingSubShapes(_:)`

Remove sub-shapes from this shape surgically.

```swift
public func removingSubShapes(_ subShapes: [Shape]) -> Shape?
```

Uses `BRepTools_ReShape` to remove faces, edges, or vertices while preserving the remaining topology.

- **Parameters:** `subShapes` — Sub-shapes to remove.
- **Returns:** Shape with sub-shapes removed, or `nil` on failure.
- **OCCT:** `BRepTools_ReShape` (via `OCCTShapeRemoveSubShapes`).

---

### `replacingSubShapes(_:)`

Replace sub-shapes within this shape.

```swift
public func replacingSubShapes(_ replacements: [(old: Shape, new: Shape)]) -> Shape?
```

- **Parameters:** `replacements` — Array of `(old, new)` shape pairs.
- **Returns:** Shape with replacements applied, or `nil` on failure.
- **OCCT:** `BRepTools_ReShape` (via `OCCTShapeReplaceSubShapes`).

---

## Plane Detection (v0.41.0)

### `DetectedPlane`

Result of plane detection.

```swift
public struct DetectedPlane {
    public let normal: SIMD3<Double>
    public let origin: SIMD3<Double>
}
```

---

### `findPlane(tolerance:)`

Find if this shape's edges lie in a plane.

```swift
public func findPlane(tolerance: Double = 1e-6) -> DetectedPlane?
```

- **Parameters:** `tolerance` — Tolerance for planarity check.
- **Returns:** Detected plane, or `nil` if the shape is not planar.
- **OCCT:** `BRepBuilderAPI_FindPlane` (via `OCCTShapeFindPlane`).
- **Example:**
  ```swift
  if let plane = wire.findPlane() {
      print("normal: \(plane.normal)")
  }
  ```

---

## Closed Edge Splitting (v0.41.0)

### `dividedClosedEdges(splitPoints:)`

Split closed (periodic) edges in the shape.

```swift
public func dividedClosedEdges(splitPoints: Int = 1) -> Shape?
```

Periodic edges (like circles) can cause issues in some algorithms. This splits each closed edge into segments.

- **Parameters:** `splitPoints` — Number of split points per closed edge (default `1`, which doubles the edge count).
- **Returns:** Shape with closed edges split, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_ShapeDivideAngle` / `BRep_Builder` (via `OCCTShapeDivideClosedEdges`).

---

## Geometry Conversion (v0.41.0)

### `withSurfacesAsBSpline(extrusion:revolution:offset:plane:)`

Convert all surfaces to BSpline form.

```swift
public func withSurfacesAsBSpline(extrusion: Bool = true, revolution: Bool = true,
                                   offset: Bool = true, plane: Bool = false) -> Shape?
```

- **Parameters:**
  - `extrusion` — Convert extrusion surfaces (default `true`).
  - `revolution` — Convert revolution surfaces (default `true`).
  - `offset` — Convert offset surfaces (default `true`).
  - `plane` — Convert planar surfaces (default `false`).
- **Returns:** Shape with converted surfaces, or `nil` on failure.
- **OCCT:** `ShapeCustom::ConvertToBSpline` (via `OCCTShapeCustomConvertToBSpline`).

---

### `withSurfacesAsRevolution()`

Convert surfaces to revolution form where possible.

```swift
public func withSurfacesAsRevolution() -> Shape?
```

- **Returns:** Shape with surfaces converted to surfaces of revolution, or `nil` on failure.
- **OCCT:** `ShapeCustom::ConvertToRevolution` (via `OCCTShapeCustomConvertToRevolution`).

---

## Face Restriction (v0.41.0)

### `faceRestricted(by:)`

Create restricted faces from a face and wire boundaries.

```swift
public func faceRestricted(by boundaries: [Wire]) -> [Shape]?
```

Uses `BRepAlgo_FaceRestrictor` to build faces on the underlying surface of this shape's first face, bounded by the given wires.

- **Parameters:** `boundaries` — Wire boundaries that define the restricted regions.
- **Returns:** Array of restricted face shapes (up to 64), or `nil` on failure.
- **OCCT:** `BRepAlgo_FaceRestrictor` (via `OCCTShapeFaceRestrict`).

---

## Solid Construction, 2D Fillet and Point Cloud (v0.42.0)

### `solidFromShells(_:)`

Create a solid from one or more shell shapes.

```swift
public static func solidFromShells(_ shells: [Shape]) -> Shape?
```

The first shape provides the outer shell; additional shapes provide cavity (inner) shells.

- **Parameters:** `shells` — Array of shapes containing shells; must not be empty.
- **Returns:** Solid shape, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_MakeSolid` (via `OCCTSolidFromShells`).
- **Note:** Each element contributes only the **first** shell found in it, so pass one shape per
  shell rather than a compound of several. An element holding no shell is skipped silently,
  except the first, which fails the whole call. (#443 audit)
- **Example:**
  ```swift
  if let solid = Shape.solidFromShells([outerShell, innerShell]) {
      print(solid.isValid)
  }
  ```

---

### `fillet2D(vertexIndices:radii:)`

Apply 2D fillets (rounded corners) to a planar face at specified vertices.

```swift
public func fillet2D(vertexIndices: [Int], radii: [Double]) -> Shape?
```

- **Parameters:**
  - `vertexIndices` — 0-based indices of vertices to fillet.
  - `radii` — Fillet radius for each vertex; must match `vertexIndices` count.
- **Returns:** Modified shape with fillets, or `nil` on failure.
- **OCCT:** `BRepFilletAPI_MakeFillet2d` (via `OCCTFace2DFillet`).
- **Note:** `vertexIndices` and `radii` must have equal length; mismatch returns `nil`.
- **Note:** Only the **first** face of the receiver is filleted, and the result is that face
  alone; the other faces of a multi-face shape are neither filleted nor carried through. Vertex
  indices are numbered within that first face. Call this on one face at a time. (#443 audit)
- **Note:** an index naming no vertex of that first face fails the whole call rather than being
  skipped (#568); previously it was dropped and the corners that did resolve were rounded, reported
  as a complete result.

---

### `chamfer2D(edgePairs:distances:)`

Apply 2D chamfers (angled cuts) to a planar face between adjacent edge pairs.

```swift
public func chamfer2D(edgePairs: [(Int, Int)], distances: [Double]) -> Shape?
```

- **Parameters:**
  - `edgePairs` — Array of `(edge1Index, edge2Index)` pairs (0-based) identifying adjacent edges.
  - `distances` — Chamfer distance for each edge pair.
- **Returns:** Modified shape with chamfers, or `nil` on failure.
- **OCCT:** `BRepFilletAPI_MakeFillet2d` (via `OCCTFace2DChamfer`).
- **Note:** Only the **first** face of the receiver is chamfered, and the result is that face
  alone; the other faces of a multi-face shape are neither chamfered nor carried through. Edge
  indices are numbered within that first face. Call this on one face at a time. (#443 audit)
- **Note:** *either* half of a pair naming no edge of that first face fails the whole call rather
  than being skipped (#568); previously the pair was dropped and the corners that did resolve were
  cut, reported as a complete result.
- **Note:** the same edge pair named twice fails the whole call rather than crashing (#705); this
  is an upstream OCCT defect in `BRepFilletAPI_MakeFillet2d::AddChamfer`, not this wrapper's own.
  The pair's second call finds its shared vertex already consumed by the first chamfer, and the
  resulting failure returns two null edges that `AddChamfer` dereferences without checking for
  first, and the process SIGSEGV'd, uncatchably, before this guard existed. The check is order
  independent, so `(0, 1)` and `(1, 0)` both name the refused pair; reusing one edge across two
  *different* pairs (chamfering every corner of a rectangle) is unaffected.

---

### `PointCloudGeometry`

Classification of a point cloud's geometric arrangement.

```swift
public enum PointCloudGeometry {
    case point(SIMD3<Double>)
    case linear(origin: SIMD3<Double>, direction: SIMD3<Double>)
    case planar(origin: SIMD3<Double>, normal: SIMD3<Double>)
    case space
}
```

- `.point` — All points are coincident.
- `.linear` — Points are collinear.
- `.planar` — Points are coplanar.
- `.space` — Points are dispersed in 3D space.

---

#### `Shape.PointCloudGeometry.space`

---

### `analyzePointCloud(_:tolerance:)`

Analyze a set of 3D points to determine their geometric arrangement.

```swift
public static func analyzePointCloud(_ points: [SIMD3<Double>], tolerance: Double = 1e-6) -> PointCloudGeometry?
```

- **Parameters:**
  - `points` — Array of 3D points (minimum 1).
  - `tolerance` — Tolerance for classification.
- **Returns:** Classification result, or `nil` on failure.
- **OCCT:** `GProp_PEquation` (via `OCCTAnalyzePointCloud`).
- **Example:**
  ```swift
  let pts: [SIMD3<Double>] = [.init(0,0,0), .init(1,0,0), .init(2,0,0)]
  if case .linear(let o, let d) = Shape.analyzePointCloud(pts) {
      print("line direction: \(d)")
  }
  ```

---

## Face Subdivision (v0.43.0)

### `dividedByArea(maxArea:)`

Subdivide faces whose area exceeds a maximum threshold.

```swift
public func dividedByArea(maxArea: Double) -> Shape?
```

- **Parameters:** `maxArea` — Maximum face area; faces larger than this are split.
- **Returns:** Shape with subdivided faces, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_ShapeDivideArea` (via `OCCTShapeDivideByArea`).

---

### `dividedByParts(_:)`

Subdivide faces into a target number of parts.

```swift
public func dividedByParts(_ parts: Int) -> Shape?
```

- **Parameters:** `parts` — Target number of parts per face.
- **Returns:** Shape with subdivided faces, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_ShapeDivideArea` in splitting-by-number mode (via `OCCTShapeDivideByParts`).

---

### `SmallFaceInfo`

Result of small/degenerate face analysis.

```swift
public struct SmallFaceInfo: Sendable {
    public let isSpotFace: Bool
    public let isStripFace: Bool
    public let isTwisted: Bool
    public let spotLocation: SIMD3<Double>?
}
```

- `isSpotFace` — Face collapsed to a point.
- `isStripFace` — Face with negligible width.
- `isTwisted` — Face with twisted geometry.
- `spotLocation` — Location of a spot face (only set when `isSpotFace` is `true`).

---

#### `SmallFaceInfo.isSpotFace`

`true` when the face has collapsed to a point.

#### `SmallFaceInfo.isStripFace`

`true` when the face has negligible width (a thin sliver).

#### `SmallFaceInfo.isTwisted`

`true` when the face's geometry is twisted.

#### `SmallFaceInfo.spotLocation`

Location of a spot face; only set when `isSpotFace` is `true`.

---

### `checkSmallFaces(tolerance:)`

Check faces for degenerate conditions (spot, strip, twisted).

```swift
public func checkSmallFaces(tolerance: Double = 1e-6) -> [SmallFaceInfo]
```

Returns only faces that have at least one degenerate condition.

- **Parameters:** `tolerance` — Analysis tolerance.
- **Returns:** Array of degenerate face descriptions; empty if none found.
- **OCCT:** `ShapeAnalysis_CheckSmallFace` (via `OCCTShapeCheckSmallFaces`).

---

### `purgedLocations`

Purge problematic location datums from the shape.

```swift
public var purgedLocations: Shape? { get }
```

Removes negative-scale and non-unit-scale transforms from the shape and all sub-shapes. Useful for cleaning imported geometry from STEP/IGES files.

- **Returns:** Cleaned shape, or `nil` if purge was unnecessary or failed.
- **OCCT:** `BRepLib::SameParameter` / transform purge (via `OCCTShapePurgeLocations`).

---

## Curve-on-Surface Check

### `CurveOnSurfaceCheck`

Result of a curve-on-surface consistency check.

```swift
public struct CurveOnSurfaceCheck {
    public let maxDistance: Double
    public let maxParameter: Double
}
```

| Field | Meaning |
|---|---|
| `maxDistance` | Maximum deviation found between a 3D edge curve and its pcurve on the face. |
| `maxParameter` | Curve parameter at which that maximum deviation occurs. |

*(Per-field anchors below, for cross-reference; the table above has the actual meaning of each.)*

#### `maxParameter`

---

### `curveOnSurfaceCheck`

Check edge-on-surface consistency.

```swift
public var curveOnSurfaceCheck: CurveOnSurfaceCheck? { get }
```

Examines all edge-face pairs in the shape and reports the maximum deviation between each edge's 3D curve and its parametric curve (pcurve) on the face surface.

- **Returns:** Check result, or `nil` if the check fails.
- **OCCT:** `BRep_Tool::CurveOnSurface` / `ShapeAnalysis_Edge` (via `OCCTShapeCheckCurveOnSurface`).

---

## Edge Connection

### `connectedEdges`

Connect edges by merging shared vertices in the shape.

```swift
public var connectedEdges: Shape? { get }
```

Identifies edges that share geometric positions and merges their vertices. Useful for healing imported geometry where topologically disconnected edges actually meet at the same point.

- **Returns:** Shape with connected edges, or `nil` on failure.
- **OCCT:** `ShapeFix_EdgeConnect` (via `OCCTShapeConnectEdges`).

---

## Self-Intersection Detection (v0.45.0)

### `SelfIntersectionResult`

Result of a self-intersection check.

```swift
public struct SelfIntersectionResult: Sendable {
    public let overlapCount: Int
    public let isDone: Bool
}
```

| Field | Meaning |
|---|---|
| `overlapCount` | Number of overlapping triangle pairs found between BVH-accelerated mesh triangles. |
| `isDone` | `true` if the check completed; `false` if the underlying mesh/BVH computation failed. |

#### `Shape.SelfIntersectionResult.overlapCount`

---

### `selfIntersection(tolerance:meshDeflection:)`

Check the shape for self-intersection using BVH-accelerated triangle mesh overlap.

```swift
public func selfIntersection(tolerance: Double = 0.001,
                              meshDeflection: Double = 0.5) -> SelfIntersectionResult?
```

Meshes the shape and detects overlapping triangle pairs.

- **Parameters:**
  - `tolerance` — Tolerance for detecting intersections.
  - `meshDeflection` — Mesh deflection for triangulation.
- **Returns:** Self-intersection result, or `nil` if the check failed.
- **OCCT:** `BRepExtrema_SelfIntersection` (via `OCCTShapeSelfIntersection`).
- **Example:**
  ```swift
  if let si = shape.selfIntersection() {
      print("overlapping pairs: \(si.overlapCount)")
  }
  ```

---

## Bezier Conversion

### `convertedToBezier`

Convert all curves and surfaces in the shape to Bezier representations.

```swift
public var convertedToBezier: Shape? { get }
```

Replaces BSpline curves and surfaces with their Bezier equivalents. Converts 2D/3D curves, surfaces, lines, circles, conics, planes, revolutions, extrusions, and BSpline entities.

- **Returns:** Shape with Bezier geometry, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_ShapeConvertToBezier` (via `OCCTShapeConvertToBezier`).

---

## Edge Concavity Analysis (v0.46.0)

### `EdgeConcavity`

Edge concavity type from `BRepOffset_Analyse`.

```swift
public enum EdgeConcavity: Sendable {
    case convex
    case concave
    case tangent
}
```

| Case | Meaning |
|---|---|
| `convex` | Edge connects two faces at a convex angle (e.g. outer corner of a box). |
| `concave` | Edge connects two faces at a concave angle (e.g. inner corner of a groove). |
| `tangent` | Edge connects two faces with a smooth (tangent) transition. |

*(Per-case anchors below, for cross-reference; the table above has the actual meaning of each.)*

#### `concave`

---

### `edgeConcavities(angle:)`

Classify all edges by their concavity type.

```swift
public func edgeConcavities(angle: Double = 0.01) -> [(Edge, EdgeConcavity)]?
```

Analyzes the angles between adjacent faces at each edge.

One entry per **distinct** edge, in `edges()` order, so `result[n].0.index == n` and the
classification at position `n` describes `edges()[n]`:

```swift
for (edge, kind) in bracket.edgeConcavities() ?? [] where kind == .concave {
    print("inside corner at edge \(edge.index), length \(edge.length)")
}
```

- **Parameters:** `angle` — Threshold angle (radians) for tangent classification.
- **Returns:** Array of `(edge, concavity)` pairs in `edges()` order, or `nil` on error.
- **OCCT:** `BRepOffset_Analyse` (via `OCCTShapeAnalyzeEdgeConcavity`).
- **Changed in #613:** the bridge enumerated topology *occurrences* (24 on a 12-edge box) while
  Swift zipped the result against `edges()`, so every label past the first repeat landed on the
  wrong edge. On an L-bracket the one concave edge was labelled convex and `concaveEdges()`
  returned `[]`.

---

### `edgeConcavityCount(_:angle:)`

Count edges of a specific concavity type.

```swift
public func edgeConcavityCount(_ type: EdgeConcavity, angle: Double = 0.01) -> Int?
```

Counts distinct edges, so the three type counts sum to at most `edgeCount`:

```swift
let box = Shape.box(width: 10, height: 10, depth: 10)!
box.edgeConcavityCount(.convex)   // 12, matching box.edgeCount
```

- **Parameters:**
  - `type` — Concavity type to count.
  - `angle` — Threshold angle (radians) for tangent classification.
- **Returns:** Count of matching edges, or `nil` on error.
- **OCCT:** `BRepOffset_Analyse` (via `OCCTShapeCountEdgeConcavity`).
- **Changed in #613:** counted topology occurrences, so a 12-edge box reported **24** convex edges.

---

## Geometric Edge Selection (v1.2.1)

### `edges(where:)`

Select edges of this shape that satisfy a geometric predicate.

```swift
public func edges(where predicate: (Edge) -> Bool) -> [Edge]
```

A robust alternative to picking edges by raw index from `edges()` — the index shifts when model parameters change, whereas a geometric predicate keeps selecting the right edge.

- **Parameters:** `predicate` — Returns `true` for edges to keep.
- **Returns:** The matching edges (possibly empty), each with a valid index.
- **Example:**
  ```swift
  // Round only long edges (> 50 mm)
  let targets = bracket.edges { $0.length > 50 }
  let rounded = bracket.filleted(edges: targets, radius: 2)
  ```

---

### `concaveEdges(angle:)`

The concave edges of this solid (interior angle > 180°).

```swift
public func concaveEdges(angle: Double = 0.01) -> [Edge]
```

Concave edges are typically the ones you want to fillet to add material to an inside corner.

- **Parameters:** `angle` — Threshold (radians) below which an edge counts as tangent rather than concave.
- **Returns:** The concave edges, or an empty array if none or on error.
- **Example:**
  ```swift
  let rounded = bracket.filleted(edges: bracket.concaveEdges(), radius: 3)
  ```

---

### `convexEdges(angle:)`

The convex edges of this solid (interior angle < 180°).

```swift
public func convexEdges(angle: Double = 0.01) -> [Edge]
```

Convex edges are the outer corners of a part, typically the ones you want to chamfer or round.

- **Parameters:** `angle` — Threshold (radians) below which an edge counts as tangent rather than convex.
- **Returns:** The convex edges, or an empty array if none or on error.

---

### `edges(parallelTo:tolerance:)`

Select straight edges whose direction is parallel to a given axis.

```swift
public func edges(parallelTo axis: SIMD3<Double>, tolerance: Double = 1e-4) -> [Edge]
```

Only line edges are considered (curved edges have no single direction). The test is sign-agnostic: edges pointing along `+axis` or `-axis` both match.

- **Parameters:**
  - `axis` — The reference direction (need not be unit length).
  - `tolerance` — Maximum sine of the angle between edge and axis.
- **Returns:** The matching straight edges, each with a valid index.
- **Example:**
  ```swift
  // Round every vertical edge of an extruded prism
  let verticals = part.edges(parallelTo: SIMD3(0, 0, 1))
  let rounded = part.filleted(edges: verticals, radius: 2)
  ```

---

### `edges(inBounds:_:)`

Select edges fully contained within an axis-aligned bounding region.

```swift
public func edges(inBounds min: SIMD3<Double>, _ max: SIMD3<Double>) -> [Edge]
```

An edge matches when its entire bounding box lies inside the box spanned by `min...max` (inclusive).

- **Parameters:**
  - `min` — Lower corner of the region.
  - `max` — Upper corner of the region.
- **Returns:** The contained edges, each with a valid index.

---

## Local Prism and Volume Inertia (v0.46.0)

### `localPrism(direction:)`

Create a local prism (extrusion) from this shape along a direction.

```swift
public func localPrism(direction: SIMD3<Double>) -> Shape?
```

Uses `LocOpe_Prism` which tracks generated shapes for each input sub-shape.

- **Parameters:** `direction` — Direction and distance of extrusion.
- **Returns:** Extruded shape, or `nil` on failure.
- **OCCT:** `LocOpe_Prism` (via `OCCTLocOpePrism`).

---

### `localPrism(direction:translation:)`

Create a local prism with an additional translation.

```swift
public func localPrism(direction: SIMD3<Double>, translation: SIMD3<Double>) -> Shape?
```

- **Parameters:**
  - `direction` — Primary direction and distance of extrusion.
  - `translation` — Secondary translation vector.
- **Returns:** Extruded shape, or `nil` on failure.
- **OCCT:** `LocOpe_Prism` (via `OCCTLocOpePrismWithTranslation`).

---

### `VolumeInertia`

Volume inertia properties of a solid shape.

```swift
public struct VolumeInertia: Sendable {
    public let volume: Double
    public let centerOfMass: SIMD3<Double>
    public let inertiaTensor: [Double]
    public let principalMoments: SIMD3<Double>
    public let principalAxes: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)
    public let gyrationRadii: SIMD3<Double>
}
```

- `inertiaTensor` — 9-element row-major 3×3 inertia tensor.
- `gyrationRadii` — Radii of gyration about the three principal axes.

---

#### `VolumeInertia.inertiaTensor`

9-element row-major 3x3 inertia tensor, taken about the center of mass.

#### `VolumeInertia.principalMoments`

The three principal moments of inertia in the principal-axis frame.

#### `VolumeInertia.gyrationRadii`

Radii of gyration about the three principal axes (`sqrt(momentOfInertia / mass)` per axis).

---

### `volumeInertia`

Compute volume inertia properties of this shape.

```swift
public var volumeInertia: VolumeInertia? { get }
```

- **Returns:** Volume inertia result, or `nil` when the shape has no closed volume, or on error.
  See `inertiaProperties()` for why every field is an artefact rather than a zero there (#609).
- **OCCT:** `BRepGProp::VolumeProperties` with `OnlyClosed = true` plus a `Mass()` test (via
  `OCCTShapeVolumeInertia`).
- **Example:**
  ```swift
  if let vi = solid.volumeInertia {
      print("volume: \(vi.volume)")
      print("gyration radii: \(vi.gyrationRadii)")
  }
  ```

---

### `SurfaceInertia`

Surface inertia properties of a shape.

```swift
public struct SurfaceInertia: Sendable {
    public let area: Double
    public let centerOfMass: SIMD3<Double>
    public let inertiaTensor: [Double]
    public let principalMoments: SIMD3<Double>
}
```

| Field | Meaning |
|---|---|
| `area` | Total surface area. |
| `centerOfMass` | Centroid of the surface. |
| `inertiaTensor` | 3x3 inertia tensor about `centerOfMass`, row-major (9 values). |
| `principalMoments` | The three principal moments of inertia (eigenvalues of `inertiaTensor`). |

*(Per-field anchors below, for cross-reference; the table above has the actual meaning of each.)*

#### `principalMoments`

---

### `surfaceInertia`

Compute surface (area) inertia properties of this shape.

```swift
public var surfaceInertia: SurfaceInertia? { get }
```

- **Returns:** Surface inertia result, or `nil` when the shape has no faces, or on error (#609).
- **OCCT:** `BRepGProp::SurfaceProperties` plus a `Mass()` test (via `OCCTShapeSurfaceInertia`).

---

## Local Revolution (v0.47.0)

### `localRevolution(axisOrigin:axisDirection:angle:)`

Create a revolved shape by rotating a profile around an axis.

```swift
public func localRevolution(axisOrigin: SIMD3<Double>,
                             axisDirection: SIMD3<Double>,
                             angle: Double) -> Shape?
```

Uses `LocOpe_Revol` for local revolution operations with shape tracking.

- **Parameters:**
  - `axisOrigin` — Origin point of the rotation axis.
  - `axisDirection` — Direction of the rotation axis.
  - `angle` — Rotation angle in radians.
- **Returns:** Revolved shape, or `nil` on failure.
- **OCCT:** `LocOpe_Revol` (via `OCCTLocOpeRevol`).

---

### `localRevolution(axisOrigin:axisDirection:angle:angularOffset:)`

Create a revolved shape with an angular offset.

```swift
public func localRevolution(axisOrigin: SIMD3<Double>,
                             axisDirection: SIMD3<Double>,
                             angle: Double,
                             angularOffset: Double) -> Shape?
```

- **Parameters:**
  - `axisOrigin` — Origin point of the rotation axis.
  - `axisDirection` — Direction of the rotation axis.
  - `angle` — Rotation angle in radians.
  - `angularOffset` — Angular offset for positioning in radians.
- **Returns:** Revolved shape, or `nil` on failure.
- **OCCT:** `LocOpe_Revol` (via `OCCTLocOpeRevolWithOffset`).

---

## Draft Prism (v0.47.0)

These methods are on `Face`, not `Shape`.

### `Face.draftPrism(height1:height2:angle:)`

Create a draft prism (tapered extrusion) from this face.

```swift
public func draftPrism(height1: Double, height2: Double, angle: Double) -> Shape?
```

- **Parameters:**
  - `height1` — First height.
  - `height2` — Second height.
  - `angle` — Draft angle in radians.
- **Returns:** Draft prism shape, or `nil` on failure.
- **OCCT:** `LocOpe_DPrism` (via `OCCTLocOpeDPrism`).

---

### `Face.draftPrism(height:angle:)`

Create a draft prism with a single height.

```swift
public func draftPrism(height: Double, angle: Double) -> Shape?
```

- **Parameters:**
  - `height` — Extrusion height.
  - `angle` — Draft angle in radians.
- **Returns:** Draft prism shape, or `nil` on failure.
- **OCCT:** `LocOpe_DPrism` (via `OCCTLocOpeDPrismSingleHeight`).

---

## Constrained Filling (v0.47.0)

### `ConstrainedFillInfo`

Information about a constrained-fill BSpline surface.

```swift
public struct ConstrainedFillInfo: Sendable {
    public let uDegree: Int
    public let vDegree: Int
    public let uPoles: Int
    public let vPoles: Int
}
```

| Field | Meaning |
|---|---|
| `uDegree` | BSpline degree of the fill surface in the U direction. |
| `vDegree` | BSpline degree of the fill surface in the V direction. |
| `uPoles` | Number of control points (poles) in the U direction. |
| `vPoles` | Number of control points (poles) in the V direction. |

*(Per-field anchors below, for cross-reference; the table above has the actual meaning of each.)*

#### `vPoles`

---

### `constrainedFill(edge1:edge2:edge3:edge4:maxDegree:maxSegments:)`

Create a surface by filling a region bounded by 3 or 4 edge curves.

```swift
public static func constrainedFill(edge1: Edge, edge2: Edge, edge3: Edge,
                                    edge4: Edge? = nil,
                                    maxDegree: Int = 8,
                                    maxSegments: Int = 15) -> Shape?
```

- **Parameters:**
  - `edge1`, `edge2`, `edge3` — Required boundary edges.
  - `edge4` — Optional fourth boundary edge; pass `nil` for a 3-sided fill.
  - `maxDegree` — Maximum BSpline degree.
  - `maxSegments` — Maximum number of segments.
- **Returns:** Face shape built on the filled BSpline surface, or `nil` on failure.
- **OCCT:** `GeomFill_ConstrainedFilling` (via `OCCTGeomFillConstrained`).

---

### `constrainedFillInfo`

Get BSpline surface info from a constrained fill result.

```swift
public var constrainedFillInfo: ConstrainedFillInfo? { get }
```

- **Returns:** Surface info (degrees and pole counts), or `nil` if not a BSpline surface.
- **OCCT:** `Geom_BSplineSurface` (via `OCCTGeomFillConstrainedInfo`).

---

## Shape Validity Checking (v0.47.0)

### `CheckStatus`

Shape check error status codes from `BRepCheck`.

```swift
public enum CheckStatus: Int32, Sendable, CaseIterable {
    case noError = 0
    case invalidPointOnCurve = 1
    case invalidPointOnCurveOnSurface = 2
    case invalidPointOnSurface = 3
    case no3DCurve = 4
    case multiple3DCurve = 5
    case invalid3DCurve = 6
    case noCurveOnSurface = 7
    case invalidCurveOnSurface = 8
    case invalidCurveOnClosedSurface = 9
    case invalidSameRangeFlag = 10
    case invalidSameParameterFlag = 11
    case invalidDegeneratedFlag = 12
    case freeEdge = 13
    case invalidMultiConnexity = 14
    case invalidRange = 15
    case emptyWire = 16
    case redundantEdge = 17
    case selfIntersectingWire = 18
    case noSurface = 19
    case invalidWire = 20
    case redundantWire = 21
    case intersectingWires = 22
    case invalidImbricationOfWires = 23
    case emptyShell = 24
    case redundantFace = 25
    case invalidImbricationOfShells = 26
    case unorientableShape = 27
    case notClosed = 28
    case notConnected = 29
    case subshapeNotInShape = 30
    case badOrientation = 31
    case badOrientationOfSubshape = 32
    case invalidPolygonOnTriangulation = 33
    case invalidToleranceValue = 34
    case enclosedRegion = 35
    case checkFail = 36
}
```

Case meanings, verified against `BRepCheck`'s checker sources (`BRepCheck_Edge`/`_Wire`/`_Face`/`_Shell`/`_Solid`/`_Analyzer.cxx`) rather than guessed from the name:

#### `CheckStatus.noError`

No error; the shape passed validation.

#### `CheckStatus.invalidPointOnCurve`

A vertex's recorded parameter on an edge's 3D curve evaluates to a point that does not match the vertex's own point within tolerance.

#### `CheckStatus.invalidPointOnCurveOnSurface`

A vertex's recorded parameter on an edge's curve-on-surface (pcurve) evaluates to a point that does not match the vertex's own point within tolerance.

#### `CheckStatus.invalidPointOnSurface`

A vertex's recorded UV parameters on a face's surface evaluate to a point that does not match the vertex's own point within tolerance.

#### `CheckStatus.no3DCurve`

The edge has no 3D curve representation at all.

#### `CheckStatus.multiple3DCurve`

The edge has more than one 3D curve representation.

#### `CheckStatus.invalid3DCurve`

Declared alongside the curve-on-surface checks below, but not raised by any checker in this OCCT version: the only references in the kernel source are the status-to-string switch and the `checkshape` Draw command's option list, not an actual check site. Kept here because `BRepCheck_Analyzer` can still report it from a custom `BRepCheck_Result` subclass.

#### `CheckStatus.noCurveOnSurface`

The edge has neither a 3D curve nor a curve-on-surface (pcurve) for the face it is being checked against.

#### `CheckStatus.invalidCurveOnSurface`

The edge's pcurve, evaluated at its endpoints, does not land within tolerance of the edge's 3D endpoints.

#### `CheckStatus.invalidCurveOnClosedSurface`

The same failure as `invalidCurveOnSurface`, but on a closed surface where the edge carries two pcurves, one for each side of the seam.

#### `CheckStatus.invalidSameRangeFlag`

The edge's `SameRange` flag is not set even though `SameParameter` is: `SameParameter` requires `SameRange`.

#### `CheckStatus.invalidSameParameterFlag`

The edge's 3D curve and pcurve are flagged `SameParameter` but do not actually share parameterisation within tolerance.

#### `CheckStatus.invalidDegeneratedFlag`

The edge is marked degenerate but still carries a genuine 3D curve reference.

#### `CheckStatus.freeEdge`

In the context of a solid, the edge borders fewer than two faces (an open, non-manifold boundary).

#### `CheckStatus.invalidMultiConnexity`

In the context of a solid, the edge borders more than two faces.

#### `CheckStatus.invalidRange`

The edge's recorded parameter range is empty (its last parameter is at or before its first) or falls outside the range, or period, of its underlying 3D curve or pcurve.

#### `CheckStatus.emptyWire`

The wire has no edges.

#### `CheckStatus.redundantEdge`

An edge appears in the wire three or more times, or twice with the same orientation instead of once FORWARD and once REVERSED.

#### `CheckStatus.selfIntersectingWire`

Two of the wire's edges intersect somewhere other than a shared vertex.

#### `CheckStatus.noSurface`

The face has no surface geometry.

#### `CheckStatus.invalidWire`

Declared alongside the wire-composition checks below, but not raised by any checker in this OCCT version: verified the same way as `invalid3DCurve`, by searching the kernel source for every reference.

#### `CheckStatus.redundantWire`

The same wire appears more than once among the face's boundary wires.

#### `CheckStatus.intersectingWires`

Two of the face's wires cross each other.

#### `CheckStatus.invalidImbricationOfWires`

The face's wires are not correctly nested: an inner wire is not properly contained within the outer one, or the wires' classification order is inconsistent.

#### `CheckStatus.emptyShell`

The shell has no faces.

#### `CheckStatus.redundantFace`

The same face appears more than once in the shell.

#### `CheckStatus.invalidImbricationOfShells`

In a solid, a shell is not correctly nested inside another (a hole shell not properly contained within the outer shell).

#### `CheckStatus.unorientableShape`

OCCT could not compute a consistent orientation for the face's wires or the shell's faces.

#### `CheckStatus.notClosed`

The wire, or shell, is not topologically closed: its edges, or faces, do not form a closed loop, or envelope.

#### `CheckStatus.notConnected`

The wire's edges, or the shell's faces, do not form a single connected chain.

#### `CheckStatus.subshapeNotInShape`

A sub-shape reported in the check result is not actually part of the shape being checked (for example, at the solid level, a shell lying outside the solid it is supposed to bound).

#### `CheckStatus.badOrientation`

Declared alongside `badOrientationOfSubshape`, but not raised by any checker in this OCCT version: verified the same way as `invalid3DCurve`, by searching the kernel source for every reference. Only the "of subshape" form below is ever set.

#### `CheckStatus.badOrientationOfSubshape`

A sub-shape (an edge in a wire, a face in a shell, a shell in a solid) has an orientation inconsistent with its container.

#### `CheckStatus.invalidPolygonOnTriangulation`

The edge's polygon-on-triangulation representation does not match its 3D curve.

#### `CheckStatus.invalidToleranceValue`

Declared for `BRepCheck_Analyzer`'s own face-tolerance consistency check, but the flag that would trigger it (`isInvalidTolerance` in `BRepCheck_Analyzer.cxx`) is initialised `false` and never assigned `true` anywhere in this OCCT version's kernel source, so it is not currently reachable.

#### `CheckStatus.enclosedRegion`

The solid has more than one non-hole (outer) shell growth: multiple disjoint solid regions rather than one solid with holes.

#### `CheckStatus.checkFail`

The check itself failed to run (an internal exception), rather than the shape failing validation.

---

### `CheckResult`

Result of a shape validity check.

```swift
public struct CheckResult: Sendable {
    public let isValid: Bool
    public let errorCount: Int
    public let firstError: CheckStatus?
}
```

---

#### `CheckResult.errorCount`

Number of `CheckStatus` errors found (`0` when `isValid` is `true`).

#### `CheckResult.firstError`

The first `CheckStatus` error encountered, or `nil` when `isValid` is `true`.

---

### `checkResult`

Check the overall validity of this shape.

```swift
public var checkResult: CheckResult { get }
```

- **Returns:** Check result with validity flag, error count, and first error code.
- **OCCT:** `BRepCheck_Analyzer` (via `OCCTCheckShape`).
- **Example:**
  ```swift
  let cr = shape.checkResult
  if !cr.isValid, let err = cr.firstError {
      print("invalid: \(err)")
  }
  ```

---

### `detailedCheckStatuses`

Get detailed error status codes for this shape.

```swift
public var detailedCheckStatuses: [CheckStatus] { get }
```

Returns all individual error codes found during validation. Useful for diagnosing exactly what's wrong with an invalid shape.

- **Returns:** Array of check status codes; empty if valid.
- **OCCT:** `BRepCheck_Analyzer` (via `OCCTCheckShapeDetailed`).

---

### `Face.faceCheckResult`

Check the validity of this face using `BRepCheck_Face`.

```swift
public var faceCheckResult: Shape.CheckResult { get }
```

More targeted than `Shape.checkResult` — includes wire intersection checks and face-specific validation.

- **Returns:** Check result.
- **OCCT:** `BRepCheck_Face` (via `OCCTCheckFace`).

---

## Local Operations, Validation, Fixing and Extrema (v0.48.0)

### `localPipe(along:)`

Perform a pipe sweep of this shape along a wire spine with shape tracking.

```swift
public func localPipe(along spine: Wire) -> Shape?
```

- **Parameters:** `spine` — Wire spine to sweep along.
- **Returns:** Swept shape, or `nil` on failure.
- **OCCT:** `LocOpe_Pipe` (via `OCCTLocOpePipe`).

---

### `localLinearForm(direction:from:to:)`

Perform a linear form (translation sweep) of this shape with shape tracking.

```swift
public func localLinearForm(direction: SIMD3<Double>,
                            from start: SIMD3<Double>,
                            to end: SIMD3<Double>) -> Shape?
```

- **Parameters:**
  - `direction` — Direction vector of the sweep.
  - `start` — Start point of the sweep.
  - `end` — End point of the sweep.
- **Returns:** Swept shape, or `nil` on failure.
- **OCCT:** `LocOpe_LinearForm` (via `OCCTLocOpeLinearForm`).

---

### `localRevolutionForm(axisOrigin:axisDirection:angle:)`

Perform a revolution form of this shape with shape tracking.

```swift
public func localRevolutionForm(axisOrigin: SIMD3<Double>,
                                 axisDirection: SIMD3<Double>,
                                 angle: Double) -> Shape?
```

- **Parameters:**
  - `axisOrigin` — Origin point of the rotation axis.
  - `axisDirection` — Direction of the rotation axis.
  - `angle` — Rotation angle in radians.
- **Returns:** Revolved shape, or `nil` on failure.
- **OCCT:** `LocOpe_RevolutionForm` (via `OCCTLocOpeRevolutionForm`).

---

### `splitFace(at:with:)`

Split a face of this shape by adding a wire on it.

```swift
public func splitFace(at faceIndex: Int, with wire: Wire) -> Shape?
```

- **Parameters:**
  - `faceIndex` — 0-based index of the face to split.
  - `wire` — Wire lying on the face that defines the split.
- **Returns:** Modified shape with the face split, or `nil` on failure.
- **OCCT:** `LocOpe_SplitShape` (via `OCCTLocOpeSplitShapeByWire`).

---

### `splitEdge(at:parameter:)`

Split an edge of this shape at a parameter.

```swift
public func splitEdge(at edgeIndex: Int, parameter: Double) -> Shape?
```

- **Parameters:**
  - `edgeIndex` — 0-based index of the edge to split.
  - `parameter` — Parameter along the edge (0.0–1.0) where the split occurs.
- **Returns:** The split edge parts as a compound, or `nil` on failure.
- **OCCT:** `LocOpe_SplitShape` (via `OCCTLocOpeSplitShapeByVertex`).

---

### `splitDrafts(faceIndex:wire:direction:planeOrigin:planeNormal:angle:)`

Split a face with draft angles on both sides of a wire.

```swift
public func splitDrafts(faceIndex: Int, wire: Wire,
                        direction: SIMD3<Double>,
                        planeOrigin: SIMD3<Double>,
                        planeNormal: SIMD3<Double>,
                        angle: Double) -> Shape?
```

- **Parameters:**
  - `faceIndex` — 0-based index of the face to split.
  - `wire` — Wire defining the split line.
  - `direction` — Extraction direction.
  - `planeOrigin` — Origin of the neutral plane.
  - `planeNormal` — Normal of the neutral plane.
  - `angle` — Draft angle in radians.
- **Returns:** Modified shape with draft, or `nil` on failure.
- **OCCT:** `LocOpe_SplitDrafts` (via `OCCTLocOpeSplitDrafts`).
- **Note:** `LocOpe_SplitDrafts::Perform()` can throw on incompatible geometry; the bridge wraps it in a try-catch.

---

### `commonEdges(with:)`

Find edges in common between this shape and another.

```swift
public func commonEdges(with other: Shape) -> [Edge]
```

The returned edges belong to **this** shape and each carries its `Edge.index` into `edges()`, so
they feed straight into any index-taking method:

```swift
let seam = lower.commonEdges(with: upper)
let rounded = lower.filleted(edges: seam, radius: 1)
```

`LocOpe_FindEdges` reports one entry per matched *pair*, so one edge of this shape can appear more
than once. Dedupe on `Edge.index` if you need one entry per distinct edge.

- **Parameters:** `other` — Shape to compare with.
- **Returns:** Array of common edges (up to 100), each with a valid index into `edges()`.
- **OCCT:** `LocOpe_FindEdges` (via `OCCTLocOpeFindEdges`).
- **Changed in #613:** `Edge.index` was the position in the result array, not an index into
  `edges()`, so it addressed a different edge — or none.

---

### `edgesInFace(at:)`

Find edges of this shape that lie in a specific face.

```swift
public func edgesInFace(at faceIndex: Int) -> [Edge]
```

Each returned edge carries its `Edge.index` into `edges()`:

```swift
let onTop = block.edgesInFace(at: 3)
let rounded = block.filleted(edges: onTop, radius: 2)

let e = onTop[0]
block.edge(at: e.index)   // the very same edge
```

- **Parameters:** `faceIndex` — 0-based index of the face to check, in the `faces()` enumeration.
- **Returns:** Array of edges found in the face (up to 100), each with a valid index into `edges()`.
- **OCCT:** `LocOpe_FindEdgesInFace` (via `OCCTLocOpeFindEdgesInFace`).
- **Changed in #613:** as for `commonEdges(with:)`. Measured on a 10 mm box, `edgesInFace(at: 3)`
  handed back 0, 1, 2, 3 for edges whose real indices are 2, 6, 10 and 11 — all four naming a
  different edge, 10.00, 12.25, 7.07 and 12.25 mm away.

---

### `CSIntersection`

Result of a curve-shape intersection.

```swift
public struct CSIntersection: Sendable {
    public let point: SIMD3<Double>
    public let parameter: Double
    public let faceUV: SIMD2<Double>
}
```

| Field | Meaning |
|---|---|
| `point` | 3D intersection point. |
| `parameter` | Parameter along the intersecting line at `point`. |
| `faceUV` | Parametric (u, v) location of `point` on the face it was found on. |

*(Per-field anchors below, for cross-reference; the table above has the actual meaning of each.)*

#### `faceUV`

---

### `intersectLine(origin:direction:)` *(LocOpe_CSIntersector variant)*

Intersect a line with this shape to find intersection points.

```swift
public func intersectLine(origin: SIMD3<Double>, direction: SIMD3<Double>) -> [CSIntersection]
```

- **Parameters:**
  - `origin` — Line origin.
  - `direction` — Line direction.
- **Returns:** Array of intersection points with curve parameters and face UV coordinates.
- **OCCT:** `LocOpe_CSIntersector` (via `OCCTLocOpeCSIntersectLine`).
- **Note:** This overload returns `[CSIntersection]` with face UV. A separate `IntCurvesFace`-backed overload in v0.61.0 returns `[LineFaceIntersection]`.

---

### `analyzeValidity(geometryChecks:)`

Perform comprehensive validity analysis on this shape.

```swift
public func analyzeValidity(geometryChecks: Bool = true) -> Bool
```

- **Parameters:** `geometryChecks` — Whether to include geometry-level checks.
- **Returns:** `true` if the shape is valid.
- **OCCT:** `BRepCheck_Analyzer` (via `OCCTBRepCheckAnalyzerIsValid`).

---

### `TopAbs_ShapeEnum`

Sub-shape type specifier.

```swift
public enum TopAbs_ShapeEnum: Int32, Sendable {
    case compound = 0, compsolid = 1, solid = 2, shell = 3
    case face = 4, wire = 5, edge = 6, vertex = 7
}
```

Raw values match OCCT's own `TopAbs_ShapeEnum` exactly (`TopAbs_COMPOUND = 0` through
`TopAbs_VERTEX = 7`), so a raw round-trip through the bridge never needs remapping.

| Case | Meaning |
|---|---|
| `compound` | A `TopoDS_Compound`, an arbitrary grouping of other shapes. |
| `compsolid` | A `TopoDS_CompSolid`, a connected group of solids sharing faces. |
| `solid` | A `TopoDS_Solid`. |
| `shell` | A `TopoDS_Shell`. |
| `face` | A `TopoDS_Face`. |
| `wire` | A `TopoDS_Wire`. |
| `edge` | A `TopoDS_Edge`. |
| `vertex` | A `TopoDS_Vertex`. |

*(Per-case anchors below, for cross-reference; the table above has the actual meaning of each.)*

#### `compsolid`

---

### `isSubShapeValid(type:at:)`

Check if a specific sub-shape is valid within this shape's context.

```swift
public func isSubShapeValid(type: TopAbs_ShapeEnum, at index: Int) -> Bool
```

- **Parameters:**
  - `type` — Type of sub-shape to check.
  - `index` — 0-based index of the sub-shape.
- **Returns:** `true` if the sub-shape is valid.
- **OCCT:** `BRepCheck_Analyzer` (via `OCCTBRepCheckSubShapeValid`).

---

### `checkEdge(at:)`

Check validity of an edge by index.

```swift
public func checkEdge(at index: Int) -> CheckResult
```

- **Parameters:** `index` — 0-based edge index.
- **Returns:** Check result for the specified edge.
- **OCCT:** `BRepCheck_Edge` (via `OCCTCheckEdge`).

---

### `checkWire(at:)`

Check validity of a wire by index.

```swift
public func checkWire(at index: Int) -> CheckResult
```

- **OCCT:** `BRepCheck_Wire` (via `OCCTCheckWire`).

---

### `checkShell(at:)`

Check validity of a shell by index.

```swift
public func checkShell(at index: Int) -> CheckResult
```

- **OCCT:** `BRepCheck_Shell` (via `OCCTCheckShell`).

---

### `checkVertex(at:)`

Check validity of a vertex by index.

```swift
public func checkVertex(at index: Int) -> CheckResult
```

- **OCCT:** `BRepCheck_Vertex` (via `OCCTCheckVertex`).

---

### `limitTolerance(min:max:)`

Limit all tolerances in this shape to a given range.

```swift
@discardableResult
public func limitTolerance(min: Double, max: Double) -> Bool
```

- **Parameters:**
  - `min` — Minimum tolerance.
  - `max` — Maximum tolerance.
- **Returns:** `true` if any tolerance was changed.
- **OCCT:** `ShapeFix_ShapeTolerance::LimitTolerance` (via `OCCTShapeFixLimitTolerance`).

---

### `setTolerance(_:)`

Set all tolerances in this shape to a specific value.

```swift
public func setTolerance(_ tolerance: Double)
```

- **Parameters:** `tolerance` — Tolerance value to set on all sub-shapes.
- **OCCT:** `ShapeFix_ShapeTolerance::SetTolerance` (via `OCCTShapeFixSetTolerance`).

---

### `splitCommonVertices()`

Split vertices that are shared between edges in incompatible ways.

```swift
public func splitCommonVertices() -> Shape?
```

- **Returns:** Fixed shape, or `nil` on failure.
- **OCCT:** `ShapeFix_SplitCommonVertex` (via `OCCTShapeFixSplitCommonVertex`).

---

### `connectedFaces(tolerance:)`

Connect adjacent faces in this shape's shell.

```swift
public func connectedFaces(tolerance: Double = 1e-4) -> Shape?
```

- **Parameters:** `tolerance` — Connection tolerance.
- **Returns:** Fixed shape with connected faces, or `nil` on failure.
- **OCCT:** `ShapeFix_FaceConnect` (via `OCCTShapeFixFaceConnect`).

---

### `fixEdgeSameParameter(tolerance:)`

Fix same-parameter inconsistencies on all edges.

```swift
@discardableResult
public func fixEdgeSameParameter(tolerance: Double = 0) -> Int
```

- **Parameters:** `tolerance` — Fixing tolerance (0 = default).
- **Returns:** Number of edges fixed.
- **OCCT:** `ShapeFix_Edge::FixSameParameter` (via `OCCTShapeFixEdgeSameParameter`).

---

### `fixEdgeVertexTolerance()`

Fix vertex tolerance issues on all edges.

```swift
@discardableResult
public func fixEdgeVertexTolerance() -> Int
```

- **Returns:** Number of edges fixed.
- **OCCT:** `ShapeFix_Edge::FixVertexTolerance` (via `OCCTShapeFixEdgeVertexTolerance`).

---

### `fixWireVertices(precision:)`

Fix vertex issues in all wires of this shape.

```swift
@discardableResult
public func fixWireVertices(precision: Double = 1e-4) -> Int
```

- **Parameters:** `precision` — Precision for fixing.
- **Returns:** Number of fixes applied.
- **OCCT:** `ShapeFix_WireVertex` (via `OCCTShapeFixWireVertex`).

---

### `EdgeEdgeExtrema`

Result of edge-edge distance extrema computation.

```swift
public struct EdgeEdgeExtrema: Sendable {
    public let distance: Double
    public let paramOnEdge1: Double
    public let paramOnEdge2: Double
    public let pointOnEdge1: SIMD3<Double>
    public let pointOnEdge2: SIMD3<Double>
    public let isParallel: Bool
    public let solutionCount: Int
}
```

| Field | Meaning |
|---|---|
| `paramOnEdge1` | Curve parameter of the closest point on the first edge. |
| `paramOnEdge2` | Curve parameter of the closest point on the second edge. |
| `pointOnEdge1` | World-space closest point on the first edge. |
| `pointOnEdge2` | World-space closest point on the second edge. |

#### `Shape.EdgeEdgeExtrema.pointOnEdge2`

---

### `edgeEdgeExtrema(edgeIndex1:other:edgeIndex2:)`

Compute distance extrema between two edges by index.

```swift
public func edgeEdgeExtrema(edgeIndex1: Int, other: Shape, edgeIndex2: Int) -> EdgeEdgeExtrema?
```

- **Parameters:**
  - `edgeIndex1` — 0-based index of the first edge in this shape.
  - `other` — Shape containing the second edge.
  - `edgeIndex2` — 0-based index of the second edge in `other`.
- **Returns:** Extrema result, or `nil` if no solutions or if edges are parallel.
- **OCCT:** `BRepExtrema_ExtCC` (via `OCCTBRepExtremaExtCC`).
- **Note:** Returns `nil` when edges are parallel (`isParallel == true`). Check `solutionCount > 0` guards this in the bridge.

---

### `PointFaceExtrema`

Result of point-face distance extrema computation.

```swift
public struct PointFaceExtrema: Sendable {
    public let distance: Double
    public let faceUV: SIMD2<Double>
    public let pointOnFace: SIMD3<Double>
    public let solutionCount: Int
}
```

---

#### `PointFaceExtrema.faceUV`

UV parameters on the face at the nearest point.

#### `PointFaceExtrema.pointOnFace`

The 3D point on the face nearest to the query point.

---

### `pointFaceExtrema(point:faceIndex:)`

Compute distance from a point to a face.

```swift
public func pointFaceExtrema(point: SIMD3<Double>, faceIndex: Int) -> PointFaceExtrema?
```

- **Parameters:**
  - `point` — 3D point.
  - `faceIndex` — 0-based face index in this shape.
- **Returns:** Extrema result, or `nil` on failure.
- **OCCT:** `BRepExtrema_ExtPF` (via `OCCTBRepExtremaExtPF`).

---

### `FaceFaceExtrema`

Result of face-face distance extrema computation.

```swift
public struct FaceFaceExtrema: Sendable {
    public let distance: Double
    public let face1UV: SIMD2<Double>
    public let face2UV: SIMD2<Double>
    public let pointOnFace1: SIMD3<Double>
    public let pointOnFace2: SIMD3<Double>
    public let solutionCount: Int
}
```

| Field | Meaning |
|---|---|
| `distance` | The extremum distance between the two faces. |
| `face1UV` | Parametric (u, v) location on the first face where the extremum point lies. |
| `face2UV` | Parametric (u, v) location on the second face where the extremum point lies. |
| `pointOnFace1` | 3D point on the first face at the extremum. |
| `pointOnFace2` | 3D point on the second face at the extremum. |
| `solutionCount` | Number of extrema solutions `BRepExtrema_ExtFF` found; this struct describes one of them. |

*(Per-field anchors below, for cross-reference; the table above has the actual meaning of each.)*

#### `pointOnFace2`

---

### `faceFaceExtrema(faceIndex1:other:faceIndex2:)`

Compute distance extrema between two faces.

```swift
public func faceFaceExtrema(faceIndex1: Int, other: Shape, faceIndex2: Int) -> FaceFaceExtrema?
```

- **Parameters:**
  - `faceIndex1` — 0-based index of the first face in this shape.
  - `other` — Shape containing the second face.
  - `faceIndex2` — 0-based index of the second face in `other`.
- **Returns:** Extrema result, or `nil` on failure.
- **OCCT:** `BRepExtrema_ExtFF` (via `OCCTBRepExtremaExtFF`).

---

### `dividedClosedFaces(splitPoints:)`

Divide closed (wrapping) faces in this shape.

```swift
public func dividedClosedFaces(splitPoints: Int = 1) -> Shape?
```

Uses `ShapeUpgrade_ShapeDivideClosed` to split faces that wrap completely around (e.g., the lateral face of a cylinder).

- **Parameters:** `splitPoints` — Number of split points per closed face.
- **Returns:** Shape with divided faces, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_ShapeDivideClosed` (via `OCCTShapeUpgradeDivideClosed`).

---

### `ContinuityLevel`

Continuity level for shape division.

```swift
public enum ContinuityLevel: Int32, Sendable, CaseIterable {
    case c0 = 0, c1 = 1, c2 = 2, c3 = 3, cn = 4, g1 = 5, g2 = 6
}
```

| Case | Meaning |
|---|---|
| `.c0` | Positional continuity only (touching, no derivative match). |
| `.c1` | First-derivative (tangent vector) continuity. |
| `.c2` | Second-derivative (curvature vector) continuity. |
| `.c3` | Third-derivative continuity. |
| `.cn` | Continuity to the geometry's own maximum available derivative order. |
| `.g1` | Geometric tangent continuity (parallel tangent direction, not equal derivative magnitude). |
| `.g2` | Geometric curvature continuity (parallel principal curvature direction). |

`dividedByContinuity(criterion:tolerance:)` duplicated `divided(at:tolerance:)` over the same
`ShapeUpgrade_ShapeDivideContinuity`, setting only the boundary criterion where
`divided(at:tolerance:)` sets boundary, pcurve AND surface criteria together, the usage OCCT's own
shape-healing guide demonstrates (#438). Deprecated as a forward to `divided(at:tolerance:)`,
it was removed at v2.0.0 (#784):

```swift
shape.divided(at: .c1, tolerance: 1e-4)   // was: shape.dividedByContinuity(criterion: .c1, tolerance: 1e-4)
```

---

#### `Shape.ContinuityLevel.g2`

> **Deliberately kept separate from
> [`ParametricContinuity`](Shape-Healing.md#parametriccontinuity)** (#398). This is a strict
> superset: `cn`, `g1` and `g2` are accepted only by
> [`divided(at:tolerance:)`](Shape-Healing.md#dividedattolerance). Every other continuity-floor
> call site silently defaults an unrecognised value, so widening them to this type would trade a
> compile error for a wrong answer.
>
> Used by `divided(at:tolerance:)` alone since #438 folded the narrower
> `dividedByContinuity(criterion:tolerance:)` (deprecated, removed at v2.0.0, #784) into it.

`dividedByContinuity(criterion:tolerance:)` duplicated `divided(at:tolerance:)` over the same
`ShapeUpgrade_ShapeDivideContinuity`, setting only the boundary criterion where
`divided(at:tolerance:)` sets boundary, pcurve AND surface criteria together, the usage OCCT's own
shape-healing guide demonstrates (#438). Deprecated as a forward to `divided(at:tolerance:)`,
it was removed at v2.0.0 (#784):

```swift
shape.divided(at: .c1, tolerance: 1e-4)   // was: shape.dividedByContinuity(criterion: .c1, tolerance: 1e-4)
```

---

### `PointEdgeExtrema`

Result of point-edge distance extrema computation.

```swift
public struct PointEdgeExtrema: Sendable {
    public let distance: Double
    public let parameter: Double
    public let pointOnEdge: SIMD3<Double>
    public let solutionCount: Int
}
```

`solutionCount` is how many perpendicular feet the point has on the edge — `BRepExtrema_ExtPC`'s
extrema count, reported for its own sake. Zero means the nearest point is one of the edge's two
ends. A non-zero count does **not** mean the nearest point is one of those feet: an extremum can be
a maximum. Read `distance` / `parameter` / `pointOnEdge` for the answer (#580).

---

#### `PointEdgeExtrema.pointOnEdge`

The 3D point on the edge nearest to the query point.

---

### `pointEdgeExtrema(point:edgeIndex:)`

Compute the minimum distance from a point to an edge of this shape, over the whole edge.

```swift
public func pointEdgeExtrema(point: SIMD3<Double>, edgeIndex: Int) -> PointEdgeExtrema?
```

```swift
let arc = Shape.fromWire(Wire.arc(
    center: SIMD3(0, 0, 0), radius: 5, startAngle: 0, endAngle: .pi)!)!

// Below the arc, the nearest point is an end — the only extremum is the far side of it.
if let hit = arc.pointEdgeExtrema(point: SIMD3(0, -6, 0), edgeIndex: 0) {
    print(hit.distance)       // 7.81, to the end at (5, 0, 0). Was 11, the far side.
    print(hit.solutionCount)  // 1 — and that one extremum is a maximum
}

let segment = Shape.fromWire(Wire.line(from: SIMD3(3, 0, 0), to: SIMD3(8, 0, 0))!)!
if let hit = segment.pointEdgeExtrema(point: SIMD3(100, 0, 0), edgeIndex: 0) {
    print(hit.distance)       // 92. Was nil: no extremum exists past the end.
}
```

- **Parameters:**
  - `point` — 3D point.
  - `edgeIndex` — 0-based edge index, in the enumeration `edges()` reads.
- **Returns:** The nearest-point result, or `nil` if there is no such edge index or that edge has no
  3D curve.
- **OCCT:** `ShapeAnalysis_Curve` + `GeomAPI_ProjectPointOnCurve` + the edge's ends, via
  `occtNearestPointOnCurveRange` (the helper behind `Edge.project(point:)`, so the two agree);
  `BRepExtrema_ExtPC` supplies `solutionCount` only.
- **Changed in #580:** this used to report the minimum over `BRepExtrema_ExtPC`'s extrema, which
  excludes the edge's ends, and to answer `nil` whenever no extremum existed. It also indexed edges
  by a bare `TopExp_Explorer` walk, which counts one entry per occurrence — from index 9 a box's
  edges disagreed with `edges()`.

---

### `EdgeFaceExtrema`

Result of edge-face distance extrema computation.

```swift
public struct EdgeFaceExtrema: Sendable {
    public let distance: Double
    public let paramOnEdge: Double
    public let faceUV: SIMD2<Double>
    public let pointOnEdge: SIMD3<Double>
    public let pointOnFace: SIMD3<Double>
    public let isParallel: Bool
    public let solutionCount: Int
}
```

---

#### `EdgeFaceExtrema.paramOnEdge`

Parameter on the edge at the nearest point.

#### `EdgeFaceExtrema.faceUV`

UV parameters on the face at the nearest point.

#### `EdgeFaceExtrema.pointOnEdge`

The 3D point on the edge at the nearest point.

#### `EdgeFaceExtrema.pointOnFace`

The 3D point on the face at the nearest point.

---

### `edgeFaceExtrema(edgeIndex:other:faceIndex:)`

Compute distance extrema between an edge and a face.

```swift
public func edgeFaceExtrema(edgeIndex: Int, other: Shape, faceIndex: Int) -> EdgeFaceExtrema?
```

- **Parameters:**
  - `edgeIndex` — 0-based edge index in this shape.
  - `other` — Shape containing the face.
  - `faceIndex` — 0-based face index in `other`.
- **Returns:** Extrema result, or `nil` if parallel or computation fails.
- **OCCT:** `BRepExtrema_ExtCF` (via `OCCTBRepExtremaExtCF`).
- **Note:** When `isParallel` is `true`, the returned struct has zero distance and `solutionCount == 0`.

---

### `removeSmallSolids(volumeThreshold:)`

Remove small solids from this shape based on volume threshold.

```swift
public func removeSmallSolids(volumeThreshold: Double) -> Shape?
```

- **Parameters:** `volumeThreshold` — Solids with volume below this threshold are removed.
- **Returns:** Shape with small solids removed, or `nil` on failure.
- **OCCT:** `ShapeFix_FixSmallSolid` (via `OCCTShapeFixRemoveSmallSolids`).

---

### `mergeSmallSolids(widthFactorThreshold:)`

Merge small solids into adjacent larger solids.

```swift
public func mergeSmallSolids(widthFactorThreshold: Double) -> Shape?
```

Small solids are merged into their neighbors rather than removed.

- **Parameters:** `widthFactorThreshold` — Width factor below which solids are merged.
- **Returns:** Shape with small solids merged, or `nil` on failure.
- **OCCT:** `ShapeFix_FixSmallSolid` (via `OCCTShapeFixMergeSmallSolids`).

---

### `BSplineContinuity` *(removed in v2.0.0)*

Renamed to `ParametricContinuity` in #398; the compatibility typealias itself was removed at
v2.0.0 ([#784](https://github.com/SecondMouseAU/OCCTSwift/issues/784)). Use
[`ParametricContinuity`](Shape-Healing.md#parametriccontinuity) (`.c0` ... `.c3`) directly. No raw
value moved.

---

### `bsplineRestriction(tol3d:tol2d:maxDegree:maxSegments:continuity3d:continuity2d:degreePriority:rational:)`

Simplify BSpline surfaces and curves by restricting degree and segment count.

```swift
public func bsplineRestriction(
    tol3d: Double = 0.01, tol2d: Double = 0.01,
    maxDegree: Int = 8, maxSegments: Int = 100,
    continuity3d: ParametricContinuity = .c1, continuity2d: ParametricContinuity = .c1,
    degreePriority: Bool = true, rational: Bool = false
) -> Shape?
```

- **Parameters:**
  - `tol3d` — 3D approximation tolerance.
  - `tol2d` — 2D approximation tolerance.
  - `maxDegree` — Maximum BSpline degree.
  - `maxSegments` — Maximum number of segments.
  - `continuity3d` — 3D continuity **ceiling**, not a guarantee. `.c3` is rejected outright and
    fails the whole call, so `.c2` is the practical maximum; below that, OCCT reduces the continuity
    it delivers with no diagnostic whenever the requested one cannot meet `tol3d` within `maxDegree`,
    and with `degreePriority` it degrades all the way to C0. Measured in #570, a face on an offset
    sphere returns the identical C0 result for `.c0`, `.c1` and `.c2`.
  - `continuity2d` — 2D continuity requirement, same ceiling and same `.c3` limit.
  - `degreePriority` — If `true`, prioritize degree reduction over segment reduction.
  - `rational` — Allow rational BSplines.
- **Returns:** Simplified shape, or `nil` on failure.
- **OCCT:** `ShapeCustom::BSplineRestriction` (via `OCCTShapeCustomBSplineRestriction`).

---

## ShapeAnalysis FreeBoundsProperties

### `FreeBoundInfo`

Properties of a single free bound (boundary wire).

```swift
public struct FreeBoundInfo: Sendable {
    public let area: Double
    public let perimeter: Double
    public let ratio: Double
    public let width: Double
    public let notchCount: Int
}
```

- `ratio`, an aspect ratio: contour length over contour width, so 2 for a 20×10 bound. **Not**
  `area / perimeter²`, which is what this field's documentation claimed before #504 (0.0556 for
  that same bound). OCCT solves it from `area` and `perimeter` and leaves *both* `ratio` and
  `width` at 0 when that solve has no real root, which an exactly square bound hits by one ulp,
  sitting precisely on the boundary between the two branches. So 0 means "not solvable here", not
  "degenerate contour"; `area` and `perimeter` are still good in that case.
- `width`, the average contour width, on the same "0 means unsolved" contract as `ratio`.
- `notchCount`, the narrow 'V'-like sub-contours found on the bound.

| Field | Meaning |
|---|---|
| `perimeter` | Total length of the bound's contour. |
| `ratio` | Contour length over contour width (0 when OCCT's solve has no real root; see above). |
| `notchCount` | Count of narrow 'V'-like sub-contours (notches) found on the bound. |

#### `Shape.FreeBoundInfo.notchCount`

---

### `FreeBoundsAnalysis`

Summary result of free bounds analysis.

```swift
public struct FreeBoundsAnalysis: Sendable {
    public let totalCount: Int
    public let closedCount: Int
    public let openCount: Int
}
```

---

### `freeBoundsAnalysis(tolerance:)`

Analyze free bounds (boundary wires) of this shape.

```swift
public func freeBoundsAnalysis(tolerance: Double) -> FreeBoundsAnalysis
```

A free bound is a chain of edges that belong to only one face, closed into a contour where it can
be. The shape needs to be a compound or shell of faces: the search runs over its direct children,
so a lone face reports no free bounds. In practice the sewing pass closes essentially every contour
it finds, so `openCount` is usually 0.

Each of the five `…FreeBound…` methods here runs its own analysis. To read several bounds of one
shape, build a `FreeBoundsProperties` instead: it analyses once and answers every query from that
one result. Both have run on the same implementation since #504.

- **Note:** Unaffected by OCCT 8.0.1's `ConnectEdgesToWires` INTERNAL/EXTERNAL skip (OCCT#1408), at any tolerance, including the `tolerance <= 0` input described below that routes to a different constructor with no sewing stage at all; see [`freeBounds(sewingTolerance:)`](#freeboundssewingtolerance) for why, on both branches. See [#655](https://github.com/SecondMouseAU/OCCTSwift/issues/655).
- **Parameters:** `tolerance`, the sewing tolerance used to chain free edges into contours. 0 or below
  selects a different OCCT algorithm, taking free edges from the shape's already-shared topology
  instead of from a sewing pass.
- **Returns:** Analysis summary with total, closed and open bound counts.
- **OCCT:** `ShapeAnalysis_FreeBoundsProperties` (via `OCCTFreeBoundsPropsCounts`).
- **Example:**
  ```swift
  let faces = Shape.box(width: 10, height: 10, depth: 10)!.subShapes(ofType: .face)
  let opened = Shape.compound(Array(faces.dropLast()))!   // free boundary = the square hole

  let fb = opened.freeBoundsAnalysis(tolerance: 1e-3)
  print("open: \(fb.openCount), closed: \(fb.closedCount)")   // open: 0, closed: 1

  if let bound = opened.closedFreeBoundInfo(tolerance: 1e-3, index: 0) {
      print(bound.area, bound.perimeter)                        // 100.0 40.0
  }
  ```

---

### `closedFreeBoundInfo(tolerance:index:)`

Get properties of a closed free bound.

```swift
public func closedFreeBoundInfo(tolerance: Double, index: Int) -> FreeBoundInfo?
```

- **Note:** Unaffected by OCCT 8.0.1's `ConnectEdgesToWires` INTERNAL/EXTERNAL skip (OCCT#1408), at any tolerance; see [`freeBounds(sewingTolerance:)`](#freeboundssewingtolerance) for why, on both branches. See [#655](https://github.com/SecondMouseAU/OCCTSwift/issues/655).
- **Parameters:**
  - `tolerance` — Same tolerance used for `freeBoundsAnalysis(tolerance:)`.
  - `index` — 0-based index of the closed free bound.
- **Returns:** Properties, or `nil` if the index is out of range.
- **OCCT:** `ShapeAnalysis_FreeBoundsProperties` (via `OCCTFreeBoundsPropsInfo`).

---

### `openFreeBoundInfo(tolerance:index:)`

Get properties of an open free bound.

```swift
public func openFreeBoundInfo(tolerance: Double, index: Int) -> FreeBoundInfo?
```

- **Note:** Unaffected by OCCT 8.0.1's `ConnectEdgesToWires` INTERNAL/EXTERNAL skip (OCCT#1408), at any tolerance; see [`freeBounds(sewingTolerance:)`](#freeboundssewingtolerance) for why, on both branches. See [#655](https://github.com/SecondMouseAU/OCCTSwift/issues/655).
- **Parameters:**
  - `tolerance` — Same tolerance used for `freeBoundsAnalysis(tolerance:)`.
  - `index` — 0-based index of the open free bound.
- **Returns:** Properties, or `nil` if the index is out of range.
- **OCCT:** `ShapeAnalysis_FreeBoundsProperties` (via `OCCTFreeBoundsPropsInfo`).

---

### `closedFreeBoundWire(tolerance:index:)`

Get the wire shape of a closed free bound.

```swift
public func closedFreeBoundWire(tolerance: Double, index: Int) -> Shape?
```

- **Note:** Unaffected by OCCT 8.0.1's `ConnectEdgesToWires` INTERNAL/EXTERNAL skip (OCCT#1408), at any tolerance; see [`freeBounds(sewingTolerance:)`](#freeboundssewingtolerance) for why, on both branches. See [#655](https://github.com/SecondMouseAU/OCCTSwift/issues/655).
- **Parameters:**
  - `tolerance` — Same tolerance used for `freeBoundsAnalysis(tolerance:)`.
  - `index` — 0-based index of the closed free bound.
- **Returns:** Wire as a `Shape`, or `nil` if the index is out of range.
- **OCCT:** `ShapeAnalysis_FreeBoundsProperties` (via `OCCTFreeBoundsPropsWire`).

---

### `openFreeBoundWire(tolerance:index:)`

Get the wire shape of an open free bound.

```swift
public func openFreeBoundWire(tolerance: Double, index: Int) -> Shape?
```

- **Note:** Unaffected by OCCT 8.0.1's `ConnectEdgesToWires` INTERNAL/EXTERNAL skip (OCCT#1408), at any tolerance; see [`freeBounds(sewingTolerance:)`](#freeboundssewingtolerance) for why, on both branches. See [#655](https://github.com/SecondMouseAU/OCCTSwift/issues/655).
- **Parameters:**
  - `tolerance` — Same tolerance used for `freeBoundsAnalysis(tolerance:)`.
  - `index` — 0-based index of the open free bound.
- **Returns:** Wire as a `Shape`, or `nil` if the index is out of range.
- **OCCT:** `ShapeAnalysis_FreeBoundsProperties` (via `OCCTFreeBoundsPropsWire`).

---

## Internal Storage
