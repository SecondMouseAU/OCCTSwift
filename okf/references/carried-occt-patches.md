---
type: reference
title: Carried OCCT source patches
resource: https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/patches
tags: [occt, patches, upstream, thread-safety, kernel]
description: Upstream-bound OCCT fixes OCCTSwift carries in its xcframework build until they ship in an OCCT release.
timestamp: 2026-09-07
---

# Carried OCCT source patches

OCCTSwift bundles a prebuilt `OCCT.xcframework`. When we find an upstream OCCT bug, we
carry a source patch in [`Scripts/patches/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/patches)
that `Scripts/build-occt.sh` applies before each build, so the fix ships in our binary
ahead of an official OCCT release. Each patch is **temporary**: retire it once the
bundled OCCT version includes the fix. Full rationale + validation per patch lives in
`Scripts/patches/README.md`: this note is the ecosystem-level pointer.

**A patch landing or retiring also changes a derived file that is not in this directory.**
`Scripts/occt-raise-if-map.txt` is a committed derivation of the patched `Libraries/occt-src`, so a
patch that adds or moves an `<Exception>_Raise_if` or a `throw` changes it, and for two pins
nothing re-derived it: `0042` put a throw in `ShapeAnalysis::GetFaceUVBounds` and the map said that
class held no live throw (#2885). Regenerate with
`python3 Scripts/census-compiled-out-validation.py --write-table`;
`check-inventory-prose.py` fails when the map's provenance stamp and `Scripts/patches/` disagree.

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
| `0011-XCAFDoc_ShapeTool-AutoNamingScope-341` | `XCAFDoc_ShapeTool::theAutoNaming` process-global race across concurrent OBJ/glTF import and PLY/OBJ/glTF export ([#341](https://github.com/SecondMouseAU/OCCTSwift/issues/341)); revised per upstream review to a per-instance `OwnAutoNamingScope` instead of a mutex-guarded global flag ([#363](https://github.com/SecondMouseAU/OCCTSwift/issues/363)) | [OCCT#1387](https://github.com/Open-Cascade-SAS/OCCT/issues/1387) (repro) → **[OCCT#1388](https://github.com/Open-Cascade-SAS/OCCT/pull/1388)** (our fix PR, **closed unmerged 2026-09-25**: the maintainer said the `theAutoNaming` global becomes a class member in 8.1.0, so it is no longer on the offered list; still carried here) | bundled OCCT includes the fix |
| `0012-CDF_Directory-XCAFApp_Application-thread-safety-344` | `XCAFApp_Application::GetApplication()`/`TDocStd_Application::Resources()` lazy-singleton races + unsynchronized `CDF_Directory`/`Resource_Manager`/`CDF_Application` reader-writer maps. SIGSEGV surviving the #341 fix ([#344](https://github.com/SecondMouseAU/OCCTSwift/issues/344); a related but architecturally different driver-reentrancy crash found in the same validation is tracked separately as [#349](https://github.com/SecondMouseAU/OCCTSwift/issues/349)) | [OCCT#1389](https://github.com/Open-Cascade-SAS/OCCT/issues/1389) (repro) → **[OCCT#1390](https://github.com/Open-Cascade-SAS/OCCT/pull/1390)** (our fix PR, 2 commits, CI pending) | bundled OCCT includes the fix |
| `0014-CDF-driver-reentrancy-mutex-349` | `CDF_Application` hands one cached storage/retrieval driver instance to every thread, but the drivers keep per-call scratch state, so concurrent `Save`/`Open` of one format corrupt each other ([#349](https://github.com/SecondMouseAU/OCCTSwift/issues/349)) | [OCCT#1393](https://github.com/Open-Cascade-SAS/OCCT/issues/1393) (repro) → **[OCCT#1394](https://github.com/Open-Cascade-SAS/OCCT/pull/1394)** (our fix PR, open) | bundled OCCT includes the fix |
| `0015-CDM_Application-metadata-lookup-table-mutex-353` | `CDM_Application::myMetaDataLookUpTable` and each `CDM_MetaData`'s own fields are shared process-wide with no guard, so a document destructor races another thread's save ([#353](https://github.com/SecondMouseAU/OCCTSwift/issues/353)) | [OCCT#1396](https://github.com/Open-Cascade-SAS/OCCT/issues/1396) (repro) → **[OCCT#1397](https://github.com/Open-Cascade-SAS/OCCT/pull/1397)** (our fix PR, open) | bundled OCCT includes the fix |
| `0016-Resource_Manager-atomic-Debug-Storage_Schema-per-instance-374` | `Resource_Manager::Debug` written unsynchronized on every construction, and `Storage_Schema::ICurrentData()`'s process-wide handle nulled by an unrelated document's `Open()` mid-save ([#374](https://github.com/SecondMouseAU/OCCTSwift/issues/374)); the `Storage_Schema` half redesigned per upstream review from a mutex to a per-instance field ([#518](https://github.com/SecondMouseAU/OCCTSwift/issues/518)) | [OCCT#1398](https://github.com/Open-Cascade-SAS/OCCT/issues/1398) (repro, filed before the PR-only rule) → **[OCCT#1399](https://github.com/Open-Cascade-SAS/OCCT/pull/1399)** (our fix PR, updated to the per-instance design, CI green) | bundled OCCT includes the fix |
| `0017-null-reshape-context-ComposeShell-WireDivide-484` | `ShapeFix_ComposeShell::Perform`/`SplitEdges` and `ShapeUpgrade_WireDivide::Perform` dereference an unset `ShapeBuild_ReShape` context, SIGSEGV on a plain 4-edge planar face ([#484](https://github.com/SecondMouseAU/OCCTSwift/issues/484)) | [OCCT#1409](https://github.com/Open-Cascade-SAS/OCCT/issues/1409) (repro; the maintainer reply on it is what set the PR-only rule) → **[OCCT#1410](https://github.com/Open-Cascade-SAS/OCCT/pull/1410)** (our fix PR, open) | bundled OCCT includes the fix |
| `0018-GCPnts-degenerate-count-and-duplicate-end-point-555` | `GCPnts_UniformAbscissa::NbPoints()` unbounded by the requested count (a `Resolution()` tolerance mismatch appends a duplicate end point), and a count below 2 stores out of bounds in `GCPnts_QuasiUniformAbscissa` ([#555](https://github.com/SecondMouseAU/OCCTSwift/issues/555)) | **[OCCT#1457](https://github.com/Open-Cascade-SAS/OCCT/pull/1457)** (our fix PR, open, base `IR`; refiled from [#1417](https://github.com/Open-Cascade-SAS/OCCT/pull/1417), closed); first one filed under the PR-only rule, no companion issue | bundled OCCT includes the fix |
| `0019-AdvApp2Var-jacobi-max-wrong-workspace-slot-522` | `GeomConvert_ApproxSurface` at `GeomAbs_C0` returns a degree-1 collapse of a non-linear direction while reporting `IsDone()` and a `MaxError()` five orders of magnitude too small, `mma2ce1_` fills both Jacobi-maxima workspace slots from the V offset, leaving `XMAXJU` zero, which zeroes every interior truncation error the approximator computes ([#522](https://github.com/SecondMouseAU/OCCTSwift/issues/522)) | **[OCCT#1418](https://github.com/Open-Cascade-SAS/OCCT/pull/1418)** (our fix PR, **merged**, base `IR`); filed under the PR-only rule, no companion issue | bundled OCCT includes the fix |
| `0020-BRepFeat_MakeCylindricalHole-select-tool-parts-532` | `BRepFeat_MakeCylindricalHole`'s four part-selecting modes called `PartsOfTool()` after a `BOPAlgo_CUT` instead of a `BOPAlgo_COMMON`, so they selected pieces of the cut result and kept nothing that was actually a tool part, `BRepFeat_NoError` with **no material removed** whenever the drill crossed two bodies, or severed one ([#532](https://github.com/SecondMouseAU/OCCTSwift/issues/532)) | **[OCCT#1447](https://github.com/Open-Cascade-SAS/OCCT/pull/1447)** (our fix PR, open, no companion issue) | bundled OCCT includes the fix |
| `0021-CPnts-adaptive-arc-length-integration-603` | `CPnts_AbscissaPoint::Length` and `CPnts_MyRootFunction::Value` integrate arc length with ONE fixed-order Gauss rule over the whole range, so a curve type with no spans to split is measured wrong: a whole ellipse up to 1.737% long, a parabola over `[-100,100]` 3.087% short ([#603](https://github.com/SecondMouseAU/OCCTSwift/issues/603)) | **[OCCT#1420](https://github.com/Open-Cascade-SAS/OCCT/pull/1420)** (our fix PR, open); filed under the PR-only rule, no companion issue | bundled OCCT includes the fix |
| `0022-ChFi2d_Builder-AddChamfer-connexion-error-check-705` | `ChFi2d_Builder::AddChamfer` accepted a duplicate edge pair and produced a wrong 2d chamfer ([#705](https://github.com/SecondMouseAU/OCCTSwift/issues/705)) | [OCCT#1431](https://github.com/Open-Cascade-SAS/OCCT/issues/1431) (repro) → **[OCCT#1432](https://github.com/Open-Cascade-SAS/OCCT/pull/1432)** (our fix PR) | bundled OCCT includes the fix |
| `0023-GeomTools_Curve2dSet-SurfaceSet-null-handle-643` | `GeomTools_Curve2dSet::Add`/`GeomTools_SurfaceSet::Add` bind a null handle and defer the crash to `Write()`, unlike the `GeomTools_CurveSet` sibling which guards ([#643](https://github.com/SecondMouseAU/OCCTSwift/issues/643)) | [OCCT#1434](https://github.com/Open-Cascade-SAS/OCCT/issues/1434) (repro) → **[OCCT#1435](https://github.com/Open-Cascade-SAS/OCCT/pull/1435)** (our fix PR) | bundled OCCT includes the fix |
| `0024-Extrema_ExtCC-Points-bound-against-mypoints-636` | `Extrema_ExtCC::Points` read past its own point container on parallel curves, an uncatchable SIGSEGV ([#636](https://github.com/SecondMouseAU/OCCTSwift/issues/636)) | **[OCCT#1445](https://github.com/Open-Cascade-SAS/OCCT/pull/1445)** (our fix PR, no companion issue) | bundled OCCT includes the fix |
| `0025-GeomFill_Sweep-report-achieved-conversion-error-597` | `GeomFill_Sweep::BuildAll` overwrites the measured C1-conversion error with the requested tolerance, so `ErrorOnSurface()` describes the request rather than the result ([#597](https://github.com/SecondMouseAU/OCCTSwift/issues/597)) | **[OCCT#1547](https://github.com/Open-Cascade-SAS/OCCT/pull/1547)** (our fix PR, open, base `master`) | bundled OCCT includes the fix |
| `0026-BRepOffsetAPI_ThruSections-capping-guard-905` | `BRepOffsetAPI_ThruSections::MakeSolid` marks a loft `Closed(true)` even when `PerformPlan()` could not cap an end, so a non-planar closed section silently loses both caps ([#905](https://github.com/SecondMouseAU/OCCTSwift/issues/905)) | **[OCCT#1462](https://github.com/Open-Cascade-SAS/OCCT/pull/1462)** (our fix PR, CI green) | bundled OCCT includes the fix |
| `0027-BRepOffsetAPI_ThruSections-CreateSmoothed-section-edge-count-guard-913` | `CreateSmoothed()` overruns its fixed-stride `shapes` array, or silently misaligns it, when a section's edge count differs from section 1's under `checkCompatibility(false)` ([#913](https://github.com/SecondMouseAU/OCCTSwift/issues/913)) | **[OCCT#1466](https://github.com/Open-Cascade-SAS/OCCT/pull/1466)** (our fix PR, CI green) | bundled OCCT includes the fix |
| `0028-GeomPlate_BuildPlateSurface-uninitialised-G0-G1-G2-errors-1018` | `GeomPlate_BuildPlateSurface::G0Error()`/`G1Error()`/`G2Error()` return uninitialised members after a `Perform()` whose constraints were all point constraints; the deviations are measured on that branch and discarded ([#1018](https://github.com/SecondMouseAU/OCCTSwift/issues/1018)) | **[OCCT#1481](https://github.com/Open-Cascade-SAS/OCCT/pull/1481)** (our fix PR, no companion issue) | bundled OCCT includes the fix |
| `0029-XCAFDoc_Datum-point-read-from-plane-array-1022` | `XCAFDoc_Datum::GetObject` builds the datum point's X from the annotation plane's array, a wrong answer with both present and an uncatchable SIGSEGV with a point and no plane ([#1022](https://github.com/SecondMouseAU/OCCTSwift/issues/1022)) | **[OCCT#1483](https://github.com/Open-Cascade-SAS/OCCT/pull/1483)** (our fix PR, no companion issue) | bundled OCCT includes the fix |

| `0030-TopoDS_TShape-myState-atomic-1154` | `TopoDS_TShape::myState` mutated by non-atomic read-modify-write on a TShape shared between a boolean result and its inputs, a lost-update race in ordinary concurrent use ([#1154](https://github.com/SecondMouseAU/OCCTSwift/issues/1154)) | **[OCCT#1548](https://github.com/Open-Cascade-SAS/OCCT/pull/1548)** (our fix PR, open, base `master`) | bundled OCCT includes the fix; also trim the `Scripts/tsan.supp` lines that suppress it |
| `0033-Interface_Static-thread-safety-mutex-1157` | `Interface_Static`'s shared STEP/IGES parameter table mutated concurrently; a recursive mutex over all seventeen entry points. Partial by design: no accessor lock stops two operations setting the same parameter from cross-talking, so the bridge's `igesMutex()` stays ([#1157](https://github.com/SecondMouseAU/OCCTSwift/issues/1157)) | **[OCCT#1553](https://github.com/Open-Cascade-SAS/OCCT/pull/1553)** (our fix PR, open, base `master`) | bundled OCCT includes the fix |
| `0034-GeomFill-CoonsAlgPatch-Value-U-parameter-1515` | `GeomFill_CoonsAlgPatch::Value(U, V)` sampled all four boundaries at `V`, where `bound[0]`/`bound[2]` are the U-direction sides. For any boundary set with straight V-direction sides the surface is independent of `U` and collapses onto the `U == V` diagonal; only `U == V` samples were right. Two lines, coefficients untouched, and `D1U` is exactly its derivative ([#1515](https://github.com/SecondMouseAU/OCCTSwift/issues/1515)) | **[OCCT#1550](https://github.com/Open-Cascade-SAS/OCCT/pull/1550)** (our fix PR, open, base `master`) | bundled OCCT includes the fix |
| `0036-IFSelect_WorkSession-per-instance-error-guard-1403` | `IFSelect_WorkSession`'s file-scope `errhand` is a recursion sentinel, not a value: one thread clearing it makes another take the **unguarded** path and lose its exception handling. Relocated to a per-instance `myInErrorHandler`, no lock, the #363 pattern. 6 race access sites to 0, measured ([#1403](https://github.com/SecondMouseAU/OCCTSwift/issues/1403)) | **[OCCT#1549](https://github.com/Open-Cascade-SAS/OCCT/pull/1549)** (our fix PR, open, base `master`) | bundled OCCT includes the fix |
| `0037-STEPControl-ActorRead-non-manifold-flag-per-instance-2061` | `STEPControl_ActorRead`'s `NM_DETECTED` is an anonymous-namespace global holding per-operation state: it gates whether a `COMPOUND` component is flattened into its parent or kept nested, so concurrent STEP reads share it. Relocated to a per-instance `myIsNMDetected`, no lock, no signature change, the #363 pattern. 5-of-5 runs report the race unpatched, 0-of-5 patched. The wrong-shape outcome follows by inspection but was NOT reproduced ([#2061](https://github.com/SecondMouseAU/OCCTSwift/issues/2061)) | **[OCCT#1552](https://github.com/Open-Cascade-SAS/OCCT/pull/1552)** (our fix PR, open, base `master`) | bundled OCCT includes the fix |
| `0038-Interface_CheckTool-errh-per-instance-1403` | `Interface_CheckTool`'s file-scope `errh` decides whether `FillCheck` guards each module `CheckCase` call. The six bulk list builders clear it and never restore it, so any bulk list operation leaves error handling off process-wide and a later direct `FillCheck` runs unguarded, losing a `Standard_Failure` that should have been reported as a check fail. Reachable single-threaded, not only a race. Relocated to a private member, no signature change. 7 race reports to 0 ([#1403](https://github.com/SecondMouseAU/OCCTSwift/issues/1403)) | **[OCCT#1555](https://github.com/Open-Cascade-SAS/OCCT/pull/1555)** (our fix PR) | bundled OCCT includes the fix |
| `0039-Interface_FileReaderData-per-instance-param-cache-1403` | `Param()`/`ChangeParam()` memoised the last record and its base offset in file-scope statics, gated by a global counter so only the newest instance could use the memo. `mutable` answers the declaration's own blocker ("Fields not possible, because Param is const") and also makes the optimisation apply at all, since any second construction disabled it for every earlier instance. `InitParams()` now invalidates the memo, which the original never needed to. 4 race reports to 0 ([#1403](https://github.com/SecondMouseAU/OCCTSwift/issues/1403)) | **held from upstream, not filed**: no test can demonstrate it, see the patch README | bundled OCCT includes the fix |
| `0040-controller-one-time-init-thread-safe-1403` | Three unguarded check-then-act one-time-init flags: both `STEPControl_Controller::Init()` and `IGESControl_Controller::Init()`, plus the IGES constructor. Only STEP's *constructor* had a mutex, so this was three sites rather than the one asymmetry #1403's re-scope claimed. All become function-local statics, removing the check-then-act instead of locking it. Guarding the outermost init also serialises the whole chain beneath it, which is why six further one-time-init globals stopped being reported ([#1403](https://github.com/SecondMouseAU/OCCTSwift/issues/1403)) | **held from upstream, not filed**: no GTest can observe it: a second call of a one-time init in a shared GTest binary is unobservable; revisit if a way to observe it appears | bundled OCCT includes the fix |
| `0041-DE-registry-maps-synchronised-1403` | `listad` (`XSControl_Controller.cxx:59`) and `atemp` (`Interface_InterfaceModel.cxx:44`), two process-wide name-keyed registries mutated without synchronisation. A lock is correct here rather than relocation, because one registry per process is the design. Recursive is required: `Template()` calls `HasTemplate()` before reading the map. `astats` excluded, already covered by `0033` ([#1403](https://github.com/SecondMouseAU/OCCTSwift/issues/1403)) | **[OCCT#1603](https://github.com/Open-Cascade-SAS/OCCT/pull/1603)** (our fix PR, open, base `IR`; stress GTests, one of them probabilistic with a measured failure rate) | bundled OCCT includes the fix |
| `0042-ShapeAnalysis-GetFaceUVBounds-null-surface-2773` | `ShapeAnalysis::GetFaceUVBounds` dereferences a null surface on a face with **no surface and no edges**, an uncatchable SIGSEGV landing exactly where `ShapeUpgrade_ShapeDivide`'s own `ShapeExtend_FAIL2` handler was meant to report. Raises `Standard_NullObject` instead: returning silently was measured and does not fix it, because `ShapeUpgrade_FaceDivide::SplitSurface` dereferences the same null surface eight lines later. The surface-less face **with** a wire already raised from `Bnd_Box2d::Get`, so the two input classes now agree ([#2773](https://github.com/SecondMouseAU/OCCTSwift/issues/2773)) | **[OCCT#1583](https://github.com/Open-Cascade-SAS/OCCT/pull/1583)** (our fix PR, open, base `master`, with a GTest) | bundled OCCT includes the fix; the bridge guard from [PR #2776](https://github.com/SecondMouseAU/OCCTSwift/pull/2776) stays regardless, it protects consumers on the pinned asset |
| `0043-BRepGProp_Gauss-keeps-the-by-plane-mass-2827` | `BRepGProp_Gauss::convert` computes the by-plane mass in its four-argument form and then overwrites it with `0.0`, with the gravity centre set to `(0, 0, 0)`, because the six-argument form guards the keep with `if (std::abs(theInertia.Mass) >= EPS_DIM && theIsByPoint)` and no by-plane path sets that flag. All four by-plane `BRepGProp_Vinert::Perform` overloads and both `Compute` paths reach it. Dropping `&& theIsByPoint` also makes the dead inner `else` live, and that `else` is the correct by-plane gravity centre rather than merely the reachable one: by-plane `theCoeff` is four plane coefficients, not the three-element translation the by-point branch adds. OCCT has no caller of the path (`BRepGProp.cxx:311` passes a point), so what the value means was derived from the integrand and measured: each face's mass is the signed volume of the column between it and the plane, the per-face sum over a closed shell is the enclosed volume for any plane, and the mass-weighted sum of the centres is the solid's first moment ([#2827](https://github.com/SecondMouseAU/OCCTSwift/issues/2827)) | **[OCCT#1587](https://github.com/Open-Cascade-SAS/OCCT/pull/1587)** (our fix PR, open, base `master`) | bundled OCCT includes the fix |
| `0045-Geom-Bezier-InsertPoleAfter-pole-bound-2875` | `Geom2d_BezierCurve::InsertPoleAfter` and `Geom_BezierCurve::InsertPoleAfter` refuse once the curve holds `MaxDegree()` poles, where both constructors and `Increase()` allow `MaxDegree() + 1`, so insertion stops two poles short of a length the constructor builds happily. `MaxDegree()` is a degree bound, not a pole bound, and both classes' static `Multiplicities()`/`KnotSequence()` tables are sized `MaxDegree() + 1` and indexed by pole count, so the relaxed bound is in range for every derived query. The two sites are the only ones in the tree that compare a pole count against `MaxDegree()` with `>=` ([#2875](https://github.com/SecondMouseAU/OCCTSwift/issues/2875)) | **[OCCT#1593](https://github.com/Open-Cascade-SAS/OCCT/pull/1593)** (our fix PR, open, base `IR`; [#1589](https://github.com/Open-Cascade-SAS/OCCT/pull/1589) closed) | bundled OCCT includes the fix; `OCCTCurve2DBezierInsertPoleAfter`'s guard stays regardless, because `No_Exception` empties the 2d class's `Standard_ConstructionError_Raise_if` and the bridge guard is then the only bound that exists |
| `0046-math_Uzawa-Errinit-row-dimension-2860` | `math_Uzawa` sizes `Errinit` by `Cont.ColNumber()` in both constructors and `Perform` writes it by row, so any overdetermined system writes past its end. The accessor documents the vector as `Cont*StartingPoint-Secont`, one entry per constraint, and every read of it is a row index, so `RowNumber()` is the documented length as well as the written one. `math_Vector` inlines 32 doubles, so the outcome is decided by size: 4 constraints in 2 unknowns returns a wrong answer, 100 in 2 is a deterministic SIGSEGV. The dimension check at the top of `Perform` never relates rows to columns, so `-DBUILD_RELEASE_DISABLE_EXCEPTIONS=OFF` would not catch it either ([#2860](https://github.com/SecondMouseAU/OCCTSwift/issues/2860)) | **[OCCT#1588](https://github.com/Open-Cascade-SAS/OCCT/pull/1588)** (our fix PR, open, base `master`) | bundled OCCT includes the fix; `OCCTMathUzawa`'s `nConstraints > nVars` guard stays regardless, since refusing an overdetermined system is an API decision as well as a crash guard, and relaxing it is a SemVer change |
| `0050-GProp_SelGProps-cone-lateral-area-drops-cos-semiangle-2992` | `GProp_SelGProps::Perform(gp_Cone)` returns `cos(semiAngle)` times the lateral area. `gp_Cone`'s `v` runs along the generatrix, so the area element is `R + v sin a` and the closed form is `(A2 - A1)(Z2 - Z1)(R + (Z2 + Z1) sin a / 2)`; the `Cnt` factor at `GProp_SelGProps.cxx:125` has no term to come from. Neither this class nor `GProp_VelGProps` has a caller anywhere in `Libraries/occt-src`, so per [follow the OCCT callers](../policies/follow-occt-callers.md) the arbiters are the closed form and the cylinder limit: the `gp_Cylinder` overload beside it is exact, and a cone of vanishing semi-angle is that cylinder ([#2992](https://github.com/SecondMouseAU/OCCTSwift/issues/2992)) | **[OCCT#1599](https://github.com/Open-Cascade-SAS/OCCT/pull/1599)** (our fix PR, open, base `IR`), **one PR together with `0051` and `0055`**, because `0055`'s hunks need `0050`'s and `0051`'s context | bundled OCCT includes the fix |
| `0051-GProp_VelGProps-cone-volume-is-the-frustum-2992` | `GProp_VelGProps::Perform(gp_Cone)` returns a quantity carrying a spurious `sin a`, so the reported volume goes to **zero** as the cone becomes the cylinder whose volume the same class answers exactly. The volume of revolution is the frustum, `(A2 - A1) cos a (Z2 - Z1)(R1^2 + R1 R2 + R2^2) / 6`, which reduces to the cylinder overload's `(A2 - A1) R^2 (Z2 - Z1) / 2` at `a = 0`. Same no-caller situation and same two arbiters as `0050` ([#2992](https://github.com/SecondMouseAU/OCCTSwift/issues/2992)) | **[OCCT#1599](https://github.com/Open-Cascade-SAS/OCCT/pull/1599)** (base `IR`), one PR together with `0050` and `0055` | bundled OCCT includes the fix |
| `0052-Geom_BezierSurface-rational-axis-prose-matches-example-2991` | `Geom_BezierSurface.hxx`'s prose for `IsURational`/`IsVRational` contradicts its own example matrix, and the example is the one that matches the code: the static `Rational()` sets `Urational` from `Weights(I, J) != Weights(I, J + 1)`, walking the **column** index, which is V. Each flag therefore names the axis opposite the one it compares along. `Geom_BSplineSurface.hxx` already states the row rule correctly, so the two headers disagree with each other as well. Documentation only ([#2991](https://github.com/SecondMouseAU/OCCTSwift/issues/2991)) | **[OCCT#1602](https://github.com/Open-Cascade-SAS/OCCT/pull/1602)** (our fix PR, open, base `IR`, filed alone; documentation only, so no GTest) | bundled OCCT includes the fix |
| `0053-BRepOffset_MakeOffset-arc-join-roots-in-binding-order-3003` | `BRepOffset_MakeOffset::BuildOffsetByArc` registers every offset face as a root by walking an `NCollection_DataMap` hashed on `TShape` addresses, and the roots are the order of the faces of the result, so every arc-join offset (`BRepOffsetAPI_MakeOffsetShape`, `MakeThickSolid`) comes back in an order that changes between processes and between builds in one, and the volume `BRepGProp` sums over them moves in its last digits (4e-16 to 9e-16 on three lines of two #766 probes). Not parallel, not a race, not uninitialised: one thread, and with the walk fixed, 0 of 72 measured requests move across 20 processes where 29 did. The fix records the binding order and walks that, about thirty-five lines in one function. For an input whose success depends on the root order (the fuse of two boxes, coplanar faces left split: a solid in 11 of 20 processes, 7 and 8 in two earlier censuses, `IsDone()` with a null shape in the rest) the answer is now the same every time, and with binding order it is the failing one; that order sensitivity is its own defect ([#3003](https://github.com/SecondMouseAU/OCCTSwift/issues/3003)) | **[OCCT#1600](https://github.com/Open-Cascade-SAS/OCCT/pull/1600)** (our fix PR, open, base `IR`). Disclosed in the PR: it makes the two-box-fuse arc offset fail deterministically (20 of 20) instead of intermittently, an intersection-stage order dependence it does not address | bundled OCCT includes the fix; the two `tolerance` declarations in the #766 probes came out with v4.0.0-kernel.5 |
| `0054-ChFi3d_Builder-StartSol-drops-an-obstacle-with-no-edge-2881` | `ChFi3d_Builder::StartSol`, on an obstacle whose neighbour face holds no edge to follow, returns `false` but leaves `HC` as the default-constructed `BRepAdaptor_Curve2d` with `c1obstacle` still `true`. `PerformSetOfSurfOnElSpine` tests `!Ok && HC.IsNull()` for the end of the chain, an empty non-null `HC` passes, the obstacle path runs, and the `SurfRst` walk dereferences a null curve through `Geom2dAdaptor_Curve::D1`: a SIGSEGV inside `BRepFilletAPI_MakeFillet::Build` that no bridge `catch (...)` can reach ([#2881](https://github.com/SecondMouseAU/OCCTSwift/issues/2881)). Eight of the 42 edges of the reporter's model crash at radius 1.5 and at no other radius tried; patched they report `IsDone() == false`, as 1.4999999 does, and the other 370 of 378 measured cases are unchanged | **[OCCT#1591](https://github.com/Open-Cascade-SAS/OCCT/pull/1591)** (our fix PR, open, base `master`); the report is [OCCT#1568](https://github.com/Open-Cascade-SAS/OCCT/issues/1568) | bundled OCCT crashes on those eight edges; pinned from v4.0.0-kernel.5 |
| `0055-GProp_SelGProps-GProp_VelGProps-cone-matrix-of-inertia-3010` | `GProp_SelGProps::Perform(gp_Cone)` and `GProp_VelGProps::Perform(gp_Cone)` build `Dm`, the matrix of inertia about the cone's location, from closed forms that do not integrate to anything: the surface `Dm(3, 3)` is `cos a sin a` times the second moment about the axis (12753.28 against 29452.43 at `a` = pi/6, `R` = 5, `v` in [0, 10]), `ISn2` repeats `ICn2`, and `IZ2`, `ICnSn`, `ICnz` and `ISnz` are other polynomials; the volume overload has a cubic over 4 where the moment is a quartic over 20. The surface centre of mass uses `sin a` where the quadratic term is `sin^2 a`, visible for a partial turn only, and the volume centre of mass is the surface one in all three coordinates. `inertia` is then assembled as `diag(lambda) V^T` from the Jacobi decomposition, not `V diag(lambda) V^T`, with `Dm` taken as already about the centre of mass. The patch computes every entry from the integral and assembles `P Dm P^T - H(g, Location) + H(g, loc)`. Against an independent Gauss-Legendre integral, 64 of 64 checks fail before and 0 after, the largest deviation 7.9e-14 ([#3010](https://github.com/SecondMouseAU/OCCTSwift/issues/3010)). The gp_Cylinder and gp_Sphere overloads fail the same probe 16 of 16 and are not touched | **[OCCT#1599](https://github.com/Open-Cascade-SAS/OCCT/pull/1599)** (base `IR`), one PR together with `0050` and `0051` | bundled OCCT returns these cone values wrong; nothing in the bridge reads them |
| `0056-BRepLib-Plane-creates-the-default-plane-under-the-magic-static-lock-3039` | `BRepLib::Plane()` creates its process-global `Geom_Plane` on first use with no lock, and every vertex `BRepLib_MakeEdge2d` builds goes through it, so two threads making their first 2D edge together can read a plane the other has released: a wrong vertex (zeros or denormal garbage) or SIGSEGV, SIGBUS or SIGTRAP. 129 of 3000 fresh 16-thread processes fail on the shipped archive, 368 on the recompiled source, none with the plane created first and none patched. The plane is now a function-local static, as `Message::DefaultMessenger()` is ([#3039](https://github.com/SecondMouseAU/OCCTSwift/issues/3039)) | **[OCCT#1597](https://github.com/Open-Cascade-SAS/OCCT/pull/1597)** (our fix PR, open, base `IR`; GTest `BRepLib_Test.Plane_ConcurrentFirstUse` with a death-test child, failure rates in the PR) | `Shape.edge2d*` can return a wrong vertex or kill the process when the first calls in a process overlap; serial use cannot hit it |
| `0057-GProp_SelGProps-GProp_VelGProps-cylinder-sphere-torus-inertia-3091` | `GProp_SelGProps::Perform` and `GProp_VelGProps::Perform` for `gp_Cylinder`, `gp_Sphere` and `gp_Torus` build the matrix of inertia from expressions that integrate to nothing and assemble it in a way that is wrong for any `Dm` (the full cylinder surface of radius 5 and height 10 reads 314.159 about its axis where `2 pi R^3 H` is 7853.98), take the centre of mass of the solid for a partial turn at `R` where the sector has `2 R / 3` (cylinder) and `3 R / 4` (sphere), and give a torus the wrong area and volume over part of the tube. 96 of 96 probe checks fail before and none after. The torus volume of a part of the tube is the solid swept from the circle through the centres of the tube, a convention OCCT leaves open, written up in the patch ([#3091](https://github.com/SecondMouseAU/OCCTSwift/issues/3091)) | **authored, not yet filed**; upstream checked 2026-10-07, no report, and the two files last changed upstream in March (OCCT#1156) | `GProps` reads these values, so on the pinned kernel its matrix of inertia, partial-range centres and torus mass are wrong |
| `0058-BRepOffsetAPI_MiddlePath-Build-carries-a-vertex-path-forward-3105` | `BRepOffsetAPI_MiddlePath::Build` pads a path that reaches the end section early with its last vertex, handles a section of two points, and then casts a vertex that is already a vertex to an edge, reads past a path, hands a null face to `BRep_Tool::CurveOnSurface` and, for a sweep that never reaches the end section, never ends. 423 of 573 pairs of faces of 16 solids abort the process on the shipped archive (116 of the 196 that share no vertex). The patch carries the vertex forward, reads a vertex end as its parameters on the face, refuses a null edge or face, and stops after as many levels as the solid has edges: none aborts or runs on, 81 of the 116 now answer a validated middle path (14 of them doubtful: loops or overshoot), 35 answer not done, and the 42 pairs that answered before answer the same ([#3105](https://github.com/SecondMouseAU/OCCTSwift/issues/3105)) | **authored, not yet filed**; upstream checked 2026-10-09, no report and no PR, and `IR` carries the same file as `V8_0_1`; an algorithm change, so upstream will want a GTest and an independent check of the result; the only OCCT caller (`BRepTest_SweepCommands.cxx`, `middlepath`) checks nothing but null | `Shape.middlePath(start:end:)` can abort the process for a pair of faces that are not a pipe's two ends and share no vertex, and runs on without end for a sweep that cannot reach the end section; the bridge refuses the shared-vertex pairs (#3098) and nothing else |

**Retired in OCCT 8.0.1** (re-pinned 2026-08-03): `0001`-`0009` and `0013`, shipped upstream as
OCCT#1323, #1334, #1374, #1377, #1380, #1382, #1331, #1329, #1318 and #1392 respectively. Their
`.patch` files are deleted; the writeups, and the per-patch check that each merged form matched
what we carried, are kept in `Scripts/patches/README.md` under "Retired patches". Nine matched;
`0001` did not: upstream's merged form also guards a *removed* face, which ours did not, so that
retirement fixed a latent null dereference of our own.

**Retired 2026-09-02 without shipping: `0032`** (`TopOpeBRepBuild` KPart-merge globals, #1371).
Upstream [OCCT#1505](https://github.com/Open-Cascade-SAS/OCCT/pull/1505) and
[#1509](https://github.com/Open-Cascade-SAS/OCCT/pull/1509) fix the same twelve globals as
per-instance fields, which is stronger than the `thread_local` duplication `0032` used, and also fix
`GLOBAL_faces2d`, which `0032` left alone. The globals are unreachable from this bridge regardless.
See `Scripts/patches/README.md`'s retired `0032` entry, and
[Upstream OCCT patch process](../policies/upstream-occt-patch-process.md) for the "check upstream's
recent activity first" step this prompted.

**Retired 2026-09-20, one day after it landed: `0035`** (`STEPControl_Writer` per-transfer init,
#1403). It reintroduced [#280](https://github.com/SecondMouseAU/OCCTSwift/issues/280): the call it
removed is not only an initialiser but the *repair* that re-sets `DirectFaces` on a shared actor an
XDE STEP read has left with empty `OperationsFlags`, which is #280's exact mechanism. Its writeup
argued the call was inert because both guards are false "in the default path"; that path was the
only one considered. `STEPWriterCAFCorruptionTests` caught it in `kernel-integration.yml`, the one
job that builds an unpinned patch. The general lesson is in `Scripts/patches/README.md`'s retired
`0035` entry: a byte-identical hunk is not a safe backport when the rest of its upstream change is
what made it safe. Tracked as [#2056](https://github.com/SecondMouseAU/OCCTSwift/issues/2056).

**Retired 2026-10-10, at the `v4.0.0-kernel.6` repin: `0031`** (`BSplCLib_Cache`/`BSplSLib_Cache`
locks, [#1153](https://github.com/SecondMouseAU/OCCTSwift/issues/1153)). Not superseded by an
upstream fix: retired because the pattern it made safe, one `GeomAdaptor_*`/`BRepAdaptor_*`
shared between threads, is unsupported by OCCT's design (each worker owns its adaptor or takes a
`ShallowCopy()`, [OCCT#1554](https://github.com/Open-Cascade-SAS/OCCT/pull/1554)), and the lock
cost about 7x on a cached `D0` while hiding a caller defect as a slower correct answer. The guards
landed first (#3121); the maintainer's decision is on
[#3065](https://github.com/SecondMouseAU/OCCTSwift/issues/3065). A consumer sharing one adaptor
across threads, which the shipped kernel from `v4.0.0-kernel.6` no longer protects, reads wrong
points; `EdgeCurve` and `WireCurve` are the only adaptors the bridge keeps alive across calls and
are not `Sendable`. See `Scripts/patches/README.md`'s retired `0031` entry.

## Pinned against carried

**There are two pinned kernels, and they are on different patch sets right now.** The heading below
means the xcframework; the wasm asset has its own section after it. Collapsing them would repeat the
mistake the rest of this page is about.

### The xcframework

`Scripts/patches/` holds forty-five patches, of which the pinned asset carries forty-five. **These
are the counts `CLAUDE.md` used to restate and no longer does** (#2954); both are derived from
`Scripts/patches/` and `Package.swift` by `check-inventory-prose.py`, which fails the PR that lets
this page and the tree disagree. The v4.0.0-kernel.6 asset `Package.swift` pins lacks none of them, so **there is no native
divergence**, per [Pinned kernel patch check](../policies/pinned-kernel-patch-check.md). It was
built from a fresh `V8_0_1` clone with every patch on disk applied, and it is the first asset
built without `0031`.

**The divergence that stood until v4.0.0-kernel.6 is closed.** `0058` and `0059` were merged after
v4.0.0-kernel.5 and were live nowhere until the v4.0.0-kernel.6 rebuild pinned both. The table
below is kept as the record of what each left exposed while it was unpinned, and of which test
gate the repin did and did not retire; it is history now, not a live gap.

| Was unpinned until v4.0.0-kernel.6 | What it left exposed |
|---|---|
| `0059-ChFi3d-Builder-fillets-that-meet-exactly-are-built-not-refused-3207` | Nothing that crashes. Two fillets whose radii sum to the width of the face between them (a 4 mm face, 2 and 2) answered `IsDone() == false` on the kernel pinned before v4.0.0-kernel.6, and `Shape.filleted` answered nil, where the patch builds a valid solid. A radius above half the width is refused with and without it ([OCCT#1177](https://github.com/Open-Cascade-SAS/OCCT/issues/1177), [#3207](https://github.com/SecondMouseAU/OCCTSwift/issues/3207)). `Issue3207FilletMeetingTests` ran in `kernel-integration.yml`, gated on `OCCTSWIFT_LOCAL=1`, and is ungated by the repin |
| `0058-BRepOffsetAPI_MiddlePath-Build-carries-a-vertex-path-forward-3105` | An uncatchable SIGSEGV in the kernel pinned before v4.0.0-kernel.6 for a pair of faces that share no vertex and are not a pipe's two ends, and a loop that never ends for a sweep that cannot reach the end section, which the bridge cannot refuse because no exact precondition on the input exists: the faults come from state that only exists while `Build()` runs its section loop (#3105). #3098's guard refuses the pairs that share a vertex. `OCC_CATCH_SIGNALS` is inert in this build, so no bridge catch reaches the signal. `Issue3105MiddlePathKernelTests` ran it in `kernel-integration.yml`, gated on `OCCTSWIFT_LOCAL=1`, and is ungated by the repin. Taking it also makes 81 more pairs answer a path (see the writeup) |

**The divergence before that is closed too.** `0053` through `0057` were authored after
v4.0.0-kernel.4 and were live nowhere until the v4.0.0-kernel.5 rebuild pinned all five. The table
below is kept as the record of what each of them left exposed while it was unpinned, and of which
bridge mitigation or test gate the repin did and did not retire; it is history now, not a live gap.

| Was unpinned until v4.0.0-kernel.5 | What it left exposed |
|---|---|
| `0053-BRepOffset_MakeOffset-arc-join-roots-in-binding-order-3003` | Nothing a bridge guard could cover, and no crash. Every arc-join offset came back in an allocator-decided face order in the kernel pinned before v4.0.0-kernel.5, so the last digits of its volume move between processes, and three lines of two #766 probes kept a `tolerance` declaration until this was pinned (#3003). Pinning it fixes the order and fixes one outcome per input, which for the fused two-box L shape is the null shape |
| `0054-ChFi3d_Builder-StartSol-drops-an-obstacle-with-no-edge-2881` | An uncatchable SIGSEGV in the kernel pinned before v4.0.0-kernel.5, and nothing a bridge guard can reach: `BRepFilletAPI_MakeFillet::Build` evaluates an empty curve when a blend meets a vertex whose neighbour face holds no edge to follow, and `OCC_CATCH_SIGNALS` is inert in this build. The bridge names `MakeFillet` in 96 places. It needs the reporter's model and a radius of exactly 1.5 on eight of its edges, so it is a knife-edge input and not a common one (#2881). `Issue2881FilletObstacleTests` ran it in `kernel-integration.yml`, gated on `OCCTSWIFT_LOCAL=1` |
| `0055-GProp_SelGProps-GProp_VelGProps-cone-matrix-of-inertia-3010` | No crash, and nothing in the older bridge reads the cone's centre of mass or matrix of inertia: `GeometryProperties.coneSurfaceArea` and `.coneVolume` read `Mass()` alone, which `0050` and `0051` fixed. `GProps.cone`, added with `0057` (#3091), does read them, so against the kernel pinned before v4.0.0-kernel.5 its matrix of inertia and its solid centre of mass are wrong (#3010); `Issue3091GPropsTests` ran the comparison in `kernel-integration.yml`, gated on `OCCTSWIFT_LOCAL=1` |
| `0056-BRepLib-Plane-creates-the-default-plane-under-the-magic-static-lock-3039` | An uncatchable SIGSEGV, SIGBUS or SIGTRAP, or a wrong vertex, in the kernel pinned before v4.0.0-kernel.5 when two threads make the first 2D edge in a process at the same moment: every `Shape.edge2d*` wrapper reaches `BRepLib::Plane()` through `BRepLib_MakeEdge2d`. It needs the first two calls in the process to overlap, so serial use and a process that has already made one 2D edge cannot hit it; `OCC_CATCH_SIGNALS` is inert in this build, so no bridge catch reaches the signal. A bridge call to `BRepLib::Plane()` behind a function-local static would close it for the Swift API without a kernel change and was not taken (#3039). `Issue3039BRepLibPlaneFirstUseTests` ran it in `kernel-integration.yml`, gated on `OCCTSWIFT_LOCAL=1` |
| `0057-GProp_SelGProps-GProp_VelGProps-cylinder-sphere-torus-inertia-3091` | `GProps.matrixOfInertia`, `GProps.principalProperties`, `momentOfInertia` and the solid's `centreOfMass` over a partial turn, and a torus's mass over part of the tube, are wrong in the kernel pinned before v4.0.0-kernel.5 for the cylinder, sphere and torus; the cone's were wrong until `0055` was pinned too. No crash. Nothing else reads them: the bridge's older `OCCTGPropCylinderSurface` family reads `Mass()` and a full-sphere centre, which were right (#3091). `Issue3091GPropsTests` ran the comparison in `kernel-integration.yml`, gated on `OCCTSWIFT_LOCAL=1` |

**The divergence before that one is closed too.** It stood at one patch (`0044`) and widened to
eight as `0045` through `0052` were authored, every one of them live nowhere, and the
v4.0.0-kernel.4 rebuild pinned the lot. The table below is kept as the record of what each of
those eight left exposed while it was unpinned, and of which bridge mitigation the repin did and
did not retire.

| Was unpinned until v4.0.0-kernel.4 | What it left exposed |
|---|---|
| `0044-Extrema-ExtSS-ExtCS-Points-bound-against-point-sequence-2840` | Nothing reachable from Swift. `Extrema_ExtSS::Points` and `Extrema_ExtCS::Points` faulted on a parallel pair in the kernel pinned before v4.0.0-kernel.4, and every bridge entry point that reads a point from either class gates on `IsParallel()` first, so the input never reached them (#2831, #2840). The exposure was to a future bridge author who adds a point read without that gate, which is why `OCCTCurve3DDistanceToSurface` carries a comment saying so |
| `0045-Geom-Bezier-InsertPoleAfter-pole-bound-2875` | Almost nothing, and not for the reason it looks. The 3d class's bound is a literal throw and was one pole too strict in the kernel pinned before v4.0.0-kernel.4, so `Curve3D.bezierInsertPoleAfter` refused a 26-pole curve the 3d constructor would build; `0045` corrected it, and the bridge's 2d bound moved to match (#3013). The 2d class's bound is a `_Raise_if` that `No_Exception` empties, so no pinned kernel enforces anything there and `OCCTCurve2DBezierInsertPoleAfter`'s guard is the bound, patched or not (#2801, #2875) |
| `0046-math_Uzawa-Errinit-row-dimension-2860` | The out-of-bounds write itself. `math_Uzawa` overran `Errinit` for any overdetermined system in the kernel pinned before v4.0.0-kernel.4, deterministically SIGSEGVing at 100 constraints in 2 unknowns, and `OCCTMathUzawa`'s `nConstraints > nVars` guard was the only thing between a Swift caller and it (#2860). The guard stays after the repin, deliberately: it is an API decision as well as a crash guard, and relaxing it is a SemVer change (`Scripts/patches/README.md`'s `0046` entry) |
| `0047-BRepMesh_IncrementalMesh-initParameters-refuses-NaN-2879-2900` | Nothing reachable from Swift. All five of `initParameters`' bounds tests are spelled `value < bound`, which NaN defeats, so before `0047` a NaN linear deflection started a tessellation that did not return and a NaN angle returned the coarsest mesh the linear rule alone accepts with `IsDone()` true (#2879, #2900). `occtValidMeshDeflection` and `occtValidMeshAngle` refuse both at every bridge site that takes a caller value, so the kernel never sees one from here. The exposure is to a future bridge author who constructs a `BRepMesh_IncrementalMesh` without either guard, which is why `check-null-handle-guards.py`'s siblings and the two helpers' doc comments say so. **Keep both guards at the repin**, the same `0042` and `0044` exception |
| `0048-BRepGProp-by-plane-offset-sign-2873` | Nothing now, and this row was the opposite case to the two above: the bridge did not refuse an input here, it **compensated**. `OCCTBRepGPropVinertPlane` built the `gp_Pln` mirrored through the origin so the unpatched kernel answered about the plane the Swift caller asked for. **A kernel carrying `0048` with that mirror still in place was wrong again**, and `BRepGPropVinertTests`' two sign assertions failed, which is what they did on #3014. The `v4.0.0-kernel.4` repin deleted the mirror in the same change (#3015) and dropped the "pass `-d`" note from the Swift doc comment and `docs/reference/Shape-HLR-Geom.md`, so `Face.volumeInertia(planeNormal:planeDistance:)` takes an ordinary geometric offset |
| `0050-GProp_SelGProps-cone-lateral-area-drops-cos-semiangle-2992` | `GeometryProperties.coneSurfaceArea(semiAngle:refRadius:height:)` returned `cos(semiAngle)` times the lateral area on the kernel pinned before v4.0.0-kernel.4, a wrong value a caller reads rather than a latent fault. Nothing on the bridge side could recover it: the factor is applied inside `GProp_SelGProps::Perform` and the bridge sees only `Mass()`. Multiplying it back out in the bridge was rejected as a mitigation, because it would have had to be retired at the repin and would silently double-correct a kernel that already carries the patch |
| `0051-GProp_VelGProps-cone-volume-is-the-frustum-2992` | `GeometryProperties.coneVolume(semiAngle:refRadius:height:)` returned a quantity that was not the volume on the kernel pinned before v4.0.0-kernel.4, and collapsed to zero as the semi-angle did. Same reasoning as `0050`: a value a caller reads, with no bridge-side recovery |
| `0052-Geom_BezierSurface-rational-axis-prose-matches-example-2991` | Nothing. It is a header comment, so it changes no binary and the pinned asset's behaviour is already what the corrected prose describes. It is carried so the tree we build and the tree we file upstream from agree, and because the wrong prose nearly cost a lift batch a false defect report |

`0043` (#2827) was the last entry here, and it was the shortest-lived: carried unbuilt on 2026-09-29
because OCCT 8.0.2 was days out and a repin was on hold until it lands, then built and pinned the
same day by `v4.0.0-kernel.3`, because what it left exposed was not a latent race but a value a
caller reads: `Face.volumeInertia(planeNormal:planeDistance:)` returned a fabricated `0.0` for every
face and every plane, and nothing on the bridge side could recover it, since the value does not exist
by the time the bridge can read it. It is live in the binary rather than merely applied to source,
measured the way this page asks: building against the new asset makes #2827's own regression fail at
the same lines and values as CI's independent `kernel-integration` build, and the per-face sum now
equals the solid's volume to the last few digits for three different reference planes. What the
by-plane mass turned out to MEAN, which no OCCT caller states because there is no OCCT caller, is in
`Scripts/patches/README.md`'s `0043` entry and in `Scripts/repro/2827/probe.mm`'s transcript.

`0042` (#2773) was the entry before it. It was carried on 2026-09-27, built and verified in the
binary the same day (all three slices, `check-pinned-asset-patches.py --asset` confirms its literal
in each), and pinned hours later by v4.0.0-kernel.2, so it spent no release window untested. The
bridge guard from [PR #2776](https://github.com/SecondMouseAU/OCCTSwift/pull/2776) is kept rather
than retired with the repin: with `0042` the kernel raises for the same input the guard refuses, so
both answer nil and the guard is redundant rather than wrong, and it still covers anyone pinning an
older asset. `Package.swift`'s pin block records that exception against
[Pinned kernel patch check](../policies/pinned-kernel-patch-check.md)'s retire-the-mitigation rule.

### The wasm kernel: in step with the native one since v4.0.0-kernel.4

`libOCCT-wasm.a` and its header tree are a **second** pinned asset, recorded in
`Scripts/wasm-kernel-pin.txt` rather than in `Package.swift`, because SwiftPM has no `binaryTarget`
for a bare static library. Both kernels carry the same patches, `0010` to `0059`. As of this
writing the pinned native asset carries forty-five, and so does this one, plus the eleven in
`Scripts/patches-wasi/` that only the wasm build applies. They were built from one tree in one
sitting and published to one release tag, so **there is no divergence between the two platforms to
record**.

`Scripts/check-wasm-kernel-parity.py` reports both sides at the same count, and
`wasm-kernel-pin.txt` carries no `ACKNOWLEDGED_*` keys. They were deleted rather than re-keyed,
because that field's own rule is that the "against" number is never bumped: an acknowledgement that
no longer acknowledges anything is removed, and its text is kept below as history.

#### History: how the wasm kernel stood at v4.0.0-kernel.2, as of 2026-09-29

Everything from here to the end of this section describes an asset that has been superseded. It is
kept because the failure it records, a divergence nothing counted, is the argument for the parity
gate. None of it describes what is pinned now.


That asset carried **thirty** patches, `0010` to `0042`, plus the eleven in `Scripts/patches-wasi/`,
while the native asset carried thirty-one, so it **lacked one of them**:

| Was unpinned on wasm until v4.0.0-kernel.4 | What it leaves exposed |
|---|---|
| `0043-BRepGProp_Gauss-keeps-the-by-plane-mass-2827` | In the browser only, `Face.volumeInertia(planeNormal:planeDistance:)` still returned the fabricated `0.0` that `v4.0.0-kernel.3` fixed natively. No other API reached the by-plane `BRepGProp_Vinert` path, and the by-point `Face.volumeInertia` is unaffected on both platforms |

`0044` was **not** a second row here. It was unpinned on both platforms, so it was not a divergence
between them, and `Scripts/check-wasm-kernel-parity.py` compares the wasm pin against
`Package.swift`'s enumeration of what the native **asset** holds rather than against the directory
listing. The v4.0.0-kernel.4 rebuild picked `0044` up on both platforms at once, which closed the row above.

**Acknowledged, not ignored**, by `OCCT_WASM_PARITY_ACKNOWLEDGED_AGAINST=31` in
`Scripts/wasm-kernel-pin.txt`: the wasm kernel is a 69-minute build and that repin did not take it,
so the divergence was written down with the native count it was accepted at. That keying is the whole
point, per [Pinned kernel patch check](../policies/pinned-kernel-patch-check.md): the NEXT native
repin makes the acknowledgement stale and `Scripts/check-wasm-kernel-parity.py` fires again, so it
could not become a permanent suppression the way two `ACKNOWLEDGED` rows in
`Scripts/patches/README.md` did before #2190. What closed it was the rebuild of both kernels from one patch set. That was expected to
be OCCT 8.0.2, due 2026-10-02; 8.0.2 did not ship, so it was done anyway for v4.0.0-kernel.4 (#3031).

`0042` was the entry here for one day. PR #2784 published the asset for `v4.0.0-kernel.1` and PR
#2782 repinned native to `v4.0.0-kernel.2` **twenty-nine seconds later**, so the browser briefly
lacked a null-surface guard #2773 measured as a SIGSEGV on seven cases.
`Scripts/check-wasm-kernel-parity.py` caught it on `main` within a minute, PR #2786 acknowledged it
to unblock, and the rebuild closed it.

**Verified the way this page asks for, in both directions.** The build tree is `V8_0_1` with all
thirty carried and all eleven WASI patches reverse-applying cleanly, and its **89 modified files
correspond exactly 1:1** with the 89 that those forty-one patches touch, so there is nothing extra
either. That reverse check is the one the xcframework did not have, and is how the two strays below
stayed invisible for a month. `0042`'s own literal,
`ShapeAnalysis::GetFaceUVBounds: face has no surface`, is present once in the published archive and
absent from the superseded `kernel.1` one, which is the control.

**And it holds two that we do not carry, so thirty-two in total.** Those are separate quantities
and collapsing them is how the divergence stayed invisible for a month: every count in this repo
asked "does the asset lack anything", and none asked "does it hold anything extra".

The two extras are retired patches that were deleted from `Scripts/patches/` but never reverted out
of the shared `Libraries/occt-src` tree the asset was built from on 2026-09-22:

| Extra in the asset | Retired | Why it is in the asset | Exposure |
|---|---|---|---|
| retired `0032`, TopOpeBRepBuild KPart-merge globals, #1371 | 2026-09-02, superseded by OCCT#1505/#1509 | `build-occt.sh` applies patches idempotently and **never reverts**, so a retired patch's edits survive in a working tree until somebody deletes them by hand. Nobody did. | None. `thread_local` and `static` are identical single-threaded, and the twelve globals are unreachable from this bridge's call surface, measured by #1371's own reachability probe. |
| retired `0034-LocOpe_SplitDrafts-trim-infinite-pipe-curves-1393`, #1393 | 2026-09-08, upstream deleted the class in OCCT#1442 | The same tree, the same cause. | None. `LocOpe_SplitDrafts` has no caller anywhere: `Shape.splitDrafts` was removed in v4.0.0. |

(The rows above are deliberately not keyed by a bare backticked filename: `check-inventory-prose.py`
reads that shape as a carried-patch row and requires the file to exist in `Scripts/patches/`, which
is exactly what these two do not.)

Verified by symbol rather than inferred: `nm -C` finds `TrimInfinite(...)` in
`LocOpe_SplitDrafts.cxx.o` and `thread-local wrapper routine for GLOBAL_*` in the three
`TopOpeBRepBuild` objects, in all three slices, and the local `OCCT.xcframework.zip` hashes to
exactly the `checksum:` `Package.swift` pins. Tracked as
[#2190](https://github.com/SecondMouseAU/OCCTSwift/issues/2190), documented rather than rebuilt out
because both are inert and a rebuild costs three cmake configures for no behavioural change.

**Both strays belonged to v4.0.0-kernel.1, and the pin has moved off it.** v4.0.0-kernel.2 was
built from a fresh `V8_0_1` clone rather than that tree, so neither stray is present: the
modified-file check computes zero files that no carried patch explains, over 78, and
v4.0.0-kernel.3 repeats it over 79 with `0043` added. The two
`ACKNOWLEDGED` rows in `check-pinned-asset-patches.py` stay keyed on `v4.0.0-kernel.1` and expire
here on their own, which is what they were built to do, and if a later asset repeats either stray
the finding comes back instead of staying suppressed. A rebuild today should now reproduce the
pinned checksum, so a mismatch is a real difference to chase rather than an expected one.

**The check that would have caught it** is `python3 Scripts/check-pinned-asset-patches.py
--require-asset`, written for #2190 and run at the repin step. It derives evidence from each
patch's own diff and looks for it in all three slices, and it looks for the retired patches too,
which is the direction nothing tested. The two rows above sit in its `ACKNOWLEDGED` table keyed on
the tag `v4.0.0-kernel.1`, so the acknowledgement expires at the next repin rather than silently
excusing the next asset.

That is new as of 2026-09-22 and it is what the rebuild was for. Twelve patches (`0028`-`0031`,
`0033`, `0034`, `0036`-`0041`) had been on disk and in no CI job, because `build-and-test` resolves
the pinned asset rather than building from source. Four of the twelve were live consumer exposure
rather than bookkeeping, and all four now ship:

| Patch | What shipping it closed |
|---|---|
| `0029` (#1022) | An uncatchable SIGSEGV on `Document.datums` for any OCAF document whose datum has a point and no annotation plane. **The bridge guard added for #1030 is retired**, in all six files that carried it, since it was refusing a shape the kernel can read. |
| `0030` (#1154) | A live data race on `TopoDS_TShape::myState` under ordinary concurrent use of a boolean result, invisible to `swift test`. Its `Scripts/tsan.supp` suppressions were removed at this repin, and `check-inventory-prose.py` is what caught them (#1409). |
| `0031` (#1153) | The same shape in `BSplCLib_Cache`/`GeomAdaptor_*` for any consumer sharing an adaptor across threads. No suppression existed, so nothing to retire. **The patch itself was retired at v4.0.0-kernel.6 (#3065).** |
| `0034` (#1515) | `Shape.coonsAlgPatch` returning a surface collapsed onto its `u == v` diagonal for every off-diagonal sample, silently. The Swift test that asserts the correct surface was impossible before the repin, because `build-and-test` resolved the unpatched asset; it exists now, in `Tests/OCCTSurfaceTests/GeomFill/Issue1515CoonsPatchUParameterTests.swift`. |

The other eight (`0028`, `0033`, `0036`-`0041`) were either unreachable from the bridge (`0028`'s
only reader was deleted by #999) or masked by the bridge's own `igesMutex()`, which serialises the
whole data-exchange surface. Shipping them buys defence in depth for any caller outside that mutex,
and is what makes narrowing the mutex thinkable later. `0036`-`0041` are the #1403 series: named
racing globals **16 to 0**, TSan reports **178 to 37**.

**The three bridge-side mitigations `CLAUDE.md` listed as "retire when the kernel is repinned" are
retired**, each with a regression test that fails if it comes back:

- the `Scripts/tsan.supp` suppressions for `TopoDS_TShape::myState` (`0030`), removed in the repin
  itself because `check-inventory-prose.py` fails the moment a cited patch becomes pinned (#1409);
- the datum lookup guard in `occtDocumentDatumObjectAt` (#1030), which was refusing a datum `0029`
  makes readable. It was duplicated across six bridge files, and retiring it also removed the
  `ReadableCheck` template parameter, since every remaining predicate was already always-true;
- the bridge-side arc-length subdivision in `occtArcConvergedLength` (#603), redundant against
  `0021`. Retired on measurement: the loop was instrumented to report any convergence past `n=2`
  or any exhaustion and the full suite run, **6,384 tests and zero reports**.

`Tests/OCCTXCAFTests/GDT/Issue1030DatumLookupGuardTests.swift` kept its name and fixtures and flipped
its assertions, which is the only way a guard's retirement can be regression tested: a test that
merely stops existing proves nothing.

`kernel-integration.yml` builds these, and nothing else does: it is the only job that compiles an
unpinned patch, and `build-and-test` resolves the pinned asset instead. It runs on the PR that adds
a patch and on `main` afterwards, which is how `0035` was caught one day after it merged.

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