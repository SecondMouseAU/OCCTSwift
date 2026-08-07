# Draft upstream PR for patch `0025` (`GeomFill_Sweep::BuildAll` reports the requested tolerance, not the achieved error)

**Status: drafted, not sent.** This task's hard constraint forbids opening, editing, pushing to, or
commenting on anything in `Open-Cascade-SAS/OCCT` or any fork of it. Everything below is text a
human can paste into a new PR against that repository's `master` branch in one sitting.

Per `okf/policies/upstream-occt-style.md` and the precedent of `0018`/`0019`/`0021`/`0024`: **no
companion issue, go straight to the PR.**

The diff is `Scripts/patches/0025-GeomFill_Sweep-report-achieved-conversion-error-597.patch`,
already `clang-format`-clean against OCCT's own root `.clang-format`, and confirmed to apply to
current upstream `master` (`b8f597c6`, "Coding - Bump version to 8.0.1 (#1412)") with zero rejected
hunks; the touched file is byte-identical between our `V8_0_1` pin and that `master` commit.

Branch to open the PR from: apply `Scripts/patches/0025-*.patch` to a clean checkout of
`Open-Cascade-SAS/OCCT` `master` (`git apply -p1`) and push that as the PR branch.

---

## Title

```
ModelingAlgorithms - GeomFill_Sweep::BuildAll reports the requested tolerance instead of the achieved C1-conversion error
```

## Body

`GeomFill_Sweep::BuildAll` computes the real approximation error of the swept surface:

```cpp
SError = Approx.MaxErrorOnSurf();
```

When the caller has requested `ForceApproxC1` and the swept surface isn't already C1 in V, it then
re-approximates through `GeomConvert_ApproxSurface`:

```cpp
if (myForceApproxC1 && !mySurface->IsCNv(1))
{
  double theTol = 1.e-4;
  ...
  GeomConvert_ApproxSurface
    ConvertApprox(mySurface, theTol, theUCont, theVCont, degU, degV, nmax, thePrec);
  if (ConvertApprox.HasResult())
  {
    mySurface = ConvertApprox.Surface();
    ...
    SError = theTol;   // <-- overwrites the measured error with the requested tolerance
  }
}
```

`GeomConvert_ApproxSurface::HasResult()` is documented as true even for "a result that is not
NECESSARILY within the required tolerance." `MaxError()` reports what the conversion actually
achieved and is never read here: the caller-visible `ErrorOnSurface()` reports `1e-4` whenever this
branch runs and produces a result, whether the conversion landed at `1e-4`, `1e-2`, or `2.5`.

`BRepFill_Sweep`/`BRepFill_PipeShell`/`BRepOffsetAPI_MakePipeShell::ErrorOnSurface()` all forward
this value verbatim, so `BRepOffsetAPI_MakePipeShell::SetForceApproxC1(true)`, a documented,
public API, not an internal-only path, hands every caller a number that describes the request, not
the result.

### Reproducer

A pipe shell whose spine is a single degree-2 B-spline edge with an interior knot of multiplicity 2
(a C0 tangent corner inside one edge, needed because the sweep is split at spine *vertices*, not
at interior parameter discontinuities, so a polyline spine never reaches this branch) and a circular
profile:

```cpp
BRepFill_PipeShell ps(spine);      // spine: 5-pole degree-2 BSpline, knots [0,0.5,1], mults [3,2,3]
ps.Set(Standard_True);             // Frenet
ps.SetForceApproxC1(Standard_True);
ps.Add(circleProfile);             // unit circle, axis (0,0,1)
ps.Build();
ps.ErrorOnSurface();               // 0.0001, exactly theTol, regardless of the real fit
```

Reconstructing the exact same `GeomConvert_ApproxSurface` call this branch makes (same input
surface, same tolerance, continuities, degrees, segment cap and precision code) from outside the
class and reading its own `MaxError()` gives `2.54714`, 25000x the reported value. Sampling both
surfaces on a grid and measuring two independent deviations confirms `2.54714` is the right order of
magnitude, not a stray number: the same-parameter deviation (what an approximator's own error model
is judged against) measures `1.77`, and the nearest-point deviation (independent of
parameterisation) measures `0.35`. Both are enormously larger than the `1e-4` this class reports
having achieved.

## Fix

Read what the conversion actually achieved instead of restating what it was asked for:

```cpp
SError = ConvertApprox.MaxError();
```

One line. No other change: `CError`'s four entries a few lines above are left as the literal `0.`
they already were (a separate, pre-existing gap: no 2D curve error is available from
`GeomConvert_ApproxSurface` at this point, not invented here).

## Validation

Override-linked the patched `GeomFill_Sweep.cxx` (compiled standalone, `-O0 -DNDEBUG -DNo_Exception`
to match a Release, exceptions-disabled build) ahead of the stock archive and re-ran the reproducer
above through the real `BRepFill_PipeShell`/`GeomFill_Sweep` object end to end (not just the
externally-reconstructed approximation): `ErrorOnSurface()` goes from `0.0001` to `2.54714`, matching
the externally-reconstructed prediction exactly. Every other value the reproducer prints (the
returned surface's degree, pole and knot counts, and both independent geometric deviations) is
byte-identical before and after: this patch changes only what the class *reports*, not the surface
any caller receives (`mySurface` is already `ConvertApprox.Surface()` two statements earlier).

## Reference

Downstream reproducer, fixture derivation and full before/after transcripts:
[`Scripts/repro/597-geomfill-sweep-error-overwrite/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/597-geomfill-sweep-error-overwrite)
(issue [#597](https://github.com/SecondMouseAU/OCCTSwift/issues/597) there). Related: the class this
branch calls, `GeomConvert_ApproxSurface`, is driven by `AdvApp2Var_ApproxF2var`, which had its own
defect fixed in patch `0019` ([OCCT#1418](https://github.com/Open-Cascade-SAS/OCCT/pull/1418)):
before that fix, `MaxError()` was structurally incapable of reporting a large truncation error
regardless of the true fit, which is why this defect's practical impact only became visible once
that one shipped.
