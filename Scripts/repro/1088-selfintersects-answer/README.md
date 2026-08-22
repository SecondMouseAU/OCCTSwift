# #1088, what `Shape.selfIntersects` was answering

`OCCTShapeSelfIntersects` (`Sources/OCCTBridge/src/OCCTBridge_Properties.mm`), which backs
`Shape.selfIntersects`, returned `BOPAlgo_CheckerSI::HasErrors()`. That is `BOPAlgo_Options`'
"did this algorithm fail" flag, not "did it find an interference". The result of the check lives in
`BOPDS_DS::Interferences()`, which the function never read.

#1088 was filed by inspection of the source, and its closing line is that nobody had checked
whether any shape actually gets a wrong answer from it. That is what this directory settles.

## The probes

Both compile against the pinned kernel with the command in `CLAUDE.md`'s "Compile a Ground Truth
C++ Test" section, and neither needs the Swift layer.

- `probe_checker_answer.mm` runs the bridge's own call sequence on seven fixtures and prints both
  readings side by side: `HasErrors()`, which is what the bridge returned, and the interference map
  walked the way `BOPAlgo_ArgumentAnalyzer::TestSelfInterferences` walks it. It also runs a **second
  construction** of the same question, `BOPAlgo_ArgumentAnalyzer` with only `SelfInterMode` enabled,
  which is the path `Shape.isSelfIntersecting(timeout:)` takes.
- `probe_error_ordering.mm` sweeps a break point over the whole analysis of a clean box, to
  establish why the fix tests `HasErrors()` before reading the map. Technique borrowed from
  `Scripts/repro/1054-selfintersect-fault-kinds/`.

Transcripts of both are committed next to them.

## The answer is wrong on every shape that self-intersects

```
fixture           faces   hasErr  mapSize   surviv involNew tolMoved   bridge   correct
BOX                   6        0        0        0        0       no   false    false
DISJOINT_BOXES       12        0        0        0        0       no   false    false
OVERLAP_BOXES        12        0       20       20        0       no   false    true
OVERLAP_SPHERES       2        0        2        2        0       no   false    true
BOWTIE_PRISM          4        0        3        3        0       no   false    true
EMPTY_SOLID           0        0        0        0        0       no   false    false
MULTI_ARG             6        1        0        0        0       no   true     false
```

Three independent constructions of "genuinely self-intersecting", chosen so that an answer holding
across them is not holding because of anything specific to one primitive: two overlapping boxes in a
compound, two overlapping spheres (a different primitive and a curved surface type), and a single
solid whose own walls cross, a bowtie profile swept into a prism. **All three reported `false`.**
This is not a defect that fires sometimes; on this evidence the property never returned `true` for a
shape that self-intersects.

`MULTI_ARG` is the defect in the other direction, and it is the clearest demonstration that the two
questions are different: the same clean box, handed to the checker twice, records
`BOPAlgo_AlertMultipleArguments`, and the old code called that "self-intersects". It is not
reachable through the bridge, which appends exactly one shape, so it is a demonstration rather than
a live path.

The second construction agrees with the corrected reading on all seven rows: the `surviving` count
equals the number of `SelfIntersect` statuses `BOPAlgo_ArgumentAnalyzer` reports (20, 2 and 3 on the
three positive rows, none on the four negative ones). The full status column is in the transcript.

`involNew` is 0 on every row, so the `IsNewShape` skip never fires on these fixtures. It is kept
because `TestSelfInterferences` has it and this code is meant to read the map the same way, not
because it was observed doing anything here.

`tolMoved` is `no` everywhere. The bridge does not call `SetNonDestructive(true)` the way
`TestSelfInterferences` does, so the checker is permitted to modify the input shape's tolerances in
place; measured, on these fixtures, it does not. Recorded rather than acted on.

## Is anything in the test suite currently getting a wrong answer?

**No.** `selfIntersects` had exactly one call site in the whole repo,
`Tests/OCCTTopologyTests/OCCTTopologyTests.swift`'s "Box does not self-intersect", which asserts a
clean 10x10x10 box answers `false`. Row `BOX` above shows that is `false` both before and after the
fix, so the suite passed for the right reason by luck: it only ever asked the one question the old
code happened to get right.

That changes the urgency and not the verdict. The property was wrong for every caller who asked it
about a shape that actually self-intersects, and nothing in the suite would ever have noticed.

## Why the fix tests `HasErrors()` first

`BOPAlgo_CheckerSI::Perform` reaches `PostTreat()`, which is what leaves the map holding only
genuine interferences, exactly when `HasErrors()` is false: every other exit either sets an error
(`BOPAlgo_AlertMultipleArguments`, the `VZ`/`EZ`/`FZ`/`ZZ` error return, the
`catch (Standard_Failure const&)` that adds `BOPAlgo_AlertIntersectionFailed`) or is a user break.

The user break is the interesting one, and the sweep is about it:

```
complete run:  hasErrors=0  surviving=0
 breakAt  hasErrors  surviving
     310          0          1
     311          0          1
     312          0          2
     377          1          3
     378          1          0
break points swept:                                  400
  ... leaving a non-empty surviving map:             68  (first at 310)
  ... answering "self-intersects" WITHOUT the HasErrors test: 68
  ... answering "self-intersects" WITH the HasErrors test:    67
```

A clean box, interrupted, leaves up to three pairs in the map, because
`CheckFaceSelfIntersection`'s first two statements clear it and a run stopped before that point is
read against `BOPAlgo_PaveFiller`'s own raw pairs instead. #1054 measured the same transition from
the other side.

**`HasErrors()` does not catch 67 of those 68, and that needed explaining rather than publishing.**
Exactly two break points in the whole sweep record an alert, 377 and 378, and they are the two that
land on `BOPAlgo_CheckerSI::Perform`'s own `UserBreak(aPS)`, which is `BOPAlgo_Options::UserBreak`
and does call `AddError`. Only one of those two, 377, is among the 68, since 378 lands after
`CheckFaceSelfIntersection` has cleared the map and so leaves `surviving=0`. That is the arithmetic:
68 non-empty rows, 1 of them flagged, **67 not**.

Those 67 are consumed inside a `BOPAlgo_PaveFiller` phase, whose loops are written
`for (...; i < n && aPS.More(); ++i)`, and `Message_ProgressScope::More()` is defined as
`!UserBreak()`. The loop simply stops early, the phase returns normally, `PerformInternal`'s
`if (HasErrors()) return;` sees nothing, and the run walks to a "successful" end having done partial
work. Confirmed by dumping the report: the alert list is empty on those rows.

None of that is reachable through this bridge function. It calls `Perform()` with a default
`Message_ProgressRange`, and `Message_ProgressScope::UserBreak()` is
`myProgress && myProgress->UserBreak()`, so with no indicator installed it is always false and no
break can occur anywhere. That is what makes `HasErrors() == false` mean "the run completed" here,
and the sweep is the standing warning that **giving this call a timeout would take that away**,
which is exactly the trap #1054 fixed one function over.

## The direction, and the trade

Both were done: the answer is fixed, and the property is deprecated.

Fixing alone was not enough, because the return type is `Bool` and the correct answer to this
question is not always a `Bool`. A check that fails cannot be expressed, and `false` therefore means
both "clean" and "could not answer". The call is also unbounded, with #319 measuring 619 s on one
artifact and #1054's own work measuring 339 s to 463 s on an ordinary bevel gear.
`isSelfIntersecting(timeout:)` answers the same question with a bound and a `Bool?` that says `nil`
for indeterminate.

Deprecating alone was not enough either, because a deprecation warning does not stop a wrong answer
reaching anyone who ignores it, and the wrong answer was a false negative on every self-intersecting
shape tested. A health check that misses the defect it exists to find is the worse failure.

Migration cost, measured rather than assumed: `selfIntersects` has one definition site and **no
call sites in `Sources/`**, one call site in the tests, and across the local ecosystem checkout
exactly one downstream caller, `OCCTSwiftViewport/Examples/MetalDemo`'s `SelectionManager.swift`,
which prints it into an info string. Every other ecosystem hit for the name is a local 2D polygon
helper of the same name in OCCTReconstruct and OCCTDesignLoop, unrelated to this property.

## What the tests cover, and what they do not

`Tests/OCCTTopologyTests/Issue1088SelfIntersectsAnswerTests.swift`, run against the shipped fix and
three injected bodies. Each injection is the real pre-#1088 code or one half of it.

| body | runs | outcome |
|---|---|---|
| shipped fix | 5 | 5/5 complete, all 7 tests pass |
| A, the pre-#1088 body (no guard, `HasErrors()` returned) | 5 | **4/5 SIGSEGV**; the one completing run fails 4 tests |
| B, null-shape guard removed only | 15 | **12/15 SIGSEGV**; the 3 completing runs pass all 7 |
| C, map reading reverted only | 3 | 3/3 complete, **3 tests fail** every time |
| D, `HasErrors()` early return dropped | 3 | 3/3 complete, all 7 pass |

**This table is a correction, and the first version of it was wrong in a way worth recording.** It
originally reported rows A and B from a single run each, and reported row B as green with the
conclusion that "no Swift test covers the null-shape guard". Repeating the rows shows the opposite:
removing the guard kills the process on **12 of 15 runs**. The single run I generalised from was one
of the 3 where the unguarded call returns `HasErrors()` instead of faulting, which is exactly the
state-dependence the guard exists for. One observation of a nondeterministic outcome is not a
measurement of it, and the first figure published here, 4 in 5, was itself only n=5 and is
superseded by the 15-run aggregate.

So the corrected reading is:

- **Row A** is the real defect, and it is caught twice over: as a crash on most runs, and as four
  failing assertions on the runs that survive.
- **Row B, the null-shape guard, is covered**, by process death rather than by a failed expectation.
  That means a green run of this file is weaker evidence than it looks: it can mean the guard is
  present, or it can be one of the 3 in 15. The deterministic evidence is `probe_checker_answer.mm`'s
  `NULL_SHAPE` fixture, which faults every time in a standalone process, and which is why that
  fixture is excluded from the committed transcript.
- **Row D, the `HasErrors()` early return, is the one guard genuinely not covered.** None of the
  fixtures errors, so nothing distinguishes the two bodies. Its justification is the structural
  argument above plus the sweep, not a test, and it is reported as uncovered rather than claimed.
- **Row C** is deterministic: 3/3 runs, the same 3 tests failing (both overlap fixtures and the
  agreement test).

The fixture control passes under every row by design: it asserts the two boxes are 1000 each and
fuse to 1500, so a fixture that silently stopped overlapping would be visible. That is the failure a
removal matrix structurally cannot see, and without it the two positive tests would pass for the
wrong reason if the overlap ever went away.

**The fixture control has its own injection, because a removal matrix cannot produce one.** Moving
the second box from `origin: (5,0,0)` to `(50,0,0)`, so the fixture silently stops overlapping,
fails `overlapFixtureActuallyOverlaps` on the fused volume (2000 against the expected 1500) **and**
`overlappingBoxesReportSelfIntersection` together. That pairing is the point: without the control,
the only signal would be "overlapping boxes are not reported", which reads as a bridge regression
rather than a dud fixture. `answerAgreesWithTheBoundedSpelling` stays green under that injection,
correctly, since both spellings agree on a compound that genuinely does not overlap.

The control reaches into `overlappingBoxes()` rather than rebuilding an equivalent pair, which a
late self-review corrected: a control that builds its own copy proves a different pair of boxes
overlaps, not the one under test.

Row A's nullified failure is worth reading carefully. On the runs where the process survives, that
test fails because the old body answered `true` for a shape with no content, which is the false
positive #1088 predicted and is reachable from Swift. That assertion failure and the crash on the
other four runs are two different defects arriving through the same input, and the guard removes
both.

## Not fixed here

- **`SetNonDestructive(true)`.** `TestSelfInterferences` sets it and this function does not, so the
  checker may modify the caller's own shape. Measured as not happening on these seven fixtures, and
  left alone rather than changed on a fixture set that cannot demonstrate the difference.
- **`check-null-handle-guards.py` is blind to this site.** Its three walks key on a parameter's
  declared type reaching a listed entry point, and the shape here is appended to a
  `TopTools_ListOfShape` before `SetArguments`/`Perform` ever see it, which is an indirection none of
  `SHAPE_DEREF_RECEIVERS`, `SHAPE_DEREF_QUALIFIED` or `SHAPE_DEREF_CTORS` can follow. Teaching it
  the list-indirection shape is real work and is not attempted here; recorded so the gap is known
  rather than silent.
