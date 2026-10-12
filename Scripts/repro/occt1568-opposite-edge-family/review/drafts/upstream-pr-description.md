Title: Modeling Algorithms - Fillets on opposite edges: no crash, no invalid solid, and the intersection of the rounded profiles

(Draft PR first. Target branch IR. Not posted. CLA: the OCCT CLA applies to the author before the PR leaves draft.)

Fixes #1568, and the part of #1177 that is still open on IR. Supersedes #1591 (the same three lines, against master).

## Summary

Five commits, each one reviewable alone, in this order:

1. `ChFi3d_Builder::StartSol` drops an obstacle it found no edge for. `HC` was left as a default-constructed
   adaptor with `c1obstacle` set, the caller took it for a curve, and `Geom2dAdaptor_Curve::D1` dereferenced null
   (SIGSEGV, #1568). Three lines and a GTest with a 15 KB window of the reporter's model.
2. `ChFi3d_HasTransversalIntersection` looked at points only. Two fillets on opposite edges whose arcs cross
   (4 x 10 x 6 box, 3 and 3) came back `IsDone() == true` with a solid BRepCheck rejects and a volume of 315 for a
   box of 240: `Geom2dInt_GInter` reports the crossing of the end-cap arcs as a segment about the tolerance long
   and no point. A segment now counts as a crossing when the curves are not tangent at it. 8.0.1 refused these.
3. `BRepFilletAPI_MakeFillet::Build` builds fillets on opposite edges whose arcs cross, after `Compute()` fails:
   the intersection (`BRepAlgoAPI_Common`) of the shape filleted on each contour alone. Each arc is tangent to the
   face it starts on and the arcs cross on the face between them.
4. `BRepFilletAPI_MakeFillet::Build` builds a fillet wider than its face (r > w): the arc stays tangent to the
   face that lasts and passes through the far edge of the face that runs out (the pivot), or through both far
   edges. The shape is cut by the prism of the region between the arc and the faces.
5. `ChFi3d_Builder::Compute` reports a failure when the result is not a valid solid. Radii 2 + 1e-9 on a 4 wide
   face, r = 5 after r = 5 on a 10 wide face, and r = w on adjacent edges all came back done and invalid.
   This one costs a `BRepCheck_Analyzer` run per fillet (a third of the fillet time on a 19 face model), so it is
   the commit to drop if that is not wanted; the others do not depend on it.

## The rule

Wherever a fillet meets a face it is filleting it is tangent to that face; where the face runs out and there is
an edge instead, the edge is the pivot and the arc passes through it. r1 + r2 = w: tangent arcs. r1 + r2 > w:
the arcs cross (intersection of the rounded profiles, order independent in one operation). One fillet r > w: pivot
at the far edge. After a finished fillet the next one sees a different shape (its tangent edge is a pivot), so a
sequence differs from one operation; that is stated, not hidden.

## Results (box 4 x 10 x 6, x across the 4 mm face)

| case | 8.0.1 | IR before | IR with this series | analytic |
| --- | --- | --- | --- | --- |
| r1 + r2 = w (2, 2) | IsDone false | valid 222.831853 | valid 222.831853 | 222.831853 |
| r1 + r2 > w (3, 3) | IsDone false | done, INVALID, 315.657 | valid 202.502076 | 202.502076 |
| (1, 3.5) | IsDone false | done, INVALID, 322.994 | valid 211.590597 | 211.590597 |
| one fillet r = 5 on w = 4 | IsDone false | IsDone false | valid 190.725724 | 190.725724 |
| r = 100 on a 10 cube | IsDone false | IsDone false | valid 523.605676 | (near flat cut) |
| the model of #1568, r = 1.5, rim of 8 edges | SIGSEGV | SIGSEGV | IsDone false | - |

715 box cases (10 configurations, radii around the critical value, `add`, `add2` and sequential), one process per
case, IR against IR with the series: 338 valid ones identical in volume (1e-9) and face count, 254 unchanged (250
refusals, 4 time outs), 56 refusals or invalid solids now valid, 64 invalid solids and 3 uncaught exceptions now
IsDone false, 0 regressed, 0 newly invalid, no invalid solid left. Every built opposite-edge case: BRepCheck valid, one closed solid, tessellates, deterministic, volume
within 2e-11 (relative) of the analytic section, tangent to its walls to 0 degrees. Images (the break, the fix,
the reference sketch + extrude) are attached.

## Not done, said plainly

- The model attached to #1568 is NOT built: with r = 1.5 on the pocket rim it is declined (`IsDone() == false`)
  instead of crashing. 1.49 and 1.6 build and are valid. The fix for the crash is commit 1; completing that
  particular fillet needs the blend to continue past a B-spline round, which this series does not attempt.
- Contours that share a vertex (adjacent edges, frames, corners), variable radius, curved or non-rectangular faces,
  dihedral angles other than 90 degrees and concave edges are not covered by commits 3 and 4 and fail as before.
- `Modified()`/`Generated()`/`IsDeleted()` know nothing of the faces built by commits 3 and 4.
- It is a construction after the fact, not the data-structure fix (a stripe-stripe section curve and an edge as a
  second support in `ChFi3d_FilDS`); that is a different and larger piece of work.
- One more thing found on IR and not touched: four fillets round a 4 x 4 face of a 4 x 4 x 4 cube at r = 2 do not
  return within 90 s (8.0.1 refuses at once). Same before and after the series.
- DRAW tests (`tests/blend`, `tests/bugs/modalg_7/bug25478_*`, `tests/bugs/moddata_1/bug119`) were not run: the
  Draw module was not built. The GTests were: whole suite 8365 passed, 7 skipped, 0 failed (8352 before).

## Choices where there is one, with the alternatives (images attached)

- r1 + r2 > w: chosen the intersection of the rounded profiles. Alternatives: decline (8.0.1), clamp the radii
  to r1 + r2 = w, first radius wins.
- r > w, one fillet: chosen pivot at the far edge. Alternatives: decline, clamp to w.
- Huge radius (100 on a 10 cube): chosen the same rule, which tends to the chord through the two far edges.
  Alternatives: a cap above which it declines, clamp.
- Both radii past their wall (7.5 and 7.5 over a 6 high wall): chosen the intersection of the two pivot results.
- Ties are not special: r1 + r2 = w and r = w give tangent arcs.
- A result that is not valid is a failure: commit 5, or leave validation to the caller.

Tests: `BRepFilletAPI_MakeFillet_Obstacle_Test.cxx` (commit 1) and `BRepFilletAPI_MakeFillet_OppositeEdges_Test.cxx`
(commits 2 to 5). Each test was run against the tree without its change and fails there.
