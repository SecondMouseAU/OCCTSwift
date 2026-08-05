# Cluster A census (#664): sub-shape enumeration, dedup vs occurrence

The census artifact `docs/v2.0.0-plan.md` names as a hard prerequisite before any of #638, #642 or
#651 starts. It answers, for every public entry point that walks sub-shapes of a `Shape`, whether
it reads the deduplicated map (`TopExp::MapShapes`, `IsSame`-keyed) or the raw occurrence explorer
(a bare `TopExp_Explorer` walk), and what each returns on a shape with duplicated orientations.

**This directory is the census only. It does not fix #638, #642 or #651.** Per #664: "fix the
root, then re-measure: some members may resolve without their own change." The last section below
re-scopes the three members against what was actually measured, and corrects two things #642 and
#651 either understated or a naive reading of #614's own fixture would have missed.

## Method

Two independent halves, per #664's own instruction that a grep is not sufficient evidence on its
own here:

1. **Dynamic (primary).** `Scripts/repro/censuses/ClusterA.swift`, built as the `cluster-a`
   subcommand of the shared `Censuses` executable target (`swift run Censuses cluster-a`), builds
   real fixtures with the public `Shape`/`Face`/`Wire` API and calls every identified public entry
   point on each one, printing the measured table below. This is the evidence: an entry point is
   DEDUP or OCCURRENCE because it was *measured* to return the deduplicated or the per-occurrence
   count/array, not because a doc comment says so. The source used to live in this directory as its
   own `ClusterACensus` target; #694 moved it into `Scripts/repro/censuses/` alongside Cluster B's
   census (#665), sharing one SwiftPM target and one set of fixtures instead of one target per
   cluster. Nothing it measures changed: same fixtures, same entry points, same 45 rows, byte
   identical, only the invocation and the file's location did.
2. **Static (secondary cross-check).** `classify_topexp_sites.py` scans every `.mm` file under
   `Sources/OCCTBridge/src/` for `TopExp_Explorer`/`TopExp::MapShapes` call sites and classifies
   each enclosing C function as DEDUP / OCCURRENCE / OTHER from the source text alone. #664 warned
   this kind of tool "must not be the primary evidence: a shared helper, a cast, or an entry point
   that walks via another entry point will all defeat it", and it was right twice over during this
   census's own construction (see "Where the two methods disagreed" below, which is the most
   useful part of this artifact per the task that commissioned it).

Both are runnable and both are committed, per the census-once rule: `swift run Censuses cluster-a`
and `python3 Scripts/repro/cluster-a-subshape-enumeration/classify_topexp_sites.py` regenerate the
tables from the pinned kernel and the current tree, respectively.

## Fixtures

Built from the real Shape API, not hand-assembled topology, so every number below is what an
ordinary caller would see:

- **`plainBox`**, `Shape.box(width: 10, height: 10, depth: 10)`, one solid, origin-centred
  `-5...5`. No sub-shape is reachable from more than one *parent shape*, but every edge is still
  reachable from two adjacent faces and every vertex from three edges within the one solid. This
  is #502's own box measurement (24 edge occurrences over 12 distinct, 48 vertex occurrences over
  8 distinct) and it needs no compound at all.
- **`splitBoxCompound(order:)`** ("vertical-cut fixture", `compoundA`/`compoundB` below), the
  *exact* construction `Tests/OCCTTopologyTests/Issue614FaceOrientationTests.swift` already uses
  and has coverage for: a 20×10×10 block cut by an upright plane, recompounded in two member
  orders. Measured here at 11 distinct faces / 12 occurrences, matching that test file exactly.
- **`horizontalSplitBoxCompound(order:)`** ("horizontal-cut fixture", `hCompoundA`/`hCompoundB`
  below), a second two-solid split, cut through `z=4` on an origin-centred 10mm box (`split(atPlane:
  normal:)`), also recompounded in two member orders.

**Both split fixtures were needed, and that is itself a finding.** The vertical-cut fixture's
shared wall has a horizontal-*axis* normal (it's a side wall), so it never touches
`isHorizontal()`/`isUpward()` at all. Measuring only that fixture would have concluded AAG is
order-*independent*, which is wrong. #642's own claim (`detectPocketsAAG()` 2 vs 1, AAG
upward+horizontal node set `[2, 8]` vs `[2]`) only reproduces on the horizontal-cut fixture, where
the shared wall itself is one of the faces `isUpward`/`isHorizontal` classifies as such. A census
that stopped at "reuse #614's own committed fixture" would have silently failed to reproduce
#642's own numbers.

## Build and run

```bash
swift run Censuses cluster-a
python3 Scripts/repro/cluster-a-subshape-enumeration/classify_topexp_sites.py
python3 Scripts/repro/cluster-a-subshape-enumeration/classify_topexp_sites.py --self-test
```

`Censuses` is a package executable target (see `Package.swift`) shared with every other cluster
census (#694); its `cluster-a` subcommand's source lives at `Scripts/repro/censuses/ClusterA.swift`
and `Scripts/repro/censuses/SharedFixtures.swift`, not under `Sources/` and not in this directory.
This directory keeps only what SwiftPM does not need to see: this README and the static cross-check
script below, which is also why renaming this directory no longer breaks `swift build`/`swift test`
the way it did before #694 (`Package.swift`'s `path:` pointed directly at it).

## Full dynamic result table

45 rows, three fixtures (`plain box`, `order A`, `order B`, vertical-cut unless the entry point
name says `[horizontal-cut fixture]`).

| family | entry point | plain box | order A | order B | note |
|---|---|---|---|---|---|
| vertex | vertexCount (dedup canonical) | 8 | 12 | 12 | |
| vertex | vertices().count (dedup) | 8 | 12 | 12 | |
| vertex | uniqueVertexCount (alias of vertexCount) | 8 | 12 | 12 | |
| vertex | subShapeCount(ofType: .vertex) (dedup canonical) | 8 | 12 | 12 | |
| vertex | nbVertices (#651: fixed, now forwards to vertexCount) | 8 | 12 | 12 | deprecated, `renamed: "vertexCount"`; was occurrence (48/96/96) before #651 |
| vertex | contents.vertices (ShapeAnalysis_ShapeContents, occurrence) | 48 | 96 | 96 | |
| vertex | contentsExtended().nbVertices (occurrence) | 48 | 96 | 96 | |
| edge | edgeCount (dedup canonical) | 12 | 20 | 20 | |
| edge | edges().count (dedup) | 12 | 20 | 20 | |
| edge | uniqueEdgeCount (alias of edgeCount) | 12 | 20 | 20 | |
| edge | subShapeCount(ofType: .edge) (dedup canonical) | 12 | 20 | 20 | |
| edge | nbEdges (#651: fixed, now forwards to edgeCount) | 12 | 20 | 20 | deprecated, `renamed: "edgeCount"`; was occurrence (24/48/48) before #651 |
| edge | contents.edges (ShapeAnalysis_ShapeContents, occurrence) | 24 | 48 | 48 | |
| edge | contentsExtended().nbEdges (occurrence) | 24 | 48 | 48 | |
| edge | Shape(wire).edgeCount (dedup; a wire's own edges) | 4 | n/a | n/a | a wire's own edges aren't shared cross-parent in these fixtures |
| face | faceCount (dedup canonical, #541) | 6 | 11 | 11 | |
| face | faces().count (dedup) | 6 | 11 | 11 | |
| face | orientedFaces().count (occurrence, deliberate #614) | 6 | 12 | 12 | documented, paired counterpart of faces(), not a defect |
| face | uniqueFaceCount (alias of faceCount) | 6 | 11 | 11 | |
| face | subShapeCount(ofType: .face) (dedup canonical) | 6 | 11 | 11 | |
| face | nbFaces (#651: fixed, now forwards to faceCount) | 6 | 11 | 11 | deprecated, `renamed: "faceCount"`; was occurrence (6/12/12) before #651, agreeing with `faceCount` on a plain box only because no face is shared there |
| face | contents.faces (occurrence) | 6 | 12 | 12 | |
| face | contentsExtended().nbFaces (occurrence) | 6 | 12 | 12 | |
| face | contentsExtended().nbSharedFaces (a THIRD rule: location-discarding dedup) | 6 | 11 | 11 | |
| face (already fixed) | horizontalFaces().count (#614, reads orientedFaces()) | 2 | 4 | 4 | |
| face (already fixed) | upwardFaces().count (#614, reads orientedFaces()) | 1 | 2 | 2 | |
| face (already fixed) | facesByZLevel() total (#614, reads horizontalFaces()) | 2 | 4 | 4 | |
| face (already fixed) | upwardFaces().count **[horizontal-cut fixture]** | 1 | 2 | 2 | corroborates #642's own table: #614's fix IS order-independent on the SAME fixture AAG is not |
| face (AAG, #642, fixed) | buildAAG().nodes.count [vertical-cut fixture] | 6 | 12 | 12 | post-fix: was 11/11, now matches orientedFaces() (the shared wall is 2 nodes) |
| face (AAG, #642, fixed) | AAG upward+horizontal count [vertical-cut fixture] | n/a | 2 | 2 | unchanged: shared wall's normal is horizontal-axis here, order-independent before and after |
| face (AAG, #642/#699) | detectPocketsAAG().count [vertical-cut fixture] | 1 | 1 | 1 | #642-fixed: was 1/1/1 pre-#699 with a NEW order-dependence (1/1/2) exposed by #642's own fix; #699 fixed the cross-solid adjacency this exposed, restoring 1/1/1 (see "Update following #699's fix" below) |
| face (AAG, #642, fixed) | buildAAG().nodes.count [horizontal-cut fixture] | 6 | 12 | 12 | post-fix: was 11/11, now matches orientedFaces() |
| face (AAG, #642, fixed) | **AAG upward+horizontal NODE INDICES [horizontal-cut fixture]** | n/a | **[2, 8]** | **[2, 8]** | post-fix: was `[2, 8]` vs `[2]`, now agrees. The shared wall is its own node per side, so neither side's index depends on which one `faces()` used to keep |
| face (AAG, #642/#699) | **detectPocketsAAG().count [horizontal-cut fixture]** | 1 | 1 | 1 | #642-fixed: agreed at 2/2 (THE #642 HEADLINE MEASUREMENT); #699 found that agreement itself rode a cross-solid false adjacency and corrected it to 1/1 (see "Update following #699's fix" below) |
| wire | wireCount (dedup) | 6 | 11 | 11 | |
| wire | wires.count (dedup) | 6 | 11 | 11 | |
| wire | subShapeCount(ofType: .wire) (dedup canonical) | 6 | 11 | 11 | |
| wire | contents.wires (occurrence) | 6 | 12 | 12 | |
| shell | shellCount (dedup) | 1 | 2 | 2 | |
| shell | shells.count (dedup) | 1 | 2 | 2 | |
| shell | subShapeCount(ofType: .shell) (dedup canonical) | 1 | 2 | 2 | |
| shell | outerShells.count (occurrence explorer, #439 restricts to per-solid use) | 1 | 2 | 2 | |
| solid | solidCount (dedup) | 1 | 2 | 2 | |
| solid | solids.count (dedup) | 1 | 2 | 2 | |
| solid | subShapeCount(ofType: .solid) (dedup canonical) | 1 | 2 | 2 | |

(exact output reproduced by `swift run Censuses cluster-a`; the printed table additionally
right-pads columns for terminal alignment, omitted here for Markdown)

## Static classification summary

**Updated after #651.** `classify_topexp_sites.py` found **124 C functions** in
`Sources/OCCTBridge/src/*.mm` containing a `TopExp_Explorer` or `TopExp::MapShapes` call: **52
DEDUP, 51 OCCURRENCE, 21 OTHER** (find-first / existence-check / dead declaration). At the time this
census was first built the totals were 127/52/54/21; #651 deleted `OCCTShapeNbEdges`,
`OCCTShapeNbFaces` and `OCCTShapeNbVertices` (all three OCCURRENCE) once `Shape.nbEdges`/`nbFaces`/
`nbVertices` were deprecated and repointed at `edgeCount`/`faceCount`/`vertexCount`, so those three
rows are simply gone rather than reclassified. Re-run the script for the full 124-row table; the
entry points that matter for cluster A specifically are cross-referenced against the dynamic table
above.

Two functions are declared and implemented but **called from nowhere in `Sources/OCCTSwift/`**:
`OCCTShapeCountFaces` and `OCCTShapeCountEdges` (`OCCTBridge_Topology.mm`), both OCCURRENCE. Since
`OCCTBridge` is not a package product (only `OCCTSwift` is, per `Package.swift`'s `products:`),
these are unreachable from any consumer of this package, orphaned, not part of the public surface
`#664` asks about. They used to match the OCCURRENCE shape of `OCCTShapeNbFaces`/`OCCTShapeNbEdges`,
the reachable pair that backed `nbFaces`/`nbEdges` before #651 deleted them; that comparison is now
historical, since the reachable pair no longer exists to compare against.

## Where the two methods disagreed

The most useful output of this census, per the task that commissioned it. Two were real bugs in
the classifier, found and fixed while building it. **An earlier version of this README claimed
both were now `--self-test` cases "proven to fail with the fix reverted." That claim was wrong for
both.** Disabling either guard as it actually reads in the source left the self-test at 6/6; see
"Self-test guard-removal matrix" below for what was actually measured, case by case, and what was
added to close the gap.

1. **A nested-paren return type broke the function-name parser.** `static Handle(Poly_Triangulation)
   occtMergedTriangulation(...)` was mis-parsed with `Handle` as the function name, greedily
   swallowing everything up to the *real* closing paren as its "argument list" and hiding the real
   function from classification entirely. Fixed by blanking the `Handle(Type)` idiom to a
   same-length, paren-free placeholder before matching (`_blank_handle_macro`).
2. **A braceless single-statement loop body was matched against the wrong braces.**
   `OCCTShapeCountFaces`, `OCCTShapeCountEdges` and `OCCTFaceWireCount` are all
   `for (TopExp_Explorer ex(...); ex.More(); ex.Next()) count++;`, no braces on the loop body at
   all. The first version of the loop-body finder searched forward for the next `{`, found the
   function's own `catch (...) { return 0; }` a few lines later, and reported a `return` "inside
   the loop" for all three, misclassifying three genuine OCCURRENCE functions as OTHER
   (find-first). Fixed by handling the braceless case explicitly (`_loop_body_span` now checks for
   `{` before assuming one).
3. **Not fixed, documented instead: the `while (explorer.More() && count < max)` idiom.**
   `OCCTShapeCheckSmallFaces` and `OCCTShapeGetContourPoints` declare the `TopExp_Explorer` on its
   own line and drive it with a `while` whose condition also checks a caller-supplied output-buffer
   cap (`found < maxResults` / `pointCount < maxPoints`), not the `for (...; .More(); .Next())`
   idiom the classifier's loop-body finder assumes. Both are reported **OTHER** by the script.
   Manual reading of both (`OCCTBridge_Healing.mm:1614`, `OCCTBridge_Modeling.mm:10819`) shows
   neither is a find-first: both walk every occurrence up to the cap with no dedup, i.e. they are
   OCCURRENCE, just *bounded* OCCURRENCE. A shared face/edge could still appear twice in the
   output, just possibly evicting a later, unrelated one past the cap. The static tool's blind spot
   here is exactly what #664 warned about ("a shared helper... will defeat it"). This is a
   different loop idiom, not a helper, but the same lesson: a grep-shaped classifier finds shapes
   it was taught to recognise, not the ones actually in the tree, and neither of these two is fed
   into or read from the dynamic table above regardless (they cap a diagnostics buffer, not a
   sub-shape count/array), so this blind spot did not affect any measured conclusion in this
   artifact.
4. **`occtHasSelfIntersectingWire`: the classifier was right, and an earlier manual read (done
   while scoping this census) was not careful enough about `return` vs `break`.** It walks
   `TopAbs_WIRE` and returns `true` from inside the loop the moment it finds a self-intersecting
   one, a genuine find-first, correctly OTHER once the classifier was taught to look for `return`
   as well as `break` inside the loop body (not just after it, where a legitimately-accumulated
   result is returned once the walk completes).

None of these four bears on the dynamic table's conclusions. The classifier is intentionally the
secondary check here, and every entry point actually measured in the table above was measured, not
inferred from source text. They are recorded because the disagreement itself, and how each was
resolved, is what #664 asked this artifact to surface.

## Self-test guard-removal matrix

Per `okf/policies/prove-the-test-fails.md`: "if removing a guard leaves the count unchanged, that
case is decorative and needs rewriting, not celebrating." A PR #693 review measured this directly
and found the two guards above were exactly that: neither's removal changed the self-test result.
The table below is the corrected, full audit: every conditional in the classifier that gates a
verdict, removed one at a time, against both the self-test and the real 127-function report.
`self-test` shows cases-correct out of the full suite; `FAILS` lists which case(s) actually caught
it (empty means none did). `real report` shows whether the actual classification of the 127 real
bridge functions changed.

| guard removed | self-test | FAILS | real report |
|---|---|---|---|
| (none, baseline) | 13/13 | | 127 total, 52/54/21 |
| A: `_blank_handle_macro` neutered (`Handle(Type)` no longer blanked before parsing) | 12/13 | `occurrence_handle_return_type` | **CHANGED**: 126 total, 52/53/21 (`occtMergedTriangulation` drops out entirely) |
| B: `control_words` skip forced off | 13/13 | none | unchanged |
| C: comment-line skip in `split_functions` forced off | 13/13 | none | unchanged |
| D: `_loop_body_span`'s `if not next_match: return None` removed | 12/13 | `occurrence_explorer_checked_once_no_next_call` | **CRASHES**: `AttributeError: 'NoneType' object has no attribute 'end'` (10 real functions hit this) |
| E: `_loop_body_span`'s `if for_close == -1: return None` removed | 13/13 | none | unchanged |
| F: `_loop_body_span`'s `if i >= len(code): return None` removed | 13/13 | none | unchanged |
| G: `if code[i] == "{":` forced to `if True:` (the review's braceless finding) | 12/13 | `other_braceless_find_first_with_later_catch_return` | **CHANGED**: 127 total, 52/55/20 |
| H: `_loop_body_span`'s `if semi == -1: return None` removed | 13/13 | none | unchanged |
| I: `BREAK_OR_RETURN_RE` check in `classify_body` neutered | 11/13 | `other_find_first_break`, `other_braceless_find_first_with_later_catch_return` | **CHANGED**: 127 total, 52/75/0 |
| J: `if not explorer_matches: return "OTHER"` removed | 12/13 | `other_unrelated_iterator_no_topexp_usage` | unchanged on real data (this guard protects `self_test()`'s own direct call to `classify_body`, which `classify_file`'s pre-filter in `run_report()` makes otherwise unreachable) |
| K: `if not MORE_RE.search(code): return "OTHER"` removed | 12/13 | `other_dead_explorer_declaration` | unchanged (no real function declares a dead `TopExp_Explorer` today) |
| L: line-comment stripping neutered | 12/13 | `occurrence_comment_contains_return_word` | **CHANGED**: 127 total, 52/53/22 (`OCCTShapeFixSolid` flips OCCURRENCE to OTHER: a comment containing "...only ever **returns** the input solid..." reads as code) |
| M: block-comment stripping neutered | 12/13 | `occurrence_block_comment_contains_return_word` | unchanged on real data (no real function hits the `/* */` form of L's failure mode yet; added for symmetry, not because it fired) |
| N: `MAPSHAPES_RE` check (DEDUP via `TopExp::MapShapes`) neutered | 12/13 | `dedup_literal_mapshapes` | **CHANGED**: 127 total, 2/54/71 |
| O: hand-rolled-dedup `.Add()` check neutered | 12/13 | `dedup_hand_rolled_add` | **CHANGED**: 127 total, 50/56/21 |
| (restored) | 13/13 | | 127 total, 52/54/21 |

**Four guards (A, D, G, L) were load-bearing on the real 127-function corpus and had zero self-test
coverage before this pass** (A and G are the review's two; D and L were found auditing the rest per
the review's own instruction not to stop at two). D is the more serious of the pair found here: its
absence does not misclassify, it **crashes** classification outright on 10 real functions that use
a `TopExp_Explorer` to read the first match of a type with no enclosing loop at all
(`occtShellIsInsideSolid`, `OCCTShapeCreateHalfSpace`, `OCCTSolidFromShells`, and seven more). New
fixtures were added for all four, plus J and K (which only guard `self_test()`'s own bypass of
`classify_file`'s pre-filter, so they can never show a real-report effect by construction) and M
(added proactively, by the same failure mode as L, though nothing in the current tree exercises
it yet).

**Guard B was wrongly filed here as unreachable, and now has a case.** The original argument was
that B's `name` can only come from a token preceded by a return-type span, which no C++ reserved
word can be. That is wrong: `FUNC_START_RE`'s return-type span is `[A-Za-z_][\w:<>\*&\s,]*?`, which
cannot tell a token is not a type, so a single-line `else if (cond) {` offers `else` as the return
type and `if` as the name. Measured, with B removed:

```
WITH guard   : ['OCCTRealFunctionWithElseIf']
WITHOUT guard: ['OCCTRealFunctionWithElseIf', 'if']
```

The phantom `if` carries whatever loop follows, so it would appear as an extra OCCURRENCE row. B
belongs with **M**: reachable on ordinary C++, merely untriggered by today's tree, which happens to
contain no single-line `else if (`. `guard_b_else_if_is_not_a_function` covers it, and catching it
needed a harness change too, since a spurious *extra* function is appended after the real one, so
classifying `funcs[0]` alone still gave the right answer.

**Four guards (C, E, F, H) remain without self-test coverage, deliberately.** These are provably
unreachable given how the classifier is constructed, not merely untriggered:
- **C** (the comment-line skip in `split_functions`) can never fire on compiling C++:
  `FUNC_START_RE`'s `^` anchor means its overall match always starts exactly at a line's first
  character, so the text C checks (`text[line_start:m.start()]`) is always the empty string.
- **E**, **F**, **H** are bounds checks inside `_loop_body_span` that only fail on syntactically
  unbalanced input (an unterminated `for (...`, a truncated file, a statement with no closing `;`)
  which cannot arise from a file that compiles.

Writing a self-test fixture for code that cannot occur in valid input would test nothing; it would
just be a decorative case pretending to prove something. They are listed here, with the reasoning,
instead. B's misfiling is the argument for stating that reasoning explicitly rather than asserting
the bucket: the claim was checkable, and it did not hold.

## Findings

**Already correct, and must not regress.** `faces()`/`orientedFaces()` (#614), `faceCount`/`edgeCount`/
`vertexCount`/`wireCount`/`shellCount`/`solidCount`/`subShapeCount(ofType:)` (#502/#541),
`horizontalFaces()`/`upwardFaces()`/`facesByZLevel()` (#614, confirmed order-independent on *both*
split fixtures in this census, rows above). Any Cluster A fix has to leave every one of these
numbers unchanged.

**#651 was confirmed by this census, and is now fixed.** At the time this census was first built,
`nbEdges`/`nbFaces`/`nbVertices` were bare `TopExp_Explorer` counts (`OCCTShapeNbEdges`/`NbFaces`/
`NbVertices`, formerly `OCCTBridge_Topology.mm:3694-3719`, now deleted) while
`docs/reference/Document-Completions.md` documented all three with the *deduplicated* value
(`box.nbEdges // 12`, `box.nbVertices // 8`, confirmed by direct read of lines 1406/1438). #651's own
table already showed `nbFaces`/`faceCount` agreeing on a box (6/6, correctly: no face is shared
within one solid) and diverging only on the two-solid compound (12/11). This census's own table
reproduced that distinction exactly (`nbFaces` row: 6/12/12 across plain box/order A/order B,
matching `contentsExtended().nbFaces` and `contents.faces` bit for bit) rather than contradicting
it. The measured dynamic table also confirmed #651's own "watch for" note: `nbEdges`/`nbFaces`/
`nbVertices` were pure OCCURRENCE duplicates of `edgeCount`/`faceCount`/`vertexCount` in every
fixture measured, with no index or orientation dimension of their own. The #536 precedent (retire
the duplicate spelling, deprecate-and-forward, rather than #613's repoint-in-place) applied, and is
what #651 did: all three are now `@available(*, deprecated, renamed:)` and forward to
`edgeCount`/`faceCount`/`vertexCount`, so the dynamic table rows above now read the same value as
their canonical siblings across every fixture.

**`ShapeAnalysis_ShapeContents` (`Shape.contents`) and `contentsExtended()` are occurrence-based
too, and undocumented as such beyond `Shape.contents`'s own doc comment.** Both track the raw
explorer count (matching #541's README, which established this for faces specifically:
"`ShapeAnalysis_ShapeContents` is a fourth answer... its `NbFaces` tracks the explorer exactly").
`contentsExtended().nbSharedFaces` is a confirmed *third* counting rule (dedup with the placement
discarded, per #541), not a second copy of `faceCount`'s dedup rule. It happens to agree with
`faceCount` on both fixtures here only because neither compounds a moved copy of the same face; #541's
own `compound(box, box.Moved())` fixture is where the three answers (occurrence 12, `IsSame`-dedup
12, location-discarding dedup 6) actually separate.

**#638 (`edges()` collapse): the census supplies the consumer audit #638's own text asks for, and
finds none.** `edges()` collapses 24 occurrences to 12 distinct on a box, the identical mechanism
#614 fixed for faces (confirmed measurement, this table's edge rows). But `Edge` (the Swift type)
exposes no `.orientation` accessor at all: `edgeCount`, `edge(at:)`, `edges()`, `hasCurve3D`,
`isClosed3D`, `isSeam(on:)`, `adjacentFaces(in:)`, `dihedralAngle`, `tangent(at:)`, `curve3D`, and
every other public member on it were checked, and none reads a stored `TopAbs_Orientation` off the
edge. Searching the bridge directly (`grep -rn "\.Orientation() =="` across every `.mm` file) finds
exactly 14 sites that branch on an edge's or face's orientation; 13 are face-normal logic already
covered by #614's fix, and the one edge-orientation site
(`OCCTBridge_Modeling.mm:2646`, `occtSampleWirePoints`) reads its orientation fresh from a
`BRepTools_WireExplorer` walk of the *wire*, not from an `Edge` obtained via `Shape.edges()`, so it
is not a consumer of the collapse at all. **No currently-existing public consumer of `edges()`'s
stored orientation was found.** This is evidence toward #638's own option 2 ("the collapse is
correct behaviour... a documented contract plus a test, not a code change") but #638's own text is
right that this needs stating in that issue's PR, not settled here. A future `Edge.orientation`
accessor, or an edge-level consumer added later, would need to re-run this same search.

**Settled in PR #696: no code change.** That PR re-ran this audit rather than trusting it, then went
past source-reading and built the same edge in both orientations, diffing every accessor on a line
and a circle. It also sharpened one claim: the audit's "no consumer" holds for `Edge`, but
`subShapes(ofType: .edge)` returns `[Shape]`, where `Shape.orientation` **is** readable. No
production code takes that path, so the conclusion stands, but the narrower statement is the
accurate one. Regression tests now fail if any `Edge` accessor becomes orientation-dependent.

**#642 reproduces exactly, but only on a fixture #642's own issue text doesn't fully specify,
which is the correction worth posting.** `detectPocketsAAG()` 2 vs 1 and the AAG upward+horizontal
node set `[2, 8]` vs `[2]` are reproduced bit-for-bit on the horizontal-cut fixture. They do **not**
reproduce on the vertical-cut fixture, the one `Issue614FaceOrientationTests.swift` already commits
and the one a reader would naturally reach for first ("PR #631's own two-solid split fixture"). A
future PR for #642 that reused #614's committed fixture verbatim, expecting the same order-dependence,
would have found none and wrongly concluded the defect didn't reproduce. #642's own "complete
consumer set" table (three executable consumers of `faces()`: `FeatureRecognition.swift:96`,
`ConstructionEntity.swift:261`, `ShapeMeasurements.swift:66`) was independently re-verified here by
grepping every `.faces()` occurrence in `Sources/OCCTSwift/*.swift` and excluding doc-comment
matches. It is exactly right: three sites, no more.

## Update following #642's fix

#642 is fixed: `AAG.buildGraph()` now builds its node set from `orientedFaces()`, not `faces()`, so
a face shared by two solids is two nodes, one per owning solid, each carrying that solid's own
normal. The census was re-run against the fixed tree and the six affected rows above were updated
in place rather than left to describe a superseded state, per this artifact's own rule that a
census disagreeing with the tree is worse than none.

**The headline measurement now agrees.** On the horizontal-cut fixture, `detectPocketsAAG().count`
is `2` in both orders (was `2` vs `1`) and the upward+horizontal node indices are `[2, 8]` in both
orders (was `[2, 8]` vs `[2]`).

**A second, different, pre-existing defect surfaced while verifying the fix, and is deliberately
not fixed here.** On the vertical-cut fixture, `detectPocketsAAG().count` moved from `1`/`1` to
`1`/`2`, i.e., a NEW order-dependence appeared where there was none before. Measured directly (by
temporarily reverting `AAG.buildGraph()` to its pre-fix, `faces()`-based form and instrumenting
both the node list and the detected pockets for both compound orders) that this is not something
the fix introduced: the pre-fix code shows the identical asymmetry, one of the fixture's two
genuine floor candidates finds a concave vertical wall neighbor and the other does not, and which
one wins flips with compound order there too. It happened to leave the pre-fix *total count*
unchanged (whichever candidate lost, the count stayed at 1), so nothing about it was visible in the
table before this pass.

The mechanism is different from #642's: the vertical-cut fixture's shared wall borders two
half-faces (the box's top face, split by the cut) that also border **each other** along the same
edge the wall's top boundary runs along, so that one edge is common to three faces. Neither
`OCCTFacesAreAdjacent` nor `OCCTEdgeGetConvexity` (`OCCTBridge_BRepGraph.mm`) has any concept of
solid membership: each tests two `TopoDS_Face` values on their own geometry, so the wall's
orientation-A occurrence gets compared against both half-faces, not only the one that is actually
part of the same solid as that orientation. One of those two comparisons is a genuine same-solid
dihedral; the other combines two orientations that never co-occur on a single real solid boundary,
and whichever concavity that mismatched comparison happens to produce is not a meaningful answer.
Since #642's own fix now gives the wall two nodes instead of one, this pre-existing ambiguity is
exercised twice as often, which is why the previously-accidental cancellation stopped holding.

This is out of scope for #642, which is specifically about a normal-derived predicate losing
information across `faces()`'s dedup collapse, not about `AAG`'s adjacency graph lacking any notion
of solid membership for a multi-solid compound. Recorded here rather than fixed so a future issue
does not have to re-derive it: the fix would need `AAG` to know which solid a face occurrence
belongs to, so it can restrict adjacency/convexity checks to same-solid pairs, which the census's
own consumer audit was not asked to design.

## Update following #699's fix

#699 is fixed: `AAG.buildGraph()` now restricts its pairwise adjacency/convexity check (the
`OCCTFacesAreAdjacent`/`OCCTEdgeGetConvexity` calls) to occurrence pairs that share a solid.
Solid membership per occurrence is derived, not looked up through a new bridge function: the same
`TopExp_Explorer` descent `OCCTShapeGetOrientedFaces` already drives visits every occurrence under
one top-level solid contiguously before moving to the next, in the same first-encountered order
`Shape.solids` itself walks, so the flat occurrence list partitions into contiguous runs sized by
each solid's own face-occurrence count. Confirmed against both split fixtures (dumping every
occurrence's bounds alongside each solid's own `orientedFaces()` count) before relying on it,
not assumed from the traversal's documented behavior alone. `AAG.buildGraph()` falls back to the
pre-#699 unrestricted comparison whenever a shape has zero or one solid, or whenever the per-solid
counts don't sum to the total occurrence count -- silently mis-partitioning would be worse than not
partitioning at all, and neither case can arise on the fixtures this census measures.

**The vertical-cut fixture's new order-dependence is gone**, restoring the 1/1/1 the previous
section recorded as the pre-#642-fix baseline: `detectPocketsAAG().count` is `1` in plain box,
order A and order B alike.

**The horizontal-cut fixture's count moved too, from `2` to `1` in both orders.** This is not a
regression: #642's own headline measurement was ORDER-AGREEMENT (`2` in both orders, instead of `2`
vs `1`), and that agreement survives #699 intact (`1` in both orders, still equal). What changed is
that one of the two "pockets" `detectPockets()` reported before #699 was built from a cross-solid
comparison between the horizontal cut's own shared wall and the wrong side of a split face, exactly
the mechanism #699 fixes -- restricting to same-solid pairs removes it, and the fixture has one
genuine same-solid floor candidate left. Measured directly: with `AAG.buildGraph()`'s solid
restriction temporarily reverted, the horizontal fixture's floor at the *small* slab's top face
shows two same-index-range neighbors classified concave that a same-solid-only walk of that solid
in isolation also shows concave (`OCCTEdgeGetConvexity`'s own sign convention is a separate, far
older defect, present on a single plain box too -- see below), while the floor on the *large*
slab's top face shows zero concave same-solid neighbors either way. The `2`-vs-`1` swing was two
independent cross-solid comparisons landing on the large slab's floor before #699 and nowhere after.

**A third, unrelated defect was found while explaining this, and is also deliberately not fixed
here.** `OCCTEdgeGetConvexity`'s reported concavity for a given physical edge depends on which face
is passed as `face1` and which as `face2` -- the underlying `(tangent × n1) · n2` triple product
negates under that swap, and `AAG.buildGraph()`'s pairwise loop picks `face1`/`face2` by array
index order (`faces[i]`, `faces[j]`, `i < j`), not by any geometric convention. This reproduces on a
**single, uncut plain box** (`detectPocketsAAG().count` is `1` for the plain-box fixture throughout
this whole census, in every row that measures it, both before and after #642 and #699): two of the
box's four side-wall-to-top-face dihedrals are genuinely convex but get reported concave, purely
because of index order, which is what feeds the plain box's own false-positive pocket. This is
orthogonal to solid membership (it needs no compound, no shared face, no second solid) and orthogonal
to #699's fix (restricting to same-solid pairs does not touch which face lands at the lower index
within a solid). Not filed as its own issue here since it was found explaining a side effect rather
than measured as a primary claim; a future pass on `detectPockets()`'s accuracy should start from
this note rather than re-derive it.

## Re-scoping the three members

#664 asks which members are "the same defect" and which are independent, now that the census
exists. They are **three different, independent fixes**, not one fix in three places. The
census's job here is to show that clearly rather than let a fourth issue re-derive it:

- **#638** (`edges()` undocumented collapse) has **no fix depending on #642 or #651, and no fix
  they depend on**. Its own open question (does the collapse need `orientedEdges()`, mirroring
  #614's `orientedFaces()`) is answered "probably not, on current evidence" by the consumer audit
  above, but that is #638's call to make and record, not this census's.
- **#642** (AAG order-dependence) **shares its root mechanism with #614** (a normal/predicate
  derived from a dedup-collapsed face loses information for whichever occurrence didn't survive)
  but **#614 already shipped the general-purpose fix** (`orientedFaces()`). #642 is not blocked on
  any further root-level change to `faces()`/`edges()`. The fix it needs is AAG's own node-identity
  redesign (per #642's own three suggested approaches), which is a consumer-side migration, not a
  root-cause fix. #642 could start immediately, and did; it was never gated on #638 or #651. See
  "Update following #642's fix" above for what landed and what it surfaced.
- **#651** (`nbEdges`/`nbFaces`/`nbVertices` vs their own docs) was **orthogonal to orientation
  entirely**. It was a "two implementations of one count, the docs describe the wrong one" bug, with
  no face/edge-orientation dimension at all, and did not share a mechanism with #638 or #642 beyond
  both families living under `TopExp_Explorer`/`TopExp::MapShapes`. **Fixed**: retired in favour of
  `edgeCount`/`faceCount`/`vertexCount` per the measured duplication above, by deprecating and
  forwarding rather than repointing in place, since nothing else distinguished the two spellings
  once the value agreed.

**Practical consequence:** there is no single "fix the root" commit left to land for Cluster A that
would move all three members. The root for the *face* side (#614) already shipped; #638 is a
documentation decision; #642 is a standalone design task; #651 is a standalone retire-the-duplicate
task. All three can proceed in parallel once opened, in any order.

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
python3 Scripts/repro/cluster-a-subshape-enumeration/classify_topexp_sites.py --self-test
```
