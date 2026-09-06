---
type: reference
title: Known OCCT bugs
resource: https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro
tags: [occt, kernel, bugs, patches, thread-safety, crashes, reference]
description: Every OCCT kernel defect this project has root-caused, one row each, with where the fix lives (carried patch, bridge-side guard, shipped upstream, or not a bug) and where the full writeup is.
timestamp: 2026-09-07
---

# Known OCCT bugs

One row per defect. The full investigation for each lives in the place the row links: the
patch's own entry in
[`Scripts/patches/README.md`](https://github.com/SecondMouseAU/OCCTSwift/blob/main/Scripts/patches/README.md)
for anything carried as a kernel patch, and the `Scripts/repro/<issue>/` directory for the
reproducer and the TSan or override-link transcripts. This page is the index, not the record.
[Carried OCCT source patches](carried-occt-patches.md) is the companion table keyed by patch number
rather than by defect; the rules a bridge author needs day to day are the short list in
`CLAUDE.md`'s Known OCCT Bugs section.

Status vocabulary: **patch `NNNN`** means carried in `Scripts/patches/`, and "pinned" or "not
pinned" says whether the release asset `Package.swift` resolves already contains it, which is the
question [Pinned kernel patch check](../policies/pinned-kernel-patch-check.md) exists to answer.
**bridge** means fixed or guarded in `Sources/OCCTBridge` with no kernel change. **8.0.1** means the
fix shipped upstream and the pinned kernel has it natively, so the patch was retired.

## Crashes and wrong answers

| Issue | OCCT site | Defect | Fix | Writeup |
|---|---|---|---|---|
| #176 | `BRepFill_CompatibleWires::SameNumberByPolarMethod` | SIGSEGV on mismatched closed loft profiles | 8.0.0p1, [OCCT#1298](https://github.com/Open-Cascade-SAS/OCCT/pull/1298) | regression test "Loft polar-method SIGSEGV regression (#176)" |
| #263 | `ShapeFix_Face` | use-after-free when a prism's context replaced a face | 8.0.1, [OCCT#1323](https://github.com/Open-Cascade-SAS/OCCT/pull/1323); patch `0001` retired, and upstream's merged form also guards a *removed* face, which ours did not | `Scripts/patches/README.md` retired `0001` |
| #310 | `ShapeAnalysis_FreeBounds::connectWiresToWiresImpl` | empty-input early return left `owires` null, SIGSEGV in `Append` | 8.0.1, [OCCT#1377](https://github.com/Open-Cascade-SAS/OCCT/pull/1377); `0004` retired | retired `0004` entry; upstream repro [OCCT#1376](https://github.com/Open-Cascade-SAS/OCCT/issues/1376) |
| #317 | `ShapeFix_Face::FixPeriodicDegenerated` | the one of twelve `Context()->Replace` sites with no null-context guard | 8.0.1, [OCCT#1380](https://github.com/Open-Cascade-SAS/OCCT/pull/1380); `0005` retired. Bridge still calls `SetContext(new ShapeBuild_ReShape)` at all three `ShapeFix_Face` sites | retired `0005` entry |
| #318 | `BRepGProp_EdgeTool::IntegrationOrder` | re-derived pole count from `Curve().Curve()`, null for a pcurve-only degenerate edge | 8.0.1, [OCCT#1382](https://github.com/Open-Cascade-SAS/OCCT/pull/1382); `0006` retired. `OCCTShapeAnalyze`'s small-edge scan also skips degenerate edges | retired `0006` entry |
| #319 | `Intf_Interference::Insert` / `BOPAlgo_CheckerSI` | O(n) `GetPoint` per comparison and no progress poll below a whole face, so `isSelfIntersecting(hardTimeout:)` ran 619 s past a 30 s deadline | patch `0010`, pinned; [OCCT#1386](https://github.com/Open-Cascade-SAS/OCCT/pull/1386) open | `Scripts/repro/319-selfintersection/` |
| #323 | `ShapeAnalysis_FreeBounds` (stale `lwire`), `Geom_BSplineCurve::PeriodicNormalization` (O(N) loop that could never terminate), `StepData_StepWriter::AddString` (infinite loop on a >72-char token) | three proactive backports | 8.0.1, [OCCT#1331](https://github.com/Open-Cascade-SAS/OCCT/pull/1331) / [#1329](https://github.com/Open-Cascade-SAS/OCCT/pull/1329) / [#1318](https://github.com/Open-Cascade-SAS/OCCT/pull/1318); `0007`-`0009` retired | retired entries; `STEPWriterOversizedNameTests` |
| #345 | `gp_Dir`, `gp_Ax1`/`Ax2`/`Ax3`, `Geom_Direction`, `D0`-`D2` evaluators | `Standard_ConstructionError` thrown from 49 bridge functions with no `try` in the chain, `std::terminate` at the Swift boundary, the SIGABRT nothing could localise | bridge: every site wrapped, `_Nonnull` returners fall back to a valid default axis. 70 clean full-suite runs | `Tests/OCCTStressTests/StressNullInvalidTests.swift`; the fourteen `occtBuildTrsf3D` callers all sit inside a `try` (#995) |
| #348 | `ShapeUpgrade_UnifySameDomain::IntUnifyFaces` / `SplitWire` | five `CurveOnSurface` results dereferenced without `IsNull()` | 8.0.1, [OCCT#1392](https://github.com/Open-Cascade-SAS/OCCT/pull/1392); `0013` retired | `Scripts/repro/348-unify-null-pcurve/` |
| #430, #433, #434 | `BRepFill_Filling::AddConstraints` + `GeomPlate_BuildPlateSurface::Perform` | face-less branch discards the pcurve's `f`/`l`, a ±2e100 constraint; the `!Ok` recovery then dereferences the handle `Perform` nullified on entry. Catchable on a planar support, an uncatchable SIGSEGV on a periodic one, and G1 was the default | bridge: `occtFillingSupportFaceFromPCurve`/`occtFillingAddConstraint` synthesise a support face so the trimming overload is used. Kernel one-liner proven, deliberately not carried or filed. #433/#434 converged `FillingSurface` onto the same builder | `Scripts/repro/430-fill-untrimmed-pcurve/` |
| #484 | `ShapeFix_ComposeShell::Perform`, `ShapeUpgrade_WireDivide::Perform` | dereference an unset `ShapeBuild_ReShape` context | patch `0017`, pinned; [OCCT#1410](https://github.com/Open-Cascade-SAS/OCCT/pull/1410) open | `Scripts/repro/484-null-reshape-context/` |
| #522 | `AdvApp2Var_ApproxF2var::mma2ce1_` | both Jacobi-maxima fills targeted the V slot, so every interior truncation error was zero: `GeomConvert_ApproxSurface` at C0 collapsed a sphere to a line while reporting `MaxError()` 1e-4. A 2021 regression (#756) | patch `0019`, pinned; [OCCT#1418](https://github.com/Open-Cascade-SAS/OCCT/pull/1418) **merged** | `Scripts/repro/522-approx-c0-collapse/` |
| #532 | `BRepFeat_MakeCylindricalHole` | four part-selecting modes read `PartsOfTool()` after a CUT instead of a COMMON, `NoError` with nothing removed whenever the cut result had two solids | patch `0020`, pinned; [OCCT#1447](https://github.com/Open-Cascade-SAS/OCCT/pull/1447) open. `PerformThruNext`'s unreachable `parbar > Last` branch is reported, not fixed | `Scripts/repro/532-cylindrical-hole-part-selection/` |
| #555 | `GCPnts_UniformAbscissa`, `GCPnts_QuasiUniformAbscissa` | point count unbounded by the request (duplicate end point); count below 2 stores out of bounds | patch `0018`, pinned; [OCCT#1457](https://github.com/Open-Cascade-SAS/OCCT/pull/1457) open (refiled from #1417). No CI coverage: the bridge stops the input first | `Scripts/repro/555-gcpnts-count-contract/` |
| #597 (kernel) | `GeomFill_Sweep::BuildAll` | `SError = theTol` after a forced C1 conversion, so `ErrorOnSurface()` reports the request (1e-4) not the result (2.547 on the #572 fixture) | patch `0025`, pinned; upstream PR drafted, not sent | `Scripts/repro/597-geomfill-sweep-error-overwrite/` |
| #597 (bridge) | `GeomPlate_MakeApprox::ApproxError()`, `BRepOffsetAPI_MakeFilling::G0Error()` | look like the gate for "accepted an approximation unread" and are not: the first measures an intermediate surface, the second exceeds the 1e-4 default on correct fills | no fix, by measurement; two doc comments record why | `Scripts/repro/597-bridge-modeling-healing-approx-error/` |
| #603 | `CPnts_AbscissaPoint::Length`, `CPnts_MyRootFunction::Value` | one fixed-order Gauss rule over the whole range: an ellipse 1.7% long, a parabola 3.1% short | patch `0021`, pinned; [OCCT#1420](https://github.com/Open-Cascade-SAS/OCCT/pull/1420) open. Bridge also subdivides (`occtAdaptorArcLength`), redundant once the kernel is pinned. `BRepGProp::LinearProperties` has its own integrator and is still wrong | `Scripts/repro/603-single-span-quadrature/` |
| #636 | `Extrema_ExtCC::Points` | reads past its own container on parallel curves | patch `0024`, pinned; [OCCT#1445](https://github.com/Open-Cascade-SAS/OCCT/pull/1445) open | `Scripts/repro/636-extrema-parallel/` |
| #643 | `GeomTools_Curve2dSet::Add`/`Index`, `GeomTools_SurfaceSet::Add`/`Index` | accept a null handle and crash in `Write()`, unlike `CurveSet` | patch `0023`, pinned; [OCCT#1435](https://github.com/Open-Cascade-SAS/OCCT/pull/1435) open. Both bridge call sites already guard every element | `Scripts/repro/643-geomtools-null-write/` |
| #705 | `ChFi2d_Builder::AddChamfer` | accepted a duplicate edge pair, null dereference | patch `0022`, pinned; [OCCT#1432](https://github.com/Open-Cascade-SAS/OCCT/pull/1432) open | `Scripts/repro/705-chamfer2d-duplicate-pair/` |
| #905 | `BRepOffsetAPI_ThruSections::MakeSolid` | marks the loft `Closed(true)` after `PerformPlan()` failed to cap a non-planar section (k >= 2 periods of out-of-plane variation). A null-face check is the wrong fix: a punctual section legitimately has none | patch `0026`, pinned; [OCCT#1462](https://github.com/Open-Cascade-SAS/OCCT/pull/1462) open | `Scripts/repro/905-thrusections-capping-guard/` |
| #913 | `BRepOffsetAPI_ThruSections::CreateSmoothed` | fixed-stride `shapes` array sized from section 1, overrun or silently misaligned under `checkCompatibility(false)` with 3+ sections | patch `0027`, pinned; [OCCT#1466](https://github.com/Open-Cascade-SAS/OCCT/pull/1466) open | `Scripts/repro/913-thrusections-createsmoothed-section-edge-count-guard/` |
| #1018 | `GeomPlate_BuildPlateSurface::G0Error`/`G1Error`/`G2Error` | uninitialised after a point-only `Perform()`; proved with a `0x5A`-filled placement-new | patch `0028`, **not pinned**; [OCCT#1481](https://github.com/Open-Cascade-SAS/OCCT/pull/1481) open. Its only bridge reader was deleted by #999 | `Scripts/repro/1018-geomplate-uninitialised-errors/` |
| #1022, #1030 | `XCAFDoc_Datum::GetObject` | reads the point's X from the annotation plane's array: wrong value with both, uncatchable SIGSEGV with a point and no plane. Reachable from all seven bridge datum functions via `occtDocumentDatumObjectAt` and from an OCAF load | patch `0029`, **not pinned**; [OCCT#1483](https://github.com/Open-Cascade-SAS/OCCT/pull/1483) open. Bridge guard #1030 refuses the crashing shape and must be retired when the kernel is repinned | `Scripts/repro/1022-datum-point-from-plane-array/`, `Scripts/repro/1030-datum-lookup-guard/` |

## Thread-safety

The 2026 cluster. Every one was found under this project's TSan protocol (minimal-module
instrumented rebuild, `Scripts/tsan-stress.sh`), and each fix followed the same pattern: a bridge
mutex first where one was needed, then a kernel patch. Read #371 and #374 together: moving from the
shared `GetApplication()` singleton to a private `TDocStd_Application` per document is what first
made the `Resource_Manager`/`Storage_Schema` races concurrent, so `ocafStoreMutex()` is not
redundant after that refactor and its coverage was widened rather than removed.

| Issue | OCCT site | Defect | Fix | Writeup |
|---|---|---|---|---|
| #298 | `ChFi3d`/`TopOpeBRep` fillet statics | non-reentrant globals in solid reconstruction | 8.0.1, [OCCT#1374](https://github.com/Open-Cascade-SAS/OCCT/pull/1374); `0003` retired | retired `0003` entry |
| #341, #363 | `XCAFDoc_ShapeTool::theAutoNaming` | process-global flag saved/mutated/restored by three importers with no synchronisation. The mutex first draft was wrong (upstream review): the override is per-document intent, now a per-instance `OwnAutoNamingScope` | patch `0011`, pinned; [OCCT#1388](https://github.com/Open-Cascade-SAS/OCCT/pull/1388) open | `Scripts/repro/341-meshcaf/`, `Scripts/repro/363-own-autonaming/` |
| #344 | `XCAFApp_Application::GetApplication()`, `CDF_Directory`, `TDocStd_Application::Resources()`, `Resource_Manager`, `CDF_Application::myReaders`/`myWriters` | lazy-singleton double-construction plus unsynchronised maps; the SIGSEGV #341 didn't explain | patch `0012`, pinned; [OCCT#1390](https://github.com/Open-Cascade-SAS/OCCT/pull/1390) open | `Scripts/repro/344-cdf-directory/` |
| #349 | `PCDM_StorageDriver`/`PCDM_Reader` | one cached driver per format shared across threads, and every driver keeps per-call scratch state | patch `0014`, pinned; [OCCT#1394](https://github.com/Open-Cascade-SAS/OCCT/pull/1394) open. `ocafStoreMutex()` stays bridge-side | `Scripts/repro/349-ocaf-driver-reentrancy/` |
| #353 | `CDM_Application::myMetaDataLookUpTable`, `CDM_MetaData` | unsynchronised table iteration against another thread's document destructor | patch `0015`, pinned; [OCCT#1397](https://github.com/Open-Cascade-SAS/OCCT/pull/1397) open. `CDM_MetaData::myDocumentVersion` has the same shape, unobserved, unfixed | `Scripts/repro/353-cdm-metadata-lookup-table/` |
| #371 | `XCAFApp_Application::GetApplication()` | the singleton itself is the root of #341/#344/#349/#353; retired bridge-side for a private `TDocStd_Application` per document. Two latent wrong-app-instance bugs fixed on the way | bridge | `Scripts/repro/371-getapplication-singleton-elimination/` |
| #374 | `Resource_Manager::Debug`, `Storage_Schema::ICurrentData()` | file-scope static written on every construction; process-wide handle nulled by any `Open()` mid-save | patch `0016`, pinned; [OCCT#1399](https://github.com/Open-Cascade-SAS/OCCT/pull/1399) open, redesigned per review to a per-instance field (#518) | `Scripts/repro/374-resource-manager-storage-schema-race/` |
| #1154 | `TopoDS_TShape::myState` | non-atomic read-modify-write of the flag word on a TShape shared between a boolean result and its inputs | patch `0030`, **not pinned**; not yet filed. `Scripts/tsan.supp` suppresses it until a rebuild and must be trimmed then | `Scripts/repro/1154-topology-flag-race/` |
| #1153 | `BSplCLib_Cache`/`BSplSLib_Cache`, `GeomAdaptor_Curve`/`GeomAdaptor_Surface` | unsynchronised per-span cache plus a check-then-act on the cache handle one layer up. First attempt (PR #1322) self-deadlocked on `D1()` and was rejected; the fix is a recursive mutex plus a hand-written copy constructor | patch `0031`, **not pinned**; not yet filed. Watch [OCCT#1076](https://github.com/Open-Cascade-SAS/OCCT/pull/1076): retarget, don't drop, if it renames the classes | `Scripts/repro/1153-bspline-adaptor-cache/` |
| #1371 | `TopOpeBRepBuild` `GLOBAL_*`/`stabuild_*` statics | twelve file-scope globals, confirmed unreachable from this bridge's call surface | **patch `0032` retired 2026-09-02, never shipped**: upstream [OCCT#1505](https://github.com/Open-Cascade-SAS/OCCT/pull/1505)/[#1509](https://github.com/Open-Cascade-SAS/OCCT/pull/1509) fix the same globals better, and `GLOBAL_faces2d` too | `Scripts/repro/1155-thread-safety-survey/`, retired `0032` entry |
| #1157 | `Interface_Static` (really `MoniTool_TypedValue::Stats()`'s map) | shared STEP/IGES parameter table mutated concurrently; `thread_local` is wrong because four one-time-init guards assume one table | patch `0033`, **not pinned**; not yet filed. Partial by design: an accessor lock cannot stop two operations setting the same parameter from cross-talking (measured 100%), so `igesMutex()` stays. Nine sibling classes carry the same shape (#1403) | `Scripts/repro/1157-interface-static-thread-safety/` |

## Not a bug

| Issue | Claim | Verdict | Writeup |
|---|---|---|---|
| #341 (part) | container overflow in `NCollection` on arm64 | never characterised, no race under TSan; three suites re-enabled | `Scripts/repro/341-meshcaf/` |
| #367, #369 | `OSD_ThreadPool::DefaultPool()` corrupts concurrent `SetRunParallel(true)` callers | `BRepAlgoAPI_BuilderAlgo` is General Fuse (a split-parts compound), not `BRepAlgoAPI_Fuse` (a merged solid); the reproducer compared the two. The 237 July races were #1153/#1154. The pool is safe. Whether to re-enable `SetRunParallel(true)` in `OCCTShapeFuseMulti` is a separate, open decision | `Scripts/repro/342-boolean-ops/` |

## Where this list used to live

Until 2026-09-07 every row above was a multi-paragraph entry in `CLAUDE.md`, 112 KB of a 159 KB
file. It moved here so the agent-instructions file carries the rules and this carries the record.
Older changelog entries, repro READMEs and test doc comments that say "see CLAUDE.md's Known OCCT
Bugs" still land on a short section there that points here.
