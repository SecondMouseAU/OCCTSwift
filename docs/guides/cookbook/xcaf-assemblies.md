---
title: XCAF Assemblies
parent: Cookbook
nav_order: 8
---

# XCAF Assemblies

A single `Shape` is one body. Real CAD data is an **assembly** — a tree of named, colored,
instanced parts. OCCTSwift models that with a `Document` (OCCT's XCAF/OCAF document), which preserves
product structure, per-part colors and materials, and instancing across a STEP round-trip.

## Create a document and add shapes

```swift
guard let doc = Document.create() else { return }

let box = Shape.box(width: 10, height: 20, depth: 30)!
let sphere = Shape.sphere(radius: 5)!

let boxId    = doc.addShape(box)      // -> Int64 label id (-1 on failure)
let sphereId = doc.addShape(sphere)
```

`addShape` returns an `Int64` **label id** — a handle into the document tree, stable within that
`Document` instance.

## Build an assembly tree

An assembly is an empty label with **components** — instances of shape labels, each placed by a
transform. Instancing means a part stored once can appear many times (the file scales with unique
parts, not total placements):

```swift
let asmId = doc.newShapeLabel()       // an empty assembly label
let c1 = doc.addComponent(assemblyLabelId: asmId, shapeLabelId: boxId,
                          translation: (0, 0, 0))
let c2 = doc.addComponent(assemblyLabelId: asmId, shapeLabelId: sphereId,
                          translation: (50, 0, 0))
doc.componentCount(assemblyLabelId: asmId)   // 2
```

A component can also take a full rigid transform via `addComponent(assemblyLabelId:shapeLabelId:matrix:)`
(12-element row-major `[r00…r22, tx, ty, tz]`; returns `-1` if it isn't a proper rigid transform).

<script type="module" src="https://cdn.jsdelivr.net/npm/@google/model-viewer/dist/model-viewer.min.js"></script>

<table>
<tr>
<td align="center"><model-viewer src="models/xcaf-assembly.glb" poster="images/xcaf-assembly.png" camera-controls auto-rotate environment-image="neutral" exposure="1.1" shadow-intensity="1" style="width:340px;height:300px;background:#eef1f5;border-radius:6px"></model-viewer><br>A two-part assembly — each part its own color</td>
</tr>
</table>

## Traverse the tree

```swift
for node in doc.rootNodes {
    print(node.name ?? "unnamed", node.isAssembly)
    for child in node.children {
        if let shape = child.shape {           // includes the inherited placement transform
            let xform = child.transform        // simd_float4x4
            _ = (shape, xform)
        }
    }
}

// jump straight to a label by id
if let node = doc.node(at: boxId) { print(node.labelId) }
```

A node's surface: `labelId`, `name` (`String?`), `isAssembly` / `isReference`, `transform`,
`children`, `shape` (with transform applied; `nil` for a pure assembly), `shapeWithoutTransform`,
`color`, and `material`.

## Colors and materials

```swift
guard let node = doc.node(at: boxId) else { return }

node.setColor(Color(red: 0.30, green: 0.52, blue: 0.90))   // also Color(red255:…), .fromHex("#4C84E6")
if let c = node.color { print(c.red, c.green, c.blue) }

// PBR material (baseColor + metallic/roughness/emissive/transparency)
node.setMaterial(Material(baseColor: Color(red: 0.8, green: 0.2, blue: 0.1),
                          metallic: 0.9, roughness: 0.3))
if let m = node.material { print(m.metallic, m.roughness) }
```

## Load, inspect, export

```swift
// load a STEP assembly — structure, names, colors preserved
let doc = try Document.load(from: stepURL)
for root in doc.rootNodes {
    print(root.name ?? "—", root.color as Any)
}

// write it back out, structure intact
try Exporter.writeSTEPAssembly(doc, to: outURL)   // product-structured STEP
try doc.write(to: outURL)                          // same (STEP)
doc.writeGLTF(to: glbURL, binary: true)            // GLB for the web (returns Bool)
```

`writeSTEPAssembly` preserves the tree, component references, names and colors — and stores each
instanced part once. To flatten to a single body instead, pull `node.shape` and export that via the
plain [Exporter](meshing-and-export.md).

## See also

- [Meshing & Export](meshing-and-export.md) — single-shape export and the file formats.
- [Topology Graph](topology-graph.md) — structure *within* one shape (faces/edges), vs. the assembly tree across shapes.
- API mapping: [`../../API_REFERENCE.md`](../../API_REFERENCE.md)
