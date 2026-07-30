# OCCTSwift#522 reproducer — `GeomConvert_ApproxSurface` at `GeomAbs_C0` collapses a direction and misreports its error

Standalone, deterministic reproducers for an upstream defect found while building #491's approximation
parity tests. Committed here rather than left in scratch because #491's own tests have to work around
it; the fix itself is #522's, not #491's.

**Not caused by #491.** Both surface approximation entry points
(`Surface.approximated` / `Surface.approxWithDetails`) hit this identically, before and after that
issue unified them, because both call the same OCCT class. Nothing about it is bridge-side.

Compile with the standard ground-truth invocation from `CLAUDE.md`:

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/522-approx-c0-collapse/occt_522_c0_minimal.mm -o /tmp/occt_522_c0
/tmp/occt_522_c0
```

No fixture file is needed — a plain `Geom_SphericalSurface` reproduces it.

## What happens

`occt_522_c0_minimal.mm` approximates a radius-10 sphere at tolerance `1e-3`, once per continuity, and
compares OCCT's reported `MaxError()` against the real maximum deviation over a 21x21 grid of the
source domain:

```
cont=C0  precis=0 isDone=1 hasResult=1 maxError=0.000106971  uDeg=1 vDeg=7 uPoles=2 vPoles=8
    fit domain U[0 6.28319] V[-1.5708 1.5708]   source U[0 6.28319] V[-1.5708 1.5708]
    real max deviation over the source domain: 19.9999  (at u=3.14159 v=0)
cont=C1  precis=0 isDone=1 hasResult=1 maxError=5.97449e-05  uDeg=8 vDeg=8 uPoles=16 vPoles=9
    real max deviation over the source domain: 1.68135e-05  (at u=3.45575 v=-0.314159)
cont=C2  precis=0 isDone=1 hasResult=1 maxError=0.000205606  uDeg=8 vDeg=8 uPoles=15 vPoles=9
    real max deviation over the source domain: 5.45774e-05  (at u=2.51327 v=0.314159)
```

At C0 the fit is 2 poles at degree 1 across the sphere's full `[0, 2*pi]` of longitude — a straight
line through the sphere, deviating by its own diameter — while `IsDone()` reports the tolerance met
and `MaxError()` reports `1.07e-4`. C1 and C2 on the identical surface are correct, and their reported
error bounds the real deviation as it should.

Both `PrecisCode` values do it, so it is unrelated to the knob #491 was about.

Reachable from the public Swift API through either entry point:

```swift
let sphere = Surface.sphere(center: .zero, radius: 10)!
let fit = sphere.approximated(tolerance: 1e-3, continuity: 0)!   // continuity: 0 == C0
// fit.uDegree == 1, fit.uPoleCount == 2; deviation from `sphere` is 19.9999

let detailed = sphere.approxWithDetails(tolerance: 1e-3, uContinuity: .c0, vContinuity: .c0)
// detailed.isDone == true, detailed.maxError == 0.000106971
```

## How wide it is

`occt_522_c0_sweep.mm` runs 98 requests — 7 surface families x all 9 `(uContinuity, vContinuity)`
combinations of C0/C1/C2 at tolerance `1e-3`, plus C0/C0 across five tolerances — and flags any whose
real deviation exceeds 10x the reported error. 12 of 98 misreport, and every one requests C0 in at
least one direction:

| surface | uCont | vCont | reported `maxError` | real deviation | result |
|---|---|---|---|---|---|
| sphere r=10 | C0 | C0 | 1.07e-4 | **19.9999** | degree 1x7, 2x8 poles |
| sphere r=10 | C1 | C0 | 1.60e-4 | **19.9999** | degree 3x8, 4x9 poles |
| sphere r=10 | C2 | C0 | 1.87e-4 | **7.66293** | degree 5x8, 6x9 poles |
| bicubic Bezier 4x4 | C0 | C0 | 4.08e-15 | **0.13824** | degree 1x1, 2x2 poles |

Two things narrow it further:

- **Degree collapse alone is not the bug.** A cylinder trimmed in V legitimately gets `vDegree = 1` —
  it *is* linear in V — and reports correctly. Collapsing where the input is not linear is the defect.
- **At C0/C0 the requested tolerance stops mattering.** The bicubic Bezier returns the identical 2x2
  bilinear patch with the identical `4.08e-15` reported error at every tolerance from `1e-1` down to
  `1e-7`. Tightening the tolerance changes nothing.

A full sphere is affected while the same sphere trimmed in V to `[-1, 1]` is not, which points at the
apex rows of the V parameterisation.

## Where to look

**Not root-caused.** These are the reproducers, not the diagnosis.
`GeomConvert_ApproxSurface::Approximate`
(`Libraries/occt-src/src/ModelingData/TKGeomBase/GeomConvert/GeomConvert_ApproxSurface.cxx:345-421`)
forwards the requested continuities into `AdvApp2Var_ApproxAFunc2Var` as `theUContinuity` /
`theVContinuity`, which become `AdvApp2Var_Context`'s `iu` / `iv` constraint orders. Those feed
`lesparam` (`AdvApp2Var_Context.cxx:22-76`), which derives the Jacobi degree and the initial per-axis
sample count, and `hMaxFactor` (`AdvApp2Var_Context.cxx:104`), which special-cases orders 0 and -1.

`myMaxError` is read back from `approx.MaxError(3, 1)` — i.e. from
`AdvApp2Var_ApproxAFunc2Var::my3DMaxError`, accumulated per patch during the iso-curve fit
(`AdvApp2Var_ApproxAFunc2Var.cxx:845-865`) rather than measured against the surface `ConvertBS` finally
builds. That gap is the plausible reason a degree-1 collapse can still report a tiny error, but it has
not been confirmed.

Worth establishing whether the returned surface is wrong, the reported error is wrong, or both, before
choosing between a kernel patch (this project carries `Scripts/patches/0001`-`0017`) and a bridge-side
rejection of the C0 request.

## Interaction with #491

`Tests/OCCTSurfaceTests/Issue491SurfaceApproxParityTests.swift` keeps `.c0` in its request set — both
entry points must return the *same* surface for the same request, and after #491 they do, garbage
included. Only its `maxErrorDescribesTheSharedFit` test excludes `.c0`, because asserting "sampled
deviation <= reported `maxError`" fails on OCCT's own numbers there. That exclusion carries a comment
pointing here and should be dropped when this is fixed.
