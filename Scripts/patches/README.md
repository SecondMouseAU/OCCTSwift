# Carried OCCT source patches

Patches in this directory are upstream-bound OCCT bug fixes we carry until they ship in an OCCT
release. `Scripts/build-occt.sh` applies each one (idempotently, `-p1`, `a/`,`b/` prefixes) to
`Libraries/occt-src` before every cmake build. A patch takes effect only when the xcframework is
**rebuilt** from source — the binary shipped in `Libraries/OCCT.xcframework` does not yet include it
until a rebuild + release.

## 0001-ShapeFix_Face-guard-non-face-context-replacement-263.patch

**Fixes the upstream OCCT crash behind [#263](https://github.com/SecondMouseAU/OCCTSwift/issues/263)**
(reported upstream as [Open-Cascade-SAS/OCCT#1322](https://github.com/Open-Cascade-SAS/OCCT/issues/1322)).

`ShapeFix_Face::Perform` casts `Context()->Apply(myFace)` with `TopoDS::Face(S.EmptyCopied())` in
three places, none of which check the type. When an earlier fix sharing the same `ShapeBuild_ReShape`
context has replaced the face with a **compound** (e.g. a self-intersecting face split into several
faces), `Apply()` returns a non-face. The unchecked cast then builds an invalid `TopoDS_Face` handle
over a compound `TShape`; subsequent topology operations corrupt the heap and abort the process with
an uncatchable OS signal (`ShapeFix_Face::FixOrientation` → `BRep_Tool::Curve` → `BRep_TEdge::EmptyCopy`,
SIGSEGV/SIGBUS at varying addresses).

The compound replacement already exists on entry to `Perform` (it was recorded by a prior face's
fix), so the patch adds a single guard at the top of `Perform`: if `Context()->Apply(myFace)` is not
a face, record it as the result and return — the replacement is already in the context, so there is
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

**Validation:** the isolated pure-C++ repro (`fuse` two/three prisms → fillet the seam, 8 threads) returns BRepCheck-invalid solids across several wrong volumes on stock p1, and 0/1600 invalid with a single correct volume after the patch. ThreadSanitizer reports the `STATIC_SOLIDINDEX` and `BlendFunc` scratch races on stock p1 and is clean on the fillet path after the patch (only an unrelated benign `BOPAlgo_InitMessages` lazy-init race remains, in the boolean path — orthogonal). While this patch is carried, the in-wrapper `occtFilletMutex` shipped in v1.12.1 serialises fillet/chamfer builds so the corruption cannot reach consumers.

**Retire** once the bundled OCCT includes these `thread_local` conversions (upstream PR pending), at which point the `occtFilletMutex` guard can also be dropped.
