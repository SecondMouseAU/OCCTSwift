# #772: should `Shape.analyze(tolerance:)` measure self-intersection?

Measurement backing the design decision in #772 (okf/policies/measure-dont-assume.md: this issue
is explicitly a "measure before choosing" task, not a "pick the option that sounds right" one).

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

## Method

`main.swift` (built as the `AnalyzeSelfIntersectionTiming` executable target, see `Package.swift`)
times `Shape.analyze(tolerance:)` (the existing cheap small-edge/small-face/gap scan) against
`Shape.isSelfIntersecting(timeout:)` (`BOPAlgo_ArgumentAnalyzer`'s self-interference test, the same
machinery #319 gave a working cooperative timeout) across four shapes, chosen to span "trivial" to
"the worst artifact on record for this check":

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
swift run -c release AnalyzeSelfIntersectionTiming
```

(Release build matters here: debug-mode overhead is comparable in magnitude to the cheap scan
itself on the small shapes, which would make the "ordinary shape" rows noise rather than signal.)

## Measured (2026-08-08, macOS arm64, this branch's pinned kernel, `v2.0.0-kernel.2`)

Three independent runs; the numbers below are one representative run (`measured-output.txt`), all
runs agreed to within roughly 2x on the sub-10ms figures (expected noise at that scale) and within
a few percent on the two informative figures (the mesh-sewn import and the pathological artifact).

| Shape | Faces | Edges | `analyze(tolerance:)` | `isSelfIntersecting(timeout: 30)` | Result | Overhead |
|---|---|---|---|---|---|---|
| 1. Simple box | 6 | 12 | 0.001 s | 0.001 s | clean | ~1x |
| 2. Moderately complex fused/filleted solid | 16 | 39 | 0.001-0.003 s | 0.003-0.008 s | clean | 2x-3x |
| 3. Mesh-sewn imported solid (kiha10 body5) | 662 | 1072 | 0.04-0.14 s | 0.06-0.28 s | self-intersects | 1.2x-3.2x |
| 4. #319 pathological artifact | 1 | 3 | 0.007-0.017 s | 30.0-30.4 s | self-intersects | ~1800x-4100x |

`4b`, the same artifact through `isSelfIntersecting(hardTimeout: 5)` (#319's true wall-clock-bound
variant): returns at 5.01s, confirming the hard deadline holds even though the cooperative
`timeout:` variant ran to ~30s on this artifact.

## What the numbers say

On every ordinary shape tested, including a real 662-face mesh-sewn import that genuinely
self-intersects, the self-intersection check costs low-single-digit-multiple of the existing cheap
scan, tens of milliseconds in absolute terms. That is cheap enough that a caller who wants the
answer should be able to opt into it without a second thought.

On the one artifact known to be pathological for this specific check, the same call costs
~1800x-4100x the cheap scan (in absolute terms 16-17ms vs 30+ seconds at the default
`hardTimeout`), and pre-#319 it never returned at all. That is not a tail-latency inconvenience;
it turns a call documented and used as a cheap synchronous scan into one that can occasionally
block a caller's thread for tens of seconds to indefinitely, on input the caller has no way to
distinguish from "one more STEP import" ahead of time. Real degenerate CAD/reconstruction input of
exactly this shape (a wildly folded B-spline surface) is not a contrived worst case: this exact
artifact came from a real reconstruction pipeline.

That combination, cheap on every ordinary shape measured but catastrophic on realistic pathological
input, decides the question in #772's own terms: **making the check unconditional (or opt-in but
defaulting on) would occasionally turn a cheap call into an unbounded one, silently.** Opt-in with
a default of `false` is not a foregone conclusion overridden by caution here; it is what "small
overhead on ordinary input, unbounded-shaped overhead on pathological input" implies for a function
documented as the cheap scan.

## Decision

**Option 2, opt-in parameter, default off** (`analyze(tolerance:checkSelfIntersection:hardTimeout:)`),
combined with option 3's discipline for representing the result: `ShapeAnalysisResult.hasSelfIntersection`
is `Bool?`, non-nil exactly when `checkSelfIntersection: true` was passed and the check resolved
before `hardTimeout`. `nil` means unmeasured (not requested, or requested but indeterminate), never
a fabricated "clean". This satisfies #771's own bar for option 3: the field is reachable and
populated on a real path (proved by
`Issue772SelfIntersectionAnalysisTests.checkSelfIntersectionTrueOnCleanShapePopulatesFalse` /
`checkSelfIntersectionTrueOnSelfIntersectingShapePopulatesTrue`), not an always-closed gate.

The type is `Bool?`, not the `Int?` the issue's own option-3 sketch mentioned: `isSelfIntersecting`
only ever answers yes/no/indeterminate (`BOPAlgo_ArgumentAnalyzer` runs with `StopOnFirstFaulty`),
never a count of intersections, so an `Int?` here would imply a precision the check does not
provide, which is the same class of defect #763 removed.

`hardTimeout`, not the cooperative `timeout:`, backs the new parameter: `isSelfIntersecting(timeout:)`'s
own documentation still warns of un-polled internal stretches capable of running well past the
requested deadline even after #319's fix (this run's own ~30.0-30.4s vs a 30s deadline shows the
fix holding on the one artifact it was proven against, not a guarantee against every artifact).
`isSelfIntersecting(hardTimeout:)` is the API #319 built specifically to give a true wall-clock
bound regardless.
