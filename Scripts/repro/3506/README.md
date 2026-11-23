# #3506: `IntCurve_IntConicConic::Perform` never returns for a conic with no radius

`BRepCheck_Analyzer` never returns on a shape whose face has a pcurve that is a `Geom2d_Circle` of
radius 0, which `BRepTools::Read` builds from a complete BREP. The issue named radius 0 and left
open whether it was the only input. It is not: this directory measures the class directly.

```bash
Scripts/repro/3506/run.sh <OCCT.xcframework>                       # a kernel as shipped
Scripts/repro/3506/run.sh <OCCT.xcframework> <patched-object.o>    # the fix, override-linked
```

`probe.cxx` calls the three overloads that carry the loop (line against circle, line against
ellipse, circle against circle) with 23 inputs, each in its own process with a 3 second alarm, so a
hang is a result and the run goes on. The shapes are the ones `BRepCheck_Wire::SelfIntersect` hands
`Geom2dInt_GInter`: a line against a full circle or ellipse domain, tolerance 1e-9.

## The loop

`IntCurve_IntConicConic_1.cxx` brings the first parameter of the conic's domain into [0, 2PI) six
times with `while (Binf >= PIpPI) Binf -= PIpPI; while (Binf < 0.0) Binf += PIpPI;`. Between the two
reductions of the line against circle overload it widens the domain by its tolerance over the
radius, `CIRC_Domain.FirstTolerance() / Circle.Radius()`. At radius 0 that is an infinity, `Binf`
becomes minus infinity, and `-inf + 2PI` is `-inf`: the second loop never ends. At radius 1e-300 the
value is finite and a turn is below its last digit, so the loop never ends either. An infinite
parameter in the domain itself hangs the first loop. NaN does not: both comparisons are false.

The stack at the hang is the issue's, `IntCurve_IntConicConic::Perform` at +216, a few instructions
into the function.

## Measured, `v4.0.0-kernel.8`, 2026-11-23

| input | `kernel.8` | with `0079` |
|---|---|---|
| circle radius 1, 1e-7, 1e-9, 1e-12 | 2, 2, 2, 1 points | same |
| circle radius 1e-20, 1e-300, denormal minimum, 0 | **hang** | 1, 1, 2, 2 points |
| circle radius 0, line off the centre | 0 points | same |
| circle radius NaN, +inf | 4, 2 points | same |
| ellipse 2 x 1, 2 x 1e-12 | 2, 2 points | same |
| ellipse 2 x 1e-300, 2 x 0, 0 x 0 | **hang** | 2, 4, 4 points |
| circle domain first = -inf, last = +inf | **hang** | 2, 2 points |
| circle domain first or last = NaN | 4 points | same |
| two circles, domain first = -inf | **hang** | 2 points |
| two circles, domain last = +inf, and the control | 2 points | same |

10 of 23 hang before, 0 after, and the 13 that returned keep their number of points. The patched
object is `IntCurve_IntConicConic_1.cxx` from a `V8_0_1` tree with all 61 carried patches applied,
compiled with `-O3 -DNDEBUG -DNo_Exception`, which is what the kernel's own build uses (the
`_Raise_if` checks are compiled out, see `okf/policies/occt-validation-is-compiled-out.md`). The
unmodified file override-linked the same way reproduces the 9 hangs the shipped archive has in the
first 20 cases, which is what makes the technique trustworthy here.

Part 2 of `run.sh` is the shape of the issue: `fused.brep` from `Scripts/repro/3487`, the radius
token of its first circle pcurve (the `5` at byte 143) replaced.

| radius token | `kernel.8` | with `0079` |
|---|---|---|
| `5` (control) | valid | valid |
| `0`, `1e-300` | **does not return** | `isValid == false` |
| `1e-20`, `1e-12`, `nan`, `inf` | `isValid == false` | `isValid == false` |
| `00`, `ff`, `-`, `*` (the issue's four, read as 0) | **does not return** | `isValid == false` |

A plain cylinder with the same edit returns on `kernel.8`: its cap's wire is the circle alone, so
`BRepCheck_Wire::SelfIntersect` has no line to intersect it with. The hang needs a wire that holds a
line and a circle, which is why the fixture is the fused body.

## What was not measured

The other places in OCCT that bring an angle into a turn by stepping a turn at a time were not
audited. `Geom2dInt_GInter` against a conic with a parabola or hyperbola was not driven. The
reader was not changed (patch `0075` refuses a non-finite trim parameter at the reader; a radius of
0 is a value `gp_Circ2d` accepts, and the class is reached from callers that never read a file).
