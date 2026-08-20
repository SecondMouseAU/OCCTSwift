# #1017 NLPlate G0/G1 resolution order

`Surface.nlPlateDeformed` and `nlPlateDeformedG1` named a parameter `maxIterations` and passed it to
`NLPlate_NLPlate::Solve2` as its first argument. Build and run with the recipe in `CLAUDE.md`:

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1017-nlplate-solve2-order/nlplate_order.mm -o /tmp/nlplate_order
/tmp/nlplate_order
```

## What the parameter is

From the pinned 8.0.1 header:

```cpp
Standard_EXPORT void Solve2(const int ord = 2, const int InitialConsraintOrder = 1);
```

There is no iteration count on `Solve2`, and none on `Solve` either. `ord` is forwarded to
`Plate_Plate::SolveTI` as the plate's resolution order, and `SolveTI` opens with

```cpp
order = ord;
if (ord <= 1) { return; }
if (ord > 9)  { return; }
```

leaving its own `OK` false. `NLPlate_NLPlate::Iterate` then drops the plate it had prepended and
returns false, and `Solve2` sets `OK = true` **after** its loop regardless. So an out-of-range order
comes back `IsDone()` with an empty plate list, and `Evaluate` returns the initial surface.

## Measured

The probe reproduces the bridge's own G0 and G1 paths on the fixtures the shipped
`NLPlateDeformationTests` use. `maxAbsGridZ` is the largest absolute Z over the bridge's 20x20
sample grid; the base surface is the plane z = 0, so 0 means nothing moved.

```
G0, three constraints, the furthest 5 units off the plane
G0 Solve2(0, 1)    IsDone=true  maxAbsGridZ=0           worstConstraintMissZ=5
G0 Solve2(1, 1)    IsDone=true  maxAbsGridZ=0           worstConstraintMissZ=5
G0 Solve2(2, 1)    IsDone=true  maxAbsGridZ=7.37499992  worstConstraintMissZ=4.375
G0 Solve2(3, 1)    IsDone=true  maxAbsGridZ=28.0000047  worstConstraintMissZ=7.71703927e-07
G0 Solve2(4, 1)    IsDone=true  maxAbsGridZ=36.0000439  worstConstraintMissZ=6.31227013e-06
G0 Solve2(5, 1)    IsDone=true  maxAbsGridZ=193.500904  worstConstraintMissZ=2.1577742e-05
G0 Solve2(8, 1)    IsDone=true  maxAbsGridZ=1764.55917  worstConstraintMissZ=0.00563499789
G0 Solve2(9, 1)    IsDone=true  maxAbsGridZ=9955.00929  worstConstraintMissZ=0.0299388555
G0 Solve2(10, 1)   IsDone=true  maxAbsGridZ=0           worstConstraintMissZ=5
G0 Solve2(12, 1)   IsDone=true  maxAbsGridZ=0           worstConstraintMissZ=5
G0 Solve2(100, 1)  IsDone=true  maxAbsGridZ=0           worstConstraintMissZ=5
```

G1 behaves the same way at the ends of the range: orders 10, 12 and 100 report done with nothing
moved and the constraint missed by its full 1.

Three things follow.

**It is not an iteration count and cannot be made into one.** Nothing in `Solve2` iterates to a
bound. `IncrementalSolve` does take an `NbIncrements`, and #999 already measured that it is a
different solver rather than a bound on this one (a surface 2% away by checksum, `Continuity()` 3
against `Solve2`'s 1, and `NbIncrements` inert from 2 upward); it is wrapped separately as
`OCCTSurfaceNLPlateIncrementalG0`. See `Scripts/repro/999-nlplate-plate-errors/`.

**It is not dead either**, which is what separates it from the G2/G3 siblings whose `maxIter` #999
deleted. Between 2 and 9 it changes the answer by three orders of magnitude. So it is renamed to
`resolutionOrder`, not dropped.

**Out of range it produces a wrong answer, not a failure.** That is what the new refusal in
`OCCTSurfaceNLPlateG0`/`G1` fixes: below 2 or above 9 the bridge returns null instead of handing
back an undeformed surface that reports success.

## The default stays at 4

OCCT's own default for `Solve2` is 2, and the issue asked whether the Swift default should follow
it. Measured, on this entry point's own three-constraint fixture, order 2 leaves the furthest
constraint 4.375 of its 5 units unmet, because `Solve2` sets `SetPolynomialPartOnly(true)` for a
pure-G0 plate and an order-2 polynomial part cannot interpolate three points. Order 3 meets it to
7.7e-7 and order 4, the shipped default, to 6.3e-6. Moving the default to OCCT's would be a
measurable regression on the shipped fixture, so 4 is kept and only the name changes.

## `InitialConsraintOrder` is live, and is still not exposed

`Solve2`'s second argument was never passed by either entry point. It is not inert:

```
G0 Solve2(4, 0)   maxAbsGridZ=36          worstConstraintMissZ=0
G0 Solve2(4, 1)   maxAbsGridZ=36.0000439  worstConstraintMissZ=6.31227013e-06
G1 Solve2(4, 1)   maxAbsGridZ=8.53224025e+18  fit=threw
G1 Solve2(4, 2)   maxAbsGridZ=18.5000041      fit=ok
```

The G1 row is the interesting one, and it is the reason the parameter is not exposed. `Solve2`'s
loop runs from `InitialConsraintOrder` to `MaxActiveConstraintOrder`, which is 1 for G0+G1
constraints, so an initial order of 2 or 3 makes the loop body never execute and the G1 refinement
pass is skipped entirely. The well-behaved surface at `(4, 2)` is that skip, not a tuning choice.
Exposing a knob whose useful setting works by disabling half the solve would be shipping an
accident. The bridge now passes 1 explicitly, matching OCCT's default and the `Solve2(2, 1)` /
`Solve2(3, 1)` spelling the G2/G3 siblings already use.

## The segfault the tests were disabled for does not reproduce

`NLPlateDeformationTests` carried
`.disabled("NLPlate G0/G1 causes segfault in OCCT — pre-existing issue")`. Against the pinned
kernel all seven tests pass, 20 consecutive runs, zero crashes. The suite is re-enabled.

The order is ruled out as the cause rather than confirmed: every value in the sweep above returns or
throws a catchable `Standard_ConstructionError`, and none faults. The G1 rows do show the mechanism
a crash report would have come from, since orders 4 and up drive the plate to 1e18 and beyond on the
two-constraint fixture and `GeomAPI_PointsToBSplineSurface` then throws
`Geom_BSplineSurface: VKnots interval values too close`. The bridge wraps that in `catch (...)` and
returns null, which is what the re-enabled `nlPlateG1MultipleConstraints` sees.
