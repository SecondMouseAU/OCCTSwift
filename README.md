# OCCTSwift

[![Swift](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fgsdali%2FOCCTSwift%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/gsdali/OCCTSwift)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fgsdali%2FOCCTSwift%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/gsdali/OCCTSwift)
[![License](https://img.shields.io/badge/license-LGPL--2.1-blue)](LICENSE)

A comprehensive Swift wrapper for [OpenCASCADE Technology (OCCT)](https://www.opencascade.com/) 8.0.0, providing B-Rep solid modeling for macOS and iOS. **v1.0.0 — SemVer-stable as of 2026-05-07.**

**4,287 wrapped operations** | macOS 12+ / iOS 15+ / visionOS 1+ / tvOS 15+ (arm64) | OCCT 8.0.0

## Quick Start

### Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/gsdali/OCCTSwift.git", from: "1.0.0")
]
```

The package ships a pre-built `OCCT.xcframework` as a release asset, so no source build of OCCT is required for end users.

### Usage

```swift
import OCCTSwift

// Primitives
let box = Shape.box(width: 10, height: 5, depth: 3)
let cylinder = Shape.cylinder(radius: 2, height: 10)

// Boolean operations
let result = box - cylinder      // subtract
let combined = box + cylinder    // union
let common = box & cylinder      // intersect

// Modifications
let filleted = result.filleted(radius: 0.5)
let shelled = filleted.shelled(thickness: -0.3)

// Export
try Exporter.writeSTEP(shape: shelled, to: stepURL)
try Exporter.writeSTL(shape: shelled, to: stlURL, deflection: 0.05)
```

## Ecosystem

OCCTSwift is the kernel of a layered family of packages, all SemVer-stable from v1.0.0 (OCCT 8.0.0 GA cohort, May 2026). See [`docs/ecosystem.md`](docs/ecosystem.md) for an architecture map and "when to use which" guidance.

| Package | Role |
|---------|------|
| **OCCTSwift** (this repo) | Core Swift wrapper — shapes, curves, surfaces, OCAF, TopologyGraph, drawing/projection, ML samplers. Bundles the OCCT 8.0.0 GA xcframework. |
| [OCCTSwiftIO](https://github.com/gsdali/OCCTSwiftIO) | Headless CAD file I/O — STEP / IGES / STL / OBJ / BREP loaders + glTF / GLB / OBJ / PLY / STEP / BREP exporters. No Viewport dep. |
| [OCCTSwiftMesh](https://github.com/gsdali/OCCTSwiftMesh) | Mesh-domain algorithms — decimation, smoothing, repair (vendors `meshoptimizer`). |
| [OCCTSwiftViewport](https://github.com/gsdali/OCCTSwiftViewport) | Metal-based 3D viewport component (UIKit / AppKit / SwiftUI). |
| [OCCTSwiftTools](https://github.com/gsdali/OCCTSwiftTools) | Bridge layer: converts kernel `Shape` to `ViewportBody` with picking metadata. |
| [OCCTSwiftAIS](https://github.com/gsdali/OCCTSwiftAIS) | High-level interactive services — selection, manipulator widgets, dimension annotations, scene objects. |
| [OCCTSwiftScripts](https://github.com/gsdali/OCCTSwiftScripts) | `occtkit` CLI + ScriptHarness — JSON-driven verbs for compose / reconstruct / drawing-export / metrics / mesh / render-preview / XCAF. |
| [OCCTMCP](https://github.com/gsdali/OCCTMCP) | MCP server exposing CAD modeling to AI tools via Model Context Protocol. |
| [simpleOCCTVP](https://github.com/gsdali/simpleOCCTVP) | Pure C API over OCCT for non-Swift consumers — shape I/O, healing, mesh extraction, offscreen rendering. |

## What's Wrapped

OCCTSwift provides method-level coverage of all user-facing OCCT classes. Key areas:

| Category | Operations | Highlights |
|----------|-----------|------------|
| Primitives & Sweeps | 36 | box, cylinder, sphere, cone, torus, wedge, pipe, extrude, revolve, loft, thru-sections |
| Booleans | 13 | union, subtract, intersect, section, split, cells builder, defeaturing |
| Modifications | 33 | fillet (uniform/variable/evolving), chamfer, shell, offset, draft |
| Wires & Edges | 56 | rectangle, circle, polygon, arc, BSpline, NURBS, helix, fillet2D, chamfer2D |
| 2D Curves | 97 | full Geom2d — lines, conics, BSplines, Bezier, Gcc constraint solver, hatching |
| 3D Curves | 84 | full Geom — lines, conics, BSplines, Bezier, interpolation, projection, evaluation |
| Surfaces | 86 | analytic, swept, freeform, plate, NLPlate, curvature, projection, trimming |
| Face / Edge Analysis | 54 | UV queries, normals, curvature, projection, classification, primary axis, surface type predicates |
| Feature-Based | 36 | boss, pocket, drill, split, pattern, rib, revolution, draft prism |
| Healing & Analysis | 69 | fix, unify, simplify, NURBS convert, sew, wire/face/shell repair |
| Measurement | 38 | volume, area, distance, inertia, point classification, proximity, revolution/symmetry axes |
| Import/Export | 19 | STEP, IGES, STL, OBJ, PLY, BREP, GLTF/GLB, DXF |
| XDE/OCAF | 200+ | assembly, colors, materials, GD&T (32 dimension types + 16 tolerance types, read + write), annotations, transactions, undo/redo, STEP AP242 round-trip |
| Math & Solvers | 50+ | root finding, BFGS, PSO, SVD, Gauss, Jacobi, constraint callbacks |
| Colors & Materials | 63 | Quantity_Color, sRGB/Lab/HLS, PBR materials, named colors |
| Geometry Factories | 90+ | GC/GCE2d/gce factories, convert to BSpline, analytical recognition |
| Drawings & Dimensions | 32 | HLR projection, visible/hidden/outline edges, linear/radial/diameter/angular dimensions, centrelines, auto-centreline from revolution axes, DXF R12 writer |
| Thread Features | 22 | ThreadForm (ISO-68/Unified), ThreadSpec parser (M5x0.8, 1/4-20 UNC), truncated 60° V-profile, multi-start, runout styles, Shape.threadedHole, Shape.threadedShaft |
| Sheet Metal | 3 | `SheetMetal.Flange` + `Bend` + `Builder.build` — declarative flange-and-bend composition via extrude + union + fillet |

For the full operation-by-operation mapping to OCCT classes, see [docs/API_REFERENCE.md](docs/API_REFERENCE.md).

## Examples

### Sweep a Profile Along a Path

```swift
let profile = Wire.rectangle(width: 5, height: 3)
let path = Wire.arc(center: .zero, radius: 50, startAngle: 0, endAngle: .pi / 2)
let swept = Shape.sweep(profile: profile, along: path)
```

### XDE Document with Assembly Structure

```swift
let doc = try Document.load(from: stepURL)

for node in doc.rootNodes {
    print("Part: \(node.name ?? "unnamed")")
    if let color = node.color {
        print("  Color: \(color.red), \(color.green), \(color.blue)")
    }
    if let shape = node.shape {
        let mesh = shape.mesh(linearDeflection: 0.1)
        // render with Metal, SceneKit, RealityKit...
    }
}
```

### Parametric Curves for Metal Rendering

```swift
let curve = Curve3D.interpolate(points: [
    SIMD3(0, 0, 0), SIMD3(5, 10, 0), SIMD3(10, 0, 5)
])!
let points = curve.drawAdaptive(curvatureDeflection: 0.1)
// Feed to Metal vertex buffer
```

### GLTF Export

```swift
try Exporter.writeGLTF(shape: model, to: gltfURL)
try Exporter.writeGLB(shape: model, to: glbURL)
```

## Architecture

```
Sources/OCCTSwift/          Swift public API
Sources/OCCTBridge/include/ C function declarations (OCCTBridge.h)
Sources/OCCTBridge/src/     Objective-C++ implementations (OCCTBridge.mm)
Libraries/OCCT.xcframework  Pre-built OCCT 8.0.0 static library (arm64)
Tests/OCCT<Domain>Tests/    Per-domain Swift Testing targets (focused compile/run)
```

Three-layer design: **Swift API** -> **C bridge** (Objective-C++) -> **OCCT C++**

Each OCCT object is managed via opaque handle types with release-on-deinit. See [docs/architecture/overview.md](docs/architecture/overview.md) for details.

## Requirements

- Swift 6.1+ (verified clean on 6.1, 6.2, 6.3)
- macOS 12.0+ (arm64) / iOS 15.0+ (arm64)
- Xcode 16.0+

### Supported Platforms

| Platform | Architecture | Status |
|---|---|---|
| macOS 12+ | arm64 (Apple Silicon) | Supported |
| iOS 15+ device | arm64 | Supported |
| iOS 15+ Simulator | arm64 (Apple Silicon host) | Supported |
| visionOS 1+ | arm64 device + simulator | Supported (v0.167.0+) |
| tvOS 15+ | arm64 device + simulator | Supported (v0.167.0+) |
| watchOS | — | Out of scope (OCCT static lib too large for watch memory) |
| macOS x86_64 (Intel) | — | Out of scope (Apple is winding down Intel macOS support) |
| Linux / Windows / Android | — | Under review — see [docs/platform-expansion.md](docs/platform-expansion.md) |

## Building OCCT from Source

The pre-built xcframework is included. To rebuild from source:

```bash
./Scripts/build-occt.sh
```

See [docs/guides/building-occt.md](docs/guides/building-occt.md) for details.

## Documentation

| Document | Description |
|----------|-------------|
| [Ecosystem](docs/ecosystem.md) | Map of the package family, dependency layering, when to use which |
| [SemVer Policy](docs/SEMVER.md) | Versioning rules for the cohort — what triggers MAJOR / MINOR / PATCH |
| [Architecture Overview](docs/architecture/overview.md) | Three-layer design, memory management, conventions |
| [Adding Features](docs/guides/adding-features.md) | How to wrap new OCCT operations |
| [OCCT Concepts](docs/guides/occt-concepts.md) | B-Rep topology, handles, shapes primer |
| [API Reference](docs/API_REFERENCE.md) | Full operation-by-operation mapping to OCCT classes |
| [Thread Safety](docs/thread-safety.md) | OCCTSerial mutex, parallel execution notes |
| [Naming Conventions](docs/naming-conventions.md) | Bridge and Swift naming patterns |
| [OCCT Upgrades](docs/occt-upgrades.md) | Breaking changes and migration for each OCCT version |
| [Wrapping Status](docs/occtswift-wrapping-gaps.md) | What's wrapped, what's not, and why |
| [Changelog](docs/CHANGELOG.md) | Release history |

## License

LGPL-2.1. OpenCASCADE Technology is licensed under LGPL-2.1.

## Acknowledgments

- [OpenCASCADE](https://www.opencascade.com/) for the geometry kernel
