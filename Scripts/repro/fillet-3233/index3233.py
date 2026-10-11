#!/usr/bin/env python3
"""index.md and table.tsv for the #3233 review set.
  index3233.py <review dir> <measure.json> <bin dir>"""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import render3233 as RR
import cases3233 as C
import steps3233 as ST
import measure as M

out, mj, bindir = sys.argv[1:4]
res = json.load(open(mj))


def vol(r, key):
    k = r.get(key, {}).get("kernel")
    return k


def outcome(r, key):
    x = r.get(key, {})
    k = x.get("kernel")
    if not k:
        return "hang before an answer" if x.get("timeout") else "no output"
    if not k["done"]:
        return "declined (IsDone false)"
    if not k["valid"]:
        return "DONE BUT INVALID (BRepCheck false, %d free edge(s), volume %.3g)" % (k["free"], k["vol"])
    ref = r["ref"]["ref"]["vol"]
    return "valid, volume %.6f (%+.1e vs reference)" % (k["vol"], k["vol"] - ref)


def classify(case, r):
    """(classification on this branch, outcome with the candidate, decision text)"""
    k = r["new"].get("kernel")
    k61 = r["p61"].get("kernel")
    ref = r["ref"]["ref"]["vol"]

    def right(x): return x and x["done"] and x["valid"] and abs(x["vol"] - ref) < 1e-5 * max(1.0, ref)
    if case.decision:
        base = "decision" + (" (kernel valid today)" if k and k["done"] and k["valid"] else " (kernel declines)" if k and not k["done"] else " (kernel hands back an open shell)")
        return base
    if right(k):
        return "already right"
    if k and not k["done"]:
        return "declined"
    return "wrong (done but invalid)"


DECISIONS = {
    "F4-corner-unequal": "D2", "I4-round-1-2": "D2", "F5-corner-4_5": "D3",
    "H1-L-1": "D1", "H4-U-1": "D1", "H2-L-1_5": "D1", "H3-L-2": "D1", "H5-U-1_5": "D1", "H6-L-3_5": "D1",
}

groups = [("E", "E: two adjacent edges at a box corner"), ("F", "F: all three edges at a box corner"), ("G", "G: a full top frame (four edges)"),
          ("H", "H: the whole top contour of an L-shaped and a U-shaped extrusion"), ("I", "I: the convex top edges plus the vertical edges, with the corner blends")]

lines = []
w = lines.append
w("# Fillet contours that share a vertex (#3233): expected geometry, what the kernel does, and the Shapr3D recipe for every case")
w("")
w("Nothing here is submitted. Branch `fix/fillet-3233-corners` (from `fix/fillet-pivot-edges`, patches 0059 and 0060), candidate patch 0061, no PR.")
w("")
w("## How to read the images")
w("")
w("The rule being drawn (yours, from #3208): wherever a fillet meets a face it is filleting it is tangent to that face; where the face runs out and there is an edge instead, the edge is the pivot and the arc passes through it. r1 + r2 = w: tangent arcs. r1 + r2 > w: the arcs cross at an included angle below 180 degrees. Two fillets on opposite edges at once give the INTERSECTION of the two rounded profiles. Read at a shared vertex: where two fillets meet at a convex corner whose third edge is not filleted, the result is the intersection of the two surfaces (that is what the kernel already does for small radii, cases E1 to E3 and G1); where three equal fillets meet at a convex corner it is a ball of that radius (F1 to F3, I1, I2).")
w("")
w("Every case has one main image `<case>.png`, 1560 x 1200, three rows of three panels:")
w("")
w("- Row 1: the analytic end view (a section across one edge away from the corner: arcs dashed blue, circles dotted, tangent points green discs, pivots red diamonds, junction or crossing blue disc, circle centres blue crosses, the kernel's own slice of its result drawn over it in green) | the kernel result, oblique, from outside the corner | the reference, oblique.")
w("- Row 2: what the rule expects in words and the section numbers | the kernel result from above with the reference's edges dashed blue over it | the reference from above (zoomed to the corner for the corner cases).")
w("- Row 3: chips for this branch plus candidate 0061, this branch (0060), main (0059) and the pinned kernel.5 (green = same solid as the reference, amber = valid but different, red = declined or invalid) | corner close-up of the kernel result | corner close-up of the reference.")
w("")
w("The REFERENCE is built with no fillet code: the base solid (a sketch and an extrude) minus removal prisms (the analytic corner profile swept along each edge, a sketch and an extrude) and, at ball corners, a cube minus a sphere. At a reflex corner the reference is one of three candidates; see the decision images (`<case>-decision.png`). `cdump.cxx` builds it, `cases3233.py` writes the removal items.")
w("")
w("Where the kernel returns a solid the image shows the branch with candidate 0061 when it differs from 0060, else 0060. The pinned kernel.5 is the v4.0.0-kernel.5 release asset; main is kernel.5 plus patch 0059; this branch is main plus patch 0060; candidate 0061 sits on top of this branch. `occtBlendResultIsValid` (#3200) is not on this branch, so the verdict here is BRepCheck_Analyzer, one solid, and every edge on two faces; a solid with a free edge fails it.")
w("")
w("Coordinates: X across the box, Y along it, Z up, one corner at the origin. Boxes are 4 x 10 x 6 unless the case says otherwise. Shapr3D steps below use absolute coordinates; \"Subtract\" means Combine, Cut with the swept body or corner piece as the tool.")
w("")

# summary table
w("## Summary")
w("")
w("Classification is for this branch (0060). \"With 0061\" is the candidate patch. A decision is geometry the rule does not fix.")
w("")
w("| case | configuration | expected | this branch (0060) | classification | with candidate 0061 | decision |")
w("| --- | --- | --- | --- | --- | --- | --- |")
tsv = ["case\tgroup\ttitle\tkernel5\tmain_0059\tbranch_0060\tcandidate_0061\treference_volume\tclassification\tdecision"]
rows = []
def natkey(c):
    import re
    return (c.group, [int(t) if t.isdigit() else t for t in re.split(r'(\d+)', c.stem)])
CASES = sorted(C.CASES, key=natkey)
for c in CASES:
    r = res[c.stem]
    cl = classify(c, r)
    d = DECISIONS.get(c.stem, "")
    short = c.title.split(":", 1)[1].strip()
    exp = "reference %.4f" % r["ref"]["ref"]["vol"] if not c.decision else ("candidates, see %s" % d)
    w("| [%s](%s.png) | %s | %s | %s | %s | %s | %s |" % (c.stem, c.stem, short, exp, outcome(r, "new"), cl, outcome(r, "p61"), ("[%s](#decisions-waiting-for-you)" % d) if d else ""))
    tsv.append("\t".join([c.stem, c.group, c.title, outcome(r, "k5"), outcome(r, "main"), outcome(r, "new"), outcome(r, "p61"), "%.6f" % r["ref"]["ref"]["vol"], cl, d]))
open(os.path.join(out, "table.tsv"), "w").write("\n".join(tsv) + "\n")
w("")

# decisions
w("## Decisions waiting for you")
w("")
h1, h4 = res["H1-L-1"], res["H4-U-1"]
def kv(r, key="new"): return r[key]["kernel"]["vol"]
w("**D1. The reflex (inside) corner of an L or U extrusion, where two filleted top edges meet at a concave vertical edge.** The two fillets do not overlap there, so \"intersection\" does not say what to build in the 90 degree square where they would meet. Three outcomes, all valid solids, drawn side by side in `H1-L-1-decision.png` and `H4-U-1-decision.png`:")
w("")
w("- A, what the kernel gives today: a smooth blend patch. L (r = 1): volume %.4f. U: %.4f." % (kv(h1), kv(h4)))
w("- B, mitre: each fillet runs r past the vertex and the two meet in the diagonal (a ridge, the union of what the two fillets remove). L: %.4f. U: %.4f." % (h1["alt"]["ref"]["vol"], h4["alt"]["ref"]["vol"]))
w("- C, rolling ball: the vertical edge is the pivot and the profile is revolved 90 degrees round it (a horn torus patch, tangent to the top face and to both walls). L: %.4f. U: %.4f. By your rule this is the one that reads the edge as a pivot; A differs from it by %.4f (L)." % (h1["ref"]["ref"]["vol"], h4["ref"]["ref"]["vol"], h1["ref"]["ref"]["vol"] - kv(h1)))
w("")
w("The other L and U cases (H2, H3, H5, H6: r = w/2, r above w/2, r above the arm width) wait on this: the kernel declines H2, H5, H6 and hands back an open shell for H3, none of which candidate 0061 changes. The reference in those images is C.")
w("")
f4, i4, f5 = res["F4-corner-unequal"], res["I4-round-1-2"], res["F5-corner-4_5"]
w("**D2. Unequal radii at a vertex of three filleted edges** (F4: 1, 2, 1.5; I4: top 1, vertical 2). No ball joins three cylinders of different radii. Candidate A is a smooth vertex blend, which is what the kernel builds for F4 (volume %.4f); for I4 the kernel declines. Candidate B is the intersection of the three single-edge fillets, a pointed corner (F4 volume %.4f, I4 volume %.4f). Images `F4-corner-unequal-decision.png`, `I4-round-1-2-decision.png`." % (kv(f4), f4["ref"]["ref"]["vol"], i4["ref"]["ref"]["vol"]))
w("")
w("**D3. A vertex of three filleted edges where a radius runs past a face** (F5: r = 4.5 on a 4 mm wide face). No ball of that radius fits the corner. The only outcome the rule defines directly is B, the intersection of the three pivot fillets (volume %.4f, pointed corner); the other outcome is to keep declining. Image `F5-corner-4_5-decision.png`." % f5["ref"]["ref"]["vol"])
w("")
h3 = res["H3-L-2"]
w("**D4. An open result.** On a frame with crossing arcs (G3, G4, G5, G9, G10) and on H3 the stripe builder answers IsDone true with a shell that has free edges (4 or 6 of them, volumes from 229 to 3.5e29 against boxes of 240 to 800), and the tessellator then never returns. Candidate 0061 replaces the open result where its construction applies (all of G). Where it does not apply (H3, reflex corner) it leaves the open result as it is. Do you want IsDone false there instead? That is a behaviour change for every multi-contour caller; I did not make it.")
w("")
w("**Assumption to confirm, not a choice.** E4 to E6 and G6, G8, G10 read the rule at a shared convex vertex as the intersection of the surfaces of the two fillets (a mitre), including when one of them pivots at a far edge. That extends your statement from opposite edges to adjacent ones; it is what the kernel already does for small radii.")
w("")

# per case
for gkey, gname in groups:
    w("## " + gname)
    w("")
    for c in [x for x in CASES if x.group == gkey]:
        r = res[c.stem]
        w("### " + c.title)
        w("")
        w("File `%s.png`%s." % (c.stem, (" and `%s-decision.png`" % c.stem) if c.decision else ""))
        w("")
        w("Fillets, all in one operation: " + "; ".join("radius %g on the edge whose middle is (%s)" % (q, ", ".join("%g" % x for x in m)) for q, m in c.edges) + ".")
        w("")
        w("Expected: " + c.expect)
        w("")
        w("Shapr3D, construction of the reference (no fillet tool):")
        w("")
        for ln in ST.steps(c, RR.R):
            w(ln if ln.startswith("   ") or ln == "" or ln[0].isdigit() else ln)
        w("")
        if c.decision and c.kind == "poly":
            w("Candidate B instead (mitre): the same, but every band runs %g past each reflex vertex instead of stopping at it, and the revolved pieces are left out." % c.edges[0][0])
            w("")
        w("Check against the fillet tool: apply the same radii to the same edges of the plain solid and compare.")
        w("")
        w("Kernel results: pinned kernel.5 %s; main (0059) %s; this branch (0060) %s; this branch with candidate 0061 %s; reference volume %.6f." % (outcome(r, "k5"), outcome(r, "main"), outcome(r, "new"), outcome(r, "p61"), r["ref"]["ref"]["vol"]))
        w("")

open(os.path.join(out, "index.md"), "w").write("\n".join(lines) + "\n")
print("wrote index.md,", len(lines), "lines")
