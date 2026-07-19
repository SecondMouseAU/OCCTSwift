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
