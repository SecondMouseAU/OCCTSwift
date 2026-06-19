---
title: Working with Meshes
parent: Cookbook
nav_order: 12
---

# Working with Meshes

A `Mesh` is OCCTSwift's triangle-soup value type — vertices, per-vertex normals, and triangle
indices. [Meshing & Export](meshing-and-export.md) covers how to *get* one (tessellate a shape) and
how to write it to a file; this page is about **operating on the `Mesh` itself**: building one,
inspecting it, mesh-level booleans, mapping triangles back to B-Rep faces, lifting it back to a solid,
and feeding it to a renderer.

## Build a mesh from your own arrays

You don't have to start from a `Shape` — construct a `Mesh` directly from vertex and index arrays
(indices are flat, three per triangle). Omit `normals` and they're computed for you:

```swift
// an octahedron
let v: [SIMD3<Float>] = [
    SIMD3(0, 0, 1), SIMD3(1, 0, 0), SIMD3(0, 1, 0),
    SIMD3(-1, 0, 0), SIMD3(0, -1, 0), SIMD3(0, 0, -1),
]
let idx: [UInt32] = [0,1,2, 0,2,3, 0,3,4, 0,4,1,  5,2,1, 5,3,2, 5,4,3, 5,1,4]
guard let mesh = Mesh(vertices: v, indices: idx) else { return }   // normals auto-computed
```

The init returns `nil` if the arrays are inconsistent (empty, `indices.count % 3 != 0`, an out-of-range
index, or a `normals` count that doesn't match `vertices`).

<script type="module" src="https://cdn.jsdelivr.net/npm/@google/model-viewer/dist/model-viewer.min.js"></script>

<table>
<tr>
<td align="center"><model-viewer src="models/mesh-octahedron.glb" poster="images/mesh-octahedron.png" camera-controls auto-rotate environment-image="neutral" exposure="1.1" shadow-intensity="1" style="width:320px;height:320px;background:#eef1f5;border-radius:6px"></model-viewer><br>An octahedron built from 6 vertices + 8 triangles</td>
</tr>
</table>

## Inspect it

```swift
mesh.vertexCount        // Int
mesh.triangleCount      // Int
mesh.vertices           // [SIMD3<Float>]
mesh.normals            // [SIMD3<Float>] (per-vertex)
mesh.indices            // [UInt32] — 3 per triangle
mesh.vertexData         // [Float] — interleaved xyz, ready for a GPU buffer
mesh.normalData         // [Float] — interleaved xyz

mesh.boundingBox        // (min: SIMD3<Float>, max: SIMD3<Float>)
mesh.size               // max − min
mesh.center
```

## Triangles ↔ B-Rep faces (picking)

`trianglesWithFaces()` gives per-triangle access that carries the **source B-Rep face index** and a
per-triangle normal — so when a user picks a triangle on screen you can recover which face of the
original solid they hit:

```swift
for tri in mesh.trianglesWithFaces() {
    // tri.v1 / tri.v2 / tri.v3 : UInt32 vertex indices
    // tri.faceIndex : Int32 — the B-Rep face this triangle came from
    // tri.normal    : SIMD3<Float>
}
```

## Mesh-level booleans

When you only have meshes (or want to avoid B-Rep booleans), combine them directly. The `deflection`
controls the tessellation of the result:

```swift
guard let a = Shape.box(width: 12, height: 12, depth: 12)?.mesh(linearDeflection: 0.3),
      let b = Shape.cylinder(at: SIMD3(6, 6, -1), direction: SIMD3(0, 0, 1),
                             radius: 3, height: 14)?.mesh(linearDeflection: 0.3) else { return }

let cut   = a.subtracting(b, deflection: 0.3)     // box with a drilled hole
let join  = a.union(with: b, deflection: 0.3)
let common = a.intersection(with: b, deflection: 0.3)
```

These are convenient for triangle data, but they work on tessellations — for exact, valid solids
prefer the B-Rep [booleans](booleans.md) and mesh the result at the end.

## Mesh → B-Rep

Lift a triangle mesh back to a shell of planar faces. The **weld tolerance** must scale with the model
size (too tight and the mesh stays unwelded):

```swift
let shape = mesh.toShape(weldTolerance: 1e-6)   // raise for large-coordinate meshes
```

The result is a faceted shell, not necessarily a valid solid — run [healing](healing-and-validity.md)
if you need one. (For an STL on disk, prefer `Shape.loadSTLRobust`, which sews + heals as it loads.)

## Hand it to a renderer

`Mesh` converts straight to the platform 3D types (each guarded by `#if canImport`, so they're
available where the framework is):

```swift
#if canImport(SceneKit)
let geometry = mesh.sceneKitGeometry()             // SCNGeometry
let node     = mesh.sceneKitNode()                 // SCNNode (optional material)
#endif

// raw Metal buffers (positions / normals / indices as Data)
let (positions, normals, indices) = mesh.metalBufferData()
```

There's also **RealityKit** interop — `mesh.realityKitMeshResource()` (`MeshResource`) and
`mesh.realityKitModelEntity()` (`ModelEntity`), both `throws`. They're `@MainActor`-isolated and gated
to macOS 15+ / iOS 18+ (RealityKit's `LowLevelMesh`), so call them from the main actor inside an
`if #available` check.

## See also

- [Meshing & Export](meshing-and-export.md) — tessellate a `Shape` and write STL / OBJ / glTF.
- [Healing & Validity](healing-and-validity.md) — clean up a shell from `mesh.toShape`.
- The [OCCTSwiftMesh](https://github.com/gsdali/OCCTSwiftMesh) package adds decimation, smoothing, and repair on top of this `Mesh` type.
