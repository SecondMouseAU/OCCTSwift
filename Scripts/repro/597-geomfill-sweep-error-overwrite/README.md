# OCCTSwift #597 (kernel half): `GeomFill_Sweep.cxx:325` overwrites the measured error with the requested tolerance

The bridge half of #597 is closed out by PR #751 (both obvious bridge-side fixes were built and
broke real tests; see that PR and the issue's own comments). What's left is the kernel defect the
issue's own re-scoping comment names:

```cpp
GeomConvert_ApproxSurface
  ConvertApprox(mySurface, theTol, theUCont, theVCont, degU, degV, nmax, thePrec);
if (ConvertApprox.HasResult())
{
  mySurface = ConvertApprox.Surface();
  ...
  SError = theTol;   // <-- GeomFill_Sweep.cxx:325. theTol is 1.e-4, a literal a few lines up.
}
```

`SError` backs `GeomFill_Sweep::ErrorOnSurface()`, which `BRepFill_Sweep`/`BRepFill_PipeShell`/
`BRepOffsetAPI_MakePipeShell` all forward verbatim (traced in the PR body). Whatever
`GeomConvert_ApproxSurface` actually achieved is discarded in favour of the tolerance it was asked
to hit. `ConvertApprox.MaxError()` sits right there, unread.

## Getting a repro to fire at all is the hard part

`myForceApproxC1`'s branch only runs when the **swept surface itself** fails `IsCNv(1)`, not C1
across the spine's own parameter. `BRepFill_Sweep` splits the sweep at every spine **vertex**, so a
polyline or multi-edge spine never reaches this code: each edge gets its own clean `GeomFill_Sweep`
call and none of them needs the C1-forcing patch-up. The discontinuity has to sit **inside** a
single, unsplit edge.

The fixture that does this (found by #572, pinned by
`Tests/OCCTModelingTests/Issue572SweepApproxTests.swift`) is a single-edge spine built as ONE
degree-2 B-spline curve with an **interior knot of multiplicity 2**, a C0 corner in the middle of
what `BRepFill_Sweep` treats as one edge:

```cpp
// poles: (0,0,0) (0,0,4) (0,0,8) (4,0,11) (9,0,13)
// knots: [0, 0.5, 1], mults: [3, 2, 3], degree 2
```

Plus a unit circle profile and Frenet trihedron, built through `BRepFill_PipeShell` exactly as the
bridge does it (`OCCTPipeShellCreate` / `SetFrenet` / `SetForceApproxC1` / `Add` /
`SetIsBuildHistory(false)` / `Build`). This is the **only** OCCTSwift-reachable input #572's own
probe found that fires this branch (`GeomFill_Sweep.cxx:296` in its reachability table).

## What the harness measures, and why each step is there

`occt_597_sweep_error.mm` answers the three things worth checking before trusting the "obvious fix"
(`SError = ConvertApprox.MaxError();`):

1. **Does the stock kernel really hardcode `1e-4`?** Build with `ForceApproxC1(true)` and read
   `ErrorOnSurface()`. Yes: `0.0001`, to the printed digit, regardless of the real fit.

2. **Is `MaxError()` measuring the same thing, against the same reference, that `SError` meant
   before the branch?** This is the trap #571 fell into: `GeomPlate_MakeApprox::ApproxError()`
   measured fidelity to an *intermediate* `GeomPlate_Surface`, not the caller's actual input, and
   gating on it broke 6/6 real tests. Here the check is more direct: `GeomConvert_ApproxSurface`'s
   `Surf` constructor argument at `GeomFill_Sweep.cxx:296` **is** `mySurface`, the pre-conversion
   swept surface, so there is no third, unrelated object in play the way there was for
   `GeomPlate_MakeApprox`. The harness confirms this isn't just a reading of the header: it
   reconstructs the exact same `GeomConvert_ApproxSurface(unforcedSurface, 1e-4, C1, C1, 14, 14, 16,
   1)` call from *outside* the kernel, using the surface obtained from a separate `ForceApproxC1(false)`
   build (which never reaches this branch, so its `ErrorOnSurface()` is untouched by #597 and its
   returned surface is exactly what `mySurface` holds at the moment the real `ConvertApprox`
   constructor runs). The reconstructed call's output surface has the same degree/pole counts as the
   real forced build's output, and measuring deviation from the same unforced-surface baseline to
   each gives **bit-identical** numbers both ways: this is the real call, not a divergent
   simulation.

3. **Does `MaxError()` actually move, now that patch `0019` (#522) repaired the AdvApp2Var
   workspace-slot bug?** Before `0019`, every interior truncation error the approximator computed
   was structurally zero, so `MaxError()` could not report a large number no matter how bad the fit
   was; #522's own writeup measured a `MaxError()` five orders of magnitude too small for exactly
   this reason. Confirmed here against the currently pinned kernel (`v2.0.0-kernel.1`, patches
   0010-0012/0014-0021 baked in): `MaxError() = 2.54714`, matching #572's own independent measurement
   of this identical fixture (`2.547`, in `Scripts/repro/572-approx-consumer-sweep/sweep-fixed.txt`)
   to the printed precision. It moves.

Finally, two independent geometric deviations (unforced surface to forced surface), because
`MaxError()`'s own report needs a second construction to be trusted, not just read off:

- **paramDev**: same normalised `(u, v)` on both surfaces. This is what an approximator's own error
  model is actually judged against: samples at corresponding parameters, not nearest points.
- **projDev**: nearest point on the fit to each sampled source point (`GeomAPI_ProjectPointOnSurf`).
  Independent of parameterisation, so it measures the shape and nothing else.

## Results (against the currently pinned kernel, `v2.0.0-kernel.1`)

| quantity | value |
|---|---|
| stock `SError` (`ErrorOnSurface()`, forced build) | `0.0001` (exactly `theTol`) |
| `ConvertApprox.MaxError()` (= fixed `SError`) | `2.54714` |
| real deviation, paramDev (40x40 grid) | `1.77238` |
| real deviation, projDev (40x40 grid) | `0.353289` |
| `MaxError()` / paramDev | `1.437` |
| `MaxError()` / projDev | `7.21` |

`MaxError()` is closer to `paramDev` (1.4x) than to `projDev` (7.2x), which is the expected
relationship: an approximation algorithm's own internal error model compares points at
corresponding parameters (what `paramDev` measures), not nearest-point distances, and it can find a
worse parameter location with its own internal sampling/quadrature than an external 40x40 grid does.
`MaxError()` is not an arbitrary or wrong-reference number: it is in the right family, against the
right object, and larger than a coarse external grid finds, which is the conservative direction to
be wrong in for a diagnostic.

(Sampling denser than #572's original 20x20 grid finds a worse point: `projDev` here is `0.353`
against #572's own `0.176` at 20x20. This does not affect
`Issue572SweepApproxTests.forcedC1CoversTheUnforcedSweep`, which uses its own 20x20 measurement
independent of this patch and asserts `< 0.25`; the shape it measures is completely unchanged by
this fix, see "Does the shape change?" below.)

## Does the shape change?

No. `diff sweep-stock.txt sweep-patched.txt` (the override-linked before/after) differs on exactly
two lines, both `ErrorOnSurface()` reads: `0.0001` becomes `2.54714`. Every geometry line (degree,
pole counts, knot counts, both deviation measurements) is byte-identical. This patch only changes
what the class *reports*; `mySurface` itself was already `ConvertApprox.Surface()` before this line
runs (line 300), so no consumer's returned shape moves.

## Consumer survey: does anything gate on this number today?

- `PipeShellBuilder.errorOnSurface` (`Sources/OCCTSwift/PipeShellBuilder.swift`, backed by
  `OCCTPipeShellErrorOnSurface`/`OCCTPipeShellError` in `OCCTBridge_Modeling.mm`) exposes the value
  as **info only**: nothing in the bridge compares it against a tolerance and rejects. The only
  test that reads it (`PipeShellExtensionTests.pipeShellErrorAndShapes`,
  `Tests/OCCTSurfaceTests/OCCTSurfaceTests.swift`) asserts `err >= 0`, not a specific value.
- `OCCTGeomFillSweep` (`OCCTBridge_Surface.mm`, fixed for the *other* half of #597 in PR #741, which
  added `if (sweep.ErrorOnSurface() > tolerance) return nullptr;`) never calls
  `SetForceApproxC1(true)`, so it never reaches the branch this patch touches; its
  `ErrorOnSurface()` is `Approx.MaxErrorOnSurf()` (line 286), untouched by #597. Confirmed by
  reading the source, not assumed: `myForceApproxC1` defaults to `false`
  (`GeomFill_Sweep.cxx:112`) and nothing in `OCCTGeomFillSweep` sets it.

So this fix cannot regress `OCCTGeomFillSweep`'s existing gate (different code path entirely) and
cannot regress `PipeShellBuilder` (nothing gates on the number, only reports it). No existing test
asserts a specific numeric value for `errorOnSurface` on the `ForceApproxC1(true)` path.

## Files

| file | what it is |
|---|---|
| `occt_597_sweep_error.mm` | the harness: builds unforced + forced, reconstructs the internal `GeomConvert_ApproxSurface` call externally, measures paramDev/projDev, equivalence-checks the reconstruction against the real build |
| `sweep-stock.txt` | harness output against the stock (unpatched) kernel |
| `sweep-patched.txt` | harness output with `0025` override-linked ahead of the archive |
| `draft-pr.md` | drafted, unsent upstream PR body |

## Building it

Plain run, against whatever `Libraries/OCCT.xcframework` currently holds:

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/597-geomfill-sweep-error-overwrite/occt_597_sweep_error.mm -o /tmp/occt_597
/tmp/occt_597
```

Override-link validation (compile the patched `.cxx` standalone at `-O0 -DNDEBUG -DNo_Exception`,
matching the production build flags, per the `0018`/`0019` entries in `Scripts/patches/README.md`,
and link it ahead of the archive so it overrides `GeomFill_Sweep`'s symbols):

```bash
cp Libraries/occt-src/src/ModelingAlgorithms/TKGeomAlgo/GeomFill/GeomFill_Sweep.cxx /tmp/GeomFill_Sweep_fixed.cxx
# apply Scripts/patches/0025-*.patch to /tmp/GeomFill_Sweep_fixed.cxx, or hand-edit line 325 to:
#   SError = ConvertApprox.MaxError();

clang++ -c -std=gnu++17 -O0 -g -w -DNDEBUG -DNo_Exception -DOCC_CONVERT_SIGNALS \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  /tmp/GeomFill_Sweep_fixed.cxx -o /tmp/GeomFill_Sweep_fixed.o

clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  Scripts/repro/597-geomfill-sweep-error-overwrite/occt_597_sweep_error.mm \
  /tmp/GeomFill_Sweep_fixed.o \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  -o /tmp/occt_597_patched
/tmp/occt_597_patched
```

No full xcframework rebuild was done for this patch (consistent with `0022`/`0023`/`0024`'s
"override-link only" validation, since a full rebuild is a separate, expensive, and already
independently-tracked step; see "Pin status" below).

## Pin status

As of this patch, `Package.swift` pins `v2.0.0-kernel.1`, which carries eleven patches
(`0010`-`0012`, `0014`-`0021`). `0022`, `0023`, `0024` are already carried in the tree but outside
that binary (see `Scripts/patches/README.md`'s "Pin consequence" notes); this patch, `0025`, makes
four. PR #754 (`chore/512-repin-kernel-2`, open at the time of writing) re-pins to
`v2.0.0-kernel.2`, folding in all fourteen (`0010`-`0012`, `0014`-`0024`); once that merges, `0025`
becomes the only patch left outside the pin, which is exactly the gap
`docs/v2.0.0-plan.md`'s RESOLVED block already names by number: "`0025` (#597) is already in flight
and will reopen it."
