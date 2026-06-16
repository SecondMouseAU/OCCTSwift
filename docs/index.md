---
title: Home
nav_order: 1
---

# OCCTSwift documentation

A comprehensive Swift wrapper for [OpenCASCADE Technology](https://dev.opencascade.org) (OCCT 8.0.0) —
B-Rep solid modeling, CAD data exchange, meshing and geometry for **macOS / iOS / visionOS / tvOS**.
Three-layer architecture: Swift public API → Objective-C++ bridge → OCCT C++.

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
figure. Start here:

- **[Booleans](guides/cookbook/booleans.md)** — union / subtracting / intersection, fuzzy value, glue, timeout, self-intersection checks.
- [Cookbook index](guides/cookbook/) — all areas (more landing progressively).

## Reference

- [API Reference](API_REFERENCE.md) — the full Swift → OCCT operation mapping.
- [Changelog](CHANGELOG.md) — release-by-release history.
- [OCCT concepts](guides/occt-concepts.md) — B-Rep topology, handles, shapes primer.
- [Adding features](guides/adding-features.md) — bridge header → impl → Swift → test.
- [Architecture](architecture/overview.md) — the three-layer design and memory model.

## Project

- Source & issues: [github.com/gsdali/OCCTSwift](https://github.com/gsdali/OCCTSwift)
- Install via Swift Package Manager — pin `from: "1.5.0"`.
