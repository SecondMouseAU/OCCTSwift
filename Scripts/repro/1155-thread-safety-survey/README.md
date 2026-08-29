# OCCTSwift#1155 survey: "algorithms with internal mutable state"

Issue #1155 named eight candidate OCCT classes with no reproducer proving any of them actually
races: `BRepBuilderAPI_Transform`, `BRepClass3d_SolidClassifier`, `GeomAPI_ProjectPointOnSurf`,
`BRepBuilderAPI_MakeEdge`/`MakeWire`/`MakeFace`, `BRepOffsetAPI_MakePipeShell`/`MakeThickSolid`,
`BRepFilletAPI_MakeFillet`/`MakeChamfer`, `ShapeFix_Face`/`Wire`/`Shape`, `BRepCheck_Analyzer`.
Per the #707 campaign's own methodology (characterize by reading source for file-scope/static
mutable state written during what should be an independent per-call operation, then build a real
TSan reproducer before concluding anything), each candidate's full call chain was read, not just
the class's own `.cxx`.

## Verdict

**All eight confirmed clean, none race.** Every candidate either has no file-scope/static mutable
state at all in its reachable call chain, or the state that exists is dead code (guarded by a
debug macro this project's Release build never defines), already `thread_local`/mutex-protected
(the #298 fix, or an unrelated upstream fix), or a function-local static that is read-only after
one-time construction. See "Per-class characterization" below for each.

**One near-miss is worth recording carefully**: `BRepFilletAPI_MakeFillet`/`MakeChamfer`'s
underlying legacy `TopOpeBRepBuild_Builder` engine (reached via `ChFi3d_Builder` →
`TopOpeBRepBuild_HBuilder`) has a cluster of live, unguarded, non-`thread_local` file-scope
globals in `TopOpeBRepBuild_ffsfs.cxx`/`TopOpeBRepBuild_GridSS.cxx`
(`GLOBAL_SplitAnc`, `GLOBAL_lfr1`, `GLOBAL_lfrtoprocess`, `GLOBAL_classifysplitedge`,
`GLOBAL_revownsplfacori`, `static_CONF1`/`static_CONF2`, `stabuild_IMELF1`/`IMELF2`/`IDMEALF1`/
`IDMEALF2`/`IMEF`) that the #298 fix did not touch (#298 was scoped to `STATIC_SOLIDINDEX` and
the `BlendFunc`/`checkcurve` statics, a different file). This is exactly the #298 shape
(file-scope statics passing state between two functions within one logical operation, zero
synchronization) and was the most promising lead this survey found. **Confirmed, by two
independent methods, to be unreachable from `BRepFilletAPI_MakeFillet`/`MakeChamfer`**, so it
does not race in practice:

1. **Reachability probe** (`fprintf` inserted into `FindIsKPart()`, `KPreturn()`,
   `GMergeSolids()` and `GFillFaceSFS()`, override-linked ahead of the production archive):
   zero hits across five geometries chosen specifically to be the most SameDomain-merge-prone
   available (a box with all 12 edges filleted -- the corner case where three fillets converge;
   a box fused with a sphere then filleted, matching the existing #341/#298 gate's own geometry;
   two boxes sharing an entire coincident face, fused, then filleted; a chamfered box; a
   filleted cylinder).
2. **Static call-graph proof**: `TopOpeBRepBuild_HBuilder::Perform(HDS)` (the only `Perform`
   overload `ChFi3d_Builder.cxx` ever calls, `myCoup->Perform(myDS)`) forwards to
   `TopOpeBRepBuild_Builder1::Perform(HDS)` (single-argument), which forwards unconditionally to
   the base class's single-argument `Perform(HDS)`. `FindIsKPart()` is called only from the
   **two-argument** `Perform(HDS, S1, S2)` overload, which `HBuilder` exposes but `ChFi3d_Builder`
   never calls (`myCoup->MergeSolid(curshape, TopAbs_IN)`, the single-shape overload, is what it
   calls instead, with the second shape implicitly null). `myIsKPart` therefore stays at its
   default-constructed `0` ("not a KPart case") for the whole fillet/chamfer reconstruction, so
   `MergeShapes` always takes the `SplitShapes`/`FillShape` branch, never `MergeKPart` -- and
   `GMergeSolids`/`GFillSolidsSFS`/`GFillSolidSFS`/`GFillShellSFS`/`GFillFaceSFS` (the whole
   GridSS/ffsfs family, and its globals) are called from nowhere else in the tree.

Filing a follow-up issue for this anyway (see below), because "unreachable today" is a fact about
the current call graph, not a property of the classes, and it is exactly the kind of thing a
future OCCT refactor (or a future OCCTSwift bridge change that starts calling `HBuilder`'s
two-argument `Perform` or a future two-solid ChFi3d mode) could silently turn live.

## Per-class characterization

Read (not assumed) via `grep -rnE '^\s*static\s+...'` over each class's own `.cxx` and every
`.cxx` in its direct call chain, then manually inspected every hit for (a) whether it is a
variable declaration rather than a free-function declaration, (b) whether it is gated by
`#ifdef OCCT_DEBUG` / `#ifdef DEBUG_Modifier` (this project's `Scripts/build-occt.sh` always
configures `-DCMAKE_BUILD_TYPE=Release`, confirmed directly from the actual `clang -cc1` compile
command captured during this survey's own TSan kernel build: `-D NDEBUG`, no `-D OCCT_DEBUG`
anywhere), and (c) whether it is mutated after construction.

1. **`BRepBuilderAPI_Transform`**: all instance state (`myTrsf`/`myLocation`/`myUseModif`/
   `myModification`/`myModifier`, the last two on the `BRepBuilderAPI_ModifyShape` base). Its
   `Perform()` calls into `BRepTools_Modifier`/`BRepTools_TrsfModification`, neither of which has
   any live static: `BRepTools_Modifier.cxx`'s one file-scope static
   (`static NCollection_IndexedMap<...> MapE, MapF;`) is entirely inside `#ifdef DEBUG_Modifier`,
   a macro this tree never defines (grepped the whole `occt-src` tree: zero definitions).
   `BRepTools_TrsfModification.cxx` has no static declarations at all.
2. **`BRepClass3d_SolidClassifier`**: all instance state (`aSolidLoaded`/`explorer`/
   `isaholeinspace`), and its `BRepClass3d_SolidExplorer` member is also all-instance (`myShape`/
   `myMapOfInter`/`myTree`/`myMapEV`, each per-instance, never shared even when two classifiers'
   input shapes share a `TopoDS_TShape`). The file's one static
   (`static StatistiquesBRepClass3d STAT;`) is entirely inside `#if LBRCOMPT` where
   `#define LBRCOMPT 0` sits four lines above unconditionally -- dead in every configuration, not
   just Release.
3. **`GeomAPI_ProjectPointOnSurf`**: instance state only (`myExtPS`, `myGeomAdaptor`). Its
   `GeomAdaptor_Surface` member is a private, per-instance copy (not shared across
   `GeomAPI_ProjectPointOnSurf` instances even when they project onto the same `Geom_Surface`
   handle), so #1153's fix (a `mutable std::mutex` on `GeomAdaptor_Surface`'s own
   check-then-act cache rebuild) is defense-in-depth here rather than load-bearing: two
   independent `GeomAPI_ProjectPointOnSurf` instances never share the mutex's object in the first
   place. `Extrema_ExtPS.cxx` and `Extrema_GenExtPS.cxx` (the actual search algorithm) have zero
   static declarations.
4. **`BRepBuilderAPI_MakeEdge`/`MakeWire`/`MakeFace`**: thin wrappers around `BRepLib_MakeEdge`/
   `MakeWire`/`MakeFace` (all instance state); the underlying `.cxx` files have zero static
   *variables* (`BRepLib_MakeEdge.cxx`'s two `static bool Project(...)` are free functions with no
   state; `MakeWire.cxx`/`MakeFace.cxx` have no statics of any kind).
5. **`BRepOffsetAPI_MakePipeShell`/`MakeThickSolid`**: both instance-state wrappers;
   `BRepFill_PipeShell.cxx` and `BRepFill_Sweep.cxx` (the sweep engine) have zero static
   variables. `BRepOffset_MakeOffset.cxx` (the class `MakeThickSolid` builds on) has one static
   object with real mutable state, `static OSD_Chronometer Clock;`, plus several `bool`/`int`
   globals (`AffichInt2d`, `ChronBuild`, `NbAE`, ...) -- all of them, including `Clock`, are
   declared and used exclusively inside `#ifdef OCCT_DEBUG`.
6. **`BRepFilletAPI_MakeFillet`/`MakeChamfer`**: the entire `ChFi3d_Builder*.cxx` family (7
   files) was grepped for state-holding statics; the *only* one found is
   `static thread_local occ::handle<GeomAdaptor_Curve> checkcurve;` in
   `ChFi3d_Builder_6.cxx`, already `thread_local` per the #298 fix documented in
   `CLAUDE.md`. The `TopOpeBRepBuild_Builder`/`Builder1` engine ChFi3d drives through
   `TopOpeBRepBuild_HBuilder` has the near-miss cluster documented above (confirmed
   unreachable).
7. **`ShapeFix_Face`/`Wire`/`Shape`**: `ShapeFix_Root` (the shared base) holds only instance
   state (`myContext`/`myMsgReg`/`myPrecision`/`myMinTol`/`myMaxTol`). None of the three `.cxx`
   files (nor `ShapeFix_Root.cxx`) has any static variable, only static free-function helpers.
   `ShapeProcess_Context.cxx` (a related but not directly reachable class, since nothing in this
   bridge drives shape-fixing through `ShapeProcess::Perform`) does have file-scope statics
   (`sRC`/`sMtime`/`sUMtime`/`sName` caching a loaded `Resource_Manager`), but they are already
   guarded by a `std::mutex` (`GetShapeProcessMutex()`) with an explicit comment
   ("Mutex is needed because we are initializing and changing static variables here") --
   confirmed to be stock upstream OCCT (no entry in `Scripts/patches/` touches this file), the
   same defensive pattern CLAUDE.md's `#344` entry references when it describes this file's
   `new Resource_Manager(*sRC)` workaround.
8. **`BRepCheck_Analyzer`**: instance state only (`myShape`/`myMap`/`myIsParallel`/`myIsExact`).
   Every file in `src/ModelingAlgorithms/TKTopAlgo/BRepCheck/` (`Analyzer`, `Edge`, `Face`,
   `Result`, `Shell`, `Solid`, `Vertex`, `Wire`, the namespace helper `BRepCheck.cxx`) has zero
   static variables. `BRepCheck_Result` additionally carries its own instance-level
   `mutable std::mutex myMutex`, matching `docs/thread-safety.md`'s existing "RC5 Thread Safety
   Improvements" note that `BRepCheck_*` result classes already have mutex protection.

## Repro

`occt_1155_stress.cpp`: eight independent scenarios (one per candidate, `transform_independent`,
`classify_independent`, `project_point_independent`, `make_edge_wire_face_independent`,
`pipe_shell_thick_solid_independent`, `fillet_chamfer_all_edges_independent`,
`shapefix_independent`, `check_analyzer_independent`), each N threads building and operating on
fully independent shapes/geometry per iteration -- no shared `TopoDS_TShape`, no shared handle,
matching `docs/thread-safety.md`'s "documented-safe" pattern the tsan-stress.sh matrix header
already distinguishes from the deliberately-adversarial ones. `fillet_chamfer_all_edges` in
particular fillets/chamfers *every* edge of an independent box per iteration, deliberately the
geometry most likely to exercise ChFi3d's corner-merge logic (see the near-miss above).

```
Usage: occt_1155_stress <scenario|all> <threads> <iterations>
```

Single-threaded sanity (production, non-instrumented `OCCT.xcframework`, before spending TSan
time): 4 threads x 3 iterations and 16 threads x 15 iterations of every scenario, `errors=0`
throughout, no crash.

## TSan confirmation

Built against this project's existing minimal-module TSan install
(`FoundationClasses`+`ModelingData`+`ModelingAlgorithms`+`DataExchange`, `RelWithDebInfo`,
`-fsanitize=thread -g`), rebuilt fresh for this survey (stamp `V8_0_1 2fe67dbe59af901e`, matching
`ls Scripts/patches/*.patch | wc -l` == 21 measured against `origin/main` at the time of the
run), so all 21 carried patches are applied, including `0030`/`0031` (#1154/#1153, already-fixed
classes of the same shape this survey is checking for siblings of).

8 threads x 30 iterations per scenario:

| Scenario | Races | Notes |
|---|---|---|
| `transform_independent` | 0 | |
| `classify_independent` | 0 | |
| `project_point_independent` | 0 | |
| `make_edge_wire_face_independent` | 0 | |
| `pipe_shell_thick_solid_independent` | 1 (suppressed) | `BOPAlgo_InitMessages`, see below |
| `fillet_chamfer_all_edges_independent` | 0 | the near-miss scenario; see "Verdict" above |
| `shapefix_independent` | 0 | |
| `check_analyzer_independent` | 0 | |

**The one race is not a new #1155 finding.** `pipe_shell_thick_solid_independent`'s
`BRepOffsetAPI_MakeThickSolid::MakeThickSolidByJoin` call reaches
`BRepOffset_MakeOffset::Intersection3D` -> `BRepOffset_Tool::Inter3D` -> a fresh
`BOPAlgo_PaveFiller`, whose base `BOPAlgo_Options` constructor races on the anonymous-namespace
global `BOPAlgo_InitMessages` (a lazy-init message-table flag). This is **already** the
confirmed-benign race `Scripts/tsan.supp` has carried since the #298/#341 investigation
(`race:BOPAlgo_InitMessages`, "Lazy one-time init of the BOPAlgo message table. Racy per TSan,
harmless in effect"), previously observed via fillet/boolean/mesh scenarios; this survey is simply
the first to reach it through `MakeThickSolid`'s own internal use of the modern BOPAlgo engine.
Re-running all eight scenarios with `TSAN_OPTIONS="...:suppressions=Scripts/tsan.supp"`: **0
unsuppressed races across all eight**, confirming this is exactly the already-known, already-
suppressed defect and nothing new.

Full transcripts (unsuppressed and suppressed runs) are in `tsan_*.log`/`tsan_supp_*.log` in this
directory. `tsan-stress-sh-run-full-gate.log` is the real integration run through
`Scripts/tsan-stress.sh run` (not this survey's own scratch scripts) after registering all eight
scenarios in the `SCENARIOS` matrix: **19/19 scenarios clean** (the ten pre-existing scenarios,
still green, plus these eight), the standard suppression file (`Scripts/tsan.supp`) applied as it
always is by the real gate.

## New follow-up

Filed as [#1371](https://github.com/SecondMouseAU/OCCTSwift/issues/1371): the
`TopOpeBRepBuild_ffsfs.cxx`/`TopOpeBRepBuild_GridSS.cxx`
`GLOBAL_*` cluster is a real, live, unguarded file-scope-static defect by the same measure #298
used, just currently unreachable from this bridge's own call surface. Worth a kernel patch
(`thread_local`, matching #298's own fix for the sibling statics in the same toolkit) the next
time anything in this tree (or upstream) starts driving `TopOpeBRepBuild_HBuilder`'s two-argument
`Perform`/two-solid path, so the fix lands before the reachability, not after.

**Fixed**: `Scripts/patches/0032-TopOpeBRepBuild-KPart-merge-globals-thread-local-1371.patch`
converts all twelve statics (the cluster above turned out to be twelve, not eleven; this survey's
own count missed `stabuild_IMEF`) to `thread_local`, plus a thirteenth file
(`TopOpeBRepBuild_GridFF.cxx`, which holds `GLOBAL_classifysplitedge`'s one true definition and
wasn't named in the original cluster list above). Compiles and links cleanly across all three
xcframework slices, with `nm -C` confirming a genuine TLV wrapper routine generated for each of the
five extern-linked globals. A live functional/TSan re-run against the patched kernel was attempted
and abandoned: the local `occt-build-macos` incremental build tree had drifted into this repo's own
documented "stale SDK sysroot, can no longer incrementally compile" failure, producing a binary
that crashes on an unrelated, unmodified test identically whether this patch is applied or
reverted (A/B'd both ways), and not at all against the pinned release kernel. So this patch's
functional correctness rests on the reachability/TSan evidence already gathered above for the
*unpatched* code (0 races because the code is unreached), not a fresh green run against the
*patched* binary; that needs a full `Scripts/build-occt.sh` reconfigure, not attempted here. See
`Scripts/patches/README.md`'s `0032` entry for the full writeup, and CLAUDE.md's Known OCCT Bugs.
`GLOBAL_faces2d` (`TopOpeBRepBuild_GridFF.cxx`, two lines from `GLOBAL_classifysplitedge`, same
unsynchronized shape but reachable from three more files this pass did not check) is noted, not
fixed, and not yet its own issue.
