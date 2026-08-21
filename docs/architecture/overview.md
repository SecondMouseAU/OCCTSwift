---
title: Architecture
nav_order: 6
---

# OCCTSwift Architecture Overview

## Purpose

OCCTSwift provides a Swift-native interface to OpenCASCADE Technology (OCCT), a professional-grade B-Rep (Boundary Representation) solid modeling kernel. This enables iOS/macOS applications to perform CAD-level geometric operations that are impossible with SceneKit or RealityKit alone.

## Why This Exists

Apple's 3D frameworks (SceneKit, RealityKit) are designed for visualization and gaming, not CAD:

| Capability | SceneKit/RealityKit | OCCT |
|------------|---------------------|------|
| Boolean operations (CSG) | No | Yes |
| Sweep along curved path | No | Yes |
| NURBS curves/surfaces | No | Yes |
| STEP file export | No | Yes |
| 64-bit precision | No (32-bit only) | Yes |
| Filleting/chamfering | No | Yes |

OCCTSwift bridges this gap by using OCCT for geometry generation and Apple frameworks for visualization.

## Layer Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Swift Application                            │
│                 (RailwayCAD, or any CAD app)                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    OCCTSwift (Swift API)                         │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐     │
│  │  Shape    │  │   Wire    │  │   Mesh    │  │ Exporter  │     │
│  │           │  │           │  │           │  │           │     │
│  │ - box()   │  │ - rect()  │  │ - verts   │  │ - STL     │     │
│  │ - sweep() │  │ - arc()   │  │ - normals │  │ - STEP    │     │
│  │ - union() │  │ - bspline │  │ - indices │  │           │     │
│  └───────────┘  └───────────┘  └───────────┘  └───────────┘     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Swift calls Obj-C
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  OCCTBridge (Objective-C++)                      │
│                                                                  │
│  C-style functions with opaque handles:                          │
│  - OCCTShapeRef, OCCTWireRef, OCCTMeshRef                        │
│  - OCCTShapeCreateBox(), OCCTShapeUnion(), etc.                  │
│                                                                  │
│  Internally wraps OCCT C++ objects:                              │
│  - TopoDS_Shape, TopoDS_Wire, etc.                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ C++ calls
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                OpenCASCADE Technology (C++)                      │
│                                                                  │
│  Modules used:                                                   │
│  - TKernel, TKMath       (core utilities)                        │
│  - TKG2d, TKG3d          (2D/3D geometry)                        │
│  - TKBRep, TKTopAlgo     (B-Rep topology)                        │
│  - TKPrim                (primitive shapes)                      │
│  - TKBO                  (boolean operations)                    │
│  - TKFillet, TKOffset    (modifications)                         │
│  - TKMesh                (triangulation)                         │
│  - TKSTEP, TKSTL         (file export)                           │
└─────────────────────────────────────────────────────────────────┘
```

## Design Decisions

### 1. C-Style Bridge (not Objective-C Classes)

We use C functions with opaque pointers rather than Objective-C classes because:

- **Simpler memory model**: Explicit `OCCTShapeRelease()` avoids ARC/C++ destructor conflicts
- **No bridging overhead**: Direct function calls, no message dispatch
- **Easier to maintain**: Clear ownership semantics
- **Thread safety**: No hidden retain/release cycles

```c
// Bridge API uses opaque handles
typedef struct OCCTShape* OCCTShapeRef;
OCCTShapeRef OCCTShapeCreateBox(double w, double h, double d);
void OCCTShapeRelease(OCCTShapeRef shape);
```

### 2. Value Semantics in Swift (Internally Reference)

Swift `Shape` class wraps the handle and releases on deinit:

```swift
public final class Shape {
    internal let handle: OCCTShapeRef

    deinit {
        OCCTShapeRelease(handle)  // Clean C++ resources
    }
}
```

Operations return new `Shape` instances (immutable pattern):

```swift
let box = Shape.box(width: 10, height: 5, depth: 3)
let rounded = box.filleted(radius: 0.5)  // New shape, box unchanged
```

### 3. SIMD Types for Vectors

We use Swift's `SIMD3<Double>` for 3D points/vectors:

- Consistent with Apple frameworks
- Hardware-accelerated operations
- Clear semantics (vs tuple or array)

```swift
let offset = SIMD3<Double>(10, 0, 0)
let moved = shape.translated(by: offset)
```

### 4. Mesh as Separate Type

`Mesh` is distinct from `Shape` because:

- **Different data**: Shape is B-Rep topology; Mesh is triangles
- **One-way conversion**: Shape → Mesh (tessellation), not reversible
- **Different uses**: Mesh for display/export; Shape for operations

```swift
let shape = Shape.box(width: 10, height: 5, depth: 3)
let mesh = shape.mesh(linearDeflection: 0.1)  // Tessellate
let geometry = mesh.sceneKitGeometry()         // For display
```

### 5. Error Handling Strategy

OCCT operations can fail (e.g., self-intersecting boolean). Current strategy:

- Return empty/null shapes on failure (OCCT's default behavior)
- `isValid` property for validation
- `healed()` for repair attempts

Future consideration: Swift `throws` for explicit error handling.

### 6. The Bridge Is Internal: No Frozen C ABI

`OCCTBridge` is a *target*, not a product. `Package.swift` declares exactly one product,
`.library(name: "OCCTSwift")`.

**That does not make it unreachable, and this section said it did until #967 measured it.** Both of
these work from a consumer package that depends only on the `OCCTSwift` product:

- a Swift target writing `import OCCTBridge`, because `publicHeadersPath: "include"` and the
  hand-written `module.modulemap` in it travel along the transitive include path;
- a plain `.m` writing `#import "OCCTBridge.h"`, with no `.mm` and no C++17.

Both compile, link and run, printing the same `23.999999999999996` for a 2x3x4 box. The evidence is
[`Scripts/repro/967-consumer-compile/bridge-reach.txt`](https://github.com/SecondMouseAU/OCCTSwift/blob/main/Scripts/repro/967-consumer-compile/bridge-reach.txt),
regenerated by `measure-bridge-reach.sh` beside it.

Nothing about the contract changes, and being exact matters more than being reassuring. The C
surface in `OCCTBridge.h` carries no compatibility promise of its own: renaming, merging, or
deleting a bridge function is an internal refactor, and the only stability contract is the Swift
API's, governed by [`SEMVER.md`](../SEMVER.md). A consumer taking the C route is opting out of
that, deliberately, rather than being prevented from it by the package.

Two practical consequences:

- **A bridge function with no Swift caller is deleted, not retained.** "Keep it exported for C
  consumers" is not a reason this repo recognises, because the packaging gives it no C consumers to
  keep it for. Retaining one instead preserves whatever contract it had at the moment it was
  orphaned, which is how #506 came to hold three arc-length functions that still returned `0` on
  failure years after the Swift layer moved to a `-1.0` sentinel, and still extrapolated past a
  curve's knots after #477 fixed that everywhere reachable.
- **The published `OCCTBridge.xcframework` is a per-release artifact, not an ABI.** The
  `OCCTSWIFT_BRIDGE_PREBUILT=1` path (see `Package.swift`) resolves a version-pinned URL, so the
  binary and the headers of any one release stay self-consistent. That is reproducibility within a
  release, not a promise across releases.

## Memory Management

### OCCT Handles

OCCT uses reference-counted handles (`opencascade::handle<T>`). Our bridge:

1. Creates OCCT objects on the heap
2. Wraps in our struct containing the handle
3. Returns opaque pointer to Swift
4. Swift class releases via bridge function on deinit

```
Swift Shape        OCCTShape struct       OCCT Handle
┌──────────┐       ┌──────────────┐       ┌──────────────┐
│ handle ──┼──────►│ TopoDS_Shape │──────►│ Actual data  │
└──────────┘       └──────────────┘       └──────────────┘
     │                                           ▲
     │ deinit                                    │
     ▼                                           │
OCCTShapeRelease() ─── delete struct ─── releases handle
```

### Value views onto a handle

A handle is owned by exactly one reference type, whose `deinit` releases it. A value type has no
`deinit`, so it cannot own one, and a struct that stores a raw `OCCT*Ref` is borrowing a handle
whose lifetime it does not control. When such a value outlives the object it borrowed from, every
read through it is a use-after-free.

The nineteen `*Properties` views on `Curve2D`, `Curve3D` and `Surface` were written that way, which
made `edge.curve3D?.circleProperties.radius` crash: `Edge.curve3D` builds a fresh `Curve3D` per
read, nothing holds it past the expression, and its `deinit` runs before `.radius` (#965).

They now conform to `NativeHandleView` (`Sources/OCCTSwift/NativeHandleView.swift`), which stores
the owner and reads the handle through it:

```swift
public struct CircleProperties: Sendable, NativeHandleView {
    let owner: Curve3D                                       // strong, so the handle outlives it
    public var radius: Double { OCCTCurve3DCircleRadius(handle) }  // handle comes from `owner`
}
```

`Scripts/check-borrowed-handles.py` fails the build on any struct or enum in `Sources/OCCTSwift`
that stores an `OCCT*Ref`, so a new view cannot reintroduce the borrow.

### Thread Safety

- OCCT is not thread-safe for shared objects
- Each `Shape` should be used from one thread
- For concurrent operations, create separate shapes

## File Organization

```
OCCTSwift/
├── Package.swift               # SPM configuration
├── README.md                   # Quick start guide
├── Sources/
│   ├── OCCTSwift/              # Swift public API
│   │   ├── Shape.swift         # 3D shapes, booleans, modifications
│   │   ├── Wire.swift          # 2D/3D wire profiles and paths
│   │   ├── Face.swift          # Face surface analysis
│   │   ├── Edge.swift          # Edge curve analysis
│   │   ├── Curve2D.swift       # 2D parametric curves (Geom2d)
│   │   ├── Curve3D.swift       # 3D parametric curves (Geom)
│   │   ├── Surface.swift       # Parametric surfaces (Geom)
│   │   ├── Document.swift      # XDE assembly + OCAF
│   │   ├── Mesh.swift          # Triangulated mesh data
│   │   └── Exporter.swift      # Multi-format export
│   └── OCCTBridge/             # Objective-C++ bridge
│       ├── include/
│       │   ├── OCCTBridge.h                  # Umbrella: handle typedefs, class index, imports (#395)
│       │   └── OCCTBridge_<Domain>.h         # 15 per-domain C declaration files
│       └── src/
│           └── OCCTBridge_<Domain>.mm        # 16 files (15 domains + OCCTBridge.mm), OCCT C++ implementations
├── Libraries/
│   ├── OCCT.xcframework/       # Pre-built OCCT 8.0.0-rc5
│   └── OCCTBridge.xcframework/ # Pre-built bridge (DISABLED on the v2.0.0 line)
├── Scripts/
│   ├── build-occt.sh           # Build OCCT from source
│   └── build-occtbridge.sh     # Build the prebuilt OCCTBridge.xcframework
├── Tests/
│   └── OCCT<Domain>Tests/      # Per-domain Swift Testing targets (Analysis, Modeling, Surface, …)
└── docs/                       # Documentation
```

## Performance Considerations

### Expensive Operations

1. **Boolean operations**: O(n²) or worse; avoid in tight loops
2. **Meshing**: Depends on deflection; smaller = more triangles
3. **Sweep along complex path**: B-spline evaluation is costly

### Optimization Strategies

1. **Batch operations**: Build compound, then mesh once
2. **Cache meshes**: Don't re-mesh unchanged shapes
3. **Appropriate deflection**: 0.1mm for preview, 0.01mm for export
4. **Background threading**: Heavy operations off main thread

## Integration with SceneKit

Typical workflow:

```swift
// 1. Create geometry with OCCT
let rail = Shape.sweep(profile: railProfile, along: trackPath)

// 2. Tessellate for display
let mesh = rail.mesh(linearDeflection: 0.1)

// 3. Create SceneKit geometry
let geometry = mesh.sceneKitGeometry()
geometry.materials = [railMaterial]

// 4. Add to scene
let node = SCNNode(geometry: geometry)
scene.rootNode.addChildNode(node)
```

## Extension Points

### Adding New Shape Operations

1. Add C function declaration to the matching `OCCTBridge_<Domain>.h` (e.g. `OCCTBridge_Modeling.h`)
2. Implement in the matching `OCCTBridge_<Domain>.mm` using OCCT classes
3. Add Swift wrapper method to `Shape.swift`
4. Add tests and documentation

### Adding New Export Formats

1. Add export function to `OCCTBridge_IO.h`
2. Implement using OCCT's TKDExxx modules
3. Add Swift wrapper to `Exporter.swift`

### Adding New Wire/Curve Types

1. Add creation function to the matching `OCCTBridge_<Domain>.h`
2. Implement using OCCT's Geom/BRepBuilderAPI classes
3. Add Swift factory method to `Wire.swift`
