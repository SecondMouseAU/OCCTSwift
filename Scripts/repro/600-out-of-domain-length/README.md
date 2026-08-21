# OCCTSwift#600 probe: a finite parameter range that reaches outside the curve's domain

Ground truth against the pinned OCCT 8.0.0p1 kernel for what a ranged arc length measures when the
range is not wholly inside the curve's own parameter domain.

#600 was filed out of #548's measurements. `Curve3D.length(from:to:)` documented, since #477, that
"parameters outside the curve's domain are clamped to it, so a range wholly outside measures `0`
rather than extrapolating the curve's polynomial". That was measured on an interpolated BSpline.
This probe asks:

1. **Which curves actually behave that way?** `GCPnts_AbscissaPoint::length` intersects the range
   with the curve's own knots in its `GCPnts_AbsComposite` branch and nowhere else, so the claim
   can only hold where that branch runs.
2. **What *should* an out-of-domain range measure?** Unlike a NaN bound (#548), this is not garbage
   input: on a periodic curve the parameters are meaningful, and winding twice round a circle is a
   real measurement.
3. **Is `IsPeriodic()` the right test?** A trimmed arc's adaptor has to be checked, not assumed.
4. **Does the proposed rule hold up before it is coded?** The probe implements it and compares every
   case against an independent reference.

Each case reports four numbers: `today` (what the kernel call returns), `confined` (the range
intersected with the domain), `traced` (a Richardson-extrapolated chord sum over the range as the
curve evaluates it, so winding on a periodic curve and extrapolation on a polynomial one), and
`proposed` (the rule below, implemented in the probe).

## Build and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/600-out-of-domain-length/occt_600_out_of_domain.mm -o /tmp/occt_600
/tmp/occt_600

# the accuracy follow-up (issue #603), same flags
clang++ ... Scripts/repro/600-out-of-domain-length/occt_600_ellipse_accuracy.mm -o /tmp/occt_600_ellipse
/tmp/occt_600_ellipse
```

## Result

Measured over `[f, l + span]`, the domain, extended by one domain width past the end:

| curve | own length | today | confined | traced | now |
|---|---|---|---|---|---|
| segment (trimmed line) | 10 | 20 | 10 | 20 | **10** |
| unbounded line | 4e308 | 4e308 | 4e308 |, | 4e308 |
| circle r=5 | 31.42 | 62.83 | 31.42 | 62.83 | 62.83 |
| ellipse 8×3 | 36.49 | 73.98 | 36.49 | 72.73 | 72.98 |
| arc (half circle) | 15.71 | 31.42 | 15.71 | 31.42 | **15.71** |
| Bezier, 4 poles | 122.14 | 1002.29 | 122.14 | 1000.67 | **122.14** |
| BSpline, 5-pt interpolated | 528.75 | 528.75 | 528.75 | 7693.66 | 528.75 |
| BSpline, 5-pt periodic | 548.51 | 548.51 | 548.51 | 1097.02 | **1097.02** |

- **The documented clamping held for exactly one row.** Only the non-periodic multi-span BSpline
  takes the branch that confines. A segment extends the line it was trimmed from, a Bezier
  evaluates its polynomial past the poles (1002.29 for a curve 122.14 long, and 3582.87 for a range
  wholly outside the domain, where the curve is not present at all), and an arc leaves its trim and
  finishes the basis circle.
- **A periodic BSpline is the case that decides the design.** It is periodic *and* composite, so
  GCPnts confined it to its knots and returned one period for a request of two, silently
  answering half of what was asked, with no failure reported. "Confine unless periodic" would have
  left that untouched, because the confining happens inside GCPnts and not at the call site.
  Winding has to be computed here.
- **`IsPeriodic()` alone is not the test.** A `Geom_TrimmedCurve` over half a circle reports
  `IsPeriodic() == true` with `Period() == 2π`, it inherits the basis curve's periodicity, so the
  domain has to cover a whole period before a range may wind. Otherwise an arc measures round the
  half its caller trimmed away.
- **The proposal validates on every fixture.** `proposed` matches `traced` on every winding curve
  and `confined` on every other, to within 1e-4 relative. The one apparent mismatch is the ellipse,
  where `proposed` reproduces `today` exactly and it is the *integrator* that is off (see below).

## The rule

> A ranged arc length measures the part of the requested range that lies on the curve. A curve
> whose parameter domain covers a whole period exists at every parameter, so its whole range is
> measured, winding included.

Implemented as `occtAdaptorLengthBetween` / `occtAdaptorWindsPeriodically` / `occtConfineToDomain`
in `Sources/OCCTBridge/src/OCCTBridge_Internal.h`, shared by all four ranged entry points
(`OCCTCurve3DGetLengthBetween`, `OCCTCurve2DGetLengthBetween`, `OCCTCurve2DLength`,
`OCCTEdgeArcLengthBetween`), so a curve, its 2D equivalent and an edge built from it answer
identically. Winding is whole turns × one period's length, plus the remainder wrapped into the
domain, one period's length, not the whole domain's, so that a curve trimmed to more than a period
does not multiply the wrong number.

Pinned by `Tests/OCCTCurveTests/Issue600OutOfDomainRangeTests.swift`, verified by injection:
restoring the raw `GCPnts_AbscissaPoint::Length(adaptor, u1, u2)` call at all four sites fails 7 of
the 10 tests. The 3 that keep passing are the ones asserting *preserved* behaviour, the circle
still winds, the multi-span BSpline is unchanged, in-domain ranges are untouched, which is what
they are there to check.

## The accuracy defect this turned up (#603)

The ellipse rows do not match the chord reference, and the fix is not responsible: `proposed`
equals `today` there. `GCPnts_AbscissaPoint::Length` integrates a single-span conic with one Gauss
quadrature over the whole domain, which is the integrator #477 removed from multi-span curves, and
an ellipse has no `GeomAbs_CN` interval boundaries for `GCPnts` to split at.

`occt_600_ellipse_accuracy.mm` measures it against a 2M-point Simpson quadrature of the elliptic
integral: **+0.337%** on an 8×3 ellipse, **+1.485%** on 10×1, **+1.737%** on 1×0.05, all on the
*whole-period* measurement; sub-ranges (`[0, π]`, `[0, π/2]`) are accurate to ~1e-6, and summing the
same call over 2 or more equal sub-ranges of the full period recovers full accuracy. A circle is
exact, because it is length-parametrized and never reaches a quadrature. Filed as #603; not fixed
here, since it is an accuracy question rather than a range-semantics one.

Not an upstream defect for #600 itself: `GCPnts_AbscissaPoint::Length` documents no clamping
contract, and deciding what an out-of-domain range means is the caller's job. #603 is the one with
an upstream angle.
