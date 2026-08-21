# #999 Geom2d / Curve3D / Healing probes

Ground truth for the residual #999 sites, sections A and D. Build with the recipe in `CLAUDE.md`:

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/999-geom2d-curve3d-healing/parameterisation_and_bisector.mm -o /tmp/probe
/tmp/probe
```

Three sites in one probe, because each asks the same question of a different call: what is the
parameter this function actually has, and does it move the answer?

## 1. `Geom2dConvert::CurveToBSplineCurve` (`OCCTCurve2DToBSpline`)

It has no tolerance. It has a `Convert_ParameterisationType`, and that is live:

```
--- full circle r=5 ---
  TgtThetaOver2    degree=2 poles=6  knots=4 rational=1 worstRelRadialError=4.44e-16
  TgtThetaOver2_1  CONVERSION THREW
  TgtThetaOver2_2  CONVERSION THREW
  TgtThetaOver2_3  degree=2 poles=6  knots=4 rational=1 worstRelRadialError=4.44e-16
  TgtThetaOver2_4  degree=2 poles=8  knots=5 rational=1 worstRelRadialError=3.33e-16
  QuasiAngular     degree=6 poles=6  knots=2 rational=1 worstRelRadialError=6.66e-16
  RationalC1       degree=4 poles=12 knots=5 rational=1 worstRelRadialError=6.66e-16
  Polynomial       degree=7 poles=7  knots=2 rational=0 worstRelRadialError=6.53e-06
```

A full ellipse gives the identical structure and the identical `Polynomial` error, which is worth
knowing: the parameterisation acts on the conic's angular parameter, not on its shape.

`Polynomial` is the only non-rational and the only inexact one, at 6.5e-06 against ~1e-16 for the
rest, exactly as `Convert_ParameterisationType`'s own documentation says. `TgtThetaOver2_1` and `_2`
throw for a full circle, matching their documented opening-angle limits of 0.9999 pi and 1.9999 pi.

**The fidelity number needed a second attempt, and the first one was the kind of mistake this
policy exists to catch.** The original probe sampled the two curves at proportionally equal
parameters and reported the distance between them, giving 0.19 for a circle and reading as a large
error. That measures the parameterisation difference, which is the thing being varied, so it
reports a large number for every correct answer. The probe now measures
`|distance to centre - radius|` over the converted curve, which is fidelity to the original conic
and nothing else.

An unbounded curve is asked separately, and the conversion itself throws for all eight types. That
too had to be separated: a fidelity loop over `Geom2d_Line`'s infinite parameter range throws on its
own, and would have been read as the conversion throwing.

## 2. `Bisector_BisecPC::Perform` (`OCCTCurve2DBisectorPC`)

It has no origin, unlike `Bisector_BisecCC::Perform`, whose origin the signature had been copied
from and which this bridge does pass through. It has a `DistMax`, and that is live:

```
  DistMax=1        EMPTY
  DistMax=10       range=[-8, 8]                   end=(8, 10)
  DistMax=100      range=[-28, 28]                 end=(28, 100)
  DistMax=500      range=[-63.1189354, 63.1189354] end=(63.1189354, 500)
  DistMax=5000     range=[-199.959996, 199.959996] end=(199.959996, 5000)
```

Fixture: a point 4 above a line, so the bisector is a parabola with something to trim. `DistMax` 1
is below the point's own offset, so nothing lies within it.

## 3. `ShapeAnalysis_Wire::CheckOuterBound` (`OCCTWireCheckOuterBound`)

It has no precision, and the `APIMake` it does have is not observable here.

The old bridge function called neither: it ran a `TopExp_Explorer` over the face and returned
"does this face have any wire", which is true of every valid face. So both the precision it declared
and the check it was named for were absent.

Sweeping precision across twelve orders of magnitude and `APIMake` across both values, on three
fixtures:

```
  MakeWire, forward      prec=1e-12 .. 100   APIMake=0 and 1   CheckOuterBound=0   (all ten rows)
  MakeWire, reversed     prec=1e-12 .. 100   APIMake=0 and 1   CheckOuterBound=1   (all ten rows)
  BRep_Builder, unshared prec=1e-12 .. 100   APIMake=0 and 1   CheckOuterBound=0   (all ten rows)
```

The verdict never moves with precision or with `APIMake`. It does move with the wire, forward
against reversed, which is the control that says the check is not simply constant. The third fixture
is a wire assembled with `BRep_Builder` from independently built edges, so consecutive edges carry
coincident but distinct vertices: that is the case `APIMake`'s own documentation distinguishes
("if False, to be used only when edges share common vertices"), and it does not separate them
either.

Reading the kernel agrees: `CheckOuterBound` rebuilds the wire onto `myFace.EmptyCopied()` and asks
`ShapeAnalysis::IsOuterBound`, touching `myPrecision` nowhere
(`ShapeAnalysis_Wire.cxx:1805`). `true` means "not an outer bound", i.e. problem found, matching the
sibling checks' convention.

`APIMake` is therefore left at OCCT's own default of `true` rather than exposed. Not observable on
three fixtures is weaker than not observable, and that is the claim made here.

## Sites in section D that needed no probe

Four were settled by reading the pinned headers, and there was nothing to measure because there is
no counterpart to measure against:

- `OCCTCurve2DTransform`'s `p5`: `buildTrsf2D` reads `p1`-`p4`, the widest case being mirror-axis,
  and no `gp_Trsf2d` setter it reaches takes a fifth. Every Swift call site passed a literal `0`.
- `OCCTMedialAxisCompute`'s `tolerance`: neither `BRepMAT2d_Explorer::Perform(face)` nor
  `BRepMAT2d_BisectingLocus::Compute(explo, LineIndex, aSide, aJoinType, IsOpenResult)` takes one.
- `OCCTExtremaElCLinElips`'s `tolerance`: of `Extrema_ExtElC`'s six constructors only line/line and
  line/circle take one; `Extrema_ExtElC(gp_Lin, gp_Elips)` does not.
- `OCCTExtremaLocateOnCurve`'s `tol`: both halves reach OCCT through
  `GeomAPI_ProjectPointOnCurve`, whose windowed constructor takes none. Its surface sibling keeps
  its `tol` because `Extrema_GenLocateExtPS` genuinely takes one.
