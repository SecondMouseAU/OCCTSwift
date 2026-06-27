---
type: repo
title: OCCTSwift
resource: https://github.com/SecondMouseAU/OCCTSwift
tags: [cad, occt, opencascade, brep, swift, kernel]
description: Swift wrapper for OpenCASCADE Technology (OCCT) — the B-Rep solid modelling kernel of the ecosystem.
timestamp: 2026-06-18
---

# OCCTSwift

The foundation of the ecosystem: a Swift package wrapping **OpenCASCADE Technology (OCCT)** for
B-Rep solid modelling on Apple platforms. A Swift 6 API layer (`OCCTSwift`) sits over an
Objective-C++ bridge (`OCCTBridge`) to a prebuilt OCCT binary (`OCCT.xcframework`), targeting
iOS 15+, macOS 12+, visionOS 1+, and tvOS 15+.

## Role in the ecosystem

- **Cluster:** kernel
- **Depends on:** nothing intra-org — this is the dependency root. Its only build input is the
  bundled `OCCT.xcframework` (OpenCASCADE), fetched from a GitHub release.
- **Feeds:** every other kernel library and, transitively, all CAD products. Dependents declare
  `depends_on: [OCCTSwift]` in their own manifests.

## Components

See [`components/`](components/index.md) — the API is organised by OCCT domain (foundation, math,
geometry, topology, modelling, mesh, shape-healing, I/O, XCAF, analysis, drawing).

## References

See [`references/`](references/index.md) — OpenCASCADE upstream and licensing (LGPL + exception).

## Notes

- Binary target auto-selects a local `Libraries/OCCT.xcframework` (path-dep / dev) or the remote
  release zip (URL / CI); see `Package.swift` for the `#filePath`-based detection.
- Published to the Swift Package Index via `.spi.yml`.
- **Release discipline (OKF standard):** documentation updates are **mandatory with every release** —
  no release ships with stale docs. Any change to a public API surface updates, in the same release,
  `README.md`, `docs/API_REFERENCE.md`, `docs/CHANGELOG.md`, the relevant `docs/reference/` page, and
  the `///` doc comments (with a runnable ```swift``` snippet for context7). See `CLAUDE.md` → Release Process.

## Policies

- [Query `context` first for OCCT / OCCTSwift docs](policies/context-first.md)
- [Documentation updates are mandatory](policies/docs-current.md)
