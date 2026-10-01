---
title: Mesh
parent: API Reference
---

# Mesh

A `Mesh` is a triangulated surface representation, vertices, per-vertex normals, and triangle
indices, produced by tessellating a `Shape` or built directly from raw arrays. It is the bridge
between OCCT's exact B-Rep geometry and renderers (SceneKit, RealityKit, Metal) and mesh file
formats (STL, OBJ, PLY). Obtain one by calling `Shape.mesh(linearDeflection:)` or
`Shape.mesh(parameters:)`, or construct one from your own `vertices`/`indices` arrays with
`Mesh.init(vertices:normals:indices:)`.

## Topics

- [Initializers](#initializers) · [Mesh Data](#mesh-data) · [Statistics](#statistics) · [Triangle Access with Face Info](#triangle-access-with-face-info) · [Mesh to Shape Conversion](#mesh-to-shape-conversion) · [Mesh Boolean Operations](#mesh-boolean-operations) · [SceneKit Integration](#scenekit-integration) · [Metal Integration](#metal-integration) · [RealityKit Integration](#realitykit-integration) · [Supporting Types](#supporting-types)

---

## Initializers

### `Mesh.init(vertices:normals:indices:)`

Constructs a `Mesh` directly from raw vertex-position and triangle-index arrays.

```swift
public convenience init?(
    vertices: [SIMD3<Float>],
    normals: [SIMD3<Float>]? = nil,
    indices: [UInt32]
)
```

Use this when you have vertex/index data from an external algorithm (decimation, smoothing,
repair, remeshing, OBJ/STL/glTF import) and no B-Rep source. For meshes derived from OCCT
shapes, use `Shape.mesh()` instead. When `normals` is `nil`, per-vertex normals are computed
by averaging the face normals of adjacent triangles (smooth shading).

- **Parameters:**
  - `vertices`: per-vertex positions; must not be empty.
  - `normals`: optional per-vertex normals; if provided must have the same count as `vertices`.
    Pass `nil` to auto-compute smooth normals from triangle adjacency.
  - `indices`: triangle index triples; length must be a multiple of 3, every value `< vertices.count`.
- **Returns:** `nil` if any input is empty, `indices.count % 3 != 0`, a normal-count mismatch
  exists, or any index is out of bounds.
- **OCCT:** Pure-Swift validation; data is stored in the C `OCCTMesh` struct via
  `OCCTMeshCreateFromArrays`.
- **Example:**
  ```swift
  // Octahedron, normals auto-computed
  let v: [SIMD3<Float>] = [
      SIMD3(0, 0, 1), SIMD3(1, 0, 0), SIMD3(0, 1, 0),
      SIMD3(-1, 0, 0), SIMD3(0, -1, 0), SIMD3(0, 0, -1),
  ]
  let idx: [UInt32] = [0,1,2, 0,2,3, 0,3,4, 0,4,1, 5,2,1, 5,3,2, 5,4,3, 5,1,4]
  guard let mesh = Mesh(vertices: v, indices: idx) else { return }
  ```

---

```swift
```
---
## Mesh Data

### `vertexCount`

The number of vertices in the mesh.

```swift
public var vertexCount: Int { get }
```

- **Returns:** Count of distinct vertex positions.
- **OCCT:** `OCCTMeshGetVertexCount`, returns `vertices.size() / 3` from the internal float buffer.
- **Example:**
  ```swift
  let mesh = Shape.box(width: 10, height: 5, depth: 3)!.mesh(linearDeflection: 0.1)!
  print(mesh.vertexCount)
  ```

---

### `triangleCount`

The number of triangles in the mesh.

```swift
public var triangleCount: Int { get }
```

- **Returns:** Count of triangles; equals `indices.count / 3`.
- **OCCT:** `OCCTMeshGetTriangleCount`, returns `indices.size() / 3` from the internal index buffer.
- **Example:**
  ```swift
  print(mesh.triangleCount)
  // indices.count == mesh.triangleCount * 3
  ```

---

### `vertices`

Vertex positions as an array of `SIMD3<Float>`.

```swift
public var vertices: [SIMD3<Float>] { get }
```

Each element is the 3D position of one vertex. Array length equals `vertexCount`.

- **Returns:** Position array; `[]` if the mesh is empty.
- **OCCT:** `OCCTMeshGetVertices`, copies the internal contiguous float buffer, then repackages
  into `SIMD3`.
- **Example:**
  ```swift
  for p in mesh.vertices {
      print(p.x, p.y, p.z)
  }
  ```

---

### `normals`

Per-vertex normals as an array of `SIMD3<Float>`.

```swift
public var normals: [SIMD3<Float>] { get }
```

Each normal is a unit vector perpendicular to the surface at that vertex. Array length equals
`vertexCount`.

`BRepMesh_IncrementalMesh` does **not** compute node normals: `Poly_Triangulation::HasNormals()` is
false for every face it meshes and nothing else has touched. They are computed when the mesh is
built, by
`BRepLib_ToolTriangulatedShape::ComputeNormals`, which takes the normal from the surface itself
(`GeomLib::NormEstim` at the node's UV) where UV nodes exist and from the average of the incident
triangle normals where they do not. That is what OCCT's own consumers do: `StdPrs_ShadedShape.cxx:186`
calls the same function immediately before shading, and `RWMesh_FaceIterator`, the glTF/OBJ/PLY export
path, computes its own. For array-constructed meshes the normals are averaged from triangle adjacency,
or taken verbatim when supplied.

The sense matches OCCT's shaded presentation: outward for a solid built the usual way, reversed for a
face whose orientation is `REVERSED`, and reversed again under a mirroring `TopLoc_Location`, which is
how a shape carrying one shades as the inside-out solid it is.

Until #2337 this returned `(0, 0, 1)` at every vertex of every meshed shape: the bridge pushed a
placeholder wherever `HasNormals()` was false, which was always. `(0, 0, 1)` is still reported for a
node whose incident triangles all cancel, which is OCCT's own answer for a normal it cannot define
(`Poly_Triangulation.cxx:472`) and needs a degenerate triangulation to reach.

`ComputeNormals` is a **write**, not a read: it calls `AddNormals()` on the handle
`BRep_Tool::Triangulation` hands back, so building a `Mesh` leaves the normals stored on the shape
as well. That is why `Shape.computeNormals()` reports `0` for a shape that has been through
`mesh(...)`: there is nothing left for it to do (#2905).

- **Returns:** Normal array; `[]` if the mesh is empty.
- **OCCT:** `OCCTMeshGetNormals`, copies the internal normal float buffer; the values come from
  `BRepLib_ToolTriangulatedShape::ComputeNormals` during `OCCTShapeCreateMesh`.
- **Example:**
  ```swift
  let mesh = Shape.sphere(radius: 5)!.mesh(linearDeflection: 0.5)!
  for (vertex, normal) in zip(mesh.vertices, mesh.normals) {
      // On a sphere centred on the origin the normal is the vertex direction.
      print(simd_normalize(vertex), normal)
  }
  ```

---

### `indices`

Triangle indices as an array of `UInt32`.

```swift
public var indices: [UInt32] { get }
```

Every three consecutive values define one triangle referencing vertices at those positions in
`vertices`. Array length equals `triangleCount * 3`.

- **Returns:** Index array; `[]` if the mesh has no triangles.
- **OCCT:** `OCCTMeshGetIndices`, copies the internal index buffer.
- **Example:**
  ```swift
  let idx = mesh.indices
  // Triangle 0: idx[0], idx[1], idx[2]
  // Triangle 1: idx[3], idx[4], idx[5]
  ```

---

### `vertexData`

Raw vertex positions as a contiguous `[Float]` interleaved array.

```swift
public var vertexData: [Float] { get }
```

Format: `[x0, y0, z0, x1, y1, z1, …]`. Length is `vertexCount * 3`. Ready for direct upload
to a GPU buffer without repackaging.

- **Returns:** Flat float array; `[]` if the mesh is empty.
- **OCCT:** `OCCTMeshGetVertices`, same buffer copy as `vertices`, without `SIMD3` wrapping.
- **Example:**
  ```swift
  let (positions, normals, indices) = mesh.metalBufferData()
  // positions is equivalent to Data(mesh.vertexData.withUnsafeBytes { … })
  ```

---

### `normalData`

Raw per-vertex normals as a contiguous `[Float]` interleaved array.

```swift
public var normalData: [Float] { get }
```

Format: `[nx0, ny0, nz0, nx1, ny1, nz1, …]`. Length is `vertexCount * 3`. Pair with
`vertexData` and `indices` for zero-copy GPU uploads.

- **Returns:** Flat float array; `[]` if the mesh is empty.
- **OCCT:** `OCCTMeshGetNormals`, same buffer copy as `normals`, without `SIMD3` wrapping.
- **Example:**
  ```swift
  let posData = Data(bytes: mesh.vertexData, count: mesh.vertexData.count * 4)
  let nrmData = Data(bytes: mesh.normalData, count: mesh.normalData.count * 4)
  ```

---

## Statistics

### `boundingBox`

Axis-aligned bounding box of the mesh.

```swift
public var boundingBox: (min: SIMD3<Float>, max: SIMD3<Float>) { get }
```

Computed by iterating all vertex positions using Swift `min`/`max` component-wise reduction.

- **Returns:** `(min, max)` corner tuple; `(.zero, .zero)` if the mesh is empty.
- **OCCT:** Pure-Swift, iterates `vertices`.
- **Example:**
  ```swift
  let (lo, hi) = mesh.boundingBox
  print("X span:", hi.x - lo.x)
  ```

---

### `size`

Extent of the mesh in each dimension.

```swift
public var size: SIMD3<Float> { get }
```

Computed as `boundingBox.max − boundingBox.min`.

- **Returns:** Width, height, depth of the AABB.
- **OCCT:** Pure-Swift, delegates to `boundingBox`.
- **Example:**
  ```swift
  let s = mesh.size   // SIMD3(width, height, depth)
  ```

---

### `center`

Centre point of the mesh bounding box.

```swift
public var center: SIMD3<Float> { get }
```

Computed as `(boundingBox.min + boundingBox.max) / 2`.

- **Returns:** Centroid of the AABB.
- **OCCT:** Pure-Swift, delegates to `boundingBox`.
- **Example:**
  ```swift
  let c = mesh.center
  ```

---

## Triangle Access with Face Info

### `trianglesWithFaces()`

Returns all triangles with their source B-Rep face index and per-triangle normal.

```swift
public func trianglesWithFaces() -> [Triangle]
```

Provides richer data than `indices` alone: each `Triangle` carries `v1`/`v2`/`v3` vertex
indices, a `faceIndex` identifying which B-Rep face this triangle was tessellated from (−1 if
unknown, e.g. from `Mesh.init(vertices:normals:indices:)`), and a `normal` vector. Use for
B-Rep-face-aware picking, CAM operations that need to reason per face, or custom per-triangle
shading.

- **Returns:** Array of `Triangle` structs; `[]` if the mesh has no triangles.
- **OCCT:** `OCCTMeshGetTrianglesWithFaces`, reads the internal `faceIndices` and
  `triangleNormals` arrays alongside the index buffer.
- **Example:**
  ```swift
  for tri in mesh.trianglesWithFaces() {
      // tri.v1 / tri.v2 / tri.v3 : UInt32 vertex indices
      // tri.faceIndex : Int32 (source B-Rep face, or -1)
      // tri.normal    : SIMD3<Float>
  }
  ```

---

## Mesh to Shape Conversion

### `toShape(weldTolerance:)`

Converts this mesh back to a B-Rep `Shape` by sewing triangle faces into a shell.

```swift
public func toShape(weldTolerance: Double = 1e-6) -> Shape?
```

Each triangle becomes a planar B-Rep face; `BRepBuilderAPI_Sewing` merges shared edges within
`weldTolerance` to produce a connected shell. The resulting shape is a shell (or compound of
planar faces), not necessarily a valid manifold solid, run shape healing if you need one. The
weld tolerance must scale with the mesh's coordinate magnitude: a value too small for a
large-coordinate mesh leaves edges unmerged and yields an open shell.

- **Parameters:** `weldTolerance`, vertex-merge tolerance in model units (default `1e-6`; raise
  for large-coordinate meshes). Must be positive.
- **Returns:** A `Shape` representing the tessellated geometry, or `nil` if the mesh is empty,
  weldTolerance is ≤ 0, or sewing fails.
- **OCCT:** `OCCTMeshToShapeWithTolerance` → `BRepBuilderAPI_MakeEdge` + `BRepBuilderAPI_MakeFace`
  per triangle + `BRepBuilderAPI_Sewing::Perform`.
- **Example:**
  ```swift
  let shape = mesh.toShape(weldTolerance: 1e-6)   // raise for large-coordinate meshes
  ```
- **Note:** For an STL file on disk, prefer `Shape.loadSTLRobust(from:sewingTolerance:)` which
  sews and heals as it loads. The result of `toShape` is a faceted shell, run
  [healing](../guides/cookbook/healing-and-validity.md) if you need a valid solid.

---

## Mesh Boolean Operations

**These three are Booleans on surfaces, not on volumes.** `toShape(weldTolerance:)` sews the triangles
into a `TopAbs_SHELL`, and `BOPAlgo_BOP` takes the dimension of its arguments
(`BOPAlgo_BOP.cxx:145-150`), so a Boolean on two shells is the Boolean of two two-dimensional objects.
The results are not the volume operations, and #2301 measured all three:

| Operation | Inputs, deflection 0.5 | Mesh Boolean result | Volume operation |
|---|---|---|---|
| `union(with:)` | two 10-cubes overlapping over half their width | 72 triangles, encloses 2000 | 1500 |
| `subtracting(_:)` | 10-cube minus cylinder r3 h15 | 120 triangles, encloses 1000 (nothing removed) | 858.63 |
| `intersection(with:)` | 10-cube and sphere r7 | **0 triangles**, not `nil` | 959.23 |

OCCT has no mesh Boolean of its own, and it never promotes a tessellated shell to a solid: its own
mesh-to-shape path, `StlAPI_Reader::Read` through `BRepBuilderAPI_MakeShapeOnMesh`, builds a compound
of planar faces and stops, and `BRepBuilderAPI_MakeSolid` has no production caller anywhere in OCCT's
source tree. The promotion is therefore the caller's decision, and `Shape.solid(from:)` is where it
lives:

```swift
// The volume operations, on the same sewn shells.
let a = Shape.solid(from: meshA.toShape()!)!
let b = Shape.solid(from: meshB.toShape()!)!
let fused = a.union(b)!.mesh(linearDeflection: 0.5)!
let drilled = a.subtracting(b)!.mesh(linearDeflection: 0.5)!
let common = a.intersection(b)!.mesh(linearDeflection: 0.5)!
```

The inputs are tessellations either way, so the volumes that route returns are the faceted
approximations of the exact ones: 1500 exactly for two boxes, and about 860 and 948 for the cylinder
and sphere cases above, where the exact B-Rep answers are 858.63 and 959.23.

### `union(with:deflection:)`

Boolean union with another mesh, on the sewn surfaces.

```swift
public func union(with other: Mesh, deflection: Double = 0.1) -> Mesh?
```

Both meshes are sewn into shells (`BRepBuilderAPI_Sewing`), `BRepAlgoAPI_Fuse` is run on those shells,
and the result is re-tessellated at `deflection`. The walls where the two bodies overlap survive
instead of being consumed, which is why the enclosed volume double-counts the overlap.

- **Parameters:** `other`, mesh to add; `deflection`, linear deflection for re-tessellating
  the result (default `0.1`).
- **Returns:** Re-meshed surface union, or `nil` if the sewing or the Boolean failed.
- **OCCT:** `OCCTMeshUnion` → `BRepBuilderAPI_Sewing` + `BRepAlgoAPI_Fuse` +
  `BRepMesh_IncrementalMesh`.
- **Example:**
  ```swift
  guard let a = Shape.box(width: 12, height: 12, depth: 12)?.mesh(linearDeflection: 0.3),
        let b = Shape.cylinder(at: SIMD3(6, 6, -1), direction: SIMD3(0, 0, 1),
                               radius: 3, height: 14)?.mesh(linearDeflection: 0.3)
  else { return }
  let joinedSurfaces = a.union(with: b, deflection: 0.3)
  ```

---

### `subtracting(_:deflection:)`

Subtracts another mesh from this one, on the sewn surfaces.

```swift
public func subtracting(_ other: Mesh, deflection: Double = 0.1) -> Mesh?
```

Both meshes are sewn into shells, `BRepAlgoAPI_Cut` is run on those shells, and the result is
re-tessellated at `deflection`. Cutting a surface with a surface splits this mesh's faces where the
other mesh's surface crosses them; it removes no volume, because neither argument has one.

- **Parameters:** `other`, mesh to subtract; `deflection`, linear deflection for
  re-tessellating the result.
- **Returns:** Re-meshed surface difference, or `nil` if the sewing or the Boolean failed.
- **OCCT:** `OCCTMeshSubtract` → `BRepBuilderAPI_Sewing` + `BRepAlgoAPI_Cut` +
  `BRepMesh_IncrementalMesh`.
- **Example:**
  ```swift
  // Splits the box's faces along the cylinder's surface. To drill the hole, use the
  // Shape.solid(from:) route above.
  let split = a.subtracting(b, deflection: 0.3)
  ```

---

### `intersection(with:deflection:)`

Intersects this mesh with another mesh, on the sewn surfaces.

```swift
public func intersection(with other: Mesh, deflection: Double = 0.1) -> Mesh?
```

Both meshes are sewn into shells, `BRepAlgoAPI_Common` is run on those shells, and the result is
re-tessellated at `deflection`. Two surfaces meet along curves, so the Boolean produces edges, and
edges have nothing to triangulate: the usual result is an **empty** mesh, which is not `nil`.

- **Parameters:** `other`, mesh to intersect with; `deflection`, linear deflection for
  re-tessellating the result.
- **Returns:** Re-meshed surface intersection, empty whenever the two surfaces meet only along
  curves, or `nil` if the sewing or the Boolean failed.
- **OCCT:** `OCCTMeshIntersect` → `BRepBuilderAPI_Sewing` + `BRepAlgoAPI_Common` +
  `BRepMesh_IncrementalMesh`.
- **Example:**
  ```swift
  // Check the count: an empty result is a successful surface intersection, not a failure.
  if let common = a.intersection(with: b, deflection: 0.3), common.triangleCount > 0 {
      // ...
  }
  ```

---

## SceneKit Integration

Available on macOS / iOS where SceneKit is importable (`#if canImport(SceneKit)`). These
members are pure-Swift and do not call the OCCT bridge.

---

### `sceneKitGeometry()`

Creates an `SCNGeometry` from this mesh.

```swift
public func sceneKitGeometry() -> SCNGeometry
```

Packages `vertexData` and `normalData` into `SCNGeometrySource` objects (float, 3 components,
stride 12 bytes) and `indices` into an `SCNGeometryElement` with `.triangles` primitive type.
Apply materials separately before adding to a scene.

- **Returns:** `SCNGeometry` with vertex and normal sources; returns an empty `SCNGeometry` if
  the mesh has no vertices.
- **OCCT:** Pure-Swift, reads `vertexData`, `normalData`, `indices`.
- **Example:**
  ```swift
  let geometry = mesh.sceneKitGeometry()
  let material = SCNMaterial()
  material.diffuse.contents = UIColor.gray
  material.metalness.contents = 0.8
  geometry.materials = [material]
  let node = SCNNode(geometry: geometry)
  scene.rootNode.addChildNode(node)
  ```

---

### `sceneKitNode(material:)`

Creates an `SCNNode` with this mesh and an optional material applied.

```swift
public func sceneKitNode(material: SCNMaterial? = nil) -> SCNNode
```

Convenience wrapper: calls `sceneKitGeometry()`, optionally assigns `material`, then wraps in
an `SCNNode`.

- **Parameters:** `material`, optional material; `nil` leaves the geometry with no applied material.
- **Returns:** `SCNNode` ready to add to a scene.
- **OCCT:** Pure-Swift, delegates to `sceneKitGeometry()`.
- **Example:**
  ```swift
  let node = mesh.sceneKitNode(material: myMaterial)
  scene.rootNode.addChildNode(node)
  ```

---

## Metal Integration

### `metalBufferData()`

Returns vertex positions, normals, and indices as raw `Data` objects ready for Metal buffers.

```swift
public func metalBufferData() -> (positions: Data, normals: Data, indices: Data)
```

All three `Data` objects are interleaved-float (`Float`, 4 bytes each component). Use with
`MTLDevice.makeBuffer(bytes:length:options:)`. Stride for positions and normals is 12 bytes
(3 × `Float`); index buffer uses `UInt32` (4 bytes each).

- **Returns:** Named tuple of `(positions: Data, normals: Data, indices: Data)`.
- **OCCT:** Pure-Swift, repackages `vertexData`, `normalData`, `indices` into `Data`.
- **Example:**
  ```swift
  let (positions, normals, indices) = mesh.metalBufferData()
  let vertexBuffer = device.makeBuffer(
      bytes: (positions as NSData).bytes,
      length: positions.count,
      options: .storageModeShared
  )
  ```

---

## RealityKit Integration

Available on macOS 15+ / iOS 18+ where RealityKit is importable (`#if canImport(RealityKit)`).
All three methods are `@MainActor`-isolated (call from the main actor inside an `if #available`
guard).

---

### `realityKitMeshResource()`

Creates a `MeshResource` from this mesh.

```swift
@available(iOS 18.0, macOS 15.0, *)
@MainActor
public func realityKitMeshResource() throws -> MeshResource
```

Builds a `MeshDescriptor` from `vertices` (positions), `normals`, and `indices`, then calls
`MeshResource.generate(from:)`. Returns an empty `MeshResource` if the mesh has no vertices.

- **Returns:** A `MeshResource` suitable for a RealityKit `ModelEntity`.
- **Throws:** RealityKit errors from `MeshResource.generate(from:)` if the descriptor is invalid.
- **OCCT:** Pure-Swift, reads `vertices`, `normals`, `indices`.
- **Note:** `@MainActor`-isolated and gated to macOS 15 / iOS 18; call from the main actor inside
  `if #available(macOS 15, iOS 18, *)`.
- **Example:**
  ```swift
  if #available(macOS 15, iOS 18, *) {
      let meshResource = try await MainActor.run {
          try mesh.realityKitMeshResource()
      }
      let material = SimpleMaterial(color: .gray, isMetallic: true)
      let entity = ModelEntity(mesh: meshResource, materials: [material])
  }
  ```

---

### `realityKitModelEntity(material:)`

Creates a `ModelEntity` from this mesh with a specified material.

```swift
@available(iOS 18.0, macOS 15.0, *)
@MainActor
public func realityKitModelEntity(material: RealityKit.Material) throws -> ModelEntity
```

Calls `realityKitMeshResource()` then constructs `ModelEntity(mesh:materials:)`.

- **Parameters:** `material`, any `RealityKit.Material` to apply.
- **Returns:** `ModelEntity` ready to add to a RealityKit scene.
- **Throws:** Propagates errors from `realityKitMeshResource()`.
- **OCCT:** Pure-Swift, delegates to `realityKitMeshResource()`.
- **Note:** `@MainActor`-isolated, macOS 15 / iOS 18 only.
- **Example:**
  ```swift
  if #available(macOS 15, iOS 18, *) {
      let entity = try await MainActor.run {
          try mesh.realityKitModelEntity(
              material: SimpleMaterial(color: .blue, isMetallic: true)
          )
      }
      content.add(entity)
  }
  ```

---

### `realityKitModelEntity()`

Creates a `ModelEntity` from this mesh with a default gray metallic material.

```swift
@available(iOS 18.0, macOS 15.0, *)
@MainActor
public func realityKitModelEntity() throws -> ModelEntity
```

Convenience overload: applies `SimpleMaterial(color: .gray, isMetallic: true)` and delegates to
`realityKitModelEntity(material:)`.

- **Returns:** `ModelEntity` with a gray metallic appearance.
- **Throws:** Propagates errors from `realityKitMeshResource()`.
- **OCCT:** Pure-Swift, delegates to `realityKitModelEntity(material:)`.
- **Note:** `@MainActor`-isolated, macOS 15 / iOS 18 only.
- **Example:**
  ```swift
  if #available(macOS 15, iOS 18, *) {
      let entity = try await MainActor.run {
          try mesh.realityKitModelEntity()
      }
  }
  ```

---

## Supporting Types

### `MeshParameters`

Fine-grained tessellation parameters for `Shape.mesh(parameters:)`.

```swift
public struct MeshParameters: Sendable {
    public var deflection: Double
    public var angle: Double
    public var deflectionInterior: Double
    public var angleInterior: Double
    public var minSize: Double
    public var relative: Bool
    public var inParallel: Bool
    public var internalVertices: Bool
    public var controlSurfaceDeflection: Bool
    public var adjustMinSize: Bool
    public var allowQualityDecrease: Bool
    public static var `default`: MeshParameters { get }
}
```

All fields correspond directly to `IMeshTools_Parameters` in OCCT's `BRepMesh_IncrementalMesh`
API. Start from `MeshParameters.default` (suitable for interactive display) and adjust as
needed.

| Field | Default | Meaning |
|---|---|---|
| `deflection` | `0.1` | Max chord deviation on boundary edges (model units) |
| `angle` | `0.5` rad | Max angle between adjacent facets on boundary edges |
| `deflectionInterior` | `0` | Interior face deflection (0 = same as `deflection`) |
| `angleInterior` | `0` | Interior face angle (0 = same as `angle`) |
| `minSize` | `0` | Minimum element size (0 = no minimum) |
| `relative` | `false` | If `true`, deflection is a proportion of edge length |
| `inParallel` | `true` | Multi-threaded meshing |
| `internalVertices` | `true` | Generate vertices inside faces, not just on edges |
| `controlSurfaceDeflection` | `true` | Validate surface approximation quality |
| `adjustMinSize` | `false` | Auto-adjust minSize from edge size |
| `allowQualityDecrease` | `false` | Allow replacing an existing finer triangulation with a coarser one |

- **OCCT:** `IMeshTools_Parameters` + `BRepMesh_IncrementalMesh`.
- **Example:**
  ```swift
  var params = MeshParameters.default
  params.deflection = 0.05   // fine mesh
  params.inParallel = true
  let mesh = shape.mesh(parameters: params)
  ```
- **Note:** `allowQualityDecrease` (added in issue #211): when re-meshing an already-tessellated
  shape at a different deflection, OCCT keeps the existing mesh if it's "good enough" unless this
  is `true`. Set it when the new deflection must actually take effect.

---

#### `MeshParameters.allowQualityDecrease`

Allow replacing an existing finer triangulation with a coarser one.

- **OCCT:** `IMeshTools_Parameters` + `BRepMesh_IncrementalMesh`.
- **Example:**
  ```swift
  var params = MeshParameters.default
  params.deflection = 0.05   // fine mesh
  params.inParallel = true
  let mesh = shape.mesh(parameters: params)
  ```
- **Note:** `allowQualityDecrease` (added in issue #211): when re-meshing an already-tessellated
  shape at a different deflection, OCCT keeps the existing mesh if it's "good enough" unless this
  is `true`. Set it when the new deflection must actually take effect.

---

```swift
```
---
### `Triangle`

A mesh triangle with B-Rep face association and per-triangle normal.

```swift
public struct Triangle: Sendable {
    public let v1: UInt32
    public let v2: UInt32
    public let v3: UInt32
    public let faceIndex: Int32
    public let normal: SIMD3<Float>
}
```

Returned by `Mesh.trianglesWithFaces()`. The `faceIndex` is the 0-based index of the B-Rep
face this triangle was tessellated from (−1 for meshes constructed directly from arrays), in the
`Shape.faces()` enumeration, so `shape.face(at: Int(tri.faceIndex))` always resolves. Use
`faceIndex` to correlate a picked triangle back to the original solid face for CAM or selection
operations.

On a shape where one face is shared by two solids, that face is meshed **twice**, once per owner,
each wound so its normals point out of that owner, and both sets of triangles carry the one index
that names it. `faceIndex` values are therefore not unique per face. Before #613 this was the
position in a `TopExp_Explorer` walk instead, which on a two-solid split compound ran 0…11 over an
11-face shape, so a triangle could claim a `faceIndex` that `face(at:)` could not address.

- **Fields:**
  - `v1`, `v2`, `v3`, vertex indices into `Mesh.vertices`.
  - `faceIndex`: source B-Rep face index; −1 if unknown.
  - `normal`: per-triangle surface normal (computed from the cross product of two edges).

---

### `Polygon2D`

A wrapper around `Poly_Polygon2D`: a standalone 2D polygon (sequence of 2D nodes with a deflection value), independent of `Mesh`'s own triangulation. Used for pcurve tessellation data attached to an edge, separately from the 3D triangle mesh above.

```swift
public final class Polygon2D: @unchecked Sendable
```

```swift
```
---
### `PolygonOnTriangulation`

A wrapper around `Poly_PolygonOnTriangulation`: a polygon defined as a sequence of node indices into a shared `Triangulation`, rather than owning its own point positions.

```swift
public final class PolygonOnTriangulation: @unchecked Sendable
```

```swift
```