# #1001: measured false-positive rates for the four re-sweep detectors

[#1001](https://github.com/SecondMouseAU/OCCTSwift/issues/1001) proposes re-sweeping the closed
passes with the detectors Pass 4a built, and states one precondition explicitly: measure each
detector's false-positive rate over a hand-adjudicated sample before anything acts on it. This
directory is that precondition. It is not the re-sweep.

The precedent is `Scripts/census-doc-occt-attribution.py`, measured in #928 at **41% false over a
40-row hand-adjudicated sample**, which is why it reports rather than gates. Everything here
follows that shape: a fixed sample committed as data, a `score_sample.py` that re-scores any later
version of a detector against the same rows, and rates that are never pooled across detectors.

## The four rates

| detector | population | sample | false-positive rate | recommendation |
|---|---|---|---:|---|
| `detect-hardcoded-arguments.py` | 27 (pre-4a tree) | **27, a census** | **81.5%** | do not re-sweep with it |
| `detect-hardcoded-arguments.py` | 23 (today) | **23, a census** | **91.3%** | as above |
| `detect-dead-parameters.py` | 13 (pre-4a tree) | **13, a census** | **0%** | use it, it is the strongest of the four |
| `occt-class-coverage.py` | 253 rows, 16 classes | **40, seed 1001** | **20.0% before, 0% after the fixes here** | use it as a screen, not as a metric |
| `shapetype_census.py` | 43 (pre-4a tree) | **20, seed 1001** | **0%**, but see the recall section | use it, and read the recall number with it |

Two of the four are censuses rather than samples: their populations were small enough to adjudicate
whole, which is strictly better than sampling and removes any question of draw luck.

```bash
python3 Scripts/repro/1001-detector-fp-rates/score_sample.py             # all five batches
python3 Scripts/repro/1001-detector-fp-rates/selftest_removal_matrix.py  # the two changed detectors
python3 Scripts/repro/1001-detector-fp-rates/verify_dead_parameters.py 90917a70
python3 Scripts/repro/1001-detector-fp-rates/measure_shapetype_recall.py
python3 Scripts/repro/1001-detector-fp-rates/sample_class_coverage.py
```

## Why the samples are drawn at two different trees

Three of the four detectors report **zero** on today's `main`, because Pass 4a fixed everything they
could see. A rate needs a non-empty population, so those batches are drawn at `90917a70`, Pass 4a's
own branch point, and `score_sample.py` exports that tree with `git archive` to score them. The
batch header names the tree; scoring against the wrong one makes the line-number matching nonsense
and the script says so rather than reporting a small number quietly.

For `detect-hardcoded-arguments.py` both trees are scored, and the pre-4a one is the fairer figure:
today's population has already had its true positives removed by being fixed, which flatters the
FALSE share.

---

## 1. `detect-hardcoded-arguments.py`: 81.5% false. Do not re-sweep with it.

**Two blind spots fixed first**, because measuring a detector that cannot see half its subject is
not measuring the detector. It scanned line by line, so any call `clang-format` wrapped at
ColumnLimit 100 was invisible; and its argument pattern forbade nested parens, so an argument that
is itself a call was invisible. Measured, the two together hid **10 of 23** call sites on today's
tree, 43% of the population. Both were found by review rather than by the tool, which is the point.

Fixing them was worth doing on its own: one of the ten hidden sites is a real defect.
`OCCTBisectorInterPointPoint` (`OCCTBridge_Geom2d.mm`, behind `bisectorIntersections`) clamps both
`IntRes2d_Domain` parameter ranges to a hardcoded `[-100, 100]` while accepting four arbitrary
caller-supplied points. `occt_1001_bisector_domain.mm` rebuilds the function twice, identical except
for that bound, and a meeting point at parameter 150 is **dropped by the shipped bound and found by
a bound derived from the input**. Two fixtures inside the bound are the control. That defect is
reported here and deliberately not filed, per the brief.

**Then the rate.** All 27 pre-4a findings and all 23 current ones were adjudicated, by hand, one at
a time. TRUE means the literal displaces something the caller supplied or something that should
follow from the input; FALSE means it does not.

- **5 TRUE of 27** on the pre-4a tree: the two `IntRes2d_Domain` rows above, and the three
  `Extrema_ExtPElC` parameter bounds #1024 already fixed.
- **2 TRUE of 23** today, both `IntRes2d_Domain`.

The FALSE rows are not close calls, and they were **measured rather than argued**.
`occt_1001_inert_literals.mm` sweeps each literal family across four orders of magnitude and prints
the result:

| family | sites | verdict |
|---|---|---|
| `GeomFill_SimpleBound` into `GeomFill_CoonsAlgPatch` | `Surface.mm:3379-3382` | INERT, byte-identical across the sweep |
| `GeomFill_BoundWithSurf` | `Surface.mm:4008` | INERT |
| `GeomFill_DegeneratedBound` | `Surface.mm:3952,3973` | INERT |
| `Extrema_ExtCS/ExtPS/ExtSS` `TolU,TolV` | `Curve3D.mm:3310,3338`, `Surface.mm:4843-4919` | see below |
| CONTROL `GCPnts_TangentialDeflection` | `Topology.mm:145,180` | MOVES |
| CONTROL `GeomFill_SimpleBound` into `GeomFill_ConstrainedFilling` | `Surface.mm:2180-2194` | MOVES |

**The two controls are the point, not decoration.** A sweep reporting "nothing moved" is
indistinguishable from one that cannot detect movement. The `GeomFill_SimpleBound` control matters
most, because it is the same class as the first row: `GeomFill_ConstrainedFilling` is the one class
in the package that actually reads `Tol3d()`/`Tolang()`, so it proves the harness can see movement
in that exact family.

**That control was a dud on the first attempt, and the fix is recorded rather than quietly made.**
It originally used the same four straight segments as the CoonsAlgPatch fixture, and came back
INERT: a quad of straight edges fits exactly as a 2x2, degree 1x1 surface at every tolerance, so it
could not have detected movement and proved nothing about the three rows reported inert beside it.
That is precisely the "fixture that has stopped meaning its name" failure `prove-the-test-fails.md`
describes. Rebuilt on curved, out-of-plane Bezier boundaries it moves from 107x107 poles at 1e-6 to
4x4 at 1.0. A second sub-fixture had the same problem: `Extrema_ExtSS` on two parallel planes
reports `IsParallel` and printed the same `-1` at every tolerance, so that third of the row was also
proving nothing. It is now a plane against a cylinder, with a real extremum.

### The Extrema row, and an assertion that was nearly weakened to make it pass

The wide sweep MOVES that family at tolerance 1.0, so its FALSE verdict cannot rest on inertness. A
first draft responded by loosening the comparison to a relative tolerance so the row would pass,
which is choosing a number to fit today's run, the same defect #726 exists to catch one level up.

Measured instead, five repetitions of a sweep from 1e-9 to 1e-2: **every row is byte-identical
across all five**, so there is no run-to-run spread and no tolerance to derive. What moves is a
deterministic function of the tolerance, with two step changes bracketing the shipped value:

```
Extrema_ExtCS squared distance steps at 1e-9 -> 1e-8   36.713066051563104 -> 36.713066047401135
Extrema_ExtSS squared distance steps at 1e-5 -> 1e-4   121               -> 121.00000000000033
```

So the plateau is 1e-8 to 1e-5, the shipped 1e-6 sits one order inside each edge, and the assertion
stays bit-identical over exactly that measured range. The relative-tolerance mode was deleted rather
than kept unused. `probe-output-extrema-plateau.txt` is the transcript.

### Recommendation

**Retire it, or rewrite the criterion.** At 81.5% false on the fairer population, four of every five
rows a re-sweep adjudicated would be a correct default with no caller-supplied source, and the
adjudication is not cheap: several rows needed a compiled probe against the pinned kernel to settle.
That is worse than #928's 41%, which was already judged too high to gate on.

The criterion is the problem, not the parser. "Two or more bare tuning literals in one call" has no
notion of whether the enclosing function has a parameter the literal could be displacing, which is
the shape #1020 actually describes. A detector that required a plausible caller-side source (a
`tolerance` parameter beside a hardcoded tolerance) would report a fraction of these and is a
different tool. Both real findings it has ever produced are the same narrow shape: **a hardcoded
parameter-domain bound on a caller-supplied geometry**. That shape is worth a targeted detector.

---

## 2. `detect-dead-parameters.py`: 0% false over a 13-row census. The strongest of the four.

**Three blind spots fixed, and all three cost zero findings, which is the useful thing to know.**

1. Every parameter whose name ended in `Ref` was exempt. The exemption existed to drop the
   twenty-three UNNAMED parameters in `OCCTBridge_BRepGraph.mm`'s deliberate ABI no-op stubs, and it
   did, but it also covered `curveRef`, `curve2dRef`, `curve3dRef` and `surfRef`, declared at more
   than a hundred sites. Replaced with the rule the exemption was reaching for: a parameter is
   unnamed when it reduces to a SINGLE token.
2. `extern "C"` on the definition line hid the whole function.
3. A parameter appearing only inside a string literal read as used.

Measured: both versions report **the same 13**, name for name, at `90917a70`, and both report zero
today. Every handle parameter is read, which is what a handle parameter almost always is; `extern
"C"` appears in `Sources/OCCTBridge/src/*.mm` only inside comments; and no parameter is mentioned
solely in a string. The corrections are proved by the fixture battery and by nothing in the tree.

**The claim was checked against a second construction.** `verify_dead_parameters.py` puts the
detector's "never read" verdict beside `clang -Wunused-parameter`, which decides the same question
from the parsed AST and shares no code with it:

```
tree: 90917a70
detector says unread : 14
clang says unused    : 14
agreed               : 14
```

Fourteen distinct `(file, parameter)` pairs, zero disagreement in either direction. That settles
claim (a), "never read". Claim (b), "and that is a defect", was checked separately: none of the 13
sites carries any note marking the parameter reserved or deliberately inert, and every one was
resolved in Pass 4a by either wiring the parameter to a real OCCT argument or deleting it. The tree
reporting zero today is the evidence that all 13 were acted on as defects.

### Recommendation

**Use it for the re-sweep.** It is cheap, its verdicts are checkable against the compiler, and its
adjudication cost is low because each row resolves by reading one function and one OCCT signature.

Two limits to carry, both already known and neither affecting the rate. It cannot see a parameter
that IS read but lands in the wrong OCCT argument slot, which is #1017's shape and produces a wrong
answer rather than an ignored one. And its 13 exclude `OCCTBridge_BRepGraph.mm`'s twenty-three
unnamed ABI stubs by design; whether Swift represents those no-ops faithfully is #1001's own open
question and this detector does not answer it.

---

## 3. `occt-class-coverage.py`: 20.0% false, fixed to 0% over the same 40 rows.

The detector prints a coverage ratio per class, but a ratio is not a finding anybody can act on. The
unit a re-sweep would act on is one NAME in its "not reached" list, asserting both that the name is
a public member function of the class and that the bridge never calls it. `sample_class_coverage.py`
draws 40 of those uniformly, seed 1001, from the 253 rows over the sixteen classes Pass 4a reported.

**8 of 40 were false, and the structure matters more than the rate: all eight are the same
direction.** Every one is something counted that is not a public member function, which inflates the
denominator and makes coverage look **worse** than it is. The detector was systematically biased,
not noisy. Four mechanical causes:

| cause | rows | example |
|---|---:|---|
| a default argument read as a method | 4 | `Perform(const Message_ProgressRange& theRange = Message_ProgressRange())` |
| a `private:` section scanned anyway | 2 | `GeomPlate_BuildPlateSurface::ProjectCurve` at `:218`, after `private:` at `:207` |
| a macro | 1 | `Standard_DEPRECATED("Use CoefPol()...")` at `Plate_Plate.hxx:105` |
| a call inside an inline body | 1 | `myConnection1.Location()` inside `GetPoint`, a call on a `gp_Ax2` member |

All four are fixed here, since none involves any judgement. Re-scored against the same 40 rows:
**8 FALSE removed, 0 TRUE lost**, population 253 to 207. The control classes move the right way too:
`BRepFeat_MakeCylindricalHole`, which CLAUDE.md documents as fully wrapped, goes from 88% to
**100%**, and `ShapeFix_Face` from 82% to 88%.

### Two things to keep separate

**`DumpJson` and `Set*` in the denominator are NOT false positives.** They are adjudicated TRUE:
they really are public member functions this bridge does not call. They are a reason the ratio is a
poor proxy for "how much of this class do we usefully reach", which is a question about the metric,
not a defect in it. No parser fix removes them and none should.

**Much of the adjudication turned on receiver identity rather than name matching**, and that is the
same failure mode as `shapetype_census.py`'s old `IsNull()`-anywhere guard test, one level over.
`G0Error`/`G1Error` are called in the bridge, but on a `BRepOffsetAPI_MakeFilling`;
`GetPresentation`/`HasPointText`/`SetPoint` on an `XCAFNoteObjects_NoteObject`; `ShapeTool` and
`GetID` as other classes' statics; `PerformUntilEnd` on a `BRepFeat_MakeCylindricalHole`. A
name-only census would have scored all eight of those as reached. This detector gets them right,
which is the half of it that works.

### Recommendation

**Use it as a screen, and read the ratio as a lower bound on coverage rather than as a measurement
of it.** At 0% false over 40 rows after the fixes it is the most accurate of the four, but its
output still needs a human to separate "we should wrap this" from "this is a setter we deliberately
never write". Fixing the four causes is what makes the numbers comparable across classes at all;
before it, a class with many defaulted `Message_ProgressRange` parameters scored artificially low.

---

## 4. `shapetype_census.py`: 0% false over 20 rows, and that is not a clean bill of health

**The `IsNull()`-anywhere defect is fixed on `main`**, checked rather than assumed: the version
there ties the guard to the argument, tracks local copies and reference bindings, knows the two
named bridge guard helpers, and carries a 14-case `--self-test` with a six-row removal matrix. It
reports **0** on today's tree, and `OCCTShapeGetType` now opens with
`if (!occtShapeIsPresent(shape)) return -1;`.

The 20-row sample is drawn at `90917a70`, where the population is 43. All 20 are TRUE. That is 0%
false.

**Read it with the recall number, not on its own.** The census's documented defect ran in the
opposite direction: accepting any `IsNull()` as a guard is a false-NEGATIVE problem, and it is why
#1026 was filed at fifteen sites when the real figure was 46. A detector that under-reports will
naturally show a low false-positive rate, so 0/20 is consistent with the known defect rather than
evidence against it. The two numbers measure different things.

`measure_shapetype_recall.py` measures the other one, against a ground truth the census had no part
in building: the set of bridge functions a human actually added a guard to in the two #1026 fix
commits.

```
ground truth (functions guarded by the #1026 fix commits) : 45
of the ground truth, reported                             : 29
raw recall                                                : 64.4%
recall WITHIN the census's stated subject                 : 100.0%
```

**All 16 misses are outside the stated subject, and that was measured rather than assumed.** The
census matches `ShapeType()` only, deferring the eight flag accessors to
`check-null-handle-guards.py`, which is the CI gate for this class. Every missed function was
checked for a `ShapeType()` read in its body at the pre-fix tree: **zero of the 16 has one**. Nine
are flag-accessor sites (`isFree`, `isConvex`, `setLocked` and siblings), four hand the shape to a
`TopoDS_Builder`, and three hand it to a kernel constructor that dereferences it. So there are no
blind spots inside the subject, and the raw 64.4% is a scope boundary rather than a defect.

### Recommendation

**Use it, and quote both numbers together.** Within what it claims to cover it is complete and
precise on this evidence. It is also the narrowest of the four by design, and the thing a re-sweep
would want, the whole null-shape class, is `check-null-handle-guards.py`'s third walk, which already
runs in CI on every PR. Re-sweeping with the census adds little that the gate does not already hold.

One caveat on the recall figure's independence: the ground truth is the set of sites #1026 fixed,
and #1026's own scoping used a corrected version of this census alongside probing. The parts that
are fully independent are the seven builder and kernel-dereference sites, found by probing, and
those are among the misses rather than among the hits.

---

## Files

| file | what it is |
|---|---|
| `adjudicated-sample.tsv` | the five batches, every row with a verdict and a reason |
| `score_sample.py` | re-scores any later version of a detector against those rows |
| `sample_class_coverage.py` | draws the class-coverage sample, seed 1001 |
| `verify_dead_parameters.py` | the detector against `clang -Wunused-parameter` |
| `measure_shapetype_recall.py` | recall against the #1026 fix commits, with the misses classified |
| `selftest_removal_matrix.py` | every guard of the two changed detectors switched off in turn |
| `occt_1001_bisector_domain.mm` | the one new real finding, measured |
| `occt_1001_inert_literals.mm` | the sweep behind the FALSE verdicts, with two controls |
| `probe-output-*.txt` | transcripts of the three probes |
