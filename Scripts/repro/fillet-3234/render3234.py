#!/usr/bin/env python3
"""Review renders for #3234 (the pivot rule beyond right-angle planar rectangles), SVG then PNG (rsvg-convert), index.md, table.tsv.

  render3234.py <outdir> <bin dir> [stem ...]

Same visual language as ../fillet-pivot-edges/render.py (whose Panel, solid shading and chip helpers this imports), three panels per case:
left the section (the RULE's profile dashed blue with its circles dotted, tangent points green, pivots red diamonds, crossings blue,
centres blue crosses, the original profile grey, the kernel's own section from slicing its mesh in green), middle the kernel's 3D
result (the input with the filleted edges red if every kernel declines), right the REFERENCE (the rule's profile as a sketch plus an
extrude or a revolve: no fillet code). Chips: valid / declined / INVALID with the volume difference from the rule, for kernel.5,
main (0059), this branch (0060) and, where it exists, the 0062 candidate.
Curved-face cases get a second row: a zoom on the fillet region (kernel against rule, and the decision's other candidate), and two more
views (top view for solids of revolution, the far side for prisms).
"""
import sys, os, math, subprocess
import numpy as np

OUT, BINS = sys.argv[1], sys.argv[2]
ONLY = sys.argv[3:]
_saved = sys.argv
sys.argv = ["render", os.path.join(OUT, "_x"), "-", "-", "-"]
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "fillet-pivot-edges"))
import render as R                                   # the 0060 review's helpers
sys.argv = _saved
try:
    os.rmdir(os.path.join(OUT, "_x"))
except OSError:
    pass
import section as sec
import cases3234 as C

PAL = R.PAL
VARIANT_NAMES = {"k5": "kernel.5 (pinned)", "main": "main (0059)", "new": "this branch (0060)", "62": "0062 candidate"}
_cache = {}


# ------------------------------------------------------------------ kernel output
def kdata(case, variant, edges=None, ref=False):
    key = (case.stem, variant, id(edges) if edges is not None else 0, ref)
    if key in _cache:
        return _cache[key]
    b = os.path.join(BINS, "gprobe-" + variant)
    out = None
    if os.path.exists(b):
        s, rc, lines = C.run(b, case.gargs(edges, ref=ref), env={"MESH": "1"})
        res = C.parse_result(s)
        if res and res["done"]:
            T, E = [], []
            for l in lines:
                t = l.split()
                if t and t[0] == "T":
                    T.append([tuple(map(float, t[1 + 3 * i:4 + 3 * i])) for i in range(3)])
                elif t and t[0] == "E":
                    E.append((tuple(map(float, t[1:4])), tuple(map(float, t[4:7]))))
            out = dict(res, T=T, E=E)
        elif res:
            out = dict(res, T=[], E=[])
        else:
            out = dict(done=False, valid=False, vol=-1.0, raw=s or "", T=[], E=[])
    _cache[key] = out
    return out


def built(d):
    return d is not None and d["done"]


# ------------------------------------------------------------------ drawing helpers
def top(p): return (p[0], p[1], p[2])


def back(p):
    return R.proj(p, az=140, el=24)


def solid_p(pn, res, projf, red=None, fit_pts=None):
    prim = []
    for tri in res["T"]:
        P = [projf(v) for v in tri]
        prim.append((sum(q[2] for q in P) / 3, "t", P, R.shade(tri), False))
    for a, b in res["E"]:
        P = [projf(a), projf(b)]
        prim.append(((P[0][2] + P[1][2]) / 2 - 0.05, "e", P, 0, bool(red and red(a, b))))
    pn.fit(fit_pts if fit_pts else [q for _, _, P, _, _ in prim for q in P])
    el = []
    for _, k, P, f, isred in sorted(prim, key=lambda t: t[0]):
        if k == "t":
            c = R.hexshade(PAL["face"], f)
            el.append(f'<polygon points="{" ".join("%.1f,%.1f" % pn.xy(q) for q in P)}" fill="{c}" stroke="{c}" stroke-width="0.5"/>')
        else:
            p, q = pn.xy(P[0]), pn.xy(P[1])
            col, w = (PAL["fail"], 3.6) if isred else (PAL["edge"], 1.3)
            el.append(f'<line x1="{p[0]:.1f}" y1="{p[1]:.1f}" x2="{q[0]:.1f}" y2="{q[1]:.1f}" stroke="{col}" stroke-width="{w}" stroke-linecap="round"/>')
    return el


def red_fn(case):
    pts = []
    for r, V in case.fillets:
        pts.append(V)

    def f(a, b):
        for V in pts:
            ok = True
            for q in (a, b):
                if case.kind == "prism":
                    ok = ok and abs(q[0] - V[0]) < 1e-5 and abs(q[2] - V[1]) < 1e-5
                else:
                    ok = ok and abs(math.hypot(q[0], q[1]) - V[0]) < 1e-5 and abs(q[2] - V[1]) < 1e-5
            if ok:
                return True
        return False
    return f


def slice_mesh(res, case):
    """The kernel's own section: the mesh cut by y = L/2 (prism) or y = +1e-4, x > 0 (revolve), as segments in (x, z)."""
    y0 = case.L / 2 if case.kind == "prism" else 1e-4
    segs = []
    for tri in res["T"]:
        d = [v[1] - y0 for v in tri]
        pts = []
        for i in range(3):
            j = (i + 1) % 3
            if (d[i] > 0) != (d[j] > 0):
                t = d[i] / (d[i] - d[j])
                pts.append((tri[i][0] + t * (tri[j][0] - tri[i][0]), tri[i][2] + t * (tri[j][2] - tri[i][2])))
        if len(pts) == 2 and (case.kind == "prism" or (pts[0][0] > 0 and pts[1][0] > 0)):
            segs.append(tuple(pts))
    return segs


def max_dev(segs, edges):
    """Largest distance from the kernel's section points to the rule's outline."""
    from shapely.geometry import LineString, Point
    ls = LineString(sec.outline(edges, 600) + [edges[0].p0])
    m = 0.0
    for a, b in segs:
        for p in (a, b):
            m = max(m, ls.distance(Point(p)))
    return m


def marks_for(case, info=None):
    info = info or case.info
    m = []

    def corner(s, side_name):
        cs = s["case"]
        piv1, piv2 = cs in ("P1T2", "PP"), cs in ("T1P2", "PP")
        for q, piv, which in ((s["Q1"], piv1, 1), (s["Q2"], piv2, 2)):
            ax = case.kind == "revolve" and abs(q[0]) < 1e-9
            lab = ("PIVOT ON THE AXIS (%.4f, %.4f)" if ax else "pivot (%.4f, %.4f)") % q if piv else "tangent point (%.4f, %.4f)" % q
            m.append(("P" if piv else "T", q, lab))
        m.append(("C", s["C"], "centre (%.4f, %.4f), r = %g" % (s["C"][0], s["C"][1], s["r"])))
    if "s1" in info:
        corner(info["s1"], "")
        corner(info["s2"], "")
        if info.get("cross"):
            m.append(("J", info["cross"], "crossing (%.4f, %.4f)" % info["cross"]))
    else:
        corner(info, "")
    return m


def notes_for(case):
    info = case.info
    n = []
    if "s1" in info:
        if info.get("cross"):
            n.append("the arcs cross at %.2f deg (included, through the material)" % info["included"])
        else:
            n.append("tangent length sums to the face width or less: tangent arcs, junction 180 deg" if True else "")
        return n
    cs = info["case"]
    n.append({"TT": "tangent to both faces", "P1T2": "the incoming face runs out: its far edge is the pivot", "T1P2": "the outgoing face runs out: its far edge is the pivot",
              "PP": "both faces run out: pivots at both far edges"}[cs])
    if abs(info["crease1"]) > 1e-6:
        n.append("crease at the first pivot: %.2f deg between the normals" % abs(info["crease1"]))
    if abs(info["crease2"]) > 1e-6:
        n.append("crease at the second pivot: %.2f deg between the normals" % abs(info["crease2"]))
    if info["side"] < 0:
        n.append("concave edge: material is ADDED (the arc fills the corner)")
    return n


def is_axis(case):
    if case.kind != "revolve" or case.new is None:
        return False
    infos = [case.info] if "s1" not in case.info else [case.info["s1"], case.info["s2"]]
    for i in infos:
        for q, piv in ((i["Q1"], i["case"] in ("P1T2", "PP")), (i["Q2"], i["case"] in ("T1P2", "PP"))):
            if piv and abs(q[0]) < 1e-9:
                return True
    return False


def clamp_radius(case):
    """The largest radius for which the corner is tangent to both faces (the tangent-fillet limit), by bisection."""
    r_lo, r_hi = 1e-3, case.fillets[0][0]
    ed = case.edges
    k = sec.corner_index(ed, case.fillets[0][1])
    def tt(r):
        s = sec.solve_corner(ed[k], ed[(k + 1) % len(ed)], r)
        return s is not None and s["case"] == "TT"
    if not tt(r_lo):
        return None
    for _ in range(60):
        mid = (r_lo + r_hi) / 2
        if tt(mid): r_lo = mid
        else: r_hi = mid
    return r_lo * (1 - 2e-3)      # a sliver short of the limit, so the flat that is left is not zero


# ------------------------------------------------------------------ the section panel
def draw_section(pn, case, kernel, extra=None, zoom=False, title=None):
    ed, new = case.edges, case.new
    pts = sec.outline(ed, 100)
    allp = list(pts)
    if zoom:
        arcp = []
        infos = [case.info] if "s1" not in case.info else [case.info["s1"], case.info["s2"]]
        for i in infos:
            arcp += [i["Q1"], i["Q2"], i["C"]]
        xs = [p[0] for p in arcp]; ys = [p[1] for p in arcp]
        c = case.info["C"] if "C" in case.info else arcp[2]
        lo = (min(xs) - 0.6, min(ys) - 0.6); hi = (max(xs) + 0.6, max(ys) + 0.6)
        # keep the corner V in view
        for r, V in case.fillets:
            lo = (min(lo[0], V[0] - 0.3), min(lo[1], V[1] - 0.3)); hi = (max(hi[0], V[0] + 0.3), max(hi[1], V[1] + 0.3))
        fit = [lo, hi]
    else:
        xs = [p[0] for p in allp]; ys = [p[1] for p in allp]
        fit = [(min(xs) - 0.5, min(ys) - 0.5), (max(xs) + 0.5, max(ys) + 0.5)]
    pn.fit(fit, pad=0.04)
    el = [f'<rect x="{pn.x0}" y="{pn.y0}" width="{pn.w}" height="{pn.h}" fill="#f6f8fb" stroke="#d5dbe5"/>']
    cid = "cp%d_%d" % (pn.x0, pn.y0)
    el.append(f'<clipPath id="{cid}"><rect x="{pn.x0}" y="{pn.y0}" width="{pn.w}" height="{pn.h}"/></clipPath><g clip-path="url(#{cid})">')
    if case.kind == "revolve":
        x0, y0 = pn.xy((0, fit[0][1])); x1, y1 = pn.xy((0, fit[1][1]))
        el.append(f'<line x1="{x0:.1f}" y1="{y0:.1f}" x2="{x1:.1f}" y2="{y1:.1f}" stroke="{PAL["mute"]}" stroke-width="1.2" stroke-dasharray="10 3 2 3"/>')
        lx, ly = pn.xy((0, fit[1][1]))
        el.append(R.text(lx + 22, ly + 16, "axis", 10.5, PAL["mute"]))
    el.append(f'<path d="M {" L ".join("%.1f,%.1f" % pn.xy(p) for p in pts)} Z" fill="none" stroke="{PAL["mute"]}" stroke-width="1.2" stroke-dasharray="2 4"/>')
    infos = [case.info] if "s1" not in case.info else [case.info["s1"], case.info["s2"]]
    for i in infos:
        cx, cy = pn.xy(i["C"])
        el.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{i["r"] * pn.s:.1f}" fill="none" stroke="{PAL["blue"]}" stroke-width="0.8" stroke-dasharray="1 4" opacity="0.55"/>')
    el.append(f'<path d="M {" L ".join("%.1f,%.1f" % pn.xy(p) for p in sec.outline(new, 300))} Z" fill="{PAL["blue"]}" fill-opacity="0.07" stroke="{PAL["blue"]}" stroke-width="2.2" stroke-dasharray="7 4"/>')
    for ex_edges, col in (extra or []):
        el.append(f'<path d="M {" L ".join("%.1f,%.1f" % pn.xy(p) for p in sec.outline(ex_edges, 300))} Z" fill="none" stroke="{col}" stroke-width="2.2" stroke-dasharray="3 3"/>')
    if kernel is not None:
        for a, b in slice_mesh(kernel, case):
            p, q = pn.xy(a), pn.xy(b)
            el.append(f'<line x1="{p[0]:.1f}" y1="{p[1]:.1f}" x2="{q[0]:.1f}" y2="{q[1]:.1f}" stroke="{PAL["ok"] if kernel["valid"] else PAL["warn"]}" stroke-width="3" stroke-linecap="round"/>')
    for kind, p, lab in marks_for(case):
        x, y = pn.xy(p)
        if kind == "C":
            el.append(f'<path d="M {x - 5:.1f},{y:.1f} L {x + 5:.1f},{y:.1f} M {x:.1f},{y - 5:.1f} L {x:.1f},{y + 5:.1f}" stroke="{PAL["blue"]}" stroke-width="1.6"/>')
            continue
        col = {"T": PAL["tan"], "P": PAL["piv"], "J": PAL["blue"]}[kind]
        if kind == "P":
            el.append(f'<rect x="{x - 5:.1f}" y="{y - 5:.1f}" width="10" height="10" fill="{col}" transform="rotate(45 {x:.1f} {y:.1f})"/>')
        else:
            el.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="4.8" fill="{col}"/>')
    el.append("</g>")
    if title:
        el.append(R.text(pn.x0 + pn.w / 2, pn.y0 + pn.h + 18, title, 12, PAL["mute"]))
    return el


def legend(case, x, y):
    el, i = [], 0
    order = {"T": 0, "P": 1, "J": 2, "C": 3}
    for kind, p, lab in sorted(marks_for(case), key=lambda t: order[t[0]]):
        col = {"T": PAL["tan"], "P": PAL["piv"], "J": PAL["blue"], "C": PAL["blue"]}[kind]
        sym = {"T": "o", "P": "<>", "J": "o", "C": "+"}[kind]
        el.append(R.text(x, y + 16 * i, ("%s  " % sym) + lab, 11.5, col, "normal", "start")); i += 1
    for n in notes_for(case):
        el.append(R.text(x, y + 16 * i, "- " + n, 11.5, PAL["ink"], "bold", "start")); i += 1
    return el, i


def status(res, want):
    if res is None:
        return None, None
    if not res["done"]:
        return "declined (IsDone false)", PAL["fail"]
    cl = C.classify(res, want)
    d = res["vol"] - want
    if cl == "right":
        return "valid, %.6f (%+.1e)" % (res["vol"], d), PAL["ok"]
    if cl == "wrong":
        return "valid but WRONG volume %.6f (%+.4f)" % (res["vol"], d), PAL["warn"]
    return "done but INVALID, %.4f (%+.4f)" % (res["vol"], d), PAL["warn"]


# ------------------------------------------------------------------ the figure
def figure_undefined(case):
    """The rule has no answer: no circle of this radius fits, tangent to both faces, inside the part. Input, the largest
    circle that does fit, and every kernel's answer."""
    variants = [v for v in C.VARIANTS if os.path.exists(os.path.join(BINS, "gprobe-" + v))]
    data = {v: kdata(case, v) for v in variants}
    inp = kdata(case, "new", edges=None, ref=True)
    ed = case.edges
    k = sec.corner_index(ed, case.fillets[0][1])
    rmax = clamp_radius(case)
    sol = sec.solve_corner(ed[k], ed[(k + 1) % len(ed)], rmax) if rmax else None
    Wd, Hd = 1560, 760
    el = [R.text(Wd / 2, 34, case.title, 19, weight="bold"),
          R.text(Wd / 2, 56, "the rule has NO ARC here: no circle of radius %g fits inside the part tangent to both faces" % case.fillets[0][0], 13, PAL["fail"])]
    A, B = R.Panel(20, 80, 480, 400), R.Panel(520, 80, 520, 400)
    pts = sec.outline(ed, 100)
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    A.fit([(min(xs) - 0.5, min(ys) - 0.5), (max(xs) + 0.5, max(ys) + 0.5)], pad=0.04)
    el.append(f'<rect x="{A.x0}" y="{A.y0}" width="{A.w}" height="{A.h}" fill="#f6f8fb" stroke="#d5dbe5"/>')
    el.append(f'<path d="M {" L ".join("%.1f,%.1f" % A.xy(p) for p in pts)} Z" fill="{PAL["blue"]}" fill-opacity="0.07" stroke="{PAL["mute"]}" stroke-width="1.6"/>')
    if sol:
        cx, cy = A.xy(sol["C"])
        el.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{rmax * A.s:.1f}" fill="none" stroke="{PAL["blue"]}" stroke-width="1.6" stroke-dasharray="6 3"/>')
        for q in (sol["Q1"], sol["Q2"]):
            x, y = A.xy(q)
            el.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="4.8" fill="{PAL["tan"]}"/>')
    el.append(R.text(28, 508, "dashed circle: the LARGEST fillet that is tangent to both faces (r = %.4f)" % (rmax or 0), 11.5, PAL["blue"], "normal", "start"))
    el.append(R.text(28, 524, "any larger circle crosses the other side of the part; pivot candidates then", 11.5, PAL["ink"], "normal", "start"))
    el.append(R.text(28, 540, "leave the part, so there is no outline to draw and no volume to compare.", 11.5, PAL["ink"], "normal", "start"))
    el += solid_p(B, inp, R.proj, red=red_fn(case))
    el.append(R.text(780, 500, "the input, filleted edge red", 12, PAL["mute"]))
    yy = 530
    for v in variants:
        d = data[v]
        if d is None:
            continue
        txt = "declined (IsDone false)" if not d["done"] else ("BUILT: valid=%s volume %.6f" % (d["valid"], d["vol"]))
        el.append(R.chip(780, yy, 480, VARIANT_NAMES[v] + ": " + txt, PAL["fail"] if not d["done"] else PAL["warn"])); yy += 34
    el.append(R.text(Wd / 2, Hd - 70, "DECISION (maintainer): when the ball cannot fit, B: decline (every kernel today), or C: clamp to the largest tangent fillet (dashed), the same", 12.5, PAL["fail"], "bold"))
    el.append(R.text(Wd / 2, Hd - 50, "choice as D1. There is no candidate A: an arc through a pivot would leave the part, so the outcome would be a different body, not a fillet.", 12.5, PAL["fail"], "bold"))
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{Wd}" height="{Hd}" viewBox="0 0 {Wd} {Hd}"><rect width="{Wd}" height="{Hd}" fill="{PAL["bg"]}"/>{"".join(el)}</svg>'
    path = os.path.join(OUT, case.stem + ".svg")
    open(path, "w").write(svg)
    subprocess.run(["rsvg-convert", "-z", "1.2", "-o", path[:-4] + ".png", path], check=True)
    return data, variants


def figure(case):
    want = case.volume(case.new)
    base = case.volume(case.edges)
    variants = [v for v in C.VARIANTS if os.path.exists(os.path.join(BINS, "gprobe-" + v))]
    data = {v: kdata(case, v) for v in variants}
    best = next((v for v in ("62", "new", "main", "k5") if v in data and built(data[v])), None)
    # 62 is only worth a chip where it changes something
    if "62" in data and data["62"] is not None and "new" in data and C.classify(data["62"], want) == C.classify(data["new"], want) and \
            (data["62"].get("raw") == data["new"].get("raw")):
        variants = [v for v in variants if v != "62"]
    ref = kdata(case, "new", edges=case.new, ref=True)
    inp = kdata(case, "new", edges=None, ref=True)
    curved = case.group == "H"
    axis = is_axis(case)
    Wd = 1560
    H1 = 720 if len(variants) <= 4 else 760
    Hd = H1 + (470 if curved else 0)
    el = [R.text(Wd / 2, 34, case.title, 19, weight="bold"),
          R.text(Wd / 2, 56, "rule volume %.6f (the original body %.6f); the section is the XZ plane, x to the right, z up%s" %
                 (want, base, "; the body is that section turned about the z axis" if case.kind == "revolve" else "; extruded %g along +Y" % case.L), 13, PAL["mute"])]
    A, B, Cc = R.Panel(20, 80, 480, 400), R.Panel(520, 80, 520, 400), R.Panel(1060, 80, 480, 400)
    kslice = data[best] if best else None
    el += draw_section(A, case, kslice)
    leg, nleg = legend(case, 28, 508)
    el += leg
    if kslice is not None:
        dv = max_dev(slice_mesh(kslice, case), case.new)
        el.append(R.text(28, 508 + 16 * nleg, "kernel section (green, %s) is within %.1e of the rule's profile" % (VARIANT_NAMES[best], dv), 11.5, PAL["ok"], "bold", "start"))
    if best:
        el += solid_p(B, data[best], R.proj)
        el.append(R.text(780, H1 - 36, "3D result of: %s" % VARIANT_NAMES[best], 12, PAL["mute"]))
    else:
        el += solid_p(B, inp, R.proj, red=red_fn(case))
        el.append(R.text(780, H1 - 36, "every kernel declines: the input, filleted edge red", 12, PAL["mute"]))
    yy = 512
    for v in variants:
        s, col = status(data[v], want)
        if s:
            el.append(R.chip(780, yy, 480, VARIANT_NAMES[v] + ": " + s, col)); yy += 34
    if ref and ref["T"]:
        el += solid_p(Cc, ref, R.proj)
    s2, c2 = status(ref, want)
    el.append(R.chip(1300, 512, 470, "reference (sketch + %s): %s" % ("extrude" if case.kind == "prism" else "revolve", s2), c2))
    el.append(R.text(1300, 548, "the rule's profile as a solid: what Shapr3D gives", 12, PAL["mute"]))
    yb = H1 - 14
    if case.note:
        el.append(R.text(Wd / 2, yb, case.note, 12.5, PAL["ink"]))
    # ---- second row for curved faces
    if curved:
        y0 = H1 + 20
        D, E, F = R.Panel(20, y0, 480, 330), R.Panel(520, y0, 520, 330), R.Panel(1060, y0, 480, 330)
        extra, ex_title, alt_ref, alt_name = [], "zoom on the fillet region: rule (blue), kernel (green)", None, None
        if axis:
            rc = clamp_radius(case)
            if rc:
                k = sec.corner_index(case.edges, case.fillets[0][1])
                ce, _ = sec.fillet_corner(case.edges, k, rc)
                extra.append((ce, "#e08a1e"))
                alt_ref = (ce, rc, "C")
                ex_title = "zoom: rule (blue) and candidate C, clamp to the tangent fillet r = %.4f (orange)" % rc
        if "alts" in case.info and case.info["alts"]:
            k = sec.corner_index(case.edges, case.fillets[0][1])
            ae, _ = sec.apply_solution(case.edges, k, case.info["alts"][0])
            extra.append((ae, "#e08a1e"))
            alt_ref = (ae, case.info["alts"][0]["case"], "alt")
            ex_title = "zoom: rule (blue) and the other arc that also satisfies the rule (orange, %s)" % case.info["alts"][0]["case"]
        el += draw_section(D, case, kslice, extra=extra, zoom=True, title=ex_title)
        if case.kind == "revolve":
            projf, vname = top, "top view (looking down the axis)"
        else:
            projf, vname = back, "the far side"
        src = data[best] if best else inp
        el += solid_p(E, src, projf, red=None if best else red_fn(case))
        el.append(R.text(780, y0 + 348, ("%s of: %s" % (vname, VARIANT_NAMES[best])) if best else "%s of the input, filleted edge red" % vname, 12, PAL["mute"]))
        if alt_ref:
            ae, tagv, kind = alt_ref
            altd = kdata(case, "new", edges=ae, ref=True)
            if altd and altd["T"]:
                el += solid_p(F, altd, projf)
            sv, cv = status(altd, case.volume(ae))
            el.append(R.chip(1300, y0 + 346, 470, ("candidate C (clamped)" if kind == "C" else "the other arc") + ": volume %.6f" % case.volume(ae), PAL["blue"]))
        else:
            src2 = ref
            if src2 and src2["T"]:
                el += solid_p(F, src2, projf)
            el.append(R.text(1300, y0 + 348, "%s of the reference" % vname, 12, PAL["mute"]))
        if axis:
            el.append(R.text(Wd / 2, Hd - 36, "DECISION (maintainer): an arc through a point ON THE AXIS has no edge to be a pivot. A: build the revolve of the rule's profile (right panel above; a "
                             "conical point at the axis). B: decline, as every kernel does today.", 12.5, PAL["fail"], "bold"))
            el.append(R.text(Wd / 2, Hd - 16, "C: build the largest fillet that is tangent to both faces (orange). Candidates A and C are drawn; B is the grey input.", 12.5, PAL["fail"], "bold"))
        elif alt_ref and alt_ref[2] == "alt":
            el.append(R.text(Wd / 2, Hd - 24, "DECISION (maintainer): two arcs satisfy the rule here. The blue one runs out the shorter face first (what a ball growing from a tangent fillet does); the orange one runs out the longer face.", 12.5, PAL["fail"], "bold"))
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{Wd}" height="{Hd}" viewBox="0 0 {Wd} {Hd}"><rect width="{Wd}" height="{Hd}" fill="{PAL["bg"]}"/>{"".join(el)}</svg>'
    path = os.path.join(OUT, case.stem + ".svg")
    open(path, "w").write(svg)
    subprocess.run(["rsvg-convert", "-z", "1.2", "-o", path[:-4] + ".png", path], check=True)
    return want, data, ref, variants


# ------------------------------------------------------------------ recipe text
def edge_steps(edges, start_label):
    out, step = [], 0
    cur = edges[0].p0
    out.append("1. Start at (%.4f, %.4f)." % cur)
    step = 1
    for e in edges:
        step += 1
        if e.kind == "L":
            if (e is edges[-1]) and sec.norm(sec.sub(e.p1, edges[0].p0)) < 1e-9:
                out.append("%d. Line back to the start (%.4f, %.4f), closing the profile." % (step, e.p1[0], e.p1[1]))
            else:
                out.append("%d. Line to (%.4f, %.4f)." % (step, e.p1[0], e.p1[1]))
        else:
            m = e.mid()
            out.append("%d. Arc, centre (%.4f, %.4f), radius %g, from (%.4f, %.4f) to (%.4f, %.4f), passing through (%.4f, %.4f), %s." %
                       (step, e.c[0], e.c[1], e.R, e.p0[0], e.p0[1], e.p1[0], e.p1[1], m[0], m[1], "counter-clockwise" if e.ccw else "clockwise"))
    return out


def fmt(res, want):
    if res is None:
        return "not run"
    if not res["done"]:
        return "declined"
    cl = C.classify(res, want)
    return ("valid %.6f" % res["vol"]) if cl == "right" else (("valid, WRONG volume %.6f" % res["vol"]) if cl == "wrong" else ("INVALID %.4f" % res["vol"]))


def recipe(case, want, data, ref, variants):
    ed = case.edges
    kind = case.kind
    ax = "extrude %g along +Y" % case.L if kind == "prism" else "revolve 360 degrees about the Z axis (the line x = 0, which is the profile's own edge)"
    picks = "; ".join("radius %g on the %s edge through the point (%s)" % (r, "straight" if kind == "prism" else "circular", ", ".join("%g" % v for v in case.pick(V))) for r, V in case.fillets)
    out = ["### " + case.title, "", "File `%s.png`. %s" % (case.stem, ("Body: " + ("a prism, the section extruded %g along +Y" % case.L) if kind == "prism" else "Body: the section turned about the Z axis")), ""]
    out += ["Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), origin at the sketch origin below, one closed profile, then %s:" % ax, ""]
    out += edge_steps(ed, "")
    out += ["", "Fillet, Shapr3D: " + picks + (", both in one operation." if len(case.fillets) == 2 else "."), ""]
    out += ["Expected (the rule): " + "; ".join(notes_for(case)) + ".", ""]
    if "alts" in case.info and case.info.get("alts"):
        out += ["Also satisfies the rule: the %s arc (the other face runs out first); see the second row. Decision." % case.info["alts"][0]["case"], ""]
    out += ["Reference, Shapr3D: the profile the rule gives, sketch on the XZ plane, then %s:" % ax, ""]
    out += edge_steps(case.new, "")
    out += ["", "Check: the fillet tool's result and this sketch should coincide. Volume %.6f (original body %.6f)." % (want, case.volume(ed)), ""]
    kr = "; ".join("%s %s" % (VARIANT_NAMES[v], fmt(data[v], want)) for v in variants)
    out += ["Kernel results: %s; reference %s." % (kr, fmt(ref, want)), ""]
    return "\n".join(out)


def recipe_undefined(case, data):
    ax = "extrude %g along +Y" % case.L if case.kind == "prism" else "revolve 360 degrees about the Z axis (the line x = 0)"
    picks = "; ".join("radius %g on the %s edge through the point (%s)" % (r, "straight" if case.kind == "prism" else "circular", ", ".join("%g" % v for v in case.pick(V))) for r, V in case.fillets)
    out = ["### " + case.title, "", "File `%s.png`. The rule has no answer: no circle of this radius fits inside the part tangent to both faces." % case.stem, "",
           "Original body, Shapr3D: sketch on the XZ plane (front plane, looking along Y), one closed profile, then %s:" % ax, ""]
    out += edge_steps(case.edges, "")
    out += ["", "Fillet, Shapr3D: " + picks + ". Expected: the fillet tool refuses (no tangent fillet this large exists); see the decision.", ""]
    out += ["Kernel results: " + "; ".join("%s %s" % (VARIANT_NAMES[v], "declined" if d is not None and not d["done"] else ("BUILT %.6f valid=%s" % (d["vol"], d["valid"]) if d else "n/a")) for v, d in data.items() if d is not None) + ".", ""]
    return "\n".join(out)


def classification(data, want, variants):
    """The branch's outcome for the summary table, from 0060 (and 0062 where it differs)."""
    d = data.get("62") if "62" in variants else None
    new = data.get("new")
    cl_new = C.classify(new, want) if new is not None else "n/a"
    cl_62 = C.classify(d, want) if d is not None else None
    return cl_new, cl_62


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    rows = []
    rows_u = []
    for case in C.CASES:
        if ONLY and case.stem not in ONLY:
            continue
        if case.new is None:
            data, variants = figure_undefined(case)
            rows_u.append((case, data))
            print(case.stem, "rule undefined |", " | ".join("%s %s" % (v, "declined" if not data[v]["done"] else "built %.6f" % data[v]["vol"]) for v in variants), flush=True)
            continue
        want, data, ref, variants = figure(case)
        rows.append((case, want, data, ref, variants))
        print(case.stem, " | ".join("%s %s" % (v, fmt(data[v], want)) for v in variants), flush=True)
    import pickle
    with open(os.path.join(OUT, "_rows.pkl"), "wb") as f:
        strip = lambda dd: {v: (None if d is None else {k: x for k, x in d.items() if k not in ("T", "E")}) for v, d in dd.items()}
        pickle.dump([(c.stem, w, strip(dd)) for c, w, dd, r, vs in rows] + [(c.stem, None, strip(dd)) for c, dd in rows_u], f)
    with open(os.path.join(OUT, "table.tsv"), "w") as f:
        f.write("file\tcase\trule_volume\t" + "\t".join(C.VARIANTS) + "\n")
        for case, want, data, ref, variants in rows:
            f.write("%s.png\t%s\t%.6f\t" % (case.stem, case.title, want) + "\t".join(fmt(data.get(v), want) for v in C.VARIANTS) + "\n")
    with open(os.path.join(OUT, "_recipes.md"), "w") as f:
        for case, want, data, ref, variants in rows:
            f.write(recipe(case, want, data, ref, variants) + "\n")
        for case, data in rows_u:
            f.write(recipe_undefined(case, data) + "\n")
