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
