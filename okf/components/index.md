---
type: component
title: Components index
resource: https://github.com/SecondMouseAU/OCCTSwift
tags: [index, api]
description: OCCTSwift public API organised by OpenCASCADE domain.
timestamp: 2026-06-18
---

# Components

`OCCTSwift` exposes one Swift API surface (the `OCCTSwift` target over the `OCCTBridge`
Objective-C++ layer), organised by OCCT domain. Domains, mirrored by the per-domain test targets:

- **Foundation**: core types, handles, collections
- **Math**: vectors, matrices, precision
- **Geometry (2D/3D)**: `Geom2d`, curves, surfaces
- **Topology**: shapes, the topology graph
- **Modeling**: primitives, booleans, fillets, sweeps
- **Mesh**: triangulation / tessellation
- **Shape Healing**: repair, sewing, fixing
- **I/O**: STEP / IGES / STL / BREP read & write
- **XCAF**: extended data (colours, assemblies, metadata)
- **Analysis**: properties, measurement
- **Drawing**: 2D projection / drawing extraction

Add one `<domain>.md` here as each domain's API is documented in depth.
