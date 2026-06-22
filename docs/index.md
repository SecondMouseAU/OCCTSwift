---
title: Home
nav_order: 1
---

# OCCTSwift documentation

A comprehensive Swift wrapper for [OpenCASCADE Technology](https://dev.opencascade.org) (OCCT 8.0.0p1) —
B-Rep solid modeling, CAD data exchange, meshing and geometry for **macOS / iOS / visionOS / tvOS**.
Three-layer architecture: Swift public API → Objective-C++ bridge → OCCT C++. **4,290 wrapped operations.**

```swift
import OCCTSwift

guard let box = Shape.box(width: 10, height: 10, depth: 10),
      let cyl = Shape.cylinder(at: SIMD3(0, 0, -8), direction: SIMD3(0, 0, 1),
                               radius: 3, height: 16) else { return }
let drilled = box.subtracting(cyl)          // a box with a through-hole
try drilled?.writeSTEP(to: outputURL)       // exact B-Rep, ready for CAD/CAM
```

## Cookbook

Task-oriented, example-rich guides — each a short bit of prose plus runnable Swift and a rendered
figure (interactive 3D where it helps). The **[Cookbook index](guides/cookbook/)** lists all areas:

[Booleans](guides/cookbook/booleans.md) ·
[Threads](guides/cookbook/threads.md) ·
[Helices & Springs](guides/cookbook/helices.md) ·
[Lofting & Sweeps](guides/cookbook/lofting-and-sweeps.md) ·
[Helical Sweeps](guides/cookbook/helical-sweeps.md) ·
[Healing & Validity](guides/cookbook/healing-and-validity.md) ·
[Meshing & Export](guides/cookbook/meshing-and-export.md) ·
[XCAF Assemblies](guides/cookbook/xcaf-assemblies.md) ·
[Topology Graph](guides/cookbook/topology-graph.md) ·
[Gordon Surfaces](guides/cookbook/gordon-surfaces.md) ·
[Surfaces from Points](guides/cookbook/surfaces-from-points.md) ·
[Working with Meshes](guides/cookbook/working-with-meshes.md)

## Reference

- **[API Reference](reference/)** — the detailed, per-type function reference: signatures, parameters,
  the OCCT class each method wraps, and runnable examples. Built progressively (Wire, Edge, Face, Mesh,
  Exporter, ThreadFeatures so far).
- [API Map (Swift ↔ OCCT)](API_REFERENCE.md) — the compact operation-to-OCCT-class mapping table.
- [Changelog](CHANGELOG.md) — release-by-release history.

## Guides & concepts

- [OCCT Concepts](guides/occt-concepts.md) — B-Rep topology, handles, shapes primer.
- [Architecture](architecture/overview.md) — the three-layer design and memory model.
- [Adding Features](guides/adding-features.md) — bridge header → impl → Swift → test.
- [Building OCCT](guides/building-occt.md) — rebuild the `OCCT.xcframework` from source.
- [Sharing the xcframework](guides/sharing-the-xcframework.md) — one shared local copy across repos + the `Package.resolved` pin footgun (#260).
- [Thread Safety](thread-safety.md) · [Naming Conventions](naming-conventions.md) ·
  [Versioning (SemVer)](SEMVER.md) · [Ecosystem](ecosystem.md)

## Project

- Source & issues: [github.com/gsdali/OCCTSwift](https://github.com/gsdali/OCCTSwift)
- Install via Swift Package Manager — pin `from: "1.0.0"` (SemVer-stable since v1.0.0).
