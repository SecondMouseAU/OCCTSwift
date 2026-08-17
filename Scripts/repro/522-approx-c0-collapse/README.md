# OCCTSwift#522 reproducer: `mma2ce1_` fills the U Jacobi-maxima buffer from the V slot, so every U truncation error evaluates to zero

Standalone, deterministic reproducers for an upstream defect found while building #491's approximation
parity tests. Committed here rather than left in scratch because #491's own tests had to work around
it; the fix itself is #522's, not #491's.

**Not caused by #491.** Both surface approximation entry points
(`Surface.approximated` / `Surface.approxWithDetails`) hit this identically, before and after that
issue unified them, because both call the same OCCT class. Nothing about it is bridge-side.

**Fixed** in `Scripts/patches/0019-AdvApp2Var-jacobi-max-wrong-workspace-slot-522.patch`, filed upstream as
[OCCT#1418](https://github.com/Open-Cascade-SAS/OCCT/pull/1418).
`sweep-before.txt` and `sweep-after.txt` are the full 98-case transcripts either side of it.

Compile with the standard ground-truth invocation from `CLAUDE.md`:

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/522-approx-c0-collapse/occt_522_c0_minimal.mm -o /tmp/occt_522_c0
/tmp/occt_522_c0
```

No fixture file is needed; a plain `Geom_SphericalSurface` reproduces it.

## Root cause

`AdvApp2Var_ApproxF2var::mma2ce1_` (`AdvApp2Var_ApproxF2var.cxx:3719`) requests one scratch
allocation and partitions it into seven consecutive buffers, `ipt4` holding `XMAXJU` (the maxima of
the U Jacobi polynomials) and `ipt5` holding `XMAXJV` (the V ones). Both `mma2jmx_` calls that fill
them target `ipt5`:

```c
AdvApp2Var_ApproxF2var::mma2jmx_(ndjacu, iordru, &wrkar_off[ipt5]);   /* -> should be ipt4 */
AdvApp2Var_ApproxF2var::mma2jmx_(ndjacv, iordrv, &wrkar_off[ipt5]);
```

so `XMAXJU` is never written. `mma2ce2_` still reads it at `ipt4`, where the allocation left whatever
was there (in practice zeros) and hands it to `mma2er1_`/`mma2er2_`, whose whole error model is

```
error += |PATJAC(i,j)| * XMAXJU(i - 2*(IORDRU+1)) * XMAXJV(j - 2*(IORDRV+1))
```

A zero `XMAXJU` zeroes every term. Two consequences, both silent:

1. **The interior approximation error of a patch is always exactly 0**, whatever the discarded
   Jacobi coefficients are. `mma2ce2_`'s tolerance test (`if (errmax[nd] > epsapr[nd])`) can never
   fire on it, and what `AdvApp2Var_ApproxAFunc2Var::MaxError` ends up reporting is only the
   boundary-iso error that `AdvApp2Var_Patch::AddErrors` adds afterwards.
2. **`mma2er2_`, asked for the lowest degree whose truncation error still fits the tolerance, always
   answers `NDMINU`** (the floor derived from the constraint order and the neighbouring isos),
   because every candidate scores 0.

Where that floor happens to be low, the fit collapses onto it. `GeomAbs_C0` gives `IORDRU = 0`, and a
full sphere's V-boundary isos degenerate to its two poles, one coefficient each, so `NDMINU` is 1 and
the fit comes back at degree 1. C1 and C2 hide the collapse (their floor is already 8) but not the
misreported error, which is why every reported error in `sweep-after.txt` is slightly larger than in
`sweep-before.txt`: the interior contribution is being counted for the first time.

The write is also out of bounds for the buffer it was given: `mma2jmx_` writes
`ndjacu + 1 - 2*(IORDRU+1)` doubles and the `ipt5` slot is sized for the `ndjacv` equivalent, so a
request with `MaxDegU` well above `MaxDegV` runs past `XMAXJV` into the `VECERR` slot behind it. That
part is benign in practice, since `VECERR` is re-zeroed on entry to `mma2ce2_` and the run stays
inside the single allocation, but it is still a write past the end of its buffer.

### Confirming the mechanism

An `-O0` single-TU override-link (the technique from #310/#348) prints the buffer directly. Copy
`Libraries/occt-src/src/ModelingData/TKGeomBase/AdvApp2Var/AdvApp2Var_ApproxF2var.cxx`, add a dump of
`&wrkar_off[ipt4]` and `&wrkar_off[ipt5]` after the two `mma2jmx_` calls, compile it standalone and
link the `.o` **before** `-lOCCT-macos`:

```bash
clang++ -c -std=gnu++17 -O0 -g -w -DNDEBUG -DNo_Exception -DOCC_CONVERT_SIGNALS \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -I"Libraries/occt-src/src/ModelingData/TKGeomBase/AdvApp2Var" \
  /tmp/AdvApp2Var_ApproxF2var.cxx -o /tmp/f2var.o
```

Stock, `XMAXJU` is all zeros; with `ipt5` corrected to `ipt4` it holds the real maxima:

```
stock:  xmaxju[8] = 0 0 0 0 0 0 0 0
fixed:  xmaxju[8] = 0.9682 0.986 1.078 1.173 1.265 1.352 1.434 1.513
```

`-DNo_Exception` matters: the production kernel is built with it
(`BUILD_RELEASE_DISABLE_EXCEPTIONS=ON`), and an override TU compiled without it reintroduces
`*_Raise_if` preconditions that the shipped kernel does not have.

## What happens

`occt_522_c0_minimal.mm` approximates a radius-10 sphere at tolerance `1e-3`, once per continuity, and
compares OCCT's reported `MaxError()` against the real maximum deviation over a 21x21 grid of the
source domain. Before the fix:

```
cont=C0  precis=0 isDone=1 hasResult=1 maxError=0.000106971  uDeg=1 vDeg=7 uPoles=2 vPoles=8
    fit domain U[0 6.28319] V[-1.5708 1.5708]   source U[0 6.28319] V[-1.5708 1.5708]
    real max deviation over the source domain: 19.9999  (at u=3.14159 v=0)
cont=C1  precis=0 isDone=1 hasResult=1 maxError=5.97449e-05  uDeg=8 vDeg=8 uPoles=16 vPoles=9
    real max deviation over the source domain: 1.68135e-05  (at u=3.45575 v=-0.314159)
cont=C2  precis=0 isDone=1 hasResult=1 maxError=0.000205606  uDeg=8 vDeg=8 uPoles=15 vPoles=9
    real max deviation over the source domain: 5.45774e-05  (at u=2.51327 v=0.314159)
```

At C0 the fit was 2 poles at degree 1 across the sphere's full `[0, 2*pi]` of longitude, a straight
line through the sphere deviating by its own diameter, while `IsDone()` reported the tolerance met
and `MaxError()` reported `1.07e-4`. After the fix the same request returns degree 7x7, 15x8 poles,
`maxError` 2.61e-4 and a real deviation of 1.21e-4:

```
cont=C0  precis=0 isDone=1 hasResult=1 maxError=0.000261108  uDeg=7 vDeg=7 uPoles=15 vPoles=8
    real max deviation over the source domain: 0.000120909  (at u=1.5708 v=0)
```

Both `PrecisCode` values did it, so it was unrelated to the knob #491 was about.

Reachable from the public Swift API through either entry point:

```swift
let sphere = Surface.sphere(center: .zero, radius: 10)!
let fit = sphere.approximated(tolerance: 1e-3, continuity: 0)!   // continuity: 0 == C0
// before: fit.uDegree == 1, fit.uPoleCount == 2; deviation from `sphere` is 19.9999
// after:  fit.uDegree == 7, fit.uPoleCount == 15; deviation 1.21e-4

let detailed = sphere.approxWithDetails(tolerance: 1e-3, uContinuity: .c0, vContinuity: .c0)
// before: detailed.isDone == true, detailed.maxError == 0.000106971
// after:  detailed.isDone == true, detailed.maxError == 0.000261108
```

## How wide it was

`occt_522_c0_sweep.mm` runs 98 requests (7 surface families x all 9 `(uContinuity, vContinuity)`
combinations of C0/C1/C2 at tolerance `1e-3`, plus C0/C0 across five tolerances) and flags any whose
real deviation exceeds 10x the reported error. Full transcripts in `sweep-before.txt` /
`sweep-after.txt`.

| | before | after |
|---|---|---|
| real deviation > 10x reported `maxError` | **12 of 98** | **0 of 98** |
| real deviation > reported `maxError` at all | **17 of 98** | 1 of 98 |
| worst ratio of real deviation to reported error | **3.4e13** | 1.0018 |

The one row still over the line after the fix is the Bezier at `C0/C2`, reported `9.95221e-15`
against a measured `9.96978e-15`: a surface reproduced exactly, disagreeing at the last bit.

Every one of the 12 requested C0 in at least one direction:

| surface | uCont | vCont | reported `maxError` | real deviation | result |
|---|---|---|---|---|---|
| sphere r=10 | C0 | C0 | 1.07e-4 | **19.9999** | degree 1x7, 2x8 poles |
| sphere r=10 | C1 | C0 | 1.60e-4 | **19.9999** | degree 3x8, 4x9 poles |
| sphere r=10 | C2 | C0 | 1.87e-4 | **7.66293** | degree 5x8, 6x9 poles |
| bicubic Bezier 4x4 | C0 | C0 | 4.08e-15 | **0.13824** | degree 1x1, 2x2 poles |

Two observations from the original investigation, both explained by the root cause above:

- **Degree collapse alone was not the bug.** A cylinder trimmed in V legitimately gets `vDegree = 1`,
  it *is* linear in V, and reported correctly, before and after. Collapsing where the input is not
  linear was the defect: `NDMINU` is the floor the search falls back to, and it is low exactly where
  the boundary constraints carry no information.
- **At C0/C0 the requested tolerance stopped mattering.** The bicubic Bezier returned the identical
  2x2 bilinear patch with the identical `4.08e-15` reported error at every tolerance from `1e-1` down
  to `1e-7`, because the number the tolerance was compared against was always zero. After the fix it
  is reproduced exactly at degree 3x3, 4x4 poles, at every one of those tolerances.

A full sphere was affected while the same sphere trimmed in V to `[-1, 1]` was not, because trimming
away the poles gives the V-boundary isos real content and raises `NDMINU` out of the collapse.

## Blast radius inside the kernel

`GeomConvert_ApproxSurface` is not a leaf. Live construction sites, with the `PrecisCode` each
passes:

| site | `PrecisCode` | continuity requested |
|---|---|---|
| `GeomFill_Sweep.cxx:296` | 1 | caller's |
| `BRepOffset_Offset.cxx:1626` | 1 | caller's `Conti` |
| `ShapeCustom_BSplineRestriction.cxx:852` | 0 | caller's, **degraded on failure** |
| `ShapeConstruct.cxx:265` | 0 | caller's, **looped down to 0 on failure** |
| `ShapeUpgrade_UnifySameDomain.cxx:3629` | 1 | caller's |
| `GeomLib.cxx:1517` | caller's | caller's |
| `GeomConvert_1.cxx:786`, `:960` | 1 | caller's |

`GeomPlate_MakeApprox` drives `AdvApp2Var_ApproxAFunc2Var` directly rather than through
`GeomConvert_ApproxSurface`, defaulting to `GeomAbs_C1`, so it took the always-zero interior error
without being on this list at all.

Most of these pass C1 or C2, where the collapse cannot happen, but the always-zero interior error
affected all of them. The healing paths reach C0 on purpose: `ShapeConstruct::ConvertSurfaceToBSpline`
loops the requested continuity down to 0 on failure and `ShapeCustom_BSplineRestriction` degrades it
the same way, both then deciding whether to accept the result with `anApprox.MaxError() <= tol`, i.e.
against the number that could not be exceeded. `ShapeCustom_ConvertToBSpline` does not construct one
itself: it calls `ShapeConstruct::ConvertSurfaceToBSpline`, and **forces `cnt = GeomAbs_C0` for any
offset surface** (`ShapeCustom_ConvertToBSpline.cxx:148`, a 1999 workaround for a hang), so that path
started at the collapsing continuity rather than degrading into it.

**Two mentions are not callers.** `BRepFill_Sweep.cxx:1162` sits inside a `/* */` block spanning
`:1064`-`:1179`, and `BRepFill_Filling.cxx:712` is a `//`-commented line. A filename-level grep counts
both; neither is compiled. `Sources/OCCTBridge/src/OCCTBridge_Surface.mm`'s `PrecisCode` census used
to cite the `BRepFill_Sweep` one as a live site, corrected in #573.

What each consumer inherited is tracked separately: #570 (the healing paths that decide on
`MaxError() <= tol`, including the forced-C0 offset-surface branch), #571 (`GeomPlate_MakeApprox`)
and #572 (the C1/C2 consumers).

## Interaction with #491

`Tests/OCCTSurfaceTests/Issue491SurfaceApproxParityTests.swift` always kept `.c0` in its request set:
both entry points must return the *same* surface for the same request, and after #491 they did,
garbage included. Its `maxErrorDescribesTheSharedFit` test used to exclude `.c0`, because asserting
"sampled deviation <= reported `maxError`" failed on OCCT's own numbers there. That exclusion is gone;
the test now checks every request. `Tests/OCCTSurfaceTests/Issue522ApproxC0CollapseTests.swift`
carries the regression tests for this issue, all four of which fail against an unpatched kernel with
exactly the numbers tabulated above.

## Upstream provenance (#756)

Maintainer gkv311's review on [OCCT#1418](https://github.com/Open-Cascade-SAS/OCCT/pull/1418)
attributed the defect to `3016a390713d2e893f4bfa797882b9f0266840e1` (2021-07-28, a UBSan coding-rules
cleanup) and asked for the 7.5.x behaviour to be confirmed by measurement rather than asserted. Done,
against a disposable shallow clone of `Open-Cascade-SAS/OCCT` rather than this project's own
`Libraries/occt-src` (left untouched). Leaving `occt-src` alone was right and still is; the
disposable clone is what has since been replaced, by the persistent fork checkout in
[§0 of the upstream patch process](../../../okf/policies/upstream-occt-patch-process.md#0-where-the-work-happens-one-persistent-checkout-of-the-fork)
(#803), which answers the same question without cloning anything.

That commit rebases every workspace offset in `mma2ce1_` down by one position (folding the old
`ipt1` base into a new `wrkar_off` pointer), and every other call site in the same diff moves with
it, for instance the neighbouring `mmapptt_` calls going from `&wrkar[ipt1]`/`&wrkar[ipt2]` to
`wrkar_off`/`&wrkar_off[ipt1]`. The two `mma2jmx_` calls should have become `&wrkar_off[ipt4]` (U)
and `&wrkar_off[ipt5]` (V); the V line moved, the U line kept its old name (`ipt5`), and both writes
land on the slot V already owns. Confirmed at the release-tag level, not just the commit's own diff:

```
V7_5_0 (2020-11-02): mma2jmx_(ndjacu, iordru, &wrkar[ipt5]);   mma2jmx_(ndjacv, iordrv, &wrkar[ipt6]);
V7_6_0 (2021-11-01): mma2jmx_(ndjacu, iordru, &wrkar_off[ipt5]); mma2jmx_(ndjacv, iordrv, &wrkar_off[ipt5]);
```

`V7_5_0` has two distinct slots; `V7_6_0`, the first release carrying the commit, already collapses
them to one, and current `master` is unchanged from `V7_6_0` at this site. So OCCT 7.5.x computed
this correctly, and the regression is confirmed at the shipped 7.6.0 release rather than merely
attributed to a commit in that range.

The review also supplied a Draw script with its assertion block commented out, asking for the
`udeg`/`vdeg` == 7 guess to be measured rather than trusted, and for a real `tests/` case. Both are
done: `Scripts/repro/522-approx-c0-collapse/upstream/tests/bugs/moddata_3/bug1418` is that case,
staged rather than committed to `Libraries/occt-src`. This project only builds a static library, not
`DRAWEXE`, so the script itself was not run; the discriminating measurement instead came from this
directory's own `occt_522_c0_minimal.mm`, reusing the exact `GeomConvert_ApproxSurface` constructor
call `approxsurf` makes (confirmed against `GeomliteTest_SurfaceCommands.cxx`, including that
`approxsurf`'s 9-argument form leaves `PrecisCode` at its default of 1, not the 0 this directory's
existing probes used). Both `PrecisCode` values agree: `udeg=1, vdeg=7` before the fix, `udeg=7,
vdeg=7` after. The reviewer's guessed 7/7 is correct.

The commented-out assertion block itself does not run as written, for two independent reasons that
have nothing to do with the degree values: `dumpjson` is not a registered Draw command anywhere in
this tree, and `Standard_Dump::DumpFieldToName` strips the `my` prefix from `myUDeg`/`myVDeg` but
does not change case, so the real `DumpJson` keys are `"UDeg"`/`"VDeg"`, not `"udeg"`/`"vdeg"`.
Either problem alone leaves the Tcl variable unset. The staged test instead captures `dump r`'s
existing textual output through `dlog` and reads the `Degrees :` line
`GeomTools_SurfaceSet::PrintSurface` writes for a `Geom_BSplineSurface`. `tests/bugs/modalg_7/bug23942`
uses the same `dlog`/`dump` capture for the same purpose, though not the same regex: it captures the
U degree into a throwaway and stores V in a variable it calls `Degrees_1`, a quirk the staged test
deliberately does not copy.

### None of that staging was ever sent (#803)

`upstream/` holds three artifacts prepared for a reply that never happened: the rewritten PR
description leading with the missed decrement (`pr-1418-description.md`), the reply itself
(`reply-to-gkv311.md`), and the Draw test (`tests/bugs/moddata_3/bug1418`). All three were held at
prepare-and-stop, and **dpasukhi merged OCCT#1418 on 2026-08-10 without any of them**, with "Thank you
for the patch!". The merged PR touches exactly one file, `AdvApp2Var_ApproxF2var.cxx`, 1 insertion and
1 deletion, and its description is still the behavioural writeup filed first.

So the provenance above is the surviving record of that measurement, and the three files carry status
headers saying so. Nothing is owed upstream on #1418. Contributing the Draw test would now be a fresh
PR against a merged fix, which is a decision nobody has taken.
