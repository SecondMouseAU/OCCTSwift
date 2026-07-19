---
type: reference
title: Carried OCCT source patches
resource: https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/patches
tags: [occt, patches, upstream, thread-safety, kernel]
description: Upstream-bound OCCT fixes OCCTSwift carries in its xcframework build until they ship in an OCCT release.
timestamp: 2026-07-18
---

# Carried OCCT source patches

OCCTSwift bundles a prebuilt `OCCT.xcframework`. When we find an upstream OCCT bug, we
carry a source patch in [`Scripts/patches/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/patches)
that `Scripts/build-occt.sh` applies before each build, so the fix ships in our binary
ahead of an official OCCT release. Each patch is **temporary**: retire it once the
bundled OCCT version includes the fix. Full rationale + validation per patch lives in
`Scripts/patches/README.md` — this note is the ecosystem-level pointer.

Each patch is also meant to be **offered upstream** as an OCCT PR. When you do, follow
[Upstream OCCT PRs follow OCCT's house style](../policies/upstream-occt-style.md): clang-format with
OCCT's own `.clang-format`, and OCCT's terse comment style — not OCCTSwift's.

| Patch | Fixes | Upstream | Retire when |
|-------|-------|----------|-------------|
| `0001-ShapeFix_Face-…-263` | ShapeFix_Face compound-context crash ([#263](https://github.com/SecondMouseAU/OCCTSwift/issues/263)) | [OCCT#1322](https://github.com/Open-Cascade-SAS/OCCT/issues/1322) reports it; fix offered as **[OCCT#1323](https://github.com/Open-Cascade-SAS/OCCT/pull/1323)** (our PR, CI green, ready for review) | bundled OCCT includes the guard |
| `0002-STEPControl_Writer-…-1334` | XDE STEP read corrupts later STEP writes ([#280](https://github.com/SecondMouseAU/OCCTSwift/issues/280)) | [OCCT#1334](https://github.com/Open-Cascade-SAS/OCCT/pull/1334) (their fix, merged upstream; we backport) | bundled OCCT moves past that commit |
| `0003-TopOpeBRep-non-reentrant-globals-fillet-298` | Concurrent fillet/chamfer corrupts geometry (non-reentrant `STATIC_SOLIDINDEX` in the TopOpeBRepBuild solid reconstruction, [#298](https://github.com/SecondMouseAU/OCCTSwift/issues/298)) | **[OCCT#1374](https://github.com/Open-Cascade-SAS/OCCT/pull/1374)** (our PR, open, not yet released) | **an upstream OCCT release includes the `thread_local` conversion** |
| `0004-ShapeAnalysis_FreeBounds-…-310` | `ShapeAnalysis_FreeBounds` SIGSEGV on a compound of 2+ disjoint free-boundary components ([#310](https://github.com/SecondMouseAU/OCCTSwift/issues/310)) | [OCCT#1376](https://github.com/Open-Cascade-SAS/OCCT/issues/1376) (repro) → **[OCCT#1377](https://github.com/Open-Cascade-SAS/OCCT/pull/1377)** (our fix PR, open) | bundled OCCT includes the fix |
| `0005-ShapeFix_Face-…-317` | `ShapeFix_Face::FixPeriodicDegenerated` SIGSEGV on a single closed wire belting a cone's full period, no `SetContext()` set ([#317](https://github.com/SecondMouseAU/OCCTSwift/issues/317)) | [OCCT#1378](https://github.com/Open-Cascade-SAS/OCCT/issues/1378) (repro) → **[OCCT#1380](https://github.com/Open-Cascade-SAS/OCCT/pull/1380)** (our fix PR, open) | bundled OCCT includes the fix |

**#298 status:** we ship the fix now via patch `0003` (xcframework rebuilt in v1.12.3);
we keep carrying it — and building our own xcframework — **until an upstream OCCT
release contains OCCT#1374**. When that lands and we re-pin to that OCCT version, drop
`0003`. (The in-wrapper `occtFilletMutex` serialization that v1.12.1 shipped was already
removed in v1.12.3 once the kernel patch made fillet reentrant.)
