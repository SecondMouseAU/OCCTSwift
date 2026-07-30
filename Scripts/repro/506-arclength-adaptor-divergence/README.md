# OCCTSwift#506 probe: pre-bounded adaptor vs range-taking `GCPnts_AbscissaPoint::Length`

Ground truth for the two spellings of ranged arc length the bridge carried, against the pinned
OCCT 8.0.0p1 kernel.

#506 found three arc-length bridge functions left unreachable when #408 routed every Swift spelling
through `OCCTCurve3DGetLength` / `OCCTCurve3DGetLengthBetween`. That reading is correct. The header
comparison also suggests the orphans are exact copies, differing only in their failure sentinel. One
of them is not: `OCCTCurve3DLength` measured through a **pre-bounded** `GeomAdaptor_Curve(c, u1, u2)`
rather than passing the range to `GCPnts_AbscissaPoint::Length(adaptor, u1, u2)`. This probe asks
what that constructor choice actually changes, which the headers do not say:

1. **Do the two forms ever disagree, and on what input?** A duplicate that behaves identically is a
   tidiness question. One that does not is a correctness question.
2. **Which one clamps to the curve's domain?** #477's fix depends on clamping rather than
   extrapolating past a BSpline's knots.
3. **How does each treat a reversed range?** The 2D sibling documents itself as range-checked, and
   #487 established that `No_Exception` voids OCCT-internal preconditions in this build, so the
   documented raise needed confirming rather than reading.

No fixture files needed: every case builds its geometry from a primitive or an interpolation.

## Build and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/506-arclength-adaptor-divergence/occt_506_arclength_adaptor.mm -o /tmp/occt_506
/tmp/occt_506
```

## What it does

Part 1 measures both forms on the same input across in-domain, reversed, equal-parameter,
out-of-domain, periodic-seam, unbounded and NaN ranges. The fixture is a 5-point interpolated
BSpline with sharply varying speed (domain `[0, 325.974]`, length 360.986), the shape #477's accuracy
work used, plus a circle and an unbounded line. Part 1g repeats the comparison for the 2D pair, where
both spellings are still live. Part 2 follows up on the NaN row, asking whether the surviving form's
NaN behaviour is the same for every curve type.

## Result

**The orphans were not exact copies. The pre-bounded form disagrees on four of eleven ranges.**

| range | pre-bounded (deleted) | ranged (live) |
|---|---|---|
| in domain, forward | 173.76 | 173.76 |
| in domain, full | 360.99 | 360.99 |
| in domain, reversed | raises `Standard_Failure` | 173.76 |
| equal parameters | 0 | 0 |
| overshooting both ends by a domain width | **8489.78** | 360.99 |
| wholly outside the domain | 1.34 | 0 |
| periodic seam, full period, unbounded sub-range | agree | agree |
| NaN upper bound | `nan` | 0 |

- **Only the range-taking form clamps.** The pre-bounded constructor evaluates the BSpline's
  polynomial past its knots: 8489.78 for a curve 360.99 long, and 1.34 for a range the curve does not
  occupy at all, both reported as ordinary successes. This is the behaviour #477 removed from every
  reachable path, preserved verbatim in the unreachable one.
- **The reversed-range raise is real in this build.** `GeomAdaptor_Curve(c, 195.6, 32.6)` and the 2D
  equivalents raise, so `No_Exception` does not void this particular precondition. The deleted
  function's `catch (...) { return 0; }` turned that raise into `0`, which is the same value a
  genuine zero-width interval reports, so a reversed range read as zero length.
- **The two agree wherever the range is ordinary**, including across a periodic seam and on an
  unbounded line, which is why nothing noticed for two releases.

**The live form's NaN handling is curve-type dependent**, which part 1f's single row hinted at:

| curve | NaN upper bound | NaN lower bound |
|---|---|---|
| segment (trimmed line) | `nan`, Swift reports `nil` | `nan`, Swift reports `nil` |
| unbounded line | `nan`, Swift reports `nil` | not measured |
| circle | `nan`, Swift reports `nil` | not measured |
| BSpline | **0**, Swift reports a value | **360.99**, Swift reports a value |

#408's distinguishability test uses `Curve3D.segment(from:to:)`, one of the types where NaN
propagates, so it passes and says nothing about splines. Filed as #548.

## What was done with it

All three orphans deleted, with tombstone comments naming the surviving function. The four divergent
ranges are pinned by `Tests/OCCTCurveTests/Issue506ArcLengthBridgeContractTests.swift`, verified by
injection: restoring the pre-#408 wiring reproduces this probe's figures through the public Swift API
(`0` against 173.76, 8489.78 against 360.99, 1.34 against 0), and rewiring `length(from:to:)` itself
onto the pre-bounded form fails all four tests.

Not an upstream defect: both `GeomAdaptor_Curve` constructors behave as documented, and choosing
between them is the caller's job. Nothing to file or patch in the kernel.

Two findings left for their own issues: the NaN dependence above (#548), and the 2D pair, where
`Curve2D.arcLength(from:to:)` still reaches the pre-bounded form deliberately, so the 2D and 3D
spellings of the same call now answer differently on a reversed range (#549).
