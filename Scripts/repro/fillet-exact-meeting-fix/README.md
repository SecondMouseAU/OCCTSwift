# Fillets that meet exactly: candidate patch 0059 (#3207, OCCT#1177)

Investigation and candidate only. No PR, nothing reported upstream. Follows
`Scripts/repro/fillet-exact-meeting/` on `investigate/fillet-exact-meeting`, which showed the refusal
is `PerformOneCorner`'s OCC119 check, not patch 0054's defect.

What the user asked for: a 4 mm face with r1 = r2 = 2 gives a perfect semicircle on top; with
(r1 + r2)/2 > 2 the arcs intersect with an included angle between them.

## Result in one table

| radius (box 4 x 10 x 6, two top edges along Y) | kernel.5 | patched | analytic |
| --- | --- | --- | --- |
| 1.9999 | valid | valid 222.833570 (identical) | 222.833570 |
| 2 - 1 ulp, 2 | IsDone false | **valid**, 7 faces, 222.831853072 | 222.831853072 |
| 2 + 1 ulp | IsDone false | IsDone false (the guard, see below) | |
| 2.0001 ... 3 | IsDone false | IsDone false, unchanged | 222.830136 ... 202.502076 |

`r > w/2` needs a different algorithm; `results/reference-common.txt` shows the intersection of the
two single-edge fillets (`BRepAlgoAPI_Common`) reproduces the oracle from 2 to 3.99999.

## Oracle (`oracle.py`)

Section looking along Y, rectangle w x h, left arc centre (r, h - r), right arc centre (w - r, h - r),
kept region the intersection of the two rounded profiles.

- r <= w/2: removed area 2 (1 - pi/4) r^2.
- w/2 <= r < min(w, h): the arcs cross on x = w/2 at height y* = h - r + sqrt(w r - w^2/4), with an
  included angle 180 - 2 asin((r - w/2)/r) degrees (180 at r = w/2, a tangent-continuous semicircle), and

  A(r) = w r - pi r^2/2 + (r - w/2) sqrt(w r - w^2/4) + r^2 asin(1 - w/(2r)),  V = w h L - L A(r).

  For w = 4: A = 4r - pi r^2/2 + 2 (r - 2) sqrt(r - 1) + r^2 asin(1 - 2/r). Checked against a 200000-step
  numeric integration (`results/oracle.txt`, agreement to 3e-8) and against the Common construction.
- The range ends at r = w, where the left arc reaches the right edge (OCCT#1177 part one, a separate failure
  that this patch does not touch), and at r = h.

## Cause, from instrumenting the kernel (`ChFi3d_Builder_C1.cxx`, `ChFi3d_Builder_0.cxx`)

Two checks, both OCC119's "Prevent the builder from creating intersecting fillets":

1. `PerformOneCorner` intersects the new end cap with the caps already on the end face. At r = w/2 the
   two caps are two quarter circles of the same circle touching at (w/2, h): `Geom2dInt_GInter` returns a
   segment of no length at an end of both curves.
2. `ChFi3d_StripeEdgeInter` intersects the two stripes' contact curves on the top face. At r = w/2 they are the
   same line, one segment spanning both.

Lifting both: r = 2 is "done", 8 faces, volume exactly right, but the top face between the stripes has area 0 and
is invalid. `ShapeFix_FixSmallFace::FixStripFace` removes it and the result is valid with 7 faces.
For r = 2.2 the same lifting gives done, invalid, volume 330 for a 240 box: the stripes cross and nothing in the
vertex stage trims them. That is the evidence that r > w/2 is a different algorithm: the DS builder only knows a
stripe cutting a face; two stripes cutting each other needs a surface-surface section curve added to the DS with
interferences on both fillet surfaces (the machinery of `PerformTwoCornerbyInter`, for stripes that share a vertex).

OCC119's own test (`tests/bugs/moddata_1/bug119`, 100 box, four fillets of 50) still throws; reproduced in `bug119.cxx`.
`tests/bugs/modalg_7/bug25478_1` ("Fillets can not touch", box 10, r = 5 on edges 1 and 3, carries a TODO that
expects the failure) now builds a valid solid, volume 892.699082 (`bug25478.cxx`, `results/occt-tests-*.txt`);
bug25478_2 still fails.

## The patch (`Scripts/patches/0059-...patch`, 4 files, ~140 lines with comments)

- `ChFi3d_IsEndContact` (new, `ChFi3d_Builder_0`): the intersection holds only points where an end of one
  curve meets an end of the other, and the first end is not past the second's in the direction it leaves. Used by
  `PerformOneCorner`'s second check only.
- `ChFi3d_StripeEdgeInter` returns bool: true when one segment spans both curves, still throws otherwise.
- `Compute()`: if any pair met exactly, `FixStripFace` after SameParameter, then `BRepCheck_Analyzer`; not valid
  means not done, so a meeting that is only approximate cannot become a done-but-invalid answer.

## Measured (`battery.py`, `validate.py`; one process per case, 90 s limit)

- Battery: C1..C10 of the previous sweep, add / add2 / seq, 715 cases. 296 valid at baseline: identical volume
  (1e-9) and face count. 42 done-but-invalid at baseline: identical. 403 unchanged outcome. **16 newly valid**
  (C1, C2, C3, C9 at c and c - 1 ulp, add and add2). 361 still IsDone false. **0 regressed, 0 newly invalid.**
  Not changed: C4 to C8 and C10 at their critical radii (adjacent edges, vertex blends, a four-edge frame).
- Newly valid, `results/validate-newly-successful.tsv`: BRepCheck valid, volume within 1e-9 of analytic (relative
  1e-6 gate), closed (no free or non-manifold edge, one solid, one shell), 7 faces, tessellates, identical
  over 3 runs: forum box, 10 x 4 x 6 along X, vertical edges, side face, cube, scales x10 and /100, rotations,
  unequal radii r1 + r2 = w (1.5/2.5, 1/3, 0.5/3.5), OCCT#1177's 10-cube with 5 and 5.
- Rounding noise: 40 random rigid motions of the box at r = 2: 22 valid, 18 IsDone false, 0 invalid. When the two
  contact lines cross by 1e-15 the DS builds garbage (done, 9 faces, volume 333) and the guard turns it into a
  clean failure. A tolerance-aware meeting would need the two contact curves made identical in the DS.
- Chamfers (`chprobe.cxx`): d = 2 still IsDone false (the first check passes only with a tolerance on the
  sidedness test, and a second failure follows). Not fixed.
- Trapezoid prism whose contact lines converge to one point (`SHAPE=trap`): unchanged.

## Known gaps

- `Modified()` / `Generated()` return the pre-`FixStripFace` faces, none of which is in the result at r = 2
  (`HIST=1`). The fix needs the ReShape context kept and applied in `ChFi3d_Builder::Generated` and
  `BRepFilletAPI_MakeFillet`/`MakeChamfer::Modified`.
- The `FixShape` inside `FixStripFace` rebuilds every face; skipping it leaves the result invalid (missing pcurves).

## Files

`fprobe.cxx` (modes add, add2, seq, common; env DUMP, MESH, CHECKS, HIST, FIXSMALL, ROT, SHAPE), `battery.py`,
`validate.py`, `oracle.py`, `bug119.cxx`, `bug25478.cxx`, `chprobe.cxx`, `meshdump.cxx`, `render_fix.py`, `build.sh`
(override-link recipe), `results/`, `review/` (the six renders and `index.md`).
