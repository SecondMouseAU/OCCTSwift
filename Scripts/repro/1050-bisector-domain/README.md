# #1050, `OCCTBisectorInterPointPoint`'s hardcoded `[-100, 100]` domain

`OCCTBisectorInterPointPoint` (`Sources/OCCTBridge/src/OCCTBridge_Geom2d.mm`, behind
`bisectorIntersections(a:b:c:d:)`) built both `IntRes2d_Domain` parameter ranges as a fixed
`[-100, 100]`, under a comment calling it "a large parameter range". A meeting point past parameter
100 was dropped and the Swift face returned an empty array, which a caller cannot tell from "these
bisectors do not meet".

The issue's table is reproduced here as rows 1 to 3 of PART 3. The rest of this directory exists
because the choice of replacement was not obvious, and picking the plausible one would have been
wrong.

## Files

| file | what it is |
|---|---|
| `occt_1050_bisector_domain.mm` | the main probe, four parts, compile line in its own header |
| `probe-output.txt` | its transcript, quoted throughout this README |
| `build-discriminating-fixture.py` | solves for the fixture that separates the two candidate bounds |
| `occt_1050_review_findings.mm` | the second probe, which corrected two claims this README got wrong |
| `probe-output-review-findings.txt` | its transcript |

Build and run:

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1050-bisector-domain/occt_1050_bisector_domain.mm -o /tmp/occt_1050_bisector
/tmp/occt_1050_bisector
```

## PART 1, what a point-point bisector is

Measured, not assumed:

```
Value()                    Geom2d_TrimmedCurve
Value()->BasisCurve()      Bisector_BisecAna
Value()->FirstParameter()  0
Value()->LastParameter()   2e+100          (== Precision::Infinite())
BasisCurve NbIntervals()   1
Value(0)                   (0, 5)
Value(1)                   (-1, 5)
Value(-1)                  (1, 5)
```

It is a **half-line**: parameter 0 is the pair's midpoint, and negative parameters run off the
curve. So `[-100, 100]` spent half its width off the curve entirely and capped the live half at
100. Neither number had any relation to the caller's four points.

## PART 2, the domain is an input, not a filter

This is the question #1020's remedy turns on. `Extrema_ExtPElC`'s `Uinf`/`Usup` post-filter an
answer already computed, so widening them to `RealFirst()`/`RealLast()` could only admit more
correct results. `IntRes2d_Domain` is not that.

Read first, in `Bisector_Inter::Perform`
(`src/ModelingAlgorithms/TKTopAlgo/Bisector/Bisector_Inter.cxx`): it walks the basis curve's
continuity intervals, **skips** any interval that does not overlap the domain's parameter range,
clips the survivors with `UMin = max(IntervalFirst, MinDomain)` / `UMax = min(IntervalLast,
MaxDomain)`, and hands the clipped sub-domain to `Geom2dInt_GInter`. The domain decides which
sub-curve is presented at all, which makes it an input.

Two consequences fall out of the same read, and both were then measured.

**An unbounded domain is not spelled `IntRes2d_Domain()`.** That same line reads
`D1.FirstTolerance()` and `D1.LastTolerance()`, which raise `Standard_DomainError` when the domain
has no first or last point. Measured: every fixture throws, and the bridge's own `catch (...)`
would turn each into the empty result the bug already produced. It is the worst of the candidates,
not the cleanest.

**Widening costs nothing measurable.** Timing `Bisector_Inter::Perform` alone, with the bisectors
and both domains pre-built, 4000 iterations, best of three sweeps per run. One run is not enough to
say this: the first draft of this section quoted a single run in which the fix's own bound looked
2.3x slower than its neighbour, and the next run reversed the ordering. Nine runs, us per `Perform`:

| bound | n | min | median | max |
|---|---|---|---|---|
| shipped `+-100` | 9 | 0.41 | 0.62 | 0.63 |
| infinite domain | | | n/a, throws | |
| `RealFirst`/`RealLast` | 9 | 0.47 | 0.53 | 0.75 |
| `+-Precision::Infinite` | 9 | 0.47 | 0.54 | 0.72 |
| curve own range | 9 | 0.47 | **0.48** | 0.71 |
| `2 * input span + 1` | 9 | 0.47 | 0.54 | 2.56 |

Every median sits between 0.48 and 0.62. The **within**-bound run-to-run spread reaches 5.4x
(`2 * input span + 1`, 0.47 to 2.56) and dwarfs every **between**-bound difference, so the
between-bound numbers are scheduler noise and not a cost signal. The widest bound is not the slowest
one: the fix has the lowest median of the six, and the shipped narrow window the highest.

So being an input rather than a filter changes the *reasoning* (an unbounded domain is a real hazard
here and it throws, where for `Extrema_ExtPElC` it would have been free) without changing the
*answer* to the cost question. The `probe-output.txt` transcript in this directory is one run, so its
timing column will not reproduce exactly; every other line will.

## PART 3, which bound

Six candidates against ten fixtures. A bound is charged with a drop only when the closed-form solve
puts a meeting point on the live side of **both** half-lines and the bound reports nothing.

```
fixtures with a reachable meeting point that the bound drops:
  shipped +-100            2
  infinite domain          4
  RealFirst/RealLast       0
  +-Precision::Infinite    0
  curve own range          0
  2 * input span + 1       1
```

Two things this table settled that reading could not.

**The input-derived bound is wrong.** `2 * span + 1`, where `span` is the largest pairwise
separation of the four points, is the bound the issue's own scoping paragraph expected to be the
answer, and it is the bound the earlier `Scripts/repro/1001-detector-fp-rates` probe used to
demonstrate the defect. It passes all three of the issue's fixtures, because in each the meeting
point happens to sit inside it. It fails the fixture built to separate it:

```
10.9 degree crossing, u=150 past 2*span+1 (82.42)   curve own range: (-150.004, 5) u=150.004
                                                    2 * input span + 1: no intersection
```

The reason is geometric and not a corner case. For two bisectors crossing at angle `t`, with
midpoints `d` apart, the crossing sits about `d / sin(t)` from a midpoint, and `d` is bounded by the
input's span while `sin(t)` is not bounded below by anything. A crossing angle of 10.9 degrees, a
long way from parallel, already puts the answer at 1.8x the span. `build-discriminating-fixture.py`
solves for C and D from the wanted meeting point and asserts both conditions (`2*span+1 < u`, and
the crossing angle well away from parallel) so the fixture cannot quietly stop meaning its name.

**A bound derived from the input is still a fabricated number.** That is the point. It looks
principled because it is computed from the caller's own data, and it has no more claim on the
geometry than 100 did.

## The fix

Each domain is built from its own bisector's `FirstParameter()`/`LastParameter()`. That is not a
number chosen by anybody: it is the curve's own range, which `Bisector_Inter::Perform` clips the
domain against regardless, so the bridge simply stops narrowing OCCT's search. `RealFirst()`/
`RealLast()` and `+-Precision::Infinite()` measure identically on every fixture here, and the
curve's range is preferred because building the domain's (unused) endpoint at `RealLast()` means
evaluating the curve at 1.8e308 and overflowing to infinite coordinates, where the curve's own
endpoints are real points on it.

## PART 4, the rows every bound misses, and why they are not the bound's fault

Three fixtures in PART 3 have a closed-form crossing that no bound finds. PART 4 walks the crossing
out along the same half-line while holding the four points inside a box about 41 across, and reports
the crossing's parameter on each bisector **measured from the built curve** rather than derived from
the construction:

```
u          deg      u1 measured  u2 measured  2*span+1   curve own range        2 * input span + 1
50         39.81    50           39.0512      83.06      (-50, 5) u=50          (-50, 5) u=50
100        17.35    100          -83.8153     82.76      no intersection        no intersection
150        10.89    150          132.382      82.42      (-150, 5) u=150        no intersection
300        5.10     300          281.114      82.03      (-300, 5) u=300        no intersection
1000       1.46     1000         -980.319     81.75      no intersection        no intersection
3000       0.48     3000         -2980.1      81.66      no intersection        no intersection
10000      0.14     10000        -9980.03     81.63      no intersection        no intersection
100000     0.01     100000       -99980       81.62      no intersection        no intersection
```

Every miss has a **negative** `u2`: `Bisector_Bisec::Perform` kept the ray pointing away from the
crossing, so there is nothing there for any bound to find. Once conditioned on that, the curve's own
range finds every reachable row and the sequence is monotone. The apparent non-monotonicity (u=100
missed while u=150 and u=300 are found) is entirely that ray choice.

**This part does not support "there is no kernel accuracy limit", and a draft of this README said it
did.** Five of the eight rows have the ray pointing away, so the sweep never produced a live
crossing past u=300 and could not answer the question its own heading asks. The pre-PR review caught
it. `occt_1050_review_findings.mm` re-runs the sweep with C and D swapped whenever the ray points the
wrong way, so every row is live, and there **is** a limit:

| u | reported x | absolute error | relative |
|---|---|---|---|
| 1e2 | -100 | 1.1e-13 | 1.1e-15 |
| 1e4 | -10000 | 6.9e-11 | 6.9e-15 |
| 1e6 | -1000000.00001 | 1.0e-5 | 1.0e-11 |
| 1e8 | -100000000.073 | 0.073 | 7.3e-10 |
| 1e10 | -10000000613.7 | 614 | 6.1e-8 |

That is conditioning, not a defect: a crossing that far from both midpoints means two nearly
parallel half-lines, and the crossing's position is ill-conditioned in their angle. It is the fix's
own claim that needed narrowing, not the fix. `docs/reference/Shape-Recognition.md` now carries the
caveat, where the first draft said a crossing is found "however far" with no qualifier.

`occt_1050_review_findings.mm` also records a second thing the review found, unrelated to the bound:
two **coincident** bisectors overlap along their whole length, OCCT reports that as a segment rather
than a point, and this bridge function reads only `NbPoints()`, so the caller gets an empty array
for two bisectors that meet everywhere. Reversing one pair flips a ray and returns a single point
instead. Pre-existing, a different mechanism from this issue, and filed as
[#1070](https://github.com/SecondMouseAU/OCCTSwift/issues/1070) rather than folded in here.

This also corrected the probe itself. An earlier draft computed reachability from the four input
points, assuming the ray ran along `perp(B - A)` normalised because that is what the bridge passes
as `v1`. `Bisector_Bisec` picks a ray from the V1/V2/Sense sector and does not always pick that one,
so four rows were labelled reachable that are not, and the drop counts were wrong in the direction
that flatters every candidate. Reachability now reads the origin and direction off the built curve.
The crossing point itself stays closed-form.

## Test coverage and the removal matrix

`Tests/OCCTGeom2dTests/Issue1050BisectorDomainTests.swift`, six tests. Three injections, each run
against the real bridge, with disjoint failure sets so each isolates a different mechanism:

| injection | tests failing (of 6) | which |
|---|---|---|
| the shipped `[-100, 100]` | 2 | past-old-window, past-input-extent |
| `2 * span + 1` | 1 | past-input-extent |
| unbounded `IntRes2d_Domain()` | 3 | past-old-window, **inside**-old-window, past-input-extent |
| the fix, curve's own range | 0 | |

The second row is the one that matters for the choice of bound: it is wider than 100 and passes the
issue's own fixture, so only the discriminating test separates it from the fix. The third row fails
a control the shipped code passes, which is the throw reaching `catch (...)`.

**Three of the six tests fail under no injection at all**, and they are labelled regression guards in
the suite rather than counted as coverage. `parallelBisectorsReportNothing`,
`crossingOnDeadSideReportsNothing` and `coincidentPointsReturnNothing` are provably insensitive to
the bound: `Bisector_Inter::Perform` re-clips any domain to `max(IntervalFirst, MinDomain)`, so no
domain choice can produce a point where the half-lines do not meet (a symmetric
`[-LastParameter, LastParameter]` domain still yields zero on both), and the coincident-points case
throws in `gp_Vec2d::Normalize()` before a domain is built. They keep "reported nothing" meaningful,
which is the distinction the whole issue turns on, so they are worth having. Labelling them is the
point: an unlabelled test that cannot fail looks exactly like coverage.

## Sibling sites

The bridge constructs `IntRes2d_Domain` in exactly **two** places, `d1` and `d2` in this one
function, both the same defect and both fixed. Nothing else in `Sources/` names `IntRes2d`,
`IntCurve_Int*` or `Geom2dInt_GInter`. The other 2D intersection entry points,
`OCCTCurve2DIntersect` and `OCCTCurve2DSelfIntersect`, go through `Geom2dAPI_InterCurveCurve`, which
takes no domain and uses the curves' own ranges, so they are not this shape and are left alone.
