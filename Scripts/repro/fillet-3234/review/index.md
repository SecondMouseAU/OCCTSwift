# Pivot rule beyond right-angle planar rectangles (#3234): what the kernel does, what it should do, and what waits on you

Nothing here is submitted. Branch `fix/fillet-3234-beyond-rectangles`, on top of `fix/fillet-pivot-edges` (patches 0059 and 0060).
Nothing is a PR and nothing goes upstream.

## The rule, and what it was applied to

Wherever a fillet meets a face it is filleting it is tangent to that face; where the face runs out and there is an edge instead, the edge
is the pivot and the arc passes through it. Two fillets on opposite edges at once give the INTERSECTION of the two rounded profiles.

`section.py` applies it to one corner of a plane section made of lines and circular arcs, any angle, convex or concave: the fillet circle
has radius r and sits in the wedge the two faces span (the material wedge of a convex edge, the air wedge of a concave one). It is
tangent to both faces when both tangent points lie on the faces (TT); when a face runs out its far edge is the pivot (P1T2 when the first
face runs out, T1P2 the second, the shorter face first); when both run out the circle passes through both far edges (PP). A prism is
the section extruded, and a solid of revolution the section turned about the Z axis, because a ball rolling between two faces of a
body of revolution touches both in the meridian plane: so an edge shared by a plane and a cylinder, a cone or a sphere is one corner
of one section. The rule gives areas exactly (Green), hence exact volumes (`Pappus` for revolutions).

Independent reference: the rule's profile is built as a SOLID by `gprobe ... -- ref` (a sketch plus an extrude or a revolve: no
fillet code, the same thing Shapr3D does). Its volume equals the rule's to 1e-9 in every case, so the rule's arithmetic and the
construction agree. The kernels are then measured against that.

## Reading an image

Same layout as `fix-fillet-pivot-edges-review/`. Left: the section, the RULE's profile dashed blue with its circles dotted, tangent points
green discs, pivots red diamonds (a pivot ON THE AXIS of a revolved body is labelled), crossings blue discs, circle centres blue crosses,
the original profile grey dotted, and the kernel's own section (the mesh cut by a plane) in green with how far it is from the rule.
Middle: the best kernel's 3D result, or the input with the filleted edge red when every kernel declines. Right: the reference. Chips:
valid / declined / WRONG / INVALID with the volume and its difference from the rule, for kernel.5, main (0059), this branch (0060) and the
0062 candidate (a chip appears for 0062 only where it changes the answer). Curved-face cases have a second row: a zoom on the fillet region
(with the other candidate of a decision in orange), and a top view (revolutions) or the far side (prisms). Coordinates: the sketch plane is
XZ, x to the right, z up, extruded along +Y for prisms, revolved about the Z axis for solids of revolution.

Classification of a kernel on a case: **right** = built, one valid closed solid, volume equal to the rule to 1e-6 relative; **declined** =
`IsDone()` false (safe: `Shape.filleted` answers nil); **wrong** = built and valid with another volume; **INVALID** = done but BRepCheck or
closure fails (`occtBlendResultIsValid` is not on this branch; BRepCheck, one solid, no free or non-manifold edge and a tessellation are
checked instead).

## Result in one paragraph

Across 51 cases and a further 11 radius sweeps of 61 radii each, **no kernel (kernel.5, main, 0060) ever returns a wrong or an invalid
solid**. Where the fillet is tangent to both faces (TT), every kernel is right at every angle, convex or concave, for planar and curved
faces. Wherever the rule needs a pivot (a face runs out) the kernel declines, except exactly what 0060 already built (right angle between
planar rectangles, and two fillets at once, which the Common of singles builds at any angle: group F). So: **no defect that returns a
bad shape; a gap that declines.** Candidate patch **0062** (new, branch only) closes the planar part of the gap: a straight edge between two
planar rectangles at **any** angle, **convex or concave** (concave fills the corner). Curved faces stay declined; the decisions below
are why, and what each costs.

## Validation behind that paragraph

All numbers from `results/`; every kernel result below is a probe linked against the released kernel.5 with the changed translation units
of the patched tree override-linked (`build.sh`), one process per case.

- **The cases** (`cases3234.py`, `results/cases-all-variants.txt`): 51 cases; for each, the rule's volume, the reference solid's volume (equal
  to 1e-9) and the four kernels. Zero wrong, zero invalid on any kernel.
- **Radius sweeps** (`sweep3234.py`, `results/sweep-0060.txt`, `-0062.txt`): each family from a small radius to far past the faces in 61 steps
  (E45, E60, E90, E120, E135, the concave L, cylinder, short cylinder, cone, washer, groove). 0060: right below the tangent limit, declined
  above it, except E90 which it builds throughout. 0062: right through every planar family at every radius, declined for the curved ones.
- **Random polygon prisms** (`fuzzpoly.py`, `results/fuzzpoly-*.txt`): 900 random simple polygons (4 to 7 corners, angles 15 to 165 degrees on each
  side, so convex and concave), one or two corners, radii 0.1 to 1.5 times the longest side, against the rule (two convex corners against an
  independent polygon intersection). 0060: 281 built, 619 declined. 0062: 765 built and equal to the rule, 135 declined (curved radii that have no
  arc, a convex and a concave pair, two concave), **0 wrong, 0 invalid, 0 signals** for both.
- **Regression against 0060** (`fuzz.py` of the 0060 review, `results/fuzz-boxes-0062-vs-0060.txt`): 800 random boxes: 431 identical, 352 unchanged
  outcomes, 1 newly valid, 16 where a two-contour Common differs in volume (largest 9e-7 relative, radii far past both faces, near-flat arcs);
  validity and face counts identical in all.
- **C++** (`GTests/BRepFilletAPI_MakeFillet_Test.cxx` in the patch): five new tests. They fail on 0060 (`IsDone()` false) and pass with 0062;
  run here against a shim of `gtest.h` since a TKFillet GTest build is not set up on this machine.
- **Swift** (`Issue3234FilletPivotAnglesTests`, `results/swift-*.txt`): with 0062 the three suites 3207, 3208, 3234 (15 tests) pass; with
  kernel.5 + 0059 the two gated 3234 tests FAIL (`Expectation failed: try filleted(...)`) and the two controls pass.


## Summary

| outcome per kernel | kernel.5 | main (0059) | branch (0060) | 0062 candidate |
|---|---|---|---|---|
| right | 21 | 21 | 26 | 37 |
| declined | 30 | 30 | 25 | 14 |
| wrong | 0 | 0 | 0 | 0 |
| INVALID | 0 | 0 | 0 | 0 |

`new` and `62` columns differ only where 0062 builds what 0060 declines. The 0062 numbers include the cases it leaves alone.

### E: one fillet on an edge at a dihedral angle other than 90 degrees (45, 60, 120, 135), radii below, at and above the face width

| case | rule | rule volume | kernel.5 | main (0059) | branch (0060) | 0062 candidate | classification (0060 / 0062) | decision |
|---|---|---|---|---|---|---|---|---|
| [E45-r1_25](#e45-r1_25) | TT | 150.391310 | valid, 150.391310 | valid, 150.391310 | valid, 150.391310 | valid, 150.391310 | right / right | - |
| [E45-r1_65](#e45-r1_65) | TT | 136.052361 | valid, 136.052361 | valid, 136.052361 | valid, 136.052361 | valid, 136.052361 | right / right | - |
| [E45-r2](#e45-r2) | P1T2 | 125.715761 | declined | declined | declined | valid, 125.715761 | declined / right | - |
| [E45-r3](#e45-r3) | P1T2 | 110.533152 | declined | declined | declined | valid, 110.533152 | declined / right | - |
| [E60-r1_75](#e60-r1_75) | TT | 186.872466 | valid, 186.872466 | valid, 186.872466 | valid, 186.872466 | valid, 186.872466 | right / right | - |
| [E60-r2_3](#e60-r2_3) | TT | 171.617360 | valid, 171.617360 | valid, 171.617360 | valid, 171.617360 | valid, 171.617360 | right / right | - |
| [E60-r3](#e60-r3) | P1T2 | 155.086267 | declined | declined | declined | valid, 155.086267 | declined / right | - |
| [E60-r4_2](#e60-r4_2) | PP | 137.833790 | declined | declined | declined | valid, 137.833790 | declined / right | D4 |
| [E120-r5_2](#e120-r5_2) | TT | 193.311693 | valid, 193.311693 | valid, 193.311693 | valid, 193.311693 | valid, 193.311693 | right / right | D4 |
| [E120-r6_9](#e120-r6_9) | TT | 182.255011 | valid, 182.255011 | valid, 182.255011 | valid, 182.255011 | valid, 182.255011 | right / right | D4 |
| [E120-r8_7](#e120-r8_7) | P1T2 | 169.972974 | declined | declined | declined | valid, 169.972974 | declined / right | D4 |
| [E120-r12_2](#e120-r12_2) | PP | 151.041842 | declined | declined | declined | valid, 151.041842 | declined / right | D4 |
| [E135-r7_25](#e135-r7_25) | TT | 158.397079 | valid, 158.397079 | valid, 158.397079 | valid, 158.397079 | valid, 158.397079 | right / right | D4 |
| [E135-r9_6](#e135-r9_6) | TT | 149.877882 | valid, 149.877882 | valid, 149.877882 | valid, 149.877882 | valid, 149.877882 | right / right | D4 |
| [E135-r12](#e135-r12) | P1T2 | 140.575109 | declined | declined | declined | valid, 140.575109 | declined / right | D4 |
| [E135-r17](#e135-r17) | PP | 124.814833 | declined | declined | declined | valid, 124.814833 | declined / right | D4 |

### F: two fillets at once on opposite edges of a face, walls at 60 and 120 degrees

| case | rule | rule volume | kernel.5 | main (0059) | branch (0060) | 0062 candidate | classification (0060 / 0062) | decision |
|---|---|---|---|---|---|---|---|---|
| [F60-r1_15](#f60-r1_15) | pair | 46.837537 | valid, 46.837537 | valid, 46.837537 | valid, 46.837537 | valid, 46.837537 | right / right | D4 |
| [F60-r1_45](#f60-r1_45) | pair | 36.467434 | declined | declined | valid, 36.467434 | valid, 36.467434 | right / right | D4 |
| [F60-r1_6](#f60-r1_6) | pair | 30.879729 | declined | declined | valid, 30.879729 | valid, 30.879729 | right / right | D4 |
| [F120-r3_5](#f120-r3_5) | pair | 129.725084 | declined | declined | valid, 129.725084 | valid, 129.725084 | right / right | D4 |
| [F120-r4_3](#f120-r4_3) | pair | 123.104189 | declined | declined | valid, 123.104189 | valid, 123.104189 | right / right | D4 |
| [F120-r4_85](#f120-r4_85) | pair | 117.960340 | declined | declined | valid, 117.960340 | valid, 117.960340 | right / right | D4 |

### G: a concave edge, the inside corner of an L, with large radii

| case | rule | rule volume | kernel.5 | main (0059) | branch (0060) | 0062 candidate | classification (0060 / 0062) | decision |
|---|---|---|---|---|---|---|---|---|
| [G-L-r2_5](#g-l-r2_5) | TT | 253.412615 | valid, 253.412615 | valid, 253.412615 | valid, 253.412615 | valid, 253.412615 | right / right | - |
| [G-L-r3_5](#g-l-r3_5) | T1P2 | 265.152066 | declined | declined | declined | valid, 265.152066 | declined / right | D3 |
| [G-L-r5](#g-l-r5) | PP | 277.353482 | declined | declined | declined | valid, 277.353482 | declined / right | D3 |
| [G-L-r8](#g-l-r8) | PP | 286.576381 | declined | declined | declined | valid, 286.576381 | declined / right | D3 |

### H: curved faces: cylinder, cone, dome, washer bore, flat against a convex cylinder, flat against a concave groove

| case | rule | rule volume | kernel.5 | main (0059) | branch (0060) | 0062 candidate | classification (0060 / 0062) | decision |
|---|---|---|---|---|---|---|---|---|
| [H1-cyl-r3](#h1-cyl-r3) | TT | 418.693668 | valid, 418.693668 | valid, 418.693668 | valid, 418.693668 | valid, 418.693668 | right / right | - |
| [H1-cyl-r5](#h1-cyl-r5) | TT | 340.339204 | valid, 340.339204 | valid, 340.339204 | valid, 340.339204 | valid, 340.339204 | right / right | - |
| [H1-cyl-r5_5](#h1-cyl-r5_5) | T1P2 | 319.191422 | declined | declined | declined | declined | declined / declined | D1 |
| [H1-cyl-r7](#h1-cyl-r7) | PP | 270.859271 | declined | declined | declined | declined | declined / declined | D1 |
| [H2-cyl3-r3_5](#h2-cyl3-r3_5) | P1T2 | 168.935364 | declined | declined | declined | declined | declined / declined | D2 |
| [H2-cyl3-r4_5](#h2-cyl3-r4_5) | P1T2 | 148.533293 | declined | declined | declined | declined | declined / declined | D2 |
| [H3-cone-r1_5](#h3-cone-r1_5) | TT | 105.186606 | valid, 105.186606 | valid, 105.186606 | valid, 105.186606 | valid, 105.186606 | right / right | - |
| [H3-cone-r2_2](#h3-cone-r2_2) | TT | 64.478542 | valid, 64.478542 | valid, 64.478542 | valid, 64.478542 | valid, 64.478542 | right / right | - |
| [H3-cone-r2_5](#h3-cone-r2_5) | P1T2 | 48.979129 | declined | declined | declined | declined | declined / declined | D1 |
| [H3-cone-r3_5](#h3-cone-r3_5) | P1T2 | 24.574664 | declined | declined | declined | declined | declined / declined | D1 |
| [H4-dome-r1_5](#h4-dome-r1_5) | TT | 424.865199 | valid, 424.865208 | valid, 424.865208 | valid, 424.865208 | valid, 424.865208 | right / right | - |
| [H4-dome-r2_5](#h4-dome-r2_5) | TT | 330.583330 | valid, 330.583343 | valid, 330.583343 | valid, 330.583343 | valid, 330.583343 | right / right | - |
| [H4-dome-r4_5](#h4-dome-r4_5) | PP | 13.738093 | declined | declined | declined | declined | declined / declined | D1 |
| [H5-washer-r2](#h5-washer-r2) | TT | 490.347928 | valid, 490.347928 | valid, 490.347928 | valid, 490.347928 | valid, 490.347928 | right / right | - |
| [H5-washer-r3_5](#h5-washer-r3_5) | P1T2 | 449.746385 | declined | declined | declined | declined | declined / declined | D2 |
| [H5-washer-r5](#h5-washer-r5) | P1T2 | 416.729380 | declined | declined | declined | declined | declined / declined | D2 |
| [H5-washer-r7](#h5-washer-r7) | P1T2 | 384.480018 | declined | declined | declined | declined | declined / declined | D2 |
| [H6-dprism-r1_5](#h6-dprism-r1_5) | TT | 672.340558 | valid, 672.340558 | valid, 672.340558 | valid, 672.340558 | valid, 672.340558 | right / right | - |
| [H6-dprism-r3](#h6-dprism-r3) | TT | 663.822555 | valid, 663.822555 | valid, 663.822555 | valid, 663.822555 | valid, 663.822555 | right / right | - |
| [H6-dprism-r4_5](#h6-dprism-r4_5) | undefined | - | declined | declined | declined | declined | declined / declined | D5 |
| [H6-dprism-r8](#h6-dprism-r8) | undefined | - | declined | declined | declined | declined | declined / declined | D5 |
| [H7-groove-r2](#h7-groove-r2) | TT | 574.506421 | valid, 574.506421 | valid, 574.506421 | valid, 574.506421 | valid, 574.506421 | right / right | - |
| [H7-groove-r4](#h7-groove-r4) | TT | 568.112189 | valid, 568.112189 | valid, 568.112189 | valid, 568.112189 | valid, 568.112189 | right / right | - |
| [H7-groove-r5](#h7-groove-r5) | P1T2 | 564.982441 | declined | declined | declined | declined | declined / declined | D2 |
| [H7-groove-r8](#h7-groove-r8) | P1T2 | 559.546265 | declined | declined | declined | declined | declined / declined | D2 |

## Decisions waiting for you

Each is drawn in the images named. The rule itself is not ambiguous for a plane against a plane at any angle, convex or concave
(groups E, F, G: the arc is fixed by the rule and was checked against an independent reference), so those are only **confirmations**
(D3, D4). The rule is ambiguous where a face runs out and there is no edge to be the pivot (D1) or no arc exists at all (D5); where the
rule is clear but I have not built it (D2) the question is whether to.

**D1. A face of revolution that runs out at its centre: the pivot would be a point on the axis, not an edge.** Cases `H1-cyl-r5_5`,
`H1-cyl-r7` (the 5 mm top disc of a cylinder, r above 5), `H3-cone-r2_5`, `H3-cone-r3_5` (the base disc of a cone, r above 2.34),
`H4-dome-r4_5` (a hemispherical dome, r above 3). "Tangent to the face" on a disc ends at its centre, where there is no edge. Candidates,
all three drawn in the second row of each image:
- **A. The literal rule:** the arc passes through the axis point. The revolve of the rule's profile is a valid solid with a conical
  point at the axis (crease 95.22 degrees at the pole for `H1-cyl-r5_5`, 138.19 at both for `H4-dome-r4_5`, which collapses the dome to
  a lens). Volumes: 319.191 and 270.859 (H1), 48.979 and 24.575 (H3), 13.738 (H4). The reference panel (right, first row) is A.
- **B. Decline,** as every kernel does today (nil from `Shape.filleted`).
- **C. Clamp:** build the largest fillet that is tangent to both faces (orange): r = 5 on the cylinder (340.787), r = 2.3419 on the cone
  (56.778), r = 3 on the dome (137.517). Its outcome is the same body whatever larger r was asked for.
A for H1 has the arc's centre at x = -0.5, on the far side of the axis, so the arc reaches the axis at a slope; that is what makes the
tip conical. I do not choose.

**D2. Curved faces whose pivot is a real edge: build them?** `H2-cyl3-r3_5`, `-r4_5` (a short cylinder: the wall runs out onto the bottom
circle), `H5-washer-r3_5`, `-r5`, `-r7` (the 3 mm ring runs out onto the outer circle, the arc stays tangent to the bore wall), `H7-groove-r5`,
`-r8` (the 3 mm flat runs out onto the block edge, tangent to the concave groove). The rule is unambiguous here (a reference solid
exists and is valid, volumes in the table), and **every kernel declines.** 0062 does not build them: its tool is a prism of a planar
section, which needs both faces planar. Building them means a tool that is the sweep of the section region, extruded along a straight
edge (cylinder or groove: the face profile is an arc, extended past the pivot) or revolved about the axis of a circular edge (disc,
cylinder, cone, torus faces), then the same Cut. Estimate: days, plus the seam handling of a full revolution. Candidates: **leave
declined** (today's behaviour, safe) or **build** for faces of revolution about one axis and prisms of arcs. I would not start before D1.

**D3. A concave edge that runs out of face adds material up to the far edge, with a crease there.** Cases `G-L-r3_5`, `-r5`, `-r8`
(foot 4 past the wall, wall 3 above the foot). The rule applied to a concave corner fills the air wedge; at r = 3.5 the wall's top
edge is the pivot and the arc meets the top face at 81.79 degrees, at r = 5 and 8 it passes through the toe of the foot and the top of the
wall (the corner is filled by a shallow arc, volume 277.35 and 286.58 against 240 for the L). 0062 builds this (Fuse of the region, merged
by `ShapeUpgrade_UnifySameDomain`). Confirm that adding up to the far edge is wanted, as against refusing a concave fillet that does not fit
(the other candidate, B, is today's behaviour). Not built either way: two concave contours at once (their dual of the "intersection" is the
union of the two fills) and a convex and a concave contour at once; both decline.

**D4. At other angles "face width" in the rule is the tangent length, not the radius.** The rule as written for 90 degrees: r1 + r2 = w gives
tangent arcs, above it they cross. At a dihedral angle theta the tangent point of a fillet of radius r is at distance t = r / tan(theta / 2) from
the edge (equal to r at 90). I used t throughout: it is the only reading in which "wherever a fillet meets a face it is tangent to it" stays
true, because a ball of radius r > w still touches a 120 degree face when t < w (case `E120-r5_2`: r = 5.2 on a 4 mm face is the ordinary
fillet, all kernels right). The alternative, a literal radius against width threshold, would put a pivot where a tangent fillet exists.
Equal-radii pairs (group F) are tangent to each other when 2 t = w (`F60-r1_15`, `F120-r3_5`: r1 + r2 is 2.3 and 7, not w) and cross above.
Please confirm t, not r. Every E and F case states its tangent length.

**D5. No arc at all: the ball does not fit.** `H6-dprism-r4_5`, `H6-dprism-r8` (the 8 mm flat against a convex cylinder of radius 5: a
circle tangent to both inside the part has r at most 4). Candidates: **B decline** (what all kernels do) or **C clamp** to r = 4. There is no
"A": the circles that touch a face and pass through a pivot leave the part, so the result would not be a fillet of this body.

Also unchanged from #3237 and not re-tested at other angles: both fillets at once give the intersection, one after the other differ
(the first fillet's tangent edge is the second's pivot).

## Recipes

Every recipe: the original body, the fillet to apply and where, and the profile the rule gives as a sketch to compare against.

## E: one fillet on an edge at a dihedral angle other than 90 degrees (45, 60, 120, 135), radii below, at and above the face width

<a id="e45-r1_25"></a>

### E: one fillet r = 1.25 on the 45 degree edge of a parallelogram prism (faces 4 and 6 wide)

File `E45-r1_25.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (0.0000, 0.0000).
3. Line to (4.2426, -4.2426).
4. Line to (8.2426, -4.2426).
5. Line back to the start (4.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 1.25 on the straight edge through the point (0, 5, 0).

Expected (the rule): tangent to both faces.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (3.0178, 0.0000).
3. Arc, centre (3.0178, -1.2500), radius 1.25, from (3.0178, 0.0000) to (2.1339, -2.1339), passing through (1.8629, -0.7716), counter-clockwise.
4. Line to (4.2426, -4.2426).
5. Line to (8.2426, -4.2426).
6. Line back to the start (4.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 150.391310 (original body 169.705627).

Kernel results: kernel.5 (pinned) valid 150.391310; main (0059) valid 150.391310; this branch (0060) valid 150.391310; reference valid 150.391310.

<a id="e45-r1_65"></a>

### E: one fillet r = 1.65 on the 45 degree edge of a parallelogram prism (faces 4 and 6 wide)

File `E45-r1_65.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (0.0000, 0.0000).
3. Line to (4.2426, -4.2426).
4. Line to (8.2426, -4.2426).
5. Line back to the start (4.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 1.65 on the straight edge through the point (0, 5, 0).

Expected (the rule): tangent to both faces.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (3.9835, 0.0000).
3. Arc, centre (3.9835, -1.6500), radius 1.65, from (3.9835, 0.0000) to (2.8167, -2.8167), passing through (2.4591, -1.0186), counter-clockwise.
4. Line to (4.2426, -4.2426).
5. Line to (8.2426, -4.2426).
6. Line back to the start (4.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 136.052361 (original body 169.705627).

Kernel results: kernel.5 (pinned) valid 136.052361; main (0059) valid 136.052361; this branch (0060) valid 136.052361; reference valid 136.052361.

<a id="e45-r2"></a>

### E: one fillet r = 2 on the 45 degree edge of a parallelogram prism (faces 4 and 6 wide)

File `E45-r2.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (0.0000, 0.0000).
3. Line to (4.2426, -4.2426).
4. Line to (8.2426, -4.2426).
5. Line back to the start (4.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 2 on the straight edge through the point (0, 5, 0).

Expected (the rule): the incoming face runs out: its far edge is the pivot; crease at the first pivot: 65.53 deg between the normals.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Arc, centre (4.7014, -1.8730), radius 2, from (4.0000, 0.0000) to (3.2872, -3.2872), passing through (2.7468, -1.4491), counter-clockwise.
3. Line to (4.2426, -4.2426).
4. Line to (8.2426, -4.2426).
5. Line back to the start (4.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 125.715761 (original body 169.705627).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; 0062 candidate valid 125.715761; reference valid 125.715761.

<a id="e45-r3"></a>

### E: one fillet r = 3 on the 45 degree edge of a parallelogram prism (faces 4 and 6 wide)

File `E45-r3.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (0.0000, 0.0000).
3. Line to (4.2426, -4.2426).
4. Line to (8.2426, -4.2426).
5. Line back to the start (4.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 3 on the straight edge through the point (0, 5, 0).

Expected (the rule): the incoming face runs out: its far edge is the pivot; crease at the first pivot: 93.28 deg between the normals.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Arc, centre (6.2392, -1.9965), radius 3, from (4.0000, 0.0000) to (4.1178, -4.1178), passing through (3.2404, -2.0823), counter-clockwise.
3. Line to (4.2426, -4.2426).
4. Line to (8.2426, -4.2426).
5. Line back to the start (4.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 110.533152 (original body 169.705627).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; 0062 candidate valid 110.533152; reference valid 110.533152.

<a id="e60-r1_75"></a>

### E: one fillet r = 1.75 on the 60 degree edge of a parallelogram prism (faces 4 and 6 wide)

File `E60-r1_75.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (0.0000, 0.0000).
3. Line to (3.0000, -5.1962).
4. Line to (7.0000, -5.1962).
5. Line back to the start (4.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 1.75 on the straight edge through the point (0, 5, 0).

Expected (the rule): tangent to both faces.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (3.0311, 0.0000).
3. Arc, centre (3.0311, -1.7500), radius 1.75, from (3.0311, 0.0000) to (1.5155, -2.6250), passing through (1.5155, -0.8750), counter-clockwise.
4. Line to (3.0000, -5.1962).
5. Line to (7.0000, -5.1962).
6. Line back to the start (4.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 186.872466 (original body 207.846097).

Kernel results: kernel.5 (pinned) valid 186.872466; main (0059) valid 186.872466; this branch (0060) valid 186.872466; reference valid 186.872466.

<a id="e60-r2_3"></a>

### E: one fillet r = 2.3 on the 60 degree edge of a parallelogram prism (faces 4 and 6 wide)

File `E60-r2_3.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (0.0000, 0.0000).
3. Line to (3.0000, -5.1962).
4. Line to (7.0000, -5.1962).
5. Line back to the start (4.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 2.3 on the straight edge through the point (0, 5, 0).

Expected (the rule): tangent to both faces.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (3.9837, 0.0000).
3. Arc, centre (3.9837, -2.3000), radius 2.3, from (3.9837, 0.0000) to (1.9919, -3.4500), passing through (1.9919, -1.1500), counter-clockwise.
4. Line to (3.0000, -5.1962).
5. Line to (7.0000, -5.1962).
6. Line back to the start (4.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 171.617360 (original body 207.846097).

Kernel results: kernel.5 (pinned) valid 171.617360; main (0059) valid 171.617360; this branch (0060) valid 171.617360; reference valid 171.617360.

<a id="e60-r3"></a>

### E: one fillet r = 3 on the 60 degree edge of a parallelogram prism (faces 4 and 6 wide)

File `E60-r3.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (0.0000, 0.0000).
3. Line to (3.0000, -5.1962).
4. Line to (7.0000, -5.1962).
5. Line back to the start (4.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 3 on the straight edge through the point (0, 5, 0).

Expected (the rule): the incoming face runs out: its far edge is the pivot; crease at the first pivot: 81.10 deg between the normals.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Arc, centre (5.0800, -2.7988), radius 3, from (4.0000, 0.0000) to (2.4819, -4.2988), passing through (2.2512, -1.7999), counter-clockwise.
3. Line to (3.0000, -5.1962).
4. Line to (7.0000, -5.1962).
5. Line back to the start (4.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 155.086267 (original body 207.846097).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; 0062 candidate valid 155.086267; reference valid 155.086267.

<a id="e60-r4_2"></a>

### E: one fillet r = 4.2 on the 60 degree edge of a parallelogram prism (faces 4 and 6 wide)

File `E60-r4_2.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (0.0000, 0.0000).
3. Line to (3.0000, -5.1962).
4. Line to (7.0000, -5.1962).
5. Line back to the start (4.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 4.2 on the straight edge through the point (0, 5, 0).

Expected (the rule): both faces run out: pivots at both far edges; crease at the first pivot: 100.06 deg between the normals; crease at the second pivot: 61.85 deg between the normals.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Arc, centre (6.7031, -3.2145), radius 4.2, from (4.0000, 0.0000) to (3.0000, -5.1962), passing through (2.5788, -2.4208), counter-clockwise.
3. Line to (7.0000, -5.1962).
4. Line back to the start (4.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 137.833790 (original body 207.846097).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; 0062 candidate valid 137.833790; reference valid 137.833790.

<a id="e120-r5_2"></a>

### E: one fillet r = 5.2 on the 120 degree edge of a parallelogram prism (faces 4 and 6 wide)

File `E120-r5_2.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (0.0000, 0.0000).
3. Line to (-3.0000, -5.1962).
4. Line to (1.0000, -5.1962).
5. Line back to the start (4.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 5.2 on the straight edge through the point (0, 5, 0).

Expected (the rule): tangent to both faces.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (3.0022, 0.0000).
3. Arc, centre (3.0022, -5.2000), radius 5.2, from (3.0022, 0.0000) to (-1.5011, -2.6000), passing through (0.4022, -0.6967), counter-clockwise.
4. Line to (-3.0000, -5.1962).
5. Line to (1.0000, -5.1962).
6. Line back to the start (4.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 193.311693 (original body 207.846097).

Kernel results: kernel.5 (pinned) valid 193.311693; main (0059) valid 193.311693; this branch (0060) valid 193.311693; reference valid 193.311693.

<a id="e120-r6_9"></a>

### E: one fillet r = 6.9 on the 120 degree edge of a parallelogram prism (faces 4 and 6 wide)

File `E120-r6_9.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (0.0000, 0.0000).
3. Line to (-3.0000, -5.1962).
4. Line to (1.0000, -5.1962).
5. Line back to the start (4.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 6.9 on the straight edge through the point (0, 5, 0).

Expected (the rule): tangent to both faces.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (3.9837, 0.0000).
3. Arc, centre (3.9837, -6.9000), radius 6.9, from (3.9837, 0.0000) to (-1.9919, -3.4500), passing through (0.5337, -0.9244), counter-clockwise.
4. Line to (-3.0000, -5.1962).
5. Line to (1.0000, -5.1962).
6. Line back to the start (4.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 182.255011 (original body 207.846097).

Kernel results: kernel.5 (pinned) valid 182.255011; main (0059) valid 182.255011; this branch (0060) valid 182.255011; reference valid 182.255011.

<a id="e120-r8_7"></a>

### E: one fillet r = 8.7 on the 120 degree edge of a parallelogram prism (faces 4 and 6 wide)

File `E120-r8_7.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (0.0000, 0.0000).
3. Line to (-3.0000, -5.1962).
4. Line to (1.0000, -5.1962).
5. Line back to the start (4.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 8.7 on the straight edge through the point (0, 5, 0).

Expected (the rule): the incoming face runs out: its far edge is the pivot; crease at the first pivot: 127.00 deg between the normals.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Arc, centre (5.0604, -8.6351), radius 8.7, from (4.0000, 0.0000) to (-2.4740, -4.2851), passing through (0.2585, -1.3804), counter-clockwise.
3. Line to (-3.0000, -5.1962).
4. Line to (1.0000, -5.1962).
5. Line back to the start (4.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 169.972974 (original body 207.846097).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; 0062 candidate valid 169.972974; reference valid 169.972974.

<a id="e120-r12_2"></a>

### E: one fillet r = 12.2 on the 120 degree edge of a parallelogram prism (faces 4 and 6 wide)

File `E120-r12_2.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (0.0000, 0.0000).
3. Line to (-3.0000, -5.1962).
4. Line to (1.0000, -5.1962).
5. Line back to the start (4.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 12.2 on the straight edge through the point (0, 5, 0).

Expected (the rule): both faces run out: pivots at both far edges; crease at the first pivot: 135.65 deg between the normals; crease at the second pivot: 122.48 deg between the normals.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Arc, centre (7.2917, -11.7475), radius 12.2, from (4.0000, 0.0000) to (-3.0000, -5.1962), passing through (0.0200, -1.9515), counter-clockwise.
3. Line to (1.0000, -5.1962).
4. Line back to the start (4.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 151.041842 (original body 207.846097).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; 0062 candidate valid 151.041842; reference valid 151.041842.

<a id="e135-r7_25"></a>

### E: one fillet r = 7.25 on the 135 degree edge of a parallelogram prism (faces 4 and 6 wide)

File `E135-r7_25.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (0.0000, 0.0000).
3. Line to (-4.2426, -4.2426).
4. Line to (-0.2426, -4.2426).
5. Line back to the start (4.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 7.25 on the straight edge through the point (0, 5, 0).

Expected (the rule): tangent to both faces.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (3.0030, 0.0000).
3. Arc, centre (3.0030, -7.2500), radius 7.25, from (3.0030, 0.0000) to (-2.1235, -2.1235), passing through (0.2286, -0.5519), counter-clockwise.
4. Line to (-4.2426, -4.2426).
5. Line to (-0.2426, -4.2426).
6. Line back to the start (4.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 158.397079 (original body 169.705627).

Kernel results: kernel.5 (pinned) valid 158.397079; main (0059) valid 158.397079; this branch (0060) valid 158.397079; reference valid 158.397079.

<a id="e135-r9_6"></a>

### E: one fillet r = 9.6 on the 135 degree edge of a parallelogram prism (faces 4 and 6 wide)

File `E135-r9_6.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (0.0000, 0.0000).
3. Line to (-4.2426, -4.2426).
4. Line to (-0.2426, -4.2426).
5. Line back to the start (4.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 9.6 on the straight edge through the point (0, 5, 0).

Expected (the rule): tangent to both faces.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (3.9765, 0.0000).
3. Arc, centre (3.9765, -9.6000), radius 9.6, from (3.9765, 0.0000) to (-2.8118, -2.8118), passing through (0.3027, -0.7308), counter-clockwise.
4. Line to (-4.2426, -4.2426).
5. Line to (-0.2426, -4.2426).
6. Line back to the start (4.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 149.877882 (original body 169.705627).

Kernel results: kernel.5 (pinned) valid 149.877882; main (0059) valid 149.877882; this branch (0060) valid 149.877882; reference valid 149.877882.

<a id="e135-r12"></a>

### E: one fillet r = 12 on the 135 degree edge of a parallelogram prism (faces 4 and 6 wide)

File `E135-r12.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (0.0000, 0.0000).
3. Line to (-4.2426, -4.2426).
4. Line to (-0.2426, -4.2426).
5. Line back to the start (4.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 12 on the straight edge through the point (0, 5, 0).

Expected (the rule): the incoming face runs out: its far edge is the pivot; crease at the first pivot: 139.84 deg between the normals.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Arc, centre (5.0134, -11.9571), radius 12, from (4.0000, 0.0000) to (-3.4718, -3.4718), passing through (-0.0432, -1.0746), counter-clockwise.
3. Line to (-4.2426, -4.2426).
4. Line to (-0.2426, -4.2426).
5. Line back to the start (4.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 140.575109 (original body 169.705627).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; 0062 candidate valid 140.575109; reference valid 140.575109.

<a id="e135-r17"></a>

### E: one fillet r = 17 on the 135 degree edge of a parallelogram prism (faces 4 and 6 wide)

File `E135-r17.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Line to (0.0000, 0.0000).
3. Line to (-4.2426, -4.2426).
4. Line to (-0.2426, -4.2426).
5. Line back to the start (4.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 17 on the straight edge through the point (0, 5, 0).

Expected (the rule): both faces run out: pivots at both far edges; crease at the first pivot: 146.41 deg between the normals; crease at the second pivot: 136.94 deg between the normals.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (4.0000, 0.0000).
2. Arc, centre (7.3640, -16.6638), radius 17, from (4.0000, 0.0000) to (-4.2426, -4.2426), passing through (-0.4161, -1.5486), counter-clockwise.
3. Line to (-0.2426, -4.2426).
4. Line back to the start (4.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 124.814833 (original body 169.705627).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; 0062 candidate valid 124.814833; reference valid 124.814833.

## F: two fillets at once on opposite edges of a face, walls at 60 and 120 degrees

<a id="f60-r1_15"></a>

### F: equal radii 1.15 on both top edges of a trapezoid prism, top 4 wide, walls 3 long at 60 degrees

File `F60-r1_15.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (2.0000, 0.0000).
2. Line to (-2.0000, 0.0000).
3. Line to (-0.5000, -2.5981).
4. Line to (0.5000, -2.5981).
5. Line back to the start (2.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 1.15 on the straight edge through the point (2, 5, 0); radius 1.15 on the straight edge through the point (-2, 5, 0), both in one operation.

Expected (the rule): tangent length sums to the face width or less: tangent arcs, junction 180 deg.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (-0.5000, -2.5981).
2. Line to (0.5000, -2.5981).
3. Line to (1.0041, -1.7250).
4. Arc, centre (0.0081, -1.1500), radius 1.15, from (1.0041, -1.7250) to (0.0081, 0.0000), passing through (1.0041, -0.5750), counter-clockwise.
5. Line to (-0.0081, 0.0000).
6. Arc, centre (-0.0081, -1.1500), radius 1.15, from (-0.0081, 0.0000) to (-1.0041, -1.7250), passing through (-1.0041, -0.5750), counter-clockwise.
7. Line back to the start (-0.5000, -2.5981), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 46.837537 (original body 64.951905).

Kernel results: kernel.5 (pinned) valid 46.837537; main (0059) valid 46.837537; this branch (0060) valid 46.837537; reference valid 46.837537.

<a id="f60-r1_45"></a>

### F: equal radii 1.45 on both top edges of a trapezoid prism, top 4 wide, walls 3 long at 60 degrees

File `F60-r1_45.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (2.0000, 0.0000).
2. Line to (-2.0000, 0.0000).
3. Line to (-0.5000, -2.5981).
4. Line to (0.5000, -2.5981).
5. Line back to the start (2.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 1.45 on the straight edge through the point (2, 5, 0); radius 1.45 on the straight edge through the point (-2, 5, 0), both in one operation.

Expected (the rule): the arcs cross at 138.69 deg (included, through the material).

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (-0.5000, -2.5981).
2. Line to (0.5000, -2.5981).
3. Line to (0.7443, -2.1750).
4. Arc, centre (-0.5115, -1.4500), radius 1.45, from (0.7443, -2.1750) to (-0.0000, -0.0932), passing through (0.8539, -0.9619), counter-clockwise.
5. Arc, centre (0.5115, -1.4500), radius 1.45, from (-0.0000, -0.0932) to (-0.7443, -2.1750), passing through (-0.8539, -0.9619), counter-clockwise.
6. Line back to the start (-0.5000, -2.5981), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 36.467434 (original body 64.951905).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) valid 36.467434; reference valid 36.467434.

<a id="f60-r1_6"></a>

### F: equal radii 1.6 on both top edges of a trapezoid prism, top 4 wide, walls 3 long at 60 degrees

File `F60-r1_6.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (2.0000, 0.0000).
2. Line to (-2.0000, 0.0000).
3. Line to (-0.5000, -2.5981).
4. Line to (0.5000, -2.5981).
5. Line back to the start (2.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 1.6 on the straight edge through the point (2, 5, 0); radius 1.6 on the straight edge through the point (-2, 5, 0), both in one operation.

Expected (the rule): the arcs cross at 122.36 deg (included, through the material).

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (-0.5000, -2.5981).
2. Line to (0.5000, -2.5981).
3. Line to (0.6144, -2.4000).
4. Arc, centre (-0.7713, -1.6000), radius 1.6, from (0.6144, -2.4000) to (0.0000, -0.1982), passing through (0.7699, -1.1700), counter-clockwise.
5. Arc, centre (0.7713, -1.6000), radius 1.6, from (0.0000, -0.1982) to (-0.6144, -2.4000), passing through (-0.7699, -1.1700), counter-clockwise.
6. Line back to the start (-0.5000, -2.5981), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 30.879729 (original body 64.951905).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) valid 30.879729; reference valid 30.879729.

<a id="f120-r3_5"></a>

### F: equal radii 3.5 on both top edges of a trapezoid prism, top 4 wide, walls 3 long at 120 degrees

File `F120-r3_5.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (2.0000, 0.0000).
2. Line to (-2.0000, 0.0000).
3. Line to (-3.5000, -2.5981).
4. Line to (3.5000, -2.5981).
5. Line back to the start (2.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 3.5 on the straight edge through the point (2, 5, 0); radius 3.5 on the straight edge through the point (-2, 5, 0), both in one operation.

Expected (the rule): the arcs cross at 179.32 deg (included, through the material).

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (-3.5000, -2.5981).
2. Line to (3.5000, -2.5981).
3. Line to (3.0104, -1.7500).
4. Arc, centre (-0.0207, -3.5000), radius 3.5, from (3.0104, -1.7500) to (0.0000, -0.0001), passing through (1.7382, -0.4741), counter-clockwise.
5. Arc, centre (0.0207, -3.5000), radius 3.5, from (0.0000, -0.0001) to (-3.0104, -1.7500), passing through (-1.7382, -0.4741), counter-clockwise.
6. Line back to the start (-3.5000, -2.5981), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 129.725084 (original body 142.894192).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) valid 129.725084; reference valid 129.725084.

<a id="f120-r4_3"></a>

### F: equal radii 4.3 on both top edges of a trapezoid prism, top 4 wide, walls 3 long at 120 degrees

File `F120-r4_3.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (2.0000, 0.0000).
2. Line to (-2.0000, 0.0000).
3. Line to (-3.5000, -2.5981).
4. Line to (3.5000, -2.5981).
5. Line back to the start (2.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 4.3 on the straight edge through the point (2, 5, 0); radius 4.3 on the straight edge through the point (-2, 5, 0), both in one operation.

Expected (the rule): the arcs cross at 167.11 deg (included, through the material).

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (-3.5000, -2.5981).
2. Line to (3.5000, -2.5981).
3. Line to (3.2413, -2.1500).
4. Arc, centre (-0.4826, -4.3000), radius 4.3, from (3.2413, -2.1500) to (0.0000, -0.0272), passing through (1.8733, -0.7028), counter-clockwise.
5. Arc, centre (0.4826, -4.3000), radius 4.3, from (0.0000, -0.0272) to (-3.2413, -2.1500), passing through (-1.8733, -0.7028), counter-clockwise.
6. Line back to the start (-3.5000, -2.5981), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 123.104189 (original body 142.894192).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) valid 123.104189; reference valid 123.104189.

<a id="f120-r4_85"></a>

### F: equal radii 4.85 on both top edges of a trapezoid prism, top 4 wide, walls 3 long at 120 degrees

File `F120-r4_85.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (2.0000, 0.0000).
2. Line to (-2.0000, 0.0000).
3. Line to (-3.5000, -2.5981).
4. Line to (3.5000, -2.5981).
5. Line back to the start (2.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 4.85 on the straight edge through the point (2, 5, 0); radius 4.85 on the straight edge through the point (-2, 5, 0), both in one operation.

Expected (the rule): the arcs cross at 161.01 deg (included, through the material).

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (-3.5000, -2.5981).
2. Line to (3.5000, -2.5981).
3. Line to (3.4001, -2.4250).
4. Arc, centre (-0.8001, -4.8500), radius 4.85, from (3.4001, -2.4250) to (-0.0000, -0.0665), passing through (1.9642, -0.8649), counter-clockwise.
5. Arc, centre (0.8001, -4.8500), radius 4.85, from (-0.0000, -0.0665) to (-3.4001, -2.4250), passing through (-1.9642, -0.8649), counter-clockwise.
6. Line back to the start (-3.5000, -2.5981), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 117.960340 (original body 142.894192).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) valid 117.960340; reference valid 117.960340.

## G: a concave edge, the inside corner of an L, with large radii

<a id="g-l-r2_5"></a>

### G: concave edge, radius 2.5 in the inside corner of an L profile (foot 4 past the wall, wall 3 above the foot)

File `G-L-r2_5.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (6.0000, 0.0000).
3. Line to (6.0000, 3.0000).
4. Line to (2.0000, 3.0000).
5. Line to (2.0000, 6.0000).
6. Line to (0.0000, 6.0000).
7. Line back to the start (0.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 2.5 on the straight edge through the point (2, 5, 3).

Expected (the rule): tangent to both faces; concave edge: material is ADDED (the arc fills the corner).

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (6.0000, 0.0000).
3. Line to (6.0000, 3.0000).
4. Line to (4.5000, 3.0000).
5. Arc, centre (4.5000, 5.5000), radius 2.5, from (4.5000, 3.0000) to (2.0000, 5.5000), passing through (2.7322, 3.7322), clockwise.
6. Line to (2.0000, 6.0000).
7. Line to (0.0000, 6.0000).
8. Line back to the start (0.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 253.412615 (original body 240.000000).

Kernel results: kernel.5 (pinned) valid 253.412615; main (0059) valid 253.412615; this branch (0060) valid 253.412615; reference valid 253.412615.

<a id="g-l-r3_5"></a>

### G: concave edge, radius 3.5 in the inside corner of an L profile (foot 4 past the wall, wall 3 above the foot)

File `G-L-r3_5.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (6.0000, 0.0000).
3. Line to (6.0000, 3.0000).
4. Line to (2.0000, 3.0000).
5. Line to (2.0000, 6.0000).
6. Line to (0.0000, 6.0000).
7. Line back to the start (0.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 3.5 on the straight edge through the point (2, 5, 3).

Expected (the rule): the outgoing face runs out: its far edge is the pivot; crease at the second pivot: 81.79 deg between the normals; concave edge: material is ADDED (the arc fills the corner).

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (6.0000, 0.0000).
3. Line to (6.0000, 3.0000).
4. Line to (5.4641, 3.0000).
5. Arc, centre (5.4641, 6.5000), radius 3.5, from (5.4641, 3.0000) to (2.0000, 6.0000), passing through (3.1728, 3.8542), clockwise.
6. Line to (0.0000, 6.0000).
7. Line back to the start (0.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 265.152066 (original body 240.000000).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; 0062 candidate valid 265.152066; reference valid 265.152066.

<a id="g-l-r5"></a>

### G: concave edge, radius 5 in the inside corner of an L profile (foot 4 past the wall, wall 3 above the foot)

File `G-L-r5.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (6.0000, 0.0000).
3. Line to (6.0000, 3.0000).
4. Line to (2.0000, 3.0000).
5. Line to (2.0000, 6.0000).
6. Line to (0.0000, 6.0000).
7. Line back to the start (0.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 5 on the straight edge through the point (2, 5, 3).

Expected (the rule): both faces run out: pivots at both far edges; crease at the first pivot: 83.13 deg between the normals; crease at the second pivot: 66.87 deg between the normals; concave edge: material is ADDED (the arc fills the corner).

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (6.0000, 0.0000).
3. Line to (6.0000, 3.0000).
4. Arc, centre (6.5981, 7.9641), radius 5, from (6.0000, 3.0000) to (2.0000, 6.0000), passing through (3.5981, 3.9641), clockwise.
5. Line to (0.0000, 6.0000).
6. Line back to the start (0.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 277.353482 (original body 240.000000).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; 0062 candidate valid 277.353482; reference valid 277.353482.

<a id="g-l-r8"></a>

### G: concave edge, radius 8 in the inside corner of an L profile (foot 4 past the wall, wall 3 above the foot)

File `G-L-r8.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (6.0000, 0.0000).
3. Line to (6.0000, 3.0000).
4. Line to (2.0000, 3.0000).
5. Line to (2.0000, 6.0000).
6. Line to (0.0000, 6.0000).
7. Line back to the start (0.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 8 on the straight edge through the point (2, 5, 3).

Expected (the rule): both faces run out: pivots at both far edges; crease at the first pivot: 71.34 deg between the normals; crease at the second pivot: 55.08 deg between the normals; concave edge: material is ADDED (the arc fills the corner).

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (6.0000, 0.0000).
3. Line to (6.0000, 3.0000).
4. Arc, centre (8.5596, 10.5795), radius 8, from (6.0000, 3.0000) to (2.0000, 6.0000), passing through (3.7596, 4.1795), clockwise.
5. Line to (0.0000, 6.0000).
6. Line back to the start (0.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 286.576381 (original body 240.000000).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; 0062 candidate valid 286.576381; reference valid 286.576381.

## H: curved faces: cylinder, cone, dome, washer bore, flat against a convex cylinder, flat against a concave groove

<a id="h1-cyl-r3"></a>

### H1: top edge of a cylinder (radius 5, height 6), fillet 3

File `H1-cyl-r3.png`. Body: the section turned about the Z axis

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (5.0000, 0.0000).
3. Line to (5.0000, 6.0000).
4. Line to (0.0000, 6.0000).
5. Line back to the start (0.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 3 on the circular edge through the point (0, 5, 6).

Expected (the rule): tangent to both faces.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (5.0000, 0.0000).
3. Line to (5.0000, 3.0000).
4. Arc, centre (2.0000, 3.0000), radius 3, from (5.0000, 3.0000) to (2.0000, 6.0000), passing through (4.1213, 5.1213), counter-clockwise.
5. Line to (0.0000, 6.0000).
6. Line back to the start (0.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 418.693668 (original body 471.238898).

Kernel results: kernel.5 (pinned) valid 418.693668; main (0059) valid 418.693668; this branch (0060) valid 418.693668; reference valid 418.693668.

<a id="h1-cyl-r5"></a>

### H1: top edge of a cylinder (radius 5, height 6), fillet 5

File `H1-cyl-r5.png`. Body: the section turned about the Z axis

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (5.0000, 0.0000).
3. Line to (5.0000, 6.0000).
4. Line to (0.0000, 6.0000).
5. Line back to the start (0.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 5 on the circular edge through the point (0, 5, 6).

Expected (the rule): tangent to both faces; crease at the second pivot: 90.00 deg between the normals.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (5.0000, 0.0000).
3. Line to (5.0000, 1.0000).
4. Arc, centre (0.0000, 1.0000), radius 5, from (5.0000, 1.0000) to (0.0000, 6.0000), passing through (3.5355, 4.5355), counter-clockwise.
5. Line back to the start (0.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 340.339204 (original body 471.238898).

Kernel results: kernel.5 (pinned) valid 340.339204; main (0059) valid 340.339204; this branch (0060) valid 340.339204; reference valid 340.339204.

<a id="h1-cyl-r5_5"></a>

### H1: top edge of a cylinder (radius 5, height 6), fillet 5.5

File `H1-cyl-r5_5.png`. Body: the section turned about the Z axis

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (5.0000, 0.0000).
3. Line to (5.0000, 6.0000).
4. Line to (0.0000, 6.0000).
5. Line back to the start (0.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 5.5 on the circular edge through the point (0, 5, 6).

Expected (the rule): the outgoing face runs out: its far edge is the pivot; crease at the second pivot: 95.22 deg between the normals.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (5.0000, 0.0000).
3. Line to (5.0000, 0.5228).
4. Arc, centre (-0.5000, 0.5228), radius 5.5, from (5.0000, 0.5228) to (0.0000, 6.0000), passing through (3.5620, 4.2309), counter-clockwise.
5. Line back to the start (0.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 319.191422 (original body 471.238898).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; reference valid 319.191422.

<a id="h1-cyl-r7"></a>

### H1: top edge of a cylinder (radius 5, height 6), fillet 7

File `H1-cyl-r7.png`. Body: the section turned about the Z axis

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (5.0000, 0.0000).
3. Line to (5.0000, 6.0000).
4. Line to (0.0000, 6.0000).
5. Line back to the start (0.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 7 on the circular edge through the point (0, 5, 6).

Expected (the rule): both faces run out: pivots at both far edges; crease at the first pivot: 95.90 deg between the normals; crease at the second pivot: 106.29 deg between the normals.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (5.0000, 0.0000).
3. Arc, centre (-1.9630, -0.7191), radius 7, from (5.0000, 0.0000) to (0.0000, 6.0000), passing through (3.4146, 3.7622), counter-clockwise.
4. Line back to the start (0.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 270.859271 (original body 471.238898).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; reference valid 270.859271.

<a id="h2-cyl3-r3_5"></a>

### H2: top edge of a short cylinder (radius 5, height 3), fillet 3.5: the wall runs out, the bottom circle is the pivot

File `H2-cyl3-r3_5.png`. Body: the section turned about the Z axis

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (5.0000, 0.0000).
3. Line to (5.0000, 3.0000).
4. Line to (0.0000, 3.0000).
5. Line back to the start (0.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 3.5 on the circular edge through the point (0, 5, 3).

Expected (the rule): the incoming face runs out: its far edge is the pivot; crease at the first pivot: 98.21 deg between the normals.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (5.0000, 0.0000).
3. Arc, centre (1.5359, -0.5000), radius 3.5, from (5.0000, 0.0000) to (1.5359, 3.0000), passing through (3.8272, 2.1458), counter-clockwise.
4. Line to (0.0000, 3.0000).
5. Line back to the start (0.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 168.935364 (original body 235.619449).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; reference valid 168.935364.

<a id="h2-cyl3-r4_5"></a>

### H2: top edge of a short cylinder (radius 5, height 3), fillet 4.5: the wall runs out, the bottom circle is the pivot

File `H2-cyl3-r4_5.png`. Body: the section turned about the Z axis

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (5.0000, 0.0000).
3. Line to (5.0000, 3.0000).
4. Line to (0.0000, 3.0000).
5. Line back to the start (0.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 4.5 on the circular edge through the point (0, 5, 3).

Expected (the rule): the incoming face runs out: its far edge is the pivot; crease at the first pivot: 109.47 deg between the normals.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (5.0000, 0.0000).
3. Arc, centre (0.7574, -1.5000), radius 4.5, from (5.0000, 0.0000) to (0.7574, 3.0000), passing through (3.3554, 2.1742), counter-clockwise.
4. Line to (0.0000, 3.0000).
5. Line back to the start (0.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 148.533293 (original body 235.619449).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; reference valid 148.533293.

<a id="h3-cone-r1_5"></a>

### H3: base edge of a cone (base radius 5, apex 6 above), fillet 1.5

File `H3-cone-r1_5.png`. Body: the section turned about the Z axis

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (5.0000, 0.0000).
3. Line to (0.0000, 6.0000).
4. Line back to the start (0.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 1.5 on the circular edge through the point (0, 5, 0).

Expected (the rule): tangent to both faces.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (1.7974, 0.0000).
3. Arc, centre (1.7974, 1.5000), radius 1.5, from (1.7974, 0.0000) to (2.9498, 2.4603), passing through (3.1558, 0.8638), counter-clockwise.
4. Line to (0.0000, 6.0000).
5. Line back to the start (0.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 105.186606 (original body 157.079633).

Kernel results: kernel.5 (pinned) valid 105.186606; main (0059) valid 105.186606; this branch (0060) valid 105.186606; reference valid 105.186606.

<a id="h3-cone-r2_2"></a>

### H3: base edge of a cone (base radius 5, apex 6 above), fillet 2.2

File `H3-cone-r2_2.png`. Body: the section turned about the Z axis

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (5.0000, 0.0000).
3. Line to (0.0000, 6.0000).
4. Line back to the start (0.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 2.2 on the circular edge through the point (0, 5, 0).

Expected (the rule): tangent to both faces.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (0.3029, 0.0000).
3. Arc, centre (0.3029, 2.2000), radius 2.2, from (0.3029, 0.0000) to (1.9930, 3.6084), passing through (2.2952, 1.2669), counter-clockwise.
4. Line to (0.0000, 6.0000).
5. Line back to the start (0.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 64.478542 (original body 157.079633).

Kernel results: kernel.5 (pinned) valid 64.478542; main (0059) valid 64.478542; this branch (0060) valid 64.478542; reference valid 64.478542.

<a id="h3-cone-r2_5"></a>

### H3: base edge of a cone (base radius 5, apex 6 above), fillet 2.5

File `H3-cone-r2_5.png`. Body: the section turned about the Z axis

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (5.0000, 0.0000).
3. Line to (0.0000, 6.0000).
4. Line back to the start (0.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 2.5 on the circular edge through the point (0, 5, 0).

Expected (the rule): the incoming face runs out: its far edge is the pivot; crease at the first pivot: 97.36 deg between the normals.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Arc, centre (-0.3204, 2.4794), radius 2.5, from (0.0000, 0.0000) to (1.6001, 4.0798), passing through (2.0070, 1.5666), counter-clockwise.
3. Line to (0.0000, 6.0000).
4. Line back to the start (0.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 48.979129 (original body 157.079633).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; reference valid 48.979129.

<a id="h3-cone-r3_5"></a>

### H3: base edge of a cone (base radius 5, apex 6 above), fillet 3.5

File `H3-cone-r3_5.png`. Body: the section turned about the Z axis

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (5.0000, 0.0000).
3. Line to (0.0000, 6.0000).
4. Line back to the start (0.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 3.5 on the circular edge through the point (0, 5, 0).

Expected (the rule): the incoming face runs out: its far edge is the pivot; crease at the first pivot: 124.21 deg between the normals.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Arc, centre (-1.9679, 2.8943), radius 3.5, from (0.0000, 0.0000) to (0.7208, 5.1350), passing through (1.4981, 2.4078), counter-clockwise.
3. Line to (0.0000, 6.0000).
4. Line back to the start (0.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 24.574664 (original body 157.079633).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; reference valid 24.574664.

<a id="h4-dome-r1_5"></a>

### H4: rim of a hemispherical dome (sphere radius 6, flat base), fillet 1.5 between the base disc and the sphere

File `H4-dome-r1_5.png`. Body: the section turned about the Z axis

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (6.0000, 0.0000).
3. Arc, centre (0.0000, 0.0000), radius 6, from (6.0000, 0.0000) to (0.0000, 6.0000), passing through (4.2426, 4.2426), counter-clockwise.
4. Line back to the start (0.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 1.5 on the circular edge through the point (0, 6, 0).

Expected (the rule): tangent to both faces.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (4.2426, 0.0000).
3. Arc, centre (4.2426, 1.5000), radius 1.5, from (4.2426, 0.0000) to (5.6569, 2.0000), passing through (5.4674, 0.6340), counter-clockwise.
4. Arc, centre (0.0000, 0.0000), radius 6, from (5.6569, 2.0000) to (0.0000, 6.0000), passing through (3.4641, 4.8990), counter-clockwise.
5. Line back to the start (0.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 424.865199 (original body 452.389342).

Kernel results: kernel.5 (pinned) valid 424.865208; main (0059) valid 424.865208; this branch (0060) valid 424.865208; reference valid 424.865199.

<a id="h4-dome-r2_5"></a>

### H4: rim of a hemispherical dome (sphere radius 6, flat base), fillet 2.5 between the base disc and the sphere

File `H4-dome-r2_5.png`. Body: the section turned about the Z axis

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (6.0000, 0.0000).
3. Arc, centre (0.0000, 0.0000), radius 6, from (6.0000, 0.0000) to (0.0000, 6.0000), passing through (4.2426, 4.2426), counter-clockwise.
4. Line back to the start (0.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 2.5 on the circular edge through the point (0, 6, 0).

Expected (the rule): tangent to both faces.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (2.4495, 0.0000).
3. Arc, centre (2.4495, 2.5000), radius 2.5, from (2.4495, 0.0000) to (4.1991, 4.2857), passing through (4.7640, 1.5551), counter-clockwise.
4. Arc, centre (0.0000, 0.0000), radius 6, from (4.1991, 4.2857) to (0.0000, 6.0000), passing through (2.2678, 5.5549), counter-clockwise.
5. Line back to the start (0.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 330.583330 (original body 452.389342).

Kernel results: kernel.5 (pinned) valid 330.583343; main (0059) valid 330.583343; this branch (0060) valid 330.583343; reference valid 330.583330.

<a id="h4-dome-r4_5"></a>

### H4: rim of a hemispherical dome (sphere radius 6, flat base), fillet 4.5 between the base disc and the sphere

File `H4-dome-r4_5.png`. Body: the section turned about the Z axis

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Line to (6.0000, 0.0000).
3. Arc, centre (0.0000, 0.0000), radius 6, from (6.0000, 0.0000) to (0.0000, 6.0000), passing through (4.2426, 4.2426), counter-clockwise.
4. Line back to the start (0.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 4.5 on the circular edge through the point (0, 6, 0).

Expected (the rule): both faces run out: pivots at both far edges; crease at the first pivot: 138.19 deg between the normals; crease at the second pivot: 138.19 deg between the normals.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (0.0000, 0.0000).
2. Arc, centre (-3.3541, 3.0000), radius 4.5, from (0.0000, 0.0000) to (0.0000, 6.0000), passing through (1.1459, 3.0000), counter-clockwise.
3. Line back to the start (0.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 13.738093 (original body 452.389342).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; reference valid 13.738093.

<a id="h5-washer-r2"></a>

### H5: bore edge of a washer (outer radius 6, bore radius 3, height 6), fillet 2: the 3 mm ring runs out onto the outer circle

File `H5-washer-r2.png`. Body: the section turned about the Z axis

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (3.0000, 0.0000).
2. Line to (6.0000, 0.0000).
3. Line to (6.0000, 6.0000).
4. Line to (3.0000, 6.0000).
5. Line back to the start (3.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 2 on the circular edge through the point (0, 3, 6).

Expected (the rule): tangent to both faces.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (3.0000, 0.0000).
2. Line to (6.0000, 0.0000).
3. Line to (6.0000, 6.0000).
4. Line to (5.0000, 6.0000).
5. Arc, centre (5.0000, 4.0000), radius 2, from (5.0000, 6.0000) to (3.0000, 4.0000), passing through (3.5858, 5.4142), counter-clockwise.
6. Line back to the start (3.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 490.347928 (original body 508.938010).

Kernel results: kernel.5 (pinned) valid 490.347928; main (0059) valid 490.347928; this branch (0060) valid 490.347928; reference valid 490.347928.

<a id="h5-washer-r3_5"></a>

### H5: bore edge of a washer (outer radius 6, bore radius 3, height 6), fillet 3.5: the 3 mm ring runs out onto the outer circle

File `H5-washer-r3_5.png`. Body: the section turned about the Z axis

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (3.0000, 0.0000).
2. Line to (6.0000, 0.0000).
3. Line to (6.0000, 6.0000).
4. Line to (3.0000, 6.0000).
5. Line back to the start (3.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 3.5 on the circular edge through the point (0, 3, 6).

Expected (the rule): the incoming face runs out: its far edge is the pivot; crease at the first pivot: 98.21 deg between the normals.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (3.0000, 0.0000).
2. Line to (6.0000, 0.0000).
3. Line to (6.0000, 6.0000).
4. Arc, centre (6.5000, 2.5359), radius 3.5, from (6.0000, 6.0000) to (3.0000, 2.5359), passing through (3.8542, 4.8272), counter-clockwise.
5. Line back to the start (3.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 449.746385 (original body 508.938010).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; reference valid 449.746385.

<a id="h5-washer-r5"></a>

### H5: bore edge of a washer (outer radius 6, bore radius 3, height 6), fillet 5: the 3 mm ring runs out onto the outer circle

File `H5-washer-r5.png`. Body: the section turned about the Z axis

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (3.0000, 0.0000).
2. Line to (6.0000, 0.0000).
3. Line to (6.0000, 6.0000).
4. Line to (3.0000, 6.0000).
5. Line back to the start (3.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 5 on the circular edge through the point (0, 3, 6).

Expected (the rule): the incoming face runs out: its far edge is the pivot; crease at the first pivot: 113.58 deg between the normals.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (3.0000, 0.0000).
2. Line to (6.0000, 0.0000).
3. Line to (6.0000, 6.0000).
4. Arc, centre (8.0000, 1.4174), radius 5, from (6.0000, 6.0000) to (3.0000, 1.4174), passing through (3.8167, 4.1560), counter-clockwise.
5. Line back to the start (3.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 416.729380 (original body 508.938010).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; reference valid 416.729380.

<a id="h5-washer-r7"></a>

### H5: bore edge of a washer (outer radius 6, bore radius 3, height 6), fillet 7: the 3 mm ring runs out onto the outer circle

File `H5-washer-r7.png`. Body: the section turned about the Z axis

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (3.0000, 0.0000).
2. Line to (6.0000, 0.0000).
3. Line to (6.0000, 6.0000).
4. Line to (3.0000, 6.0000).
5. Line back to the start (3.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 7 on the circular edge through the point (0, 3, 6).

Expected (the rule): the incoming face runs out: its far edge is the pivot; crease at the first pivot: 124.85 deg between the normals.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge):

1. Start at (3.0000, 0.0000).
2. Line to (6.0000, 0.0000).
3. Line to (6.0000, 6.0000).
4. Arc, centre (10.0000, 0.2554), radius 7, from (6.0000, 6.0000) to (3.0000, 0.2554), passing through (3.7952, 3.4958), counter-clockwise.
5. Line back to the start (3.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 384.480018 (original body 508.938010).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; reference valid 384.480018.

<a id="h6-dprism-r1_5"></a>

### H6: edge between a flat (8 wide) and a convex cylinder (radius 5), fillet 1.5

File `H6-dprism-r1_5.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (4.0000, 3.0000).
2. Line to (-4.0000, 3.0000).
3. Arc, centre (0.0000, 0.0000), radius 5, from (-4.0000, 3.0000) to (4.0000, 3.0000), passing through (-0.0000, -5.0000), counter-clockwise.

Fillet, Shapr3D: radius 1.5 on the straight edge through the point (-4, 5, 3).

Expected (the rule): tangent to both faces.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (4.0000, 3.0000).
2. Line to (-3.1623, 3.0000).
3. Arc, centre (-3.1623, 1.5000), radius 1.5, from (-3.1623, 3.0000) to (-4.5175, 2.1429), passing through (-3.9641, 2.7677), counter-clockwise.
4. Arc, centre (0.0000, 0.0000), radius 5, from (-4.5175, 2.1429) to (4.0000, 3.0000), passing through (0.5006, -4.9749), counter-clockwise.

Check: the fillet tool's result and this sketch should coincide. Volume 672.340558 (original body 673.574359).

Kernel results: kernel.5 (pinned) valid 672.340558; main (0059) valid 672.340558; this branch (0060) valid 672.340558; reference valid 672.340558.

<a id="h6-dprism-r3"></a>

### H6: edge between a flat (8 wide) and a convex cylinder (radius 5), fillet 3

File `H6-dprism-r3.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (4.0000, 3.0000).
2. Line to (-4.0000, 3.0000).
3. Arc, centre (0.0000, 0.0000), radius 5, from (-4.0000, 3.0000) to (4.0000, 3.0000), passing through (-0.0000, -5.0000), counter-clockwise.

Fillet, Shapr3D: radius 3 on the straight edge through the point (-4, 5, 3).

Expected (the rule): tangent to both faces.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (4.0000, 3.0000).
2. Line to (-2.0000, 3.0000).
3. Arc, centre (-2.0000, 0.0000), radius 3, from (-2.0000, 3.0000) to (-5.0000, 0.0000), passing through (-4.1213, 2.1213), counter-clockwise.
4. Arc, centre (0.0000, 0.0000), radius 5, from (-5.0000, 0.0000) to (4.0000, 3.0000), passing through (1.5811, -4.7434), counter-clockwise.

Check: the fillet tool's result and this sketch should coincide. Volume 663.822555 (original body 673.574359).

Kernel results: kernel.5 (pinned) valid 663.822555; main (0059) valid 663.822555; this branch (0060) valid 663.822555; reference valid 663.822555.

<a id="h6-dprism-r4_5"></a>

### H6: edge between a flat (8 wide) and a convex cylinder (radius 5), fillet 4.5

File `H6-dprism-r4_5.png`. The rule has no answer: no circle of this radius fits inside the part tangent to both faces.

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), one closed profile, then extrude 10 along +Y:

1. Start at (4.0000, 3.0000).
2. Line to (-4.0000, 3.0000).
3. Arc, centre (0.0000, 0.0000), radius 5, from (-4.0000, 3.0000) to (4.0000, 3.0000), passing through (-0.0000, -5.0000), counter-clockwise.

Fillet, Shapr3D: radius 4.5 on the straight edge through the point (-4, 5, 3). Expected: the fillet tool refuses (no tangent fillet this large exists); see the decision.

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; 0062 candidate declined.

<a id="h6-dprism-r8"></a>

### H6: edge between a flat (8 wide) and a convex cylinder (radius 5), fillet 8

File `H6-dprism-r8.png`. The rule has no answer: no circle of this radius fits inside the part tangent to both faces.

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), one closed profile, then extrude 10 along +Y:

1. Start at (4.0000, 3.0000).
2. Line to (-4.0000, 3.0000).
3. Arc, centre (0.0000, 0.0000), radius 5, from (-4.0000, 3.0000) to (4.0000, 3.0000), passing through (-0.0000, -5.0000), counter-clockwise.

Fillet, Shapr3D: radius 8 on the straight edge through the point (-4, 5, 3). Expected: the fillet tool refuses (no tangent fillet this large exists); see the decision.

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; 0062 candidate declined.

<a id="h7-groove-r2"></a>

### H7: edge between the 3 mm flat and a concave cylindrical groove (radius 3) in a 12 x 6 block, fillet 2

File `H7-groove-r2.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (12.0000, 0.0000).
3. Line to (12.0000, 6.0000).
4. Line to (9.0000, 6.0000).
5. Arc, centre (6.0000, 6.0000), radius 3, from (9.0000, 6.0000) to (3.0000, 6.0000), passing through (6.0000, 3.0000), clockwise.
6. Line to (0.0000, 6.0000).
7. Line back to the start (0.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 2 on the straight edge through the point (9, 5, 6).

Expected (the rule): tangent to both faces.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (12.0000, 0.0000).
3. Line to (12.0000, 6.0000).
4. Line to (10.5826, 6.0000).
5. Arc, centre (10.5826, 4.0000), radius 2, from (10.5826, 6.0000) to (8.7495, 4.8000), passing through (9.4871, 5.6733), counter-clockwise.
6. Arc, centre (6.0000, 6.0000), radius 3, from (8.7495, 4.8000) to (3.0000, 6.0000), passing through (5.3871, 3.0633), clockwise.
7. Line to (0.0000, 6.0000).
8. Line back to the start (0.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 574.506421 (original body 578.628331).

Kernel results: kernel.5 (pinned) valid 574.506421; main (0059) valid 574.506421; this branch (0060) valid 574.506421; reference valid 574.506421.

<a id="h7-groove-r4"></a>

### H7: edge between the 3 mm flat and a concave cylindrical groove (radius 3) in a 12 x 6 block, fillet 4

File `H7-groove-r4.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (12.0000, 0.0000).
3. Line to (12.0000, 6.0000).
4. Line to (9.0000, 6.0000).
5. Arc, centre (6.0000, 6.0000), radius 3, from (9.0000, 6.0000) to (3.0000, 6.0000), passing through (6.0000, 3.0000), clockwise.
6. Line to (0.0000, 6.0000).
7. Line back to the start (0.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 4 on the straight edge through the point (9, 5, 6).

Expected (the rule): tangent to both faces.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (12.0000, 0.0000).
3. Line to (12.0000, 6.0000).
4. Line to (11.7446, 6.0000).
5. Arc, centre (11.7446, 2.0000), radius 4, from (11.7446, 6.0000) to (8.4620, 4.2857), passing through (9.8929, 5.5456), counter-clockwise.
6. Arc, centre (6.0000, 6.0000), radius 3, from (8.4620, 4.2857) to (3.0000, 6.0000), passing through (5.1016, 3.1377), clockwise.
7. Line to (0.0000, 6.0000).
8. Line back to the start (0.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 568.112189 (original body 578.628331).

Kernel results: kernel.5 (pinned) valid 568.112189; main (0059) valid 568.112189; this branch (0060) valid 568.112189; reference valid 568.112189.

<a id="h7-groove-r5"></a>

### H7: edge between the 3 mm flat and a concave cylindrical groove (radius 3) in a 12 x 6 block, fillet 5

File `H7-groove-r5.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (12.0000, 0.0000).
3. Line to (12.0000, 6.0000).
4. Line to (9.0000, 6.0000).
5. Arc, centre (6.0000, 6.0000), radius 3, from (9.0000, 6.0000) to (3.0000, 6.0000), passing through (6.0000, 3.0000), clockwise.
6. Line to (0.0000, 6.0000).
7. Line back to the start (0.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 5 on the straight edge through the point (9, 5, 6).

Expected (the rule): the incoming face runs out: its far edge is the pivot; crease at the first pivot: 92.87 deg between the normals.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (12.0000, 0.0000).
3. Line to (12.0000, 6.0000).
4. Arc, centre (12.2500, 1.0063), radius 5, from (12.0000, 6.0000) to (8.3438, 4.1273), passing through (9.9707, 5.4565), counter-clockwise.
5. Arc, centre (6.0000, 6.0000), radius 3, from (8.3438, 4.1273) to (3.0000, 6.0000), passing through (5.0078, 3.1688), clockwise.
6. Line to (0.0000, 6.0000).
7. Line back to the start (0.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 564.982441 (original body 578.628331).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; reference valid 564.982441.

<a id="h7-groove-r8"></a>

### H7: edge between the 3 mm flat and a concave cylindrical groove (radius 3) in a 12 x 6 block, fillet 8

File `H7-groove-r8.png`. Body: a prism, the section extruded 10 along +Y

Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (12.0000, 0.0000).
3. Line to (12.0000, 6.0000).
4. Line to (9.0000, 6.0000).
5. Arc, centre (6.0000, 6.0000), radius 3, from (9.0000, 6.0000) to (3.0000, 6.0000), passing through (6.0000, 3.0000), clockwise.
6. Line to (0.0000, 6.0000).
7. Line back to the start (0.0000, 0.0000), closing the profile.

Fillet, Shapr3D: radius 8 on the straight edge through the point (9, 5, 6).

Expected (the rule): the incoming face runs out: its far edge is the pivot; crease at the first pivot: 102.64 deg between the normals.

Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (12.0000, 0.0000).
3. Line to (12.0000, 6.0000).
4. Arc, centre (13.7500, -1.8062), radius 8, from (12.0000, 6.0000) to (8.1136, 3.8710), passing through (9.9065, 5.2100), counter-clockwise.
5. Arc, centre (6.0000, 6.0000), radius 3, from (8.1136, 3.8710) to (3.0000, 6.0000), passing through (4.8469, 3.2304), clockwise.
6. Line to (0.0000, 6.0000).
7. Line back to the start (0.0000, 0.0000), closing the profile.

Check: the fillet tool's result and this sketch should coincide. Volume 559.546265 (original body 578.628331).

Kernel results: kernel.5 (pinned) declined; main (0059) declined; this branch (0060) declined; reference valid 559.546265.
