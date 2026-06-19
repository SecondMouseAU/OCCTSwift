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
chord deviation (mm) — smaller = finer; **angular deflection** caps the angle between adjacent facet
normals (radians):

```swift
let box = Shape.box(width: 10, height: 5, depth: 3)!
guard let mesh = box.mesh(linearDeflection: 0.1) else { return }

mesh.vertexCount          // Int
mesh.triangleCount        // Int
mesh.vertices             // [SIMD3<Float>]
mesh.normals              // [SIMD3<Float>] (per-vertex)
mesh.indices              // [UInt32] — every 3 = one triangle
// indices.count == triangleCount * 3
```

The `Mesh` also exposes `boundingBox`, `size`, `center`, raw interleaved `vertexData`/`normalData`
(ready for a GPU buffer), and `trianglesWithFaces()` — per-triangle access that carries the **source
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

## Mesh → shape

A triangle mesh can be lifted back to a B-Rep (a shell of planar faces). The **weld tolerance** must
scale with the model size — too tight leaves the mesh unwelded:

```swift
let shape = mesh.toShape(weldTolerance: 1e-6)   // raise for large-coordinate meshes
```

The result is a shell/compound of planar facets — not necessarily a valid solid; run
[healing](healing-and-validity.md) if you need one.

## Exporting

Two families: **tessellated** formats (STL/OBJ/PLY — triangles, take a deflection) and **exact** B-Rep
formats (STEP/IGES/BREP — full analytic geometry). All `Exporter.write…` calls throw.

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
let iges = try Shape.loadIGES(from: igesURL)        // loadIGESRobust sews/heals tolerance issues
let brep = try Shape.loadBREP(from: brepURL)        // exact + triangulation if exported with it
let stl  = try Shape.loadSTLRobust(from: stlURL, sewingTolerance: 1e-6)   // auto sew + heal
```

For mesh formats prefer the **robust** loaders (`loadSTLRobust`) — they sew and heal the seams a raw
triangle soup carries. Loaders throw `ImportError` on failure.

## STEP round-trip

```swift
try Exporter.writeSTEP(shape: model, to: stepURL, modelType: .asIs)
let reimported = try Shape.load(from: stepURL)
// reimported.isValid == true
```

For multi-part assemblies with structure/colors, export the **document**, not a flattened shape — see
[XCAF Assemblies](xcaf-assemblies.md) and `Exporter.writeSTEPAssembly(_:to:)`. To shrink a STEP with
shared geometry, `Exporter.optimizeSTEP(input:output:)` deduplicates it.

## See also

- [XCAF Assemblies](xcaf-assemblies.md) — structured STEP with parts, colors, instances.
- [Healing & Validity](healing-and-validity.md) — clean up after `mesh.toShape` or an STL import.
- API mapping: [`../../API_REFERENCE.md`](../../API_REFERENCE.md)
