# Pivot-edge fillets: what to look at, and the Shapr3D recipe for every case

Nothing here is submitted. These renders are for you to confirm the behaviour before anything goes upstream.

Every image has three panels. Left: the end view looking along Y, the ANALYTIC profile dashed blue with its circles
dotted, the tangent points (green discs), the pivots (red diamonds), the junction or crossing (blue disc), the circle
centres (blue crosses), every number listed under the panel, and the patched kernel's end face drawn over it in green.
Middle: the patched kernel's 3D result with edges drawn, or the input box with the filleted edges red if the kernel
declines. Right: the reference, the analytic section extruded (a sketch and an extrude, independent of the fillet code).
Chips: valid / declined, the volume, and the difference from the analytic volume, for this branch (patch 0060), for main
(patch 0059, kernel.5 plus the exact-meeting patch) and for the pinned kernel.5.

The rule being drawn: wherever a fillet meets a face it is filleting it is tangent to that face; where the face runs out
and there is an edge instead, the edge is the pivot and the arc passes through it. Two fillets on opposite edges at once
give the INTERSECTION of the two rounded profiles. One fillet after another differs (case D3): the first fillet's
tangent edge is the second one's pivot, so the result depends on the order.

Decisions waiting for you, all visible in the images: (1) D3 against B at r = 3: 213.81 in sequence, 202.50 at once;
(2) radii above the face width in case B (D4, and r >= 4 on the 4 mm face, which the intersection still builds, each
fillet taking its own pivot arc); (3) D2: a radius so large it is a near-flat cut through both far edges (r = 100 on a 10
cube builds, a flat-ish cut, where it used to be refused).

Coordinates: X across the top face, Y along the filleted edges, Z up; the sketch plane is XZ.

## A: r1 + r2 = w

### A: r1 + r2 = w, radii 1.5 and 2.5 on the top edges of a 4 x 10 x 6 box

File `A-1_5-2_5.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Fillets: radius 1.5 on the edge whose middle is (0, 5, 6); radius 2.5 on the edge whose middle is (4, 5, 6), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (0.0000, 4.5000).
3. Arc, centre (1.5000, 4.5000), radius 1.5, from (0.0000, 4.5000) to (1.5000, 6.0000), the short way round (it bulges towards the corner it rounds).
4. Arc, centre (1.5000, 3.5000), radius 2.5, from (1.5000, 6.0000) to (4.0000, 3.5000), the short way round (it bulges towards the corner it rounds).
5. Line to (4.0000, 0.0000).
6. Close the profile back to the start with a line, then extrude 10.

Expected: the arcs are tangent to each other at the junction (180 deg).

Check against the fillet tool: apply the same radii to the same edges of a plain box and compare the profile with the sketch above; they should coincide. Volume 221.758844 (the profile area is 22.175884).

Kernel results: pinned kernel.5 declined; main (0059) valid 221.758844; this branch (0060) valid 221.758844; reference extrusion valid 221.758844.

### A: r1 + r2 = w, radii 1 and 3 on the top edges of a 4 x 10 x 6 box

File `A-1-3.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Fillets: radius 1 on the edge whose middle is (0, 5, 6); radius 3 on the edge whose middle is (4, 5, 6), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (0.0000, 5.0000).
3. Arc, centre (1.0000, 5.0000), radius 1, from (0.0000, 5.0000) to (1.0000, 6.0000), the short way round (it bulges towards the corner it rounds).
4. Arc, centre (1.0000, 3.0000), radius 3, from (1.0000, 6.0000) to (4.0000, 3.0000), the short way round (it bulges towards the corner it rounds).
5. Line to (4.0000, 0.0000).
6. Close the profile back to the start with a line, then extrude 10.

Expected: the arcs are tangent to each other at the junction (180 deg).

Check against the fillet tool: apply the same radii to the same edges of a plain box and compare the profile with the sketch above; they should coincide. Volume 218.539816 (the profile area is 21.853982).

Kernel results: pinned kernel.5 declined; main (0059) valid 218.539816; this branch (0060) valid 218.539816; reference extrusion valid 218.539816.

### A: r1 + r2 = w, radii 2 and 2 on the top edges of a 4 x 10 x 6 box

File `A-2-2.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Fillets: radius 2 on the edge whose middle is (0, 5, 6); radius 2 on the edge whose middle is (4, 5, 6), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (0.0000, 4.0000).
3. Arc, centre (2.0000, 4.0000), radius 2, from (0.0000, 4.0000) to (2.0000, 6.0000), the short way round (it bulges towards the corner it rounds).
4. Arc, centre (2.0000, 4.0000), radius 2, from (2.0000, 6.0000) to (4.0000, 4.0000), the short way round (it bulges towards the corner it rounds).
5. Line to (4.0000, 0.0000).
6. Close the profile back to the start with a line, then extrude 10.

Expected: the arcs are tangent to each other at the junction (180 deg).

Check against the fillet tool: apply the same radii to the same edges of a plain box and compare the profile with the sketch above; they should coincide. Volume 222.831853 (the profile area is 22.283185).

Kernel results: pinned kernel.5 declined; main (0059) valid 222.831853; this branch (0060) valid 222.831853; reference extrusion valid 222.831853.

## B: r1 + r2 > w

### B: r1 + r2 > w, equal radii 2.2 on the top edges of a 4 x 10 x 6 box

File `B-equal-2_2.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Fillets: radius 2.2 on the edge whose middle is (0, 5, 6); radius 2.2 on the edge whose middle is (4, 5, 6), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (0.0000, 3.8000).
3. Arc, centre (2.2000, 3.8000), radius 2.2, from (0.0000, 3.8000) to (2.0000, 5.9909), the short way round (it bulges towards the corner it rounds).
4. Arc, centre (1.8000, 3.8000), radius 2.2, from (2.0000, 5.9909) to (4.0000, 3.8000), the short way round (it bulges towards the corner it rounds).
5. Line to (4.0000, 0.0000).
6. Close the profile back to the start with a line, then extrude 10.

Expected: the arcs cross; 169.57 deg between them (included, through the material).

Check against the fillet tool: apply the same radii to the same edges of a plain box and compare the profile with the sketch above; they should coincide. Volume 219.238679 (the profile area is 21.923868).

Kernel results: pinned kernel.5 declined; main (0059) declined; this branch (0060) valid 219.238678; reference extrusion valid 219.238678.

### B: r1 + r2 > w, equal radii 2.5 on the top edges of a 4 x 10 x 6 box

File `B-equal-2_5.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Fillets: radius 2.5 on the edge whose middle is (0, 5, 6); radius 2.5 on the edge whose middle is (4, 5, 6), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (0.0000, 3.5000).
3. Arc, centre (2.5000, 3.5000), radius 2.5, from (0.0000, 3.5000) to (2.0000, 5.9495), the short way round (it bulges towards the corner it rounds).
4. Arc, centre (1.5000, 3.5000), radius 2.5, from (2.0000, 5.9495) to (4.0000, 3.5000), the short way round (it bulges towards the corner it rounds).
5. Line to (4.0000, 0.0000).
6. Close the profile back to the start with a line, then extrude 10.

Expected: the arcs cross; 156.93 deg between them (included, through the material).

Check against the fillet tool: apply the same radii to the same edges of a plain box and compare the profile with the sketch above; they should coincide. Volume 213.342452 (the profile area is 21.334245).

Kernel results: pinned kernel.5 declined; main (0059) declined; this branch (0060) valid 213.342452; reference extrusion valid 213.342452.

### B: r1 + r2 > w, equal radii 3 on the top edges of a 4 x 10 x 6 box

File `B-equal-3.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Fillets: radius 3 on the edge whose middle is (0, 5, 6); radius 3 on the edge whose middle is (4, 5, 6), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (0.0000, 3.0000).
3. Arc, centre (3.0000, 3.0000), radius 3, from (0.0000, 3.0000) to (2.0000, 5.8284), the short way round (it bulges towards the corner it rounds).
4. Arc, centre (1.0000, 3.0000), radius 3, from (2.0000, 5.8284) to (4.0000, 3.0000), the short way round (it bulges towards the corner it rounds).
5. Line to (4.0000, 0.0000).
6. Close the profile back to the start with a line, then extrude 10.

Expected: the arcs cross; 141.06 deg between them (included, through the material).

Check against the fillet tool: apply the same radii to the same edges of a plain box and compare the profile with the sketch above; they should coincide. Volume 202.502076 (the profile area is 20.250208).

Kernel results: pinned kernel.5 declined; main (0059) declined; this branch (0060) valid 202.502076; reference extrusion valid 202.502076.

### B: r1 + r2 > w, equal radii 3.5 on the top edges of a 4 x 10 x 6 box

File `B-equal-3_5.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Fillets: radius 3.5 on the edge whose middle is (0, 5, 6); radius 3.5 on the edge whose middle is (4, 5, 6), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (0.0000, 2.5000).
3. Arc, centre (3.5000, 2.5000), radius 3.5, from (0.0000, 2.5000) to (2.0000, 5.6623), the short way round (it bulges towards the corner it rounds).
4. Arc, centre (0.5000, 2.5000), radius 3.5, from (2.0000, 5.6623) to (4.0000, 2.5000), the short way round (it bulges towards the corner it rounds).
5. Line to (4.0000, 0.0000).
6. Close the profile back to the start with a line, then extrude 10.

Expected: the arcs cross; 129.25 deg between them (included, through the material).

Check against the fillet tool: apply the same radii to the same edges of a plain box and compare the profile with the sketch above; they should coincide. Volume 190.731782 (the profile area is 19.073178).

Kernel results: pinned kernel.5 declined; main (0059) declined; this branch (0060) valid 190.731782; reference extrusion valid 190.731782.

### B: r1 + r2 > w, radii 2 and 2.5 on the top edges of a 4 x 10 x 6 box

File `B-unequal-2-2_5.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Fillets: radius 2 on the edge whose middle is (0, 5, 6); radius 2.5 on the edge whose middle is (4, 5, 6), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (0.0000, 4.0000).
3. Arc, centre (2.0000, 4.0000), radius 2, from (0.0000, 4.0000) to (1.7640, 5.9860), the short way round (it bulges towards the corner it rounds).
4. Arc, centre (1.5000, 3.5000), radius 2.5, from (1.7640, 5.9860) to (4.0000, 3.5000), the short way round (it bulges towards the corner it rounds).
5. Line to (4.0000, 0.0000).
6. Close the profile back to the start with a line, then extrude 10.

Expected: the arcs cross; 167.16 deg between them (included, through the material).

Check against the fillet tool: apply the same radii to the same edges of a plain box and compare the profile with the sketch above; they should coincide. Volume 218.026575 (the profile area is 21.802658).

Kernel results: pinned kernel.5 declined; main (0059) declined; this branch (0060) valid 218.026575; reference extrusion valid 218.026575.

### B: r1 + r2 > w, radii 1 and 3.5 on the top edges of a 4 x 10 x 6 box

File `B-unequal-1-3_5.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Fillets: radius 1 on the edge whose middle is (0, 5, 6); radius 3.5 on the edge whose middle is (4, 5, 6), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (0.0000, 5.0000).
3. Arc, centre (1.0000, 5.0000), radius 1, from (0.0000, 5.0000) to (0.8261, 5.9848), the short way round (it bulges towards the corner it rounds).
4. Arc, centre (0.5000, 2.5000), radius 3.5, from (0.8261, 5.9848) to (4.0000, 2.5000), the short way round (it bulges towards the corner it rounds).
5. Line to (4.0000, 0.0000).
6. Close the profile back to the start with a line, then extrude 10.

Expected: the arcs cross; 164.64 deg between them (included, through the material).

Check against the fillet tool: apply the same radii to the same edges of a plain box and compare the profile with the sketch above; they should coincide. Volume 211.590597 (the profile area is 21.159060).

Kernel results: pinned kernel.5 declined; main (0059) declined; this branch (0060) valid 211.590597; reference extrusion valid 211.590597.

### B: r1 + r2 > w, radii 2.5 and 3 on the top edges of a 4 x 10 x 6 box

File `B-unequal-2_5-3.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Fillets: radius 2.5 on the edge whose middle is (0, 5, 6); radius 3 on the edge whose middle is (4, 5, 6), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (0.0000, 3.5000).
3. Arc, centre (2.5000, 3.5000), radius 2.5, from (0.0000, 3.5000) to (1.7848, 5.8955), the short way round (it bulges towards the corner it rounds).
4. Arc, centre (1.0000, 3.0000), radius 3, from (1.7848, 5.8955) to (4.0000, 3.0000), the short way round (it bulges towards the corner it rounds).
5. Line to (4.0000, 0.0000).
6. Close the profile back to the start with a line, then extrude 10.

Expected: the arcs cross; 148.21 deg between them (included, through the material).

Check against the fillet tool: apply the same radii to the same edges of a plain box and compare the profile with the sketch above; they should coincide. Volume 207.791557 (the profile area is 20.779156).

Kernel results: pinned kernel.5 declined; main (0059) declined; this branch (0060) valid 207.791557; reference extrusion valid 207.791557.

## C: one fillet wider than its face

### C: ONE fillet of radius 4 on the 4 mm wide top face of a 4 x 10 x 6 box

File `C-single-4.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Fillets: radius 4 on the edge whose middle is (0, 5, 6), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (0.0000, 2.0000).
3. Arc, centre (4.0000, 2.0000), radius 4, from (0.0000, 2.0000) to (4.0000, 6.0000), the short way round (it bulges towards the corner it rounds).
4. Line to (4.0000, 0.0000).
5. Close the profile back to the start with a line, then extrude 10.

Expected: r = w: the arc ends on the far edge, tangent to the top face as well.

Check against the fillet tool: apply the same radii to the same edges of a plain box and compare the profile with the sketch above; they should coincide. Volume 205.663706 (the profile area is 20.566371).

Kernel results: pinned kernel.5 declined; main (0059) declined; this branch (0060) valid 205.663706; reference extrusion valid 205.663706.

### C: ONE fillet of radius 4.5 on the 4 mm wide top face of a 4 x 10 x 6 box

File `C-single-4_5.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Fillets: radius 4.5 on the edge whose middle is (0, 5, 6), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (0.0000, 1.5279).
3. Arc, centre (4.5000, 1.5279), radius 4.5, from (0.0000, 1.5279) to (4.0000, 6.0000), the short way round (it bulges towards the corner it rounds).
4. Line to (4.0000, 0.0000).
5. Close the profile back to the start with a line, then extrude 10.

Expected: meets the far wall at 83.62 deg (interior), not tangent.

Check against the fillet tool: apply the same radii to the same edges of a plain box and compare the profile with the sketch above; they should coincide. Volume 197.704072 (the profile area is 19.770407).

Kernel results: pinned kernel.5 declined; main (0059) declined; this branch (0060) valid 197.704072; reference extrusion valid 197.704072.

### C: ONE fillet of radius 5 on the 4 mm wide top face of a 4 x 10 x 6 box

File `C-single-5.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Fillets: radius 5 on the edge whose middle is (0, 5, 6), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (0.0000, 1.1010).
3. Arc, centre (5.0000, 1.1010), radius 5, from (0.0000, 1.1010) to (4.0000, 6.0000), the short way round (it bulges towards the corner it rounds).
4. Line to (4.0000, 0.0000).
5. Close the profile back to the start with a line, then extrude 10.

Expected: meets the far wall at 78.46 deg (interior), not tangent.

Check against the fillet tool: apply the same radii to the same edges of a plain box and compare the profile with the sketch above; they should coincide. Volume 190.725724 (the profile area is 19.072572).

Kernel results: pinned kernel.5 declined; main (0059) declined; this branch (0060) valid 190.725724; reference extrusion valid 190.725724.

### C: ONE fillet of radius 6 on the 4 mm wide top face of a 4 x 10 x 6 box

File `C-single-6.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Fillets: radius 6 on the edge whose middle is (0, 5, 6), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (0.0000, 0.3431).
3. Arc, centre (6.0000, 0.3431), radius 6, from (0.0000, 0.3431) to (4.0000, 6.0000), the short way round (it bulges towards the corner it rounds).
4. Line to (4.0000, 0.0000).
5. Close the profile back to the start with a line, then extrude 10.

Expected: meets the far wall at 70.53 deg (interior), not tangent.

Check against the fillet tool: apply the same radii to the same edges of a plain box and compare the profile with the sketch above; they should coincide. Volume 178.729983 (the profile area is 17.872998).

Kernel results: pinned kernel.5 declined; main (0059) declined; this branch (0060) valid 178.729983; reference extrusion valid 178.729983.

## D: other configurations the same rule covers

### D1: radius 4 on the edge of a 3 mm thick plate (10 x 10 x 3): the bottom edge is the pivot

File `D1-plate-4.png`. Box 10 x 10 x 3 (X x Y x Z), one corner at the origin, top face Z = 3. Fillets: radius 4 on the edge whose middle is (0, 5, 3), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (0.0000, 0.0000).
3. Arc, centre (3.8730, -1.0000), radius 4, from (0.0000, 0.0000) to (3.8730, 3.0000), the short way round (it bulges towards the corner it rounds).
4. Line to (10.0000, 3.0000).
5. Line to (10.0000, 0.0000).
6. Close the profile back to the start with a line, then extrude 10.

Expected: meets the bottom face at 75.52 deg (interior), not tangent.

Check against the fillet tool: apply the same radii to the same edges of a plain box and compare the profile with the sketch above; they should coincide. Volume 269.894869 (the profile area is 26.989487).

Kernel results: pinned kernel.5 declined; main (0059) declined; this branch (0060) valid 269.894869; reference extrusion valid 269.894869.

### D2: radius 4.5 on a 4 x 10 x 3 box: both far edges are pivots

File `D2-both-4_5.png`. Box 4 x 10 x 3 (X x Y x Z), one corner at the origin, top face Z = 3. Fillets: radius 4.5 on the edge whose middle is (0, 5, 3), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (0.0000, 0.0000).
3. Arc, centre (4.2450, -1.4933), radius 4.5, from (0.0000, 0.0000) to (4.0000, 3.0000), the short way round (it bulges towards the corner it rounds).
4. Line to (4.0000, 0.0000).
5. Close the profile back to the start with a line, then extrude 10.

Expected: tangent to neither face: 86.88 deg to the far wall, 70.62 deg to the bottom.

Check against the fillet tool: apply the same radii to the same edges of a plain box and compare the profile with the sketch above; they should coincide. Volume 85.737337 (the profile area is 8.573734).

Kernel results: pinned kernel.5 declined; main (0059) declined; this branch (0060) valid 85.737337; reference extrusion valid 85.737337.

### D3: radius 3, THEN radius 3, on the top edges of a 4 x 10 x 6 box (one after the other)

File `D3-seq-3-3.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Fillets: radius 3 on the edge whose middle is (0, 5, 6); radius 3 on the edge whose middle is (4, 5, 6), one after the other in that order.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (0.0000, 3.0000).
3. Arc, centre (3.0000, 3.0000), radius 3, from (0.0000, 3.0000) to (3.0000, 6.0000), the short way round (it bulges towards the corner it rounds).
4. Arc, centre (1.0000, 3.7639), radius 3, from (3.0000, 6.0000) to (4.0000, 3.7639), the short way round (it bulges towards the corner it rounds).
5. Line to (4.0000, 0.0000).
6. Close the profile back to the start with a line, then extrude 10.

Expected: the second arc leaves the first fillet's tangent edge at 138.19 deg to the top plane.

Check against the fillet tool: apply the same radii to the same edges of a plain box and compare the profile with the sketch above; they should coincide. Volume 213.812565 (the profile area is 21.381257).

Kernel results: pinned kernel.5 declined; main (0059) declined; this branch (0060) valid 213.812565; reference extrusion valid 213.812565.

### D4: radii 7.5 on both edges of the 10 mm wide top face of a 10 x 4 x 6 box (7.5 > the 6 mm wall)

File `D4-pair-7_5.png`. Box 10 x 4 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Fillets: radius 7.5 on the edge whose middle is (0, 2, 6); radius 7.5 on the edge whose middle is (10, 2, 6), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 4 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (0.0000, 0.0000).
3. Arc, centre (7.3485, -1.5000), radius 7.5, from (0.0000, 0.0000) to (5.0000, 5.6228), the short way round (it bulges towards the corner it rounds).
4. Arc, centre (2.6515, -1.5000), radius 7.5, from (5.0000, 5.6228) to (10.0000, 0.0000), the short way round (it bulges towards the corner it rounds).
5. Line to (10.0000, 0.0000).
6. Close the profile back to the start with a line, then extrude 4.

Expected: the arcs cross; 143.50 deg between them (included, through the material).

Check against the fillet tool: apply the same radii to the same edges of a plain box and compare the profile with the sketch above; they should coincide. Volume 153.644087 (the profile area is 38.411022).

Kernel results: pinned kernel.5 declined; main (0059) declined; this branch (0060) valid 153.644087; reference extrusion valid 153.644087.

