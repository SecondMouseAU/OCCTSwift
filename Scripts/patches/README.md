# Carried OCCT source patches

Patches in this directory are upstream-bound OCCT bug fixes we carry until they ship in an OCCT
release. `Scripts/build-occt.sh` applies each one (idempotently, `-p1`, `a/`,`b/` prefixes) to
`Libraries/occt-src` before every cmake build. A patch takes effect only when the xcframework is
**rebuilt** from source — the binary shipped in `Libraries/OCCT.xcframework` does not yet include it
until a rebuild + release.

## 0001-ShapeFix_Face-guard-non-face-context-replacement-263.patch

**Fixes the upstream OCCT crash behind [#263](https://github.com/SecondMouseAU/OCCTSwift/issues/263)**
(reported upstream as [Open-Cascade-SAS/OCCT#1322](https://github.com/Open-Cascade-SAS/OCCT/issues/1322); fix
offered as [Open-Cascade-SAS/OCCT#1323](https://github.com/Open-Cascade-SAS/OCCT/pull/1323), CI green, ready for review).

`ShapeFix_Face::Perform` casts `Context()->Apply(myFace)` with `TopoDS::Face(S.EmptyCopied())` in
three places, none of which check the type. When an earlier fix sharing the same `ShapeBuild_ReShape`
context has replaced the face with a **compound** (e.g. a self-intersecting face split into several
faces), `Apply()` returns a non-face. The unchecked cast then builds an invalid `TopoDS_Face` handle
over a compound `TShape`; subsequent topology operations corrupt the heap and abort the process with
an uncatchable OS signal (`ShapeFix_Face::FixOrientation` → `BRep_Tool::Curve` → `BRep_TEdge::EmptyCopy`,
SIGSEGV/SIGBUS at varying addresses).

The compound replacement already exists on entry to `Perform` (it was recorded by a prior face's
fix), so the patch adds a single guard at the top of `Perform`: if `Context()->Apply(myFace)` is not
a face, record it as the result and return, since the replacement is already in the context and there is
nothing to fix here. This one guard covers all three cast sites.

**Validation** (fast path, no full rebuild): compile the single patched TU and link it *before*
`libOCCT-macos.a` so it overrides that symbol:

```bash
clang++ -std=c++17 -O2 -w -I Libraries/OCCT.xcframework/macos-arm64/Headers \
  -c Libraries/occt-src/src/ModelingAlgorithms/TKShHealing/ShapeFix/ShapeFix_Face.cxx -o /tmp/sff.o
clang++ -std=c++17 -O2 repro.cxx /tmp/sff.o \
  -L Libraries/OCCT.xcframework/macos-arm64 -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ -o repro
MMGT_OPT=0 ./repro
```

A 4-point "bowtie" face extruded into a prism and healed (`ShapeFix_Shape`) crashes 3/3 on stock
OCCT 8.0.0p1 and survives 5/5 with the patch; the four `OCCTReconstruct` `crash-repro` fixtures
likewise survive. `ShapeFix_Shape` output on valid box/sphere/cylinder is byte-identical to stock
(the guard only triggers for a non-face replacement, which never happens for a well-formed face).

Until the xcframework is rebuilt with this patch, the in-wrapper guard shipped in v1.8.3
(`occtHasSelfIntersectingWire`) prevents the crash from reaching this code.

## 0002-STEPControl_Writer-initialize-missing-shape-processing-1334.patch

**Backports [Open-Cascade-SAS/OCCT#1334](https://github.com/Open-Cascade-SAS/OCCT/pull/1334)** ("Data
Exchange - initialize STEP writer healing parameters", merged 2026-07-10), which lands *after* our
`V8_0_0_p1` pin (tagged 2026-06-16). Fixes [#280](https://github.com/SecondMouseAU/OCCTSwift/issues/280).

`STEPCAFControl_Controller`'s constructor replaces the actor its base `STEPControl_Controller`
constructor had just configured, without re-applying `SetShapeProcessFlags`, and then `AutoRecord()`s
itself under the same `"STEP"`/`"step"` names the plain writer resolves by —
`STEPControl_Writer::SetWS()` unconditionally re-runs `SelectNorm("STEP")`. So after **any** XDE STEP
read (merely *constructing* a `STEPCAFControl_Reader` is enough — no `ReadFile`, no `Transfer`, no
document), every shape-level STEP write ran with **empty** `OperationsFlags`: `DirectFaces` never ran,
and faces built on indirect (left-handed) surfaces were silently dropped.

A cone frustum (r1=5, r2=2, h=10) wrote as a 2-face solid with its lateral `CONICAL_SURFACE` and seam
`LINE`s missing and 63% of its volume gone (408.407 → 151.844) — while still reporting
`isValid == true`. Only cones were affected: box/cylinder/sphere/torus have no indirect surfaces.

p1 already *defines* `STEPControl_Writer::InitializeMissingParameters()` (which restores the default
ShapeFix parameters **and** the `SplitCommonVertex`/`DirectFaces` flags when absent) but never calls
it — dead code there, and `private`, so a consumer cannot invoke it either. The patch is upstream's
one-line fix: call it at the point of transfer.

**Validation:** `STEPWriterCAFCorruptionTests` in `Tests/OCCTIOTests` does the XDE read itself and
asserts the frustum still round-trips (3 faces, `CONICAL_SURFACE` present in the file, volume within
1% of the analytic 130π). Red against the stock p1 binary, green after this rebuild. It also fixes the
long-standing `cone()` failure in `StressFormatRoundTripTests`, which passed in isolation and failed in
every full run because `OCCTIOTests` reads a STEP first.

**Retire** once the bundled OCCT moves past upstream `e2de4398ca6bf034074e6921599da76a9941c792`.

## 0003-TopOpeBRep-non-reentrant-globals-fillet-298.patch

**Fixes the upstream OCCT thread-safety defect behind [#298](https://github.com/SecondMouseAU/OCCTSwift/issues/298)** — concurrent `BRepFilletAPI_MakeFillet` builds on independent shapes corrupt each other.

`BRepFilletAPI_MakeFillet` reconstructs its result solid through the legacy `TopOpeBRepBuild` boolean engine (`ChFi3d_Builder::Compute` → `TopOpeBRepBuild_HBuilder::MergeSolid` → `TopOpeBRepBuild_Builder::SplitSolid`), which passes state between methods through **file-scope `static` variables**. That makes it non-reentrant: two fillet builds on separate threads produce a wrong-but-plausible solid that fails `BRepCheck` — silent bad geometry, no crash, no thrown error.

ThreadSanitizer on an 8-thread fuse+fillet stress (V8_0_0_p1) pinpoints the **functional** culprit as `STATIC_SOLIDINDEX` in `TopOpeBRepBuild_Builder.cxx`: `SplitSolid` sets it to 1/2 to tell `FillSolid` which operand it is splitting, and `FillSolid` reads it back to pick the operand shape. Concurrent reconstructions interleave the writes, so `FillSolid` mis-classifies faces and drops material (the ~260-unit volume loss in the repro). Fixing that one variable makes a stress of 1600 concurrent fillet builds return correct geometry every time (was ~15–20% corrupt).

The patch converts the fillet-path shared statics to `static thread_local` (each thread keeps its own copy of the cross-call state; single-thread behaviour is unchanged):

- **Functional** (cause the corruption): `STATIC_SOLIDINDEX` (`TopOpeBRepBuild_Builder.cxx`) and `STATIC_lastVPind` (`TopOpeBRep_kpart.cxx`, same cross-call-cache pattern, converted for the same reason).
- **Benign data races** on the same path (no geometry corruption observed — `STATIC_SOLIDINDEX` alone already gives correct geometry — but still UB; converted so concurrent fillet is TSan-clean): the constant/evolutive-radius blend solvers' scratch cache (`BlendFunc_ConstRad.cxx`, `BlendFunc_EvolRad.cxx`) and the ChFi3d curve checker's reused adaptor (`ChFi3d_Builder_6.cxx`).

This is the same class of fix, in the same engine, as [Open-Cascade-SAS/OCCT#1180](https://github.com/Open-Cascade-SAS/OCCT/pull/1180) (19 TKBool globals → `thread_local` across 8 files); `STATIC_SOLIDINDEX` and these were not covered by it.

**Validation:** the isolated pure-C++ repro (`fuse` two/three prisms → fillet the seam, 8 threads) returns BRepCheck-invalid solids across several wrong volumes on stock p1, and 0/1600 invalid with a single correct volume after the patch. ThreadSanitizer reports the `STATIC_SOLIDINDEX` and `BlendFunc` scratch races on stock p1 and is clean on the fillet path after the patch (only an unrelated benign `BOPAlgo_InitMessages` lazy-init race remains, in the boolean path — orthogonal). The in-wrapper `occtFilletMutex` that v1.12.1 shipped as the interim guard was **already removed in v1.12.3** once this kernel patch made fillet reentrant — the patch is now the sole protection.

**Submitted upstream** as [Open-Cascade-SAS/OCCT#1374](https://github.com/Open-Cascade-SAS/OCCT/pull/1374) (open). **Retire** once an upstream OCCT release includes these `thread_local` conversions and we re-pin to it.

## 0004-ShapeAnalysis_FreeBounds-init-owires-empty-input-310.patch

**Fixes the upstream OCCT crash behind [#310](https://github.com/SecondMouseAU/OCCTSwift/issues/310)** — `ShapeAnalysis_FreeBounds` (backing `Shape.freeBoundsClosedWires`/`freeBoundsClosedCount`/`freeBoundsOpenWires`) SIGSEGVs on certain shapes with multiple free-boundary components.

`ShapeAnalysis_FreeBounds::SplitWire` (its per-wire helper) finds each wire's closed sub-loops, then hands whatever edges weren't consumed to `ConnectEdgesToWires` to build the "open" result. When a wire's edges are **entirely** consumed by closed-loop detection — leaving zero leftover edges — that hand-off is an empty (but non-null) sequence. The call chain `ConnectEdgesToWires` → `ConnectWiresToWires` → `connectWiresToWiresImpl` starts with:

```cpp
if (iwires.IsNull() || !iwires->Length())
{
  return;
}
```

For empty input this returns **without ever assigning `owires`** — every caller in the file starts from a freshly-defaulted (null) handle, so the null propagates all the way back to `SplitWire`'s `open` output parameter, then to `ShapeAnalysis_FreeBounds::SplitWires`'s `open->Append(tmpopen)` — dereferencing the null handle, an uncatchable SIGSEGV. Not a data-volume threshold: it depends only on whether *any* single free-boundary component happens to close with nothing left over, so a shape with 150+ loops can be fine while a 2-loop shape crashes (and vice versa).

**Fix:** the one-line contract restoration `connectWiresToWiresImpl`'s own non-empty path already follows a few lines down (`owires = new NCollection_HSequence<TopoDS_Shape>;` before populating it) — "nothing to connect" should produce a valid **empty** result, not an untouched out-parameter.

**Validation** (AddressSanitizer, extending the #0001 override-link technique — see the patch's own commit message for the full command sequence): an ASan-instrumented macOS-arm64 build (`ModelingAlgorithms`+`ModelingData`+`FoundationClasses`, `RelWithDebInfo`, `MMGT_OPT=0` at runtime) crashes 100% of the time on two disjoint planar faces in one compound — same function, same `NCollection_Sequence::Append` call, same `0xfffffffffffffff8` fault address at both `-O2` and `-O0` — and returns the correct `2 closed, 0 open` after the patch. On the real 150-face fixture from #310: `tol=0.05` gives `152 closed/0 open` byte-identical before and after (no behavior change on the working path); `tol=0.10` crashes on stock p1 and returns `144 closed/0 open` after.

Reported and isolated at SecondMouseAU/OCCTSwift#310; a repro-only report was filed upstream as [Open-Cascade-SAS/OCCT#1376](https://github.com/Open-Cascade-SAS/OCCT/issues/1376) before the root cause was pinned down, followed up with the fix as [OCCT#1377](https://github.com/Open-Cascade-SAS/OCCT/pull/1377).

**Retire** once the bundled OCCT includes this fix.

## 0005-ShapeFix_Face-guard-null-context-FixPeriodicDegenerated-317.patch

**Fixes the upstream OCCT crash behind [#317](https://github.com/SecondMouseAU/OCCTSwift/issues/317)** — `ShapeFix_Face::Perform` SIGSEGVs healing a face whose sole boundary wire is a single closed edge belting the full period of a `Geom_ConicalSurface` (the shape produced by fitting a rivet/boss-rim seam as one periodic curve — `Wire.wireFromEdges` itself was the original suspect, per the issue's title, until a real in-process backtrace pinpointed the actual site).

`ShapeFix_Face::FixPeriodicDegenerated()` (added to patch in a degenerate apex edge for exactly this "lone wire belts a cone" case) builds the apex edge/wire, assembles a new face, and finalizes:

```cpp
myResult = aNewFace;
Context()->Replace(myFace, myResult);
```

Every *other* `Context()->Replace` call site in this same file — eleven of them — guards against a null `Context()` first (either a plain `if (!Context().IsNull())`, or a lazy `SetContext(new ShapeBuild_ReShape)` when null). `FixPeriodicDegenerated` even checks `Context().IsNull()` at the *top* of the function before calling `Context()->Apply()` — but the check is missing at the *bottom*. `Context()` returns `ShapeFix_Root::myContext`, which the base constructor leaves null; it's only set by an explicit `SetContext()` call, which the ordinary, most common usage (`ShapeFix_Face fixer(face); fixer.Perform();` — including our own bridge, before this patch) never makes. Any caller healing a lone periodic-conical wire without a context null-derefs.

**Fix:** the same guard used at every other call site in the file — only replace in the context if there is one.

**Validation** (fast path, no full rebuild — see the `#0001` entry above for the override-link technique): a synthetic single closed edge (`GeomAPI_Interpolate`, `closed=true`, 10 real points from a rivet rim on `railsim_581_lead.stl`) trimmed to a `Geom_ConicalSurface` via `BRepBuilderAPI_MakeFace(surf, wire, true)`, then healed with a bare `ShapeFix_Face fixer(face); fixer.Perform();`, SIGSEGVs 100% of the time on stock `V8_0_0_p1`. Diagnosed with a custom `backtrace_symbols_fd` `SIGSEGV` handler (`lldb`/core dumps unavailable in the diagnosing sandbox — see the `feedback-lldb-blocked-use-signal-handler` note): the backtrace pins the crash to `ShapeFix_Face::FixPeriodicDegenerated`; `-O0` single-TU override-link tracing confirms every prior statement in the function completes and the crash is specifically the unguarded `Context()->Replace` call. After the patch the same input returns `IsDone()==true` and a valid healed face. Also applied as a defensive `fixer.SetContext(new ShapeBuild_ReShape)` in the three OCCTSwift bridge call sites that construct a bare `ShapeFix_Face` (`OCCTShapeCreateFaceFromSurfaceWire[WithHoles]`, `OCCTFaceFixerCreate`), so the crash is closed immediately without waiting on an xcframework rebuild.

Reported and isolated at SecondMouseAU/OCCTSwift#317; filed upstream as [Open-Cascade-SAS/OCCT#1378](https://github.com/Open-Cascade-SAS/OCCT/issues/1378), fix as [OCCT#1380](https://github.com/Open-Cascade-SAS/OCCT/pull/1380).

**Retire** once the bundled OCCT includes this fix.

## 0006-BRepGProp_EdgeTool-use-adaptor-NbPoles-curve-on-surface-318.patch

**Fixes the upstream OCCT crash behind [#318](https://github.com/SecondMouseAU/OCCTSwift/issues/318)** — `BRepGProp::LinearProperties` (backing `Shape.analyze(tolerance:)`'s small-edge scan, and anything else built on `BRepGProp_Cinert`) SIGSEGVs computing the integration order for an edge whose sole geometry is a Bezier/BSpline-type curve-on-surface pcurve (no 3D curve) — the common case for a degenerate edge `BRepBuilderAPI_Sewing` produces reconciling near-coincident vertices between two faces that don't share an edge outright.

`BRepGProp_EdgeTool::IntegrationOrder` branches on `BAC.GetType()` (a `BRepAdaptor_Curve`), which correctly reports the curve-on-surface pcurve's type via `GeomAdaptor_TransformedCurve::GetType()`'s override (`myConSurf.IsNull() ? myCurve.GetType() : myConSurf->GetType()`), but then reads the pole count via a completely different, non-virtual path: `BAC.Curve().Curve()`, down-cast to `Geom_BezierCurve`/`Geom_BSplineCurve`. `BAC.Curve()` returns the base `GeomAdaptor_Curve` sub-object (`myCurve`), which holds the 3D-curve representation only — it is never `Load()`ed when the edge has no 3D curve (only `myConSurf` gets set), so the handle is null, the down-cast returns null, and `->NbPoles()` dereferences it.

**Fix:** `GeomAdaptor_TransformedCurve` already has a correctly-dispatching `NbPoles()` override right next to `GetType()` in the same header (`myConSurf.IsNull() ? myCurve.NbPoles() : myConSurf->NbPoles()`). Calling `BAC.NbPoles()` instead of manually re-deriving the pole count fixes the crash and matches the accessor `GetType()` already uses one line above it — no cast, no null check needed, no behaviour change for an edge that does have a 3D curve.

**Validation:** sewing two real mesh-derived planar candidate faces from OCCTReconstruct's plane-select spike (`kof_ii_engine_cover.stl`, regions 10 + 64) with `BRepBuilderAPI_Sewing` produces a compound containing a degenerate edge whose only representation is a BSpline-type pcurve; running `BRepGProp::LinearProperties(edge, props)` on it (the same call `Shape.analyze(tolerance:)` makes per edge) SIGSEGVs 100% of the time on stock p1 — diagnosed with a custom `SIGSEGV` handler (`lldb`/core dumps unavailable in the diagnosing sandbox), backtrace pins the crash to `BRepGProp_EdgeTool::IntegrationOrder`. A from-scratch synthetic degenerate edge (`BRep_Builder` + a hand-built `Geom2d_BSplineCurve` pcurve on a plane, no 3D curve) reproduces the identical crash trace, confirming the mechanism doesn't depend on the specific fixture. After the patch both the real fixture and the synthetic edge complete and return a sane length. Also applied as a defensive guard in the bridge (`OCCTShapeAnalyze`'s small-edge scan skips degenerate edges outright — a degenerate edge's zero 3D extent isn't a "small edge" defect to flag, and this closes the crash immediately without waiting on an xcframework rebuild).

Reported and isolated at SecondMouseAU/OCCTSwift#318; filed upstream as [Open-Cascade-SAS/OCCT#1381](https://github.com/Open-Cascade-SAS/OCCT/issues/1381), fix as [OCCT#1382](https://github.com/Open-Cascade-SAS/OCCT/pull/1382).

**Retire** once the bundled OCCT includes this fix.

## 0007-ShapeAnalysis_FreeBounds-reset-lwire-skipped-loop-323.patch

**Backports** [Open-Cascade-SAS/OCCT#1331](https://github.com/Open-Cascade-SAS/OCCT/pull/1331) (open, third-party author, pinned to commit `7557161a3dbe7e1ba18a3e63e1e104830d8c24c5`), fixing [OCCT#1330](https://github.com/Open-Cascade-SAS/OCCT/issues/1330). Audited and queued in [#323](https://github.com/SecondMouseAU/OCCTSwift/issues/323) alongside `0008`/`0009`; unlike `0001`–`0006`, this batch wasn't discovered via an OCCTSwift crash report — it's a proactive audit of upstream OCCT PRs filed since our `V8_0_0_p1` baseline that fix crashes/hangs in code paths we exercise.

`ShapeAnalysis_FreeBounds::connectWiresToWiresImpl` — the same static helper patch `0004` already touches for a different bug (#310) — has a "find the next unconsumed wire" loop that sets `lwire = i` **before** checking whether the candidate wire it just loaded actually has any edges:

```cpp
lwire = i;
sewd->Add(TopoDS::Wire(arrwires->Value(lwire)));
aSel.LoadList(lwire);
if (sewd->NbEdges() > 0) { break; }
sewd->Clear();
```

If the wire is skipped (zero edges — e.g. a "wire" wrapping a single **internal-orientation** edge, which contributes no real boundary edges), `lwire` is left stale instead of reset. If every remaining candidate is likewise skipped, the loop exits with `lwire` still holding that stale index rather than `-1`, so the caller's `if (lwire == -1) { done = true; }` never fires — the outer loop's next iteration reads invalid memory through the stale `sewd`.

**Fix:** only assign `lwire = i` once the wire is actually accepted (`sewd->NbEdges() > 0`), matching upstream's exact reordering.

**Validation** (fast path, no full rebuild — see the `#0001` entry above for the override-link technique): the upstream TCL test (`tests/bugs/heal/bug1330`) translated to C++ — a valid closed triangle wire plus a single internal-orientation edge, fed to `ShapeAnalysis_FreeBounds::ConnectEdgesToWires` — SIGSEGVs 100% of the time on stock p1 + patches `0001`–`0006` (`ShapeExtend_WireData::Edge` reading invalid data) and returns a valid 1-wire result after this patch.

Reported upstream as [OCCT#1330](https://github.com/Open-Cascade-SAS/OCCT/issues/1330) / [OCCT#1331](https://github.com/Open-Cascade-SAS/OCCT/pull/1331) (third party, open — pin to the SHA above and re-verify if it changes in review).

**Retire** once the bundled OCCT includes this fix.

## 0008-Geom_BSplineCurve-O1-PeriodicNormalization-323.patch

**Backports** [Open-Cascade-SAS/OCCT#1329](https://github.com/Open-Cascade-SAS/OCCT/pull/1329) (merged 2026-07-05, upstream commit `37c9279f446894c5d123cb1fdda0ac848959361f`), fixing [OCCT#1288](https://github.com/Open-Cascade-SAS/OCCT/issues/1288) ("Boolean operation 'section' hangs-up for a pair of cylindrical shapes"). Audited and queued in [#323](https://github.com/SecondMouseAU/OCCTSwift/issues/323).

`Geom_BSplineCurve::PeriodicNormalization` brought an out-of-range parameter back into a periodic curve's valid range by repeatedly adding/subtracting one period at a time in a `while` loop — O(N) in the distance from the valid range, and a genuine infinite loop once the parameter's magnitude is many orders larger than the period: `Parameter -= Period` becomes a floating-point no-op at that magnitude, so the loop never terminates. `BRepAlgoAPI_Section` hung indefinitely reaching this path on cylindrical shapes with self-intersecting geometry.

**Fix:** rewritten to O(1) — one division (`std::floor`) computes the whole number of periods to shift, applied in a single step, with at most one single-period correction for floating-point residual overshoot (using `std::nextafter` to guarantee forward progress if the correction is itself a no-op). An early return when the parameter is already in range skips even that division in the common case.

**Validation** (fast path, no full rebuild): a normal closed periodic curve (`GeomAPI_Interpolate`, 8 points on a unit circle, period ≈ 6.12) with `PeriodicNormalization(1e17)` hangs indefinitely on stock p1 (confirmed by wall-clock timeout) and returns instantly with a valid in-range parameter (`1.0364`) after the patch. A sanity sweep of nine in-range/near-boundary/several-periods-off parameters produces **byte-identical** output before and after — no behavior change for values this function is normally called with.

Filed upstream by OCCT as [OCCT#1329](https://github.com/Open-Cascade-SAS/OCCT/pull/1329) (merged, stable).

**Retire** once the bundled OCCT moves past commit `37c9279f446894c5d123cb1fdda0ac848959361f`.

## 0009-StepData_StepWriter-split-oversized-string-323.patch

**Backports** [Open-Cascade-SAS/OCCT#1318](https://github.com/Open-Cascade-SAS/OCCT/pull/1318) (open, by an OCCT maintainer, pinned to commit `72bc2368372d93d6f84717f2327131d4c000d7c1`). No linked upstream issue. Audited and queued in [#323](https://github.com/SecondMouseAU/OCCTSwift/issues/323). Same subsystem as `0002`.

`StepData_StepWriter::AddString` writes a raw token into the writer's current-line buffer (fixed at 72 characters, `StepLong`), flushing and resetting the line whenever the pending text won't fit — assuming the token itself is never longer than one full line. When a single unbroken string value (e.g. a long name/label field with no natural break point) is longer than 72 characters, the flush-check can never become true no matter how many times the line is reset: the loop runs forever.

**Fix:** when the token fits within `StepLong`, behavior is unchanged. When it doesn't, the new code splits the token across as many lines as needed, filling each with as much as fits before flushing and continuing with the remainder — continuation lines also drop their indentation when the indented prefix would leave no room for the pending text.

**Validation** (fast path, no full rebuild): `StepData_StepWriter::StartEntity` + `SendString` (the public entry point — `AddString` itself is private) with a 200-character unbroken string hangs indefinitely on stock p1 (confirmed by wall-clock timeout) and returns instantly after the patch, correctly split across three continuation lines with the original text intact end-to-end. A sanity check with only normal-length fields produces **byte-identical** `Print()` output before and after. New OCCTSwift-level regression test `STEPWriterOversizedNameTests` (`OCCTIOTests`) exercises the same path through `Shape.writeSTEP(to:name:)`.

**Retire** once the bundled OCCT includes this fix (open PR — pin to the SHA above and re-verify if it changes in review).

## 0010-Intf_Interference-O1-tangent-zone-checkpoint-breaker-319.patch

**Fixes the upstream OCCT hang behind [#319](https://github.com/SecondMouseAU/OCCTSwift/issues/319)** — `isSelfIntersecting`'s `hardTimeout:` bound could not actually interrupt the self-interference search on a pathological artifact, running 619s+ of CPU (and observed to run far longer, uninterrupted) against a 30s deadline. Reported upstream as [Open-Cascade-SAS/OCCT#1385](https://github.com/Open-Cascade-SAS/OCCT/issues/1385) (reproducer at
[`Scripts/repro/319-selfintersection`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/319-selfintersection)), fix as [OCCT#1386](https://github.com/Open-Cascade-SAS/OCCT/pull/1386) (CI green on all 3 platforms, ready for review).

Two independent, compounding defects in `BOPAlgo_ArgumentAnalyzer`'s self-interference phase (`BOPAlgo_CheckerSI::CheckFaceSelfIntersection` → `IntTools_FaceFace::Perform` → `Intf_Interference::Insert`):

1. **O(n)-per-call point access.** `Intf_Interference::Insert` compares points between the new tangent zone and every existing zone via `Intf_TangentZone::GetPoint(Index)`, called inside a doubly-nested loop. `GetPoint` indexes the zone's backing `NCollection_Sequence` — a linked list with no O(1) random access — so each call walks from the nearest end. Profiling the pathological artifact (both independently and cross-checked against a second session's report) attributed ~80% of leaf samples to `NCollection_BaseSequence::Find`. The artifact's geometry produces an unboundedly growing *number* of distinct tangent zones, not one giant merging zone, so this alone is an O(1)-per-lookup fix to an inherently expensive matching structure — it helps, but does not bound wall-clock time.
2. **No checkpoint below `CheckFaceSelfIntersection`.** The self-interference phase never polled its cooperative progress indicator (OCCT's usual `Message_ProgressRange`/`UserBreak()` idiom) anywhere inside a single face's check — only *between* whole-face checks. A caller's timeout could therefore only fire in the gaps between faces, not while stuck inside one, which is exactly where the artifact spends its time.

**Fix:** (1) `Intf_TangentZone::Points()` builds and caches a true `NCollection_Array1` per zone in one linear pass on first use, invalidated by any mutation (`Append`/`InsertAfter`/`InsertBefore`); `Insert()` now indexes through the cached array instead of calling `GetPoint` in the nested loop — same comparisons, same result, O(1) lookup. (2) `Intf_Interference::SetBreaker` (a thread-local, RAII-scoped via `Intf_InterferenceBreakerScope`) lets `Insert()` poll a `Message_ProgressScope` every 256 calls (not every call, to avoid taxing the common case) and abort by throwing `Standard_Failure`, unwinding the deep `IntTools_FaceFace`/`Intf_Interference` call stack safely. `BOPAlgo_CheckerSI`'s self-intersect functor wires this up around `IntTools_FaceFace::Perform`, gated on `!myRunParallel` — an exception thrown from a worker thread of `OSD_Parallel::For`'s parallel path would be unsafe (risks `std::terminate()`), so the checkpoint is only active on the single-threaded path.

**Validation:** verified on the linked artifact — with both fixes, a 0.5s deadline returns in 0.547s and a 30s deadline returns in 30.1s (vs. 619s+ CPU / never returning on stock p1), with correct `HasFaulty()` results at every deadline tested (0.5s/1s/2s/3s/5s/30s), clean across a 10x repeated-run stress test. Zero regression on clean, overlapping, and grid self-intersection sanity cases (byte-identical `HasFaulty()`/point output). An empty-zone edge case (`Intf_TangentZone::Points()` on a zone with zero points) is guarded explicitly — `NCollection_Array1::Resize(1, 0, false)` throws `Standard_RangeError` for an empty range, caught by a dedicated GTest before it could reach a real caller. New upstream GTests `Intf_TangentZone_Test.cxx` (`Points()` correctness and cache invalidation, including the empty-zone case) and `Intf_Interference_Test.cxx` (breaker aborts `Insert()` promptly; a non-tripping or absent breaker leaves behavior unchanged) pass on Linux/Windows/macOS in OCCT's own CI, alongside the full regression/GTest/build matrix — all green on the first PR submission.

**Retire** once the bundled OCCT includes this fix.

## 0011-XCAFDoc_ShapeTool-AutoNamingScope-341.patch

**Fixes the upstream OCCT thread-safety defect behind [#341](https://github.com/SecondMouseAU/OCCTSwift/issues/341)** — concurrent OBJ/glTF import or PLY/OBJ/glTF export races on `XCAFDoc_ShapeTool`'s global auto-naming mode.

`XCAFDoc_ShapeTool::theAutoNaming` is a file-scope `static bool` — a single process-wide setting, by design (the header says so explicitly: "This setting is global; it cannot be made a member function"). Three independent call sites do the same unsynchronized save/modify/restore dance around it: `RWMesh_CafReader::fillDocument()` (shared base of `RWObj_CafReader` and `RWGltf_CafReader` — OBJ **and** glTF import both hit this), `RWGltf_CafReader::fillDocument()` (a *separate*, near-duplicate override — not a call into the base class's version), and `XCAFDoc_Editor::Expand()` (which additionally recurses into itself while the dance is still in flight). `XCAFDoc_ShapeTool::AddShape`/`addShape` reads the same flag internally to decide whether to auto-generate a name.

ThreadSanitizer on an 8-10 thread concurrent-OBJ-round-trip stress (each thread its own uniquely-named file, V8_0_0_p1 + patches `0001`–`0010`) reports 9-17 races per run — `SetAutoNaming`/`AutoNaming`/`addShape`'s internal read, all on `theAutoNaming` — confirming two distinct problems: (1) two threads' save/modify/restore critical sections can interleave, so one thread's restore stomps another's still-in-progress override (a *logical* bug: the wrong auto-naming mode is active for part of a build, independent of memory safety); (2) `theAutoNaming` itself is a plain `bool` read and written with no synchronization from *any* caller, including ordinary `AddShape` calls made outside any of the three save/restore call sites above — a genuine data race (undefined behavior) on every access, not just inside the three call sites.

**Fix, both layers.** `XCAFDoc_ShapeTool::AutoNamingScope` is a new RAII helper (`AutoNamingScope(bool)` constructor / destructor) that holds a `std::recursive_mutex` for its *entire* lifetime — not just around the individual get/set calls — so two threads' save-modify-restore sequences serialize against each other instead of interleaving (recursive because `XCAFDoc_Editor::Expand()` needs to reenter it on the same thread). All three call sites now use it instead of a bare `AutoNaming()`/`SetAutoNaming()` pair, collapsing `XCAFDoc_Editor::Expand()`'s two duplicate manual-restore-before-return sites into one destructor-driven restore that fires on every exit path. Separately, `theAutoNaming` itself is now `std::atomic<bool>` instead of a plain `bool`, so *every* access anywhere in the file — including `AddShape`'s internal read, which participates in none of the three scoped sections — is well-defined and TSan-clean, closing the residual gap the mutex alone doesn't reach (an unscoped `AddShape` call has no scope to be excluded by; it was never going to get a *stable* value while another thread's scope is active, since the flag is deliberately global, but it must at least get a *real*, non-torn one).

**Validation:** the same TSan stress (10 threads × 200 iterations, 2000 concurrent OBJ round-trips) reports **zero** `XCAFDoc_ShapeTool` races after the patch, across 4 separate runs — only the already-known, unrelated `Message_PrinterOStream`/`std::cout` console-write race remains (OCCT's default messenger has no internal locking; cosmetic, not fixed here). Regression-clean on the `create_fillet_boolean` (#298) and `mesh_independent` scenarios — only the already-known benign `BOPAlgo_InitMessages` lazy-init race, unchanged. `RWGltf_CafReader`'s copy of the fix could not be exercised under TSan directly (this repo's minimal-module TSan build excludes `TKDEGLTF` — it requires RapidJSON, disabled for the faster build) but compiles cleanly and is mechanically identical to the `RWMesh_CafReader`/`RWObj_CafReader` path that *was* verified.

Superseded the interim bridge-side mitigation (`meshCafMutex()` in `OCCTBridge_IO.mm`, shipped v1.15.4) — removed once this kernel patch made the underlying OCCT calls safe on their own.

Reported and isolated at SecondMouseAU/OCCTSwift#341; filed upstream as [Open-Cascade-SAS/OCCT#1387](https://github.com/Open-Cascade-SAS/OCCT/issues/1387) (repro), fix as [OCCT#1388](https://github.com/Open-Cascade-SAS/OCCT/pull/1388) (draft).

**Retire** once the bundled OCCT includes this fix.

## 0012-CDF_Directory-XCAFApp_Application-thread-safety-344.patch

**Fixes the upstream OCCT crash behind [#344](https://github.com/SecondMouseAU/OCCTSwift/issues/344)** — an uncatchable SIGSEGV seen in ~1-in-10 parallel `swift test` runs right after two concurrent OBJ mesh imports, confirmed to survive the #341 kernel fix (theAutoNaming) in v1.15.5.

Two independent, previously-undetected races, both in code the #341 TSan stress never reached — that harness (`Scripts/repro/341-meshcaf/occt_341_stress.cpp`) builds its `TDocStd_Document` directly (`new TDocStd_Document("BinXCAF")`), bypassing `XCAFApp_Application`/`CDF_Application` entirely. The real bridge path (`OCCTDocumentLoadOBJ` and every other document-producing bridge call) does not: all of them go through `XCAFApp_Application::GetApplication()->NewDocument(...)`.

1. **`XCAFApp_Application::GetApplication()`** — a textbook double-checked-locking-without-locking bug: `static Handle(XCAFApp_Application) locApp; if (locApp.IsNull()) { locApp = new XCAFApp_Application; }`. Two threads' first concurrent call can both observe `IsNull()` and both construct a new instance, racing to assign the shared `locApp` handle. This is the dominant defect: TSan shows it produces **multiple concurrently constructed `XCAFApp_Application` instances**, whose "losing" copies are then torn down while other threads are still constructing/using a same-generation object — cascading into races across dozens of unrelated destructors (`TDF_LabelNode::Destroy`, `TCollection_ExtendedString::~`, `CDM_Document::~CDM_Document`, `NCollection_BaseList::PClear`, ...) and several ctor/dtor-vs-virtual-call ("vptr") reports, not just a leaked handle.
2. **`CDF_Directory::Add`/`Remove`/`Contains`** — every `XCAFApp_Application`/`CDF_Application` instance is normally shared process-wide (the entire point of `GetApplication()`), so its one `CDF_Directory` receives `Add()` from every document-creating call on every thread. `myDocuments` is a plain `NCollection_List` with zero synchronization: `NCollection_BaseList::PAppend` mutates `myFirst`/`myLast`/`myLength` with no locking at all. Confirmed independently by TSan (`CDF_Directory.cxx:30`, `NCollection_BaseList.cxx:45/52/53`) even setting aside race #1.

The bridge never calls `Application->Close()` on a document (no call site in `Sources/OCCTBridge`), so `CDF_Directory::Remove` is never reached from OCCTSwift — every document ever created via the bridge accumulates in `myDocuments` for the life of the process. That's a separate, pre-existing leak, not fixed here (out of scope for #344).

**Fix, both layers:**

1. `XCAFApp_Application::GetApplication()`: fold construction into the static local's initializer — a C++11 "magic static" is thread-safe exactly once, unlike the previous separate `IsNull()`-guarded assignment.
2. `CDF_Directory`: a private `mutable std::mutex myMutex` guards `Add`/`Remove`/`Contains`/`Length`/`IsEmpty`/`Last`. `Add()` inlines the containment scan instead of calling the public `Contains()`, to avoid a self-deadlock on the (non-recursive) mutex. `List()` — used only by the friend `CDF_DirectoryIterator`, which nothing in OCCTSwift's bridge uses — is intentionally left unguarded; closing that gap would need a bigger API change (a snapshot copy) out of proportion to the two confirmed, reachable races this patch fixes.

**Validation:** a debug (`-O0 -g`) build with a temporary `SIGSEGV`/`SIGBUS` signal handler (`backtrace_symbols_fd`, per the `feedback-lldb-blocked-use-signal-handler` technique) crashes ~50% of runs at 10 threads × 3000 barrier-synchronized rounds on stock p1, resolving to `TDocStd_Application::NewDocument -> CDF_Application::Open` both times — matching the `CDF_Directory::Add`/`PAppend` corruption mechanism. TSan (minimal-module build, same protocol as #298/#319/#341): stock p1 reports 234 races at 8 threads × 200 free-running iterations; the patch reduces this to 9, all directly in `CDF_Directory::Add`/`PAppend` and all showing the *same* mutex held on both sides of the reported conflict (`mutexes: write M0` on both the read and the write) — a pattern consistent with a TSan/allocator-recycling artifact rather than a genuine unaddressed race (a control program with a trivially-correct `std::lock_guard` pattern under the identical TSan flags reports no such warning). The entire `GetApplication()`-driven destructor cascade — dozens of unique signatures pre-fix — is gone entirely.

**Second part, found during validation.** Fixing `GetApplication()`'s race means every caller now genuinely shares ONE `TDocStd_Application` instance (as intended) — which surfaced further races on that *same* instance's other unsynchronized state, previously masked by threads sometimes getting different (uncontended) instances of their own. Repeated `swift test` runs (validating the fix above) hit two more crashes in `Tests/OCCTXCAFTests`, both resolving to state on the same shared singleton:

3. **`TDocStd_Application::Resources()`** — the identical lazy-init race pattern as `GetApplication()`: `if (myResources.IsNull()) { myResources = new Resource_Manager(...); }`, no locking.
4. **`Resource_Manager`'s own maps** (`myRefMap`/`myUserMap`/`myExtStrMap`) — no synchronization at all. Caught live: a SIGTRAP inside `Resource_Manager::SetResource`, called from `TDocStd_Application::DefineFormat` (itself called by `Document.defineAllFormats()`, a common per-test setup call many parallel XCAF tests invoke concurrently).
5. **`CDF_Application::myReaders`/`myWriters`** (format-name → driver maps) — read/written from `DefineFormat`, `ReaderFromFormat`/`WriterFromFormat`, and `ReadingFormats`/`WritingFormats` with no locking. Caught live: a SIGSEGV inside `TDocStd_Application::ReadingFormats` iterating `myReaders` while another thread's `DefineFormat` mutated it concurrently.

**Fix, continued:** a mutex guards `Resources()`'s lazy-init (same pattern as fix 1); a `std::recursive_mutex` guards `Resource_Manager`'s public accessors (recursive because `Integer()`/`Real()`/`ExtValue()` call `Value()` internally, and the `int`/`double` `SetResource()` overloads call the `char*` one) — `GetMap()`, a raw-reference escape hatch with no callers in this area, is left unguarded, same rationale as `CDF_Directory::List()`; a mutex guards `CDF_Application::myReaders`/`myWriters` across every access point. The new `Resource_Manager` mutex member makes the class non-copyable by default, breaking `ShapeProcess_Context.cxx`'s existing (pre-existing, unrelated) `new Resource_Manager(*sRC)` thread-safety workaround (its own comment: *"Creating copy of sRC for thread safety of Resource_Manager variables... calling of SetResource() for one object in multiple threads causes race condition"* — OCCT's own prior acknowledgement of this exact defect, worked around locally rather than fixed at the source) — added an explicit copy constructor that copies the maps under the source's lock and default-constructs a fresh mutex for the new instance.

**Validation, continued:** SIGTRAP (`Resource_Manager::SetResource`) and SIGSEGV (`TDocStd_Application::ReadingFormats`) both reproducible before this part of the patch; 0/12 further `swift test` runs of `OCCTXCAFTests` reproduce either after it.

A third, separate crash surfaced during this same validation (`BinLDrivers_DocumentStorageDriver::Write`/`WriteSubTree` corrupting a *shared, cached, non-reentrant storage-driver instance* under concurrent `Save`/`SaveAs` of the same format) — architecturally different (a shared worker object, not a container needing a lock) and **not fixed here**; filed separately as SecondMouseAU/OCCTSwift#349 for its own dedicated investigation.

See [`Scripts/repro/344-cdf-directory/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/344-cdf-directory) for the reproducers and full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1389](https://github.com/Open-Cascade-SAS/OCCT/issues/1389) (repro) / [OCCT#1390](https://github.com/Open-Cascade-SAS/OCCT/pull/1390) (fix, two commits).

**Retire** once the bundled OCCT includes this fix.

## 0013-ShapeUpgrade_UnifySameDomain-guard-null-pcurve-348.patch

**Fixes the upstream OCCT crash behind [#348](https://github.com/SecondMouseAU/OCCTSwift/issues/348)** — an uncatchable SIGSEGV in `UnifySameDomainBuilder.build()` on a real mesh-sewn solid, minimized to a standalone OCCTSwift-only reproducer (no mesh handling, no OCCTReconstruct code involved).

`ShapeUpgrade_UnifySameDomain::IntUnifyFaces` (and its file-local `SplitWire` helper) disambiguate between multiple candidate next-edges at a branching vertex by comparing each candidate's pcurve tangent direction on the current reference face. Three call sites in `IntUnifyFaces` (`ShapeUpgrade_UnifySameDomain.cxx:3989`, `:4003`, `:4027`) and a structurally identical pair in `SplitWire` (`:4643`, `:4659`) fetch that pcurve via `BRep_Tool::CurveOnSurface(edge, refFace, first, last)` and dereference it immediately (`->D1(...)`/`->Value(...)`) with no `IsNull()` check — unlike every other `CurveOnSurface` call site in the same file (e.g. `:426`, `:1838`), which do check. `CurveOnSurface` legitimately returns a null handle when an edge has no pcurve on the given face — routine for a raw per-triangle mesh-sewn solid (`BRepBuilderAPI_Sewing` output from an STL/mesh import) at a vertex shared by more than two edges. The dereference is a null-pointer virtual call: Address 0, uncatchable in-process (same signature as the #263/#310/#317/#318 crash family).

Confirmed via a debug (`-g -O0`) single-TU override-link (compile the patched `.cxx` standalone and link it *before* `libOCCT-macos.a`, so the linker never pulls the stock archive member for these symbols) + `lldb bt`: the crash resolves precisely to `ShapeUpgrade_UnifySameDomain.cxx:4003` (`aPCurve->D1(...)`), reached via `IntUnifyFaces` → `UnifyFaces` → `Build`.

**Fix:** guard all five call sites with `IsNull()` checks, following the file's own established pattern. A missing pcurve on a *candidate* edge means "skip it, not a rankable direction" (`continue`); a missing pcurve on the *current* edge (nothing to compare candidates against) falls back to treating all candidates as equally likely — the same fallback the surrounding code already takes for the "only one candidate" case (`TmpElist.Extent() <= 1`/`aElist.Extent() == 1`).

**Validation:** the attached fixture SIGSEGVs 3/3 on stock p1 + patches 0001-0012 (v1.15.7) and survives repeated runs (3+) with the patch applied.

See [`Scripts/repro/348-unify-null-pcurve/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/348-unify-null-pcurve) for the reproducer and full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1391](https://github.com/Open-Cascade-SAS/OCCT/issues/1391) (repro) / [OCCT#1392](https://github.com/Open-Cascade-SAS/OCCT/pull/1392) (fix).

**Retire** once the bundled OCCT includes this fix.

## 0014-CDF-driver-reentrancy-mutex-349.patch

**Fixes the upstream OCCT crash behind [#349](https://github.com/SecondMouseAU/OCCTSwift/issues/349)** — an uncatchable SIGSEGV under concurrent `Save`/`SaveAs` of the same document format, surfaced during validation of the #344 fix (the third, architecturally distinct crash found in that pass, deliberately not folded into patch 0012).

`CDF_Application::WriterFromFormat`/`ReaderFromFormat` cache one storage/retrieval driver instance per format (`myWriters`/`myReaders`, the map itself already made safe by #344) and hand the *same* cached instance back to every subsequent `Store()`/`Retrieve()` call for that format — including from different threads, different documents, concurrently. But `PCDM_StorageDriver`/`PCDM_Reader` subclasses (`BinLDrivers_DocumentStorageDriver` et al.) are not reentrant: `Write()`/`Read()` mutate instance-level scratch state — for `BinLDrivers_DocumentStorageDriver` alone: `myRelocTable`, `myTypesMap`, `myPAtt`, `myEmptyLabels`, `myMapUnsupported`, `mySizesToWrite`, `myFileName`, `myMsgDriver`, the lazily-initialized `myDrivers` table, plus the base class's `myIsError`/`myStoreStatus` — that gets clobbered when two threads call `Write()` on the same shared instance concurrently. `CDF_StoreList::Store`'s own comment already shows awareness the driver is shared across threads ("It has sense in multi-threaded access to the storage driver..."), but only the store-status was ever made safe; every other member raced freely. Structural, not BinLDrivers-specific: `XmlLDrivers`, `BinXCAFDrivers`/`XmlXCAFDrivers`, and `TObj` drivers all extend the same base classes and follow the identical per-instance-scratch-state pattern.

Confirmed via a debug (`-O0 -g`) build with a temporary SIGSEGV/SIGBUS signal handler: two threads racing `TDocStd_Application::SaveAs()` on a shared application crash reliably (within a few hundred rounds at just 2 threads), resolving to `BinMDF_ADriverTable::AssignIds(myTypesMap) <- NCollection_BaseMap::Destroy`, reached via `BinLDrivers_DocumentStorageDriver::Write -> FirstPass -> CDF_StoreList::Store -> CDF_Store::Realize -> TDocStd_Application::SaveAs` — two concurrent `Write()` calls both clearing/rebuilding `myTypesMap` out from under each other. TSan (minimal-module build, same protocol as #298/#319/#341/#344) confirms it directly: 136 distinct race warnings in one run (8 threads × 25 rounds), process itself still SIGSEGVs (exit 139) partway through — every non-unrelated report resolves into `BinLDrivers_DocumentStorageDriver::Write`/`FirstPass`/`FirstPassSubTree`/`WriteSubTree`/`WriteInfoSection`, `PCDM_StorageDriver::SetIsError`/`SetStoreStatus`, `BinMDF_ADriverTable::GetDriver`/`AssignIds`/`AddDerivedDriver`, and their `NCollection_BaseMap`/`NCollection_IndexedMap`/`NCollection_BaseList` internals — consistent with the whole per-call scratch surface racing, not just one field.

**Fix:** considered the issue's own two options — (a) a coarser mutex serializing driver dispatch, or (b) making the driver's `Write()`/`Read()` genuinely reentrant by eliminating shared scratch state. (b) was investigated and rejected as impractical here (unlike #298/#319/#341/#344, which each had one small, well-bounded piece of shared state): TSan shows essentially the *entire* driver object is scratch state for the duration of one `Write()` call, plus a nested shared object (`BinMDF_ADriverTable`) with its own internal mutation — eliminating it would mean threading new parameters through half a dozen private helpers, a sweeping signature change every format driver subclass would also need, for a change with high regression risk and far outside "minimal, surgical" for an upstream PR. Went with (a), placed on the shared resource itself rather than as one big lock around unrelated code: `PCDM_StorageDriver`/`PCDM_Reader` each get a `mutable std::mutex` + `Mutex()` accessor (every concrete format driver inherits it for free, zero subclass changes needed), held by the three places `CDF_Application`/`CDF_StoreList` actually invoke a cached, possibly-shared driver's `Write()`/`Read()`: `CDF_StoreList::Store`, `CDF_Application::Retrieve`, `CDF_Application::Read`. Doesn't serialize unrelated formats against each other — a `"BinOcaf"` save and an unrelated `"Xml"` save use different cached driver instances and different mutexes.

**Validation:** rebuilt the minimal-module TSan install with the patch applied and re-ran the same stress: race warnings 136 → **0** (confirmed again at a larger 10×200 stress), crash (SIGSEGV, exit 139) → **clean exit** across repeated runs. Full production xcframework rebuilt via `Scripts/build-occt.sh` (all 3 core slices, clean); `swift test --filter OCAFSaveLoadBinaryTests` and `swift test --filter OCCTXCAFTests` (339 tests) both clean, plus **3× full `swift test`** (4423 tests / 1282 suites each) clean, zero failures.

**New finding surfaced by this fix, not fixed here:** post-patch TSan runs consistently surface one different, previously-masked race — same "fixing one race exposes the next" pattern as #344's own history. `CDM_Application::myMetaDataLookUpTable` is a plain `NCollection_DataMap`, one instance per `CDM_Application`/`CDF_Application`, with zero synchronization; every `CDF_StoreList::Store()`/`CDF_FWOSDriver::CreateMetaData()`/`CDM_MetaData::LookUp()` call across every thread sharing that one `TDocStd_Application` reads/writes the same map and the `CDM_MetaData` objects it hands out — same failure class as `CDF_Directory::myDocuments` (#344) and `theAutoNaming` (#341). Out of scope for #349 (specifically the driver reentrancy this patch fixes); filed separately as [SecondMouseAU/OCCTSwift#353](https://github.com/SecondMouseAU/OCCTSwift/issues/353).

**Bridge mitigation:** `Sources/OCCTBridge/src/OCCTBridge_Document.mm`'s `ocafStoreMutex()` (serializing `OCCTDocumentSaveOCAF`/`OCCTDocumentSaveOCAFInPlace`/`OCCTDocumentLoadOCAF`, shipped v1.15.6) **stays** regardless of this kernel fix — same PR1→PR2 pattern as #298/#341/#344. It's coarser than necessary now, but removing it is a separate, lower-priority follow-up once this kernel fix has shipped in a released xcframework for a while.

See [`Scripts/repro/349-ocaf-driver-reentrancy/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/349-ocaf-driver-reentrancy) for the reproducer and full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1393](https://github.com/Open-Cascade-SAS/OCCT/issues/1393) (repro) / [OCCT#1394](https://github.com/Open-Cascade-SAS/OCCT/pull/1394) (fix, CI green on all platforms).

**Retire** once the bundled OCCT includes this fix.

## 0015-CDM_Application-metadata-lookup-table-mutex-353.patch

**Fixes the upstream OCCT crash behind [#353](https://github.com/SecondMouseAU/OCCTSwift/issues/353)** — a race surfaced while validating the #349 fix (patch 0014, shipped v1.15.9): post-#349-fix TSan runs consistently produced exactly one different, previously-masked warning, matching the "fixing one race exposes the next" pattern from #341→#344→#349.

`CDM_Application::myMetaDataLookUpTable` is a plain `NCollection_DataMap`, one instance per `CDM_Application` (in practice the one process-wide singleton, since #344's `GetApplication()` fix), with zero synchronization anywhere in the class. Three independent things race: (1) **map mutation** — `CDM_MetaData::LookUp()`'s unguarded `IsBound`+`Bind`/`Find`, called from `CDF_FWOSDriver::MetaData`/`CreateMetaData` (every `Store()`/`SaveAs()`), `XmlLDrivers_DocumentRetrievalDriver::Read`, and `PCDM_ReferenceIterator::MetaData`; (2) **map iteration** — `CDM_Document::SetMetaData()` walks the *entire* table on every save, reading every other document's `CDM_MetaData` state; (3) **per-object state** — each `CDM_MetaData`'s `myIsRetrieved`/`myDocument` fields, mutated by `SetDocument()`/`UnsetDocument()` and read by `IsRetrieved()`/`Document()` with no guard at all. TSan confirmed the exact trace quoted in the issue: `CDM_Document::SetMetaData()`'s map-iteration loop (reading `IsRetrieved()`, still inside #349's own per-driver lock — but that lock has no relationship to a *different* thread's document destructor) racing `~CDM_Document() -> CDM_MetaData::UnsetDocument()` tearing down an unrelated document's metadata entry on another thread. 1 confirmed race + SIGABRT (exit 134) on stock #349-fixed kernel, matching the issue's reported symptom exactly.

**Fix:** follows the established "lock the shared resource, don't restructure the subsystem" precedent (#341's atomic bool, #344's `CDF_Directory` mutex, #349's per-driver mutex) — the map's "bind once, reuse forever, share across all documents" caching design is load-bearing (how OCCT recognizes "this file is already open" across separate calls), not incidental scratch state. Two independent locks, matching the two distinct race shapes: (1) `CDM_Application` gets a `mutable std::mutex myMetaDataLookUpTableMutex` + accessor, threaded through `CDM_MetaData::LookUp()`'s two overloads (now take the mutex as an explicit parameter) and `CDM_Document::SetMetaData()`'s iteration — `CDF_FWOSDriver`'s constructor also now takes the mutex alongside the table reference it already stored; (2) `CDM_MetaData` gets its own private `mutable std::mutex myDocumentMutex` guarding `myIsRetrieved`/`myDocument`, since two already-bound `CDM_MetaData` objects can race on `SetDocument()`/`UnsetDocument()` vs. `IsRetrieved()`/`Document()` independent of the table lock. No changes to any format-specific driver subclass.

**Validation:** rebuilt the minimal-module TSan install (reused `occt-build-tsan349`/`occt-install-tsan349` from the #349 investigation, which already had patch 0014 baked in) with 0015 applied: race count 1 (+SIGABRT) → **0**, clean exit, across 5 runs (8×25, 10×60, 3×8×40). Full production xcframework rebuilt via `Scripts/build-occt.sh`; `swift test --filter OCAFSaveLoadBinaryTests`/`OCCTXCAFTests` and 3× full `swift test` (4423 tests) all clean.

**Not changed**: `CDM_MetaData::myDocumentVersion` (reached via `CDM_Reference.cxx` and `CDM_Application::SetDocumentVersion`) has the identical unguarded-mutable-field shape as the fixed `myIsRetrieved`/`myDocument`, but on the document-*reference* resolution path rather than save/close — not TSan-observed in any run (the repro doesn't exercise cross-document references), flagged as a plausible sibling for a future pass, not fixed here.

**Upstream formatting note:** OCCT's CI `clang-format` (invoked via their format-check workflow) disagreed with a locally-run `clang-format` (v22.1.8) on two spots — both formatter-alignment artifacts (`AlignConsecutiveAssignments`/declaration alignment shifting due to nearby edits), not intentional changes. Applied CI's own `format.patch` artifact to resolve; the version skew is a tooling quirk, not a real formatting defect. Worth checking CI's format-check output (not just a local dry-run) before every future upstream OCCT PR.

See [`Scripts/repro/353-cdm-metadata-lookup-table/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/353-cdm-metadata-lookup-table) for the reproducer and full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1396](https://github.com/Open-Cascade-SAS/OCCT/issues/1396) (repro) / [OCCT#1397](https://github.com/Open-Cascade-SAS/OCCT/pull/1397) (fix, CI green on all platforms).

**Retire** once the bundled OCCT includes this fix.
