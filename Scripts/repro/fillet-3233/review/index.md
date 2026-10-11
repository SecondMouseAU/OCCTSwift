# Fillet contours that share a vertex (#3233): expected geometry, what the kernel does, and the Shapr3D recipe for every case

Nothing here is submitted. Branch `fix/fillet-3233-corners` (from `fix/fillet-pivot-edges`, patches 0059 and 0060), candidate patch 0061, no PR.

## How to read the images

The rule being drawn (yours, from #3208): wherever a fillet meets a face it is filleting it is tangent to that face; where the face runs out and there is an edge instead, the edge is the pivot and the arc passes through it. r1 + r2 = w: tangent arcs. r1 + r2 > w: the arcs cross at an included angle below 180 degrees. Two fillets on opposite edges at once give the INTERSECTION of the two rounded profiles. Read at a shared vertex: where two fillets meet at a convex corner whose third edge is not filleted, the result is the intersection of the two surfaces (that is what the kernel already does for small radii, cases E1 to E3 and G1); where three equal fillets meet at a convex corner it is a ball of that radius (F1 to F3, I1, I2).

Every case has one main image `<case>.png`, 1560 x 1200, three rows of three panels:

- Row 1: the analytic end view (a section across one edge away from the corner: arcs dashed blue, circles dotted, tangent points green discs, pivots red diamonds, junction or crossing blue disc, circle centres blue crosses, the kernel's own slice of its result drawn over it in green) | the kernel result, oblique, from outside the corner | the reference, oblique.
- Row 2: what the rule expects in words and the section numbers | the kernel result from above with the reference's edges dashed blue over it | the reference from above (zoomed to the corner for the corner cases).
- Row 3: chips for this branch plus candidate 0061, this branch (0060), main (0059) and the pinned kernel.5 (green = same solid as the reference, amber = valid but different, red = declined or invalid) | corner close-up of the kernel result | corner close-up of the reference.

The REFERENCE is built with no fillet code: the base solid (a sketch and an extrude) minus removal prisms (the analytic corner profile swept along each edge, a sketch and an extrude) and, at ball corners, a cube minus a sphere. At a reflex corner the reference is one of three candidates; see the decision images (`<case>-decision.png`). `cdump.cxx` builds it, `cases3233.py` writes the removal items.

Where the kernel returns a solid the image shows the branch with candidate 0061 when it differs from 0060, else 0060. The pinned kernel.5 is the v4.0.0-kernel.5 release asset; main is kernel.5 plus patch 0059; this branch is main plus patch 0060; candidate 0061 sits on top of this branch. `occtBlendResultIsValid` (#3200) is not on this branch, so the verdict here is BRepCheck_Analyzer, one solid, and every edge on two faces; a solid with a free edge fails it.

Coordinates: X across the box, Y along it, Z up, one corner at the origin. Boxes are 4 x 10 x 6 unless the case says otherwise. Shapr3D steps below use absolute coordinates; "Subtract" means Combine, Cut with the swept body or corner piece as the tool.

## Summary

Classification is for this branch (0060). "With 0061" is the candidate patch. A decision is geometry the rule does not fix.

| case | configuration | expected | this branch (0060) | classification | with candidate 0061 | decision |
| --- | --- | --- | --- | --- | --- | --- |
| [E1-adj-1-1](E1-adj-1-1.png) | two adjacent top edges meeting at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 1 (front, along X) and 1 (left, along Y) | reference 237.0914 | valid, volume 237.091445 (+0.0e+00 vs reference) | already right | valid, volume 237.091445 (+0.0e+00 vs reference) |  |
| [E2-adj-1-2](E2-adj-1-2.png) | two adjacent top edges meeting at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 1 (front, along X) and 2 (left, along Y) | reference 230.8110 | valid, volume 230.811017 (+1.2e-08 vs reference) | already right | valid, volume 230.811017 (+1.2e-08 vs reference) |  |
| [E3-adj-3-3](E3-adj-3-3.png) | two adjacent top edges meeting at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 3 (front, along X) and 3 (left, along Y) | reference 215.5487 | valid, volume 215.548668 (-4.6e-08 vs reference) | already right | valid, volume 215.548668 (-4.6e-08 vs reference) |  |
| [E4-adj-1-4_5](E4-adj-1-4_5.png) | two adjacent top edges meeting at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 1 (front, along X) and 4.5 (left, along Y) | reference 197.5167 | declined (IsDone false) | declined | valid, volume 197.516664 (-1.5e-07 vs reference) |  |
| [E5-adj-3-4_5](E5-adj-3-4_5.png) | two adjacent top edges meeting at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 3 (front, along X) and 4.5 (left, along Y) | reference 194.4847 | declined (IsDone false) | declined | valid, volume 194.484741 (-1.4e-07 vs reference) |  |
| [E6-adj-4_5-4_5](E6-adj-4_5-4_5.png) | two adjacent top edges meeting at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 4.5 (front, along X) and 4.5 (left, along Y) | reference 188.8114 | declined (IsDone false) | declined | valid, volume 188.811386 (+0.0e+00 vs reference) |  |
| [F1-corner-1](F1-corner-1.png) | all three edges at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 1, 1, 1 (front, left, vertical) | reference 235.8754 | valid, volume 235.875368 (+0.0e+00 vs reference) | already right | valid, volume 235.875368 (+0.0e+00 vs reference) |  |
| [F2-corner-2](F2-corner-2.png) | all three edges at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 2, 2, 2 (front, left, vertical) | reference 224.1711 | valid, volume 224.171087 (+0.0e+00 vs reference) | already right | valid, volume 224.171087 (+0.0e+00 vs reference) |  |
| [F3-corner-3_5](F3-corner-3_5.png) | all three edges at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 3.5, 3.5, 3.5 (front, left, vertical) | reference 194.6000 | valid, volume 194.600009 (+0.0e+00 vs reference) | already right | valid, volume 194.600009 (+0.0e+00 vs reference) |  |
| [F4-corner-unequal](F4-corner-unequal.png) | all three edges at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 1, 2, 1.5 (front, left, vertical) | candidates, see D2 | valid, volume 228.137050 (-2.9e-01 vs reference) | decision (kernel valid today) | valid, volume 228.137050 (-2.9e-01 vs reference) | [D2](#decisions-waiting-for-you) |
| [F5-corner-4_5](F5-corner-4_5.png) | all three edges at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 4.5, 4.5, 4.5 (front, left, vertical) | candidates, see D3 | declined (IsDone false) | decision (kernel declines) | declined (IsDone false) | [D3](#decisions-waiting-for-you) |
| [G1-frame-1](G1-frame-1.png) | all four top edges (a frame), radius 1, of a 4 x 10 x 6 box | reference 234.3746 | valid, volume 234.374630 (+0.0e+00 vs reference) | already right | valid, volume 234.374630 (+0.0e+00 vs reference) |  |
| [G2-frame-2](G2-frame-2.png) | all four top edges (a frame), radius 2, of a 4 x 10 x 6 box | reference 219.0324 | valid, volume 219.032445 (-5.5e-08 vs reference) | already right | valid, volume 219.032445 (-5.5e-08 vs reference) |  |
| [G3-frame-2_5](G3-frame-2_5.png) | all four top edges (a frame), radius 2.5, of a 4 x 10 x 6 box | reference 208.5288 | DONE BUT INVALID (BRepCheck false, 4 free edge(s), volume -2.26e+26) | wrong (done but invalid) | valid, volume 208.528817 (+2.3e-08 vs reference) |  |
| [G4-frame-3](G4-frame-3.png) | all four top edges (a frame), radius 3, of a 4 x 10 x 6 box | reference 196.8402 | DONE BUT INVALID (BRepCheck false, 4 free edge(s), volume 3.51e+29) | wrong (done but invalid) | valid, volume 196.840194 (+2.4e-07 vs reference) |  |
| [G5-frame-3_9](G5-frame-3_9.png) | all four top edges (a frame), radius 3.9, of a 4 x 10 x 6 box | reference 173.8657 | DONE BUT INVALID (BRepCheck false, 4 free edge(s), volume -3.67e+28) | wrong (done but invalid) | valid, volume 173.865651 (-1.9e-07 vs reference) |  |
| [G6-frame-4_5](G6-frame-4_5.png) | all four top edges (a frame), radius 4.5, of a 4 x 10 x 6 box | reference 158.4712 | declined (IsDone false) | declined | valid, volume 158.471230 (-1.2e-07 vs reference) |  |
| [G7-frame-sq-3](G7-frame-sq-3.png) | all four top edges (a frame), radius 3, of a 10 x 10 x 8 box | reference 733.0973 | valid, volume 733.097335 (-2.2e-07 vs reference) | already right | valid, volume 733.097335 (-2.2e-07 vs reference) |  |
| [G8-frame-sq-5](G8-frame-sq-5.png) | all four top edges (a frame), radius 5, of a 10 x 10 x 8 box | reference 633.3333 | declined (IsDone false) | declined | valid, volume 633.333333 (-1.0e-09 vs reference) |  |
| [G9-frame-sq-6](G9-frame-sq-6.png) | all four top edges (a frame), radius 6, of a 10 x 10 x 8 box | reference 573.7496 | DONE BUT INVALID (BRepCheck false, 4 free edge(s), volume 684) | wrong (done but invalid) | valid, volume 573.749618 (-1.9e-07 vs reference) |  |
| [G10-frame-3-1](G10-frame-3-1.png) | all four top edges (a frame) of a 4 x 10 x 6 box, radius 3 on the two long edges and 1 on the two short ones | reference 202.3263 | DONE BUT INVALID (BRepCheck false, 4 free edge(s), volume 229) | wrong (done but invalid) | valid, volume 202.326335 (-1.0e-08 vs reference) |  |
| [H1-L-1](H1-L-1.png) | the whole top contour (6 edges, radius 1) of a L-shaped (arms 3 wide) extrusion 6 high | candidates, see D1 | valid, volume 227.516223 (-2.1e-02 vs reference) | decision (kernel valid today) | valid, volume 227.516223 (-2.1e-02 vs reference) | [D1](#decisions-waiting-for-you) |
| [H2-L-1_5](H2-L-1_5.png) | the whole top contour (6 edges, radius 1.5) of a L-shaped (arms 3 wide) extrusion 6 high | candidates, see D1 | declined (IsDone false) | decision (kernel declines) | declined (IsDone false) | [D1](#decisions-waiting-for-you) |
| [H3-L-2](H3-L-2.png) | the whole top contour (6 edges, radius 2) of a L-shaped (arms 3 wide) extrusion 6 high | candidates, see D1 | DONE BUT INVALID (BRepCheck false, 6 free edge(s), volume 237) | decision (kernel hands back an open shell) | DONE BUT INVALID (BRepCheck false, 6 free edge(s), volume 237) | [D1](#decisions-waiting-for-you) |
| [H4-U-1](H4-U-1.png) | the whole top contour (8 edges, radius 1) of a U-shaped (arms 3 wide) extrusion 6 high | candidates, see D1 | valid, volume 297.799408 (-4.1e-02 vs reference) | decision (kernel valid today) | valid, volume 297.799408 (-4.1e-02 vs reference) | [D1](#decisions-waiting-for-you) |
| [H5-U-1_5](H5-U-1_5.png) | the whole top contour (8 edges, radius 1.5) of a U-shaped (arms 3 wide) extrusion 6 high | candidates, see D1 | declined (IsDone false) | decision (kernel declines) | declined (IsDone false) | [D1](#decisions-waiting-for-you) |
| [H6-L-3_5](H6-L-3_5.png) | the whole top contour (6 edges, radius 3.5) of a L-shaped (arms 3 wide) extrusion 6 high | candidates, see D1 | declined (IsDone false) | decision (kernel declines) | declined (IsDone false) | [D1](#decisions-waiting-for-you) |
| [I1-round-1-1](I1-round-1-1.png) | the four top edges (radius 1) and the four vertical edges (radius 1) of a 4 x 10 x 6 box: four corner blends | reference 229.5103 | valid, volume 229.510322 (+0.0e+00 vs reference) | already right | valid, volume 229.510322 (+0.0e+00 vs reference) |  |
| [I2-round-1_5-1_5](I2-round-1_5-1_5.png) | the four top edges (radius 1.5) and the four vertical edges (radius 1.5) of a 4 x 10 x 6 box: four corner blends | reference 217.1515 | valid, volume 217.151543 (+0.0e+00 vs reference) | already right | valid, volume 217.151543 (+0.0e+00 vs reference) |  |
| [I3-round-2-2](I3-round-2-2.png) | the four top edges (radius 2) and the four vertical edges (radius 2) of a 4 x 10 x 6 box: four corner blends | reference 200.7198 | declined (IsDone false) | declined | valid, volume 200.719755 (+0.0e+00 vs reference) |  |
| [I4-round-1-2](I4-round-1-2.png) | the four top edges (radius 1) and the four vertical edges (radius 2) of a 4 x 10 x 6 box: four corner blends | candidates, see D2 | declined (IsDone false) | decision (kernel declines) | declined (IsDone false) | [D2](#decisions-waiting-for-you) |

## Decisions waiting for you

**D1. The reflex (inside) corner of an L or U extrusion, where two filleted top edges meet at a concave vertical edge.** The two fillets do not overlap there, so "intersection" does not say what to build in the 90 degree square where they would meet. Three outcomes, all valid solids, drawn side by side in `H1-L-1-decision.png` and `H4-U-1-decision.png`:

- A, what the kernel gives today: a smooth blend patch. L (r = 1): volume 227.5162. U: 297.7994.
- B, mitre: each fillet runs r past the vertex and the two meet in the diagonal (a ridge, the union of what the two fillets remove). L: 227.2788. U: 297.3245.
- C, rolling ball: the vertical edge is the pivot and the profile is revolved 90 degrees round it (a horn torus patch, tangent to the top face and to both walls). L: 227.5368. U: 297.8406. By your rule this is the one that reads the edge as a pivot; A differs from it by 0.0206 (L).

The other L and U cases (H2, H3, H5, H6: r = w/2, r above w/2, r above the arm width) wait on this: the kernel declines H2, H5, H6 and hands back an open shell for H3, none of which candidate 0061 changes. The reference in those images is C.

**D2. Unequal radii at a vertex of three filleted edges** (F4: 1, 2, 1.5; I4: top 1, vertical 2). No ball joins three cylinders of different radii. Candidate A is a smooth vertex blend, which is what the kernel builds for F4 (volume 228.1371); for I4 the kernel declines. Candidate B is the intersection of the three single-edge fillets, a pointed corner (F4 volume 228.4289, I4 volume 215.4363). Images `F4-corner-unequal-decision.png`, `I4-round-1-2-decision.png`.

**D3. A vertex of three filleted edges where a radius runs past a face** (F5: r = 4.5 on a 4 mm wide face). No ball of that radius fits the corner. The only outcome the rule defines directly is B, the intersection of the three pivot fillets (volume 175.2536, pointed corner); the other outcome is to keep declining. Image `F5-corner-4_5-decision.png`.

**D4. An open result.** On a frame with crossing arcs (G3, G4, G5, G9, G10) and on H3 the stripe builder answers IsDone true with a shell that has free edges (4 or 6 of them, volumes from 229 to 3.5e29 against boxes of 240 to 800), and the tessellator then never returns. Candidate 0061 replaces the open result where its construction applies (all of G). Where it does not apply (H3, reflex corner) it leaves the open result as it is. Do you want IsDone false there instead? That is a behaviour change for every multi-contour caller; I did not make it.

**Assumption to confirm, not a choice.** E4 to E6 and G6, G8, G10 read the rule at a shared convex vertex as the intersection of the surfaces of the two fillets (a mitre), including when one of them pivots at a far edge. That extends your statement from opposite edges to adjacent ones; it is what the kernel already does for small radii.

## E: two adjacent edges at a box corner

### E: two adjacent top edges meeting at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 1 (front, along X) and 1 (left, along Y)

File `E1-adj-1-1.png`.

Fillets, all in one operation: radius 1 on the edge whose middle is (2, 0, 6); radius 1 on the edge whose middle is (0, 5, 6).

Expected: Mitre: the two cylinders meet along their intersection curve (the plane through the corner at 45 deg for equal radii). Both radii below every face width, so this is the ordinary fillet; the rule adds nothing.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 1.0000, 6.0000)
   - arc centre (0.0000, 1.0000, 5.0000), radius 1, from A to B = (0.0000, 0.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 6.0000)
   - line from O to A = (1.0000, 10.0000, 6.0000)
   - arc centre (1.0000, 10.0000, 5.0000), radius 1, from A to B = (0.0000, 10.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 valid, volume 237.091445 (+0.0e+00 vs reference); main (0059) valid, volume 237.091445 (+0.0e+00 vs reference); this branch (0060) valid, volume 237.091445 (+0.0e+00 vs reference); this branch with candidate 0061 valid, volume 237.091445 (+0.0e+00 vs reference); reference volume 237.091445.

### E: two adjacent top edges meeting at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 1 (front, along X) and 2 (left, along Y)

File `E2-adj-1-2.png`.

Fillets, all in one operation: radius 1 on the edge whose middle is (2, 0, 6); radius 2 on the edge whose middle is (0, 5, 6).

Expected: The two cylinders (r 1 and r 2) meet along their space intersection curve, not a plane. Both below the face widths: ordinary fillet.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 1.0000, 6.0000)
   - arc centre (0.0000, 1.0000, 5.0000), radius 1, from A to B = (0.0000, 0.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 6.0000)
   - line from O to A = (2.0000, 10.0000, 6.0000)
   - arc centre (2.0000, 10.0000, 4.0000), radius 2, from A to B = (0.0000, 10.0000, 4.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 valid, volume 230.811017 (+1.2e-08 vs reference); main (0059) valid, volume 230.811017 (+1.2e-08 vs reference); this branch (0060) valid, volume 230.811017 (+1.2e-08 vs reference); this branch with candidate 0061 valid, volume 230.811017 (+1.2e-08 vs reference); reference volume 230.811017.

### E: two adjacent top edges meeting at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 3 (front, along X) and 3 (left, along Y)

File `E3-adj-3-3.png`.

Fillets, all in one operation: radius 3 on the edge whose middle is (2, 0, 6); radius 3 on the edge whose middle is (0, 5, 6).

Expected: Mitre of two r = 3 cylinders. 3 is below the 4 mm top face width, so no pivot; the bands overlap over a large part of the corner, which is still just the intersection.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 3.0000, 6.0000)
   - arc centre (0.0000, 3.0000, 3.0000), radius 3, from A to B = (0.0000, 0.0000, 3.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 6.0000)
   - line from O to A = (3.0000, 10.0000, 6.0000)
   - arc centre (3.0000, 10.0000, 3.0000), radius 3, from A to B = (0.0000, 10.0000, 3.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 valid, volume 215.548668 (-4.6e-08 vs reference); main (0059) valid, volume 215.548668 (-4.6e-08 vs reference); this branch (0060) valid, volume 215.548668 (-4.6e-08 vs reference); this branch with candidate 0061 valid, volume 215.548668 (-4.6e-08 vs reference); reference volume 215.548668.

### E: two adjacent top edges meeting at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 1 (front, along X) and 4.5 (left, along Y)

File `E4-adj-1-4_5.png`.

Fillets, all in one operation: radius 1 on the edge whose middle is (2, 0, 6); radius 4.5 on the edge whose middle is (0, 5, 6).

Expected: The left edge (r 4.5) runs out of the 4 mm top face: tangent to the left wall, pivot at the far top edge (4, y, 6). The front edge (r 1) is ordinary. Where they meet: the intersection of the two surfaces.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 1.0000, 6.0000)
   - arc centre (0.0000, 1.0000, 5.0000), radius 1, from A to B = (0.0000, 0.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 6.0000)
   - line from O to A = (4.0000, 10.0000, 6.0000)
   - arc centre (4.5000, 10.0000, 1.5279), radius 4.5, from A to B = (0.0000, 10.0000, 1.5279), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 declined (IsDone false); main (0059) declined (IsDone false); this branch (0060) declined (IsDone false); this branch with candidate 0061 valid, volume 197.516664 (-1.5e-07 vs reference); reference volume 197.516664.

### E: two adjacent top edges meeting at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 3 (front, along X) and 4.5 (left, along Y)

File `E5-adj-3-4_5.png`.

Fillets, all in one operation: radius 3 on the edge whose middle is (2, 0, 6); radius 4.5 on the edge whose middle is (0, 5, 6).

Expected: As E4 with the front fillet r 3: its cylinder crosses the pivot cylinder of the left edge; the corner is their intersection.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 3.0000, 6.0000)
   - arc centre (0.0000, 3.0000, 3.0000), radius 3, from A to B = (0.0000, 0.0000, 3.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 6.0000)
   - line from O to A = (4.0000, 10.0000, 6.0000)
   - arc centre (4.5000, 10.0000, 1.5279), radius 4.5, from A to B = (0.0000, 10.0000, 1.5279), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 declined (IsDone false); main (0059) declined (IsDone false); this branch (0060) declined (IsDone false); this branch with candidate 0061 valid, volume 194.484741 (-1.4e-07 vs reference); reference volume 194.484741.

### E: two adjacent top edges meeting at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 4.5 (front, along X) and 4.5 (left, along Y)

File `E6-adj-4_5-4_5.png`.

Fillets, all in one operation: radius 4.5 on the edge whose middle is (2, 0, 6); radius 4.5 on the edge whose middle is (0, 5, 6).

Expected: Both radii 4.5: the left edge pivots at the far top edge; the front edge (top face reaches 10 along Y, wall 6) is ordinary. Corner is the intersection of the two cylinders.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 4.5000, 6.0000)
   - arc centre (0.0000, 4.5000, 1.5000), radius 4.5, from A to B = (0.0000, 0.0000, 1.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 6.0000)
   - line from O to A = (4.0000, 10.0000, 6.0000)
   - arc centre (4.5000, 10.0000, 1.5279), radius 4.5, from A to B = (0.0000, 10.0000, 1.5279), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 declined (IsDone false); main (0059) declined (IsDone false); this branch (0060) declined (IsDone false); this branch with candidate 0061 valid, volume 188.811386 (+0.0e+00 vs reference); reference volume 188.811386.

## F: all three edges at a box corner

### F: all three edges at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 1, 1, 1 (front, left, vertical)

File `F1-corner-1.png`.

Fillets, all in one operation: radius 1 on the edge whose middle is (2, 0, 6); radius 1 on the edge whose middle is (0, 5, 6); radius 1 on the edge whose middle is (0, 0, 3).

Expected: Spherical corner: a ball of radius 1 centred (1, 1, 5), tangent to all three faces and to the three cylinders (rolling ball).

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 1.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (1.0000, 0.0000, 6.0000)
   - line from O to A = (1.0000, 1.0000, 6.0000)
   - arc centre (1.0000, 1.0000, 5.0000), radius 1, from A to B = (1.0000, 0.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 3.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 6.0000)
   - line from O to A = (1.0000, 10.0000, 6.0000)
   - arc centre (1.0000, 10.0000, 5.0000), radius 1, from A to B = (0.0000, 10.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 9.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the XY plane at Z = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 0.0000)
   - line from O to A = (1.0000, 0.0000, 0.0000)
   - arc centre (1.0000, 1.0000, 0.0000), radius 1, from A to B = (0.0000, 1.0000, 0.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 5.0000 along (0, 0, 1) as a Subtract (Combine, Cut) from the body.
5. Cut the corner piece: make a box with opposite corners (0, 0, 5) and (1, 1, 6) as a separate body, make a sphere centre (1.0000, 1.0000, 5.0000) radius 1 as a second body, Subtract the sphere from the box (what is left is the corner cube minus the ball), then Subtract that piece from the main body.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 valid, volume 235.875368 (+0.0e+00 vs reference); main (0059) valid, volume 235.875368 (+0.0e+00 vs reference); this branch (0060) valid, volume 235.875368 (+0.0e+00 vs reference); this branch with candidate 0061 valid, volume 235.875368 (+0.0e+00 vs reference); reference volume 235.875368.

### F: all three edges at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 2, 2, 2 (front, left, vertical)

File `F2-corner-2.png`.

Fillets, all in one operation: radius 2 on the edge whose middle is (2, 0, 6); radius 2 on the edge whose middle is (0, 5, 6); radius 2 on the edge whose middle is (0, 0, 3).

Expected: Spherical corner: a ball of radius 2 centred (2, 2, 4), tangent to the three faces and the three cylinders.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 2.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (2.0000, 0.0000, 6.0000)
   - line from O to A = (2.0000, 2.0000, 6.0000)
   - arc centre (2.0000, 2.0000, 4.0000), radius 2, from A to B = (2.0000, 0.0000, 4.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 2.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 6.0000)
   - line from O to A = (2.0000, 10.0000, 6.0000)
   - arc centre (2.0000, 10.0000, 4.0000), radius 2, from A to B = (0.0000, 10.0000, 4.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 8.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the XY plane at Z = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 0.0000)
   - line from O to A = (2.0000, 0.0000, 0.0000)
   - arc centre (2.0000, 2.0000, 0.0000), radius 2, from A to B = (0.0000, 2.0000, 0.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (0, 0, 1) as a Subtract (Combine, Cut) from the body.
5. Cut the corner piece: make a box with opposite corners (0, 0, 4) and (2, 2, 6) as a separate body, make a sphere centre (2.0000, 2.0000, 4.0000) radius 2 as a second body, Subtract the sphere from the box (what is left is the corner cube minus the ball), then Subtract that piece from the main body.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 valid, volume 224.171087 (+0.0e+00 vs reference); main (0059) valid, volume 224.171087 (+0.0e+00 vs reference); this branch (0060) valid, volume 224.171087 (+0.0e+00 vs reference); this branch with candidate 0061 valid, volume 224.171087 (+0.0e+00 vs reference); reference volume 224.171087.

### F: all three edges at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 3.5, 3.5, 3.5 (front, left, vertical)

File `F3-corner-3_5.png`.

Fillets, all in one operation: radius 3.5 on the edge whose middle is (2, 0, 6); radius 3.5 on the edge whose middle is (0, 5, 6); radius 3.5 on the edge whose middle is (0, 0, 3).

Expected: Spherical corner, r 3.5 (below the 4 mm width, above half of it): ball centred (3.5, 3.5, 2.5).

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 3.5000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (3.5000, 0.0000, 6.0000)
   - line from O to A = (3.5000, 3.5000, 6.0000)
   - arc centre (3.5000, 3.5000, 2.5000), radius 3.5, from A to B = (3.5000, 0.0000, 2.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 0.5000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 6.0000)
   - line from O to A = (3.5000, 10.0000, 6.0000)
   - arc centre (3.5000, 10.0000, 2.5000), radius 3.5, from A to B = (0.0000, 10.0000, 2.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 6.5000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the XY plane at Z = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 0.0000)
   - line from O to A = (3.5000, 0.0000, 0.0000)
   - arc centre (3.5000, 3.5000, 0.0000), radius 3.5, from A to B = (0.0000, 3.5000, 0.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 2.5000 along (0, 0, 1) as a Subtract (Combine, Cut) from the body.
5. Cut the corner piece: make a box with opposite corners (0, 0, 2.5) and (3.5, 3.5, 6) as a separate body, make a sphere centre (3.5000, 3.5000, 2.5000) radius 3.5 as a second body, Subtract the sphere from the box (what is left is the corner cube minus the ball), then Subtract that piece from the main body.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 valid, volume 194.600009 (+0.0e+00 vs reference); main (0059) valid, volume 194.600009 (+0.0e+00 vs reference); this branch (0060) valid, volume 194.600009 (+0.0e+00 vs reference); this branch with candidate 0061 valid, volume 194.600009 (+0.0e+00 vs reference); reference volume 194.600009.

### F: all three edges at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 1, 2, 1.5 (front, left, vertical)

File `F4-corner-unequal.png` and `F4-corner-unequal-decision.png`.

Fillets, all in one operation: radius 1 on the edge whose middle is (2, 0, 6); radius 2 on the edge whose middle is (0, 5, 6); radius 1.5 on the edge whose middle is (0, 0, 3).

Expected: Unequal radii: the three cylinders cannot be joined by a sphere. Candidate A is any smooth blend (the kernel's vertex patch), candidate B is the pointed intersection of the three. A design choice.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 1.0000, 6.0000)
   - arc centre (0.0000, 1.0000, 5.0000), radius 1, from A to B = (0.0000, 0.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 6.0000)
   - line from O to A = (2.0000, 10.0000, 6.0000)
   - arc centre (2.0000, 10.0000, 4.0000), radius 2, from A to B = (0.0000, 10.0000, 4.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the XY plane at Z = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 0.0000)
   - line from O to A = (1.5000, 0.0000, 0.0000)
   - arc centre (1.5000, 1.5000, 0.0000), radius 1.5, from A to B = (0.0000, 1.5000, 0.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 6.0000 along (0, 0, 1) as a Subtract (Combine, Cut) from the body.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 valid, volume 228.137050 (-2.9e-01 vs reference); main (0059) valid, volume 228.137050 (-2.9e-01 vs reference); this branch (0060) valid, volume 228.137050 (-2.9e-01 vs reference); this branch with candidate 0061 valid, volume 228.137050 (-2.9e-01 vs reference); reference volume 228.428889.

### F: all three edges at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii 4.5, 4.5, 4.5 (front, left, vertical)

File `F5-corner-4_5.png` and `F5-corner-4_5-decision.png`.

Fillets, all in one operation: radius 4.5 on the edge whose middle is (2, 0, 6); radius 4.5 on the edge whose middle is (0, 5, 6); radius 4.5 on the edge whose middle is (0, 0, 3).

Expected: r 4.5 is above the 4 mm width of the top face and of the front face: the left and vertical edges pivot on the far edges. No ball of radius 4.5 fits the corner. Candidate B (intersection of the three pivot fillets) is the only outcome the rule defines directly; a vertex blend there is a design choice.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 4.5000, 6.0000)
   - arc centre (0.0000, 4.5000, 1.5000), radius 4.5, from A to B = (0.0000, 0.0000, 1.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 6.0000)
   - line from O to A = (4.0000, 10.0000, 6.0000)
   - arc centre (4.5000, 10.0000, 1.5279), radius 4.5, from A to B = (0.0000, 10.0000, 1.5279), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the XY plane at Z = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 0.0000)
   - line from O to A = (4.0000, 0.0000, 0.0000)
   - arc centre (4.5000, 4.4721, 0.0000), radius 4.5, from A to B = (0.0000, 4.4721, 0.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 6.0000 along (0, 0, 1) as a Subtract (Combine, Cut) from the body.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 declined (IsDone false); main (0059) declined (IsDone false); this branch (0060) declined (IsDone false); this branch with candidate 0061 declined (IsDone false); reference volume 175.253622.

## G: a full top frame (four edges)

### G: all four top edges (a frame), radius 1, of a 4 x 10 x 6 box

File `G1-frame-1.png`.

Fillets, all in one operation: radius 1 on the edge whose middle is (2, 0, 6); radius 1 on the edge whose middle is (4, 5, 6); radius 1 on the edge whose middle is (2, 10, 6); radius 1 on the edge whose middle is (0, 5, 6).

Expected: Ordinary: four cylinders, a mitre at each of the four corners, a flat top 2 x 8 left in the middle.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 1.0000, 6.0000)
   - arc centre (0.0000, 1.0000, 5.0000), radius 1, from A to B = (0.0000, 0.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 0.0000, 6.0000)
   - line from O to A = (3.0000, 0.0000, 6.0000)
   - arc centre (3.0000, 0.0000, 5.0000), radius 1, from A to B = (4.0000, 0.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the YZ plane at X = 4.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 10.0000, 6.0000)
   - line from O to A = (4.0000, 9.0000, 6.0000)
   - arc centre (4.0000, 9.0000, 5.0000), radius 1, from A to B = (4.0000, 10.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
5. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 6.0000)
   - line from O to A = (1.0000, 10.0000, 6.0000)
   - arc centre (1.0000, 10.0000, 5.0000), radius 1, from A to B = (0.0000, 10.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.

Shorter equivalent for a frame: build the two rounded profiles and Intersect them.
   Body 1, sketch on the XZ plane (origin at the box's lower-left corner), the profile across the 4 mm width, extruded 10 along +Y:
   1. Start at (0.0000, 0.0000).
   2. Line to (0.0000, 5.0000).
   3. Arc, centre (1.0000, 5.0000), radius 1, from (0.0000, 5.0000) to (1.0000, 6.0000), the short way round.
   4. Line to (3.0000, 6.0000).
   5. Arc, centre (3.0000, 5.0000), radius 1, from (3.0000, 6.0000) to (4.0000, 5.0000), the short way round.
   6. Line to (4.0000, 0.0000).
   7. Close the profile with a line, then extrude 10.
   Body 2, sketch on the YZ plane, the profile across the 10 mm length, extruded 4 along +X:
   1. Start at (0.0000, 0.0000).
   2. Line to (0.0000, 5.0000).
   3. Arc, centre (1.0000, 5.0000), radius 1, from (0.0000, 5.0000) to (1.0000, 6.0000), the short way round.
   4. Line to (9.0000, 6.0000).
   5. Arc, centre (9.0000, 5.0000), radius 1, from (9.0000, 6.0000) to (10.0000, 5.0000), the short way round.
   6. Line to (10.0000, 0.0000).
   7. Close the profile with a line, then extrude 4.
   Intersect (Combine, Common) Body 1 with Body 2.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 valid, volume 234.374630 (+0.0e+00 vs reference); main (0059) valid, volume 234.374630 (+0.0e+00 vs reference); this branch (0060) valid, volume 234.374630 (+0.0e+00 vs reference); this branch with candidate 0061 valid, volume 234.374630 (+0.0e+00 vs reference); reference volume 234.374630.

### G: all four top edges (a frame), radius 2, of a 4 x 10 x 6 box

File `G2-frame-2.png`.

Fillets, all in one operation: radius 2 on the edge whose middle is (2, 0, 6); radius 2 on the edge whose middle is (4, 5, 6); radius 2 on the edge whose middle is (2, 10, 6); radius 2 on the edge whose middle is (0, 5, 6).

Expected: r = w/2 on the 4 mm width: the flat top shrinks to a line along Y at x = 2 (the long edges are exactly tangent to each other there); the end fillets (r 2) meet them in mitres.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 2.0000, 6.0000)
   - arc centre (0.0000, 2.0000, 4.0000), radius 2, from A to B = (0.0000, 0.0000, 4.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 0.0000, 6.0000)
   - line from O to A = (2.0000, 0.0000, 6.0000)
   - arc centre (2.0000, 0.0000, 4.0000), radius 2, from A to B = (4.0000, 0.0000, 4.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the YZ plane at X = 4.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 10.0000, 6.0000)
   - line from O to A = (4.0000, 8.0000, 6.0000)
   - arc centre (4.0000, 8.0000, 4.0000), radius 2, from A to B = (4.0000, 10.0000, 4.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
5. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 6.0000)
   - line from O to A = (2.0000, 10.0000, 6.0000)
   - arc centre (2.0000, 10.0000, 4.0000), radius 2, from A to B = (0.0000, 10.0000, 4.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.

Shorter equivalent for a frame: build the two rounded profiles and Intersect them.
   Body 1, sketch on the XZ plane (origin at the box's lower-left corner), the profile across the 4 mm width, extruded 10 along +Y:
   1. Start at (0.0000, 0.0000).
   2. Line to (0.0000, 4.0000).
   3. Arc, centre (2.0000, 4.0000), radius 2, from (0.0000, 4.0000) to (2.0000, 6.0000), the short way round.
   4. Arc, centre (2.0000, 4.0000), radius 2, from (2.0000, 6.0000) to (4.0000, 4.0000), the short way round.
   5. Line to (4.0000, 0.0000).
   6. Close the profile with a line, then extrude 10.
   Body 2, sketch on the YZ plane, the profile across the 10 mm length, extruded 4 along +X:
   1. Start at (0.0000, 0.0000).
   2. Line to (0.0000, 4.0000).
   3. Arc, centre (2.0000, 4.0000), radius 2, from (0.0000, 4.0000) to (2.0000, 6.0000), the short way round.
   4. Line to (8.0000, 6.0000).
   5. Arc, centre (8.0000, 4.0000), radius 2, from (8.0000, 6.0000) to (10.0000, 4.0000), the short way round.
   6. Line to (10.0000, 0.0000).
   7. Close the profile with a line, then extrude 4.
   Intersect (Combine, Common) Body 1 with Body 2.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 declined (IsDone false); main (0059) valid, volume 219.032445 (-5.5e-08 vs reference); this branch (0060) valid, volume 219.032445 (-5.5e-08 vs reference); this branch with candidate 0061 valid, volume 219.032445 (-5.5e-08 vs reference); reference volume 219.032445.

### G: all four top edges (a frame), radius 2.5, of a 4 x 10 x 6 box

File `G3-frame-2_5.png`.

Fillets, all in one operation: radius 2.5 on the edge whose middle is (2, 0, 6); radius 2.5 on the edge whose middle is (4, 5, 6); radius 2.5 on the edge whose middle is (2, 10, 6); radius 2.5 on the edge whose middle is (0, 5, 6).

Expected: r > w/2: the long edges' arcs cross at x = 2 (included angle 156.93 deg) along a ridge; the two end fillets cut the ridge down to their own mitre curves. The intersection of the four rounded profiles.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 2.5000, 6.0000)
   - arc centre (0.0000, 2.5000, 3.5000), radius 2.5, from A to B = (0.0000, 0.0000, 3.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 0.0000, 6.0000)
   - line from O to A = (1.5000, 0.0000, 6.0000)
   - arc centre (1.5000, 0.0000, 3.5000), radius 2.5, from A to B = (4.0000, 0.0000, 3.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the YZ plane at X = 4.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 10.0000, 6.0000)
   - line from O to A = (4.0000, 7.5000, 6.0000)
   - arc centre (4.0000, 7.5000, 3.5000), radius 2.5, from A to B = (4.0000, 10.0000, 3.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
5. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 6.0000)
   - line from O to A = (2.5000, 10.0000, 6.0000)
   - arc centre (2.5000, 10.0000, 3.5000), radius 2.5, from A to B = (0.0000, 10.0000, 3.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.

Shorter equivalent for a frame: build the two rounded profiles and Intersect them.
   Body 1, sketch on the XZ plane (origin at the box's lower-left corner), the profile across the 4 mm width, extruded 10 along +Y:
   1. Start at (0.0000, 0.0000).
   2. Line to (0.0000, 3.5000).
   3. Arc, centre (2.5000, 3.5000), radius 2.5, from (0.0000, 3.5000) to (2.0000, 5.9495), the short way round.
   4. Arc, centre (1.5000, 3.5000), radius 2.5, from (2.0000, 5.9495) to (4.0000, 3.5000), the short way round.
   5. Line to (4.0000, 0.0000).
   6. Close the profile with a line, then extrude 10.
   Body 2, sketch on the YZ plane, the profile across the 10 mm length, extruded 4 along +X:
   1. Start at (0.0000, 0.0000).
   2. Line to (0.0000, 3.5000).
   3. Arc, centre (2.5000, 3.5000), radius 2.5, from (0.0000, 3.5000) to (2.5000, 6.0000), the short way round.
   4. Line to (7.5000, 6.0000).
   5. Arc, centre (7.5000, 3.5000), radius 2.5, from (7.5000, 6.0000) to (10.0000, 3.5000), the short way round.
   6. Line to (10.0000, 0.0000).
   7. Close the profile with a line, then extrude 4.
   Intersect (Combine, Common) Body 1 with Body 2.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 DONE BUT INVALID (BRepCheck false, 4 free edge(s), volume -2.26e+26); main (0059) DONE BUT INVALID (BRepCheck false, 4 free edge(s), volume -2.26e+26); this branch (0060) DONE BUT INVALID (BRepCheck false, 4 free edge(s), volume -2.26e+26); this branch with candidate 0061 valid, volume 208.528817 (+2.3e-08 vs reference); reference volume 208.528817.

### G: all four top edges (a frame), radius 3, of a 4 x 10 x 6 box

File `G4-frame-3.png`.

Fillets, all in one operation: radius 3 on the edge whose middle is (2, 0, 6); radius 3 on the edge whose middle is (4, 5, 6); radius 3 on the edge whose middle is (2, 10, 6); radius 3 on the edge whose middle is (0, 5, 6).

Expected: r = 3: the arcs cross at an included angle of 141.06 deg; intersection of all four.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 3.0000, 6.0000)
   - arc centre (0.0000, 3.0000, 3.0000), radius 3, from A to B = (0.0000, 0.0000, 3.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 0.0000, 6.0000)
   - line from O to A = (1.0000, 0.0000, 6.0000)
   - arc centre (1.0000, 0.0000, 3.0000), radius 3, from A to B = (4.0000, 0.0000, 3.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the YZ plane at X = 4.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 10.0000, 6.0000)
   - line from O to A = (4.0000, 7.0000, 6.0000)
   - arc centre (4.0000, 7.0000, 3.0000), radius 3, from A to B = (4.0000, 10.0000, 3.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
5. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 6.0000)
   - line from O to A = (3.0000, 10.0000, 6.0000)
   - arc centre (3.0000, 10.0000, 3.0000), radius 3, from A to B = (0.0000, 10.0000, 3.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.

Shorter equivalent for a frame: build the two rounded profiles and Intersect them.
   Body 1, sketch on the XZ plane (origin at the box's lower-left corner), the profile across the 4 mm width, extruded 10 along +Y:
   1. Start at (0.0000, 0.0000).
   2. Line to (0.0000, 3.0000).
   3. Arc, centre (3.0000, 3.0000), radius 3, from (0.0000, 3.0000) to (2.0000, 5.8284), the short way round.
   4. Arc, centre (1.0000, 3.0000), radius 3, from (2.0000, 5.8284) to (4.0000, 3.0000), the short way round.
   5. Line to (4.0000, 0.0000).
   6. Close the profile with a line, then extrude 10.
   Body 2, sketch on the YZ plane, the profile across the 10 mm length, extruded 4 along +X:
   1. Start at (0.0000, 0.0000).
   2. Line to (0.0000, 3.0000).
   3. Arc, centre (3.0000, 3.0000), radius 3, from (0.0000, 3.0000) to (3.0000, 6.0000), the short way round.
   4. Line to (7.0000, 6.0000).
   5. Arc, centre (7.0000, 3.0000), radius 3, from (7.0000, 6.0000) to (10.0000, 3.0000), the short way round.
   6. Line to (10.0000, 0.0000).
   7. Close the profile with a line, then extrude 4.
   Intersect (Combine, Common) Body 1 with Body 2.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 DONE BUT INVALID (BRepCheck false, 4 free edge(s), volume 3.51e+29); main (0059) DONE BUT INVALID (BRepCheck false, 4 free edge(s), volume 3.51e+29); this branch (0060) DONE BUT INVALID (BRepCheck false, 4 free edge(s), volume 3.51e+29); this branch with candidate 0061 valid, volume 196.840194 (+2.4e-07 vs reference); reference volume 196.840194.

### G: all four top edges (a frame), radius 3.9, of a 4 x 10 x 6 box

File `G5-frame-3_9.png`.

Fillets, all in one operation: radius 3.9 on the edge whose middle is (2, 0, 6); radius 3.9 on the edge whose middle is (4, 5, 6); radius 3.9 on the edge whose middle is (2, 10, 6); radius 3.9 on the edge whose middle is (0, 5, 6).

Expected: r just below the 4 mm width: the arcs cross low on the wall; intersection of all four.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 3.9000, 6.0000)
   - arc centre (0.0000, 3.9000, 2.1000), radius 3.9, from A to B = (0.0000, 0.0000, 2.1000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 0.0000, 6.0000)
   - line from O to A = (0.1000, 0.0000, 6.0000)
   - arc centre (0.1000, 0.0000, 2.1000), radius 3.9, from A to B = (4.0000, 0.0000, 2.1000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the YZ plane at X = 4.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 10.0000, 6.0000)
   - line from O to A = (4.0000, 6.1000, 6.0000)
   - arc centre (4.0000, 6.1000, 2.1000), radius 3.9, from A to B = (4.0000, 10.0000, 2.1000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
5. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 6.0000)
   - line from O to A = (3.9000, 10.0000, 6.0000)
   - arc centre (3.9000, 10.0000, 2.1000), radius 3.9, from A to B = (0.0000, 10.0000, 2.1000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.

Shorter equivalent for a frame: build the two rounded profiles and Intersect them.
   Body 1, sketch on the XZ plane (origin at the box's lower-left corner), the profile across the 4 mm width, extruded 10 along +Y:
   1. Start at (0.0000, 0.0000).
   2. Line to (0.0000, 2.1000).
   3. Arc, centre (3.9000, 2.1000), radius 3.9, from (0.0000, 2.1000) to (2.0000, 5.5059), the short way round.
   4. Arc, centre (0.1000, 2.1000), radius 3.9, from (2.0000, 5.5059) to (4.0000, 2.1000), the short way round.
   5. Line to (4.0000, 0.0000).
   6. Close the profile with a line, then extrude 10.
   Body 2, sketch on the YZ plane, the profile across the 10 mm length, extruded 4 along +X:
   1. Start at (0.0000, 0.0000).
   2. Line to (0.0000, 2.1000).
   3. Arc, centre (3.9000, 2.1000), radius 3.9, from (0.0000, 2.1000) to (3.9000, 6.0000), the short way round.
   4. Line to (6.1000, 6.0000).
   5. Arc, centre (6.1000, 2.1000), radius 3.9, from (6.1000, 6.0000) to (10.0000, 2.1000), the short way round.
   6. Line to (10.0000, 0.0000).
   7. Close the profile with a line, then extrude 4.
   Intersect (Combine, Common) Body 1 with Body 2.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 DONE BUT INVALID (BRepCheck false, 4 free edge(s), volume -3.67e+28); main (0059) DONE BUT INVALID (BRepCheck false, 4 free edge(s), volume -3.67e+28); this branch (0060) DONE BUT INVALID (BRepCheck false, 4 free edge(s), volume -3.67e+28); this branch with candidate 0061 valid, volume 173.865651 (-1.9e-07 vs reference); reference volume 173.865651.

### G: all four top edges (a frame), radius 4.5, of a 4 x 10 x 6 box

File `G6-frame-4_5.png`.

Fillets, all in one operation: radius 4.5 on the edge whose middle is (2, 0, 6); radius 4.5 on the edge whose middle is (4, 5, 6); radius 4.5 on the edge whose middle is (2, 10, 6); radius 4.5 on the edge whose middle is (0, 5, 6).

Expected: r above the 4 mm width: each long edge pivots at the far top edge; the intersection of the two pivot cylinders, plus the end fillets (r 4.5 < the 6 mm wall, the 10 mm top).

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 4.5000, 6.0000)
   - arc centre (0.0000, 4.5000, 1.5000), radius 4.5, from A to B = (0.0000, 0.0000, 1.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 0.0000, 6.0000)
   - arc centre (-0.5000, 0.0000, 1.5279), radius 4.5, from A to B = (4.0000, 0.0000, 1.5279), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the YZ plane at X = 4.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 10.0000, 6.0000)
   - line from O to A = (4.0000, 5.5000, 6.0000)
   - arc centre (4.0000, 5.5000, 1.5000), radius 4.5, from A to B = (4.0000, 10.0000, 1.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
5. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 6.0000)
   - line from O to A = (4.0000, 10.0000, 6.0000)
   - arc centre (4.5000, 10.0000, 1.5279), radius 4.5, from A to B = (0.0000, 10.0000, 1.5279), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.

Shorter equivalent for a frame: build the two rounded profiles and Intersect them.
   Body 1, sketch on the XZ plane (origin at the box's lower-left corner), the profile across the 4 mm width, extruded 10 along +Y:
   1. Start at (0.0000, 0.0000).
   2. Line to (0.0000, 1.5279).
   3. Arc, centre (4.5000, 1.5279), radius 4.5, from (0.0000, 1.5279) to (2.0000, 5.2695), the short way round.
   4. Arc, centre (-0.5000, 1.5279), radius 4.5, from (2.0000, 5.2695) to (4.0000, 1.5279), the short way round.
   5. Line to (4.0000, 0.0000).
   6. Close the profile with a line, then extrude 10.
   Body 2, sketch on the YZ plane, the profile across the 10 mm length, extruded 4 along +X:
   1. Start at (0.0000, 0.0000).
   2. Line to (0.0000, 1.5000).
   3. Arc, centre (4.5000, 1.5000), radius 4.5, from (0.0000, 1.5000) to (4.5000, 6.0000), the short way round.
   4. Line to (5.5000, 6.0000).
   5. Arc, centre (5.5000, 1.5000), radius 4.5, from (5.5000, 6.0000) to (10.0000, 1.5000), the short way round.
   6. Line to (10.0000, 0.0000).
   7. Close the profile with a line, then extrude 4.
   Intersect (Combine, Common) Body 1 with Body 2.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 declined (IsDone false); main (0059) declined (IsDone false); this branch (0060) declined (IsDone false); this branch with candidate 0061 valid, volume 158.471230 (-1.2e-07 vs reference); reference volume 158.471230.

### G: all four top edges (a frame), radius 3, of a 10 x 10 x 8 box

File `G7-frame-sq-3.png`.

Fillets, all in one operation: radius 3 on the edge whose middle is (5, 0, 8); radius 3 on the edge whose middle is (10, 5, 8); radius 3 on the edge whose middle is (5, 10, 8); radius 3 on the edge whose middle is (0, 5, 8).

Expected: Ordinary frame on a 10 x 10 top: a flat 4 x 4 top.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (10, 10); extrude 8 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 8.0000)
   - line from O to A = (0.0000, 3.0000, 8.0000)
   - arc centre (0.0000, 3.0000, 5.0000), radius 3, from A to B = (0.0000, 0.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (10.0000, 0.0000, 8.0000)
   - line from O to A = (7.0000, 0.0000, 8.0000)
   - arc centre (7.0000, 0.0000, 5.0000), radius 3, from A to B = (10.0000, 0.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the YZ plane at X = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (10.0000, 10.0000, 8.0000)
   - line from O to A = (10.0000, 7.0000, 8.0000)
   - arc centre (10.0000, 7.0000, 5.0000), radius 3, from A to B = (10.0000, 10.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
5. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 8.0000)
   - line from O to A = (3.0000, 10.0000, 8.0000)
   - arc centre (3.0000, 10.0000, 5.0000), radius 3, from A to B = (0.0000, 10.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.

Shorter equivalent for a frame: build the two rounded profiles and Intersect them.
   Body 1, sketch on the XZ plane (origin at the box's lower-left corner), the profile across the 10 mm width, extruded 10 along +Y:
   1. Start at (0.0000, 0.0000).
   2. Line to (0.0000, 5.0000).
   3. Arc, centre (3.0000, 5.0000), radius 3, from (0.0000, 5.0000) to (3.0000, 8.0000), the short way round.
   4. Line to (7.0000, 8.0000).
   5. Arc, centre (7.0000, 5.0000), radius 3, from (7.0000, 8.0000) to (10.0000, 5.0000), the short way round.
   6. Line to (10.0000, 0.0000).
   7. Close the profile with a line, then extrude 10.
   Body 2, sketch on the YZ plane, the profile across the 10 mm length, extruded 10 along +X:
   1. Start at (0.0000, 0.0000).
   2. Line to (0.0000, 5.0000).
   3. Arc, centre (3.0000, 5.0000), radius 3, from (0.0000, 5.0000) to (3.0000, 8.0000), the short way round.
   4. Line to (7.0000, 8.0000).
   5. Arc, centre (7.0000, 5.0000), radius 3, from (7.0000, 8.0000) to (10.0000, 5.0000), the short way round.
   6. Line to (10.0000, 0.0000).
   7. Close the profile with a line, then extrude 10.
   Intersect (Combine, Common) Body 1 with Body 2.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 valid, volume 733.097335 (-2.2e-07 vs reference); main (0059) valid, volume 733.097335 (-2.2e-07 vs reference); this branch (0060) valid, volume 733.097335 (-2.2e-07 vs reference); this branch with candidate 0061 valid, volume 733.097335 (-2.2e-07 vs reference); reference volume 733.097336.

### G: all four top edges (a frame), radius 5, of a 10 x 10 x 8 box

File `G8-frame-sq-5.png`.

Fillets, all in one operation: radius 5 on the edge whose middle is (5, 0, 8); radius 5 on the edge whose middle is (10, 5, 8); radius 5 on the edge whose middle is (5, 10, 8); radius 5 on the edge whose middle is (0, 5, 8).

Expected: r = w/2 in both directions: the flat top shrinks to a single point at (5, 5); four cylinders meeting along the two diagonals (a pyramid-like dome with a point).

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (10, 10); extrude 8 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 8.0000)
   - line from O to A = (0.0000, 5.0000, 8.0000)
   - arc centre (0.0000, 5.0000, 3.0000), radius 5, from A to B = (0.0000, 0.0000, 3.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (10.0000, 0.0000, 8.0000)
   - line from O to A = (5.0000, 0.0000, 8.0000)
   - arc centre (5.0000, 0.0000, 3.0000), radius 5, from A to B = (10.0000, 0.0000, 3.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the YZ plane at X = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (10.0000, 10.0000, 8.0000)
   - line from O to A = (10.0000, 5.0000, 8.0000)
   - arc centre (10.0000, 5.0000, 3.0000), radius 5, from A to B = (10.0000, 10.0000, 3.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
5. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 8.0000)
   - line from O to A = (5.0000, 10.0000, 8.0000)
   - arc centre (5.0000, 10.0000, 3.0000), radius 5, from A to B = (0.0000, 10.0000, 3.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.

Shorter equivalent for a frame: build the two rounded profiles and Intersect them.
   Body 1, sketch on the XZ plane (origin at the box's lower-left corner), the profile across the 10 mm width, extruded 10 along +Y:
   1. Start at (0.0000, 0.0000).
   2. Line to (0.0000, 3.0000).
   3. Arc, centre (5.0000, 3.0000), radius 5, from (0.0000, 3.0000) to (5.0000, 8.0000), the short way round.
   4. Arc, centre (5.0000, 3.0000), radius 5, from (5.0000, 8.0000) to (10.0000, 3.0000), the short way round.
   5. Line to (10.0000, 0.0000).
   6. Close the profile with a line, then extrude 10.
   Body 2, sketch on the YZ plane, the profile across the 10 mm length, extruded 10 along +X:
   1. Start at (0.0000, 0.0000).
   2. Line to (0.0000, 3.0000).
   3. Arc, centre (5.0000, 3.0000), radius 5, from (0.0000, 3.0000) to (5.0000, 8.0000), the short way round.
   4. Arc, centre (5.0000, 3.0000), radius 5, from (5.0000, 8.0000) to (10.0000, 3.0000), the short way round.
   5. Line to (10.0000, 0.0000).
   6. Close the profile with a line, then extrude 10.
   Intersect (Combine, Common) Body 1 with Body 2.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 declined (IsDone false); main (0059) declined (IsDone false); this branch (0060) declined (IsDone false); this branch with candidate 0061 valid, volume 633.333333 (-1.0e-09 vs reference); reference volume 633.333333.

### G: all four top edges (a frame), radius 6, of a 10 x 10 x 8 box

File `G9-frame-sq-6.png`.

Fillets, all in one operation: radius 6 on the edge whose middle is (5, 0, 8); radius 6 on the edge whose middle is (10, 5, 8); radius 6 on the edge whose middle is (5, 10, 8); radius 6 on the edge whose middle is (0, 5, 8).

Expected: r > w/2 in both directions: the intersection of four rounded profiles, a ridge-less crossing; the arcs cross at an included angle of 134.9 deg and the top face is gone.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (10, 10); extrude 8 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 8.0000)
   - line from O to A = (0.0000, 6.0000, 8.0000)
   - arc centre (0.0000, 6.0000, 2.0000), radius 6, from A to B = (0.0000, 0.0000, 2.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (10.0000, 0.0000, 8.0000)
   - line from O to A = (4.0000, 0.0000, 8.0000)
   - arc centre (4.0000, 0.0000, 2.0000), radius 6, from A to B = (10.0000, 0.0000, 2.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the YZ plane at X = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (10.0000, 10.0000, 8.0000)
   - line from O to A = (10.0000, 4.0000, 8.0000)
   - arc centre (10.0000, 4.0000, 2.0000), radius 6, from A to B = (10.0000, 10.0000, 2.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
5. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 8.0000)
   - line from O to A = (6.0000, 10.0000, 8.0000)
   - arc centre (6.0000, 10.0000, 2.0000), radius 6, from A to B = (0.0000, 10.0000, 2.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.

Shorter equivalent for a frame: build the two rounded profiles and Intersect them.
   Body 1, sketch on the XZ plane (origin at the box's lower-left corner), the profile across the 10 mm width, extruded 10 along +Y:
   1. Start at (0.0000, 0.0000).
   2. Line to (0.0000, 2.0000).
   3. Arc, centre (6.0000, 2.0000), radius 6, from (0.0000, 2.0000) to (5.0000, 7.9161), the short way round.
   4. Arc, centre (4.0000, 2.0000), radius 6, from (5.0000, 7.9161) to (10.0000, 2.0000), the short way round.
   5. Line to (10.0000, 0.0000).
   6. Close the profile with a line, then extrude 10.
   Body 2, sketch on the YZ plane, the profile across the 10 mm length, extruded 10 along +X:
   1. Start at (0.0000, 0.0000).
   2. Line to (0.0000, 2.0000).
   3. Arc, centre (6.0000, 2.0000), radius 6, from (0.0000, 2.0000) to (5.0000, 7.9161), the short way round.
   4. Arc, centre (4.0000, 2.0000), radius 6, from (5.0000, 7.9161) to (10.0000, 2.0000), the short way round.
   5. Line to (10.0000, 0.0000).
   6. Close the profile with a line, then extrude 10.
   Intersect (Combine, Common) Body 1 with Body 2.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 DONE BUT INVALID (BRepCheck false, 4 free edge(s), volume 684); main (0059) DONE BUT INVALID (BRepCheck false, 4 free edge(s), volume 684); this branch (0060) DONE BUT INVALID (BRepCheck false, 4 free edge(s), volume 684); this branch with candidate 0061 valid, volume 573.749618 (-1.9e-07 vs reference); reference volume 573.749618.

### G: all four top edges (a frame) of a 4 x 10 x 6 box, radius 3 on the two long edges and 1 on the two short ones

File `G10-frame-3-1.png`.

Fillets, all in one operation: radius 1 on the edge whose middle is (2, 0, 6); radius 3 on the edge whose middle is (4, 5, 6); radius 1 on the edge whose middle is (2, 10, 6); radius 3 on the edge whose middle is (0, 5, 6).

Expected: Unequal radii: the long edges (r 3) cross at x = 2; the end edges (r 1) meet them in mitres whose curves are the intersections of a r = 1 and a r = 3 cylinder. Intersection of the four.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 1.0000, 6.0000)
   - arc centre (0.0000, 1.0000, 5.0000), radius 1, from A to B = (0.0000, 0.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 0.0000, 6.0000)
   - line from O to A = (1.0000, 0.0000, 6.0000)
   - arc centre (1.0000, 0.0000, 3.0000), radius 3, from A to B = (4.0000, 0.0000, 3.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the YZ plane at X = 4.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 10.0000, 6.0000)
   - line from O to A = (4.0000, 9.0000, 6.0000)
   - arc centre (4.0000, 9.0000, 5.0000), radius 1, from A to B = (4.0000, 10.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
5. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 6.0000)
   - line from O to A = (3.0000, 10.0000, 6.0000)
   - arc centre (3.0000, 10.0000, 3.0000), radius 3, from A to B = (0.0000, 10.0000, 3.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.

Shorter equivalent for a frame: build the two rounded profiles and Intersect them.
   Body 1, sketch on the XZ plane (origin at the box's lower-left corner), the profile across the 4 mm width, extruded 10 along +Y:
   1. Start at (0.0000, 0.0000).
   2. Line to (0.0000, 5.0000).
   3. Arc, centre (1.0000, 5.0000), radius 1, from (0.0000, 5.0000) to (1.0000, 6.0000), the short way round.
   4. Line to (3.0000, 6.0000).
   5. Arc, centre (3.0000, 5.0000), radius 1, from (3.0000, 6.0000) to (4.0000, 5.0000), the short way round.
   6. Line to (4.0000, 0.0000).
   7. Close the profile with a line, then extrude 10.
   Body 2, sketch on the YZ plane, the profile across the 10 mm length, extruded 4 along +X:
   1. Start at (0.0000, 0.0000).
   2. Line to (0.0000, 5.0000).
   3. Arc, centre (1.0000, 5.0000), radius 1, from (0.0000, 5.0000) to (1.0000, 6.0000), the short way round.
   4. Line to (9.0000, 6.0000).
   5. Arc, centre (9.0000, 5.0000), radius 1, from (9.0000, 6.0000) to (10.0000, 5.0000), the short way round.
   6. Line to (10.0000, 0.0000).
   7. Close the profile with a line, then extrude 4.
   Intersect (Combine, Common) Body 1 with Body 2.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 DONE BUT INVALID (BRepCheck false, 4 free edge(s), volume 229); main (0059) DONE BUT INVALID (BRepCheck false, 4 free edge(s), volume 229); this branch (0060) DONE BUT INVALID (BRepCheck false, 4 free edge(s), volume 229); this branch with candidate 0061 valid, volume 202.326335 (-1.0e-08 vs reference); reference volume 202.326335.

## H: the whole top contour of an L-shaped and a U-shaped extrusion

### H: the whole top contour (6 edges, radius 1) of a L-shaped (arms 3 wide) extrusion 6 high

File `H1-L-1.png` and `H1-L-1-decision.png`.

Fillets, all in one operation: radius 1 on the edge whose middle is (4, 0, 6); radius 1 on the edge whose middle is (8, 1.5, 6); radius 1 on the edge whose middle is (5.5, 3, 6); radius 1 on the edge whose middle is (3, 5.5, 6); radius 1 on the edge whose middle is (1.5, 8, 6); radius 1 on the edge whose middle is (0, 4, 6).

Expected: Five convex corners are mitres. At the reflex corner (3, 3) the two fillets do not meet on their own: this is a design choice (candidates A, B, C in the decision image). r = 1 is below half the arm width.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane the closed polyline (0, 0), (8, 0), (8, 3), (3, 3), (3, 8), (0, 8); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 1.0000, 6.0000)
   - arc centre (0.0000, 1.0000, 5.0000), radius 1, from A to B = (0.0000, 0.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 8.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (8.0000, 0.0000, 6.0000)
   - line from O to A = (7.0000, 0.0000, 6.0000)
   - arc centre (7.0000, 0.0000, 5.0000), radius 1, from A to B = (8.0000, 0.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 3.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the YZ plane at X = 8.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (8.0000, 3.0000, 6.0000)
   - line from O to A = (8.0000, 2.0000, 6.0000)
   - arc centre (8.0000, 2.0000, 5.0000), radius 1, from A to B = (8.0000, 3.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 5.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
5. Cut by a swept profile. Sketch on the XZ plane at Y = 3.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (3.0000, 3.0000, 6.0000)
   - line from O to A = (2.0000, 3.0000, 6.0000)
   - arc centre (2.0000, 3.0000, 5.0000), radius 1, from A to B = (3.0000, 3.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 5.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
6. Cut by a swept profile. Sketch on the YZ plane at X = 3.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (3.0000, 8.0000, 6.0000)
   - line from O to A = (3.0000, 7.0000, 6.0000)
   - arc centre (3.0000, 7.0000, 5.0000), radius 1, from A to B = (3.0000, 8.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 3.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
7. Cut by a swept profile. Sketch on the XZ plane at Y = 8.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 8.0000, 6.0000)
   - line from O to A = (1.0000, 8.0000, 6.0000)
   - arc centre (1.0000, 8.0000, 5.0000), radius 1, from A to B = (0.0000, 8.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 8.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.
8. Cut the revolved corner piece. Sketch on the vertical plane through O = (3.0000, 3.0000, 6.0000) that contains the direction (-1, 0, 0), one closed profile:
   - line from O to A = (2.0000, 3.0000, 6.0000)
   - arc centre (2.0000, 3.0000, 5.0000), radius 1, from A to B = (3.0000, 3.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Revolve the profile 90 degrees about the vertical axis through O, counter-clockwise seen from above starting from that direction, as a Subtract from the body.

Candidate B instead (mitre): the same, but every band runs 1 past each reflex vertex instead of stopping at it, and the revolved pieces are left out.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 valid, volume 227.516223 (-2.1e-02 vs reference); main (0059) valid, volume 227.516223 (-2.1e-02 vs reference); this branch (0060) valid, volume 227.516223 (-2.1e-02 vs reference); this branch with candidate 0061 valid, volume 227.516223 (-2.1e-02 vs reference); reference volume 227.536797.

### H: the whole top contour (6 edges, radius 1.5) of a L-shaped (arms 3 wide) extrusion 6 high

File `H2-L-1_5.png` and `H2-L-1_5-decision.png`.

Fillets, all in one operation: radius 1.5 on the edge whose middle is (4, 0, 6); radius 1.5 on the edge whose middle is (8, 1.5, 6); radius 1.5 on the edge whose middle is (5.5, 3, 6); radius 1.5 on the edge whose middle is (3, 5.5, 6); radius 1.5 on the edge whose middle is (1.5, 8, 6); radius 1.5 on the edge whose middle is (0, 4, 6).

Expected: r = w/2 on 3 mm arms: each arm's top shrinks to a ridge line; reflex corner as H1 (decision).

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane the closed polyline (0, 0), (8, 0), (8, 3), (3, 3), (3, 8), (0, 8); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 1.5000, 6.0000)
   - arc centre (0.0000, 1.5000, 4.5000), radius 1.5, from A to B = (0.0000, 0.0000, 4.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 8.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (8.0000, 0.0000, 6.0000)
   - line from O to A = (6.5000, 0.0000, 6.0000)
   - arc centre (6.5000, 0.0000, 4.5000), radius 1.5, from A to B = (8.0000, 0.0000, 4.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 3.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the YZ plane at X = 8.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (8.0000, 3.0000, 6.0000)
   - line from O to A = (8.0000, 1.5000, 6.0000)
   - arc centre (8.0000, 1.5000, 4.5000), radius 1.5, from A to B = (8.0000, 3.0000, 4.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 5.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
5. Cut by a swept profile. Sketch on the XZ plane at Y = 3.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (3.0000, 3.0000, 6.0000)
   - line from O to A = (1.5000, 3.0000, 6.0000)
   - arc centre (1.5000, 3.0000, 4.5000), radius 1.5, from A to B = (3.0000, 3.0000, 4.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 5.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
6. Cut by a swept profile. Sketch on the YZ plane at X = 3.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (3.0000, 8.0000, 6.0000)
   - line from O to A = (3.0000, 6.5000, 6.0000)
   - arc centre (3.0000, 6.5000, 4.5000), radius 1.5, from A to B = (3.0000, 8.0000, 4.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 3.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
7. Cut by a swept profile. Sketch on the XZ plane at Y = 8.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 8.0000, 6.0000)
   - line from O to A = (1.5000, 8.0000, 6.0000)
   - arc centre (1.5000, 8.0000, 4.5000), radius 1.5, from A to B = (0.0000, 8.0000, 4.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 8.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.
8. Cut the revolved corner piece. Sketch on the vertical plane through O = (3.0000, 3.0000, 6.0000) that contains the direction (-1, 0, 0), one closed profile:
   - line from O to A = (1.5000, 3.0000, 6.0000)
   - arc centre (1.5000, 3.0000, 4.5000), radius 1.5, from A to B = (3.0000, 3.0000, 4.5000), the short way round (it bulges towards O)
   - line from B back to O
   Revolve the profile 90 degrees about the vertical axis through O, counter-clockwise seen from above starting from that direction, as a Subtract from the body.

Candidate B instead (mitre): the same, but every band runs 1.5 past each reflex vertex instead of stopping at it, and the revolved pieces are left out.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 declined (IsDone false); main (0059) declined (IsDone false); this branch (0060) declined (IsDone false); this branch with candidate 0061 declined (IsDone false); reference volume 219.912354.

### H: the whole top contour (6 edges, radius 2) of a L-shaped (arms 3 wide) extrusion 6 high

File `H3-L-2.png` and `H3-L-2-decision.png`.

Fillets, all in one operation: radius 2 on the edge whose middle is (4, 0, 6); radius 2 on the edge whose middle is (8, 1.5, 6); radius 2 on the edge whose middle is (5.5, 3, 6); radius 2 on the edge whose middle is (3, 5.5, 6); radius 2 on the edge whose middle is (1.5, 8, 6); radius 2 on the edge whose middle is (0, 4, 6).

Expected: r > w/2: the opposite arcs cross along each arm; the intersection of the rounded profiles; reflex corner as H1 (decision).

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane the closed polyline (0, 0), (8, 0), (8, 3), (3, 3), (3, 8), (0, 8); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 2.0000, 6.0000)
   - arc centre (0.0000, 2.0000, 4.0000), radius 2, from A to B = (0.0000, 0.0000, 4.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 8.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (8.0000, 0.0000, 6.0000)
   - line from O to A = (6.0000, 0.0000, 6.0000)
   - arc centre (6.0000, 0.0000, 4.0000), radius 2, from A to B = (8.0000, 0.0000, 4.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 3.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the YZ plane at X = 8.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (8.0000, 3.0000, 6.0000)
   - line from O to A = (8.0000, 1.0000, 6.0000)
   - arc centre (8.0000, 1.0000, 4.0000), radius 2, from A to B = (8.0000, 3.0000, 4.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 5.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
5. Cut by a swept profile. Sketch on the XZ plane at Y = 3.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (3.0000, 3.0000, 6.0000)
   - line from O to A = (1.0000, 3.0000, 6.0000)
   - arc centre (1.0000, 3.0000, 4.0000), radius 2, from A to B = (3.0000, 3.0000, 4.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 5.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
6. Cut by a swept profile. Sketch on the YZ plane at X = 3.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (3.0000, 8.0000, 6.0000)
   - line from O to A = (3.0000, 6.0000, 6.0000)
   - arc centre (3.0000, 6.0000, 4.0000), radius 2, from A to B = (3.0000, 8.0000, 4.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 3.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
7. Cut by a swept profile. Sketch on the XZ plane at Y = 8.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 8.0000, 6.0000)
   - line from O to A = (2.0000, 8.0000, 6.0000)
   - arc centre (2.0000, 8.0000, 4.0000), radius 2, from A to B = (0.0000, 8.0000, 4.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 8.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.
8. Cut the revolved corner piece. Sketch on the vertical plane through O = (3.0000, 3.0000, 6.0000) that contains the direction (-1, 0, 0), one closed profile:
   - line from O to A = (1.0000, 3.0000, 6.0000)
   - arc centre (1.0000, 3.0000, 4.0000), radius 2, from A to B = (3.0000, 3.0000, 4.0000), the short way round (it bulges towards O)
   - line from B back to O
   Revolve the profile 90 degrees about the vertical axis through O, counter-clockwise seen from above starting from that direction, as a Subtract from the body.

Candidate B instead (mitre): the same, but every band runs 2 past each reflex vertex instead of stopping at it, and the revolved pieces are left out.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 DONE BUT INVALID (BRepCheck false, 6 free edge(s), volume 237); main (0059) DONE BUT INVALID (BRepCheck false, 6 free edge(s), volume 237); this branch (0060) DONE BUT INVALID (BRepCheck false, 6 free edge(s), volume 237); this branch with candidate 0061 DONE BUT INVALID (BRepCheck false, 6 free edge(s), volume 237); reference volume 209.933799.

### H: the whole top contour (8 edges, radius 1) of a U-shaped (arms 3 wide) extrusion 6 high

File `H4-U-1.png` and `H4-U-1-decision.png`.

Fillets, all in one operation: radius 1 on the edge whose middle is (4.5, 0, 6); radius 1 on the edge whose middle is (9, 3.5, 6); radius 1 on the edge whose middle is (7.5, 7, 6); radius 1 on the edge whose middle is (6, 5, 6); radius 1 on the edge whose middle is (4.5, 3, 6); radius 1 on the edge whose middle is (3, 5, 6); radius 1 on the edge whose middle is (1.5, 7, 6); radius 1 on the edge whose middle is (0, 3.5, 6).

Expected: Two reflex corners, each a design choice as in H1; r = 1 below half the arm width.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane the closed polyline (0, 0), (9, 0), (9, 7), (6, 7), (6, 3), (3, 3), (3, 7), (0, 7); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 1.0000, 6.0000)
   - arc centre (0.0000, 1.0000, 5.0000), radius 1, from A to B = (0.0000, 0.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 9.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (9.0000, 0.0000, 6.0000)
   - line from O to A = (8.0000, 0.0000, 6.0000)
   - arc centre (8.0000, 0.0000, 5.0000), radius 1, from A to B = (9.0000, 0.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 7.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the YZ plane at X = 9.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (9.0000, 7.0000, 6.0000)
   - line from O to A = (9.0000, 6.0000, 6.0000)
   - arc centre (9.0000, 6.0000, 5.0000), radius 1, from A to B = (9.0000, 7.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 3.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
5. Cut by a swept profile. Sketch on the XZ plane at Y = 7.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (6.0000, 7.0000, 6.0000)
   - line from O to A = (7.0000, 7.0000, 6.0000)
   - arc centre (7.0000, 7.0000, 5.0000), radius 1, from A to B = (6.0000, 7.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.
6. Cut by a swept profile. Sketch on the YZ plane at X = 6.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (6.0000, 3.0000, 6.0000)
   - line from O to A = (6.0000, 2.0000, 6.0000)
   - arc centre (6.0000, 2.0000, 5.0000), radius 1, from A to B = (6.0000, 3.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 3.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
7. Cut by a swept profile. Sketch on the XZ plane at Y = 3.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (3.0000, 3.0000, 6.0000)
   - line from O to A = (2.0000, 3.0000, 6.0000)
   - arc centre (2.0000, 3.0000, 5.0000), radius 1, from A to B = (3.0000, 3.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
8. Cut by a swept profile. Sketch on the YZ plane at X = 3.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (3.0000, 7.0000, 6.0000)
   - line from O to A = (3.0000, 6.0000, 6.0000)
   - arc centre (3.0000, 6.0000, 5.0000), radius 1, from A to B = (3.0000, 7.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 3.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
9. Cut by a swept profile. Sketch on the XZ plane at Y = 7.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 7.0000, 6.0000)
   - line from O to A = (1.0000, 7.0000, 6.0000)
   - arc centre (1.0000, 7.0000, 5.0000), radius 1, from A to B = (0.0000, 7.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 7.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.
10. Cut the revolved corner piece. Sketch on the vertical plane through O = (6.0000, 3.0000, 6.0000) that contains the direction (-0, -1, 0), one closed profile:
   - line from O to A = (6.0000, 2.0000, 6.0000)
   - arc centre (6.0000, 2.0000, 5.0000), radius 1, from A to B = (6.0000, 3.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Revolve the profile 90 degrees about the vertical axis through O, counter-clockwise seen from above starting from that direction, as a Subtract from the body.
11. Cut the revolved corner piece. Sketch on the vertical plane through O = (3.0000, 3.0000, 6.0000) that contains the direction (-1, 0, 0), one closed profile:
   - line from O to A = (2.0000, 3.0000, 6.0000)
   - arc centre (2.0000, 3.0000, 5.0000), radius 1, from A to B = (3.0000, 3.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Revolve the profile 90 degrees about the vertical axis through O, counter-clockwise seen from above starting from that direction, as a Subtract from the body.

Candidate B instead (mitre): the same, but every band runs 1 past each reflex vertex instead of stopping at it, and the revolved pieces are left out.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 valid, volume 297.799408 (-4.1e-02 vs reference); main (0059) valid, volume 297.799408 (-4.1e-02 vs reference); this branch (0060) valid, volume 297.799408 (-4.1e-02 vs reference); this branch with candidate 0061 valid, volume 297.799408 (-4.1e-02 vs reference); reference volume 297.840556.

### H: the whole top contour (8 edges, radius 1.5) of a U-shaped (arms 3 wide) extrusion 6 high

File `H5-U-1_5.png` and `H5-U-1_5-decision.png`.

Fillets, all in one operation: radius 1.5 on the edge whose middle is (4.5, 0, 6); radius 1.5 on the edge whose middle is (9, 3.5, 6); radius 1.5 on the edge whose middle is (7.5, 7, 6); radius 1.5 on the edge whose middle is (6, 5, 6); radius 1.5 on the edge whose middle is (4.5, 3, 6); radius 1.5 on the edge whose middle is (3, 5, 6); radius 1.5 on the edge whose middle is (1.5, 7, 6); radius 1.5 on the edge whose middle is (0, 3.5, 6).

Expected: r = w/2: every arm top shrinks to a line; two reflex corners.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane the closed polyline (0, 0), (9, 0), (9, 7), (6, 7), (6, 3), (3, 3), (3, 7), (0, 7); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 1.5000, 6.0000)
   - arc centre (0.0000, 1.5000, 4.5000), radius 1.5, from A to B = (0.0000, 0.0000, 4.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 9.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (9.0000, 0.0000, 6.0000)
   - line from O to A = (7.5000, 0.0000, 6.0000)
   - arc centre (7.5000, 0.0000, 4.5000), radius 1.5, from A to B = (9.0000, 0.0000, 4.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 7.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the YZ plane at X = 9.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (9.0000, 7.0000, 6.0000)
   - line from O to A = (9.0000, 5.5000, 6.0000)
   - arc centre (9.0000, 5.5000, 4.5000), radius 1.5, from A to B = (9.0000, 7.0000, 4.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 3.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
5. Cut by a swept profile. Sketch on the XZ plane at Y = 7.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (6.0000, 7.0000, 6.0000)
   - line from O to A = (7.5000, 7.0000, 6.0000)
   - arc centre (7.5000, 7.0000, 4.5000), radius 1.5, from A to B = (6.0000, 7.0000, 4.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.
6. Cut by a swept profile. Sketch on the YZ plane at X = 6.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (6.0000, 3.0000, 6.0000)
   - line from O to A = (6.0000, 1.5000, 6.0000)
   - arc centre (6.0000, 1.5000, 4.5000), radius 1.5, from A to B = (6.0000, 3.0000, 4.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 3.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
7. Cut by a swept profile. Sketch on the XZ plane at Y = 3.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (3.0000, 3.0000, 6.0000)
   - line from O to A = (1.5000, 3.0000, 6.0000)
   - arc centre (1.5000, 3.0000, 4.5000), radius 1.5, from A to B = (3.0000, 3.0000, 4.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
8. Cut by a swept profile. Sketch on the YZ plane at X = 3.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (3.0000, 7.0000, 6.0000)
   - line from O to A = (3.0000, 5.5000, 6.0000)
   - arc centre (3.0000, 5.5000, 4.5000), radius 1.5, from A to B = (3.0000, 7.0000, 4.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 3.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
9. Cut by a swept profile. Sketch on the XZ plane at Y = 7.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 7.0000, 6.0000)
   - line from O to A = (1.5000, 7.0000, 6.0000)
   - arc centre (1.5000, 7.0000, 4.5000), radius 1.5, from A to B = (0.0000, 7.0000, 4.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 7.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.
10. Cut the revolved corner piece. Sketch on the vertical plane through O = (6.0000, 3.0000, 6.0000) that contains the direction (-0, -1, 0), one closed profile:
   - line from O to A = (6.0000, 1.5000, 6.0000)
   - arc centre (6.0000, 1.5000, 4.5000), radius 1.5, from A to B = (6.0000, 3.0000, 4.5000), the short way round (it bulges towards O)
   - line from B back to O
   Revolve the profile 90 degrees about the vertical axis through O, counter-clockwise seen from above starting from that direction, as a Subtract from the body.
11. Cut the revolved corner piece. Sketch on the vertical plane through O = (3.0000, 3.0000, 6.0000) that contains the direction (-1, 0, 0), one closed profile:
   - line from O to A = (1.5000, 3.0000, 6.0000)
   - arc centre (1.5000, 3.0000, 4.5000), radius 1.5, from A to B = (3.0000, 3.0000, 4.5000), the short way round (it bulges towards O)
   - line from B back to O
   Revolve the profile 90 degrees about the vertical axis through O, counter-clockwise seen from above starting from that direction, as a Subtract from the body.

Candidate B instead (mitre): the same, but every band runs 1.5 past each reflex vertex instead of stopping at it, and the revolved pieces are left out.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 declined (IsDone false); main (0059) declined (IsDone false); this branch (0060) declined (IsDone false); this branch with candidate 0061 declined (IsDone false); reference volume 288.118958.

### H: the whole top contour (6 edges, radius 3.5) of a L-shaped (arms 3 wide) extrusion 6 high

File `H6-L-3_5.png` and `H6-L-3_5-decision.png`.

Fillets, all in one operation: radius 3.5 on the edge whose middle is (4, 0, 6); radius 3.5 on the edge whose middle is (8, 1.5, 6); radius 3.5 on the edge whose middle is (5.5, 3, 6); radius 3.5 on the edge whose middle is (3, 5.5, 6); radius 3.5 on the edge whose middle is (1.5, 8, 6); radius 3.5 on the edge whose middle is (0, 4, 6).

Expected: r above the 3 mm arm width: every arm edge pivots at the far edge of the arm; the intersection; reflex corner as H1 (decision).

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane the closed polyline (0, 0), (8, 0), (8, 3), (3, 3), (3, 8), (0, 8); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 3.0000, 6.0000)
   - arc centre (0.0000, 3.5000, 2.5359), radius 3.5, from A to B = (0.0000, 0.0000, 2.5359), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 8.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (8.0000, 0.0000, 6.0000)
   - line from O to A = (4.5000, 0.0000, 6.0000)
   - arc centre (4.5000, 0.0000, 2.5000), radius 3.5, from A to B = (8.0000, 0.0000, 2.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 3.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the YZ plane at X = 8.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (8.0000, 3.0000, 6.0000)
   - line from O to A = (8.0000, 0.0000, 6.0000)
   - arc centre (8.0000, -0.5000, 2.5359), radius 3.5, from A to B = (8.0000, 3.0000, 2.5359), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 5.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
5. Cut by a swept profile. Sketch on the XZ plane at Y = 3.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (3.0000, 3.0000, 6.0000)
   - line from O to A = (0.0000, 3.0000, 6.0000)
   - arc centre (-0.5000, 3.0000, 2.5359), radius 3.5, from A to B = (3.0000, 3.0000, 2.5359), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 5.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
6. Cut by a swept profile. Sketch on the YZ plane at X = 3.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (3.0000, 8.0000, 6.0000)
   - line from O to A = (3.0000, 4.5000, 6.0000)
   - arc centre (3.0000, 4.5000, 2.5000), radius 3.5, from A to B = (3.0000, 8.0000, 2.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 3.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
7. Cut by a swept profile. Sketch on the XZ plane at Y = 8.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 8.0000, 6.0000)
   - line from O to A = (3.0000, 8.0000, 6.0000)
   - arc centre (3.5000, 8.0000, 2.5359), radius 3.5, from A to B = (0.0000, 8.0000, 2.5359), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 8.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.
8. Cut the revolved corner piece. Sketch on the vertical plane through O = (3.0000, 3.0000, 6.0000) that contains the direction (-1, 0, 0), one closed profile:
   - line from O to A = (-0.5000, 3.0000, 6.0000)
   - arc centre (-0.5000, 3.0000, 2.5000), radius 3.5, from A to B = (3.0000, 3.0000, 2.5000), the short way round (it bulges towards O)
   - line from B back to O
   Revolve the profile 90 degrees about the vertical axis through O, counter-clockwise seen from above starting from that direction, as a Subtract from the body.

Candidate B instead (mitre): the same, but every band runs 3.5 past each reflex vertex instead of stopping at it, and the revolved pieces are left out.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 declined (IsDone false); main (0059) declined (IsDone false); this branch (0060) declined (IsDone false); this branch with candidate 0061 declined (IsDone false); reference volume 174.207582.

## I: the convex top edges plus the vertical edges, with the corner blends

### I: the four top edges (radius 1) and the four vertical edges (radius 1) of a 4 x 10 x 6 box: four corner blends

File `I1-round-1-1.png`.

Fillets, all in one operation: radius 1 on the edge whose middle is (2, 0, 6); radius 1 on the edge whose middle is (4, 5, 6); radius 1 on the edge whose middle is (2, 10, 6); radius 1 on the edge whose middle is (0, 5, 6); radius 1 on the edge whose middle is (0, 0, 3); radius 1 on the edge whose middle is (4, 0, 3); radius 1 on the edge whose middle is (4, 10, 3); radius 1 on the edge whose middle is (0, 10, 3).

Expected: Four spherical corners (balls of radius 1 at the corners of the inner box), cylinders between them: the rolling ball over the box.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 1.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (1.0000, 0.0000, 6.0000)
   - line from O to A = (1.0000, 1.0000, 6.0000)
   - arc centre (1.0000, 1.0000, 5.0000), radius 1, from A to B = (1.0000, 0.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 2.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 1.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 1.0000, 6.0000)
   - line from O to A = (3.0000, 1.0000, 6.0000)
   - arc centre (3.0000, 1.0000, 5.0000), radius 1, from A to B = (4.0000, 1.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 8.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the YZ plane at X = 3.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (3.0000, 10.0000, 6.0000)
   - line from O to A = (3.0000, 9.0000, 6.0000)
   - arc centre (3.0000, 9.0000, 5.0000), radius 1, from A to B = (3.0000, 10.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 2.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
5. Cut by a swept profile. Sketch on the XZ plane at Y = 9.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 9.0000, 6.0000)
   - line from O to A = (1.0000, 9.0000, 6.0000)
   - arc centre (1.0000, 9.0000, 5.0000), radius 1, from A to B = (0.0000, 9.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 8.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.
6. Cut by a swept profile. Sketch on the XY plane at Z = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 0.0000)
   - line from O to A = (1.0000, 0.0000, 0.0000)
   - arc centre (1.0000, 1.0000, 0.0000), radius 1, from A to B = (0.0000, 1.0000, 0.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 5.0000 along (0, 0, 1) as a Subtract (Combine, Cut) from the body.
7. Cut by a swept profile. Sketch on the XY plane at Z = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 0.0000, 0.0000)
   - line from O to A = (4.0000, 1.0000, 0.0000)
   - arc centre (3.0000, 1.0000, 0.0000), radius 1, from A to B = (3.0000, 0.0000, 0.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 5.0000 along (0, 0, 1) as a Subtract (Combine, Cut) from the body.
8. Cut by a swept profile. Sketch on the XY plane at Z = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 10.0000, 0.0000)
   - line from O to A = (3.0000, 10.0000, 0.0000)
   - arc centre (3.0000, 9.0000, 0.0000), radius 1, from A to B = (4.0000, 9.0000, 0.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 5.0000 along (0, 0, 1) as a Subtract (Combine, Cut) from the body.
9. Cut by a swept profile. Sketch on the XY plane at Z = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 0.0000)
   - line from O to A = (0.0000, 9.0000, 0.0000)
   - arc centre (1.0000, 9.0000, 0.0000), radius 1, from A to B = (1.0000, 10.0000, 0.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 5.0000 along (0, 0, 1) as a Subtract (Combine, Cut) from the body.
10. Cut the corner piece: make a box with opposite corners (0, 0, 5) and (1, 1, 6) as a separate body, make a sphere centre (1.0000, 1.0000, 5.0000) radius 1 as a second body, Subtract the sphere from the box (what is left is the corner cube minus the ball), then Subtract that piece from the main body.
11. Cut the corner piece: make a box with opposite corners (3, 0, 5) and (4, 1, 6) as a separate body, make a sphere centre (3.0000, 1.0000, 5.0000) radius 1 as a second body, Subtract the sphere from the box (what is left is the corner cube minus the ball), then Subtract that piece from the main body.
12. Cut the corner piece: make a box with opposite corners (3, 9, 5) and (4, 10, 6) as a separate body, make a sphere centre (3.0000, 9.0000, 5.0000) radius 1 as a second body, Subtract the sphere from the box (what is left is the corner cube minus the ball), then Subtract that piece from the main body.
13. Cut the corner piece: make a box with opposite corners (0, 9, 5) and (1, 10, 6) as a separate body, make a sphere centre (1.0000, 9.0000, 5.0000) radius 1 as a second body, Subtract the sphere from the box (what is left is the corner cube minus the ball), then Subtract that piece from the main body.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 valid, volume 229.510322 (+0.0e+00 vs reference); main (0059) valid, volume 229.510322 (+0.0e+00 vs reference); this branch (0060) valid, volume 229.510322 (+0.0e+00 vs reference); this branch with candidate 0061 valid, volume 229.510322 (+0.0e+00 vs reference); reference volume 229.510322.

### I: the four top edges (radius 1.5) and the four vertical edges (radius 1.5) of a 4 x 10 x 6 box: four corner blends

File `I2-round-1_5-1_5.png`.

Fillets, all in one operation: radius 1.5 on the edge whose middle is (2, 0, 6); radius 1.5 on the edge whose middle is (4, 5, 6); radius 1.5 on the edge whose middle is (2, 10, 6); radius 1.5 on the edge whose middle is (0, 5, 6); radius 1.5 on the edge whose middle is (0, 0, 3); radius 1.5 on the edge whose middle is (4, 0, 3); radius 1.5 on the edge whose middle is (4, 10, 3); radius 1.5 on the edge whose middle is (0, 10, 3).

Expected: As I1 with r 1.5.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 1.5000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (1.5000, 0.0000, 6.0000)
   - line from O to A = (1.5000, 1.5000, 6.0000)
   - arc centre (1.5000, 1.5000, 4.5000), radius 1.5, from A to B = (1.5000, 0.0000, 4.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 1.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 1.5000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 1.5000, 6.0000)
   - line from O to A = (2.5000, 1.5000, 6.0000)
   - arc centre (2.5000, 1.5000, 4.5000), radius 1.5, from A to B = (4.0000, 1.5000, 4.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 7.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the YZ plane at X = 2.5000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (2.5000, 10.0000, 6.0000)
   - line from O to A = (2.5000, 8.5000, 6.0000)
   - arc centre (2.5000, 8.5000, 4.5000), radius 1.5, from A to B = (2.5000, 10.0000, 4.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 1.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
5. Cut by a swept profile. Sketch on the XZ plane at Y = 8.5000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 8.5000, 6.0000)
   - line from O to A = (1.5000, 8.5000, 6.0000)
   - arc centre (1.5000, 8.5000, 4.5000), radius 1.5, from A to B = (0.0000, 8.5000, 4.5000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 7.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.
6. Cut by a swept profile. Sketch on the XY plane at Z = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 0.0000)
   - line from O to A = (1.5000, 0.0000, 0.0000)
   - arc centre (1.5000, 1.5000, 0.0000), radius 1.5, from A to B = (0.0000, 1.5000, 0.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.5000 along (0, 0, 1) as a Subtract (Combine, Cut) from the body.
7. Cut by a swept profile. Sketch on the XY plane at Z = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 0.0000, 0.0000)
   - line from O to A = (4.0000, 1.5000, 0.0000)
   - arc centre (2.5000, 1.5000, 0.0000), radius 1.5, from A to B = (2.5000, 0.0000, 0.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.5000 along (0, 0, 1) as a Subtract (Combine, Cut) from the body.
8. Cut by a swept profile. Sketch on the XY plane at Z = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 10.0000, 0.0000)
   - line from O to A = (2.5000, 10.0000, 0.0000)
   - arc centre (2.5000, 8.5000, 0.0000), radius 1.5, from A to B = (4.0000, 8.5000, 0.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.5000 along (0, 0, 1) as a Subtract (Combine, Cut) from the body.
9. Cut by a swept profile. Sketch on the XY plane at Z = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 0.0000)
   - line from O to A = (0.0000, 8.5000, 0.0000)
   - arc centre (1.5000, 8.5000, 0.0000), radius 1.5, from A to B = (1.5000, 10.0000, 0.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.5000 along (0, 0, 1) as a Subtract (Combine, Cut) from the body.
10. Cut the corner piece: make a box with opposite corners (0, 0, 4.5) and (1.5, 1.5, 6) as a separate body, make a sphere centre (1.5000, 1.5000, 4.5000) radius 1.5 as a second body, Subtract the sphere from the box (what is left is the corner cube minus the ball), then Subtract that piece from the main body.
11. Cut the corner piece: make a box with opposite corners (2.5, 0, 4.5) and (4, 1.5, 6) as a separate body, make a sphere centre (2.5000, 1.5000, 4.5000) radius 1.5 as a second body, Subtract the sphere from the box (what is left is the corner cube minus the ball), then Subtract that piece from the main body.
12. Cut the corner piece: make a box with opposite corners (2.5, 8.5, 4.5) and (4, 10, 6) as a separate body, make a sphere centre (2.5000, 8.5000, 4.5000) radius 1.5 as a second body, Subtract the sphere from the box (what is left is the corner cube minus the ball), then Subtract that piece from the main body.
13. Cut the corner piece: make a box with opposite corners (0, 8.5, 4.5) and (1.5, 10, 6) as a separate body, make a sphere centre (1.5000, 8.5000, 4.5000) radius 1.5 as a second body, Subtract the sphere from the box (what is left is the corner cube minus the ball), then Subtract that piece from the main body.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 valid, volume 217.151543 (+0.0e+00 vs reference); main (0059) valid, volume 217.151543 (+0.0e+00 vs reference); this branch (0060) valid, volume 217.151543 (+0.0e+00 vs reference); this branch with candidate 0061 valid, volume 217.151543 (+0.0e+00 vs reference); reference volume 217.151543.

### I: the four top edges (radius 2) and the four vertical edges (radius 2) of a 4 x 10 x 6 box: four corner blends

File `I3-round-2-2.png`.

Fillets, all in one operation: radius 2 on the edge whose middle is (2, 0, 6); radius 2 on the edge whose middle is (4, 5, 6); radius 2 on the edge whose middle is (2, 10, 6); radius 2 on the edge whose middle is (0, 5, 6); radius 2 on the edge whose middle is (0, 0, 3); radius 2 on the edge whose middle is (4, 0, 3); radius 2 on the edge whose middle is (4, 10, 3); radius 2 on the edge whose middle is (0, 10, 3).

Expected: r = w/2 on the 4 mm width: the ridge along Y meets the spheres; the vertical edges r 2 make the two ends full half cylinders in plan.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the XZ plane at Y = 2.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 2.0000, 6.0000)
   - line from O to A = (2.0000, 2.0000, 6.0000)
   - arc centre (2.0000, 2.0000, 4.0000), radius 2, from A to B = (4.0000, 2.0000, 4.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 6.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 8.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 8.0000, 6.0000)
   - line from O to A = (2.0000, 8.0000, 6.0000)
   - arc centre (2.0000, 8.0000, 4.0000), radius 2, from A to B = (0.0000, 8.0000, 4.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 6.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the XY plane at Z = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 0.0000)
   - line from O to A = (2.0000, 0.0000, 0.0000)
   - arc centre (2.0000, 2.0000, 0.0000), radius 2, from A to B = (0.0000, 2.0000, 0.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (0, 0, 1) as a Subtract (Combine, Cut) from the body.
5. Cut by a swept profile. Sketch on the XY plane at Z = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 0.0000, 0.0000)
   - line from O to A = (4.0000, 2.0000, 0.0000)
   - arc centre (2.0000, 2.0000, 0.0000), radius 2, from A to B = (2.0000, 0.0000, 0.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (0, 0, 1) as a Subtract (Combine, Cut) from the body.
6. Cut by a swept profile. Sketch on the XY plane at Z = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 10.0000, 0.0000)
   - line from O to A = (2.0000, 10.0000, 0.0000)
   - arc centre (2.0000, 8.0000, 0.0000), radius 2, from A to B = (4.0000, 8.0000, 0.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (0, 0, 1) as a Subtract (Combine, Cut) from the body.
7. Cut by a swept profile. Sketch on the XY plane at Z = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 0.0000)
   - line from O to A = (0.0000, 8.0000, 0.0000)
   - arc centre (2.0000, 8.0000, 0.0000), radius 2, from A to B = (2.0000, 10.0000, 0.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (0, 0, 1) as a Subtract (Combine, Cut) from the body.
8. Cut the corner piece: make a box with opposite corners (0, 0, 4) and (2, 2, 6) as a separate body, make a sphere centre (2.0000, 2.0000, 4.0000) radius 2 as a second body, Subtract the sphere from the box (what is left is the corner cube minus the ball), then Subtract that piece from the main body.
9. Cut the corner piece: make a box with opposite corners (2, 0, 4) and (4, 2, 6) as a separate body, make a sphere centre (2.0000, 2.0000, 4.0000) radius 2 as a second body, Subtract the sphere from the box (what is left is the corner cube minus the ball), then Subtract that piece from the main body.
10. Cut the corner piece: make a box with opposite corners (2, 8, 4) and (4, 10, 6) as a separate body, make a sphere centre (2.0000, 8.0000, 4.0000) radius 2 as a second body, Subtract the sphere from the box (what is left is the corner cube minus the ball), then Subtract that piece from the main body.
11. Cut the corner piece: make a box with opposite corners (0, 8, 4) and (2, 10, 6) as a separate body, make a sphere centre (2.0000, 8.0000, 4.0000) radius 2 as a second body, Subtract the sphere from the box (what is left is the corner cube minus the ball), then Subtract that piece from the main body.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 declined (IsDone false); main (0059) declined (IsDone false); this branch (0060) declined (IsDone false); this branch with candidate 0061 valid, volume 200.719755 (+0.0e+00 vs reference); reference volume 200.719755.

### I: the four top edges (radius 1) and the four vertical edges (radius 2) of a 4 x 10 x 6 box: four corner blends

File `I4-round-1-2.png` and `I4-round-1-2-decision.png`.

Fillets, all in one operation: radius 1 on the edge whose middle is (2, 0, 6); radius 1 on the edge whose middle is (4, 5, 6); radius 1 on the edge whose middle is (2, 10, 6); radius 1 on the edge whose middle is (0, 5, 6); radius 2 on the edge whose middle is (0, 0, 3); radius 2 on the edge whose middle is (4, 0, 3); radius 2 on the edge whose middle is (4, 10, 3); radius 2 on the edge whose middle is (0, 10, 3).

Expected: Unequal radii at each corner (top r 1, vertical r 2): no sphere joins them. The reference shown is the pointed intersection of the eight single-edge fillets (candidate B); candidate A is whatever blend the kernel gives. A design choice.

Shapr3D, construction of the reference (no fillet tool):

1. Base solid: sketch on the XY plane a rectangle with corners (0, 0) and (4, 10); extrude 6 along +Z.
2. Cut by a swept profile. Sketch on the YZ plane at X = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 6.0000)
   - line from O to A = (0.0000, 1.0000, 6.0000)
   - arc centre (0.0000, 1.0000, 5.0000), radius 1, from A to B = (0.0000, 0.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (1, 0, 0) as a Subtract (Combine, Cut) from the body.
3. Cut by a swept profile. Sketch on the XZ plane at Y = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 0.0000, 6.0000)
   - line from O to A = (3.0000, 0.0000, 6.0000)
   - arc centre (3.0000, 0.0000, 5.0000), radius 1, from A to B = (4.0000, 0.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, 1, 0) as a Subtract (Combine, Cut) from the body.
4. Cut by a swept profile. Sketch on the YZ plane at X = 4.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 10.0000, 6.0000)
   - line from O to A = (4.0000, 9.0000, 6.0000)
   - arc centre (4.0000, 9.0000, 5.0000), radius 1, from A to B = (4.0000, 10.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 4.0000 along (-1, 0, 0) as a Subtract (Combine, Cut) from the body.
5. Cut by a swept profile. Sketch on the XZ plane at Y = 10.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 6.0000)
   - line from O to A = (1.0000, 10.0000, 6.0000)
   - arc centre (1.0000, 10.0000, 5.0000), radius 1, from A to B = (0.0000, 10.0000, 5.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 10.0000 along (0, -1, 0) as a Subtract (Combine, Cut) from the body.
6. Cut by a swept profile. Sketch on the XY plane at Z = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 0.0000, 0.0000)
   - line from O to A = (2.0000, 0.0000, 0.0000)
   - arc centre (2.0000, 2.0000, 0.0000), radius 2, from A to B = (0.0000, 2.0000, 0.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 6.0000 along (0, 0, 1) as a Subtract (Combine, Cut) from the body.
7. Cut by a swept profile. Sketch on the XY plane at Z = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 0.0000, 0.0000)
   - line from O to A = (4.0000, 2.0000, 0.0000)
   - arc centre (2.0000, 2.0000, 0.0000), radius 2, from A to B = (2.0000, 0.0000, 0.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 6.0000 along (0, 0, 1) as a Subtract (Combine, Cut) from the body.
8. Cut by a swept profile. Sketch on the XY plane at Z = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (4.0000, 10.0000, 0.0000)
   - line from O to A = (2.0000, 10.0000, 0.0000)
   - arc centre (2.0000, 8.0000, 0.0000), radius 2, from A to B = (4.0000, 8.0000, 0.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 6.0000 along (0, 0, 1) as a Subtract (Combine, Cut) from the body.
9. Cut by a swept profile. Sketch on the XY plane at Z = 0.0000 (the plane through the corner point perpendicular to the edge), one closed profile:
   - corner point O = (0.0000, 10.0000, 0.0000)
   - line from O to A = (0.0000, 8.0000, 0.0000)
   - arc centre (2.0000, 8.0000, 0.0000), radius 2, from A to B = (2.0000, 10.0000, 0.0000), the short way round (it bulges towards O)
   - line from B back to O
   Extrude the profile 6.0000 along (0, 0, 1) as a Subtract (Combine, Cut) from the body.

Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.

Kernel results: pinned kernel.5 declined (IsDone false); main (0059) declined (IsDone false); this branch (0060) declined (IsDone false); this branch with candidate 0061 declined (IsDone false); reference volume 215.436308.

