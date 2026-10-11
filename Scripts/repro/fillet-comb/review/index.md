# Fillet and chamfer comb: summary, decisions, and the chamfer parity set

Nothing here is submitted: no PR, nothing posted upstream. Branch `fix/fillet-comb-chamfer` (from `fix/fillet-pivot-edges`, merged with `origin/main` for the #3200 guard and the kernel.6 pin). Kernels measured: pinned kernel.6 (carries 0059, not 0060), kernel.6 + 0060 (the pivot branch), kernel.6 + 0060 + candidate 0063 in three readings. Method: `Scripts/repro/fillet-comb/` (raw-OCCT probe `cprobe`, independent reference volumes in `comb_oracle.py`, sweep, Swift cross-check through the public API and the #3200 guard).

## One page: the failure classes

1828 sweep cases, every one a separate process with a 60 s timeout: **no hang and no crash anywhere**. Inside the unambiguous regime (every blended edge keeps both its faces, no two share one) the kernel is exact: 0 wrong volumes against the independent reference except the silent no-op below, over boxes of five aspect ratios, cylinders, a plate with a hole, L and U extrusions. Everything that fails sits at an exact tie (r or d equal to w or w/2) or past the face. Outcome counts, kernel.6 / +0060 / +0063: valid and matching 635 / 707 / 728, valid without a reference 209 / 235 / 257, declined 936 / 838 / 795, done-but-invalid (guard answers nil) 45 / 45 / 45, valid but wrong 3 / 3 / 3.

1828 cases (box x5 aspect ratios, cylinder, plate with hole, L and U extrusions, the #2881 model), radii and distances 0.1 to 5 x the smallest face width, fillet and chamfer (symmetric and two-distance). Class assigned on kernel.6 + 0060 (the branch); the other columns count the same class on pinned kernel.6 and on kernel.6 + 0060 + 0063 (decline reading). `cprobe` is `Scripts/repro/fillet-comb/cprobe.cxx`; box specs are corner-origin boxes, edges named by bounding-box centre.

| rank | failure class | tracked | kernel.6 | + 0060 | + 0063 | smallest reproducer |
|---|---|---|---|---|---|---|
| 1 | Done and valid, but returned the unchanged input (chamfer of all edges of a cube at d = edge/2) | NEW #3297 | 1 | 1 | 1 | `cprobe run box:10,10,10 chamfer_all 5` (Swift: `Shape.box(width: 10, height: 10, depth: 10)!.chamfered(distance: 5)`) |
| 2 | Done and valid, but two solids and twice the volume (both rims of a cylinder, r = R = H/2) | NEW #3298 | 2 | 2 | 2 | `cprobe run cyl:5,10 fillet 5.0 0,0,10 0,0,0` |
| 3 | The vertex-snap window of the #2881 model: done but BRepCheck-invalid for 7 radii, declined for 4 more | tracked #3209 | 11 | 11 | 11 | `cprobe run brep:model2881.brep fillet 1.4983 -0,0,20` |
| 4 | Done but invalid: a frame of chamfers at d = w/2 (guard answers nil); declined on other sizes by edge order | NEW #3299 / #3300 | 4 | 4 | 4 | `cprobe run box:10,10,10 chamfer2m 5.0:2.5:5,0,10@5,5,10 5.0:2.5:5,10,10@5,5,10 5.0:2.5:0,5,10@5,5,10 5.0:2.5:10,5,10@5,5,10` |
| 5 | Done but invalid: chamfers past the face on curved faces and extrusions (cylinder rim d > R, L/U vertical edge d past the arm, hole rims) | NEW, under #3300 / #3234 | 9 | 9 | 9 | `cprobe run cyl:5,10 chamfer_sym 5.5 0,0,10` |
| 6 | Done but invalid: fillets that overlap on a shared face past w/2 (frames, all edges, outlines, hole rims) | tracked #3200 (guard), #3234 beyond boxes | 25 | 25 | 25 | `cprobe run plate:20,20,4,3 fillet 2.4 10,10,4 10,10,0` |
| 7 | Declined at every radius on 22 of the 41 edges of the #2881 model (radius independent: tangent or seam edges, untriaged) | untriaged (not a radius defect) | 133 | 133 | 133 | `cprobe run brep:model2881.brep fillet 0.3 -45.25,1.5,10` |
| 8 | Declined at an exact tie: chamfer distance = face width, or two chamfers whose cuts meet (d = w/2) | NEW #3300 (0063 builds the single-contour ones) | 48 | 48 | 27 | `cprobe run box:10,10,10 chamfer2m 10.0:5.0:0,5,10@5,5,10` |
| 9 | Declined at an exact tie with contours that share a vertex (frames, adjacent edges, corners) | tracked #3207 / #3233, order dependent #3299 | 18 | 18 | 18 | `cprobe run box:10,10,10 fillet 10.0 0,5,10 5,0,10` |
| 10 | Declined at an exact tie on curved faces, concave edges and extrusions (r = w or w/2) | tracked #3207 / #3234 | 21 | 8 | 8 | `cprobe run plate:20,20,4,3 fillet 4.0 10,10,4` |
| 11 | Declined past the face (chamfer distance beyond its face, or cuts crossing; includes shared-vertex frames) | NEW #3300 (design choice: pivot, half-space or decline) | 420 | 420 | 398 | `cprobe run box:10,10,10 chamfer2m 11.0:5.5:0,5,10@5,5,10` |
| 12 | Declined past w/2 or w with contours that share a vertex | tracked #3233 / #3235 | 108 | 108 | 108 | `cprobe run box:10,10,10 fillet 11.0 0,5,10 5,0,10` |
| 13 | Declined past the face on curved faces, concave edges and extrusions | tracked #3234 | 184 | 99 | 99 | `cprobe run cyl:5,10 fillet 5.5 0,0,10` |


Three results worth reading first: (1) **#3297 and #3298 are the only wrong answers that the #3200 guard passes**, because they are BRepCheck-valid: an unchanged cube from `chamfered(distance: 5)`, and two solids with twice the volume from both rims of a cylinder at r = R = H/2. The guard needs a solid-count check and a "removed material" bound, or those cases need declining. (2) **#3299: at an exact tie the order the edges are added decides** whether a frame builds; away from a tie it never does (8 random orders per cell). (3) Chamfers are declined wherever a distance reaches its face, #3300, which patch 0063 addresses.

Conventions found, not defects, no reference claimed: a corner of three equal chamfers is closed by a triangular face through the three mitre ends (d^3/12 more than three planes meeting in a point, measured per vertex); at a re-entrant plan corner of an extrusion whose whole top outline is blended, the kernel's corner matches none of three reasonable readings (two strips, a patch around the vertex, two extended strips), so those cases carry no reference. Neither is filed.

Swift cross-check: 1032 cases (every unambiguous one, every done-but-invalid one, 250 others) go through `Shape.filleted`, `chamferedTwoDistances`, `chamfered(distance:)` with the guard; 1028 agree with the raw probe; the 4 that disagree are the edge-order ties of #3299.

## Decisions for the maintainer

1. **What a chamfer distance that exceeds its face means** (#3300). Three candidates, each drawn in the DECISION images (`T-5_2.png`, `S-sym-4p5.png`, `D-seq-3.png`, `A-5_30.png` and the others of the 14): PIVOT (the cut passes through the far edge, keeps the distance that fits, order dependent in sequence, the fillet rule's analogue); HALF-SPACE (the plane through the two distances, extended and clipped by the box, order independent); or keep declining. 0063 compiles all three behind `BRepFilletAPI_CHAMFER_RUNOUT` (default 0 = decline) and builds exactly the cases where the readings agree in every setting.
2. **Both at once versus one after the other for chamfers** (cf. #3237): pivot makes `D-seq-3` (3 then 3) 180, half-space makes it 160 and equal to both at once.
3. **Exact ties** (d or r equal to w or w/2): should the answer be the built shape in all subsets (frames included) or a refusal? Today it is order dependent (#3299).
4. **The guard** (#3297, #3298): extend `occtBlendResultIsValid` with one-solid and a removed-material bound?

## Chamfer parity set

Each image has the end-view profile with both candidates, the kernel's result, the independent reference (sketch + extrude), and chips. Table of all 42 cases: `chamfer-table.tsv`. Also here: `sweep-K60.csv`, `sweep-K6-pinned.csv`, `sweep-K63-0.csv` (full sweep, one row per case), `sweep-table.md`, `order-dependence.tsv`, `swift-crosscheck.csv`.

Nothing here is submitted. Companion to the fillet pivot-edge review; the chamfer analogue of the same rule.

Every image: the end view looking along Y with the analytic profile dashed (blue, and orange where a second reading exists), the points
where a cut meets a face (green discs), a hollow ring where a reading puts the cut end outside the face, a red diamond where a reading
ends the cut at the far edge of a face (the pivot), the kernel's end face drawn over it in green; the kernel's 3D result; the reference,
the profile sketched and extruded (a sketch and an extrude, independent of the chamfer code). Chips: valid / declined, the volume, and
the difference from the analytic one, for the pinned kernel.6 and for kernel.6 plus the candidate patch 0063.

Coordinates: X across the top face (4 wide), Y along the edges (10), Z up (6). The first distance of a two-distance chamfer is
measured on the top face, the second on the wall, unless the case says the wall is the reference face. Distance and angle: the
distance is on the top face and the angle is between the chamfer and the top face, so the wall distance is d tan(angle), which the
valid cases confirm.

The two readings of a distance that runs past its face (cases where both are drawn):

- PIVOT (blue): the face ends at its far edge, the cut line passes through that edge and keeps the distance that fits. The analogue of
  the fillet rule, and order dependent when two chamfers are applied one after the other.
- HALF-SPACE (orange): the cut is the plane through the two distances, extended past the face and clipped by the box. Order does not
  matter.
- Or keep declining (the pinned kernel's behaviour).

Where nothing runs past a face the answer is one shape, and the pinned kernel declines it whenever a distance EQUALS its face or two
cuts meet or cross on the face (the analogue of OCCT#1177 for chamfers). Those are the cases patch 0063 builds in every reading.

## S: one symmetric chamfer on one top edge

### S: ONE symmetric chamfer, distance 1, on the left top edge of a 4 x 10 x 6 box

File `S-sym-1.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 1 on the top face and 1 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (1.0000, 6.0000).
5. Line to (0.0000, 5.0000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 235.000000 (the profile area is 23.500000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 valid 235.000000; kernel.6 + 0063 valid 235.000000; reference extrusion valid 235.000000.

### S: ONE symmetric chamfer, distance 2, on the left top edge of a 4 x 10 x 6 box

File `S-sym-2.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 2 on the top face and 2 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (2.0000, 6.0000).
5. Line to (0.0000, 4.0000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 220.000000 (the profile area is 22.000000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 valid 220.000000; kernel.6 + 0063 valid 220.000000; reference extrusion valid 220.000000.

### S: ONE symmetric chamfer, distance 3.9, on the left top edge of a 4 x 10 x 6 box

File `S-sym-3p9.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 3.9 on the top face and 3.9 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (3.9000, 6.0000).
5. Line to (0.0000, 2.1000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 163.950000 (the profile area is 16.395000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 valid 163.950000; kernel.6 + 0063 valid 163.950000; reference extrusion valid 163.950000.

### S: ONE symmetric chamfer, distance 4, on the left top edge of a 4 x 10 x 6 box

File `S-sym-4.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 4 on the top face and 4 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (0.0000, 2.0000).
5. Close the profile back to the start with a line, then extrude 10.

Volume 160.000000 (the profile area is 16.000000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; kernel.6 + 0063 valid 160.000000; reference extrusion valid 160.000000.

### S: ONE symmetric chamfer, distance 4.5, on the left top edge of a 4 x 10 x 6 box

File `S-sym-4p5.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 4.5 on the top face and 4.5 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction (pivot reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (0.0000, 1.5000).
5. Close the profile back to the start with a line, then extrude 10.

Volume 150.000000 (the profile area is 15.000000).

Shapr3D, construction (half-space reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 5.5000).
4. Line to (0.0000, 1.5000).
5. Close the profile back to the start with a line, then extrude 10.

Volume 140.000000 (the profile area is 14.000000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; 0063 with the runout declined declined; 0063 pivot reading valid 150.000000 (expected 150.000000); 0063 half-space reading valid 140.000000 (expected 140.000000).

### S: ONE symmetric chamfer, distance 5.9, on the left top edge of a 4 x 10 x 6 box

File `S-sym-5p9.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 5.9 on the top face and 5.9 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction (pivot reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (0.0000, 0.1000).
5. Close the profile back to the start with a line, then extrude 10.

Volume 122.000000 (the profile area is 12.200000).

Shapr3D, construction (half-space reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 4.1000).
4. Line to (0.0000, 0.1000).
5. Close the profile back to the start with a line, then extrude 10.

Volume 84.000000 (the profile area is 8.400000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; 0063 with the runout declined declined; 0063 pivot reading valid 122.000000 (expected 122.000000); 0063 half-space reading valid 84.000000 (expected 84.000000).

### S: ONE symmetric chamfer, distance 6, on the left top edge of a 4 x 10 x 6 box

File `S-sym-6.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 6 on the top face and 6 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction (pivot reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Close the profile back to the start with a line, then extrude 10.

Volume 120.000000 (the profile area is 12.000000).

Shapr3D, construction (half-space reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 4.0000).
4. Close the profile back to the start with a line, then extrude 10.

Volume 80.000000 (the profile area is 8.000000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; 0063 with the runout declined declined; 0063 pivot reading valid 120.000000 (expected 120.000000); 0063 half-space reading valid 80.000000 (expected 80.000000).

### S: ONE symmetric chamfer, distance 7, on the left top edge of a 4 x 10 x 6 box

File `S-sym-7.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 7 on the top face and 7 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction (pivot reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Close the profile back to the start with a line, then extrude 10.

Volume 120.000000 (the profile area is 12.000000).

Shapr3D, construction (half-space reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (1.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 3.0000).
4. Close the profile back to the start with a line, then extrude 10.

Volume 45.000000 (the profile area is 4.500000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; 0063 with the runout declined declined; 0063 pivot reading valid 120.000000 (expected 120.000000); 0063 half-space reading valid 45.000000 (expected 45.000000).

## T: one chamfer with two distances (first distance on the top face)

### T: ONE chamfer, 1 on the top face and 3 on the left wall, left top edge of a 4 x 10 x 6 box

File `T-1_3.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 1 on the top face and 3 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (1.0000, 6.0000).
5. Line to (0.0000, 3.0000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 225.000000 (the profile area is 22.500000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 valid 225.000000; kernel.6 + 0063 valid 225.000000; reference extrusion valid 225.000000.

### T: ONE chamfer, 3 on the top face and 1 on the left wall, left top edge of a 4 x 10 x 6 box

File `T-3_1.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 3 on the top face and 1 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (3.0000, 6.0000).
5. Line to (0.0000, 5.0000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 225.000000 (the profile area is 22.500000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 valid 225.000000; kernel.6 + 0063 valid 225.000000; reference extrusion valid 225.000000.

### T: ONE chamfer, 3.9 on the top face and 2 on the left wall, left top edge of a 4 x 10 x 6 box

File `T-3p9_2.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 3.9 on the top face and 2 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (3.9000, 6.0000).
5. Line to (0.0000, 4.0000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 201.000000 (the profile area is 20.100000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 valid 201.000000; kernel.6 + 0063 valid 201.000000; reference extrusion valid 201.000000.

### T: ONE chamfer, 4 on the top face and 2 on the left wall, left top edge of a 4 x 10 x 6 box

File `T-4_2.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 4 on the top face and 2 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (0.0000, 4.0000).
5. Close the profile back to the start with a line, then extrude 10.

Volume 200.000000 (the profile area is 20.000000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; kernel.6 + 0063 valid 200.000000; reference extrusion valid 200.000000.

### T: ONE chamfer, 5 on the top face and 2 on the left wall, left top edge of a 4 x 10 x 6 box

File `T-5_2.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 5 on the top face and 2 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction (pivot reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (0.0000, 4.0000).
5. Close the profile back to the start with a line, then extrude 10.

Volume 200.000000 (the profile area is 20.000000).

Shapr3D, construction (half-space reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 5.6000).
4. Line to (0.0000, 4.0000).
5. Close the profile back to the start with a line, then extrude 10.

Volume 192.000000 (the profile area is 19.200000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; 0063 with the runout declined declined; 0063 pivot reading valid 200.000000 (expected 200.000000); 0063 half-space reading valid 192.000000 (expected 192.000000).

### T: ONE chamfer, 2 on the top face and 5.9 on the left wall, left top edge of a 4 x 10 x 6 box

File `T-2_5p9.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 2 on the top face and 5.9 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (2.0000, 6.0000).
5. Line to (0.0000, 0.1000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 181.000000 (the profile area is 18.100000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 valid 181.000000; kernel.6 + 0063 valid 181.000000; reference extrusion valid 181.000000.

### T: ONE chamfer, 2 on the top face and 6 on the left wall, left top edge of a 4 x 10 x 6 box

File `T-2_6.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 2 on the top face and 6 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (2.0000, 6.0000).
5. Close the profile back to the start with a line, then extrude 10.

Volume 180.000000 (the profile area is 18.000000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; kernel.6 + 0063 valid 180.000000; reference extrusion valid 180.000000.

### T: ONE chamfer, 2 on the top face and 7 on the left wall, left top edge of a 4 x 10 x 6 box

File `T-2_7.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 2 on the top face and 7 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction (pivot reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (2.0000, 6.0000).
5. Close the profile back to the start with a line, then extrude 10.

Volume 180.000000 (the profile area is 18.000000).

Shapr3D, construction (half-space reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.2857, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (2.0000, 6.0000).
5. Close the profile back to the start with a line, then extrude 10.

Volume 171.428571 (the profile area is 17.142857).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; 0063 with the runout declined declined; 0063 pivot reading valid 180.000000 (expected 180.000000); 0063 half-space reading valid 171.428571 (expected 171.428571).

### T: ONE chamfer, 5 on the top face and 7 on the left wall, left top edge of a 4 x 10 x 6 box

File `T-5_7.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 5 on the top face and 7 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction (pivot reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Close the profile back to the start with a line, then extrude 10.

Volume 120.000000 (the profile area is 12.000000).

Shapr3D, construction (half-space reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.7143, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 4.6000).
4. Close the profile back to the start with a line, then extrude 10.

Volume 75.571429 (the profile area is 7.557143).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; 0063 with the runout declined declined; 0063 pivot reading valid 120.000000 (expected 120.000000); 0063 half-space reading valid 75.571429 (expected 75.571429).

## W: the reference face is the WALL

### W: ONE chamfer, reference face = the left WALL: 2 on the wall and 5 on the top, left top edge

File `W-2_5.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 5 on the top face and 2 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction (pivot reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (0.0000, 4.0000).
5. Close the profile back to the start with a line, then extrude 10.

Volume 200.000000 (the profile area is 20.000000).

Shapr3D, construction (half-space reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 5.6000).
4. Line to (0.0000, 4.0000).
5. Close the profile back to the start with a line, then extrude 10.

Volume 192.000000 (the profile area is 19.200000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; 0063 with the runout declined declined; 0063 pivot reading valid 200.000000 (expected 200.000000); 0063 half-space reading valid 192.000000 (expected 192.000000).

### W: ONE chamfer, reference face = the left WALL: 5 on the wall and 2 on the top, left top edge

File `W-5_2.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 2 on the top face and 5 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (2.0000, 6.0000).
5. Line to (0.0000, 1.0000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 190.000000 (the profile area is 19.000000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 valid 190.000000; kernel.6 + 0063 valid 190.000000; reference extrusion valid 190.000000.

## B: both top edges in one operation

### B: BOTH top edges at once, 1 on the top face and 1 on each wall, 4 x 10 x 6 box

File `B-sym-1.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 1 on the top face and 1 on the left wall, on the left top edge (middle (0, 5, 6)); 1 on the top face and 1 on the right wall, on the right top edge (middle (4, 5, 6)), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 5.0000).
4. Line to (3.0000, 6.0000).
5. Line to (1.0000, 6.0000).
6. Line to (0.0000, 5.0000).
7. Close the profile back to the start with a line, then extrude 10.

Volume 230.000000 (the profile area is 23.000000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 valid 230.000000; kernel.6 + 0063 valid 230.000000; reference extrusion valid 230.000000.

### B: BOTH top edges at once, 1.9 on the top face and 1.9 on each wall, 4 x 10 x 6 box

File `B-sym-1p9.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 1.9 on the top face and 1.9 on the left wall, on the left top edge (middle (0, 5, 6)); 1.9 on the top face and 1.9 on the right wall, on the right top edge (middle (4, 5, 6)), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 4.1000).
4. Line to (2.1000, 6.0000).
5. Line to (1.9000, 6.0000).
6. Line to (0.0000, 4.1000).
7. Close the profile back to the start with a line, then extrude 10.

Volume 203.900000 (the profile area is 20.390000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 valid 203.900000; kernel.6 + 0063 valid 203.900000; reference extrusion valid 203.900000.

### B: BOTH top edges at once, 2 on the top face and 2 on each wall, 4 x 10 x 6 box

File `B-sym-2.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 2 on the top face and 2 on the left wall, on the left top edge (middle (0, 5, 6)); 2 on the top face and 2 on the right wall, on the right top edge (middle (4, 5, 6)), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 4.0000).
4. Line to (2.0000, 6.0000).
5. Line to (0.0000, 4.0000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 200.000000 (the profile area is 20.000000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; kernel.6 + 0063 valid 200.000000; reference extrusion valid 200.000000.

### B: BOTH top edges at once, 2.1 on the top face and 2.1 on each wall, 4 x 10 x 6 box

File `B-sym-2p1.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 2.1 on the top face and 2.1 on the left wall, on the left top edge (middle (0, 5, 6)); 2.1 on the top face and 2.1 on the right wall, on the right top edge (middle (4, 5, 6)), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 3.9000).
4. Line to (2.0000, 5.9000).
5. Line to (0.0000, 3.9000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 196.000000 (the profile area is 19.600000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; kernel.6 + 0063 valid 196.000000; reference extrusion valid 196.000000.

### B: BOTH top edges at once, 3 on the top face and 3 on each wall, 4 x 10 x 6 box

File `B-sym-3.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 3 on the top face and 3 on the left wall, on the left top edge (middle (0, 5, 6)); 3 on the top face and 3 on the right wall, on the right top edge (middle (4, 5, 6)), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 3.0000).
4. Line to (2.0000, 5.0000).
5. Line to (0.0000, 3.0000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 160.000000 (the profile area is 16.000000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; kernel.6 + 0063 valid 160.000000; reference extrusion valid 160.000000.

### B: BOTH top edges at once, 3.9 on the top face and 3.9 on each wall, 4 x 10 x 6 box

File `B-sym-3p9.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 3.9 on the top face and 3.9 on the left wall, on the left top edge (middle (0, 5, 6)); 3.9 on the top face and 3.9 on the right wall, on the right top edge (middle (4, 5, 6)), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 2.1000).
4. Line to (2.0000, 4.1000).
5. Line to (0.0000, 2.1000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 124.000000 (the profile area is 12.400000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; kernel.6 + 0063 valid 124.000000; reference extrusion valid 124.000000.

### B: BOTH top edges at once, 4.5 on the top face and 4.5 on each wall, 4 x 10 x 6 box

File `B-sym-4p5.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 4.5 on the top face and 4.5 on the left wall, on the left top edge (middle (0, 5, 6)); 4.5 on the top face and 4.5 on the right wall, on the right top edge (middle (4, 5, 6)), all in one operation.

Shapr3D, construction (pivot reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 1.5000).
4. Line to (2.0000, 3.7500).
5. Line to (0.0000, 1.5000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 105.000000 (the profile area is 10.500000).

Shapr3D, construction (half-space reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 1.5000).
4. Line to (2.0000, 3.5000).
5. Line to (0.0000, 1.5000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 100.000000 (the profile area is 10.000000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; 0063 with the runout declined declined; 0063 pivot reading valid 105.000000 (expected 105.000000); 0063 half-space reading valid 100.000000 (expected 100.000000).

### B: BOTH top edges at once, left (1 on top, 3 on the wall), right (3 on top, 1 on the wall)

File `B-asym-1_3-3_1.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 1 on the top face and 3 on the left wall, on the left top edge (middle (0, 5, 6)); 3 on the top face and 1 on the right wall, on the right top edge (middle (4, 5, 6)), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 5.0000).
4. Line to (1.0000, 6.0000).
5. Line to (0.0000, 3.0000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 210.000000 (the profile area is 21.000000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; kernel.6 + 0063 valid 210.000000; reference extrusion valid 210.000000.

### B: BOTH top edges at once, left (1, 3), right (2, 2)

File `B-asym-1_3-2_2.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 1 on the top face and 3 on the left wall, on the left top edge (middle (0, 5, 6)); 2 on the top face and 2 on the right wall, on the right top edge (middle (4, 5, 6)), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 4.0000).
4. Line to (2.0000, 6.0000).
5. Line to (1.0000, 6.0000).
6. Line to (0.0000, 3.0000).
7. Close the profile back to the start with a line, then extrude 10.

Volume 205.000000 (the profile area is 20.500000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 valid 205.000000; kernel.6 + 0063 valid 205.000000; reference extrusion valid 205.000000.

### B: BOTH top edges at once, each (3 on top, 2 on the wall): the cuts cross

File `B-asym-3_2-3_2.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 3 on the top face and 2 on the left wall, on the left top edge (middle (0, 5, 6)); 3 on the top face and 2 on the right wall, on the right top edge (middle (4, 5, 6)), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 4.0000).
4. Line to (2.0000, 5.3333).
5. Line to (0.0000, 4.0000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 186.666667 (the profile area is 18.666667).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; kernel.6 + 0063 valid 186.666667; reference extrusion valid 186.666667.

### B: BOTH top edges at once, each (5 on top, 2 on the wall): each runs past the far edge

File `B-sym-5-2.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 5 on the top face and 2 on the left wall, on the left top edge (middle (0, 5, 6)); 5 on the top face and 2 on the right wall, on the right top edge (middle (4, 5, 6)), all in one operation.

Shapr3D, construction (pivot reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 4.0000).
4. Line to (2.0000, 5.0000).
5. Line to (0.0000, 4.0000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 180.000000 (the profile area is 18.000000).

Shapr3D, construction (half-space reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 4.0000).
4. Line to (2.0000, 4.8000).
5. Line to (0.0000, 4.0000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 176.000000 (the profile area is 17.600000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; 0063 with the runout declined declined; 0063 pivot reading valid 180.000000 (expected 180.000000); 0063 half-space reading valid 176.000000 (expected 176.000000).

## D: one after the other

### D: 1.5 then 1.5, left top edge then right, one after the other (symmetric distances)

File `D-seq-1p5.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 1.5 on the top face and 1.5 on the left wall, on the left top edge (middle (0, 5, 6)); 1.5 on the top face and 1.5 on the right wall, on the right top edge (middle (4, 5, 6)), one after the other in that order.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 4.5000).
4. Line to (2.5000, 6.0000).
5. Line to (1.5000, 6.0000).
6. Line to (0.0000, 4.5000).
7. Close the profile back to the start with a line, then extrude 10.

Volume 217.500000 (the profile area is 21.750000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 valid 217.500000; kernel.6 + 0063 valid 217.500000; reference extrusion valid 217.500000.

### D: 2 then 2, left top edge then right, one after the other (symmetric distances)

File `D-seq-2.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 2 on the top face and 2 on the left wall, on the left top edge (middle (0, 5, 6)); 2 on the top face and 2 on the right wall, on the right top edge (middle (4, 5, 6)), one after the other in that order.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 4.0000).
4. Line to (2.0000, 6.0000).
5. Line to (0.0000, 4.0000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 200.000000 (the profile area is 20.000000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; kernel.6 + 0063 valid 200.000000; reference extrusion valid 200.000000.

### D: 3 then 3, left top edge then right, one after the other (symmetric distances)

File `D-seq-3.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 3 on the top face and 3 on the left wall, on the left top edge (middle (0, 5, 6)); 3 on the top face and 3 on the right wall, on the right top edge (middle (4, 5, 6)), one after the other in that order.

Shapr3D, construction (pivot reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 3.0000).
4. Line to (3.0000, 6.0000).
5. Line to (0.0000, 3.0000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 180.000000 (the profile area is 18.000000).

Shapr3D, construction (half-space reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 3.0000).
4. Line to (2.0000, 5.0000).
5. Line to (0.0000, 3.0000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 160.000000 (the profile area is 16.000000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; 0063 with the runout declined declined; 0063 pivot reading valid 180.000000 (expected 180.000000); 0063 half-space reading valid 160.000000 (expected 160.000000).

## A: distance and angle

### A: distance 2 on the top face and 20 degrees, left top edge (the wall distance is 0.7279)

File `A-2_20.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 2 on the top face and 0.72794 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (2.0000, 6.0000).
5. Line to (0.0000, 5.2721).
6. Close the profile back to the start with a line, then extrude 10.

Volume 232.720595 (the profile area is 23.272060).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 valid 232.720595; kernel.6 + 0063 valid 232.720595; reference extrusion valid 232.720595.

### A: distance 2 on the top face and 30 degrees, left top edge (the wall distance is 1.1547)

File `A-2_30.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 2 on the top face and 1.1547 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (2.0000, 6.0000).
5. Line to (0.0000, 4.8453).
6. Close the profile back to the start with a line, then extrude 10.

Volume 228.452995 (the profile area is 22.845299).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 valid 228.452995; kernel.6 + 0063 valid 228.452995; reference extrusion valid 228.452995.

### A: distance 2 on the top face and 45 degrees, left top edge (the wall distance is 2.0000)

File `A-2_45.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 2 on the top face and 2 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (2.0000, 6.0000).
5. Line to (0.0000, 4.0000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 220.000000 (the profile area is 22.000000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 valid 220.000000; kernel.6 + 0063 valid 220.000000; reference extrusion valid 220.000000.

### A: distance 2 on the top face and 60 degrees, left top edge (the wall distance is 3.4641)

File `A-2_60.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 2 on the top face and 3.4641 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (2.0000, 6.0000).
5. Line to (0.0000, 2.5359).
6. Close the profile back to the start with a line, then extrude 10.

Volume 205.358984 (the profile area is 20.535898).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 valid 205.358984; kernel.6 + 0063 valid 205.358984; reference extrusion valid 205.358984.

### A: distance 2 on the top face and 75 degrees, left top edge (the wall distance is 7.4641)

File `A-2_75.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 2 on the top face and 7.4641 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction (pivot reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (2.0000, 6.0000).
5. Close the profile back to the start with a line, then extrude 10.

Volume 180.000000 (the profile area is 18.000000).

Shapr3D, construction (half-space reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.3923, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (2.0000, 6.0000).
5. Close the profile back to the start with a line, then extrude 10.

Volume 168.230855 (the profile area is 16.823085).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; 0063 with the runout declined declined; 0063 pivot reading valid 180.000000 (expected 180.000000); 0063 half-space reading valid 168.230855 (expected 168.230855).

### A: distance 3.9 on the top face and 30 degrees, left top edge (the wall distance is 2.2517)

File `A-3p9_30.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 3.9 on the top face and 2.25167 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (3.9000, 6.0000).
5. Line to (0.0000, 3.7483).
6. Close the profile back to the start with a line, then extrude 10.

Volume 196.092512 (the profile area is 19.609251).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 valid 196.092512; kernel.6 + 0063 valid 196.092512; reference extrusion valid 196.092512.

### A: distance 5 on the top face and 30 degrees, left top edge (the wall distance is 2.8868)

File `A-5_30.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 5 on the top face and 2.88675 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction (pivot reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (0.0000, 3.1132).
5. Close the profile back to the start with a line, then extrude 10.

Volume 182.264973 (the profile area is 18.226497).

Shapr3D, construction (half-space reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 5.4226).
4. Line to (0.0000, 3.1132).
5. Close the profile back to the start with a line, then extrude 10.

Volume 170.717968 (the profile area is 17.071797).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; 0063 with the runout declined declined; 0063 pivot reading valid 182.264973 (expected 182.264973); 0063 half-space reading valid 170.717968 (expected 170.717968).

### A: distance 2 on the top face and 80 degrees, left top edge (the wall distance is 11.3426)

File `A-2_80.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 2 on the top face and 11.3426 on the left wall, on the left top edge (middle (0, 5, 6)).

Shapr3D, construction (pivot reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (2.0000, 6.0000).
5. Close the profile back to the start with a line, then extrude 10.

Volume 180.000000 (the profile area is 18.000000).

Shapr3D, construction (half-space reading): sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.9420, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 6.0000).
4. Line to (2.0000, 6.0000).
5. Close the profile back to the start with a line, then extrude 10.

Volume 151.738857 (the profile area is 15.173886).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; 0063 with the runout declined declined; 0063 pivot reading valid 180.000000 (expected 180.000000); 0063 half-space reading valid 151.738857 (expected 151.738857).

### A: BOTH top edges at once, distance 2.1 and 45 degrees each

File `A-both-2p1-45.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: 2.1 on the top face and 2.1 on the left wall, on the left top edge (middle (0, 5, 6)); 2.1 on the top face and 2.1 on the right wall, on the right top edge (middle (4, 5, 6)), all in one operation.

Shapr3D, construction: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:

1. Start at (0.0000, 0.0000).
2. Line to (4.0000, 0.0000).
3. Line to (4.0000, 3.9000).
4. Line to (2.0000, 5.9000).
5. Line to (0.0000, 3.9000).
6. Close the profile back to the start with a line, then extrude 10.

Volume 196.000000 (the profile area is 19.600000).

Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.

Kernel results: pinned kernel.6 declined; kernel.6 + 0063 valid 196.000000; reference extrusion valid 196.000000.

