# OCCTSwift#3519 ground truth: `BRepFilletAPI_MakeFillet::NbSurf(IC)` on a contour with no surface data

`FilletBuilder.simulatedSurfaceCount(contour:)` faults the process on a builder that holds a contour
and was never built or simulated, and on any builder after `Reset()`. Found while measuring #3516
(`Scripts/repro/3516/`); this directory is the trace #3516 left open. Nothing was posted upstream.

Two probes, both against the `v4.0.0-kernel.8` `macos-arm64` slice, the asset `Package.swift` pins:

- `occt_3519_simulated_surf_matrix.mm`: every (builder state, accessor) pair in its own forked child,
  so a SIGSEGV is a row in the table. Output in `probe-output.txt`. Its last section is the check
  that the predicate the bridge uses agrees with `NbSurf` everywhere `NbSurf` answers.
- `occt_3519_stripe_state.mm`: opens `BRepFilletAPI_MakeFillet::myBuilder` and
  `ChFi3d_Builder::myListStripe` with `#define private public` (probe-only; nothing under `Sources/`
  does it) and prints what each stripe's `SetOfSurfData()` actually is in each state. Output in
  `stripe-state-output.txt`.

## Compile and run

```bash
XC=.build/artifacts/<package>/OCCT/OCCT.xcframework      # or Libraries/OCCT.xcframework
for p in occt_3519_simulated_surf_matrix occt_3519_stripe_state; do
  clang++ -std=c++17 -ObjC++ -w -I"$XC/macos-arm64/Headers" -L"$XC/macos-arm64" -lOCCT-macos \
    -framework Foundation -framework AppKit -lz -lc++ Scripts/repro/3519/$p.mm -o /tmp/$p
done
/tmp/occt_3519_simulated_surf_matrix      # exits 0 when the predicate check passes
/tmp/occt_3519_stripe_state
```

## Why it faults

`BRepFilletAPI_MakeFillet::NbSurf(IC)` is `ChFi3d_FilBuilder::NbSurf(IC)`
(`ChFi3d_FilBuilder.cxx:439-451`), which walks `myListStripe` to the IC-th stripe and returns

```cpp
itel.Value()->SetOfSurfData()->Length();
```

with no null test. `SetOfSurfData()` is `ChFiDS_Stripe::myHdata`, a default-null handle. Two things
touch it:

- It is assigned (`HData = new NCollection_HSequence<...>()`, in `PerformSetOfKPart`,
  `ChFi3d_Builder_2.cxx`) by `ChFi3d_Builder::PerformSetOfSurf` whenever the spine's split is not
  done. `Build()` runs that on every stripe, and `Simulate(IC)` on one
  (`ChFi3d_FilBuilder::Simulate`, `ChFi3d_FilBuilder.cxx:402-435`, is `PerformSetOfSurf(stripe, true)`).
  A stripe nobody ran either on has a null `myHdata`.
- It is `Nullify()`'d by `ChFiDS_Stripe::Reset()` (`ChFiDS_Stripe.cxx:46-52`), and
  `ChFi3d_Builder::Reset()` runs that on every stripe that still has a spine. The stripes stay, which
  is why `NbContours()` is still 1 after a reset and `NbSurf(1)` still reaches a stripe to read.

So the fault is `Length()` on a null handle, in three states: a contour added and never run, any
builder after `Reset()`, and, found here and not in the issue, a contour that a `Simulate` of another
contour never reached. A build or a simulation that is *declined* assigns the sequence before it
fails, so it is set and empty and the count is 0, which is why the issue saw 0 there.
`stripe-state-output.txt` shows the handle itself in each state.

`ChFi3d_Builder::NbComputedSurfaces(IC)` (`ChFi3d_Builder_1.cxx:438-467`) walks the same list to the
same stripe and returns the same `hd->Length()`, behind

```cpp
if (hd.IsNull()) { return 0; }
```

and `BRepFilletAPI_MakeFillet` exposes it. That is the null test OCCT ships for this sequence.

## Measured, `BRepFilletAPI_MakeFillet`, contour 1 unless a row says otherwise

`stripe` is `SetOfSurfData()` as `occt_3519_stripe_state` prints it.

| state | stripe | `NbSurf` | `NbComputedSurfaces` |
|---|---|---|---|
| fresh, no contour | no stripe | 0 | 0 |
| edge added, never built or simulated | null | SIGSEGV | 0 |
| edge added, `Simulate(1)` (control) | set, 1 | 1 | 1 |
| `Simulate(1)`, then `Reset()` | null | SIGSEGV | 0 |
| `Simulate(1)`, `Reset()`, `Simulate(1)` | set, 1 | 1 | 1 |
| built ok (radius 1) | set, 1, not simulated | 1 | 1 |
| built ok, then `Reset()` | null | SIGSEGV | 0 |
| `Simulate(1)`, then `Build()` | | 1 | 1 |
| `Build()`, then `Simulate(1)` | | 1 | 1 |
| declined build (radius 20) | set, empty | 0 | 0 |
| `Simulate(1)` declined (radius 20, throws `StartSol echec`) | set, empty | 0 | 0 |
| `Build()` with no contour (throws) | no stripe | 0 | 0 |
| two contours, only `Simulate(1)`: contour 1 | set, 1 | 1 | 1 |
| two contours, only `Simulate(1)`: contour 2 | null | SIGSEGV | 0 |
| two contours, nothing run: contours 1 and 2 | null | SIGSEGV | 0 |

`IsDone()` is false after a `Simulate` and true after a build, so it cannot be the guard: a real
simulation has `IsDone()` false and a real count (the mistake #3516's guard would be if copied here).
`NbComputedSurfaces(IC)` equals `NbSurf(IC)` in all 22 of the 28 (state, contour 1 or 2) pairs where
`NbSurf` answers, and is 0 in all 6 where it faults; the probe's last section checks that and exits
non-zero on a disagreement. The bridge now reads `NbSurf` only while `NbComputedSurfaces(IC)` is above 0.

A completed build keeps its count (row "built ok": 1), as before: the stripe holds the surface data
that build made, `NbSurf` answers it without a fault, and changing a non-faulting answer is not this
defect. `Sect(IC, 1)` is null there (the first `SurfData` carries no simulation sections), so a caller
who wants only a simulation's count can tell the two apart from `Sect`, which the bridge does not wrap.

OCCT itself never calls `MakeFillet::NbSurf`, `Sect` or `Simulate`: a grep of `Libraries/occt-src/src`
outside `ChFi3d`, `ChFiDS` and `BRepFilletAPI` finds only `FilletSurf_Builder`, which owns its own
`ChFi3d_Builder` subclass. That class reads simulated sections only through
`FilletSurf_Builder::NbSection`, which throws `StdFail_NotDone` unless the `Simulate()` before it
completed (`FilletSurf_Builder.cxx:326-352`). So there is no call site to copy, the nearest analogue
refuses rather than answers, and 0 is the refusal this builder already gives.

## Siblings, checked in the same states

| accessor | result | disposition |
|---|---|---|
| `NbComputedSurfaces(IC)`, IC in 0, 1, 2, 99 | returns in every state | the predicate |
| `NbSurf(0)`, `NbSurf(99)` | 0 in every state: no stripe matches | none needed |
| `Simulate(1)`, `Simulate(2)` as an operation | never faulted in any state; throws `StartSol echec` when the contour is declined, which the bridge catches | none needed |
| `Sect(IC, 1)` | SIGSEGV in the null states, the same read one step further; also SIGSEGV when the sequence is empty (declined), where `Value(1)` is past the end and the range check is compiled out; null handle after a build; the section array after a simulation (2 sections on a box edge) | not wrapped by the bridge, nothing to guard |
| `ComputedSurface(IC, IS)` | SIGSEGV in the null and empty states and with no stripe at all | not wrapped by the bridge |
| `StripeStatus(IC)` | SIGSEGV only with no stripe (IC past `NbContours()`) | a contour-index range defect, #3518 |
| `OCCTFilletBuilder*` other than `NbSimulatedSurf` | none reads a stripe's `SetOfSurfData()` | none needed |

## `BRepFilletAPI_MakeChamfer`: the same fault, not fixed here

`ChFi3d_ChBuilder::NbSurf` and `Sect` (`ChFi3d_ChBuilder.cxx:614-647`) are line for line the fillet's,
and the probe's chamfer section reproduces every row: `NbSurf(1)` SIGSEGV on a contour never run, after
`Reset()` (simulated or built), and on contour 2 after only `Simulate(1)`; 0 after a declined build or
simulation; 1 after `Simulate(1)` or a build. `ChamferBuilder.simulatedSurfaceCount(contour:)` has the
same fault and is **not** changed by this directory's fix, because the predicate is not reachable:
`BRepFilletAPI_MakeChamfer` has no `NbComputedSurfaces` or `StripeStatus`, and its `myBuilder` is
private. A bridge-side flag does not work either: which stripes hold a sequence after a *declined*
multi-contour `Build()` depends on how far `Compute` got, and `Remove` renumbers contours. Left open.
