---
type: reference
title: References index
resource: https://github.com/SecondMouseAU/OCCTSwift
tags: [index, references]
description: Upstream and licensing references for OCCTSwift.
timestamp: 2026-09-07
---

# References

- **OpenCASCADE Technology (OCCT)**: the underlying C++ kernel. <https://dev.opencascade.org/>
- **Licensing**: OCCT is LGPL-2.1 with an exception; see `LICENSE` and `OCCT_LGPL_EXCEPTION.md`
  in the repo root.
- **Swift Package Index**: package page driven by `.spi.yml`.
- [**Carried OCCT source patches**](carried-occt-patches.md), upstream-bound OCCT fixes we build
  into the xcframework until they ship in an OCCT release, one row per patch, plus which of them the
  pinned release asset does not yet hold.
- [**Known OCCT bugs**](known-occt-bugs.md), every kernel defect this project has root-caused, one
  row per defect, keyed by issue rather than by patch, with where the writeup lives.
