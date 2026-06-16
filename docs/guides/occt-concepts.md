---
title: OCCT Concepts
nav_order: 5
---

# OpenCASCADE Concepts for Swift Developers

This guide explains core OCCT concepts for developers coming from iOS/Swift backgrounds who may not be familiar with CAD kernel terminology.

## What is a CAD Kernel?

A CAD kernel is the mathematical engine that represents and manipulates 3D geometry. Unlike game engines (Unity, SceneKit) that work with triangulated meshes, CAD kernels use **exact mathematical representations**.

**Key difference:**

```
SceneKit sphere:
  - List of triangles approximating a sphere
  - More triangles = smoother, but never perfect
  - Can't calculate exact surface area

OCCT sphere:
  - Mathematical equation: x² + y² + z² = r²
  - Infinitely smooth (conceptually)
  - Exact calculations possible
  - Convert to triangles only when needed for display
```

## B-Rep: Boundary Representation

OCCT uses **B-Rep** (Boundary Representation) to define solids. A solid is defined by its boundary surfaces, not by filling space with voxels or triangles.

### Topology Hierarchy

```
COMPOUND ─── Contains multiple unrelated shapes
    │
COMPSOLID ── Multiple solids sharing faces
    │
SOLID ────── A watertight 3D volume
    │
SHELL ────── Collection of connected faces (surface)
    │
FACE ─────── A bounded portion of a surface
    │
WIRE ─────── A connected sequence of edges (loop)
    │
EDGE ─────── A bounded portion of a curve
    │
VERTEX ───── A point in 3D space
```

### Example: A Simple Box

```
Box (SOLID)
├── Shell (SHELL) - the 6 faces
│   ├── Top face (FACE) - bounded by 4 edges
│   │   └── Wire (WIRE) - the boundary
│   │       ├── Edge 1 (EDGE) - top front edge
│   │       ├── Edge 2 (EDGE) - top right edge
│   │       ├── Edge 3 (EDGE) - top back edge
│   │       └── Edge 4 (EDGE) - top left edge
│   ├── Bottom face (FACE)
│   ├── Front face (FACE)
│   ├── Back face (FACE)
│   ├── Left face (FACE)
│   └── Right face (FACE)
└── Vertices (8 corners)
```

### In OCCTSwift

```swift
// Creates a full B-Rep structure internally
let box = Shape.box(width: 10, height: 5, depth: 3)

// You don't see the topology directly - Shape wraps it
// But OCCT maintains full topological information
```

## Geometry vs Topology

OCCT separates **geometry** (mathematical shapes) from **topology** (how they connect).

### Geometry (Mathematical Definitions)

- **gp_Pnt**: A 3D point (x, y, z)
- **Geom_Line**: An infinite line
- **Geom_Circle**: A circle (center, radius, plane)
- **Geom_BSplineCurve**: A NURBS curve
- **Geom_Plane**: An infinite plane
- **Geom_CylindricalSurface**: An infinite cylinder
- **Geom_BSplineSurface**: A NURBS surface

### Topology (Bounded Regions)

- **TopoDS_Vertex**: A point on geometry
- **TopoDS_Edge**: A bounded curve segment
- **TopoDS_Wire**: Connected edges forming a loop
- **TopoDS_Face**: A bounded surface region
- **TopoDS_Shell**: Connected faces
- **TopoDS_Solid**: A closed volume

### Example

```
A cylinder face:
- Geometry: Geom_CylindricalSurface (infinite)
- Topology: TopoDS_Face with boundary wires
  - Wire 1: Circle at top
  - Wire 2: Circle at bottom
  - These bound the finite portion of the infinite surface
```

## Wires: The Building Blocks

A **Wire** is a connected sequence of edges forming a path. Wires are essential for:

1. **2D Profiles**: Cross-sections to sweep or extrude
2. **3D Paths**: Curves along which to sweep profiles
3. **Face Boundaries**: Defining the edges of a face

### Creating Wires in OCCTSwift

```swift
// 2D rectangle profile (for extrusion)
let profile = Wire.rectangle(width: 10, height: 5)

// 2D custom profile (for rail cross-section)
let railProfile = Wire.polygon([
    SIMD2(0, 0),
    SIMD2(3, 0),
    SIMD2(3, 1),
    SIMD2(2, 1),
    SIMD2(2, 8),
    SIMD2(1, 8),
    SIMD2(1, 1),
    SIMD2(0, 1)
], closed: true)

// 3D arc path (for curved track)
let path = Wire.arc(
    center: .zero,
    radius: 500,
    startAngle: 0,
    endAngle: .pi / 4
)
```

## Shape Operations

### Boolean Operations (CSG)

Constructive Solid Geometry combines shapes:

```swift
// Union: Add shapes together
let combined = shapeA + shapeB  // or shapeA.union(with: shapeB)

// Subtraction: Cut one from another
let holed = block - cylinder    // or block.subtracting(cylinder)

// Intersection: Keep only overlapping volume
let common = shapeA & shapeB    // or shapeA.intersection(with: shapeB)
```

**How it works internally:**
1. Find intersection curves between surfaces
2. Split faces along intersection curves
3. Classify face regions (inside/outside/on boundary)
4. Build result from appropriate regions

**Pitfalls:**
- Shapes must actually intersect for useful result
- Tangent (just-touching) cases can be problematic
- Result may be invalid if input shapes have issues

### Sweep Operations

Create solids by moving profiles:

```swift
// Extrusion: Move profile linearly
let beam = Shape.extrude(
    profile: rectangle,
    direction: SIMD3(0, 0, 1),
    length: 100
)

// Revolution: Rotate profile around axis
let vase = Shape.revolve(
    profile: crossSection,
    axisOrigin: .zero,
    axisDirection: SIMD3(0, 1, 0),
    angle: .pi * 2  // Full rotation
)

// Pipe sweep: Move profile along arbitrary path
let rail = Shape.sweep(
    profile: railProfile,
    along: curvedPath
)
```

**Pipe sweep details:**
- Profile must be planar (2D wire)
- Profile is positioned perpendicular to path at start
- Profile "follows" the path, staying perpendicular
- For curved paths, the profile rotates (Frenet frame)

### Modification Operations

```swift
// Fillet: Round edges
let rounded = shape.filleted(radius: 2.0)
// Finds all edges and applies circular fillet

// Chamfer: Bevel edges
let beveled = shape.chamfered(distance: 1.0)
// Creates flat cut at 45° along edges

// Shell: Hollow out a solid
let hollow = shape.shelled(thickness: 1.0)
// Removes interior, leaving walls of given thickness

// Offset: Expand/shrink all faces
let bigger = shape.offset(by: 0.5)
// Moves all faces outward (positive) or inward (negative)
```

## Meshing: From B-Rep to Triangles

For visualization (SceneKit) and export (STL), we convert exact geometry to triangles.

### Deflection Parameters

```swift
let mesh = shape.mesh(
    linearDeflection: 0.1,   // Max distance from true surface (mm)
    angularDeflection: 0.5   // Max angle between adjacent segments (radians)
)
```

**Linear deflection**: Controls chord height - how far a triangle edge can deviate from the true curve.

```
True curve: ────────────────
             \            /
              \   0.1mm  /
               \  max   /
Tessellation:   ────────
```

**Angular deflection**: Controls how much adjacent polygon edges can turn. Smaller = more segments on tight curves.

### Choosing Deflection Values

| Use Case | Linear | Angular | Notes |
|----------|--------|---------|-------|
| Quick preview | 0.5 | 1.0 | Fast, chunky |
| Interactive display | 0.1 | 0.5 | Good balance |
| 3D print (FDM) | 0.05 | 0.3 | Suitable for ~0.2mm layers |
| 3D print (SLA) | 0.02 | 0.2 | High detail |
| CNC machining | 0.01 | 0.1 | Precision output |

## Precision and Tolerances

OCCT uses 64-bit doubles and tracks tolerances explicitly.

### Default Precision

```cpp
Precision::Confusion() = 1e-7  // Points closer than this are "same"
```

### Tolerance in Practice

Each topological entity has a tolerance:
- Vertex: sphere of radius tolerance (point is "somewhere in there")
- Edge: tube around curve
- Face: band around surface

This handles numeric imprecision from floating-point calculations.

### For 3D Printing

Model railway at HO scale (1:87):
- 0.01mm in model = 0.87mm prototype
- OCCT's default precision (1e-7 = 0.0001mm) is more than sufficient
- FDM printers typically have 0.1-0.4mm resolution anyway

## Common Patterns in OCCTSwift

### Creating a Rail Section

```swift
// 1. Define the rail cross-section (2D profile)
let railProfile = Wire.polygon([
    SIMD2(0, 0),           // Base left
    SIMD2(2.5, 0),         // Base right
    SIMD2(2.5, 0.8),       // Web start
    SIMD2(1.8, 0.8),       // Web right
    SIMD2(1.8, 6.5),       // Head start
    SIMD2(2.2, 6.8),       // Head flare
    SIMD2(2.2, 7.5),       // Head top right
    SIMD2(0.3, 7.5),       // Head top left
    SIMD2(0.3, 6.8),       // Head flare left
    SIMD2(0.7, 6.5),       // Head start left
    SIMD2(0.7, 0.8),       // Web left
    SIMD2(0, 0.8)          // Back to base
], closed: true)

// 2. Define the track path (3D curve)
let straightPath = Wire.line(
    from: SIMD3(0, 0, 0),
    to: SIMD3(100, 0, 0)
)

// 3. Sweep to create the rail
let rail = Shape.sweep(profile: railProfile, along: straightPath)

// 4. Position for left/right rail
let leftRail = rail.translated(by: SIMD3(0, 0, -6))  // Half gauge
let rightRail = rail.translated(by: SIMD3(0, 0, 6))

// 5. Combine
let trackSection = Shape.compound([leftRail, rightRail])
```

### Creating a Sleeper with Holes

```swift
// Base sleeper block
let sleeper = Shape.box(width: 25, height: 2, depth: 4)

// Mounting holes for clips
let hole = Shape.cylinder(radius: 0.4, height: 2.5)
    .translated(by: SIMD3(0, -0.25, 0))  // Slightly below top

// Position holes at rail locations
let holeLeft = hole.translated(by: SIMD3(0, 0, -6))
let holeRight = hole.translated(by: SIMD3(0, 0, 6))

// Subtract holes from sleeper
let sleeperWithHoles = sleeper - holeLeft - holeRight
```

### Exporting for 3D Printing

```swift
// Combine all track components
let fullTrack = Shape.compound([
    rails,
    sleepers,
    clips
])

// Export as STL with appropriate resolution
try Exporter.writeSTL(
    shape: fullTrack,
    to: URL(fileURLWithPath: "track.stl"),
    deflection: 0.03  // Fine for FDM printing
)
```

## Error Handling

OCCT operations can fail silently, returning empty or invalid shapes.

### Checking Validity

```swift
let result = shapeA - shapeB

if !result.isValid {
    // Boolean failed - maybe shapes don't intersect
    // or geometry is too complex
    let healed = result.healed()
    if healed.isValid {
        // Healing fixed it
    } else {
        // Need to adjust input geometry
    }
}
```

### Common Failure Causes

1. **Non-intersecting booleans**: Subtracting a shape that doesn't touch
2. **Self-intersecting profiles**: Wire crosses itself
3. **Degenerate geometry**: Zero-length edges, zero-area faces
4. **Tolerance issues**: Parts that should touch, don't quite
5. **Complex fillet**: Radius too large for edge configuration

## Further Reading

- [OCCT Documentation](https://dev.opencascade.org/doc/overview/html/)
- [OCCT Modeling Algorithms](https://dev.opencascade.org/doc/overview/html/occt_user_guides__modeling_algos.html)
- [B-Rep on Wikipedia](https://en.wikipedia.org/wiki/Boundary_representation)
