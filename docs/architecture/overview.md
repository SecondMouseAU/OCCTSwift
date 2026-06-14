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
│       │   └── OCCTBridge.h    # C function declarations
│       └── src/
│           └── OCCTBridge.mm   # OCCT C++ implementations
├── Libraries/
│   └── OCCT.xcframework/       # Pre-built OCCT 8.0.0-rc5
├── Scripts/
│   └── build-occt.sh           # Build OCCT from source
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

1. Add C function declaration to `OCCTBridge.h`
2. Implement in `OCCTBridge.mm` using OCCT classes
3. Add Swift wrapper method to `Shape.swift`
4. Add tests and documentation

### Adding New Export Formats

1. Add export function to `OCCTBridge.h`
2. Implement using OCCT's TKDExxx modules
3. Add Swift wrapper to `Exporter.swift`

### Adding New Wire/Curve Types

1. Add creation function to `OCCTBridge.h`
2. Implement using OCCT's Geom/BRepBuilderAPI classes
3. Add Swift factory method to `Wire.swift`
