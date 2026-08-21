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
| `occt_1050_review_findings.mm` | the second probe, which corrected three claims this README got wrong |
| `probe-output-review-findings.txt` | its transcript |
| `occt_1050_regression_sweep.mm` | 16000 randomised configurations, shipped bound against the fix |
| `probe-output-regression-sweep.txt` | its transcript |
| `matrix.sh` | generates the removal matrix below, injection by injection |
| `probe-output-matrix.txt` | its transcript, which is where the matrix table comes from |

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
long way from parallel, already puts the answer at 3.69x the span (u 150.0042 against span
40.7108). An earlier draft said 1.8x, which is u divided by the `2*span+1` **bound**, 82.4217, and
so is the adjacent number rather than the one the sentence names. `build-discriminating-fixture.py`
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
curve's range is preferred because it is not a chosen number at all: you ask the curve what it
covers, and nothing has to be justified.

An earlier draft justified it differently and was wrong. It claimed `RealLast()` "means evaluating
the curve at 1.8e308 and overflowing to infinite coordinates". Measured against the pinned kernel,
it does not: the direction is a unit vector, so `Value(RealLast())` is `(-1.7976931348623157e+308, 5)`
for the axis-aligned bisector and `(1.51664e+308, -9.65137e+307)` for an oblique one, both finite.
The choice between the three wide bounds is genuinely free, PART 3 shows them answering identically,
and the reason to take the curve's own is that it needs no argument, not that the alternatives break.

## PART 4, the rows every bound misses, and why they are not the bound's fault

Two fixtures in PART 3 have a closed-form crossing that no bound finds, both `near-parallel` rows.
(Drafts of this line said three, and the probe's own header and body said "three" and "One row", so
the same count was stated three times with three values. Counted off PART 3's ten rows: the two
parallel rows and the two collinear/coincident pairs have no closed-form crossing to miss, and the
10.9-degree row is found by three of the six bounds.) PART 4 walks the crossing
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
it, `occt_1050_review_findings.mm` re-runs the sweep with C and D swapped whenever the ray points
the wrong way, so every row is live.

**The replacement claim was then wrong too, in the opposite direction, and it is worth reading how.**
The corrected sweep printed errors of 0.073 at u=1e8 and 614 at 1e10 and this README published them
as a kernel accuracy limit. They are not. The error was taken against the construction's *intended*
target, `-u`, and the fixture actually passes C and D rounded to a representable double, which puts
the true crossing somewhere else entirely. Measured against a closed-form solve of **the C and D
actually handed in**, the kernel is right to about 1e-16 relative at every u out to 1e10:

| u | reported x | closed form of the same input | error vs closed form | intended target, for contrast |
|---|---|---|---|---|
| 1e2 | -100 | -100 | 1.4e-14 (1.4e-16 rel) | 1.3e-13 |
| 1e6 | -1000000.00001 | -1000000.00001 | 1.2e-10 (1.2e-16 rel) | 1.0e-5 |
| 1e8 | -100000000.073 | -100000000.073 | 0 | 0.073 |
| 1e10 | -10000000613.7 | -10000000613.7 | 1.9e-06 (1.9e-16 rel) | 614 |

The last column is the whole of the "limit" the previous draft reported. So the caveat that belongs
in the reference doc is not "the kernel loses accuracy far away" but "a distant crossing is
ill-conditioned **in the input**": nearly parallel bisectors mean a one-ulp change in a coordinate
moves the crossing by hundreds of units, which is a fact about the caller's data rather than about
the computation. The two read similarly and imply opposite advice, and this is the third time on
this issue that a number measured of the thing next to the subject was published as a number
measured of the subject.

`occt_1050_review_findings.mm` carries two more things, neither about the bound.

**Coincident bisectors.** Two bisectors that overlap along their whole length are reported by OCCT
as a segment rather than a point, and this bridge function reads only `NbPoints()`, so the caller
gets an empty array for two bisectors that meet everywhere. Reversing one pair flips a ray and
returns a single point instead. Pre-existing, a different mechanism from this issue, filed as
[#1070](https://github.com/SecondMouseAU/OCCTSwift/issues/1070) rather than folded in here.

**The complete set of empty results, derived rather than listed.** The reference doc enumerated
these by hand and undercounted twice, first at two and then at three; the second correction added
the item the review named instead of re-deriving the set, which is why it was still short. Part f3
walks one case per branch and prints the mechanism, and the partition closes by construction: either
a bisector does not exist (a coincident pair), or both do, and then the two underlying lines are
parallel-distinct, identical, or cross at one point that is on both kept rays or is not. Four.

## The no-regression sweep

Ten hand-picked fixtures can show the fix finds something the old window dropped. They cannot show
it never **loses** one, never **moves** one, and never **invents** one, because those are claims
about the whole input space. `occt_1050_regression_sweep.mm` runs both bodies over randomised
four-point configurations at four scales, fixed seed so the numbers are re-derivable rather than a
fresh sample each time:

| scale | cases | both found | neither | gained | lost | moved | bogus | worst equidistance |
|---|---|---|---|---|---|---|---|---|
| 1e-3 | 4000 | 1006 | 2994 | 0 | 0 | 0 | 0 | 0 |
| 1 | 4000 | 985 | 3011 | 4 | 0 | 0 | 0 | 2.18e-16 |
| 1e3 | 4000 | 14 | 3006 | 980 | 0 | 0 | 0 | 2.29e-15 |
| 1e6 | 4000 | 0 | 3031 | 969 | 0 | 0 | 0 | 3.69e-15 |

**16000 cases: 1953 gained, 0 lost, 0 moved, 0 bogus.** It exits non-zero if any of the last three
is not 0, so it is a check rather than a printout. The scale column is why the shipped window looked
adequate for so long: at scale 1 it drops 4 crossings in 4000, and at 1e3 it drops 980.

**The three zeros do not all rest on 16000, and the headline reads as though they do.** `gained` and
`bogus` are over all 16000. But `lost` and `moved` can only fire where the **shipped** body found a
crossing, which is the `both` column plus `lost`, so **2005** cases, and **none of the 4000 at scale
1e6**, where the old window found nothing at all. So "never loses one, never moves one" is
established over 2005 opportunities concentrated at the small scales, not over the whole sweep. That
is still the entire population where the two could possibly differ, which is why the sweep is worth
running, but the denominator is 2005 and quoting 16000 next to it borrows a bigger number than the
claim earns.

`bogus` is the "never invents one" half, and the first draft of this probe claimed that while
counting only lost/moved/gained, which checks no gained crossing at all. Every gained crossing is
now validated on its own terms, with no reference to what either body computed: equidistant from
both point pairs, and at non-negative parameter on both kept rays. Worst relative equidistance error
over all 1953: **3.69e-15**.

The check was proved to fire rather than trusted, and the proof is a committed switch rather than a
quoted number nobody can reproduce:

```bash
OCCT_1050_NUDGE_GAINED=1 /tmp/occt_1050_sweep     # displaces every gained crossing before validating
```

It flags **1951 of 1953** and exits 1, per scale 0/0, 4/4, 980/980, 967/969. The two it still passes
are both in the 1e6 row, and the reason is not established here; at that scale a crossing can sit
far enough away that a nudge of 1000 stays inside the relative equidistance tolerance. Two
unexplained passes out of 1953 do not weaken the check enough to chase further, and the number is
recorded rather than rounded to "all of them".

This also corrected the probe itself. An earlier draft computed reachability from the four input
points, assuming the ray ran along `perp(B - A)` normalised because that is what the bridge passes
as `v1`. `Bisector_Bisec` picks a ray from the V1/V2/Sense sector and does not always pick that one,
so four rows were labelled reachable that are not, and the drop counts were wrong in the direction
that flatters every candidate. Reachability now reads the origin and direction off the built curve.
The crossing point itself stays closed-form.

## Test coverage and the removal matrix

`Tests/OCCTGeom2dTests/Issue1050BisectorDomainTests.swift`, seven tests, plus the three in the
pre-existing `BisectorIntersectionTests` this PR gave real assertions to. Ten in total, against six
injections, each compiled and run against the real bridge.

The failure sets are **not** disjoint, and an earlier draft of this paragraph claimed they were.
B's set is a strict subset of A's, and E and F are identical to each other. What each row buys is
therefore worth stating one at a time rather than asserting as a property of the table:

Every row below is measured by `matrix.sh`, which applies each injection, runs the ten tests,
captures the failing test **names** rather than a count, restores the file and verifies the restore
is byte-identical. That mechanism is not decoration. The first version of this table was carried
over from a six-test suite with its denominator edited to nine and its counts left alone, and two of
its rows were wrong; a hand-maintained matrix is the same kind of artifact as the hand-maintained
cause list two sections up, and it failed the same way.

| injection | fails (of 10) | which |
|---|---|---|
| **A** the shipped `[-100, 100]` | 2 | past-old-window, past-input-extent |
| **B** `2 * span + 1` | 1 | past-input-extent |
| **C** unbounded `IntRes2d_Domain()` | 6 | every test that expects to find something |
| **D** swap `pC`/`pD` into `b2.Perform` | 5 | all three ray tests, plus past- and inside-old-window |
| **E** `Sense` flipped to `-1.0` | 2 | past-input-extent, documented-example |
| **F** `perpCD` negated | 2 | past-input-extent, documented-example |
| the fix, curve's own range | 0 | |

What each row establishes, given the sets overlap:

- **A** is the defect as shipped, and it is the baseline the others are read against.
- **B** is the row that decides the *choice* of bound. Its single failure is a strict subset of A's
  two, which is exactly the point: B is wider than 100 and passes the issue's own fixture, so
  nothing except the discriminating test can tell it apart from the fix. A subset relation is what
  makes B informative here, not a flaw in it.
- **C** fails a control that A and B both pass, which is the `Standard_DomainError` reaching
  `catch (...)` and turning every input into an empty result. That extra failure is what separates
  "too narrow" from "refuses everything".
- **D** is the only row that moves the ray tests, and it moves them in both directions: the
  as-written ordering starts finding `(5, 5)` where it must find nothing, and the reversed ordering
  stops finding it.
- **E** and **F** have identical failure sets, so the second adds no discrimination over the first.
  It is kept and labelled as adding none, because the question it answers ("is this input inert?")
  was answered wrongly once already and the answer is worth being able to re-derive.

**Rows E and F were published as "inert" and are not.** Reaching row D took three attempts, and the
first two, flipping `Sense` and negating `perpCD`, left the three ray tests green. That was read as
"neither is load-bearing", with a mechanism written to explain it:
`Bisector_BisecAna::Perform`'s point-point overload takes the ray from
`GccAna_Pnt2dBisec(afirstpoint, asecondpoint)`, whose line follows the point order, and the bridge
passes `v3` and `v4` as exact opposites, which makes the sector test in `Distance()` degenerate. The
mechanism is right about the ray tests and the conclusion drawn from it was too broad: measured
against the whole suite, E and F each fail two. They are inert for the fixtures that were being
watched, not inert, and `matrix.sh` no longer labels them with the retracted word.

That is the same mistake as the accuracy claim above and as the matrix denominator: a measurement
taken of part of the subject, published as a measurement of the subject. Three instances on one
issue is why every count in this file now names what was measured and over what.

**Three of the ten tests fail under no injection at all**, and they are labelled regression guards in
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
