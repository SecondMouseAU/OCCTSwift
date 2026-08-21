# OCCTSwift#571 reproducer, `Nbmax = 1` makes `GeomPlate_MakeApprox` ignore its own error criterion

Standalone, deterministic probes for the two `GeomPlate_MakeApprox` arguments that decided whether
the `tolerance` parameter of the six plate entry points meant anything. No fixture file is needed;
both programs build their own plates from point constraints.

**Fixed bridge-side**: no kernel patch, no `OCCT.xcframework` rebuild. All six sites now share
`occtPlateApproxSurface` (`Sources/OCCTBridge/src/OCCTBridge_ProjLib_NLPlate.mm`, contract
documented in `OCCTBridge_Internal.h`).

Compile with the standard ground-truth invocation from `CLAUDE.md`:

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/571-plate-approx-contract/occt_571_plate_sweep.mm -o /tmp/occt_571_sweep
/tmp/occt_571_sweep
```

## The census the issue asked for

`GeomPlate_MakeApprox` is the one consumer of `AdvApp2Var_ApproxAFunc2Var` that does not go through
`GeomConvert_ApproxSurface`: it drives the approximator directly, so it sat outside every census
built by grepping for `GeomConvert_ApproxSurface`. **#571 named three bridge call sites; there are
six**, and the two that the issue's list missed are the ones that diverge most:

| # | site | Nbmax | dmax |
|---|---|---|---|
| 1 | `OCCTShapePlatePoints` (`OCCTBridge_Healing.mm`) | 1 | `tolerance * 10` |
| 2 | `OCCTShapePlateCurves` (`OCCTBridge_Healing.mm`) | 1 | `tolerance * 10` |
| 3 | `OCCTShapePlatePointsAdvanced` (`OCCTBridge_ProjLib_NLPlate.mm`) | 1 | `tolerance * 10` |
| 4 | `OCCTShapePlateMixed` (`OCCTBridge_ProjLib_NLPlate.mm`) | 1 | `tolerance * 10` |
| 5 | `OCCTSurfacePlateThrough` (`OCCTBridge_ProjLib_NLPlate.mm`) | 1 | `tolerance * 10` |
| 6 | `OCCTGeomPlateSurface` (`OCCTBridge_ProjLib_NLPlate.mm`) | caller's `maxSegments` (default 20) | `tolerance * 0.1` |

Sites 1 and 6 are reachable from **overloads of one Swift name**, `Shape.plateSurface(through:)`
and `Shape.plateSurface(points:)`, doing the same job with contracts 22x apart on accuracy.

## Root cause

`Nbmax` caps the number of Bezier patches, and **1 is the one value that disarms the algorithm.**
`AdvApp2Var_ApproxAFunc2Var::ComputePatches` derives its cut decision `NumDec` from `myMaxPatches`:

```cpp
if (((NbPatch + NbV) <= myMaxPatches) && ((NbPatch + NbU) > myMaxPatches) && (Umore)) NumDec = 1;
// ... every branch requires a sum of at least 2 to be <= myMaxPatches
```

At `myMaxPatches == 1` every guard fails and `NumDec` stays 0. `AdvApp2Var_Patch::CutSense` then
returns 0 whether or not the criterion is satisfied:

```cpp
if (Crit.IsSatisfied(*this)) { return 0; } else { return NumDec; }   // NumDec is 0 too
```

so "the fit missed" and "the fit is fine" issue the same instruction, keep this patch. The
criterion is still computed and still reported through `CriterionError()`; it just cannot act.

`dmax` sets that criterion's threshold, as `seuil = max(Tol3d, 10 * dmax)`
(`GeomPlate_MakeApprox.cxx:391-399`), so `dmax = tolerance * 10` asks the G0 criterion to accept
100x the tolerance the caller requested.

## What the probes show

`criterion-probe.txt` is the direct proof that the criterion is violated and ignored:

```
  Nbmax=1 dmax=1e-09    seuil=0.01     critErr=0.0981545    violated=YES | uP=9 vP=9
  Nbmax=1 dmax=1e-06    seuil=0.01     critErr=0.0981545    violated=YES | uP=9 vP=9
  Nbmax=1 dmax=0.001    seuil=0.01     critErr=0.0981545    violated=YES | uP=9 vP=9
  Nbmax=2 dmax=1e-09    seuil=0.01     critErr=0.00484093   violated=no  | uP=16 vP=16
```

`Nbmax = 2` is enough; everything from 2 to 100 produces the identical surface on this fixture. And
at `Nbmax = 1`, sweeping `dmax` across nine orders of magnitude (`1e-5` to `1e4`) yields
**bit-identical control nets**: a dead argument in the sense of #497's inert `SetFuzzyValue`.

The same probe pins the continuity contract: `GeomPlate_MakeApprox` accepts `C0`, `C1` and `C2`
only. `G1`, `G2`, `C3` and `CN` each throw `AdvApp2Var_ApproxAFunc2Var : UContinuity Error`, which
is why `occtGeomAbsFromSurfaceContinuity` (order 1 → `GeomAbs_G1`) must not feed that argument.

## The #522 question: did the surfaces move?

**No.** `sweep-stock.txt` and `sweep-0019.txt` are the same 54-case sweep either side of
`Scripts/patches/0019-AdvApp2Var-jacobi-max-wrong-workspace-slot-522.patch`, the "stock" side built
by compiling the unpatched `AdvApp2Var_ApproxF2var.cxx` as a single TU and linking it ahead of the
archive:

```bash
clang++ -std=c++17 -c -w -O2 -DNo_Exception \
  -I"Libraries/occt-src/src/ModelingData/TKGeomBase/AdvApp2Var" \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  AdvApp2Var_ApproxF2var_stock.cxx -o stock.o
# then link stock.o BEFORE -lOCCT-macos
```

Every one of the 54 pole fingerprints is identical, as are all degrees and pole counts. Only the
reported `ApproxError()` changed, rising 1.03x to 5.37x (median 1.15x), the interior contribution
being counted for the first time, exactly the effect #522 documented. At the implicit `C1` default
the `NDMINU` degree floor is already 8, so #522's collapse could not reach these sites, which is
what #571 predicted. Nothing in the plate family needed re-baselining because of `0019`.

Verify the override-link is actually taking effect before trusting a "stock" run, link it into
`Scripts/repro/522-approx-c0-collapse/occt_522_c0_minimal.mm` and check the `cont=C0` row reports
`uDeg=1 uPoles=2` (the collapse) rather than `uDeg=7 uPoles=15` (patched).

## Note on the `EnlargeCoeff` domain

`GeomPlate_MakeApprox` scales each of the plate's real bounds by `EnlargeCoeff` (default 1.1) rather
than expanding the interval about its centre, so the fit domain is only genuinely enlarged when the
bounds straddle zero. Plate UV domains from `GeomPlate_BuildPlateSurface` are centred near the
origin, so in practice they do, the sweep prints both domains and the count of constraint points
falling strictly inside the enlarged one, since `GeomPlate_PlateG0Criterion::Value` skips any point
on or outside the patch boundary and would silently measure nothing if they all fell outside.
