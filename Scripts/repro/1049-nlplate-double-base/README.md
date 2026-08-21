# #1049 / #1046: the NLPlate entry points and the base surface

`Surface.nlPlateDeformed` and `nlPlateDeformedG1` added the input surface to a value that already
contained it, so any surface away from the origin came back at twice its distance (#1049). All five
`OCCTSurfaceNLPlate*` entry points then refit their samples onto `[0, 1] x [0, 1]`, so the `(u, v)`
the constraints were written in addressed nothing on the result (#1046).

`nlplate_double_base.mm` links the real bridge translation unit and calls the shipped C functions,
so every number below is the shipped function's own answer.

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -I"Sources/OCCTBridge/include" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1049-nlplate-double-base/nlplate_double_base.mm \
  Sources/OCCTBridge/src/OCCTBridge_ProjLib_NLPlate.mm \
  -o /tmp/nlplate_double_base
/tmp/nlplate_double_base
```

`before.txt` is that run against `origin/main`'s copy of the bridge file, `after.txt` against the
fixed one. Both are on the same pinned kernel and the same probe.

## What `Evaluate` returns

Read from the pinned source, `NLPlate_NLPlate.cxx`, not from the header, which says nothing about
it:

```cpp
gp_XYZ NLPlate_NLPlate::Evaluate(const gp_XY& point2d) const
{
  return EvaluateDerivative(point2d, 0, 0);
}

gp_XYZ NLPlate_NLPlate::EvaluateDerivative(const gp_XY& point2d, const int iu, const int iv) const
{
  gp_XYZ Value(0., 0., 0.);
  if ((iu == 0) && (iv == 0))
  {
    Value = myInitialSurface->Value(point2d.X(), point2d.Y()).XYZ();   // the base point
  }
  ...
  for (... SI(mySOP); SI.More(); SI.Next())
    Value += SI.Value().EvaluateDerivative(point2d, iu, iv);           // plus each plate
  return Value;
}
```

The accumulator is seeded with the base surface's own point, so `Evaluate` is the absolute deformed
point. `Iterate` in the same file corroborates it from the other side:

```cpp
TopP.Load(Plate_PinpointConstraint(UV, HGPP->G0Target() - Evaluate(UV)));
```

`G0Target()` is the caller's absolute target, so the subtraction only makes sense if `Evaluate` is a
point in that same space. The probe measures it directly: for a plane through `(100, 0, 0)` with a
single G0 constraint pinning uv `(0,0)` to `(100, 0, 5)`, `Evaluate((0,0))` is exactly
`(100, 0, 5)` and `Evaluate((3,4))` is `(103, 4, 5)`, the base point plus 5 in z.

## The closed-form fixture

A G0 constraint contributes `target - Evaluate(uv)` as its pinpoint load. Ask for the point the base
surface already has and the load is the zero vector, the plate solution is identically zero, and
`Evaluate(uv) == base(uv)` everywhere. The correct answer is the input surface over the working
domain, and no fit tolerance or solver residual enters into it.

The doubled answer is `2 * base`, whose worst deviation over the working domain
`[-10, 10] x [-10, 10]` is `|base(10, 10)| = sqrt(110^2 + 10^2) = 110.4536101718726`. That is what
`before.txt` reports, to ten significant figures.

The same construction extends to all five entry points: give the derivative constraints the values
the base surface already has (a plane's `d/du` is `(1, 0, 0)`, its `d/dv` is `(0, 1, 0)`, and every
higher derivative is zero) and the load is zero again.

Deviations below walk both surfaces over their own domains in step, so a result on `[0, 1]`
and one on `[-10, 10]` are compared corner to corner rather than at the same numeric `(u, v)`.
That is what isolates the doubling from the parametrisation: `Issue1049NLPlateBaseSurfaceTests`
compares at the same numeric `(u, v)` instead, which is the property a caller actually has.

| fixture | origin/main | fixed |
|---|---|---|
| G0 identity, deviation from input | 110.453610172 | 2.84771664771e-14 |
| G1 identity, deviation from input | 110.453610172 | 2.84771664771e-14 |
| G2 identity, deviation from input | 14.1421356237 | 2.84771664771e-14 |
| G3 identity, deviation from input | 14.1421356237 | 2.84771664771e-14 |
| Incremental identity, deviation from input | 14.1421356237 | 2.84771664771e-14 |
| G0 pure-Z constraint, worst \|x - (100 + u)\| and \|y - v\| | 470.000007259 | 2.84217094304e-14 |
| G0 pure-Z constraint, max \|z\| | 5.00000010626 | 5 |
| G0 at the caller's own uv (0,0), target (100, 0, 5) | (180, -20, 5) | (100, 0, 5) |
| output domain, plane | [0, 1] x [0, 1] | [-10, 10] x [-10, 10] |
| output domain, cylinder u | [0, 1] | [0, 2pi] |
| origin-centred plane at the caller's uv (5,5) | (180, 180, 5), outside the domain | (5, 5, 5) |

The 110.45 and the 14.14 are two different defects, which is why they are two issues. G0 and G1
counted the base surface twice. G2, G3 and Incremental never did, and their 14.14 is the
`[0, 1]`-versus-`[-10, 10]` parametrisation gap on its own.

## The injection matrix

`Tests/OCCTSurfaceTests/Issue1049NLPlateBaseSurfaceTests.swift` was run against three broken
versions of the bridge file, restoring between each. Ten tests in the suite.

| row | injection | mechanism it isolates | tests failing |
|---|---|---|---|
| 1 | `occtNLPlateReparametrise` call removed | the parametrisation half (#1046) alone | 9 of 10 |
| 2 | the base surface added back in the sample loop | the doubling half (#1049) alone | 7 of 10 |
| 3 | `origin/main`'s whole file | both, as shipped | 9 of 10 |

Row 2 is the disjointness that makes rows 1 and 2 different experiments rather than one: under it
`The output carries the working domain` and `A bounded direction keeps the input surface's own
range` both pass, because the doubling moves the poles and not the knots, and its identity failures
report exactly `110.45361017187261`, the closed-form value above. Row 1's identity failures report
`282.8427158171896` instead, which is `200 * sqrt(2)`: with the output left on `[0, 1]`, asking it
for `u = -10` walks 20 times as far along the surface as the caller meant, landing 200 out in each
of u and v at the corner. Not a doubled base, a rescaled parameter.

The one test that passes in every row is `The fixture plane is parametrised as (100 + u, v, 0)`. It
never calls the bridge; it exists so that a fixture which had stopped meaning its own name would be
caught before anything downstream inherited it.

## Why no shipped test caught it

Every NLPlate fixture in the tree is `Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))`:
`NLPlateDeformationTests` (three G0 cases and three G1), `NLPlateG2G3Tests`,
`Issue999NLPlateParametersTests` and `Issue1017NLPlateResolutionOrderTests`. They assert `!= nil`,
`isFinite`, `uMax > uMin`, that two orders differ, and that the surface moves in z. None asserts a
coordinate.

The issue's own framing, that a surface centred on the origin has a base of roughly zero, is close
but not quite right, and fixture 6 shows the difference. A plane through the origin is parametrised
`(u, v, 0)`, which is zero only at uv `(0,0)`; the doubling stretches the patch by two in u and v
rather than translating it, and at the caller's uv `(5,5)` the old code answered `(180, 180, 5)`
from a parameter that was outside the returned surface's own domain. The reason no test saw it is
that no test asserted a coordinate, not that the fixture made the defect vanish.

## Two things the probe reports that this change does not fix

- **A G1 constraint's plate grows enormously over a 20-unit working domain.** Fixture 3 measures
  `max |solver.Evaluate|` at 6.53e12 on the pinned kernel, and the 20x20 fit deviates 2.63e12 from
  the solver it is fitting. That is the solver's own answer, reached directly with no bridge in the
  call, and it is unchanged by this fix: `before.txt` reports the same 6.53e12 grid and a worse
  1.97e23 fit. It is not #1049 and not #1046.
- **The 20x20 sample grid is still hardcoded**, so the `tolerance` a caller passes is compared
  against a fit whose input resolution they cannot influence. Fixture 5 is where it shows: the
  solver hits the cylinder's constraint target exactly, the fit misses it by 13.5, and the worst
  deviation between the fit and the solver anywhere on the domain is 52.3, against a plate whose own
  excursions reach 128.8. Two different numbers for two different questions, kept apart on purpose.
  Same family as #479 and #558, recorded in `docs/occtswift-wrapping-gaps.md` rather than fixed
  here.

Periodicity is also still lost. A linear knot map restores the parametrisation of the returned
surface but cannot make a fitted open BSpline close on itself, which is the limitation #1046's own
option 1 names.
