---
type: reference
title: Carried OCCT source patches
resource: https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/patches
tags: [occt, patches, upstream, thread-safety, kernel]
description: Upstream-bound OCCT fixes OCCTSwift carries in its xcframework build until they ship in an OCCT release.
timestamp: 2026-08-03
---

# Carried OCCT source patches

OCCTSwift bundles a prebuilt `OCCT.xcframework`. When we find an upstream OCCT bug, we
carry a source patch in [`Scripts/patches/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/patches)
that `Scripts/build-occt.sh` applies before each build, so the fix ships in our binary
ahead of an official OCCT release. Each patch is **temporary**: retire it once the
bundled OCCT version includes the fix. Full rationale + validation per patch lives in
`Scripts/patches/README.md`: this note is the ecosystem-level pointer.

Each patch is also meant to be **offered upstream** as an OCCT PR. When you do, follow
[Upstream OCCT PRs, style and submission workflow](../policies/upstream-occt-style.md): clang-format
with OCCT's own `.clang-format`, OCCT's terse comment style, not OCCTSwift's, and, as of
2026-07-30, go straight to the PR rather than filing a separate repro issue first when the fix is
already in hand (an OCCT maintainer asked for exactly that). Rows up to `0017` still show the
older repro-issue-then-fix-PR pattern, left as the accurate historical record rather than retitled
after the fact; `0018` is the first filed as a PR alone. For the rest of the lifecycle, from the
GTest a PR needs before submission through to the git mechanics of pushing to a live PR branch
without silently closing it, see
[Upstream OCCT patch process, start to finish](../policies/upstream-occt-patch-process.md).

| Patch | Fixes | Upstream | Retire when |
|-------|-------|----------|-------------|
| `0010-Intf_Interference-O1-tangent-zone-checkpoint-breaker-319` | `isSelfIntersecting(hardTimeout:)` couldn't interrupt an unbounded self-interference search. O(n)-per-call tangent-zone point access plus no checkpoint below `CheckFaceSelfIntersection` ([#319](https://github.com/SecondMouseAU/OCCTSwift/issues/319)) | [OCCT#1385](https://github.com/Open-Cascade-SAS/OCCT/issues/1385) (repro) → **[OCCT#1386](https://github.com/Open-Cascade-SAS/OCCT/pull/1386)** (our fix PR, CI green, ready for review) | bundled OCCT includes the fix |
| `0011-XCAFDoc_ShapeTool-AutoNamingScope-341` | `XCAFDoc_ShapeTool::theAutoNaming` process-global race across concurrent OBJ/glTF import and PLY/OBJ/glTF export ([#341](https://github.com/SecondMouseAU/OCCTSwift/issues/341)); revised per upstream review to a per-instance `OwnAutoNamingScope` instead of a mutex-guarded global flag ([#363](https://github.com/SecondMouseAU/OCCTSwift/issues/363)) | [OCCT#1387](https://github.com/Open-Cascade-SAS/OCCT/issues/1387) (repro) → **[OCCT#1388](https://github.com/Open-Cascade-SAS/OCCT/pull/1388)** (our fix PR, updated, CI green, ready for review) | bundled OCCT includes the fix |
| `0012-CDF_Directory-XCAFApp_Application-thread-safety-344` | `XCAFApp_Application::GetApplication()`/`TDocStd_Application::Resources()` lazy-singleton races + unsynchronized `CDF_Directory`/`Resource_Manager`/`CDF_Application` reader-writer maps. SIGSEGV surviving the #341 fix ([#344](https://github.com/SecondMouseAU/OCCTSwift/issues/344); a related but architecturally different driver-reentrancy crash found in the same validation is tracked separately as [#349](https://github.com/SecondMouseAU/OCCTSwift/issues/349)) | [OCCT#1389](https://github.com/Open-Cascade-SAS/OCCT/issues/1389) (repro) → **[OCCT#1390](https://github.com/Open-Cascade-SAS/OCCT/pull/1390)** (our fix PR, 2 commits, CI pending) | bundled OCCT includes the fix |
| `0014-CDF-driver-reentrancy-mutex-349` | `CDF_Application` hands one cached storage/retrieval driver instance to every thread, but the drivers keep per-call scratch state, so concurrent `Save`/`Open` of one format corrupt each other ([#349](https://github.com/SecondMouseAU/OCCTSwift/issues/349)) | [OCCT#1393](https://github.com/Open-Cascade-SAS/OCCT/issues/1393) (repro) → **[OCCT#1394](https://github.com/Open-Cascade-SAS/OCCT/pull/1394)** (our fix PR, open) | bundled OCCT includes the fix |
| `0015-CDM_Application-metadata-lookup-table-mutex-353` | `CDM_Application::myMetaDataLookUpTable` and each `CDM_MetaData`'s own fields are shared process-wide with no guard, so a document destructor races another thread's save ([#353](https://github.com/SecondMouseAU/OCCTSwift/issues/353)) | [OCCT#1396](https://github.com/Open-Cascade-SAS/OCCT/issues/1396) (repro) → **[OCCT#1397](https://github.com/Open-Cascade-SAS/OCCT/pull/1397)** (our fix PR, open) | bundled OCCT includes the fix |
| `0016-Resource_Manager-atomic-Debug-Storage_Schema-per-instance-374` | `Resource_Manager::Debug` written unsynchronized on every construction, and `Storage_Schema::ICurrentData()`'s process-wide handle nulled by an unrelated document's `Open()` mid-save ([#374](https://github.com/SecondMouseAU/OCCTSwift/issues/374)); the `Storage_Schema` half redesigned per upstream review from a mutex to a per-instance field ([#518](https://github.com/SecondMouseAU/OCCTSwift/issues/518)) | [OCCT#1398](https://github.com/Open-Cascade-SAS/OCCT/issues/1398) (repro, filed before the PR-only rule) → **[OCCT#1399](https://github.com/Open-Cascade-SAS/OCCT/pull/1399)** (our fix PR, updated to the per-instance design, CI green) | bundled OCCT includes the fix |
| `0017-null-reshape-context-ComposeShell-WireDivide-484` | `ShapeFix_ComposeShell::Perform`/`SplitEdges` and `ShapeUpgrade_WireDivide::Perform` dereference an unset `ShapeBuild_ReShape` context, SIGSEGV on a plain 4-edge planar face ([#484](https://github.com/SecondMouseAU/OCCTSwift/issues/484)) | [OCCT#1409](https://github.com/Open-Cascade-SAS/OCCT/issues/1409) (repro; the maintainer reply on it is what set the PR-only rule) → **[OCCT#1410](https://github.com/Open-Cascade-SAS/OCCT/pull/1410)** (our fix PR, open) | bundled OCCT includes the fix |
| `0018-GCPnts-degenerate-count-and-duplicate-end-point-555` | `GCPnts_UniformAbscissa::NbPoints()` unbounded by the requested count (a `Resolution()` tolerance mismatch appends a duplicate end point), and a count below 2 stores out of bounds in `GCPnts_QuasiUniformAbscissa` ([#555](https://github.com/SecondMouseAU/OCCTSwift/issues/555)) | **[OCCT#1417](https://github.com/Open-Cascade-SAS/OCCT/pull/1417)** (our fix PR, open); first one filed under the PR-only rule, no companion issue | bundled OCCT includes the fix |
| `0019-AdvApp2Var-jacobi-max-wrong-workspace-slot-522` | `GeomConvert_ApproxSurface` at `GeomAbs_C0` returns a degree-1 collapse of a non-linear direction while reporting `IsDone()` and a `MaxError()` five orders of magnitude too small, `mma2ce1_` fills both Jacobi-maxima workspace slots from the V offset, leaving `XMAXJU` zero, which zeroes every interior truncation error the approximator computes ([#522](https://github.com/SecondMouseAU/OCCTSwift/issues/522)) | **[OCCT#1418](https://github.com/Open-Cascade-SAS/OCCT/pull/1418)** (our fix PR, open); filed under the PR-only rule, no companion issue | bundled OCCT includes the fix |
| `0020-BRepFeat_MakeCylindricalHole-select-tool-parts-532` | `BRepFeat_MakeCylindricalHole`'s four part-selecting modes called `PartsOfTool()` after a `BOPAlgo_CUT` instead of a `BOPAlgo_COMMON`, so they selected pieces of the cut result and kept nothing that was actually a tool part, `BRepFeat_NoError` with **no material removed** whenever the drill crossed two bodies, or severed one ([#532](https://github.com/SecondMouseAU/OCCTSwift/issues/532)) | not yet filed; PR-only per the rule above, no companion issue | bundled OCCT includes the fix |
| `0021-CPnts-adaptive-arc-length-integration-603` | `CPnts_AbscissaPoint::Length` and `CPnts_MyRootFunction::Value` integrate arc length with ONE fixed-order Gauss rule over the whole range, so a curve type with no spans to split is measured wrong: a whole ellipse up to 1.737% long, a parabola over `[-100,100]` 3.087% short ([#603](https://github.com/SecondMouseAU/OCCTSwift/issues/603)) | **[OCCT#1420](https://github.com/Open-Cascade-SAS/OCCT/pull/1420)** (our fix PR, open); filed under the PR-only rule, no companion issue | bundled OCCT includes the fix |
| `0022-ChFi2d_Builder-AddChamfer-connexion-error-check-705` | `ChFi2d_Builder::AddChamfer` accepted a duplicate edge pair and produced a wrong 2d chamfer ([#705](https://github.com/SecondMouseAU/OCCTSwift/issues/705)) | [OCCT#1431](https://github.com/Open-Cascade-SAS/OCCT/issues/1431) (repro) → **[OCCT#1432](https://github.com/Open-Cascade-SAS/OCCT/pull/1432)** (our fix PR) | bundled OCCT includes the fix |
| `0023-GeomTools_Curve2dSet-SurfaceSet-null-handle-643` | `GeomTools_Curve2dSet::Add`/`GeomTools_SurfaceSet::Add` bind a null handle and defer the crash to `Write()`, unlike the `GeomTools_CurveSet` sibling which guards ([#643](https://github.com/SecondMouseAU/OCCTSwift/issues/643)) | [OCCT#1434](https://github.com/Open-Cascade-SAS/OCCT/issues/1434) (repro) → **[OCCT#1435](https://github.com/Open-Cascade-SAS/OCCT/pull/1435)** (our fix PR) | bundled OCCT includes the fix |
| `0024-Extrema_ExtCC-Points-bound-against-mypoints-636` | `Extrema_ExtCC::Points` read past its own point container on parallel curves, an uncatchable SIGSEGV ([#636](https://github.com/SecondMouseAU/OCCTSwift/issues/636)) | **[OCCT#1445](https://github.com/Open-Cascade-SAS/OCCT/pull/1445)** (our fix PR, no companion issue) | bundled OCCT includes the fix |
| `0025-GeomFill_Sweep-report-achieved-conversion-error-597` | `GeomFill_Sweep::BuildAll` overwrites the measured C1-conversion error with the requested tolerance, so `ErrorOnSurface()` describes the request rather than the result ([#597](https://github.com/SecondMouseAU/OCCTSwift/issues/597)) | drafted, not sent (`Scripts/repro/597-geomfill-sweep-error-overwrite/draft-pr.md`) | bundled OCCT includes the fix |
| `0026-BRepOffsetAPI_ThruSections-capping-guard-905` | `BRepOffsetAPI_ThruSections::MakeSolid` marks a loft `Closed(true)` even when `PerformPlan()` could not cap an end, so a non-planar closed section silently loses both caps ([#905](https://github.com/SecondMouseAU/OCCTSwift/issues/905)) | **[OCCT#1462](https://github.com/Open-Cascade-SAS/OCCT/pull/1462)** (our fix PR, CI green) | bundled OCCT includes the fix |
| `0027-ThruSections-CreateSmoothed-section-edge-count-guard-913` | `CreateSmoothed()` overruns its fixed-stride `shapes` array, or silently misaligns it, when a section's edge count differs from section 1's under `checkCompatibility(false)` ([#913](https://github.com/SecondMouseAU/OCCTSwift/issues/913)) | **[OCCT#1466](https://github.com/Open-Cascade-SAS/OCCT/pull/1466)** (our fix PR, CI green) | bundled OCCT includes the fix |
| `0028-GeomPlate_BuildPlateSurface-uninitialised-G0-G1-G2-errors-1018` | `GeomPlate_BuildPlateSurface::G0Error()`/`G1Error()`/`G2Error()` return uninitialised members after a `Perform()` whose constraints were all point constraints; the deviations are measured on that branch and discarded ([#1018](https://github.com/SecondMouseAU/OCCTSwift/issues/1018)) | **[OCCT#1481](https://github.com/Open-Cascade-SAS/OCCT/pull/1481)** (our fix PR, no companion issue) | bundled OCCT includes the fix |
| `0029-XCAFDoc_Datum-point-read-from-plane-array-1022` | `XCAFDoc_Datum::GetObject` builds the datum point's X from the annotation plane's array, a wrong answer with both present and an uncatchable SIGSEGV with a point and no plane ([#1022](https://github.com/SecondMouseAU/OCCTSwift/issues/1022)) | **[OCCT#1483](https://github.com/Open-Cascade-SAS/OCCT/pull/1483)** (our fix PR, no companion issue) | bundled OCCT includes the fix |

**Retired in OCCT 8.0.1** (re-pinned 2026-08-03): `0001`-`0009` and `0013`, shipped upstream as
OCCT#1323, #1334, #1374, #1377, #1380, #1382, #1331, #1329, #1318 and #1392 respectively. Their
`.patch` files are deleted; the writeups, and the per-patch check that each merged form matched
what we carried, are kept in `Scripts/patches/README.md` under "Retired patches". Nine matched;
`0001` did not: upstream's merged form also guards a *removed* face, which ours did not, so that
retirement fixed a latent null dereference of our own.

This table stopped at `0021` for six patches, and `0028` is what caught it. It is one of **five**
in-repo statements of the same set, and they do not all answer the same question, which is why
listing them matters more than listing the count:

| Where | What it describes | Moves when |
|---|---|---|
| `Scripts/patches/README.md` | every carried patch, with its writeup | a patch is carried or retired |
| this table | the same set, one row each | the same |
| `Package.swift`'s manifest comment | what the **pinned asset** holds, plus the difference against the tree | the pin moves, or a patch lands untested |
| `docs/occt-upgrades.md` | the carried number range | a patch is carried or retired |
| `docs/CHANGELOG.md`'s released-version header | what the asset that shipped **with that version** held | never, once the version is released |

`Scripts/patches/README.md` is canonical for the first four. The changelog's copy is a historical
record of a shipped release and is correct as written even when the tree has moved past it; do not
update it. If this table falls behind again, prefer deleting it for a pointer over letting a stale
copy read as current.

**Numbers are never reused**, so the carried sequence has gaps. That is deliberate: these numbers
are cited across `CLAUDE.md`, `docs/`, closed issues and `Scripts/repro/`, and renumbering would
have silently repointed every citation at a different fix.