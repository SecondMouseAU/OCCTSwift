# #999 NLPlate and GeomPlate-error probes

Ground-truth C++ probes compiled against the pinned 8.0.1 kernel, for the two `ProjLib_NLPlate`
sites in #999. Build each with the recipe in `CLAUDE.md`:

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/999-nlplate-plate-errors/<probe>.mm -o /tmp/<probe>
/tmp/<probe>
```

## `nlplate_solver.mm`

`OCCTSurfaceNLPlateG2` / `G3` declared a `maxIter` and called
`NLPlate_NLPlate::Solve2(ord, InitialConsraintOrder)`, which has no iteration count. #999 asked
whether `IncrementalSolve` was the intended entry point instead. Measured on a five-constraint G0G2
saddle with +-40 out-of-plane displacement on a 10x10 plane, deliberately large so that a mild
deformation converging in one step for every strategy could not make the rows agree for a reason
unrelated to the parameter:

```
Solve2(2, 1)               checksum=600947607.081183195114  worstConstraintMiss=9.22e-12  continuity=1
Solve(2, 1)                checksum=600947597.710318803787  worstConstraintMiss=4.33e-12  continuity=2
IncrementalSolve n=1       checksum=588761794.227541565895  worstConstraintMiss=5.93e-12  continuity=3
IncrementalSolve n=2       checksum=588761794.227590084076  worstConstraintMiss=0         continuity=3
IncrementalSolve n=4       checksum=588761794.227590084076  worstConstraintMiss=0         continuity=3
IncrementalSolve n=8       checksum=588761794.227590084076  worstConstraintMiss=0         continuity=3
IncrementalSolve n=16      checksum=588761794.227590084076  worstConstraintMiss=0         continuity=3
```

`IncrementalSolve` is a **different solver**, not a bound on this one: it returns a surface 2% away
by checksum and reports `Continuity()` 3 where `Solve2` reports 1. Its `NbIncrements` moves the
answer only between 1 and 2, and is inert from 2 upward on this fixture. So wiring `maxIter` to it
would silently change every existing caller's surface and still not mean "maximum iterations".
`IncrementalSolve` is already wrapped separately, as `OCCTSurfaceNLPlateIncrementalG0`, with its own
`nbIncrements`. `maxIter` is therefore removed rather than redirected.

The checksum samples a mid-row, the parametric diagonal, and a third slanted line, weighted apart.
A mid-row-only checksum would agree between genuinely different surfaces, because the fixture is a
saddle and a saddle is symmetric across v = 0.5.

## `geomplate_errors.mm`

`OCCTGeomPlateErrors` declared `maxDegree` and `maxSegments` and hardcoded
`GeomPlate_BuildPlateSurface builder(3, 10, 5, tolerance)`. The probe asks two questions and the
second one is the reason the function is deleted rather than repaired.

**Are `maxDegree`/`maxSegments` knobs of this computation?** No. In the sibling
`OCCTGeomPlateSurface` they are forwarded to `GeomPlate_MakeApprox` as `Nbmax`/`dgmax`, for the
BSpline fit that follows the plate build. `OCCTGeomPlateErrors` performs no fit; it reports the
builder's own `G0Error`/`G1Error`/`G2Error`. Running `GeomPlate_MakeApprox` afterwards at
`Nbmax` 2 and 20 crossed with `dgmax` 3 and 8 changes the fitted surface a great deal (6x6 poles at
`ApproxError` 56.9, up to 37x37 at 0.0569) and leaves the builder's three reported errors
bit-identical, as it must, since they are read off a different object.

The issue's framing, "a caller asking for degree 8 gets 3", conflates two different knobs: the `3`
in that constructor is `GeomPlate_BuildPlateSurface`'s own `Degree`, documented as "to optimize
resolution, Degree will have the default value of 3" and rejected below 3, not the approximation's
maximum degree.

**Do the reported errors mean anything at all?** No, and this is the finding:

```
--- what the bridge builds today, at three caller tolerances ---
builder(3, 10, 5, Tol2d=0.1)               G0=0 G1=0 G2=0
builder(3, 10, 5, Tol2d=0.001)             G0=0 G1=0 G2=0
builder(3, 10, 5, Tol2d=1e-06)             G0=0 G1=0 G2=0

--- the constructor slot the caller's tolerance actually lands in ---
builder(3, 10, 5, Tol2d=1e-5, Tol3d=1e-1)  G0=3.03135716117e-314 ...
builder(3, 10, 5, Tol2d=1e-5, Tol3d=1e-6)  G0=6.17868146607e-314 ...

--- the builder's own Degree ---
builder(Degree=3, 10, 5, 1e-3)             G0=6.1787917099e-314 ...
builder(Degree=5, 10, 5, 1e-3)             G0=6.1787917099e-314 ...
builder(Degree=8, 10, 5, 1e-3)             G0=6.1787917099e-314 ...
```

Those are denormal doubles, and they **change between runs of the same binary** (3.046e-314 on one
run, 3.016e-314 on the next, same inputs). The kernel explains it exactly:
`GeomPlate_BuildPlateSurface::VerifSurface()` is the only writer of `myG0Error`/`myG1Error`/
`myG2Error`, and `Perform()` reaches it only on the branch that has curve constraints. The
point-only branch calls `VerifPoints(di, an, cu)`, which computes its deviations into three locals
and discards them. None of the three constructors initialises the members, and they have no in-class
initialiser. So a point-only plate leaves all three uninitialised, and the getters return whatever
was in that memory.

Confirmed a second way, through the real bridge rather than a reconstruction of it, by calling
`Surface.plateErrors` repeatedly in one process:

```
run 0: (g0Error: 1.9355577472e-313,  g1Error: 5e-324,   g2Error: 4.217484478e-314)
run 1: (g0Error: -3.105038551588571e+231, g1Error: 1.6e-322, g2Error: 3.16e-322)
run 2: (g0Error: 3.818182542e-314,   g1Error: -nan,     g2Error: 3.16e-322)
```

`OCCTGeomPlateErrors` is point-only by construction, so `Surface.plateErrors` returned three
uninitialised doubles on every call it ever made. The shipped test asserted `r.g0Error >= 0` and
passed by luck; run 1 above would have failed it, and run 2's `-nan` fails every comparison. That is
why the entry point is deleted rather than having two dead parameters trimmed off it.

A curve-constraint entry point would report real numbers, since `VerifSurface` runs on that branch.
That is new API rather than a repair of this one, and is not attempted here.
