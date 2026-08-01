# OCCTSwift#548 probe: a non-finite parameter bound through every ranged arc-length entry point

Ground truth against the pinned OCCT 8.0.0p1 kernel for what `GCPnts_AbscissaPoint::Length` does
with a `NaN` or infinite bound, per curve type and per bridge spelling.

#548 was filed out of #506's measurements, which found `Curve3D.length(from:to:)` reporting `0` for
a NaN upper bound and the curve's whole length for a NaN lower one on a BSpline, where a segment,
a line and a circle all propagate NaN and report `nil`. That makes the "`nil` means the computation
failed" guarantee — the guarantee #408 built the `-1.0` sentinel of `arcLength(from:to:)` /
`arcLengthBetween(_:_:)` on top of — hold only for some curves. This probe asks:

1. **Does it reproduce, and is the BSpline really the exception?** The issue measured two rows on
   one curve. Both a Bezier (single span, not length-parametrized) and a multi-span BSpline are
   needed to separate "spline" from "composite" as the discriminator.
2. **Is NaN the whole story?** An infinite bound goes through the same unchecked path.
3. **Do the siblings behave the same?** The 2D pair (`Curve2D.length(from:to:)` through the
   range-taking overload, `Curve2D.arcLength(from:to:)` through a pre-bounded adaptor) and the edge
   spelling (`Shape.edgeArcLength(from:to:)` through `BRepAdaptor_Curve`) were never measured.
4. **What is the mechanism?** The issue attributes it to #477's domain clamping, "not confirmed in
   the kernel source".

No fixture files needed: every case builds its geometry from a primitive or an interpolation.

## Build and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/548-nonfinite-length-bounds/occt_548_nonfinite_bounds.mm -o /tmp/occt_548
/tmp/occt_548
```

## Result

Fixtures: a trimmed line (domain `[0, 10]`), an unbounded line, a circle of radius 5, a 4-pole
Bezier and a 5-point interpolated BSpline (domain `[0, 485.39]`, length 528.75). "Swift sees" applies
the bridge's own `l >= 0 ? l : nil` guard.

| bounds | segment | unbounded line | circle | Bezier | multi-span BSpline |
|---|---|---|---|---|---|
| `(f, nan)` | `nan` → `nil` | `nan` → `nil` | `nan` → `nil` | `nan` → `nil` | **`0`** |
| `(nan, l)` | `nan` → `nil` | `nan` → `nil` | `nan` → `nil` | `nan` → `nil` | **`528.75`** |
| `(nan, nan)` | `nan` → `nil` | `nan` → `nil` | `nan` → `nil` | `nan` → `nil` | **`528.75`** |
| `(f, +inf)` | **`+inf`** | **`+inf`** | **`+inf`** | `nan` → `nil` | `528.75` |
| `(-inf, +inf)` | **`+inf`** | **`+inf`** | **`+inf`** | `nan` → `nil` | `528.75` |

- **The issue reproduces, and "BSpline" is not the discriminator — "composite" is.** The 4-pole
  Bezier is a spline and propagates NaN like the analytic types. What separates the BSpline is
  `NbIntervals(GeomAbs_CN) == 4`.
- **An infinite bound is the worse case, and it is not confined to composite curves.** A segment,
  an unbounded line and a circle each return `+inf`, which passes `l >= 0` and reaches the caller as
  a length. `(nan, nan)` measuring the whole length is a third row the issue did not have.

**The mechanism is not #477's domain clamping.** `GCPnts_AbscissaPoint::length` (the private
template behind every public `Length` overload) reduces the caller's range in its
`GCPnts_AbsComposite` branch with `std::min`/`std::max`:

```cpp
const double aUU1 = std::min(theU1, theU2);
const double aUU2 = std::max(theU1, theU2);
for (int anIndex = 1; anIndex <= aNbIntervals; ++anIndex) {
  if (aTI(anIndex) > aUU2) break;
  if (aTI(anIndex + 1) < aUU1) continue;
  aL += CPnts_AbscissaPoint::Length(theC, std::max(aTI(anIndex), aUU1),
                                          std::min(aTI(anIndex + 1), aUU2));
}
```

Both return their *first* argument when the comparison is false, which the probe's last section
confirms: `std::min(3.0, nan) == std::max(3.0, nan) == 3.0`, while `std::min(nan, 3.0)` and
`std::max(nan, 3.0)` are both `nan`. So

- a **NaN upper** bound gives `aUU1 == aUU2 == theU1`, an interval collapsed onto the start
  parameter — hence `0`, the encoding of a genuine zero-width interval;
- a **NaN lower** bound gives `aUU1 == aUU2 == nan`, which makes both per-span skip tests false and
  both per-span intersections identities, so every span is integrated in full — hence the whole
  length, indistinguishable from a valid measurement.

The other two branches (`GCPnts_LengthParametrized`, `|u2 - u1| * ratio`, and `GCPnts_Parametrized`,
a Gauss quadrature over `[u1, u2]`) have no such reduction, which is why they propagate NaN — and
why `|inf - u1| * ratio` returns `+inf` on the length-parametrized types.

**The sibling spellings, measured for the first time:**

| spelling | NaN bound | infinite bound |
|---|---|---|
| `Curve2D.length(from:to:)` (range-taking) | same as 3D: `0` / whole length on a composite curve | `+inf` on a segment/circle, whole length on a composite curve |
| `Curve2D.arcLength(from:to:)` (pre-bounded adaptor) | `nan` → `-1.0` on every type | **`+inf`** on a segment/circle |
| `Shape.edgeArcLength(from:to:)` | **`nan` returned to the caller** on a straight edge; `0` / whole length on a multi-span edge | `+inf` on a straight edge |

The edge spelling is the worst of the three: it is a non-optional `Double` with no sentinel at all,
so NaN escapes into caller arithmetic rather than being reported as anything.

(The pre-bounded row is measured as of this branch's base. #549 / PR #601 deletes
`OCCTCurve2DLength` and routes `Curve2D.arcLength(from:to:)` through `length(from:to:)`; once that
lands, the guard on the range-taking function covers both 2D spellings and the guard on the
pre-bounded one goes with the function.)

**A finite out-of-domain range is a separate, still-open divergence.** The same probe shows the
documented "parameters outside the curve's domain are clamped to it" holds only for composite
curves: measuring `[f, l + span]` gives `528.75` (clamped) on the BSpline, `20` on a 10-long segment,
two turns on a circle, and `1002.29` on a Bezier 122.14 long — that last one the polynomial
extrapolation #477 removed from the pre-bounded form. Not touched here, filed as #600: for a
periodic curve, measuring past the domain is meaningful, so this needs a contract decision rather
than a guard.

## What was done with it

The bounds are checked in the bridge, before any adaptor is constructed, by
`occtValidParameterRange` (`Sources/OCCTBridge/src/OCCTBridge_Internal.h`), applied at all four
ranged entry points. That makes the contract independent of the integrator's own NaN handling, so
it holds for every curve type rather than for the ones the tests happened to use.
`OCCTEdgeArcLength` / `OCCTEdgeArcLengthBetween` also move from `0` to `-1.0` as their failure
value, matching every other arc-length function in the bridge.

Pinned by `Tests/OCCTCurveTests/Issue548NonFiniteLengthBoundTests.swift`, verified by injection:
removing the precondition reproduces this probe's figures through the public Swift API (8 of the 9
tests fail, with `0`, `528.75`, `+inf` and `nan` all reported as measurements; the ninth is the
regression guard asserting finite ranges are unaffected, which must keep passing).

Not an upstream defect worth filing: `GCPnts_AbscissaPoint::Length` documents no precondition on its
bounds, and validating caller input is the caller's job. Nothing to patch in the kernel.
