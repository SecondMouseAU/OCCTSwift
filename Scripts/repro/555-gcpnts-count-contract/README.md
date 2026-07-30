# OCCTSwift#555 reproducer: two `GCPnts` point-count defects in the kernel

Two unpatched defects in `GCPnts_UniformAbscissa` / `GCPnts_QuasiUniformAbscissa`, both about the
requested point count. `Scripts/patches/0018-*` fixes them.

[#501](https://github.com/SecondMouseAU/OCCTSwift/issues/501) closed the OCCTSwift-reachable half of
defect 1 at the bridge layer (`occtSamplerKept`/`occtSamplerIndex`/`occtValidSampleCount`), which was
the right immediate fix and is unaffected by this patch. What is here is the kernel side, which every
other OCCT consumer still had.

## Defect 1: `NbPoints()` exceeds the requested count

`GCPnts_UniformAbscissa::initialize` sizes its parameter array at `theNbPoints + 5` and the arc-length
walk fills it until it reaches the end parameter or runs out of room, setting `myNbPoints` to whatever
it reached. `GCPnts_QuasiUniformAbscissa` inherits this for every curve that is neither Bezier nor
BSpline, since it forwards to `GCPnts_UniformAbscissa` for those.

The mechanism is a tolerance mismatch, not an off-by-one. `Perform`'s termination test is

```cpp
if (std::abs(aUi - aUU2) <= theEPSILON)
```

where `theEPSILON = theC.Resolution(max(theTol, Precision::Confusion()))`. `Resolution()` converts a
3D tolerance to a parametric one using the curve's **largest** derivative. On an ellipse with major
radius 1e6 and minor radius 1e-3 that gives about 1e-13, while at the end of that curve the local
derivative is 1e-3, so the parametric tolerance actually corresponding to 1e-7 in 3D is about 1e-4.
The test is around nine orders of magnitude too tight there. The walk lands 1.557e-08 in parameter
short of the end, does not call that "done", takes one more step, and snaps that step to the end.

**The surplus point is a duplicate**: measured at `n=4`, the last two parameters differ by 1.557e-08
and the two 3D points by **1.175e-10**. That is the fact that decides the fix. Clamping `myNbPoints`
to the request would drop the exact end parameter and leave the distribution stopping short;
tightening the termination test keeps the end and removes a point that carries no geometry.

Measured on the shipped kernel before the patch, ellipse 1e6 x 1e-3, counts 2 to 60: **22 counts
over-request, always by exactly one**, for both classes.

## Defect 2: a point count below 2 stores out of bounds

Both classes document `theNbPoints >= 2` and enforce it with `Standard_ConstructionError_Raise_if`,
which compiles to nothing under `No_Exception`. That is how the shipped Release kernel is built
(`BUILD_RELEASE_DISABLE_EXCEPTIONS=ON`, see
[#487](https://github.com/SecondMouseAU/OCCTSwift/issues/487)), so in practice there is no check.

With `theNbPoints == 0`, `GCPnts_QuasiUniformAbscissa`'s Bezier/BSpline branch allocates
`new NCollection_HArray1<double>(1, theNbPoints)`, an empty range, and the next statement is an
unconditional `myParams->SetValue(1, theU1)`. `SetValue`'s own bounds check is a `Raise_if` too, so
the store lands out of bounds. Uncatchable, same class as #263/#310/#317/#318.

Measured on the shipped kernel before the patch:

| curve | `GCPnts_UniformAbscissa` | `GCPnts_QuasiUniformAbscissa` |
|---|---|---|
| line, circle | done, 1 point | done, 1 point |
| ellipse | done, **5 points** | done, **5 points** |
| 4-pole Bezier | done, 5 points | **SIGSEGV** |
| 8-point BSpline fit | done, 5 points | **SIGSEGV** |

A negative count behaves the same way. Even where it does not crash, answering a request for zero
points with five is not a defensible result.

## Fix

`Scripts/patches/0018-GCPnts-degenerate-count-and-duplicate-end-point-555.patch`.

- **Defect 2**: an ordinary `if` after each `Raise_if`, leaving the object not done for a count below
  2. The `Raise_if` stays, so a build with exceptions enabled still throws exactly as before; this
  only stops the undefined behaviour in builds where the check is compiled out. Applied to both
  classes, since `GCPnts_UniformAbscissa` had the same missing precondition without the crash.
- **Defect 1**: `Perform` also accepts a point that coincides with the end **in 3D** within the
  caller's tolerance, not only one that is close in parameter. The 3D tolerance is threaded in
  alongside the parametric one, the end point is evaluated once outside the walk, and the distance
  test is gated behind a cheap `aUU2 - aUi < aDelta` check so it runs on the final step rather than
  every step.

Nothing in either class' public API changes.

## Building and running

Both programs must be built with the **production defines**, or they measure a kernel nobody ships:

```bash
clang++ -std=c++17 -ObjC++ -w -g -DNDEBUG -DNo_Exception \
  -I Libraries/OCCT.xcframework/macos-arm64/Headers \
  -L Libraries/OCCT.xcframework/macos-arm64 \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/555-gcpnts-count-contract/repro_555_count.mm -o /tmp/repro_555_count
MMGT_OPT=0 /tmp/repro_555_count
```

`repro_555_count.mm` reports both defects: the requested-versus-actual table for defect 1, and one
`fork()`ed child per curve/class/count for defect 2 so a SIGSEGV in one case does not hide the rest.

`repro_555_equivalence.mm` is the regression guard. It fingerprints both classes across 17 curves and
counts 2 to 200, printing `nb`, `excess`, the first and last parameter and a digest of the full
parameter list, so a stock run and a patched run diff line for line:

```bash
clang++ -std=c++17 -ObjC++ -w -g -DNDEBUG -DNo_Exception \
  -I Libraries/OCCT.xcframework/macos-arm64/Headers \
  -L Libraries/OCCT.xcframework/macos-arm64 \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/555-gcpnts-count-contract/repro_555_equivalence.mm -o /tmp/repro_555_equiv
MMGT_OPT=0 /tmp/repro_555_equiv > /tmp/eq.txt
```

To measure a patch without a full rebuild, use the override-link technique from
`Scripts/patches/README.md`'s `#0001` entry, compiling the two patched TUs **with the same defines**
and linking them before `libOCCT-macos.a`.

## Results

Against the rebuilt kernel, with no override-linked TUs:

- `repro_555_count.mm`: over-request goes from 22 counts to **0**, and every degenerate count on
  every curve returns `IsDone() == false` for both classes, in place of a SIGSEGV, a 5-point answer
  or a 1-point answer depending on which curve and which class you happened to call.
- `repro_555_equivalence.mm`: of 6766 measured configurations, **232 changed and they are exactly the
  232 that were over-requesting**. Every other line is byte-identical, across a line, four circles
  from radius 1e-6 to 1e7, a 5 x 2 ellipse, a hyperbola, a parabola, a 2-pole and a 4-pole Bezier, an
  8-point and a 40-point BSpline, an offset circle, an offset BSpline and a trimmed circle. On the
  changed lines the last parameter is still exactly the end.
- Full `swift test`: 4842 tests in 1346 suites, clean.

The override-linked prediction and the rebuilt binary agree byte for byte.

## A measurement trap worth remembering

Compiling the override TUs **without** `-DNo_Exception` makes the `Raise_if` live again. Defect 2's
cases then abort with an uncaught `Standard_ConstructionError` instead of either crashing (stock) or
returning not-done (patched), which looks like a patch that broke something. Match the production
defines, or the measurement is of a build that does not exist.
