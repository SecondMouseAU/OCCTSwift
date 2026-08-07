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

Recorded output is in `ground-truth-output.txt` (971 lines, every manifold edge of all ten
fixture variants, not excerpted; fixtures 1 through 6 were measured before the fix was written,
fixture 8 was added afterward, during review, to test a removal-matrix conjunction, see below).
`probe_762.mm` calls `ChFi3d::DefineConnectType` with the
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

## The `.convex` guard: load-bearing past a junction, but untested there

`wallsAndJunctions(fromFloor:floorZ:tolerance:)` never crosses a `.convex` edge. A first pass at the
removal matrix (injection C, disabling that block alone) came back green on every test in this PR,
which read as "decorative." That reading was wrong, caught in review, and worth recording precisely.

The guard has two call sites with different backstops. For a DIRECT (1-hop) floor neighbor, the
#724 Z-tolerance check is independent cover: even with `.convex` disabled, a direct neighbor still
has to bottom out at the floor's own Z to become a wall, and nothing in this PR's fixtures happens
to do that by coincidence. For a face reached PAST an already-absorbed junction, the Z check is
deliberately bypassed (see "Why a chain-discovered wall skips the #724 Z-tolerance check" in
`wallsAndJunctions`'s own doc comment), so `.convex` is the ONLY remaining protection there.
Injection C alone came back clean because every fixture in the original set happened to exercise
the direct-neighbor case, never the past-a-junction one in isolation. Untested and proven-safe read
identically in a green run.

Two fixtures were built specifically to isolate the past-a-junction case, both ground-truthed
against `ChFi3d` first (fixtures 5 and 8), and both failed to isolate it, for related but distinct
reasons:

- **The filleted through-slot (fixture 5).** Its open end's exterior wall is convex-connected to
  the fillet, but that same exterior wall is ALSO a direct (1-hop) neighbor of the floor (the
  floor's own polygon reaches the same exterior boundary the fillet does, since they share that
  corner). The #724 Z-check resolves it via the direct route before the fillet's own convex edge is
  ever tried.
- **The L-shaped pocket, reflex corner, partially filleted (fixture 8).** Built to test the reflex
  vertex of a non-convex floor boundary: at an ORDINARY corner of a rectangular pocket, two walls
  meet via a `.concave` edge (fixture 1, edges #17-24); at a REFLEX corner (the inner corner of an
  L, where a small block of material sticks into the cavity, the mirror image of a boss standing in
  a room's corner), the hypothesis was that the two walls instead meet via `.convex`, matching how
  two of a boss's own base fillets meet convexly going around its corner (fixture 6, edges
  #9/#11/#13/#15). Measured: the hypothesis holds (edge #9, `Cylinder` to `Plane`, `.convex`). But
  filleting only ONE of the two reflex-corner walls and leaving the other sharp does not isolate the
  guard either: `BRepFilletAPI_MakeFillet`'s own corner-blending, needed to keep the result
  watertight where a fillet ends at an unfilleted reflex corner, reshapes the unfilleted wall's own
  face so the FLOOR borders it directly too (confirmed via exact bounding boxes on the Swift side,
  not inferred from face areas: `Sources/OCCTTest/main.swift` scratch diagnostic). So the same
  masking recurs, for a kernel-side reason rather than a floor-topology one.

A geometric argument, not just "no fixture reached it," emerged from both attempts: a floor's own
boundary is a closed loop, and every vertex on it has exactly two incident edges, both bordering
something the floor is directly adjacent to at the same BFS level (level 0) the junction's own
convex-edged neighbor would only be reached at level 1 or later. A reentrant floor/wall pairing is
never itself `.convex`, so the floor's own two edges at any vertex are always crossable, and always
explored one level before a junction reached from that same vertex gets a chance to explore its own
neighbors. Whatever a junction's convex-edged neighbor turns out to be, tracing it back reaches a
vertex the floor already has its own, earlier route to. The same reasoning was checked (not
re-built as a fixture) against a floor-boss-inside-a-pocket configuration too: a boss's wall is
always additionally reachable via the floor's own inner-wire boundary, independent of any outer-wall
fillet's own corner.

This argument covers the pocket topologies this investigation could construct and reason through.
It is not offered as an exhaustive proof over every shape `BRepFilletAPI`/`BRepAlgoAPI` can produce,
and it has not been used to justify removing the guard: `.convex` stays blocked, at essentially zero
runtime cost, with its status recorded accurately as untested-but-plausibly-necessary rather than
proven either way. A fixture that would settle it needs a face with genuinely no OTHER route to the
floor at all, which on this evidence likely means two separate solids sharing an edge rather than
one solid's own corner. That is a real, specific target for the next person who wants to close it,
not a dead end.

### Injection D: the conjunction, not each half separately

Per review, `.convex` (injection C) and the Z-tolerance bypass (injection B) were also disabled
TOGETHER (injection D), re-running the full 21-test suite (`Tests/OCCTModelingTests
/Issue762FilletedPocketDetectionTests.swift`, `Issue753FilletedJunctionDetectedTests`,
`Issue735PocketEnclosureTests`) after each. Injection D's failure set was IDENTICAL to injection B's
own, 9 of 21 tests, the same 9 in both cases. The conjunction reveals nothing beyond injection B
alone on this fixture set, which is itself consistent with (not independent confirmation of) the
masking argument above: if `.convex`'s own removal changes no outcome by itself, removing it
alongside something else that does change outcomes should not produce a different failure set
either, unless the two guards interact on some fixture in a way that cancels out. None here do.
