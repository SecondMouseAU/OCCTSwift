#!/usr/bin/env python3
"""One figure per design decision: the chosen behaviour and the alternatives, each drawn as the analytic section
extruded (what each rule would produce), with its volume.

  render_alternatives.py <outdir> <meshdump_any>
"""
import sys, os, subprocess, math
OUT, MD = sys.argv[1:3]
sys.argv = [sys.argv[0], OUT, "-", "-", "-"]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render as R
from render import PAL, text, chip, Panel, solid

class Alt:
    def __init__(self, title, rule, geo=None, box=None, edges=None, chosen=False, note=""):
        self.title, self.rule, self.geo, self.box, self.edges, self.chosen, self.note = title, rule, geo, box, edges, chosen, note

def cell(alt, x0, w, H):
    el = []
    top = 70
    pn = Panel(x0, top, w, 250)
    el.append(f'<rect x="{x0}" y="{top}" width="{w}" height="{H - top - 20}" rx="8" fill="{"#eef7f1" if alt.chosen else "#f7f8fa"}" stroke="{PAL["ok"] if alt.chosen else "#d5dbe5"}" stroke-width="{2.5 if alt.chosen else 1}"/>')
    el.append(text(x0 + w / 2, top + 24, alt.title + ("  (CHOSEN)" if alt.chosen else ""), 14, PAL["ok"] if alt.chosen else PAL["ink"], "bold"))
    pn = Panel(x0, top + 30, w, 250)
    vol = None
    if alt.geo is not None:
        wd, L, h = alt.box
        res = R.dump(MD, ["profile", repr(L)] + sum([( ["S", repr(s[1][0]), repr(s[1][1])] if s[0] == "S" else ["L", repr(s[1][0]), repr(s[1][1])] if s[0] == "L" else ["A", repr(s[1][0]), repr(s[1][1]), repr(s[2][0]), repr(s[2][1])]) for s in alt.geo.path], []))
        if res:
            el += solid(pn, res)
            vol = res["vol"]
    else:
        el += R.input_box(pn, alt.box, [m for _, m in alt.edges])
    lab = ("volume %.6f" % vol) if vol is not None else "IsDone false: nothing is built"
    el.append(chip(x0 + w / 2, top + 310, w - 40, lab, PAL["ok"] if vol is not None else PAL["fail"]))
    for i, line in enumerate(alt.rule):
        el.append(text(x0 + 14, top + 345 + 17 * i, line, 12, PAL["ink"], "normal", "start"))
    return el

def figure(stem, title, subtitle, alts):
    n = len(alts)
    Wd = 40 + n * 420
    Hd = 520
    el = [text(Wd / 2, 32, title, 19, weight="bold"), text(Wd / 2, 54, subtitle, 13, PAL["mute"])]
    for i, a in enumerate(alts):
        el += cell(a, 20 + i * 420, 400, Hd)
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{Wd}" height="{Hd}"><rect width="{Wd}" height="{Hd}" fill="#fff"/>{"".join(el)}</svg>'
    p = os.path.join(OUT, stem + ".svg")
    open(p, "w").write(svg)
    subprocess.run(["rsvg-convert", "-o", p[:-4] + ".png", p], check=True)

W, LEN, H = 4.0, 10.0, 6.0
L_, R_ = (0, 5, 6), (4, 5, 6)
B1 = (W, LEN, H)
os.makedirs(OUT, exist_ok=True)

# Q1: opposite fillets whose radii add up to more than the face (3 and 3 on 4)
figure("Q1-opposite-radii-past-the-face", "Q1: two fillets on opposite edges, radii 3 and 3 on a 4 wide face (r1 + r2 > w)",
       "what the rule gives and what the alternatives would give; every volume is the analytic section extruded",
       [Alt("A. intersection of the rounded profiles", ["each arc tangent to its wall; the arcs cross on the face", "between them (141 deg). Order does not matter.", "Same rule as r1 + r2 = w, continuous in r."],
            R.build_add(W, H, 3, 3), B1, chosen=True),
        Alt("B. decline (what 8.0.1 does)", ["IsDone false. Safe, and the caller can retry", "with a smaller radius. Discontinuous: r = 2 builds,", "r = 2.001 does not."], None, B1, [(3, L_), (3, R_)]),
        Alt("C. clamp the radii to fit (2 and 2)", ["both radii scaled so that r1 + r2 = w: a smooth", "top, but not the radius that was asked for;", "the result no longer depends on what was typed."],
            R.build_add(W, H, 2, 2), B1),
        Alt("D. first radius wins (3, then 1)", ["the second radius is cut to what is left (w - r1).", "Depends on the order the edges were added."],
            R.build_add(W, H, 3, 1), B1)])
# Q2: order
figure("Q2-order-dependence", "Q2: radius 3 on both edges of a 4 wide face: at once or one after the other",
       "an existing fillet is part of the shape the next fillet sees, so a sequence cannot equal a single operation",
       [Alt("A. at once = intersection (CHOSEN for one operation)", ["both fillets in one BRepFilletAPI_MakeFillet:", "the intersection of the two rounded profiles."], R.build_add(W, H, 3, 3), B1, chosen=True),
        Alt("B. one after the other (the result of the rule)", ["the first fillet's tangent edge is the second one's", "pivot: the second arc leaves it at 138 deg.", "Same rule, applied to a different shape."], R.build_seq(W, H, 3, 3), B1, chosen=True,
            note="the pivot rule applied to the shape the second fillet sees"),
        Alt("C. make both equal: decline the sequence", ["refuse the second fillet when it runs past the first", "fillet's tangent edge. Order independent by", "construction, at the cost of IsDone false."], None, B1, [(3, R_)])])
# Q3: single fillet wider than its face
figure("Q3-single-radius-past-the-face", "Q3: ONE fillet of radius 5 on the 4 wide top face of a 4 x 10 x 6 box",
       "the far edge of the face is the pivot: the arc stays tangent to the wall and passes through it",
       [Alt("A. pivot at the far edge", ["tangent to the left wall, through the far edge of", "the top face. Continuous: r = 4 is tangent to both,", "r = 4.5, 5, 6 pivot at the same edge."], R.build_single(W, H, 5), B1, chosen=True),
        Alt("B. decline (8.0.1)", ["IsDone false for any r > w."], None, B1, [(5, L_)]),
        Alt("C. clamp to the face (r = 4)", ["the largest radius that fits both faces. Returns", "a different radius from the one asked for."], R.build_single(W, H, 4), B1)])
# Q4: huge radius
figure("Q4-huge-radius", "Q4: radius 100 on a 10 cube edge: a near flat cut through both far edges",
       "the pivot rule is defined for every r above half the chord; as r grows the arc tends to the chord",
       [Alt("A. pivot through both far edges", ["builds; the arc is almost the chord through the", "two far edges. Continuous in r."], R.build_single(10.0, 10.0, 100.0), (10.0, 10.0, 10.0), chosen=True),
        Alt("B. decline above a cap (r > the diagonal)", ["IsDone false: a radius of 100 on a 10 mm cube", "is more likely a typo than an intent."], None, (10.0, 10.0, 10.0), [(100, (0, 5, 10))]),
        Alt("C. clamp to the face (r = 10)", ["a quarter circle ending on both far edges."], R.build_single(10.0, 10.0, 10.0), (10.0, 10.0, 10.0))])
# Q5: both radii past their wall
figure("Q5-both-past-their-wall", "Q5: radii 7.5 on both edges of a 10 wide face over a 6 high wall",
       "each fillet runs past the wall: its pivot is the bottom edge; at once the two pivot results intersect",
       [Alt("A. intersection of the two pivot results", ["each fillet takes its own pivot arc (through the", "bottom edge of its wall); the arcs cross at 143.5 deg."], R.build_add(10.0, 6.0, 7.5, 7.5), (10.0, 4.0, 6.0), chosen=True),
        Alt("B. decline", ["IsDone false (8.0.1, and IR before this series)."], None, (10.0, 4.0, 6.0), [(7.5, (0, 2, 6)), (7.5, (10, 2, 6))]),
        Alt("C. clamp to the wall (6 and 6)", ["smaller radii that fit the wall; the arcs still cross."], R.build_add(10.0, 6.0, 6.0, 6.0), (10.0, 4.0, 6.0))])
# Q6: ties
figure("Q6-exact-ties", "Q6: exact ties: r1 + r2 = w (2 and 2 on 4) and r = w (4 on 4)",
       "an exact tie is not a special case of the rule: the arcs are tangent, and the result is a perfect semicircle or quarter",
       [Alt("A. r1 + r2 = w: tangent arcs", ["the top is two quarter circles, tangent at the", "middle. IR builds this already (#1449)."], R.build_add(W, H, 2, 2), B1, chosen=True),
        Alt("B. r = w: tangent to both faces", ["the arc ends on the far edge, tangent to the top", "face there as well."], R.build_single(W, H, 4), B1, chosen=True),
        Alt("C. refuse ties, build ties of a hair either side", ["what 8.0.1 does: 1.99999999 builds, 2 does not,", "2.00000001 does not. A tie is not noise."], None, B1, [(2, L_), (2, R_)])])
print("done")
