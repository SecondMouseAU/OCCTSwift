# Fillets that meet exactly: what to look at

Box 4 x 10 x 6 mm, one corner at the origin (X = 4, Y = 10, Z = 6). Fillet the two top edges that run
along Y (at x = 0 and x = 4, top face z = 6), equal radius r. To compare in Shapr3D: sketch on the
XZ plane the rectangle 0..4 by 0..6, round the two top corners with radius r, and extrude 10 along Y; for
r > 2 the rounded corners overlap, so draw the profile as the intersection of the two rounded shapes. Its
profile top is the lower of two arcs, centres (r, 6 - r) and (4 - r, 6 - r); they meet at x = 2.

Each image has three panels. Left: end view along Y, the analytic profile dashed blue, the patched kernel's
end face solid green. Middle: the patched kernel's 3D result with edges (or the input box with the filleted
edges red if it fails). Right: the reference construction, the intersection of the box filleted on each edge
alone (not part of the patch). Chips: valid / invalid / failed, volume and difference from analytic.

| file | r | kernel.5 | patched kernel | reference | analytic volume |
| --- | --- | --- | --- | --- | --- |
| `r-1_9999.png` | 1.9999 | valid | valid, 222.833570 | valid | 222.833570 |
| `r-2_0.png` | 2.0 | IsDone false | valid, 222.831853, 7 faces, perfect semicircle | valid | 222.831853 |
| `r-2_0001.png` | 2.0001 | IsDone false | IsDone false | valid 222.830136 | 222.830136 |
| `r-2_2.png` | 2.2 | IsDone false | IsDone false | valid 219.238678 | 219.238678 |
| `r-2_5.png` | 2.5 | IsDone false | IsDone false | valid 213.342452 | 213.342452 |
| `r-3_0.png` | 3.0 | IsDone false | IsDone false | valid 202.502076 | 202.502076 |

For r above 2 the patch still answers IsDone false, on purpose: lifting the guard there gives a "done" solid of
volume 330 for a 240 box. The right panel is what it should look like, with the included angle between the arcs
(169.6 deg at 2.2, 156.9 at 2.5, 141.1 at 3.0) and the crossing height above the base (5.99, 5.95, 5.83 mm).
Volume formula: `V(r) = 240 - 10 A(r)`, `A` in `oracle.py`.
