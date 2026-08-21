# #1054 / #1068, what `OCCTShapeSelfIntersectsBounded` was answering

Two issues about one bridge function, `OCCTShapeSelfIntersectsBounded`
(`Sources/OCCTBridge/src/OCCTBridge_Modeling.mm`), which backs
`Shape.isSelfIntersecting(timeout:)` and `Shape.isSelfIntersecting(hardTimeout:)`.

- **#1054**: it returned `1` ("self-intersects") for faults that are not a self-intersection,
  including the one OCCT records when the caller's own timeout aborts the analysis. Fixed.
- **#1068**: `isSelfIntersecting(timeout:)` returned `nil` for a bevel gear solid at every
  timeout from 1 ms to 20 s. Measured, not fixed: the check terminates and reports the shape
  clean, it just needs **339 s to 463 s** on this hardware.

## The two probes

Both compile against the pinned kernel with the command in `CLAUDE.md`'s "Compile a Ground
Truth C++ Test" section. Neither needs the Swift layer.

- `probe_fault_kinds.mm`, the analyzer call the bridge makes, printing the whole
  `BOPAlgo_CheckStatus` list rather than `HasFaulty()`, plus what the bridge returned before
  the fix and what it returns after, for the same run. `PROBE_VERBOSE=1` traces every progress
  poll and scope close, which is how the checkpoint-free stretches were located.
- `probe_break_point_sweep.mm`, the same call driven by a **break-at-the-Nth-poll** breaker
  rather than a clock, sweeping N over the whole analysis. A wall-clock watchdog only ever
  visits whichever abort point the machine happens to be at, so "can a timed-out check report a
  self-intersection on a clean solid" is a question about luck when asked that way. Sweeping
  break points makes it a count.

## #1054, measured

### The spurious `1` the issue could not observe, on a real timeout

#1054's own report says "Not proven: I did not directly observe the spurious `1`", because
`GetCheckResult` is not reachable from Swift. It is reachable from here, and the #319 artifact
at the default-ish 30 s bound produces it every time on an idle machine:

```
$ probe_fault_kinds Scripts/repro/319-selfintersection/dualskin_lateral.15.brep 1 30 30 30 30 30 30
timeout=30.0000 elapsed=30.038 firstTrip=30.026 polls=118 HasFaulty=1 statuses=[OperationAborted] before=1 after=-1
timeout=30.0000 elapsed=30.206 firstTrip=30.195 polls=130 HasFaulty=1 statuses=[OperationAborted] before=1 after=-1
timeout=30.0000 elapsed=30.069 firstTrip=30.043 polls=113 HasFaulty=1 statuses=[OperationAborted] before=1 after=-1
timeout=30.0000 elapsed=30.311 firstTrip=30.303 polls=142 HasFaulty=1 statuses=[OperationAborted] before=1 after=-1
timeout=30.0000 elapsed=30.329 firstTrip=30.315 polls=139 HasFaulty=1 statuses=[OperationAborted] before=1 after=-1
timeout=30.0000 elapsed=30.282 firstTrip=30.275 polls=159 HasFaulty=1 statuses=[OperationAborted] before=1 after=-1
```

6 of 6 idle, and 7 of 8 counting two earlier runs taken while a full `swift test` was using the
machine (the miss recorded nothing at all and answered `-1` either way, which is the same
`statuses=[]` those shorter timeouts give below). The whole result list is one
`BOPAlgo_OperationAborted`, with no `BOPAlgo_SelfIntersect` anywhere in it, and the pre-fix bridge
reports "self-intersects".

**This is also #772's row 4.** `Scripts/repro/772-analyze-self-intersection/README.md` records
`timeout: 30` on this artifact as returning "a conclusive `self-intersects` around 30.05-30.15s"
and builds an argument for `analyze()` preferring `timeout:` over `hardTimeout:` on it. That was
this abort. The correction is at the top of that file, and the choice of `timeout:` stands on its
other reasons.

Shorter bounds on the same artifact record nothing at all, which is worth knowing before trying to
hunt this with a clock:

```
$ probe_fault_kinds Scripts/repro/319-selfintersection/dualskin_lateral.15.brep 1 0.5 2 5
timeout=0.5000 elapsed=3.488 polls=5  trips=3 HasFaulty=0 statuses=[] before=-1 after=-1
timeout=2.0000 elapsed=4.488 polls=5  trips=3 HasFaulty=0 statuses=[] before=-1 after=-1
timeout=5.0000 elapsed=5.938 polls=77 trips=3 HasFaulty=0 statuses=[] before=-1 after=-1
```

An abort does not always leave a fault behind. Which is why the next section stops using a clock.

### A clean box, every abort point visited once

```
$ probe_break_point_sweep BOX 400
shape=BOX  polls in an uninterrupted run=381  break points swept=400
  (none)                                                     x332
  OperationAborted                                           x1
  SelfIntersect                                              x2
  SelfIntersect,SelfIntersect                                x7
  SelfIntersect,SelfIntersect,SelfIntersect                  x58
  SelfIntersect,SelfIntersect,SelfIntersect,OperationAborted x1
  first break point yielding OperationAborted: 379
  first break point yielding SelfIntersect:    312
  first break point yielding CheckUnknown:     -1
  first break point yielding BadType:          -1
  break points answering 1 before the fix:     69
  break points answering 1 after the fix:      0
```

A plain 10x10x10 box. Uninterrupted it is clean, and the analyzer records nothing. Interrupted
at any of break points 312 to 380 it records up to three `BOPAlgo_SelfIntersect` results, and
at 379 to 380 an `BOPAlgo_OperationAborted` as well. **69 of the 401 break points answered
"this shape self-intersects" before the fix.**

### Why a clean box has self-interferences to report at all

`BOPAlgo_CheckerSI::PostTreat` fills `BOPDS_DS::Interferences()` from the pave filler's raw
interference lists, skipping any pair that involves a shape the filler itself created
(`BOPDS_DS::IsNewShape`). Every adjacency interference of a valid solid does involve one, because
the filler splits at each intersection, so on a complete run the map comes out **empty**.
`BOPAlgo_ArgumentAnalyzer::TestSelfInterferences` then applies the same filter again on the way
out. Measured directly, running `BOPAlgo_CheckerSI` on the same box and breaking at the same
points:

```
breakAt=0    polls=378 tripped=0 HasErrors=0 sourceShapes=34 newShapes=13 interferences=0 surviving=0
breakAt=300  polls=308 tripped=1 HasErrors=0 sourceShapes=34 newShapes=0  interferences=0 surviving=0
breakAt=311  polls=312 tripped=1 HasErrors=0 sourceShapes=34 newShapes=0  interferences=1 surviving=1
breakAt=312  polls=313 tripped=1 HasErrors=0 sourceShapes=34 newShapes=0  interferences=2 surviving=2
breakAt=340  polls=345 tripped=1 HasErrors=0 sourceShapes=34 newShapes=4  interferences=3 surviving=3
```

The complete run creates 13 new shapes and ends with zero interferences. A run cut short creates
none, or too few, and the same adjacency pairs sail through the filter: one at break point 311,
two at 312, three by 340, which is exactly the one to three `BOPAlgo_SelfIntersect` results the
sweep above reports. Nothing is wrong with the box; the filter simply has nothing to match yet.

So the loss is not "PostTreat had not run". PostTreat *had* run in every row above (`HasErrors=0`,
so `BOPAlgo_CheckerSI::Perform` reached it). What was missing is the new shapes it filters on.

### A genuinely self-intersecting shape

```
$ probe_break_point_sweep OVERLAP 1500
shape=OVERLAP  polls in an uninterrupted run=1402  break points swept=1500
  ...
  first break point yielding OperationAborted: 1353
  first break point yielding SelfIntersect:    0
  break points answering 1 before the fix:     1473
  break points answering 1 after the fix:      99
```

Two 10-unit boxes overlapping by 5, in one compound. The 99 that still answer `1` are the
uninterrupted run (break point 0) and break points 1403 to 1500, which are past the end of the
analysis and so never fire. **Every interrupted run now answers `nil` instead of `true`.** That
is the deliberate cost of the fix, and it follows from the box measurement above: on an aborted
run a `BOPAlgo_SelfIntersect` result cannot be told from an artefact of stopping early.

### An argument the analyzer rejects

```
$ probe_fault_kinds EMPTY_SOLID 1 0 30
shape: an emptied solid (EmptyCopied of a box)
ArgumentTypeMode=1
timeout=0.0000 ... HasFaulty=1 statuses=[BadType] before=1 after=-1
timeout=30.0000 ... HasFaulty=1 statuses=[BadType] before=1 after=-1

$ probe_fault_kinds EMPTY_SOLID 0 0 30      # ArgumentTypeMode off
timeout=0.0000 ... HasFaulty=0 statuses=[] before=0 after=0
```

No timeout involved. `BOPTools_AlgoTools3D::IsEmptyShape` is true for a shape with no geometry
anywhere below it, so `TestTypes()` records `BOPAlgo_BadType` and `HasFaulty()` goes true before
the self-interference pass runs at all. The bridge enables `ArgumentTypeMode` for "basic argument
sanity" and then had no way to express the answer, so it said "self-intersects".

The second run is why the issue's alternative (drop `ArgumentTypeMode`) was not taken: it turns
the answer into `false`, "clean", which claims more than the analyzer established. `nil` is what
the Swift contract already has for "could not answer".

## The fix

Two changes, and the measurements above show neither is sufficient alone:

1. Read the watchdog **before** the results. Catches the 69 clean-box break points.
2. Read the results **by status** rather than through `HasFaulty()`. Catches `BOPAlgo_BadType`
   and `BOPAlgo_OperationAborted`, neither of which involves the watchdog at all.

Within (2), a status other than `BOPAlgo_SelfIntersect` wins over one, which is not obvious and
is deliberate. `BOPAlgo_OperationAborted` is appended *after* whatever the aborted pass had
already recorded, so a mixed `[SelfIntersect, SelfIntersect, SelfIntersect, OperationAborted]`
list is a real outcome: the box sweep produces exactly that at break point 379. The watchdog test
happens to cover it in both sweeps here, which is why the two "after the fix" counts are the same
either way. It does not cover it in general, for two reasons. `isSelfIntersecting(hardTimeout:)`
passes `0` to this function, so there is no breaker to test at all. And
`BOPAlgo_ArgumentAnalyzer::TestSelfInterferences` appends `BOPAlgo_OperationAborted` whenever
`BOPAlgo_CheckerSI::HasErrors()` is true, which includes a `Standard_Failure` inside the pave
filler (`BOPAlgo_AlertIntersectionFailed`) with no user break anywhere in it. On that path the
interference map is whatever the failed run left behind, which is the same untrustworthy thing an
interrupted run leaves.

`Tests/OCCTModelingTests/Issue1054SelfIntersectFaultKindTests.swift` covers both, one test each,
and the injection matrix in the PR shows each test failing for exactly one of them.

## #1068, measured, and why it is a report rather than a fix

The fixture is the issue's own: `BevelGear.build` from `SecondMouseAU/OCCTParts` with
`teeth: 36, mateTeeth: 36, circularPitch: 5, spiralAngle: .degrees(0), cutterRadius: .automatic,
slices: 5, shaftDiameter: 5`, exported to BREP. Rebuilding it takes about 82 s and gives volume
`19272.592112059167`, matching the volume quoted in #1068 to every digit it printed, with 1339
faces and 3938 edges. `export_bevel_gear.swift` is the exporter; the BREP itself is **not
committed**, at 3.8 MB raw and 867 KB gzipped it is not worth putting in every consumer's clone
when the recipe reproduces it exactly.

Reproducing the issue's table, on that BREP:

```
$ probe_fault_kinds bevel_gear_1068.brep 1 0.001 0.1 1 5 10 20
timeout=0.0010  elapsed=0.381    polls=5      trips=3     HasFaulty=0 statuses=[] after=-1
timeout=0.1000  elapsed=0.383    polls=5      trips=3     HasFaulty=0 statuses=[] after=-1
timeout=1.0000  elapsed=1.027    polls=156412 trips=42509 HasFaulty=0 statuses=[] after=-1
timeout=5.0000  elapsed=5.056    polls=521107 trips=97512 HasFaulty=0 statuses=[] after=-1
timeout=10.0000 elapsed=10.086   polls=521107 trips=97110 HasFaulty=0 statuses=[] after=-1
timeout=20.0000 elapsed=20.166   polls=521107 trips=94830 HasFaulty=0 statuses=[] after=-1
```

Same shape, unbounded, and then again through the bounded path with a budget larger than it
needs, so the answer does not rest on one run or on one code path:

```
$ probe_fault_kinds bevel_gear_1068.brep 1 0
timeout=0.0000   elapsed=462.504 polls=0      trips=0 threw=0 HasFaulty=0 statuses=[] after=0

$ probe_fault_kinds bevel_gear_1068.brep 1 600
timeout=600.0000 elapsed=339.086 polls=883232 trips=0 threw=0 HasFaulty=0 statuses=[] after=0
```

**It finishes, and the answer is "clean", both ways.** The unbounded run installs no progress
indicator at all, so patch `0010`'s breaker never polls; the 600 s run installs one, polls it
883232 times, and never trips. The two runtimes differ (462 s and 339 s) because the machine was
doing other work during the first, not because the answers differ: every reported field but the
elapsed time and the poll count is identical.

So the shape is not one the check can never answer for. 20 s is 4% to 6% of what it needs, and
there is no bridge defect here to fix: the ~0.38 s floor the issue noticed is the stretch before
the first progress poll, and past that the elapsed time tracks the requested timeout, which is
the cooperative watchdog working as documented (#293).

Two things the numbers say that are worth keeping:

- The poll count saturates at 521107 for every timeout of 5 s or more. Once the deadline has
  passed, patch `0010`'s breaker throws out of `Intf_Interference::Insert` for each remaining
  face in turn, so the tail after the deadline is bounded by the face count rather than by the
  remaining work. That is why elapsed tracks the deadline so closely (0.056 s over at 5 s,
  0.166 s over at 20 s) and it is the behaviour #319 bought.
- The last two rows differ by 4x in wall clock with an identical poll count, which is the same
  fact seen from the other side: the polls are dominated by the post-deadline unwind, not by
  the work that happened before it.

## Is #1054 a consequence of patch `0010`?

Partly, and the distinction matters for anyone reading #319 next to this.

The conflation is upstream and older than `0010`. `BOPAlgo_ArgumentAnalyzer::TestSelfInterferences`
has always recorded `BOPAlgo_OperationAborted` when its `BOPAlgo_CheckerSI` reports errors, and
`BOPAlgo_Options::UserBreak` has always added `BOPAlgo_AlertUserBreak` as one; `HasFaulty()` has
always been the union over every enabled mode; and the bridge has always read it first. The
`BOPAlgo_BadType` half needs no watchdog at all and is reachable on a stock kernel.

What `0010` changed is how often the aborted case is *reachable*. Before it, the
self-interference phase had no checkpoint below `BOPAlgo_CheckerSI::CheckFaceSelfIntersection`,
which is exactly why #319's artifact burned 619 s against a 30 s deadline without ever
returning: a deadline that cannot fire cannot produce an aborted result either. `0010` made the
abort prompt, which is the whole point of it, and promptness is what turns a latent wrong answer
into one a caller meets.

Which abort points record a fault is a separate question from how promptly they arrive, and the
first section above is that question measured: on #319's own artifact a 30 s bound records
`BOPAlgo_OperationAborted` every time, and a 0.5 s, 2 s or 5 s bound records nothing at all. So an
abort does not always leave a fault behind, and which bound you pick decides whether you meet the
defect. That is not a good property to leave a caller holding, and it is why the break-point sweep
exists: it answers the question without a clock in it.

## The same flag, read the other way round, forty lines up

`runBooleanEx` reads `OCCTBoolTimeoutBreaker::tripped()` **last**, only once
`BRepAlgoAPI_BooleanOperation::IsDone()` has already declined (#1067, PR #1079). This function
reads it **first**. That is one rule, not two: ask the watchdog only where the operation cannot
say for itself whether it finished.

A boolean can say, through `IsDone()`, so a completed build is kept even if a late poll happened
to trip. `BOPAlgo_ArgumentAnalyzer` cannot. It exposes no done flag; its result list is populated
identically whether it ran to the end or not; and the progress position is not a substitute,
because every `Message_ProgressScope` advances to its own end when destroyed. The verbose trace
of an aborted run shows exactly that:

```
$ PROBE_VERBOSE=1 probe_fault_kinds Scripts/repro/319-selfintersection/dualskin_lateral.15.brep 1 1
    [poll 1 at 0.000s]
    [poll 2 at 0.000s]
    [close Performing intersection of shapes    pos=0.032 at 0.001s]
    [poll 3 at 10.952s]
    [close (unnamed)                            pos=0.407 at 10.952s]
    [close Performing intersection of shapes    pos=0.640 at 10.952s]
    [poll 4 at 10.952s]
    [close Checking shape on self-intersection  pos=0.800 at 10.952s]
    [poll 5 at 10.952s]
    [close Analyze shapes                       pos=1.000 at 10.952s]
```

`pos=1.000` on a run that was cut short at 10.952 s of a 1 s budget. So `tripped()` is the only
completion signal available here, it is read first, and a late trip on an analysis that did in
fact complete costs a real answer. That is the smaller cost: the sweep above shows a clean box
interrupted anywhere in the last fifth of its analysis reporting up to three self-interferences.

That trace is also where the two long checkpoint-free stretches show up: nothing polls between
0.001 s and 10.952 s, which is `BOPAlgo_PaveFiller` running with no reachable checkpoint on this
artifact, and it is the same shape of gap #319 was about.

## Not fixed here

`Shape.selfIntersects` (`Sources/OCCTSwift/Shape+Topology.swift`, via `OCCTShapeSelfIntersects`
in `OCCTBridge_Properties.mm`) is a different, older function that returns
`BOPAlgo_CheckerSI::HasErrors()` directly. That is "the checker failed", not "the shape
self-intersects", and it never looks at `BOPDS_DS::Interferences()` at all. It is a separate
defect in a file this change does not own and wants its own issue.

`OCCTBOPAlgoAnalyzeArguments` (`OCCTBridge_Modeling.mm`) also reads `HasFaulty()`, and that is
**correct** there and deliberately untouched: it is asked "are these arguments usable for a
Boolean Operation", which is exactly the union `HasFaulty()` reports. It is the nearest sibling to
this fix and the one most likely to be mistaken for the same defect.
