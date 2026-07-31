# OCCTSwift#553 probe — a zero-radius circle handed to the 2D solvers

`occt_553_probe.mm` measures what every 2D solver family in `OCCTBridge_Geom2d.mm` does when one of
its circle arguments has radius 0, and compares that against OCCT's own point overload of the same
query. It is a measurement, not a crash reproducer: nothing here crashes, and that is the point.
Every one of these calls returns something that reads as an answer.

No fixture files and no kernel patch. Build and run:

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/553-gcc-zero-radius-circle/occt_553_probe.mm -o /tmp/occt_553_probe
/tmp/occt_553_probe
```

## The question

#514 guarded the 2D conic *construction* sites and deliberately stopped there. About 25 more sites
in the same file build a `gp_Circ2d` from caller-supplied doubles, but those circles are inputs to a
tangency, bisector, intersection or extrema solver rather than geometry being returned. A
zero-radius circle handed to such a solver is geometrically a point, and several of these solvers
have a documented, meaningful answer for a point argument. Rejecting it outright would remove a
query some callers might legitimately be making — unlike the construction sites, where a zero-radius
circle can only produce a degenerate result.

So the decision had to be made per family, on measurement.

## What the probe found

Negative was never the gap. `gp_Circ2d`'s constructor is `constexpr` in the header, so its
`Standard_ConstructionError_Raise_if(theRadius < 0.0, ...)` **does** run in a bridge translation
unit — the same finding #514 made for `gp_Elips2d`, confirmed again here — and the existing
`catch (...)` already turns a negative radius into an empty result. `GC_MakeCircle2d` rejects a
negative radius through `gce_NegativeRadius`, a status rather than a macro, so `No_Exception` does
not void that either. **The gap is exactly zero.**

And no family answers the point question:

| family | zero-radius argument gives | the point overload gives |
|---|---|---|
| `GccAna_Circ2dBisec` | 4 solutions, each duplicated. With **both** radii 0: a line plus two hyperbolas of **major radius 0** | `GccAna_CircPnt2dBisec` gives 2; `GccAna_Pnt2dBisec` gives the perpendicular bisector line |
| `GccAna_CircPnt2dBisec` | 2 hyperbolas of **major radius 0** | `GccAna_Pnt2dBisec` gives a **line** — the returned *type* is wrong, not just duplicated |
| `GccAna_CircLin2dBisec` | the point overload's parabola, twice | `GccAna_LinPnt2dBisec` gives it once |
| `GccAna_Lin2dTanPar` | the point overload's line, twice | the `gp_Pnt2d` overload gives it once |
| `GccAna_Lin2dTanPer` | the point overload's line, twice | the `gp_Pnt2d` overload gives it once |
| `GccAna_Lin2d2Tan` | the point overload's line, twice | the point/point overload gives it once |
| `GccAna_Circ2d3Tan`, 3 circles | 8 solutions: the point overload's 4, each twice | 4, all tangency residuals < 1e-14 |
| `GccAna_Circ2d3Tan`, 2 circles + point | 4 solutions holding 2 distinct circles | — |
| `GccAna_Circ2d3Tan`, 1 circle + 2 points | **0 solutions** | the all-points overload finds the circumscribed circle |
| `Extrema_ExtPElC2d` | **0 extrema** | — |
| `Extrema_ExtElC2d` | the right distance, twice | — |
| `IntAna2d_AnaIntersection` | the right point, with `ParamOnSecond()` **NaN** | — |

The duplication has a cause worth recording: tangency to a circle of radius 0 satisfies the
enclosing and the outside case simultaneously, so the solver enumerates each solution once per
qualifier. The two hyperbolas of major radius 0 are the same degenerate conic
`occtValidHyperbolaRadii` refuses to construct on the other side of this same file, so the bisector
families were handing back curves the construction API would not accept.

Every one of those families already has a point entry point wrapped in `OCCTBridge_Geom2d.mm`
(`OCCTGccAnaPnt2dBisec`, `OCCTGccAnaLinPnt2dBisec`, `OCCTGccAnaLin2dTanParPt`,
`OCCTGccAnaLin2dTanPerPtLin`, `OCCTGccAnaCirc2d3TanPoints`, `OCCTGccAnaLin2d2TanPntPnt`, and the
mixed circle/point overloads). Naming a point as a point already has a spelling, and a degenerate
circle is not it. So: **guard, in every family** — a decision reached per family, which happened to
converge.

## Two more radius contracts in the same file

The probe also covers the other two things a caller can mean by "radius" here.

**The radius of the circle the solver must find.** `GccAna_Circ2d2TanRad` and
`GccAna_Circ2dTanOnRad` asked for radius 0 return solution circles of radius 0. Three bridge entry
points already rejected that inline (`OCCTGccCircle2d2TanRad`, `OCCTGccCircle2dTanPtRad`,
`OCCTGccCircle2d2PtRad`); four siblings did not.

**A circle this file is asked to build.** Four sites #514 did not reach.
`BRepBuilderAPI_MakeEdge2d` reports `IsDone()` for a zero-radius arc and returns a zero-length edge
with both vertices at the centre. `GC_MakeCircle2d(ax, 0)` succeeds with `gce_Done`. And the
parallel constructor takes the *absolute value* of `radius + dist` rather than refusing an offset
that reaches or passes the centre:

```
GC_MakeCircle2d(r=5, dist=-5)   IsDone(), radius 0
GC_MakeCircle2d(r=5, dist=-6)   IsDone(), radius 1     <-- not the circle asked for
```

so `OCCTCurve2DMakeCircleParallel` checks the offset as well as the radius.

## Deliberately not changed

`extractBisecSolution` has a `case` for each of `GccInt_Lin`/`Cir`/`Ell`/`Hpr`/`Par` and a `default`
that writes `(0, 0)`, so a `GccInt_Pnt` solution would lose its coordinates. Section 13 of the probe
looks for one: identical circles, concentric circles, externally and internally tangent circles,
crossing circles, a point on the circle, a point at the centre. None of them produces a `GccInt_Pnt`,
and neither does any zero-radius case in sections 1–3. Left alone rather than fixed speculatively —
it is a `default` branch with no measured way to reach it, not an observed defect.
