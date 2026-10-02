# OCCTSwift#2972: eight SheetMetal volumes that did not add up

Ten `SheetMetal` fixtures carry pinned volumes. Two were derived to the last digit when they were
pinned; the other eight matched no flange-volume-plus-bend-material sum, and four of them came out
**below their flange volumes alone**. This directory is the measurement that split them.

The verdict is that the eight were two different things:

- **The four stepped-seam fixtures were a real defect.** `findSeamEdges` filleted the whole seam
  *line*, not the bend, so the free edge of the wider flange's outer split piece was rounded away.
- **The four convex-bend fixtures were right all along.** The arithmetic that called them
  unexplained left out the flange-body overlap and, in each part, the concave bend sitting beside
  the convex one. All four derive exactly once both are counted.

## Running it

```bash
swift run Harnesses 2972-sheetmetal-volumes
```

The harness is `Scripts/repro/harnesses/SheetMetalVolumes.swift`, in the shared `Harnesses`
executable target (#694's pattern: one target, not one per repro directory). It builds each
fixture through the public `SheetMetal.Builder` and compares the volume against terms declared per
fixture rather than fitted afterwards:

```
ideal   = sum of flange body volumes
        - the volume where two flange bodies interpenetrate
        + r^2 (1 - pi/4) * L   for every CONCAVE bend, over its matched seam length L
        + (pi/4) t^2 * L       for every CONVEX bend, the quarter-disc bend-material prism

leaked  = ideal - r^2 (1 - pi/4) * L over every run of the seam line OUTSIDE the bend's extent
```

`ideal` and `leaked` are the same number for the six fixtures with no stepped seam, which is what
makes the comparison a test rather than a fit.

## Measured on `main` at e6a3b8f7, `v4.0.0-kernel.3`

Before the fix:

| fixture | measured | v - ideal | v - leaked |
|---|---|---|---|
| `SheetMetalTests.lBracket` | 13315.796477516664 | 0 | 0 |
| `SheetMetalTests.uChannel` | 2819.314165294229 | 0 | 0 |
| `narrowUprightStepSucceeds` | 8815.654315677795 | **-17.866** | +0.000003 |
| `lBracketStepSeamCentredTab` | 7580.685854250031 | **-28.971** | +0.000020 |
| `zBracket` | 6219.314184838488 | **-14.486** | +0.000020 |
| `uChannelStepped` | 12857.942652236779 | **-19.314** | +0.000156 |
| `ConvexBendIssue89.zBracketRepro` | 12671.999999999995 | 0 | 0 |
| `ConvexBendIssue89.symmetricZ` | 7248.285413235574 | 0 | 0 |
| `ConvexBendIssue89.offsetLShortWeb` | 12577.466807156732 | 0 | 0 |
| `ConvexBendIssue89.channelWithFlange` | 10759.358422418583 | 0 | 0 |

Four fixtures needed the surplus term and six did not. The harness also classifies a point 0.2
inside the base flange's free back corner, well outside every bend's extent: **`outside` on all
four** stepped fixtures, which reads the defect without going through a volume at all.

After the fix every fixture lands on `ideal`:

| fixture | measured | v - ideal |
|---|---|---|
| `narrowUprightStepSucceeds` | 8833.505966569946 | -0.013949 |
| `lBracketStepSeamCentredTab` | 7609.603645881255 | -0.053437 |
| `zBracket` | 6233.761588994660 | -0.038200 |
| `uChannelStepped` | 12876.881759332367 | -0.374902 |

and all four corner probes classify `inside`.

## The defect

`findSeamEdges` selects edges parallel to the seam direction that lie on both flanges'
toward-the-other faces. Both plane tests hold all the way along the seam **line**, not just along
the bend, so on a stepped seam the outer split piece's free edge passes them too. That edge is
convex, so a fillet there removes `r^2 (1 - pi/4)` per unit instead of adding it, which is why four
fixtures came out below their flange volumes. The deltas are exact:

| fixture | matched seam | surplus seam | net |
|---|---|---|---|
| `narrowUpright` | 28 | 37 | -9, and -9 * 1.5^2 * (1 - pi/4) = -4.3457 |
| `lBracketStepSeamCentredTab` | 20 | 30 + 30 | -40, = -19.314 |
| `zBracket` | 50 + 20 | 30 | +40, = +19.314 |
| `uChannelStepped` | 80 + 80 | 10 x 4 | +120, = +57.943 |

This contradicted the builder's own documentation, which says the split leaves "the matched-extent
middle piece carrying the bend, and the outer pieces flat", and `build()`'s own comment that "the
post-union fillet only targets that piece's seam edges". It did not: the piece identity was never
used to bound the edge selection.

## The residual, and why it is not part of the defect

The corrected volumes sit 0.014 to 0.375 **under** the closed form, which is the fillet run-out
where the seam line carries on into a flat neighbour. Measured two ways:

- The cross-section is full to within 0.01 of the step and the surface stops about 0.1 past it. The
  harness classifies a point at radial distance 1.697 from the fillet axis (outside `r = 1.5`, so
  it should be solid) and one at 1.414 (inside the axis cylinder, so it should be air) along the
  seam: the first is `inside` for every x up to 28.01 and `outside` from 28.1, the second is
  `outside` throughout.
- **A control with the step removed and nothing else changed.** The same bend with the base trimmed
  to the upright's own width, so the seam line ends at the base's side faces rather than running on,
  gives 5725.519915705962 against a closed form of 5725.519915705961. That is the second
  construction that attributes the residual to the run-out rather than to the prediction.

## Why the convex fixtures were never wrong

`#2972`'s table compared against the raw sum of flange volumes. Each of the four convex parts has a
concave bend as well, and in three of them two flange bodies interpenetrate. Counting both:

| fixture | flanges | overlap | concave | convex | total |
|---|---|---|---|---|---|
| `symmetricZ` | 7200 | -180 | +405 (1 - pi/4) | +45 pi | 7248.285413235574 |
| `offsetLShortWeb` | 12600 | -240 | +135 (1 - pi/4) | +60 pi | 12577.466807156732 |
| `channelWithFlange` | 10800 | -180 | +320 (1 - pi/4) | +22.5 pi | 10759.358422418583 |
| `zBracketRepro` | 12672 | -460.8 | +460.8 (1 - pi/4) | +460.8 pi/4 | 12672 |

Each matches the builder to the last digit. `zBracketRepro` is the one that looked most like a bug,
because it lands exactly on its flange sum and so reads as a sharp square corner. It is not: there
`r = t = 3.2`, so the concave term `r^2 (1 - pi/4) L` and the convex term `(pi/4) t^2 L` sum to
`t^2 L = 460.8`, the same quantity the top/web overlap removed. The issue's reading accounted for
the convex corner and not the concave bend, which is how one number came out twice.

## A second defect, measured here and filed rather than fixed

The extent is read off the bend's own `aIntersection` rather than off the matched pieces, because
the matched pieces cannot be trusted to be the right ones. `splitFlange` names a flange's first
piece after the whole flange, and `splitFlange`'s matching loop only records a bend whose
intersection equals a single cell exactly. So a bend covering a flange's **full** width, on a
flange some *other* bend split, resolves to that first sliver. Measured on `zBracket`: bend 0
(`base` to `mid`, the full 50) resolved to `mid`'s x in [0, 15] piece.

It did not change `zBracket`'s answer, because OCCT's fillet propagates along the tangent-continuous
chain and recovered the other 35, and the plane tests are identical for every piece of one flange.
It is still wrong, and the convex path's `seamSegment(of: a, ...)` reads that piece's profile
directly with no propagation to save it. Filed as a separate issue with this measurement.
