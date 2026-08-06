# Cluster B census (#665): the fillet and chamfer edge-set contract

The census artifact `docs/v2.0.0-plan.md` names as a hard prerequisite before #633 or #639 starts.
It tabulates, for every entry point in the fillet/chamfer/blend/draft/offset family that takes an
edge list, a vertex list, or a single edge/vertex index, what happens to a **duplicate index**, an
**out-of-range index**, an **index OCCT declines**, and an **empty list**.

**This directory is the census only. It does not fix #633 or #639.** #520, #568, #612, #633 and
#639 are prior art on this exact contract and are cited inline rather than rederived, per #665's
own instruction not to rediscover them.

## Method

Two independent halves, matching Cluster A's (#664) own method:

1. **Dynamic (primary).** `Scripts/repro/censuses/ClusterB.swift`, run as the `cluster-b`
   subcommand of the shared `Censuses` executable target (`swift run Censuses cluster-b`), calls
   every identified entry point against real fixtures and prints the measured grid below. This is
   the evidence: a cell says REJECT, SKIP, OVERWRITE or FIRST WINS because it was *measured*, not
   because a doc comment or an issue's own table says so.
2. **Static (secondary cross-check).** `classify_fillet_sites.py` scans the bridge source for each
   named C function and classifies its out-of-range-index handling and per-element value
   validation from the text alone. Where it disagrees with the dynamic measurement, that
   disagreement is reported below rather than reconciled away, per #664's own finding that this is
   "the most valuable output" a static cross-check produces.

```bash
swift run Censuses cluster-b
python3 Scripts/repro/cluster-b-fillet-edge-contract/classify_fillet_sites.py
python3 Scripts/repro/cluster-b-fillet-edge-contract/classify_fillet_sites.py --self-test
```

## Fixtures

- **`box`**: `Shape.box(width: 10, height: 10, depth: 10)` (`SharedFixture.plainBox()`), 12 edges,
  6 faces, every edge accepted by every entry point below.
- **`compound`**: `SharedFixture.splitBoxCompound(order: .asSplit)`, Cluster A's own two-solid,
  20-edge fixture, reused rather than copied. This is #694's concrete shared-fixture win in
  practice: `compound.edges()[15]` (`.index == 15`) is the out-of-range probe for
  `filleted(edges:radius:)`/`filleted(edges:startRadius:endRadius:)`, which take `[Edge]` rather
  than `[Int]` and so need a genuinely foreign `Edge`, not just a bad number, and a second,
  independent `blendedEdges` out-of-range check runs against it directly.
- **`shell`**: a 10mm box with one face dropped and the rest sewn back together, identical
  construction to `Issue612FilletContourSelectionTests.openShell()`. 4 of its 12 edges are declined
  by `BRepFilletAPI_MakeFillet::Add` (measured, not assumed: probed one edge at a time through
  `filletedVariable`, the narrowest entry point that fails cleanly on a declined edge rather than
  building a partial result): edges `[6, 9, 10, 11]` declined, `[0, 1, 2, 3, 4, 5, 7, 8]` accepted.
- **`rectFace`**: `Shape.face(from: Wire.rectangle(width: 20, height: 20))`, the exact fixture
  `Issue568IndexSkipTests` already uses for `fillet2D`/`chamfer2D`: 4 vertices, 4 edges, edges
  `(0, 1)` share a vertex.

## The grid

16 entry points. Volumes/areas to 6 decimal places, as measured against the pinned kernel.

| family | entry point | duplicate index | out-of-range index | OCCT-declined index | empty list |
|---|---|---|---|---|---|
| fillet-edges | `filleted(edges:radius:)` | N/A: uniform radius (dup 991.415927 == single 991.415927) | REJECT (nil) | SKIP (non-nil, area 465.097336 vs unfilleted 500.000000) -- **#639 fixed**: `filletedWithReport(edges:radius:)` sibling reports `declinedEdgeIndices` | REJECT (nil) |
| fillet-linear | `filleted(edges:startRadius:endRadius:)` | N/A: uniform law (dup 990.523733 == single 990.523733) | REJECT (nil) | SKIP (non-nil, area 465.097336 vs unfilleted 500.000000) -- **#639 fixed**: `filletedWithReport(edges:startRadius:endRadius:)` sibling reports `declinedEdgeIndices` | REJECT (nil) |
| fillet-edges (per-edge radius) | `blendedEdges(_:)` | **OVERWRITE: last radius wins** (dup 946.349541 == last-only 946.349541, != first-only 991.415927) -- #633 | REJECT (nil) | SKIP (non-nil, area 465.097336 vs unfilleted 500.000000) | REJECT (nil) |
| fillet-variable | `filletedVariable(edgeIndex:radiusProfile:)` | N/A: scalar edgeIndex, no list | REJECT (nil) | REJECT (nil): single edge, no partial fillet possible | N/A: no list; `radiusProfile` needs >=2 points, stricter than `filletEvolving`'s >=1 |
| fillet-evolving | `filletEvolving(_:)` | **OVERWRITE: last law wins** (dup 946.349541 == last-only 946.349541), documented on `EvolvingFilletEdge`, same mechanism as #633 | REJECT (nil) | SKIP (non-nil, area 465.097336) -- **#639 fixed**: `filletEvolvingWithReport(_:)` now reports `declinedEdgeIndices` | REJECT (nil) |
| fillet-edges (with history) | `filletedWithFullHistory(radius:edges:)` | N/A: uniform radius (dup 997.853982 == single-edge 997.853982) | REJECT (nil) | SKIP (non-nil, area 465.097336) -- **#639**: needed no new API; `history.record(of:)`'s `!isDeleted && generated.isEmpty` already names the declined set | REJECT (nil) |
| fillet-variable (with history) | `filletedWithFullHistory(edge:startRadius:endRadius:)` | N/A: scalar edge index, no list | REJECT (nil) | REJECT (nil): single edge | N/A: no list |
| blend (BiTgte_Blend) | `biTgteBlend(edgeIndices:radius:)` | N/A: uniform radius over a set; `BiTgte_Blend` keys edges into an `IndexedMap` (dup 1000.000000 == single 1000.000000) | REJECT (nil), fixed by #613 | **NO-OP** on a convex edge (non-nil, volume unchanged): structurally different from a skip-from-a-batch, see note below | REJECT (nil) |
| chamfer (two distances) | `chamferedTwoDistances(_:)` | **FIRST WINS** (dup 995.000000 == first-only 995.000000, != last-only 980.000000) -- the OPPOSITE of #633's last-wins | REJECT (nil) | REJECT (nil): single-edge batch, whole call fails | REJECT (nil) |
| chamfer (distance-angle) | `chamferedDistAngle(_:)` | **FIRST WINS** (dup 997.113249 == first-only 997.113249, != last-only 991.339746), same as `chamferedTwoDistances` | REJECT (nil) | REJECT (nil): single-edge batch | REJECT (nil) |
| chamfer (with history) | `chamferedWithFullHistory(distance:edges:)` | N/A: uniform distance (dup 995.000000 == single-edge 995.000000) | REJECT (nil) | SKIP (non-nil, area 476.191927 vs unfilleted 500.000000) | REJECT (nil) |
| offset-per-face | `offsetPerFace(defaultOffset:faceOffsets:)` | N/A: `faceOffsets` is a `Dictionary`, a duplicate key cannot be constructed | REJECT (nil), fixed by **#541** (see "Corrections" below) | N/A: `BRepOffset_MakeOffset` has no per-face decline analogous to `Add()` on a free-boundary edge | ACCEPTS (non-nil): applies `defaultOffset` uniformly, a legitimate no-override request |
| 2D fillet (face) | `fillet2D(vertexIndices:radii:)` | REJECT (nil) on a duplicated vertex index | REJECT (nil), fixed by #568 | UNMEASURED: no open/degenerate planar-face fixture built here | REJECT (nil), Swift-side guard |
| 2D chamfer (face) | `chamfer2D(edgePairs:distances:)` | REJECT (nil), order-independent, fixed by #705 (was **CRASH (SIGSEGV, uncatchable)**, see "New findings" below) | REJECT (nil), fixed by #568 | UNMEASURED, same reason as `fillet2D` | REJECT (nil), Swift-side guard |
| fillet (class API) | `FilletBuilder.addEdge(_:radius:)` | **OVERWRITE: last radius wins**, same mechanism as #633, unaudited by #489/#520/#568 | N/A: takes an `Edge`, not an index | foreign edge (a different `Shape` entirely): `addEdge` returns `true`, `contour(for:) == 0`, `build()` REJECT (nil) -- **#639 correction**: `contour(for:)` already reports the decline per edge | `build()` with zero `addEdge` calls: REJECT (nil) |
| chamfer (class API) | `ChamferBuilder.addEdge(_:distance:)` | **FIRST WINS**, matches `chamferedTwoDistances` -- `addEdge` itself prefers the first call, not just the bridge's hand-rolled loop | N/A: takes an `Edge`, not an index | foreign edge: `addEdge` returns `true`, `build()` REJECT (nil) | `build()` with zero `addEdge` calls: REJECT (nil) |

Full command output (with the `note` column this table drops for width) is reproduced exactly by
`swift run Censuses cluster-b`.

## Headline finding: fillet and chamfer disagree on duplicate-index handling, in OPPOSITE directions

This is the axis #633 is filed against, generalized across the whole family:

- **The fillet family (`blendedEdges`, `filletEvolving`, `FilletBuilder.addEdge`) is LAST WINS.**
  A duplicated edge index silently discards every radius/law but the last one written.
- **The chamfer family (`chamferedTwoDistances`, `chamferedDistAngle`, `ChamferBuilder.addEdge`)
  is FIRST WINS.** A duplicated edge silently discards every distance/angle but the *first* one
  written -- the opposite direction.

Both are silent: neither family reports that a value was discarded, and neither is documented
(`EvolvingFilletEdge`'s own doc comment is the only place either direction is written down). The
`ChamferBuilder`/`FilletBuilder` class API measurements confirm this is not an artifact of the
bridge's own array-based index resolution: `addEdge` calls made directly, with no index array or
loop at all, reproduce the identical direction per family. The behaviour lives in
`BRepFilletAPI_MakeFillet::Add`/`BRepFilletAPI_MakeChamfer::Add` themselves, not in anything this
bridge's own loops do.

**#633 asks for one contract, chosen and applied across the whole family.** This measurement says
the fillet side is internally consistent (three independent entry points, plus the class API, all
last-wins) and the chamfer side is *also* internally consistent (two entry points plus its own
class API, all first-wins) -- so unifying the two families onto one contract is a bigger decision
than #633's own title suggests, since it means picking a *direction* and changing it for one whole
family, not just deciding to reject/dedupe/document.

## New findings (not in #520/#568/#612/#633/#639)

1. **`chamfer2D(edgePairs:distances:)` SIGSEGVs (uncatchable) on a duplicated edge pair --
   fixed by #705, this census's own row now measures it live.** At the time this census landed,
   `rectFace.chamfer2D(edgePairs: [(0, 1), (0, 1)], distances: [1.0, 2.0])` crashed the process on
   the pair's *second* occurrence. Confirmed in isolation before writing the census's own note
   (not run live in the shipped artifact -- an OS signal is uncatchable, per this repo's own
   `CLAUDE.md` precedent for this exact family). `fillet2D`'s equivalent duplicate-*vertex* call
   does **not** crash (it rejects, cleanly), so this was specific to `BRepFilletAPI_MakeFillet2d
   ::AddChamfer`, not the shared `TopTools_IndexedMapOfShape` lookup both functions use. The
   mechanism this census guessed at without chasing further -- diagnosing it was a fix, not a
   census -- was confirmed exactly by #705: `AddChamfer` rebuilds the face incrementally, so the
   edge handles resolved from the *original* `edgeMap` before the loop starts were stale by a
   second call naming the same pair, order-independent (`(0, 1)` then `(1, 0)` crashed identically
   to `(0, 1)` twice). #705 fixed it by rejecting the whole call on a repeated pair, in either
   order, before `AddChamfer` sees the second one -- reusing one edge across two *different* pairs
   (e.g. chamfering adjacent corners of a polygon with `(0, 1)` then `(1, 2)`) is unaffected and
   still measures non-nil. `ClusterB.swift`'s own `chamfer2D` block now calls the duplicate case
   live rather than noting it as unsafe.
2. **The `FilletBuilder`/`ChamferBuilder` class API has zero index resolution or value validation
   of any kind.** No `occtUseSubShapesByIndex`, no `occtValidFilletRadius`. A foreign edge (one
   belonging to an entirely different `Shape`) is silently accepted by `addEdge` (returns `true`)
   and produces no built result (`build()` returns `nil`) with no signal as to why. This is a
   second, independent access path into the same OCCT builder classes the free functions wrap.
   **Correction (#639): the claim that "there is no per-edge report at all" was wrong, and #639
   found it by trying the query this census never tried.** `FilletBuilder.contour(for:)` --
   present since before this census, unrelated to #639 -- already answers exactly this: `Contour(E)
   == 0` for the foreign edge above (measured directly: `addEdge` returns `true`,
   `contour(for: foreignEdge)` returns `0`, `build()` returns `nil`), the identical signal it
   reports for a same-shape edge OCCT declines on geometric grounds. Neither this census nor #639's
   own issue text noticed the query already existed; #639 documents the recipe rather than adding
   new bridge code for this class.
3. **`offsetPerFace`'s reject-not-skip fix is attributed to #541 in the bridge's own comment, not
   #568.** See "Corrections" below.

## Static classification (secondary cross-check)

```
function                                   | file                     | index handling           | value validation
-------------------------------------------|--------------------------|--------------------------|-----------------
OCCTShapeFilletEdges                       | OCCTBridge_Modeling.mm   | REJECT (shared helper)   | VALIDATED
OCCTShapeFilletEdgesLinear                 | OCCTBridge_Modeling.mm   | REJECT (shared helper)   | VALIDATED
OCCTShapeBlendEdges                        | OCCTBridge_Healing.mm    | REJECT (shared helper)   | VALIDATED
OCCTShapeFilletVariable                    | OCCTBridge_Healing.mm    | REJECT (shared helper)   | UNVALIDATED
OCCTShapeFilletEvolving                    | OCCTBridge_Modeling.mm   | REJECT (shared helper)   | UNVALIDATED
OCCTShapeHistoryFromFilletEdges            | OCCTBridge_Modeling.mm   | REJECT (shared helper)   | VALIDATED
OCCTShapeHistoryFromFilletEdgeVariable     | OCCTBridge_Modeling.mm   | REJECT (inline bounds)   | VALIDATED
OCCTBiTgteBlend                            | OCCTBridge_Modeling.mm   | REJECT (shared helper)   | UNVALIDATED
OCCTShapeChamferTwoDistances               | OCCTBridge_Modeling.mm   | REJECT (inline bounds)   | UNVALIDATED
OCCTShapeChamferDistAngle                  | OCCTBridge_Modeling.mm   | REJECT (inline bounds)   | UNVALIDATED
OCCTShapeHistoryFromChamferEdges           | OCCTBridge_Modeling.mm   | REJECT (shared helper)   | UNVALIDATED
OCCTShapeOffsetPerFace                     | OCCTBridge_Modeling.mm   | REJECT (inline bounds)   | UNVALIDATED
OCCTFace2DFillet                           | OCCTBridge_Modeling.mm   | REJECT (shared helper)   | UNVALIDATED
OCCTFace2DChamfer                          | OCCTBridge_Modeling.mm   | OTHER                    | UNVALIDATED
```

## Where the two methods disagree

Both disagreements below are genuine blind spots in the static classifier, kept rather than
patched over, per #664's finding that a census's static half is only ever secondary evidence and
the disagreement itself is the useful output:

1. **`OCCTFace2DChamfer` classifies OTHER for index handling, but the dynamic census measured
   REJECT.** The classifier's `INLINE_BOUNDS_RE` only recognises a numeric `idx < 1 || idx > N`
   pattern (the shape `OCCTShapeChamferTwoDistances`/`DistAngle`/`OffsetPerFace` use), and its
   `REJECT_HELPERS` list only recognises the three fillet-family shared helpers.
   `OCCTFace2DChamfer` resolves both edges of a pair via `occtMappedSubShapeAt` (a *fourth*, real,
   already-shared helper this classifier's pattern list does not include) and rejects with a plain
   `if (e1.IsNull() || e2.IsNull()) return nullptr;` -- a third reject idiom, textually distinct
   from the other two, that behaves identically at runtime. The dynamic measurement is correct;
   the classifier's pattern list is incomplete. Not patched here, since the point of leaving it is
   the same one #664 made: a grep-shaped classifier is blind to indirection until it is taught
   the exact shape, and there is always one more shape.
2. **`OCCTShapeFilletVariable` and `OCCTShapeFilletEvolving` classify UNVALIDATED, but both
   validate radii at runtime.** Neither function's own body calls `occtValidFilletRadius`
   directly -- the validation happens inside `occtFilletSetRadiusProfile`
   (`OCCTBridge_Internal.h`), a helper both functions call but this classifier does not itself
   scan. `Issue612FilletContourSelectionTests.malformedProfilesStillReject` already exercises this
   at runtime (`filletEvolving` with a `-3.0` radius in the profile returns `nil`), so the dynamic
   answer is VALIDATED for both; UNVALIDATED here is the classifier's own indirection blind spot,
   the textbook case #664's own warning names.

## Guard-removal matrix

`classify_fillet_sites.py --self-test` proves each classification by removing the textual cue and
confirming the label actually moves, not just that it once printed correctly:

```
extract_body: call-site-only text has no definition to find                       : pass
extract_body: finds the real definition                                           : pass
shared-helper fixture classifies REJECT                                           : pass
shared-helper GUARD REMOVED classifies OTHER (proves the case, not a fixed label)  : pass
inline-bounds fixture classifies REJECT                                           : pass
inline-bounds GUARD REMOVED classifies OTHER                                      : pass
skip-idiom fixture (no guard at all) classifies OTHER, not REJECT                  : pass
validated fixture classifies VALIDATED                                            : pass
validator GUARD REMOVED classifies UNVALIDATED                                    : pass
unvalidated fixture (baseline, no removal needed) classifies UNVALIDATED          : pass

All 10 self-test checks passed.
```

## Are #633 and #639 the same defect?

**No. They are independent, on two different axes of the same grid.**

- **#633** (`blendedEdges` discards a radius on a duplicated index) fires on the **duplicate
  index** column, against edges OCCT would happily fillet on their own -- no declined edge is
  involved at all. The mechanism is the bridge's own per-contour-slot write landing twice at the
  same slot.
- **#639** (the family cannot report a declined edge) fires on the **OCCT-declined index**
  column, against a shape (like `shell`) where some *distinct*, non-duplicated edge is
  geometrically un-fillet-able. The mechanism is OCCT's own `Add()` silently doing nothing, with
  no bridge-side write to conflict.

A shape can trigger one, the other, both, or neither, independently: `blendedEdges` on `shell`
with a duplicated *accepted* edge would hit both at once, but that is two bugs firing on the same
call, not one bug. This grid is the evidence for that separation -- posted to #665 alongside this
census landing.

## Corrections to #665's own prior art

- **`offsetPerFace`'s reject-not-skip fix is `#541`, not `#568`.** #568's own table lists
  `OCCTShapeOffsetPerFace` as a site where the skip idiom was still live at the time #568 was
  filed. The current bridge source's own comment on `OCCTShapeOffsetPerFace`
  (`OCCTBridge_Modeling.mm`) attributes the fix to `#541`, alongside the 1-based-to-0-based index
  fix, not to `#568`. Read literally, `#541` must have landed and fixed this site independently,
  sometime after #568 was filed and before this tree. Recorded here rather than corrected in
  #568's own already-closed text, per this project's practice of not editing closed issues.
- **#665's own scale estimate ("79 public members... 18 entry points... 29 that take an edge
  list or index") was explicitly flagged in the task as name-prefix noise, not a work list, and
  measurement bears that out: the real, edge/index-taking surface this census actually exercises
  is 16 entry points**, once class-based builders, whole-shape operations (`chamfered(distance:)`,
  `drafted`), single-face operations with no list (`draftModification`, `splitDrafts`), and
  face-index families with no duplicate/decline axis to speak of (`offsetPerFace`'s `Dictionary`)
  are set against the grid's own four questions rather than counted by name.

## Verify

```bash
swift build                                    # 0 errors, no OCCTSWIFT_LOCAL, pinned v2.0.0-kernel.1
swift test                                     # full suite
python3 Scripts/check-bridge-index.py
python3 Scripts/check-null-handle-guards.py
python3 Scripts/check-docs-defaults.py
python3 Scripts/count-operations.py
python3 Scripts/check-bridge-index.py --self-test
python3 Scripts/check-null-handle-guards.py --self-test
python3 Scripts/check-docs-defaults.py --self-test
python3 Scripts/repro/cluster-b-fillet-edge-contract/classify_fillet_sites.py --self-test
```
