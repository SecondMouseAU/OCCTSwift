# #772: should `Shape.analyze(tolerance:)` measure self-intersection?

Measurement backing the design decision in #772 (okf/policies/measure-dont-assume.md: this issue
is explicitly a "measure before choosing" task, not a "pick the option that sounds right" one).

> **Correction, #1054.** Row 4 of the table below, and the "`hardTimeout:` gives a worse answer
> than `timeout:`" paragraph that rests on it, are **wrong and withdrawn**. The "conclusive
> `self-intersects`" recorded there for `timeout: 30` on the #319 pathological artifact was
> `BOPAlgo_OperationAborted`, the fault OCCT records when the watchdog stops the analysis.
> `OCCTShapeSelfIntersectsBounded` decided from `BOPAlgo_ArgumentAnalyzer::HasFaulty()`, which is
> the union over every enabled mode and cannot tell an abort from a self-interference, so this
> harness was measuring the defect #1054 fixed. Re-measured directly on the same artifact at the
> same 30 s bound, with the statuses printed rather than `HasFaulty()`, the analyzer's whole
> result list is `[OperationAborted]`, and after the fix both mechanisms answer `nil`, which is
> the correct answer for an analysis that did not finish. The measurement is in
> `Scripts/repro/1054-selfintersect-fault-kinds/`.
>
> Nothing else in this document changes. Rows 1 to 3 are unaffected (they either complete or
> genuinely self-intersect), the cost figures the opt-in decision rests on are unaffected, and
> `analyze()` still forwards to `timeout:` for the reasons in `Shape+Analysis.swift` that were
> never about this artifact.

## Background

`ShapeAnalysisResult.selfIntersectionCount` was always `0` and never computed (#702/#763):
the bridge's own comment on the field read "would require more expensive computation". #763/PR#770
removes the fabricated field, which leaves `analyze(tolerance:)` reporting nothing at all about
self-intersection. #772 asks whether it should measure it, with three candidate answers:

1. Leave it out, document `analyze()` as a cheap-defect scan and point at
   `isSelfIntersecting(timeout:)`/`isSelfIntersecting(hardTimeout:)` as the separate, expensive
   check.
2. An opt-in parameter, `analyze(tolerance:checkSelfIntersection:hardTimeout:)`, defaulting off.
3. Report it as unmeasured rather than absent: an optional that is `nil` unless requested.

The issue is explicit that the choice must follow a measurement, not precede it, and flags a
specific trap for option 3: #771 found that `ShapeAxis.hasExtent` used the "gate an optional"
pattern while never actually flipping (`false` at every assignment site, `true` at none), so the
`nil` it produced was indistinguishable from a field that had simply been deleted. Picking option 3
here without a passing "the gate actually flips" test would repeat that exact defect.

## Round 1: the measurement that shipped, and what was wrong with it

The first version of this harness timed `Shape.analyze(tolerance:)` against
`Shape.isSelfIntersecting(timeout:)` (a direct synchronous `OCCTShapeSelfIntersectsBounded` call)
on every ordinary shape, and concluded the overhead was small enough to ship as an opt-in
parameter forwarding to `isSelfIntersecting(hardTimeout:)`.

Review caught the mismatch: `isSelfIntersecting(hardTimeout:)` is a **different, more expensive**
mechanism (`Shape.swift:2150-2169`) than the one the harness measured. It `deepCopy()`s the whole
shape, hands the copy to a `DispatchQueue.global` worker that calls
`OCCTShapeSelfIntersectsBounded(probe.handle, 0)` (0 = no cooperative bound at all on that call),
and waits on the caller's thread with a `DispatchSemaphore`. The number that justified "cheap
enough to opt into" was never the number the shipped code path actually cost; the only place
`hardTimeout:` was measured at all was the pathological artifact, at one deadline.

This section is kept, not deleted, because the same measure-first policy that governs the design
decision governs the record of getting the measurement wrong the first time.

## Round 2: measuring both entry points, on every row

`Scripts/repro/harnesses/AnalyzeSelfIntersectionTiming.swift` (one harness in the shared
`Harnesses` executable target, see `Package.swift` and `Scripts/repro/harnesses/HarnessRunner.swift`;
this directory keeps only this README and the captured output, not Swift source, the same
arrangement #694 established for `Censuses`) now times, on every shape, at the same deadline:

- `Shape.analyze(tolerance:)` (the existing cheap small-edge/small-face/gap scan)
- `Shape.deepCopy()` alone (the step `isSelfIntersecting(hardTimeout:)` takes before spawning its
  worker, isolated so its share of that mechanism's cost is visible on its own)
- `Shape.isSelfIntersecting(timeout:)` (`BOPAlgo_ArgumentAnalyzer`'s self-interference test, the
  same machinery #319 gave a working cooperative timeout)
- `Shape.isSelfIntersecting(hardTimeout:)` (the background-thread, true-wall-clock variant)

across four shapes, chosen to span "trivial" to "the worst artifact on record for this check":

1. **A plain box** (`Shape.box`): the primitive case.
2. **A moderately complex fused/filleted solid**: a plate, a boss fused on, four through-holes
   cut, all edges filleted (16 faces, 39 edges). Representative of an ordinary mechanical part.
3. **A real mesh-sewn imported solid**: the #348 fixture
   (`Tests/OCCTStressTests/Fixtures/unify-crash-mmd-kiha10-body5.brep`), a body extracted from a
   real reconstruction pipeline (OCCTReconstruct#194). 662 faces, 1072 edges; genuinely
   self-intersects.
4. **The #319 pathological artifact**
   (`Scripts/repro/319-selfintersection/dualskin_lateral.15.brep`): a single-face shell whose
   B-spline surface folds enormously (bounding box ~1.6e6 x 3.8e6 mm for a ~260 mm part). Measured
   pre-#319-fix at 619s CPU against a 30s deadline that never fired. This branch's pinned kernel
   carries the #319 fix (patch 0010: O(1) tangent-zone lookup + a checkpointed breaker), so this
   run is also a live regression check that the fix still holds on the exact artifact it was filed
   against.

Run with:

```bash
swift run -c release Harnesses 772-self-intersection
```

(Release build matters here: debug-mode overhead is comparable in magnitude to the cheap scan
itself on the small shapes, which would make the "ordinary shape" rows noise rather than signal.)

## Measured (2026-08-08, macOS arm64, this branch's pinned kernel, `v2.0.0-kernel.2`)

Several independent runs; the numbers below are one representative run (`measured-output.txt`),
all runs agreeing to within roughly 2x on the sub-10ms figures (expected noise at that scale) and
within a few percent on the informative ones (the mesh-sewn import and the pathological artifact).

| Shape | Faces | Edges | `analyze(tolerance:)` | `deepCopy()` | `timeout: 30` (shipped) | `hardTimeout: 30` (rejected) |
|---|---|---|---|---|---|---|
| 1. Simple box | 6 | 12 | ~0.0005-0.002 s | ~0.00004-0.001 s | ~0.0005-0.007 s, clean | ~0.0004-0.0007 s, clean |
| 2. Moderately complex fused/filleted solid | 16 | 39 | ~0.001-0.003 s | ~0.00003-0.001 s | ~0.0025-0.003 s, clean | ~0.0025-0.003 s, clean |
| 3. Mesh-sewn imported solid (kiha10 body5) | 662 | 1072 | ~0.04-0.19 s | ~0.0008-0.001 s | ~0.06-0.10 s, self-intersects | ~0.05-0.10 s, self-intersects |
| 4. #319 pathological artifact | 1 | 3 | ~0.007-0.017 s | ~0.00001 s | ~30.0-30.15 s, ~~**self-intersects**~~ **indeterminate**, see the correction above (#1054) | ~30.0-30.02 s, **indeterminate** |

`4b`, the same artifact through `isSelfIntersecting(hardTimeout: 5)`: returns at ~5.0-5.01s,
confirming the hard deadline holds at a short bound even though its internal call is unbounded.

## What the numbers say

**`deepCopy()` is cheap everywhere measured**, under 1ms even on the 662-face mesh-sewn import.
The overhead-comparison table for `timeout:` vs `hardTimeout:` on the three ordinary shapes is
close either way (0.8x-2.0x for both), so the deep copy is not, on its own, the reason to prefer
one mechanism over the other. This corrects Round 1's framing: the concern was never really "is
the deep copy too expensive", it was "is the mechanism the code actually calls the one that was
measured", and once it was, a second and more decisive difference showed up.

~~**On the #319 pathological artifact, `hardTimeout:` gives a worse answer than `timeout:`, for the
same wall-clock cost.**~~ **Withdrawn, see the correction at the top of this file (#1054).** The
paragraph read: *`timeout:` reliably returns a conclusive `self-intersects` around 30.05-30.15s;
`hardTimeout:` reliably returns `nil` (indeterminate) at almost exactly 30.0s, every run. The
reason is structural, not incidental: `hardTimeout:`'s internal `OCCTShapeSelfIntersectsBounded`
call passes `0` (unbounded), so the background computation has no cooperative deadline of its own
to help it find the fault before the caller's semaphore gives up; `timeout:`'s own internal
checkpoint-based breaker does.* The mechanism described is real, and the timings are real. What is
wrong is the word "conclusive": what `timeout:`'s breaker found first was its own abort, recorded
as `BOPAlgo_OperationAborted` and reported as a self-intersection by a `HasFaulty()` that could not
tell the two apart. Both mechanisms answer `nil` on this artifact now.

The rest of that paragraph stands and is not about the artifact: `hardTimeout:` leaves its
computation running, abandoned and still unbounded, after returning `nil` (documented on
`isSelfIntersecting(hardTimeout:)` itself); `timeout:`'s own call is the one the caller's thread is
already inside, so nothing extra is orphaned.

**On every ordinary shape, including a real 662-face mesh-sewn import that genuinely
self-intersects, both entry points cost a low single-digit multiple of the existing cheap scan**,
well under a second in absolute terms. That is cheap enough that a caller who wants the answer
should be able to opt into it without a second thought, whichever mechanism backs it.

**On the pathological artifact, the shipped mechanism costs ~3500x-4200x the cheap scan** (in
absolute terms a few milliseconds vs 30+ seconds at a 30s timeout), and pre-#319 it never returned
at all. That is not a tail-latency inconvenience: it turns a call documented and used as a cheap
synchronous scan into one that can occasionally block a caller's thread for tens of seconds, on
input the caller has no way to distinguish from "one more STEP import" ahead of time. Real
degenerate CAD/reconstruction input of exactly this shape (a wildly folded B-spline surface) is
not a contrived worst case: this exact artifact came from a real reconstruction pipeline.

That combination, cheap on every ordinary shape measured but severe on realistic pathological
input, decides the opt-in-vs-default question in #772's own terms: making the check unconditional
(or opt-in but defaulting on) would occasionally turn a cheap call into a many-second one,
silently. The `hardTimeout:` vs `timeout:` finding decides the second, narrower question review
raised: given the check is opt-in either way, which mechanism should back it.

## Decision

**Option 2, opt-in parameter, default off**, combined with option 3's discipline for representing
the result, as before. What changed: the parameter is `analyze(tolerance:selfIntersectionTimeout:)`,
a single `Double?` (not the two separate parameters, `checkSelfIntersection: Bool` and
`hardTimeout: Double`, the first version shipped), and it forwards to
**`isSelfIntersecting(timeout:)`, not `isSelfIntersecting(hardTimeout:)`**.

`ShapeAnalysisResult.hasSelfIntersection` is `Bool?`, non-nil exactly when
`selfIntersectionTimeout` was non-`nil` and the check resolved before it. `nil` means unmeasured
(not requested, or requested but indeterminate), never a fabricated "clean". This satisfies #771's
own bar for option 3: the field is reachable and populated on a real path (proved by
`Issue772SelfIntersectionAnalysisTests.nonNilTimeoutOnCleanShapePopulatesFalse` /
`nonNilTimeoutOnSelfIntersectingShapePopulatesTrue`), not an always-closed gate.

The type is `Bool?`, not the `Int?` the issue's own option-3 sketch mentioned: `isSelfIntersecting`
only ever answers yes/no/indeterminate (`BOPAlgo_ArgumentAnalyzer` runs with `StopOnFirstFaulty`),
never a count of intersections, so an `Int?` here would imply a precision the check does not
provide, which is the same class of defect #763 removed.

**Why `timeout:`, not `hardTimeout:`**, settled from the measurement above rather than from which
one sounds safer: `hardTimeout:`'s wall-clock guarantee is real, but `analyze()` is already a
fully synchronous call with no async variant, so a caller here has already committed to blocking;
the guarantee buys nothing over `timeout:` in that context, and on the one artifact where it
mattered it cost a worse answer at the same wall-clock price, plus an abandoned, still-unbounded
background computation. `isSelfIntersecting(timeout:)`'s own documentation still warns of un-polled
internal stretches capable of running past the requested deadline on *some* pathological input even
after #319's fix (this run's own ~30.05-30.15s vs a 30s deadline shows the fix holding on the one
artifact it was proven against, not a guarantee against every artifact); that residual risk is
`isSelfIntersecting(timeout:)`'s own pre-existing, already-documented risk, which `analyze()`
inherits by forwarding to it rather than introduces. A caller who genuinely needs the hard
wall-clock guarantee despite that (for example no process/subprocess isolation available) should
call `isSelfIntersecting(hardTimeout:)` directly and accept its documented trade-offs; `analyze()`
does not make that call on the caller's behalf.

**Two parameters became one** (`checkSelfIntersection: Bool` + `hardTimeout: Double` to
`selfIntersectionTimeout: Double?`) for a reason found by review, not by this measurement: the
two-parameter form let a caller supply `hardTimeout: 5` while forgetting
`checkSelfIntersection: true`, which compiled, ran, and silently discarded the timeout, returning
`hasSelfIntersection == nil` indistinguishable from the ordinary default-off case. Collapsing them
into one optional (supplying a value *is* opting in) makes that mistake unrepresentable;
`Issue772SelfIntersectionAnalysisTests.timeoutAloneCannotBeSuppliedWithoutOptingIn` is the
regression test, including a comment showing the exact call the old signature allowed.

**Blocking is now documented explicitly.** `analyze()`'s own doc comment previously said the check
was "orders of magnitude more expensive" without ever saying "blocks the calling thread"; it now
has its own `- Important` note to that effect, naming the up-to-`selfIntersectionTimeout`-seconds
stall and warning against a UI/main-thread call site, matching what `isSelfIntersecting(timeout:)`
already documents.

**Abandoned background computations**: no longer a documentation-only mitigation. Since
`analyze()` no longer wires into `isSelfIntersecting(hardTimeout:)` at all, the specific risk
review raised (looping `analyze(checkSelfIntersection: true, hardTimeout: <small>)` over many
files piling up abandoned, deep-copied, still-running background computations) does not reach
`analyze()` by construction. `isSelfIntersecting(hardTimeout:)` itself still carries that
documented trade-off for any caller who reaches it directly (unchanged, out of scope for #772: see
the issue's own "Not in scope" section).
