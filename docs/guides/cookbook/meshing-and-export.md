---
title: Meshing & Export
parent: Cookbook
nav_order: 7
---

# Meshing & Export

A B-Rep solid is exact analytic geometry. To render it, 3D-print it, or hand it to a mesh pipeline you
**tessellate** it into triangles; to round-trip it through CAD you **export** the exact B-Rep. This
page covers both.

## Tessellating a shape

`mesh(linearDeflection:angularDeflection:)` triangulates the shape. **Linear deflection** is the max
chord deviation (mm), smaller = finer; **angular deflection** caps the angle between adjacent facet
normals (radians):

```swift
let box = Shape.box(width: 10, height: 5, depth: 3)!
guard let mesh = box.mesh(linearDeflection: 0.1) else { return }

mesh.vertexCount          // Int
mesh.triangleCount        // Int
mesh.vertices             // [SIMD3<Float>]
mesh.normals              // [SIMD3<Float>] (per-vertex, outward, unit length)
mesh.indices              // [UInt32], every 3 = one triangle
// indices.count == triangleCount * 3
```

`BRepMesh_IncrementalMesh` stores no node normals, so `normals` is computed at mesh time by
`BRepLib_ToolTriangulatedShape::ComputeNormals`, the same call `StdPrs_ShadedShape` makes before
shading: from the surface itself where the triangulation has UV nodes, and from the average of the
incident triangle normals where it does not. Before #2337 every entry was `(0, 0, 1)`. That call
writes the normals onto the shape's own triangulation as well as into the `Mesh`, so
`Shape.computeNormals()` has nothing left to do afterwards and reports `0` (#2905).

The `Mesh` also exposes `boundingBox`, `size`, `center`, raw interleaved `vertexData`/`normalData`
(ready for a GPU buffer), and `trianglesWithFaces()`, per-triangle access that carries the **source
B-Rep face index** and a per-triangle normal, so you can map a picked triangle back to its face.

For fine-grained control, mesh from a `MeshParameters`:

```swift
var params = MeshParameters.default
params.deflection = 0.05
params.inParallel = true       // multi-threaded
let fine = box.mesh(parameters: params)
```

Deflection is a quality/size trade-off:

| Use case | linear deflection |
|---|---|
| Quick preview | 0.5 |
| FDM print (0.2 mm layers) | 0.1 |
| Fine FDM (0.1 mm) | 0.05 |
| SLA / display-quality | 0.02 |

### The deflection floor, and what a degenerate value does

Every linear deflection this library takes has a floor of **`1e-7`**, OCCT's `Precision::Confusion()`.
It is OCCT's bound rather than ours: `BRepMesh_IncrementalMesh::initParameters` throws below it, the
`incmesh` DRAW command clamps its `LinDefl` argument up to it, and `Prs3d::GetDeflection`, which is
the presentation path, applies the same floor to the value it derives from a relative coefficient.

A value below the floor, a negative one, and **NaN** are all refused, and a refusal is the same `nil`
(or empty result) the call already gives a shape it cannot mesh. NaN is the reason the check exists:
`NaN < x` is false, so OCCT's own test lets it through, and a NaN deflection on a curved solid does
not return.

```swift
let cyl = Shape.cylinder(radius: 10, height: 5)!
cyl.mesh(linearDeflection: 0)         // nil
cyl.mesh(linearDeflection: -1)        // nil
cyl.mesh(linearDeflection: .nan)      // nil
cyl.edgeMesh(deflection: .nan)        // nil
```

A *small* deflection is expensive rather than invalid and is not refused. On a radius-10 cylinder,
measured against the pinned kernel: `1e-4` meshes in about a second, `1e-5` in five, `1e-6` in
seventy and the floor itself, `1e-7`, in ninety, at 88,862 nodes. Choose the number for the job.

### The angular floor

The **angular** deflection beside it has its own floor, **`1e-12`**, OCCT's `Precision::Angular()`,
and the same hole: `initParameters` tests it with `Angle < Precision::Angular()`, which NaN passes.
Zero, negative and sub-floor values already threw and came back as `nil`; NaN did not. It neither
threw nor hung. It returned a mesh, built as though there were no angular criterion at all, because
every comparison against NaN is false.

Measured on a radius-10 cylinder at a linear deflection of `10.0`, where the angle is the criterion
that decides the tessellation (`Scripts/repro/2900/`): `0.05` and `0.2` give 254 nodes, `0.5` gives
106, `1.0` gives 54, and NaN gives **18**, with `IsDone()` true and no status flag. So it is
refused for the same reason the linear value is, and the refusal is the same `nil`.

```swift
let cyl = Shape.cylinder(radius: 10, height: 5)!
cyl.mesh(linearDeflection: 0.1, angularDeflection: .nan)   // nil
cyl.mesh(linearDeflection: 0.1, angularDeflection: 0)      // nil
cyl.mesh(linearDeflection: 0.1, angularDeflection: 0.5)    // a mesh
```

`MeshParameters.angleInterior` needs no floor of its own: `0` means "use `angle`", and OCCT
replaces anything below the floor with `2 x angle`. Nor does a `DisplayDrawer`:
`Prs3d_Drawer::DeviationAngle()` answers 20 degrees for any value that is not positive, NaN
included, so a degenerate angle set on a drawer never reaches the mesher.

## Mesh → shape

A triangle mesh can be lifted back to a B-Rep (a shell of planar faces). The **weld tolerance** must
scale with the model size, too tight leaves the mesh unwelded:

```swift
let shape = mesh.toShape(weldTolerance: 1e-6)   // raise for large-coordinate meshes
```

The result is a shell/compound of planar facets, not necessarily a valid solid; run
[healing](healing-and-validity.md) if you need one.

## Exporting

Two families: **tessellated** formats (STL/OBJ/PLY, triangles, take a deflection) and **exact** B-Rep
formats (STEP/IGES/BREP, full analytic geometry). All `Exporter.write…` calls throw.

```swift
// tessellated (deflection controls facet density)
try Exporter.writeSTL(shape: box, to: stlURL, deflection: 0.05)        // binary by default
try Exporter.writeSTL(shape: box, to: stlURL, deflection: 0.05, ascii: true)
try Exporter.writeOBJ(shape: box, to: objURL, deflection: 0.1)
try Exporter.writePLY(shape: box, to: plyURL, deflection: 0.1)

// exact B-Rep
try Exporter.writeSTEP(shape: box, to: stepURL)
try Exporter.writeIGES(shape: box, to: igesURL, unit: "MM")
try Exporter.writeBREP(shape: box, to: brepURL)                        // native OCCT, full precision

// glTF / GLB (mesh + materials, for the web / model-viewer)
try Exporter.writeGLTF(shape: box, to: glbURL)                 // GLB (binary: true by default)
try Exporter.writeGLTF(shape: box, to: gltfURL, binary: false) // text .gltf
```

Instance methods mirror the statics where handy: `box.writeSTL(to:deflection:)`,
`box.writeSTEP(to:modelType:)`, `box.writeIGES(to:unit:)`.

## Importing

```swift
let step = try Shape.load(from: stepURL)            // STEP (also Shape.loadSTEP)
let iges = try Shape.loadIGES(from: igesURL)        // loadIGESRobust heals tolerance issues
let brep = try Shape.loadBREP(from: brepURL)        // exact + triangulation if exported with it
let stl  = try Shape.loadSTLRobust(from: stlURL, sewingTolerance: 1e-6)   // auto sew + heal; compound if multibody
```

For mesh formats prefer the **robust** loaders (`loadSTLRobust`), they sew and heal the seams a raw
triangle soup carries. Loaders throw `ImportError` on failure.

## STEP round-trip

```swift
try Exporter.writeSTEP(shape: model, to: stepURL, modelType: .asIs)
let reimported = try Shape.load(from: stepURL)
// reimported.isValid == true
```

For multi-part assemblies with structure/colors, export the **document**, not a flattened shape, see
[XCAF Assemblies](xcaf-assemblies.md) and `Exporter.writeSTEPAssembly(_:to:)`. To shrink a STEP with
shared geometry, `Exporter.optimizeSTEP(input:output:)` deduplicates it.

## See also

- [XCAF Assemblies](xcaf-assemblies.md), structured STEP with parts, colors, instances.
- [Healing & Validity](healing-and-validity.md), clean up after `mesh.toShape` or an STL import.
- API mapping: [`../../API_REFERENCE.md`](../../API_REFERENCE.md)
