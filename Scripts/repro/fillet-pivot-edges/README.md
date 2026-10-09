# Fillets that cross or run out of face: candidate patch 0060 (#3208, OCCT#1177)

Investigation and candidate only. No PR, nothing reported upstream. Follows patch 0059
(`Scripts/repro/fillet-exact-meeting-fix/`). The review images and the Shapr3D recipes are in `review/`
(`review/index.md`); read those first.

## The behaviour specified

Wherever a fillet meets a face it is filleting it is tangent to that face. Where the face runs out and there is an
edge instead, the edge is the pivot: the arc passes through it. r1 + r2 = w: arcs tangent to the walls and to each
other. r1 + r2 > w: tangent to the walls, crossing on the face between at an included angle below 180 degrees. A single
r > w: tangent to the filleted wall, through the far edge of the top face.

## Oracles (`oracle.py`, numerically checked, `results/oracle.txt`)

Section looking along Y, box w x h, depth d below the top face, `F_r(u) = (u/2) sqrt(r^2 - u^2) + (r^2/2) asin(u/r)`.

- **A and B, two fillets r1 (x = 0) and r2 (x = w) at once.** Removed depth `max(g1, g2)`, `g_i = r_i - sqrt(r_i^2 - (x - x_i)^2)`
  inside the arc's span; area `A = integral of max(g1, g2)`. s = r1 + r2 - w. `s <= 0`: `A = (1 - pi/4)(r1^2 + r2^2)`, the arcs
  tangent to each other at (r1, top) when s = 0 (case A). `s > 0`: the radical line is `2 s x = 2 (r2 - r1) d + s (r1 + w - r2)`;
  the crossing (xc, dc) is its intersection with circle 1 (centre (r1, r1) in (x, d)), the root with the smaller d, and
  `A = [r1 xc - (F_r1(xc - r1) - F_r1(-r1))] + [r2 (w - xc) - (F_r2(r2) - F_r2(xc - (w - r2)))]`. Equal radii reduce to
  `A(r) = w r - pi r^2/2 + (r - w/2) sqrt(w r - w^2/4) + r^2 asin(1 - w/(2 r))`. Included angle: the angle between the
  two arcs' tangent rays leaving the crossing towards their own walls, `180 - 2 asin((r - w/2)/r)` degrees for equal radii.
  Agreement with a 2e6-step integration: 1e-9. Range: both radii < w (each fillet alone is a fillet) and <= h. Above that
  the intersection of the two per-edge pivot results is built (D4) and the oracle (`validate.py: area_add`) matches it.
- **C and D, one fillet on a right-angle edge between faces reaching a (face 1) and b (face 2) from it.** Corner at the
  origin, face 1 on u, face 2 on v. `r <= min(a, b)`: centre (r, r). `r >= a` (face 1 runs out): tangent to face 2 and
  through P1 = (a, 0), centre `(r, sqrt(2 a r - a^2))`, valid while `r <= (a^2 + b^2)/(2 a)`. Mirror for b. Both run out:
  through P1 and P2 = (0, b), centre on the perpendicular bisector away from the corner, valid for `r >= sqrt(a^2 + b^2)/2`.
  Removed area `q1 q2/2 - (r^2/2)(theta - sin theta)`, theta = 2 asin(sqrt(q1^2 + q2^2)/(2r)), (q1, q2) the arc's ends on
  the two faces. Crease at a pivot: normals differ by `acos((a - cu)/r)` (face-1 pivot). r = w: the arc ends tangent on the
  far edge (OCCT#1177 part one). Checked by a 4e6-step integration to 2e-10.

## Before and after (`results/before-*.txt`, `results/after-branch.txt`; one process per case, kernel.5 as released)

| case (4 x 10 x 6) | kernel.5 | main (0059) | branch (0060) | analytic volume |
| --- | --- | --- | --- | --- |
| A (1.5, 2.5), (1, 3), (0.5, 3.5), (2, 2) | IsDone false | valid | valid, unchanged | 221.758844, 218.539816, 213.174770, 222.831853 |
| B equal 2.2, 2.5, 3, 3.5, 3.9 | IsDone false | IsDone false | valid | 219.238678, 213.342452, 202.502076, 190.731782, 180.809285 |
| B unequal (2, 2.5), (1, 3.5), (2.5, 3), (0.5, 3.9) | IsDone false | IsDone false | valid | 218.026575, 211.590597, 207.791557, 206.837421 |
| C one fillet 3.9 / 4 / 4.5 / 5 / 6 | valid / false / false / false / false | same | valid all | 207.359061, 205.663706, 197.704072, 190.725724, 178.729983 |
| D1 10 x 10 x 3 plate r = 4, D2 4 x 10 x 3 r = 4.5 | false | false | valid | 269.894869, 85.737337 |
| D3 r = 3 then r = 3 | false | false | valid | 213.812565 |

## What was built

In `BRepFilletAPI_MakeFillet::Build`, after `Compute()` fails: (1) contours with no common vertex, constant radius: the
`BRepAlgoAPI_Common` of the shape filleted on each contour alone (each contour that cannot be filleted alone, a single
edge with r past a face, is built by (2)); (2) one straight edge between two planar rectangles at a right angle: the shape
is cut by the prism of the region between the pivot arc and the faces. Every result must be one valid closed solid that
takes material away; the Common must remove at least the maximum and at most the sum of the per-contour amounts; the cut
must remove exactly area x length. Otherwise the failure stands. It is a construction after the fact, not the data-structure
fix: a stripe-stripe section curve and an edge as a second support are not added (see "Where the work stops").

## Validation (`validate.py`, `results/validate.tsv`: 0 failed cases of 38)

Every built case: BRepCheck valid, one solid, one shell, every edge on two faces, tessellates, identical over 3 runs,
volume within 2e-11 (relative to the box) of the oracle (1e-7 gate), tangency to the filleted wall 0.00 degrees, crease
angles equal to the formulas (B r = 3: 38.942441 degrees between normals, included 141.0576), scaled x10 and /100,
rotated about z and (1, 1, 0), vertical edges, the cube. 715 box cases (`battery.py`, C1..C10, add / add2 / seq):
**312 valid ones identical in volume (1e-9) and face count, 331 unchanged outcomes, 70 IsDone false now valid, 0 regressed,
0 newly invalid**; the 2 "changed" are the probe's own `seq` edge lookup throwing "no suitable edges" on a shape that
now gets one step further. `fuzz.py` (1000 random boxes and edge sets against main): 0 regressed, 0 newly invalid, 412
newly valid, and `fuzz_oracle.py` checks the 302 add-mode ones against an independent grid union of the removal prisms
(worst 7.9e-4 of the box volume, grid noise). OCCT's own tests (`results/occt-tests.txt`): `bug119` still fails as it must,
`bug25478_1` builds (as with 0059), the one-sided r = 10 sample of OCCT#1177 now builds (785.398163), `bug25478_2`
still fails; TKFillet's 17 GTests (8 existing and 4 new fillet tests, 5 chamfer tests) pass.

## Prove the test fails

`swap-members.sh` compiles the changed units from the patched tree and `ar r`s them into a COPY of the kernel.5
xcframework. Pristine kernel.5, `Issue3208` and `Issue3207` (`results/swift-run-k5-saved.txt`): the five gated 3208 tests
and the two gated 3207 tests FAIL (`Expectation failed: try filleted(...)`), the controls pass. kernel.5 + 0058 + 0059 (main
equivalent): the five 3208 tests fail, all else of OCCTModelingTests (794) passes (`results/swift-mod-main.txt`). kernel.5 +
0058 + 0059 + 0060: all 794 pass and the whole package suite passes. The C++ side: the four new GTests fail on kernel.5
and pass with the patch. Without 0058 the pinned kernel crashes `OCCTModelingTests` (SIGSEGV in
`noPairOfFacesOfAnySolidAbortsOrAnswersAnInvalidShape`), with or without this patch.

## Where the work stops

- Not done: contours that share a vertex (adjacent edges, frames, corners), because the intersection is not a fillet
  there (a vertex blend is); variable radius; curved or non-rectangular faces, dihedral angles other than 90 degrees,
  concave edges; chamfers; `Modified`/`Generated` history for the new results.
- Not done: the data-structure fix (stripe-stripe section curve, edge as support). Estimate: weeks, in
  `ChFi3d_FilDS` and `TopOpeBRepBuild` territory, with no guarantee of a smaller patch.
- Behaviour that needs your decision: (1) both at once and one after the other differ for r1 + r2 > w (D3); (2) a very large
  radius builds a near-flat cut through both far edges, where it used to be refused (r = 100 on a 10 cube, 523.6);
  (3) for r1 or r2 at least w, B takes the intersection of each fillet's own pivot result.

## Files

`fprobe.cxx` (raw `BRepFilletAPI_MakeFillet`, env TANGENT / CHECKS / MESH / HIST), `meshdump.cxx` (renderer input),
`build.sh`, `swap-members.sh`, `cases.py`, `validate.py`, `oracle.py`, `battery.py` + `sweep.py`, `fuzz.py`,
`fuzz_oracle.py`, `bug119.cxx`, `bug25478.cxx`, `render.py`, `results/`, `review/`.
