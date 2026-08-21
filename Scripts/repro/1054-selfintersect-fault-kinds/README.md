# #1054 / #1068, what `OCCTShapeSelfIntersectsBounded` was answering

Two issues about one bridge function, `OCCTShapeSelfIntersectsBounded`
(`Sources/OCCTBridge/src/OCCTBridge_Modeling.mm`), which backs
`Shape.isSelfIntersecting(timeout:)` and `Shape.isSelfIntersecting(hardTimeout:)`.

- **#1054**: it returned `1` ("self-intersects") for faults that are not a self-intersection,
  including the one OCCT records when the caller's own timeout aborts the analysis. Fixed.
- **#1068**: `isSelfIntersecting(timeout:)` returned `nil` for a bevel gear solid at every
  timeout from 1 ms to 20 s. Measured, not fixed: the check terminates and reports the shape
  clean, it just needs **339 s to 463 s** on this hardware.

## The three probes

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
- `probe_interference_map.mm`, one level down: `BOPAlgo_CheckerSI` driven directly, printing the
  state `TestSelfInterferences` reads afterwards. Its columns are chosen to separate the candidate
  explanations rather than to illustrate one, which is what caught two wrong explanations of this
  same behaviour.

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

**This section was wrong twice before it was measured properly, and the correction is the point.**
The first version said `BOPAlgo_CheckerSI::PostTreat` "discards the adjacency interferences and
runs last". The second said `PostTreat` fills `BOPDS_DS::Interferences()` while skipping every pair
involving a shape the pave filler created, so the `BOPDS_DS::IsNewShape` filter empties the map on a
complete run. Both are wrong, and the second was contradicted by a column in its own transcript that
nobody read. `probe_interference_map.mm` prints that column deliberately:

```
$ probe_interference_map 0 100 300 311 312 340 375 376 377 378 379 400
breakAt=0   polls=378 tripped=0 hasErrors=0 newShapes=13 ffRaw=12 mapSize=0 involvingNew=0 surviving=0
breakAt=100 polls=101 tripped=1 hasErrors=0 newShapes=0  ffRaw=0  mapSize=0 involvingNew=0 surviving=0
breakAt=300 polls=308 tripped=1 hasErrors=0 newShapes=0  ffRaw=0  mapSize=0 involvingNew=0 surviving=0
breakAt=311 polls=312 tripped=1 hasErrors=0 newShapes=0  ffRaw=2  mapSize=1 involvingNew=0 surviving=1
breakAt=312 polls=313 tripped=1 hasErrors=0 newShapes=0  ffRaw=3  mapSize=2 involvingNew=0 surviving=2
breakAt=340 polls=345 tripped=1 hasErrors=0 newShapes=4  ffRaw=12 mapSize=3 involvingNew=0 surviving=3
breakAt=375 polls=376 tripped=1 hasErrors=0 newShapes=13 ffRaw=12 mapSize=3 involvingNew=0 surviving=3
breakAt=376 polls=377 tripped=1 hasErrors=0 newShapes=13 ffRaw=12 mapSize=3 involvingNew=0 surviving=3
breakAt=377 polls=377 tripped=1 hasErrors=1 newShapes=13 ffRaw=12 mapSize=3 involvingNew=0 surviving=3
breakAt=378 polls=378 tripped=1 hasErrors=1 newShapes=13 ffRaw=12 mapSize=0 involvingNew=0 surviving=0
breakAt=379 polls=378 tripped=0 hasErrors=0 newShapes=13 ffRaw=12 mapSize=0 involvingNew=0 surviving=0
breakAt=400 polls=378 tripped=0 hasErrors=0 newShapes=13 ffRaw=12 mapSize=0 involvingNew=0 surviving=0
```

**`involvingNew` is 0 on every row, including the complete one.** The `IsNewShape` filter never
fires in either direction, so it cannot be what empties the map, and it was never the discriminator.
Rows 375, 376 and 377 also settle it from the other side: all 13 shapes created, all 12 FF
interferences recorded, and the map still holds 3.

What separates the rows is one poll. Break at 377 and the map holds 3; break at 378 and it holds 0,
with `newShapes`, `ffRaw` and `involvingNew` identical on both. `BOPAlgo_CheckerSI::Perform` polls
`UserBreak(aPS)` immediately after `BOPAlgo_PaveFiller::Perform` and immediately before
`CheckFaceSelfIntersection`, and `CheckFaceSelfIntersection`'s first two statements are

```cpp
NCollection_Map<BOPDS_Pair>& aMPK = *((NCollection_Map<BOPDS_Pair>*)&myDS->Interferences());
aMPK.Clear();
```

(`BOPAlgo_CheckerSI.cxx:442-443`). Break at 377 and that poll returns true, `Perform` returns, the
`Clear()` never runs. Break at 378 and the poll passes, the `Clear()` runs, and the next poll inside
`CheckFaceSelfIntersection` trips. The `hasErrors=1` on both rows is the same
`BOPAlgo_AlertUserBreak` in either position.

So: **the map is emptied by `CheckFaceSelfIntersection`, not filtered into emptiness by `PostTreat`,
and `PostTreat` afterwards declines to re-add any of the 12 raw FF interferences** (a valid solid's
face adjacency passes none of its per-type gates, which is why the complete run ends at
`ffRaw=12 mapSize=0`). An analysis stopped before the `Clear()` hands
`BOPAlgo_ArgumentAnalyzer::TestSelfInterferences` the pave filler's own raw map, and it reports what
it finds there.

Two caveats worth keeping, because the numbers here look like they should line up with the sweep's
and do not quite. This probe drives `BOPAlgo_CheckerSI` directly while the sweep drives
`BOPAlgo_ArgumentAnalyzer`, so the two count different poll sequences and their break-point indices
are not comparable; only the shape of the transition is. And `polls` can be lower than `breakAt`
because the run ends before that many polls are reached.

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

## The one guard with no test behind it

`otherFault` outranking `selfIntersects` (the pre-PR review's f1) is the one part of this change
**no test covers**, and the injection matrix says so rather than hiding it. Injecting the opposite
ordering, watchdog still first and statuses still typed, leaves all fifteen tests in the four
self-intersection suites green.

The reason is that reaching a result list holding both a genuine `BOPAlgo_SelfIntersect` and a
`BOPAlgo_OperationAborted` needs the analysis to have recorded real interferences and *then* failed,
on the unbounded path where no watchdog exists to catch it. `BOPAlgo_ArgumentAnalyzer::TestSelfInterferences`
appends `BOPAlgo_OperationAborted` for any `BOPAlgo_CheckerSI::HasErrors()`, which includes a
`Standard_Failure` inside the pave filler (`BOPAlgo_AlertIntersectionFailed`) with no user break
involved, and `Perform`'s own `catch` appends `BOPAlgo_CheckUnknown` after
`TestSelfInterferences` has already run. Both are reachable by inspection; neither was reproduced on
a real shape here, and no fixture is known that produces one.

So the ordering rests on a reachability argument, not on a reproduced case, and the argument is only
that **an analysis that did not finish cannot be trusted about what it did record**, which is the
same rule the watchdog branch above it already applies. If a shape that produces a mixed list turns
up, it belongs here as a fixture and the injection above becomes a real row.

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
