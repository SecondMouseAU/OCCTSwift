---
title: Feature Recognition & Medial Axis
parent: API Reference
---

# Feature Recognition & Medial Axis

`FeatureRecognition.swift` provides an Attributed Adjacency Graph (AAG) for B-Rep feature recognition, classifying faces and their shared-edge convexity to detect pockets and holes. `MedialAxis.swift` computes the Voronoi skeleton (medial axis transform) of a planar face, producing a graph of bisector arcs annotated with inscribed-circle radii for thin-wall detection and tool-path planning.

## Topics

- [EdgeConvexity](#edgeconvexity) · [AAGNode](#aagnode) · [AAGEdge](#aagedge) · [AAG](#aag) · [PocketFeature](#pocketfeature) · [Feature Recognition Extensions (AAG)](#feature-recognition-extensions-aag) · [Shape Extension, Feature Recognition](#shape-extension--feature-recognition) · [MedialAxisNode](#medialaxisnode) · [MedialAxisArc](#medialaxisarc) · [MedialAxis](#medialaxis)

---

## EdgeConvexity

Classification of the dihedral angle at a shared edge between two adjacent faces.

```swift
public enum EdgeConvexity: Int32, Sendable {
    case concave = -1   // Interior angle > 180° (pocket-like, going inward)
    case smooth = 0     // Tangent faces (~180°)
    case convex = 1     // Interior angle < 180° (fillet-like, going outward)
}
```

Maps to `OCCTEdgeConvexity` from the bridge. The classification is computed by `OCCTEdgeGetConvexity`, which calls OCCT's own classifier, `ChFi3d::DefineConnectType`: the same one the fillet and chamfer builders use to decide which edges they can round or bevel (#723). It samples the LOCAL dihedral at the edge midpoint: each face's normal there (from its pcurve's `D1` evaluation) against the edge tangent, reporting the identical classification regardless of which face the caller passes as `face1` versus `face2`.

Before #723 this used each face's own GLOBAL area centroid (`BRepGProp::SurfaceProperties`) as a stand-in for "which side is material": whether a point deep inside one face fell on the material or void side of the other face's tangent plane, averaged over both faces for the same order-independence `ChFi3d` now gives natively. That formula (#703, replacing an even earlier one, the sign of `(tangent × n1) · n2`, that silently depended on argument order) drifted with face proportions: a through-hole rim could classify concave or convex purely as a function of plate thickness, since a cylindrical wall's centroid moves as the wall gets taller while the rim geometry itself never changes.

`OCCTEdgeGetConvexity` (like `OCCTFaceGetSharedEdgeSummary`) has no notion of which solid `face1`/`face2` belong to; it is `AAG.buildGraph()` that restricts which pairs reach it to occurrences sharing a solid (#699). Called directly on two faces from different solids the result is not meaningful for either, see `AAG`, below.

- `concave`: the two face normals "open inward"; typical of pocket walls meeting a floor.
- `smooth`: faces are tangent (within ~0.5°); typical of filleted edges.
- `convex`: the two face normals "open outward"; typical of external edges.

---

### `EdgeConvexity.concave`

Interior dihedral angle greater than 180 degrees: the two face normals "open inward," typical of a pocket wall meeting its floor.

### `EdgeConvexity.smooth`

Faces are tangent, dihedral angle within about 0.5 degrees of 180: typical of a filleted edge.

### `EdgeConvexity.convex`

Interior dihedral angle less than 180 degrees: the two face normals "open outward," typical of an external edge.

---

## AAGNode

A node in the Attributed Adjacency Graph, representing a single B-Rep face **occurrence** (#642).

```swift
public struct AAGNode: Sendable {
    public let faceIndex: Int
    public let distinctFaceIndex: Int
    public let normal: SIMD3<Double>?
    public let isPlanar: Bool
    public let isHorizontal: Bool
    public let isUpward: Bool
    public let isDownward: Bool
    public let isVertical: Bool
    public let zLevel: Double?
    public let bounds: (min: SIMD3<Double>, max: SIMD3<Double>)
}
```

All fields are populated once during `AAG.buildGraph()` by querying the corresponding `Face` properties. `normal` is `nil` for degenerate faces; `zLevel` is `nil` for non-planar or non-horizontal faces. `bounds` is the face's exact-geometry bounding box (`Face.exactBounds`, not `Face.bounds`), so it is unaffected by any triangulation the face carries: meshing a shape before building an `AAG` from it does not change this value (#733). A face with no bounding box at all (`Face.exactBounds == nil`, #943) has no extent for any of the graph's geometric comparisons and contributes no node: `buildGraph()` drops it before anything derives from the face list, so `nodes` stays index-aligned with the occurrences it was built from. No explorer-derived face in this project's fixtures is in that state, so this is the contract rather than an observed case.

- `faceIndex`: this node's position in the graph, the index every `AAG` method (`neighbors(of:)`, `edge(between:and:)`, `concaveNeighbors(of:)`, `convexNeighbors(of:)`) takes and returns. An occurrence index into `Shape.orientedFaces()`, not a distinct face index.
- `distinctFaceIndex`: this occurrence's underlying face, its position in `Shape.faces()`, the deduplicated enumeration. Two nodes with the same `distinctFaceIndex` are the two sides of one face shared between two solids in a compound, same geometry, opposite orientation, opposed normals. On a shape whose faces are not shared, every node has `distinctFaceIndex == faceIndex`.

Before #642, `AAG.buildGraph()` read `Shape.faces()`, the deduplicated enumeration, so a face shared by two solids collapsed to one node carrying whichever orientation the dedup happened to keep, and `isHorizontal`/`isUpward`/`isDownward`/`isVertical`/`zLevel` (all derived from that node's normal) silently depended on compound member order. Reading `Shape.orientedFaces()` instead gives each side its own node, so the node set no longer depends on that order.

---

### `AAGNode.isDownward`

Whether the face's normal points downward.

---

## AAGEdge

An edge in the Attributed Adjacency Graph, representing the adjacency relationship between two faces that share at least one B-Rep edge.

```swift
public struct AAGEdge: Sendable {
    public let face1Index: Int
    public let face2Index: Int
    public let convexity: EdgeConvexity
    public let sharedEdgeCount: Int
}
```

`convexity` is taken from the first shared edge between the two faces. `sharedEdgeCount` is the total number of B-Rep edges shared by the pair, uncapped: before v2.0.0 (#761) it silently capped at 10 (`OCCTFaceGetSharedEdges`'s buffer was sized by a hardcoded caller argument, not the true count, confirmed wrong on a synthetic fixture at 12 real shared edges, reported as 10); #783 then replaced the count-then-fetch pair with a single `OCCTFaceGetSharedEdgeSummary` call, which returns the true total and the first shared edge from one walk of the pair. Neither `OCCTFaceGetSharedEdgeCount` nor `OCCTFaceGetSharedEdges` is on `AAG`'s call path today; both are still declared and are exercised directly by `Issue761SharedEdgeCountCapTests` (#811).

- `face1Index` / `face2Index`: occurrence indices (into `Shape.orientedFaces()`) of the two adjacent faces.
- `convexity`: convexity classification of the (first) shared edge.
- `sharedEdgeCount`: total number of B-Rep edges shared by the pair.

### `sharedEdgeCount`

---

## AAG

Attributed Adjacency Graph for feature recognition. Nodes are face occurrences (`Shape.orientedFaces()`, #642); graph edges connect pairs of adjacent occurrences **within the same solid** (#699) and carry convexity attributes.

A face shared by two solids in a compound is two nodes, one per owning solid, each carrying that solid's own normal and derived predicates. `AAG` does not build a graph edge between the two occurrences of one shared face: they are the same face, not neighbors of it. On a shape whose faces are not shared this is exactly the node set the old `Shape.faces()`-based graph produced, in the same order.

### Adjacency is scoped to one solid (#699)

Two occurrences that share a B-Rep edge but belong to different solids in a compound are adjacent *in the compound* and not adjacent in *either* solid: a floor face's candidate walls are the faces bounding the same body, not any face anywhere in the compound that happens to touch the same edge locus. Neither `OCCTFaceGetSharedEdgeSummary` nor `OCCTEdgeGetConvexity` has any notion of solid membership on their own (both compare two `TopoDS_Face` values purely on their own edge geometry), so `AAG.buildGraph()` restricts which pairs it hands to them: only occurrences it can establish share a solid are compared at all.

Solid membership per occurrence is derived from the shape's own traversal order rather than a new bridge entry point: `orientedFaces()`'s underlying `TopExp_Explorer` walk visits every occurrence under one top-level solid contiguously before moving to the next, in the same first-encountered order `Shape.solids` itself enumerates solids in, so the flat occurrence list partitions into contiguous runs sized by each solid's own face-occurrence count. On a shape with zero or one solid, including every single-solid shape, there is no cross-solid pair to restrict, so nothing changes: this is a compound-only concern.

```swift
let box = Shape.box(width: 10, height: 10, depth: 10)!
let halves = box.split(atPlane: SIMD3(4, 0, 0), normal: SIMD3(1, 0, 0))!

// Same geometry, opposite compound member order.
let orderA = Shape.compound(halves)!
let orderB = Shape.compound(halves.reversed())!

// Order-independent: cross-solid pairs never reach the shared-edge probe at all.
print(orderA.detectPocketsAAG().count == orderB.detectPocketsAAG().count)   // true
```

### `AAG.init(shape:)`

Constructs the AAG by traversing all face-occurrence pairs in the shape.

```swift
public init(shape: Shape)
```

Calls `buildGraph()` which reads `shape.orientedFaces()`, iterates all `(i, j)` occurrence pairs (skipping any pair that is the two sides of one shared face, and any pair `AAG` can establish belongs to two different solids, #699), asks `OCCTFaceGetSharedEdgeSummary` for the pair's true shared-edge count and its first shared edge in one walk (backed by `TopExp::MapShapes` + `TopoDS_Edge::IsSame`; a non-zero count *is* adjacency, [#783](https://github.com/SecondMouseAU/OCCTSwift/issues/783)), and classifies each shared edge via `OCCTEdgeGetConvexity` (`ChFi3d::DefineConnectType`, #723). Unlike the #703/#720 centroid formula this replaced, `ChFi3d::DefineConnectType` needs no per-face integration, since it samples the local dihedral directly, so there is nothing to precompute or cache before the pairwise loop.

- **Parameters:** `shape`, the solid to analyse. Works best on closed solids.
- **OCCT:** `TopExp::MapShapes` / `TopoDS_Edge::IsSame` (adjacency); `ChFi3d::DefineConnectType` (convexity).
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 5)!
  let aag = AAG(shape: box)
  print(aag.nodes.count)   // 6
  print(aag.edges.count)   // 12
  ```

---

### `shape`

The shape this graph was built from.

```swift
public let shape: Shape
```

---

### `nodes`

All nodes (one per face occurrence) in the graph, in `Shape.orientedFaces()` order. A face shared between two solids contributes two nodes here (#642).

```swift
public private(set) var nodes: [AAGNode]
```

---

### `edges`

All adjacency edges in the graph.

```swift
public private(set) var edges: [AAGEdge]
```

---

### `adjacencyList`

Bidirectional adjacency map: `adjacencyList[faceIndex][neighborIndex]` gives the index into `edges` for that pair.

```swift
public private(set) var adjacencyList: [[Int: Int]]
```

---

### `neighbors(of:)`

Returns the face indices of all faces adjacent to the given face.

```swift
public func neighbors(of faceIndex: Int) -> [Int]
```

- **Parameters:** `faceIndex`, 0-based index into `nodes`.
- **Returns:** Array of neighbor face indices; empty if `faceIndex` is out of range.
- **Example:**
  ```swift
  let aag = Shape.box(width: 10, height: 10, depth: 5)!.buildAAG()
  let neighbors = aag.neighbors(of: 0)
  // A box face has 4 adjacent neighbors
  ```

---

### `edge(between:and:)`

Returns the `AAGEdge` between two faces, if they are adjacent.

```swift
public func edge(between face1: Int, and face2: Int) -> AAGEdge?
```

- **Parameters:** `face1`, first face index; `face2`, second face index.
- **Returns:** The `AAGEdge` describing their shared boundary, or `nil` if they are not adjacent or the index is out of range.
- **Example:**
  ```swift
  if let e = aag.edge(between: 0, and: 1) {
      print(e.convexity)  // .convex for an external box edge
  }
  ```

---

### `concaveNeighbors(of:)`

Returns the face indices of all neighbors connected to this face via concave edges.

```swift
public func concaveNeighbors(of faceIndex: Int) -> [Int]
```

Pocket floors are typically surrounded by concave-edge neighbors (vertical walls). Returns empty if `faceIndex` is out of range.

- **Parameters:** `faceIndex`, 0-based face index.
- **Returns:** Indices of neighbor faces where the shared edge is classified `.concave`.
- **Example:**
  ```swift
  let pocketFloor = 2
  let walls = aag.concaveNeighbors(of: pocketFloor)
  ```

---

### `convexNeighbors(of:)`

Returns the face indices of all neighbors connected to this face via convex edges.

```swift
public func convexNeighbors(of faceIndex: Int) -> [Int]
```

- **Parameters:** `faceIndex`, 0-based face index.
- **Returns:** Indices of neighbor faces where the shared edge is classified `.convex`.

---

#### Private implementation helpers

Not part of the public API; documented for completeness since they carry the actual graph-build and pocket/wall analysis behind `init(shape:)` and `detectPockets(tolerance:)`.

```swift
```
- **Example:**
  ```swift
  ```

```swift
```

```swift
```

```swift
```

```swift
```

```swift
```

```swift
```

```swift
```
---
## PocketFeature

A recognized pocket feature detected from the AAG.

```swift
public struct PocketFeature: Sendable {
    public let floorFaceIndex: Int
    public let wallFaceIndices: [Int]
    public let zLevel: Double
    public let bounds: (min: SIMD3<Double>, max: SIMD3<Double>)
    public let isOpen: Bool
    public var depth: Double
}
```

### `floorFaceIndex`

0-based index of the upward-facing horizontal face identified as the pocket floor.

```swift
public let floorFaceIndex: Int
```

- **Note:** An **occurrence** index, resolving against `Shape.orientedFaces()` and **not**
  `Shape.faces()` (#642). Before #642 it indexed `faces()`; the two differ on a compound whose
  solids share a face, where indexing `faces()` with it gives the wrong face or an out-of-range
  index, silently. Read `aag.nodes[pocket.floorFaceIndex].distinctFaceIndex` for the old identity.

```swift
let aag = shape.buildAAG()
for pocket in shape.detectPocketsAAG() {
    let floor = shape.orientedFaces()[pocket.floorFaceIndex]   // correct
    let distinct = aag?.nodes[pocket.floorFaceIndex].distinctFaceIndex
    print(floor.area, distinct as Any)
}
```

---

### `wallFaceIndices`

0-based indices of the vertical faces that form the pocket walls.

```swift
public let wallFaceIndices: [Int]
```

- **Note:** **Occurrence** indices into `Shape.orientedFaces()`, on the same footing as
  `floorFaceIndex` (#642).

---

### `zLevel`

Z coordinate of the pocket floor plane.

```swift
public let zLevel: Double
```

---

### `bounds`

Axis-aligned bounding box of the pocket (floor + walls combined).

```swift
public let bounds: (min: SIMD3<Double>, max: SIMD3<Double>)
```

`bounds.min.z` equals `zLevel`; `bounds.max.z` is the height of the tallest wall.

---

### `isOpen`

Whether the pocket's wall loop leaves a gap in the floor's own boundary.

```swift
public let isOpen: Bool
```

Tested per edge, not by counting walls: the pocket is enclosed exactly when every edge of the floor's **outer** wire is an edge of one of the covering faces (the walls, plus any fillet or chamfer absorbed at a junction), matched by structural identity (`TopoDS_Shape::IsSame`). A slot that opens at the side of a part has a floor boundary edge that borders no covering face, so it reports `true`.

The wall count is not the test and never was a sufficient one (#735): a blind cylindrical bore has exactly one wall and is fully enclosed, while an open three-sided slot and a closed triangular pocket both have three. An inner wire (an island on the floor, e.g. a boss) never enters the test, so a boss's own wall cannot mask a gap in the outer boundary (#753). #777 changed only how membership is looked up, reading the covering faces' own edges once per pocket instead of asking the whole shape which faces bound each boundary edge. The verdict is unchanged wherever solid membership can be established, which is every ordinary solid and every compound `AAG.solidGroups` can partition; see `Scripts/repro/777-pocket-isopen/` for the one compound shape where it could differ and why that difference lands on the better answer.

---

### `depth`

Approximate depth of the pocket: `bounds.max.z - zLevel`.

```swift
public var depth: Double
```

Pure-Swift computed property; no bridge call.

---

## Feature Recognition Extensions (AAG)

These methods extend `AAG` with higher-level feature detection.

### `AAG.detectPockets(tolerance:)`

Detects pocket features in the shape by AAG analysis.

```swift
public func detectPockets(tolerance: Double = defaultFloorRestsOnWallTolerance) -> [PocketFeature]
```

A pocket is identified when: (1) an upward-facing, horizontal, planar face exists as the floor; (2) tracing outward from that floor, at least one true vertical wall is reached, either directly via a concave edge or through a filleted or chamfered floor/wall junction absorbed along the way (#762, below); (3) each directly-reached wall's own bounding-box minimum Z matches the floor's Z within `tolerance` (#724), meaning the wall must actually rest ON that floor, not merely open past it. (A wall reached only after absorbing a junction face skips this check, since the junction itself is what bottoms out at the floor's Z, not the wall's own remaining planar remnant.) Results are sorted by ascending `zLevel` (deepest pocket first).

**A filleted or chamfered junction is absorbed, not reclassified (#762).** Before this fix, condition (2) required a DIRECT concave neighbor. Nearly every real machined pocket has a filleted floor/wall junction, since an endmill cannot cut a sharp internal corner, so `detectPocketsAAG()` could not see the pockets anyone would actually machine. `ChFi3d::DefineConnectType` is not wrong to call a fillet junction `.smooth` (a fillet is G1-continuous with both faces it blends, so there is no local sign to read at either new edge); the pocket's concavity moved into the fillet FACE's own curvature, not its edges. The fix traces outward through:

- a `.concave` edge into a non-wall face (a chamfer, unconditionally: its own two new edges are still `.concave`, just planar at an intermediate angle that fails the wall's own vertical-face test), or
- a `.smooth` edge into a face confirmed to curve the right way: cylindrical, conical or spherical, with its own outward normal pointing back toward its axis (radially inward), the same material-side test `detectHoles()` uses to tell a bore from a boss. This refuses to cross into an ordinary convex exterior rounding (radially outward) or an unrelated, incidentally-tangent planar pair.

Each absorbed junction face is tracked separately from the true walls it leads to: `PocketFeature.wallFaceIndices` still reports only the true (vertical) walls, unchanged in meaning, but the pocket's bounds and its open/enclosed test both use walls UNION absorbed junctions, since a junction's own extent reaches past where the trimmed wall now starts, and the floor's own outer-wire boundary borders the junction face, not the far wall, whenever one is interposed.

Requirement (4) exists because a wall's own exterior opening can satisfy (1)-(3) too: the exterior
surface a pocket opens through is upward-facing, horizontal and planar exactly like the real floor,
and its rim edge to the wall can classify concave in the same cases a real floor's does (a curved
wall's rim commonly does, prior to #723's replacement of `OCCTEdgeGetConvexity`'s formula). Without
(4), a single blind cylindrical pocket reported **two** pockets: the real floor at the bottom of
the bore, and the box's own top face at the wall's other end, for what is physically one cavity. A
floor is always the low end of the walls that rise from it; a wall's high end is where it opens,
never where it floors. This does not depend on any edge's classification being correct, only on
the floor actually sitting at the bottom of its own walls, which is a geometric fact independent of
#723.

```swift
let box  = Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20)!
let tool = Shape.cylinder(at: .zero, direction: SIMD3(0, 0, 1), radius: 4, height: 20)!
let cut  = box.subtracting(tool)!
print(cut.detectPocketsAAG().count)   // 1, not 2 (#724)
```

The comparison in (4) reads `AAGNode.bounds`, which is always the wall's exact-geometry bounding
box (`Face.exactBounds`), never the mesh-enlarged one `Face.bounds` can return once a shape has
been meshed, so a prior call to `Shape.mesh(...)`/`meshWithProgress(...)` does not change the
result (#733).

- **Parameters:**
  - `tolerance`: how close (model units) a wall's own low-Z bound must come to a candidate floor's
    Z to count as resting on it. Defaults to `defaultFloorRestsOnWallTolerance` (1e-4). Not a fixed
    constant (#733): a shape modeled at a different scale than millimeters may need a different
    value.
- **Returns:** Array of `PocketFeature` values, sorted deepest-first.
- **Example:**
  ```swift
  let part = Shape.box(width: 20, height: 20, depth: 10)!
  let aag = part.buildAAG()
  let pockets = aag.detectPockets()
  for p in pockets {
      print("floor \(p.floorFaceIndex), depth \(p.depth), open: \(p.isOpen)")
  }
  ```

---

### `AAG.defaultFloorRestsOnWallTolerance`

The default value of `detectPockets(tolerance:)`'s `tolerance` parameter (#733).

```swift
public static let defaultFloorRestsOnWallTolerance: Double  // 1e-4
```

Public so a caller who widens or narrows the tolerance can still express it relative to the
library's own default rather than hardcoding `1e-4` again.

---

### `AAG.detectHoles()`

Detects cylindrical or conical bore features (through or blind) by the wall's own geometry.

```swift
public func detectHoles() -> [(faceIndex: Int, radius: Double, depth: Double)]
```

**Rewritten in #747; the criterion is not neighbor convexity any more.** The original criterion,
requiring every neighbor to connect via a concave edge, was written against a convexity formula (pre-#723)
that sometimes misclassified a curved rim as concave when it geometrically should not be. Under
the correct classifier that criterion is unsatisfiable for either ordinary hole shape: a
through-hole's wall has **zero** concave neighbors (both rims are convex), and a blind hole's wall
has exactly **one** out of two (the floor, not the rim where it opens), so "all neighbors concave"
reported zero holes for both, the two shapes anyone would actually drill.

A hole is now identified by the wall's own intrinsic shape, independent of what borders it:

1. `Face.surfaceType` is `.cylinder` or `.cone` (a countersink/counterbore transition is conical).
2. **Closed in U by its own seam**: the wall wraps a full 2π around its axis
   (`face.uvBounds`), not partially, so a fillet (a partial revolve) is excluded.
3. **Material lies radially outside the wall** (`AAG.isMaterialRadiallyInward(of:revolution:uv:)`):
   a hole is a void, so the face's own outward normal points back toward the axis. A boss or a
   standalone cylinder has the identical surface type and the identical closed-in-U shape,
   sometimes even the identical zero-concave-neighbor signature, but its material fills the
   inside, so its normal points *away* from the axis. This is the only test that tells the two
   apart; neighbor convexity cannot.

None of this assumes a vertical axis: `radius` and `depth` are read from the wall's own measured
axis (`Face.revolutionProperties`, `Face.point(atU:v:)`) rather than a Z-aligned bounding box, so a
hole bored on any axis, or a pipe's bore (material lies radially outside its inner wall; a pipe's
*outer* wall is correctly excluded, since material there lies radially inside), reports correctly.

- **Returns:** Array of `(faceIndex, radius, depth)` tuples. `radius` is the wall's own measured
  revolution radius (`Face.revolutionProperties`), not a bounding-box estimate. `depth` is measured
  along the wall's own axis between its two V-bound points, not `bounds.max.z - bounds.min.z`.
- **Note:** `faceIndex` is an **occurrence** index into `Shape.orientedFaces()`, not `Shape.faces()`
  (#642), matching `AAGNode.faceIndex`. A hole's face is rarely shared between two solids, so the
  two usually coincide, but only the occurrence index is correct here.
- **Example:**
  ```swift
  let box  = Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20)!
  let tool = Shape.cylinder(at: .zero, direction: SIMD3(0, 0, 1), radius: 4, height: 20)!
  let blind = box.subtracting(tool)!
  print(blind.buildAAG().detectHoles().count)   // 1 (was 0 before #747)

  let tool2 = Shape.cylinder(at: SIMD3(0, 0, -15), direction: SIMD3(0, 0, 1), radius: 4, height: 30)!
  let through = box.subtracting(tool2)!
  print(through.buildAAG().detectHoles().count) // 1 (was 0 before #747)
  ```

---

## Shape Extension. Feature Recognition

### `Shape.buildAAG()`

Constructs an Attributed Adjacency Graph for this shape.

```swift
public func buildAAG() -> AAG
```

Convenience wrapper around `AAG(shape: self)`. The graph's nodes are face occurrences (`Shape.orientedFaces()`), not distinct faces (`Shape.faces()`): a face shared by two solids in a compound is two nodes, one per owning solid, each with that solid's own normal (#642).

- **Returns:** A fully built `AAG` for the receiver.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 5)!
  let aag = box.buildAAG()
  print(aag.nodes.count)   // 6, one per face, nothing shared
  ```

---

### `Shape.detectPocketsAAG(tolerance:)`

Detects pockets using AAG-based feature recognition.

```swift
public func detectPocketsAAG(tolerance: Double = AAG.defaultFloorRestsOnWallTolerance) -> [PocketFeature]
```

Equivalent to `buildAAG().detectPockets(tolerance:)`. Selects on each node's `isUpward`, `isHorizontal` and `isPlanar`, which `buildAAG()` derives per face occurrence, so the result no longer depends on a compound's member order (#642): before that fix, a face shared between two solids in a compound could report a different pocket count depending only on which order the solids were compounded in, for identical geometry. #699 closed a second, independent source of the same symptom: `concaveNeighbors(of:)` (which `detectPockets()` reads to find candidate walls) used to include neighbors from a *different* solid than the floor's own, which could make the result order-dependent on a fixture #642 alone did not fix (a vertical, rather than horizontal, two-solid split) and could inflate the count with a wall that was never really adjacent to that floor in either solid.

- **Parameters:** `tolerance`: forwarded to `AAG.detectPockets(tolerance:)`; see its doc.
- **Returns:** Array of `PocketFeature` values, sorted deepest-first.
- **Example:**
  ```swift
  let pockets = myPart.detectPocketsAAG()
  for pocket in pockets {
      print("Z=\(pocket.zLevel), depth=\(pocket.depth)")
  }
  ```

---

## MedialAxisNode

A node in the medial axis graph, representing a point on the skeleton with an associated inscribed-circle radius.

```swift
public struct MedialAxisNode: Sendable {
    public let index: Int32
    public let position: SIMD2<Double>
    public let distance: Double
    public let isPending: Bool
    public let isOnBoundary: Bool
}
```

- `index`: 1-based index within the `MAT_Graph`.
- `position`: 2D coordinates of the node in the plane of the face.
- `distance`: distance to the nearest boundary curve (inscribed-circle radius at this node). Half of local wall thickness.
- `isPending`: `true` if the node has only one linked arc (a skeleton endpoint). Wraps `MAT_Node::PendingNode`.
- `isOnBoundary`: `true` if the node lies on the shape boundary. Wraps `MAT_Node::OnBasicElt`.

---

### `MedialAxisNode.isPending`

`true` if the node has only one linked arc, i.e. a skeleton endpoint. Wraps `MAT_Node::PendingNode`.

### `MedialAxisNode.isOnBoundary`

`true` if the node lies on the shape boundary. Wraps `MAT_Node::OnBasicElt`.

---

## MedialAxisArc

An arc in the medial axis graph, connecting two nodes along a bisector curve.

```swift
public struct MedialAxisArc: Sendable {
    public let index: Int32
    public let geomIndex: Int32
    public let firstNodeIndex: Int32
    public let secondNodeIndex: Int32
    public let firstElementIndex: Int32
    public let secondElementIndex: Int32
}
```

- `index`: 1-based index within the `MAT_Graph`.
- `geomIndex`: geometry index referencing the bisector curve in the `BRepMAT2d_BisectingLocus`.
- `firstNodeIndex` / `secondNodeIndex`, 1-based indices of the endpoint nodes.
- `firstElementIndex` / `secondElementIndex`, 1-based indices of the boundary elements (input edges) the arc bisects.

---

### `secondElementIndex`

---

## MedialAxis

Medial axis (Voronoi skeleton) of a planar face. Computes the locus of centers of maximal inscribed circles within a 2D profile using `BRepMAT2d_BisectingLocus`.

### `MedialAxis.init?(of:)`

Computes the medial axis of the first planar face found in `shape`.

```swift
public init?(of shape: Shape)
```

Extracts the first face via `TopExp_Explorer`, runs `BRepMAT2d_Explorer::Perform` on it, then calls `BRepMAT2d_BisectingLocus::Compute` with `MAT_Left` side and `GeomAbs_Arc` join type. Returns `nil` if no face is found, the computation does not complete, or the resulting graph has no arcs.

There is no tolerance: neither `BRepMAT2d_Explorer::Perform` nor `BRepMAT2d_BisectingLocus::Compute` accepts one. `Compute`'s own knobs are `LineIndex`, `aSide`, `aJoinType` and `IsOpenResult`, all fixed here at OCCT's defaults; exposing any of them would be a new capability.

- **Parameters:** `shape`, a shape containing at least one face.
- **Returns:** `nil` if computation fails or the shape has no faces.
- **OCCT:** `BRepMAT2d_Explorer::Perform` + `BRepMAT2d_BisectingLocus::Compute` + `MAT_Graph`.
- **Example:**
  ```swift
  let rect = Shape.face(
      from: Wire.polygon3D([
          SIMD3(0, 0, 0), SIMD3(10, 0, 0),
          SIMD3(10, 4, 0), SIMD3(0, 4, 0)
      ], closed: true)!
  )!
  if let ma = MedialAxis(of: rect) {
      print("Arcs: \(ma.arcCount), nodes: \(ma.nodeCount)")
  }
  ```

---

## Graph Counts

### `arcCount`

Number of bisector arcs in the medial axis graph.

```swift
public var arcCount: Int { get }
```

- **OCCT:** `MAT_Graph::NumberOfArcs`.

---

### `nodeCount`

Number of nodes (arc endpoints) in the medial axis graph.

```swift
public var nodeCount: Int { get }
```

- **OCCT:** `MAT_Graph::NumberOfNodes`.

---

### `basicElementCount`

Number of boundary elements (input edges) used in the computation.

```swift
public var basicElementCount: Int { get }
```

- **OCCT:** `BRepMAT2d_BisectingLocus` basic element count via `MAT_Graph`.

---

## Node Access

### `MedialAxis.node(at:)`

Returns a node by its 1-based index.

```swift
public func node(at index: Int) -> MedialAxisNode?
```

- **Parameters:** `index`, 1-based node index (1…`nodeCount`).
- **Returns:** `MedialAxisNode`, or `nil` if the index is out of range or the graph is null.
- **OCCT:** `MAT_Graph::Node` + `BRepMAT2d_BisectingLocus::GeomElt(node)`.
- **Example:**
  ```swift
  if let ma = MedialAxis(of: face), let n = ma.node(at: 1) {
      print(n.position, n.distance)
  }
  ```

---

### `nodes`

All nodes in the graph.

```swift
public var nodes: [MedialAxisNode] { get }
```

Iterates 1-based indices 1…`nodeCount` via `node(at:)`.

- **Returns:** Array of all `MedialAxisNode` values; empty if the graph has no nodes.
- **Example:**
  ```swift
  if let ma = MedialAxis(of: face) {
      let minDist = ma.nodes.map { $0.distance }.min() ?? 0
      print("Min inscribed radius: \(minDist)")
  }
  ```

---

## Arc Access

### `MedialAxis.arc(at:)`

Returns an arc by its 1-based index.

```swift
public func arc(at index: Int) -> MedialAxisArc?
```

- **Parameters:** `index`, 1-based arc index (1…`arcCount`).
- **Returns:** `MedialAxisArc`, or `nil` if the index is out of range or the graph is null.
- **OCCT:** `MAT_Graph::Arc`.
- **Example:**
  ```swift
  if let ma = MedialAxis(of: face), let a = ma.arc(at: 1) {
      print(a.firstNodeIndex, a.secondNodeIndex)
  }
  ```

---

### `arcs`

All arcs in the graph.

```swift
public var arcs: [MedialAxisArc] { get }
```

Iterates 1-based indices 1…`arcCount` via `arc(at:)`.

- **Returns:** Array of all `MedialAxisArc` values; empty if the graph has no arcs.

---

## Distance / Thickness

### `minThickness`

Minimum inscribed circle radius across all nodes. Represents half of the minimum wall thickness.

```swift
public var minThickness: Double { get }
```

- **Returns:** Minimum `distance` value across all nodes, or `-1` if the computation fails.
- **OCCT:** `OCCTMedialAxisMinThickness`, iterates all `MAT_Node` positions, computes distance to nearest boundary curve via `Geom2dAPI_ProjectPointOnCurve`, returns the minimum.
- **Example:**
  ```swift
  if let ma = MedialAxis(of: thinWallPart) {
      let halfThickness = ma.minThickness
      print("Min wall thickness ≈ \(halfThickness * 2)")
  }
  ```

---

### `distanceToBoundary(arcIndex:parameter:)`

Interpolated inscribed-circle radius along an arc at a given parameter.

```swift
public func distanceToBoundary(arcIndex: Int, parameter t: Double) -> Double
```

Samples a point on the arc's bisector curve at parameter `t` and computes the distance to the nearest boundary element via `Geom2dAPI_ProjectPointOnCurve`.

- **Parameters:** `arcIndex`, 1-based arc index; `t`, parameter in [0, 1] (0 = first node, 1 = second node).
- **Returns:** Inscribed circle radius at the sampled point, or `-1` on error.
- **OCCT:** `BRepMAT2d_BisectingLocus::GeomBis` + `Geom2d_TrimmedCurve::Value` + `Geom2dAPI_ProjectPointOnCurve`.
- **Example:**
  ```swift
  if let ma = MedialAxis(of: face) {
      let radiusMid = ma.distanceToBoundary(arcIndex: 1, parameter: 0.5)
  }
  ```

---

## Drawing

### `drawArc(at:maxPoints:)`

Samples points along a single bisector arc for visualization.

```swift
public func drawArc(at index: Int, maxPoints: Int = 32) -> [SIMD2<Double>]
```

Evaluates the arc's bisector curve (`BRepMAT2d_BisectingLocus::GeomBis`) at uniformly spaced parameters. Infinite curve parameters are clamped to ±1000.

- **Parameters:** `index`, 1-based arc index; `maxPoints`, sample points *requested* (default 32), honoured within `2...Sampling.maximumSampleCount` (10,000,000); outside that range the result is empty (#558). The name says capacity but the contract is a request: the bridge samples the arc at exactly `maxPoints` evenly-spaced parameters and always returns that many, so an unservable count is rejected rather than clamped, clamping would hand back a coarser sampling than asked for.
- **Returns:** Array of 2D points along the arc; empty on error.
- **OCCT:** `MAT_Graph::Arc` + `BRepMAT2d_BisectingLocus::GeomBis` + `Geom2d_TrimmedCurve::Value`.
- **Example:**
  ```swift
  if let ma = MedialAxis(of: face) {
      let pts = ma.drawArc(at: 1, maxPoints: 20)
      for pt in pts { print(pt) }
  }
  ```

---

### `drawAll(maxPointsPerArc:)`

Samples points along all bisector arcs, returning one polyline per arc.

```swift
public func drawAll(maxPointsPerArc: Int = 32) -> [[SIMD2<Double>]]
```

Calls `OCCTMedialAxisDrawAll` which fills a flat XY buffer and per-arc start/length arrays in one pass. More efficient than calling `drawArc(at:)` in a loop.

- **Parameters:** `maxPointsPerArc`, sample points *requested* per arc (default 32), at least 2. The bound is on the total: `arcCount * maxPointsPerArc` must not exceed `Sampling.maximumSampleCount` (10,000,000), else the result is empty; `maxPointsPerArc` is checked on its own too, since a negative count on a graph with no arcs multiplies to a plausible total (#558).
- **Returns:** Array of polylines, one per arc; empty if `arcCount == 0`.
- **OCCT:** `BRepMAT2d_BisectingLocus::GeomBis` (per arc) + `Geom2d_TrimmedCurve::Value`.
- **Example:**
  ```swift
  if let ma = MedialAxis(of: face) {
      let skeleton = ma.drawAll()
      for polyline in skeleton {
          // render each bisector arc as a 2D polyline
          print(polyline.count, "points")
      }
  }
  ```
