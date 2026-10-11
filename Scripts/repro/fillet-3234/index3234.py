#!/usr/bin/env python3
"""Assemble index.md for the #3234 review from render3234.py's output.

  index3234.py <outdir> <bin dir>

Reads <outdir>/_rows.pkl and _recipes.md (written by render3234.py), the cases themselves, and writes index.md: the method,
the summary table (case, rule, outcome on each kernel, classification, decision waiting), the decisions with their candidates,
and the Shapr3D recipe for every case.
"""
import os, pickle, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cases3234 as C

OUT = sys.argv[1]
rows = {s: (w, d) for s, w, d in pickle.load(open(os.path.join(OUT, "_rows.pkl"), "rb"))}
recipes = {}
for chunk in open(os.path.join(OUT, "_recipes.md")).read().split("### ")[1:]:
    title = chunk.split("\n", 1)[0]
    recipes[title] = "### " + chunk.rstrip() + "\n"

NAMES = {"k5": "kernel.5", "main": "main (0059)", "new": "branch (0060)", "62": "0062 candidate"}
GROUPS = [("E", "E: one fillet on an edge at a dihedral angle other than 90 degrees (45, 60, 120, 135), radii below, at and above the face width"),
          ("F", "F: two fillets at once on opposite edges of a face, walls at 60 and 120 degrees"),
          ("G", "G: a concave edge, the inside corner of an L, with large radii"),
          ("H", "H: curved faces: cylinder, cone, dome, washer bore, flat against a convex cylinder, flat against a concave groove")]


def cell(res, want):
    if res is None:
        return "n/a"
    if not res.get("done"):
        return "declined"
    cl = C.classify(res, want)
    return {"right": "valid, %.6f" % res["vol"], "wrong": "WRONG %.6f" % res["vol"], "INVALID": "INVALID %.4f" % res["vol"]}[cl]


def rulecase(c):
    if c.undefined:
        return "undefined"
    return "pair" if "s1" in c.info else c.info["case"]


def decisions_of(c):
    d = []
    if c.undefined:
        return ["D5"]
    if "axis" in c.tags:
        d.append("D1")
    if c.group == "H" and "axis" not in c.tags and rulecase(c) != "TT":
        d.append("D2")
    if c.group == "G" and rulecase(c) != "TT":
        d.append("D3")
    if c.group == "E" and c.fillets[0][0] >= 4.0:
        d.append("D4")
    if c.group == "F":
        d.append("D4")
    return d


counts = {v: {} for v in ("k5", "main", "new", "62")}
table = []
for c in C.CASES:
    if c.stem not in rows:
        continue
    want, data = rows[c.stem]
    if want is None:
        table.append((c, None, data, {v: ("declined" if data.get(v) and not data[v].get("done") else ("BUILT" if data.get(v) else "n/a")) for v in counts}))
        for v in counts:
            cl = table[-1][3][v]
            counts[v][cl] = counts[v].get(cl, 0) + 1
        continue
    cls = {}
    for v in counts:
        d = data.get(v)
        cl = C.classify(d, want) if d is not None else "n/a"
        cls[v] = cl
        counts[v][cl] = counts[v].get(cl, 0) + 1
    table.append((c, want, data, cls))

HEAD = """# Pivot rule beyond right-angle planar rectangles (#3234): what the kernel does, what it should do, and what waits on you

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

Across %d cases and a further 11 radius sweeps of 61 radii each, **no kernel (kernel.5, main, 0060) ever returns a wrong or an invalid
solid**. Where the fillet is tangent to both faces (TT), every kernel is right at every angle, convex or concave, for planar and curved
faces. Wherever the rule needs a pivot (a face runs out) the kernel declines, except exactly what 0060 already built (right angle between
planar rectangles, and two fillets at once, which the Common of singles builds at any angle: group F). So: **no defect that returns a
bad shape; a gap that declines.** Candidate patch **0062** (new, branch only) closes the planar part of the gap: a straight edge between two
planar rectangles at **any** angle, **convex or concave** (concave fills the corner). Curved faces stay declined; the decisions below
are why, and what each costs.

## Validation behind that paragraph

All numbers from `results/`; every kernel result below is a probe linked against the released kernel.5 with the changed translation units
of the patched tree override-linked (`build.sh`), one process per case.

- **The cases** (`cases3234.py`, `results/cases-all-variants.txt`): %d cases; for each, the rule's volume, the reference solid's volume (equal
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

""" % (len(table), len(table))


def main():
    out = [HEAD]
    out.append("## Summary\n")
    out.append("| outcome per kernel | " + " | ".join(NAMES[v] for v in counts) + " |\n|---|---|---|---|---|")
    for cl in ("right", "declined", "wrong", "INVALID"):
        out.append("| %s | " % cl + " | ".join(str(counts[v].get(cl, 0)) for v in counts) + " |")
    out.append("")
    out.append("`new` and `62` columns differ only where 0062 builds what 0060 declines. The 0062 numbers include the cases it leaves alone.\n")
    for g, gname in GROUPS:
        out.append("### " + gname + "\n")
        out.append("| case | rule | rule volume | kernel.5 | main (0059) | branch (0060) | 0062 candidate | classification (0060 / 0062) | decision |")
        out.append("|---|---|---|---|---|---|---|---|---|")
        for c, want, data, cls in table:
            if c.group != g:
                continue
            if want is None:
                out.append("| [%s](#%s) | undefined | - | %s | %s | %s | %s | %s / %s | %s |" % (
                    c.stem, c.stem.lower(), *(cell(data.get(v), 0.0).replace("n/a", "n/a") if False else ("declined" if data.get(v) and not data[v]["done"] else "BUILT") for v in ("k5", "main", "new", "62")),
                    cls["new"], cls["62"], ", ".join(decisions_of(c)) or "-"))
                continue
            out.append("| [%s](#%s) | %s | %.6f | %s | %s | %s | %s | %s / %s | %s |" % (
                c.stem, c.stem.lower(), rulecase(c), want, *(cell(data.get(v), want) for v in ("k5", "main", "new", "62")),
                cls["new"], cls["62"], ", ".join(decisions_of(c)) or "-"))
        out.append("")
    out.append(DECISIONS)
    out.append("## Recipes\n")
    out.append("Every recipe: the original body, the fillet to apply and where, and the profile the rule gives as a sketch to compare against.\n")
    for g, gname in GROUPS:
        out.append("## " + gname + "\n")
        for c, want, data, cls in table:
            if c.group == g:
                out.append("<a id=\"%s\"></a>\n" % c.stem.lower())
                out.append(recipes[c.title])
    open(os.path.join(OUT, "index.md"), "w").write("\n".join(out))


DECISIONS = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "decisions.md")).read()
main()
