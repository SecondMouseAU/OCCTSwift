# #762: `detectPocketsAAG()` cannot see a filleted or chamfered pocket

Ground truth for [#762](https://github.com/SecondMouseAU/OCCTSwift/issues/762): what
`ChFi3d::DefineConnectType` (the classifier `OCCTEdgeGetConvexity` calls, #723) reports at every
floor/wall-adjacent junction of a sharp, filleted (several radii), chamfered, partially-filleted,
filleted-through-slot, and filleted-boss fixture. Built and measured *before* writing the fix, per
`docs/v2.0.0-plan.md`'s census-once rule and #723/#747's own precedent of ground-truthing against
`ChFi3d` before choosing a criterion.

## Build and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/762-filleted-pocket-detection/probe_762.mm -o /tmp/probe_762
/tmp/probe_762
```

Recorded output is in `ground-truth-output.txt` (every manifold edge of all ten fixture variants,
not excerpted; fixtures 1 through 6 were measured before the fix was written, fixture 8 was added
during a second review round to test a removal-matrix conjunction, and fixtures 9 and 10 were added
during a third review round to ground-truth the OR-fusion bug described below, see "The OR-fusion
bug" section). `probe_762.mm` calls `ChFi3d::DefineConnectType` with the
identical arguments `OCCTEdgeGetConvexity` does (`smoothThreshold = 0.01`, `CorrectPoint = true`),
against fixtures built with plain OCCT primitives, no bridge and no Swift, so this is OCCT's own
classifier's answer, not this project's wrapper of it.

## Fixture summary

All built on a 10x10x15 pocket in a 20mm cube (`Shape.box(width:height:depth:)`'s own centred
fixture, matching `Issue753FilletedJunctionDetectedTests`, formerly `...NotDetectedTests` before
this fix inverted it), unless noted:

| # | fixture | floor/wall junction | detected pre-fix | detected post-fix |
|---|---|---|---|---|
| 1 | Sharp pocket (control) | `.concave`, direct | 1, enclosed | 1, enclosed (unchanged) |
| 2 | Filleted pocket, r = 0.5 / 1 / 2 / 4 | floor `.smooth` to cylinder `.smooth` to wall | **0** | 1, enclosed |
| 3 | Chamfered pocket, d = 1.0 (symmetric) | floor `.concave` to chamfer `.concave` to wall | **0** | 1, enclosed |
| 4 | Partially filleted (2 of 4 edges, r = 1) | mixed: 2 direct `.concave`, 2 via fillet | **0** | 1, enclosed |
| 5 | Filleted through-slot (open both ends, r = 1) | 2 walls via fillet; 2 open ends `.convex` | 0 (already open, no walls found at all) | 1, **open** (unchanged verdict) |
| 6 | Filleted boss (convex feature, r = 1) | floor `.smooth` to cylinder `.smooth` to boss wall | 0 | 1, **open** (matches sharp boss, see below) |
| 7 | Plain box, own top exterior edges filleted, r = 2 (not in the probe binary, measured directly against the Swift API, see below) | floor `.smooth` to cylinder (radially OUTWARD) | 0 | **0** (must never become 1) |
| 8 | L-shaped pocket, reflex corner, one of its two reflex-corner walls filleted, r = 1 (added during review, see "The `.convex` guard" below) | floor `.smooth` to cylinder `.smooth` to fillet, then `.convex` to the unfilleted wall | n/a (built after the fix) | 2 pockets (the L's own coplanar floor split), both open |
| 9 | South floor/wall junction filleted (r = 3), and, separately, the vertical corner edge between west and south walls also filleted (r = 2), west's own floor/wall junction left SHARP (added during round-4 review, see "The OR-fusion bug" below) | floor `.smooth` to horizontal fillet cylinder `.smooth` to torus `.smooth` to vertical corner-blend cylinder | n/a (built after the fix) | 1 pocket, 4 walls, enclosed; the vertical corner-blend cylinder correctly excluded |
| 10 | Fully rounded pocket: all four floor/wall junctions filleted (r = 3) AND all four vertical corners separately filleted (r = 2) (added during round-4 review, a stress generalization of fixture 9) | a torus/corner-fillet ring: 8 curved junction faces plus 4 BSpline corner-reconciliation faces | n/a (built after the fix) | 1 pocket, exactly 4 (flat) walls, enclosed; all 12 curved/freeform faces correctly excluded |

"pre-fix" / "post-fix" counts are from `Sources/OCCTTest/main.swift` scratch runs against
`detectPocketsAAG()` before and after the fix in this PR (the scratch probe itself is not
committed, per this repo's convention: the numbers are transcribed here and in the PR body).

## The two junction shapes, and why they need different handling

**A fillet's two new edges are both `.smooth` (tangent), at both ends, by construction.** A fillet
is G1-continuous with both faces it blends, so there is no local sign left to read at either edge:
`ChFi3d::DefineConnectType` cannot report `.concave` or `.convex` for a tangent transition, and
correctly does not. `concaveNeighbors(of:)` therefore finds nothing. This is fixture 2's mechanism,
matching the issue's own description exactly.

**A chamfer's two new edges are both `.concave`.** A symmetric chamfer at a pocket's floor/wall
junction replaces one 270-degree reentrant corner with two 225-degree ones (still `>180`). This was
worked out geometrically before measuring, then confirmed here (fixture 3's edges #1 through #24
are `.concave` or `.convex`, never `.smooth`). `concaveNeighbors(of:)` **does** reach the chamfer
face directly. The reason `detectPockets` still missed it is a *different* gate: the chamfer is
planar at 45 degrees, fails `wallIndices`' own `isVertical` filter, and the pre-fix search never
continued past a concave-but-non-vertical neighbor to find the real wall beyond it.

So the fix needed two things: continue searching past a **non-wall face reached via `.concave`**
(covers chamfers, unconditionally, since the edge already carries the right sign), and separately
allow crossing a **`.smooth` edge into a face confirmed to curve the right way** (covers fillets,
where the edge itself carries no sign and the fillet FACE's own curvature has to be asked instead).

## The radial-curvature test, and the hypothesis it corrected

The natural first hypothesis (mirroring `detectHoles()`'s #747/#760 material-side test) was this: a
concave/pocket-like fillet's own outward normal points radially INWARD (toward its axis, like a
hole's bore), and a convex/boss-like fillet's points radially OUTWARD (away from its axis, like a
boss's own wall), so the radial sign alone would tell a pocket's fillet from a boss's.

**Measured, this is wrong.** Fixture 6 (filleted boss) shows the identical `INWARD (dot=-1.000000)`
signature as fixture 2 (filleted pocket): see `ground-truth-output.txt` lines under
`=== 6. Filleted boss ===`, edges #1 through #4. Worked out after measuring, not before: a boss's
own base junction is a *reentrant* (270-degree material) corner, exactly like a pocket's floor/wall
junction. The "T-shape" cross-section at a boss's base wraps material around the corner on three
sides (below the plate, and inside the boss above it), identical in kind to a pocket's own
floor/wall corner, just mirrored. The distinguishing property between a pocket and a boss was never
at this junction at all. It is which side of the far WALL the material is on, which #753's own
existing enclosure test already resolves independent of this fix (see below).

**What the radial test is actually for**, confirmed by contrast: filleting a genuinely CONVEX,
external corner (the box's own exterior edge, `.convex` at the sharp edge, material occupying only
90 degrees) gives the OPPOSITE, `OUTWARD`, signature. That specific case is not built into this
probe directly, but it is derivable from the same `ChFi3d`/curvature relationship the measured
fixtures establish, and implicit in why fixtures 2 and 6 (both reentrant) share a sign while a
plain rounded external corner would not. The radial test's job is refusing to chain through a
`.smooth`-connected face that curves the WRONG way for a junction, an ordinary convex rounding, or
an unrelated incidentally-tangent face, not distinguishing a pocket's fillet from a boss's.

## Consequence for the false-positive guard

Because the radial test cannot (and does not try to) tell a pocket's fillet from a boss's, a
filleted boss standing alone on a flat plate is **not** excluded from `PocketFeature.wallFaceIndices`
by this fix. That is consistent with, not a regression of, the pre-existing, already-tested behavior
for a *sharp* boss: `Issue753PocketBossWireScopeTests` already established that a floor boss's wall
is a legitimate member of `wallFaceIndices` when the boss stands on a real pocket's floor, with
`isOpen`'s own outer-wire-scoped test (#753, unchanged by this fix) correctly reporting the
enclosure state regardless. Measured directly (`Sources/OCCTTest/main.swift` scratch run): a sharp
boss on a bare plate already reports `1 pocket, isOpen: true` before this fix; a filleted boss on
the same plate reports the identical `1 pocket, isOpen: true` after it. Neither is a false
*enclosed* pocket, which is the property that actually matters to a consumer. See
`Tests/OCCTModelingTests/Issue762FilletedPocketDetectionTests.swift`'s
`Issue762FilletedBossFalsePositiveTests` for the codified version of this measurement.

## `detectHoles()`: checked, not assumed, and found unaffected

The issue asked to verify, not assume, whether `detectHoles()` (rewritten in #760 onto surface
type plus closed-in-U plus material side, not neighbor convexity) shares this blindness. Measured
directly (`Sources/OCCTTest/main.swift` scratch run, not committed):

| fixture | `detectHoles()` result |
|---|---|
| Blind hole, sharp rim (control) | 1 hole, radius 4.0, depth 10.0 |
| Blind hole, filleted rim (r = 1) | 1 hole, radius 4.0, depth **9.0** |
| Blind hole, chamfered rim (d = 1) | **2** holes: cylindrical bore (radius 4.0, depth 9.0) plus conical countersink (radius 4.5, depth 1.0) |

`detectHoles()` never reports **zero** holes in either case: it has no neighbor-convexity
dependency to lose in the first place (#760's whole point). The filleted-rim depth drops by exactly
the fillet's own axial extent, because the cylindrical wall really is shorter now (the fillet
consumes the top of it). That is an accurate consequence of the geometry changing, not a detection
failure. The chamfered-rim case reports the countersink's conical face as its own hole segment,
which is exactly what `detectHoles()`'s own doc comment says a conical wall means ("a
countersink/counterbore transition"), again correct, not a symptom of #762's bug. **No fix needed
here; not filed separately, since there is nothing to fix.**

## Why the sharp-through-slot control was worth measuring twice

Fixture 5's pre-fix count is `0`, same as its post-fix count of `1, open`, matching the *sharp*
through-slot's own existing behavior exactly (`Issue735PocketEnclosureTests
.twoWalledThroughSlotIsNotEnclosed`), but the two zeros mean different things. Before this fix, the
filleted slot found **zero** pockets at all (both walls unreachable, same
`.smooth`-with-no-concave-neighbor mechanism as fixture 2), which happened to look like "correctly
not a pocket" by coincidence of it also being open, not because the code correctly recognized an
open slot. After the fix, it is found (walls resolved through their fillets) AND correctly reported
open: the two exit ends have no neighbor at all (a `.convex` edge to the box's own exterior wall),
so nothing is absorbed there and the enclosure test still sees the gap. The verdict (open) does not
change. *Why* it is open does.

## The visited-marking bug that had been hiding the `.convex` guard's own proof

`wallsAndJunctions(fromFloor:floorZ:tolerance:)` marked a face `visited` as soon as an edge into
it was crossable, before deciding wall, junction, or dead end. Review found this directly: a face
that failed the #724 Z-tolerance check as a DIRECT floor neighbor was marked visited regardless,
so a SEPARATE edge reaching that same face through an already-absorbed junction, where the Z check
is bypassed and would have accepted it, could never run. Fixed by marking `visited` only once the
outcome is decided, leaving a dead end (a direct vertical neighbor that fails the Z check)
revisitable through a later junction.

Measured on this codebase's own fixtures, not only argued: a partially-filleted pocket's two SHARP
walls each have a low-Z bound offset from the floor's exact Z by about `1.5e-7`, a
`BRepFilletAPI_MakeFillet` corner-blending artifact invisible at the default tolerance but decisive
at a smaller one (`1e-8`). At that tolerance, the direct route fails and the fillet's own separate
`.concave` edge to the same wall is the only thing that finds it. Proved by injection: reverting
the fix and rerunning drops both sharp walls entirely (`wallFaceIndices.count` 4 to 2, `isOpen`
false to true); restoring the fix returns both. See
`Issue762DeadEndRevisitableThroughJunctionTests` in the test suite for the committed version.

## The `.convex` guard: proven load-bearing, once dead ends could be retried

A first removal-matrix pass (injection C, disabling the `.convex` block alone) came back green on
every test in this PR at the time, read as proof the guard was decorative. That reading was wrong,
and the visited-marking bug above is why: it was not that no fixture could isolate the
past-a-junction path where `.convex` is the only protection (the #724 Z-check independently covers
DIRECT neighbors, so `.convex` only matters once `reachedThroughJunction` bypasses that check). Two
fixtures were built specifically to isolate it (fixtures 5 and 8, both ground-truthed against
`ChFi3d` first), and both appeared to fail: the filleted through-slot's open-end exterior wall, and
the L-shaped pocket's reflex-corner far wall, were each also a direct (1-hop) floor neighbor, so the
Z-check seemed to resolve them first.

That conclusion rested on an unexamined assumption, the same one the bug made in code: that a
direct neighbor failing the Z-check was fully resolved. Both "masking" direct routes were actually
REJECTING (near-boundary Z-tolerance noise in each case: the through-slot's own construction, and
the reflex corner's `BRepFilletAPI` corner-blending artifact landing exactly on the tolerance
boundary), and a rejected direct neighbor used to be marked `visited` anyway, permanently closing
off the very `.convex`-gated path under investigation. Neither "masking" fixture was independent
confirmation of anything: both were the visited-marking bug, not yet found.

With dead ends left revisitable and `Issue762ReflexCornerPartialFilletTests` restored to the
default tolerance (rather than widened past the noise, which is what let it clear the direct route
and hide this), injection C alone now fails on exactly those two fixtures:

| fixture | before injection C | under injection C |
|---|---|---|
| Filleted through-slot | `wallFaceIndices.count` 2, `isOpen` true | `wallFaceIndices.count` **4**, `isOpen` **false** |
| L-shaped pocket, reflex corner | `wallCounts` `[2, 4]` | `wallCounts` `[2, **5**]` |

`.convex` is not untested any more. It is what stops both of these, proven by the same injection
that once read as clearing it.

The earlier "geometric argument" this README used to make (that a floor's own polygon vertex
always gives it an equally early, non-`.convex` route to whatever a junction's `.convex` neighbor
could reach, so the guard's own contribution was always redundant) is retracted, not merely
superseded. It was true of the graph as the code then implemented it, where a rejected direct
neighbor's `visited` marking made that route's failure equivalent to its success, both closing off
the second route equally. It was never true of the geometry itself, only of a bug that happened to
make the two indistinguishable in every fixture built to tell them apart.

### Injection D: the conjunction, re-measured

`.convex` (injection C) and the Z-tolerance bypass (injection B) were disabled TOGETHER (injection
D) again after both fixes, re-running the full 22-test suite. Injection D's failure set (10 of 22
tests) is identical to injection B's own (also 10, now including the new dead-end test), not to
injection C's smaller, more specific pair. With the Z-tolerance bypass gone, most fillet-mediated
walls are not found at all regardless of `.convex`, so there is nothing left for a relaxed
`.convex` to over-include on top of that: B's much larger breakage dominates C's narrower one. The
conjunction does not reveal a new failure mode beyond B alone; it is consistent with C's own
now-real effect being masked once B is also disabled, the same shape of interaction as the
visited-marking bug's masking, just between two live guards rather than a guard and a bug.

## The OR-fusion bug: entering a junction vs. continuing past one

A third review round on this PR found the `.smooth` crossable test for a face reached from an
already-confirmed fillet (`currentIsConfirmedFillet == true`) checked `neighborNode.isVertical ||
isRadiallyInwardFillet(neighbor)` with no further distinction of WHERE the candidate sits relative
to the floor. Once `current` is confirmed, every vertical `.smooth` neighbor looked eligible to
become the wall, including a face that is itself another junction, not the wall at all.

This traces back to an earlier, algebraically equivalent form the review named directly: the
original crossable test was `isRadiallyInwardFillet(edge.face1Index) ||
isRadiallyInwardFillet(edge.face2Index)`, testing EITHER end of the edge. `buildGraph()` always
populates `edge.face1Index`/`edge.face2Index` as exactly `{current, neighbor}` as a set (`i < j` in
occurrence order, unrelated to which node the BFS is currently expanding from), so that OR is
provably identical to `isRadiallyInwardFillet(current) || isRadiallyInwardFillet(neighbor)`. Once
`current` is confirmed, its own half of the OR is trivially true, making the far side irrelevant to
crossability, exactly the "entering vs. continuing" ambiguity the review named.

Built to prove this is reachable, not argued (the review's explicit instruction, given this PR had
already been wrong twice about something looking "untestable" or "geometrically impossible" that
turned out to be a live bug: the `.convex` guard's own history above): fixture 9. A vertical,
radially-inward, but non-planar corner-blend cylinder (the separately-filleted west/south corner)
is reached only through the south fillet's own further torus junction, never directly from the
floor. Before the fix, `detectPocketsAAG()` reports `floor=6 walls=[0, 2, 3, 7, 8]`, five wall
indices; node 2 is the corner-blend cylinder, wrongly promoted. Fixture 10 generalizes this to all
four corners of a fully rounded pocket and shows a far more dramatic failure: `walls=[0, 2, 3, 8,
9, 10, 11, 12]`, eight indices, all four corner-blend cylinders wrongly promoted, not just one.

### The fix that was tried first, and regressed real walls

The first fix attempted required a wall candidate to be `isVertical && isPlanar`, reasoning that a
curved face satisfying `isVertical` (its own sampled normal is horizontal, which a vertical-axis
cylinder or torus satisfies regardless of curvature) could not be a genuine flat wall.  Measured
against the full suite, this broke three pre-existing, unrelated tests:
`Issue735PocketEnclosureTests.cylindricalPocketIsEnclosed` and two floor-boss enclosure tests,
because a SHARP cylindrical pocket's own bore, and a boss's own cylindrical side wall, are
genuinely curved walls reached directly (no fillet at all), and `isPlanar` excluded them too. The
`isPlanar` requirement was answering "is this face flat," which is not the same question as "is
this face a wall of this floor's own pocket," and a curved fillet junction and a curved genuine
wall can look identical by that one property alone. This confirms the same shape of mistake as
round 2's retracted "no fixture reached it" argument: a plausible-sounding local property is not
the same as measuring the actual distinguishing structure, and it cost a second full pass through
the suite to find.

### The fix that shipped: `currentBordersFloorDirectly`

The distinguishing property that actually separates a genuine wall from an incidental corner blend
is not a property of the CANDIDATE face at all: it is a property of `current`, the node whose edges
are being examined. `currentBordersFloorDirectly` is true when `current` is the floor itself, or a
junction whose own entering edge came directly from the floor: exactly the fillet or chamfer built
to blend the floor to its wall specifically, which by construction has exactly two "long"
tangent/concave relationships (to the floor, and to that wall) and nothing else. A junction reached
only through ANOTHER junction (a corner blend continuing the chain, e.g. fixture 9's torus and
second fillet) is not that relationship: it exists to reconcile two OTHER faces, and its own far
neighbor is not automatically this floor's wall just because it is vertical and radially inward,
since a further corner blend can be both of those too.

A vertical candidate reached when `currentBordersFloorDirectly` is false is absorbed as a further
junction instead (kept in the search, not dropped), so a genuine wall further down the same chain
is still reachable by whichever route finds it. Measured on fixtures 9 and 10, both now report
exactly the intended walls (`[0, 3, 7, 8]` and `[0, 8, 9, 12]` respectively, each all planar), with
every corner-blend cylinder and BSpline correctly absorbed as a junction instead.

### Why not a hop limit

Fixture 10 was built specifically to check whether a fixed hop limit would have worked instead
(the review's own question: "if a bound is needed on junction chaining, prefer something
principled"). Measured, not assumed: every wall in fixture 10 is found in exactly one hop past its
own floor-bordering horizontal fillet (ground truth edges #1/#12/#14/#18), the identical depth as
the single-corner fixtures above, even though the same shape also offers a longer route to the same
wall through its own vertical corner cylinder and BSpline (ground truth edges #2/#9, #3/#12, etc.).
The BFS finds a wall by whichever route reaches it first, so the longer route is never actually
needed here, and no fixture built for this issue required a genuine wall to be found more than one
hop past a floor-bordering junction. `currentBordersFloorDirectly` gates on a structural fact
(whether `current`'s own entering edge came from the floor) rather than a hop count precisely
because a fillet is built to blend exactly the two named faces it sits between: a floor-bordering
fillet's OTHER tangent relationship is its wall by construction, independent of how much unrelated
corner-to-corner chaining exists elsewhere in the same graph. Termination does not depend on this
gate either: `visited` already bounds the total work to this floor's own face count regardless of
how many junction faces a chain absorbs (see "A direct dead end stays revisitable" above for the
matching argument about the dead-end case).

## `currentBordersFloorDirectly` reconstructed a fact the BFS already knew, and got it wrong

A fourth review round found two problems with the fix above, both confirmed and both fixed.

**Finding 1: the gate asked the wrong question.** `currentBordersFloorDirectly` first shipped as
`adjacencyList[floorIndex][current] != nil`: "does some edge exist between the floor and
`current`". That is not "was `current` reached directly from the floor". `adjacencyList` is built
for every edge regardless of convexity, so a junction that only incidentally touches the floor
through a non-crossable edge would satisfy the check without ever having been reached that way,
reopening this method's own bug for a topology none of the ten ground-truthed fixtures happens to
exercise. Not hypothetical here: `BRepFilletAPI_MakeFillet`'s own corner-blending is documented, in
`Issue762ReflexCornerPartialFilletTests`'s own doc comment (re: WallX0), to reshape an unrelated
face so the floor borders it directly by incident, not by the route actually taken to reach it.

Fixed by carrying the fact instead of reconstructing it. The BFS frontier changed from a plain
`[Int]` to `[(index: Int, bordersFloorDirectly: Bool)]`: each entry pairs a node with whether IT
was reached directly from the floor, decided once, at the moment it is enqueued (`current ==
floorIndex` at that moment). This never consults `adjacencyList[floorIndex]` at all, so it cannot
be fooled by an incidental edge, by construction rather than by a narrower heuristic.

**Finding 2: no removal-matrix row actually isolated this gate.** The two round-4 tests fold into
injection B/D's failure set (the Z-tolerance-bypass mechanism), which is a real but DIFFERENT way
to break them, not evidence about `currentBordersFloorDirectly` itself. A test comment pointed at
"the PR body's removal-matrix update" for proof that was not there: the third guard on this PR
believed proven by a row that was actually exercising something else (after injection C being
masked by the `visited` bug, and injections B/D backstopping each other).

Fixed with a dedicated injection E: force `currentBordersFloorDirectly` to its pre-fix effective
value of `true` (as if every node bordered the floor directly), and confirm the failure set is
disjoint from every other injection's own. Measured: exactly
`Issue762VerticalCornerBlendNotAWallTests`/`Issue762FullyRoundedPocketChainingTests` fail, and no
other test in the full `#762`/`#753`/`#735`/`#747` suite (34 tests) does. That disjointness is
what makes E an isolation rather than a coincidence: those same two tests ALSO fail under B/D, for
the unrelated Z-tolerance reason, so a row that merely observed them failing there would prove
nothing about this specific gate.

## Removal matrix, final

| injection | what it disables | what it isolates | tests that failed |
|---|---|---|---|
| A | `.smooth`-edge radially-inward gate, unconditionally crossable | whether a fillet is confirmed reentrant before crossing into it | 3: plain-box exterior fillet, both L-shape tests (sharp and filleted) |
| B | Z-tolerance bypass for chain-discovered walls | whether a chain-discovered wall is trusted by contiguity instead of its own Z | 12: all 4 fillet-radius cases, chamfer, partial-fillet, filleted through-slot, inverted `Issue753FilletedJunctionDetectedTests`, L-shape reflex corner, the dead-end test, the fixture-9 corner-blend test, and the fixture-10 ring test |
| C | `.convex` edge block, alone | whether a reentrant-the-wrong-way edge is refused | **2**: filleted through-slot, L-shape reflex corner (see table above) |
| D | B and C together | both of the above at once | 12, identical to B's own set (B's breakage dominates) |
| E | `currentBordersFloorDirectly`, forced `true` | whether a wall can only be accepted from the floor itself or a junction that borders it directly | **2**: exactly the fixture-9 and fixture-10 round-4 tests, and only those |

Each row's "isolates" column states, and its own measurement confirms, that disabling exactly that
mechanism (and nothing upstream or downstream of it) produces its own failure set: A and C fail
disjoint, narrow sets that neither B/D nor E also produce; B and D collapse to the same set because
B's breakage is a superset of what C alone can add; E's set is a strict subset of B/D's own
(reached by both mechanisms) but distinguishable from it, since E fails ONLY those two tests while
B/D fails twelve, proving E is doing its own, narrower job rather than merely restating B's.

Re-run in full after both fixes above, since crossability rules changed what each injection
reaches: the failure sets for A through D are unchanged in shape from the pre-round-4 matrix plus
exactly the two new round-4 tests folding into B/D (their own mechanism is a fillet chain, so
removing the Z-tolerance bypass breaks them the same way as every other chain-discovered wall).
`Issue762FilletedPocketDetectionTests.swift`
carries 15 `@Test` functions (unchanged this round; no new fixture was added, only the injection
that isolates the existing gate), and all five injections (A through E) were re-run against the
full `Issue762|Issue753|Issue735|Issue747` filter (34 tests), confirming no other, unrelated test
picked up a new failure under any of the five.

## The radial material-side test was duplicated, now shared

Review also found `isRadiallyInwardFillet(_:)` (used above) and `detectHoles()`'s own inline
material-side check had drifted into near-duplicates: identical `uMid`/`vMid` midpoint,
identical `offset`/`radial`/`radialLength` computation, identical `1e-9` guard, identical final
dot-product test, differing only in whether a sphere is handled (a fillet junction can be a corner
blend; `detectHoles()` is already gated to `.cylinder`/`.cone` and never needs it). Factored into
one shared, `static` helper, `AAG.isMaterialRadiallyInward(of:revolution:uv:allowSphere:)`, taking
the already-computed `revolution`/`uv` both callers already have rather than recomputing them.
`detectHoles()`'s own tests (`Issue747DetectHolesConvexClassifierTests`) and the `#762` suites here
both continue to pass unchanged, confirming the extraction is behavior-preserving. #723 and #747
both already fixed this exact test once, on the copy that existed at the time; the point of sharing
it now is that a third fix only has to happen once.
