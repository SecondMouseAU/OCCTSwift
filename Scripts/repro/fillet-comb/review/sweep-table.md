# Sweep table: failure classes ranked

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

## Counts per outcome class

| class | kernel.6 | + 0060 | + 0063 (decline) |
|---|---|---|---|
| OK | 635 | 707 | 728 |
| OK-unref | 209 | 235 | 257 |
| DECLINED | 936 | 838 | 795 |
| INVALID | 45 | 45 | 45 |
| WRONG-VOL | 1 | 1 | 1 |
| SANITY | 2 | 2 | 2 |
| TIMEOUT | 0 | 0 | 0 |
| SIGNAL | 0 | 0 | 0 |
| NORESULT | 0 | 0 | 0 |

No case hung or crashed (timeout 60 s per case, one process each). Outcome classes: OK valid and equal to the reference; OK-unref valid with no reference (policy region, or no oracle); DECLINED IsDone false; INVALID done but BRepCheck-invalid (the guard answers nil); WRONG-VOL / SANITY done and valid but wrong.
