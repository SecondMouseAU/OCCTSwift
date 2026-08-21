# #1019 / #1020 `OCCTGeomPlateSurface`'s builder arguments

`OCCTGeomPlateSurface` (`OCCTBridge_ProjLib_NLPlate.mm`, backs `Shape.plateSurface(points:)`) built

```cpp
GeomPlate_BuildPlateSurface builder(3, 10, 5, tolerance);
```

#1019 says the fourth slot is `Tol2d`, not `Tol3d`. #1020 says `maxDegree` and `maxSegments` reach
only the approximation and never the plate. Build and run with the recipe in `CLAUDE.md`:

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1019-1020-plate-builder-arguments/plate_builder_arguments.mm -o /tmp/plate_args
/tmp/plate_args
```

The probe rebuilds the entry point's whole pipeline (builder, point constraints, `Perform`,
`GeomPlate_MakeApprox` with `occtPlateApproxSurface`'s own `dmax` and continuity, then
`BRepBuilderAPI_MakeFace`) with one argument moved per row, and reports the fitted surface's pole
counts plus the worst distance from the caller's own input points to the result. It deliberately
does not report `G0Error`/`G1Error`/`G2Error`: those three are uninitialised members after a
point-constraint-only `Perform()` (#1018), so they are not a number yet.

## #1019: the slot is wrong, and moving the value would change nothing

The constructor, from the pinned 8.0.1 refman:

```cpp
GeomPlate_BuildPlateSurface(const int Degree = 3, const int NbPtsOnCur = 10, const int NbIter = 3,
                            const double Tol2d = 0.00001, const double Tol3d = 0.0001,
                            const double TolAng = 0.01, const double TolCurv = 0.1,
                            const bool Anisotropie = false);
```

So `tolerance`, a 3D distance, was landing on the 2D parametric tolerance. That much of #1019 is
real as written. The predicted consequence is not. Swept over fourteen orders of magnitude on two
fixtures (the cloud from `Shape.plateSurface`'s own doc comment, and a larger, steeply folded one
1000 units from the origin):

```
fixture 0                                        fixture 1
Tol2d=1e-12  poles=23x23  miss=0.000479583132    poles=37x37  miss=0.486404232
Tol2d=1e-09  poles=23x23  miss=0.000479583132    poles=37x37  miss=0.486404232
Tol2d=1e-05  poles=23x23  miss=0.000479583132    poles=37x37  miss=0.486404232
Tol2d=1e-02  poles=23x23  miss=0.000479583132    poles=37x37  miss=0.486404232
Tol2d=1e+00  poles=23x23  miss=0.000479583132    poles=37x37  miss=0.486404232
Tol2d=1e+02  poles=23x23  miss=0.000479583132    poles=37x37  miss=0.486404232
Tol3d=1e-12  poles=23x23  miss=0.000479583132    poles=37x37  miss=0.486404232
Tol3d=1e-09  poles=23x23  miss=0.000479583132    poles=37x37  miss=0.486404232
Tol3d=1e-05  poles=23x23  miss=0.000479583132    poles=37x37  miss=0.486404232
Tol3d=1e-02  poles=23x23  miss=0.000479583132    poles=37x37  miss=0.486404232
Tol3d=1e+00  poles=23x23  miss=0.000479583132    poles=37x37  miss=0.486404232
Tol3d=1e+02  poles=23x23  miss=0.000479583132    poles=37x37  miss=0.486404232
```

Both slots are inert. For contrast, the approximation tolerance in the same table moves the answer
as expected: `1e-1` gives 9x9 poles at 0.0723681775, `1e-3` gives 23x23 at 0.000479583132, `1e-6`
gives 37x37 at 0.000131121547.

The kernel says why. `myTol2d` is read at exactly two places, both inside
`for (int i = 1; i <= NTLinCont; i++)` in `Intersect()`, and this entry point loads only
`GeomPlate_PointConstraint`, so `NTLinCont` is 0. `myTol3d`'s point-only readers are the
average-plane planarity test (`GeomPlate_BuildAveragePlane(..., myTol3d / 1000, ...)`) and the
projection resolutions (`aSurfInit.UResolution(myTol3d)`), and both are exact on the planar initial
surface the point-only branch builds.

So `Tol3d = tolerance` is not a fix, it is a different no-op. The argument is dropped instead of
relocated: it was a value of the wrong kind in a slot nothing reads, and every sibling in the same
file (`OCCTShapePlatePointsAdvanced`, `OCCTShapePlateMixed`, `OCCTSurfacePlateThrough`) already
passes three arguments and leaves both tolerances at their defaults. `tolerance` keeps the two
places it does govern, `occtPlateApproxSurface` and the face tolerance.

**No test accompanies this change, because none can be made to fail.** The 24 rows above are the
evidence that the edit is observationally inert; a test asserting that would pass before and after.

## #1020: `maxDegree` and `maxSegments` should not reach the builder

The builder's first argument is its own `Degree`, and `GeomPlate_BuildPlateSurface::Perform` hands
it to `myPlate.SolveTI(myDegree, ...)`. That is a plate resolution order with the same cap
`Plate_Plate::SolveTI` enforces everywhere:

```
builder Degree=2   poles=37x37  miss=0.0125594471
builder Degree=3   poles=23x23  miss=0.000479583132
builder Degree=4   poles=16x16  miss=0.000383642037
builder Degree=5   poles=16x16  miss=0.00010413973
builder Degree=8   poles=9x9    miss=0.000300871783
builder Degree=9   poles=9x9    miss=0.000495251676
builder Degree=10  NOT BUILT
```

The caller's `maxDegree` is `GeomPlate_MakeApprox`'s `dgmax`, the maximum BSpline degree of the fit,
documented on `Shape.plateSurface` as exactly that and defaulting to 8. Degrees of 10 and above are
ordinary requests of an approximator and forwarding them to the builder turns each into an outright
failure. It would also move the shipped default's plate off `Degree = 3`, which OCCT's own
documentation calls the value chosen "to optimize resolution", and which
`Surface.plateThrough(_:degree:tolerance:)` already exposes separately with that same default for
callers who do want it.

The other two hardcoded builder arguments are inert here for the same reason `Tol2d` is:

```
builder NbIter=1, 2, 3, 5, 10          all poles=23x23  miss=0.000479583132
builder NbPtsOnCur=0, 1, 10, 15, 40    all poles=23x23  miss=0.000479583132
```

`myNbIter` is consulted only inside `if (NTLinCont != 0)`, and `myNbPtsOnCur` only in curve
discretisation. So the divergence between this site's `(3, 10, 5)` and the siblings' `(degree, 15,
2)` is cosmetic for a point-only plate, and converging them would change no answer.

The parameters the caller does reach govern a great deal, which is the point:

```
approx maxDegree=3 maxSegments=2    poles=6x6    miss=1.4332902
approx maxDegree=3 maxSegments=20   poles=12x12  miss=0.0787962815
approx maxDegree=5 maxSegments=2    poles=10x10  miss=0.0744081435
approx maxDegree=5 maxSegments=20   poles=22x22  miss=0.000964447528
approx maxDegree=8 maxSegments=2    poles=16x16  miss=0.00307612831
approx maxDegree=8 maxSegments=20   poles=23x23  miss=0.000479583132
```

#1020's reading of this site, "the caller's request governs half the pipeline", is accurate as a
description and wrong as a defect: the half it governs is the half its parameters are named for.
