---
title: Home
nav_order: 1
---

# OCCTSwift documentation

A comprehensive Swift wrapper for [OpenCASCADE Technology](https://dev.opencascade.org) (OCCT 8.0.1),
B-Rep solid modeling, CAD data exchange, meshing and geometry for **macOS and iOS**. visionOS and tvOS are declared and buildable but untested, and need a local kernel rebuild (#978).
Three-layer architecture: Swift public API → Objective-C++ bridge → OCCT C++. **4,365 wrapped operations.**
```swift
import OCCTSwift

guard let box = Shape.box(width: 10, height: 10, depth: 10),
      let cyl = Shape.cylinder(at: SIMD3(0, 0, -8), direction: SIMD3(0, 0, 1),
                               radius: 3, height: 16) else { return }
let drilled = box.subtracting(cyl)          // a box with a through-hole
try drilled?.writeSTEP(to: outputURL)       // exact B-Rep, ready for CAD/CAM
```

## Cookbook

Task-oriented, example-rich guides, each a short bit of prose plus runnable Swift and a rendered
figure (interactive 3D where it helps). The **[Cookbook index](guides/cookbook/)** lists all areas:

[Booleans](guides/cookbook/booleans.md) ·
[Threads](guides/cookbook/threads.md) ·
[Helices & Springs](guides/cookbook/helices.md) ·
[Lofting & Sweeps](guides/cookbook/lofting-and-sweeps.md) ·
[Helical Sweeps](guides/cookbook/helical-sweeps.md) ·
[Healing & Validity](guides/cookbook/healing-and-validity.md) ·
[Meshing & Export](guides/cookbook/meshing-and-export.md) ·
[XCAF Assemblies](guides/cookbook/xcaf-assemblies.md) ·
[BRep Graph](guides/cookbook/brep-graph.md) ·
[Gordon Surfaces](guides/cookbook/gordon-surfaces.md) ·
[Surfaces from Points](guides/cookbook/surfaces-from-points.md) ·
[Working with Meshes](guides/cookbook/working-with-meshes.md)

## Reference

- **[API Reference](reference/)**: the detailed, per-type function reference: signatures, parameters,
  the OCCT class each method wraps, and runnable examples. Built progressively (Wire, Edge, Face, Mesh,
  Exporter, ThreadFeatures so far).
- [API Map (Swift ↔ OCCT)](API_REFERENCE.md), the compact operation-to-OCCT-class mapping table.
- [Changelog](CHANGELOG.md), release-by-release history.

## Guides & concepts

- [OCCT Concepts](guides/occt-concepts.md), B-Rep topology, handles, shapes primer.
- [Consuming the package](guides/consuming-from-objective-c.md), what your own target has to set, and the two requirements on any file of yours that includes an OCCT header (#967).
- [Architecture](architecture/overview.md), the three-layer design and memory model.
- [Adding Features](guides/adding-features.md), bridge header → impl → Swift → test.
- [Building OCCT](guides/building-occt.md), rebuild the `OCCT.xcframework` from source.
- [Sharing the xcframework](guides/sharing-the-xcframework.md), one shared local copy across repos + the `Package.resolved` pin footgun (#260).
- [Thread Safety](thread-safety.md) · [Naming Conventions](naming-conventions.md) ·
  [Versioning (SemVer)](SEMVER.md) · [Ecosystem](ecosystem.md)
- [v4.0.0 Release Plan](v4.0.0-plan.md), scope, order, and beta/RC criteria for the in-flight major.
- [v2.0.0 Release Plan](v2.0.0-plan.md), scope, clusters, and the census-once rule the previous
  major shipped under.

## Project

- Source & issues: [github.com/gsdali/OCCTSwift](https://github.com/gsdali/OCCTSwift)
- Install via Swift Package Manager, pin `from: "3.0.0"` (SemVer-stable since v1.0.0; `from: "1.0.0"` resolves to the 1.x line and never reaches 3.x).
