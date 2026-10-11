#!/usr/bin/env python3
"""Review images for #3233 (fillet contours that share a vertex). Standard library plus numpy; reuses the section machinery of
../fillet-pivot-edges/render.py (imported with its command line stubbed).

  render3233.py <outdir> <bin dir with cdump_k5 cdump_main cdump_new> <measure.json> [stem ...]

Layout, 1560 x 1190, three rows of three panels:
  row 1  the analytic end view (a section across one edge away from the corner: the arcs, tangent points, pivots, crossing, numbers, with
         the branch's slice of the kernel result drawn over it in green) | the kernel result, oblique, edges drawn | the reference, oblique
  row 2  what the rule expects, in words, and the volumes | the kernel result seen from above, the reference's edges dashed blue over it | the reference from above
  row 3  chips: valid / declined / hung and the volume difference for this branch (0060), main (0059) and kernel.5 | corner close-up, kernel | corner close-up, reference
The reference is built with no fillet code: removal prisms (sketch + extrude) and cube-minus-ball pieces cut out of the base solid.
"""
import sys, os, math, json, subprocess, tempfile
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "fillet-pivot-edges"))
_argv = sys.argv
sys.argv = ["render", tempfile.mkdtemp(prefix="r3233-"), "", "", ""]
import render as R          # section geometry and drawing helpers
sys.argv = _argv
import cases3233 as C
import measure as M

PAL = R.PAL
text, chip, hexshade, shade, Panel = R.text, R.chip, R.hexshade, R.shade, R.Panel


def proj(p, az, el):
    """Orthographic camera at azimuth az (degrees, in the XY plane, measured from +X) and elevation el, looking at the origin;
    returns (screen right, screen up, depth with larger = nearer). el = 90 is the plan view, X right and Y up."""
    x, y, z = p
    if el >= 89.9:
        return (x, y, z)
    a, e = math.radians(az), math.radians(el)
    c = (math.cos(e) * math.cos(a), math.cos(e) * math.sin(a), math.sin(e))
    f = (-c[0], -c[1], -c[2])
    right = (f[1], -f[0], 0.0)                         # f cross +Z
    n = math.hypot(right[0], right[1])
    right = (right[0] / n, right[1] / n, 0.0)
    up = (right[1] * f[2] - right[2] * f[1], right[2] * f[0] - right[0] * f[2], right[0] * f[1] - right[1] * f[0])
    return (right[0] * x + right[1] * y, up[0] * x + up[1] * y + up[2] * z, c[0] * x + c[1] * y + c[2] * z)


def load_mesh(exe, case, mode):
    p = subprocess.run([exe] + M.args_of(case, mode), capture_output=True, text=True, timeout=90, start_new_session=True)
    st, T, E = None, [], []
    for l in p.stdout.splitlines():
        t = l.split()
        if t[0] == "STATUS":
            st = t
        elif t[0] == "T":
            T.append([tuple(map(float, t[1 + 3 * i:4 + 3 * i])) for i in range(3)])
        elif t[0] == "E":
            E.append((tuple(map(float, t[1:4])), tuple(map(float, t[4:7]))))
    if not st or "done" not in st:
        return None
    d = dict(x.split("=") for x in st[3:])
    return dict(valid=d["valid"] == "1", vol=float(d["vol"]), T=T, E=E)


def prims(res, az, el, edges=True):
    out = []
    for tri in res["T"]:
        P = [proj(v, az, el) for v in tri]
        out.append((sum(q[2] for q in P) / 3, "t", P, shade(tri)))
    if edges:
        for a, b in res["E"]:
            P = [proj(a, az, el), proj(b, az, el)]
            out.append(((P[0][2] + P[1][2]) / 2 - 0.05, "e", P, 0))
    return out


def draw(pn, pr, base="#9fb4cc", ew=1.4):
    el = []
    for _, k, P, f in sorted(pr, key=lambda t: t[0]):
        if k == "t":
            c = hexshade(base, f)
            el.append(f'<polygon points="{" ".join("%.1f,%.1f" % pn.xy(q) for q in P)}" fill="{c}" stroke="{c}" stroke-width="0.5"/>')
        else:
            p, q = pn.xy(P[0]), pn.xy(P[1])
            el.append(f'<line x1="{p[0]:.1f}" y1="{p[1]:.1f}" x2="{q[0]:.1f}" y2="{q[1]:.1f}" stroke="{PAL["edge"]}" stroke-width="{ew}" stroke-linecap="round"/>')
    return el


def frame_rect(pn, label=""):
    return [f'<rect x="{pn.x0}" y="{pn.y0}" width="{pn.w}" height="{pn.h}" fill="#f6f8fb" stroke="#d5dbe5"/>']


def tag_label(pn, label):
    label = label if len(label) * 6.3 < pn.w - 20 else label[: int((pn.w - 20) / 6.3) - 3] + "..."
    return [f'<rect x="{pn.x0 + 4}" y="{pn.y0 + 4}" width="{min(6.4 * len(label) + 10, pn.w - 8):.0f}" height="18" rx="4" fill="#f6f8fb" opacity="0.85"/>', text(pn.x0 + 9, pn.y0 + 17, label, 11.5, PAL["mute"], "normal", "start")]


def input_solid(case):
    """The input as triangles-free wireframe segments: polygon top and bottom and the verticals."""
    poly, H = case.poly, case.H
    seg = []
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        seg.append(((a[0], a[1], 0.0), (b[0], b[1], 0.0)))
        seg.append(((a[0], a[1], H), (b[0], b[1], H)))
        seg.append(((a[0], a[1], 0.0), (a[0], a[1], H)))
    return seg


def is_filleted(case, a, b):
    m = tuple((a[i] + b[i]) / 2 for i in range(3))
    return any(max(abs(m[i] - e[i]) for i in range(3)) < 1e-6 for _, e in case.edges)


def wire_panel(pn, case, az, el, label, top=False, focus=None, r=None):
    segs = input_solid(case)
    pts = [proj(p, az, el) for s in segs for p in s]
    pn.fit(pts, pad=0.08)
    out = frame_rect(pn)
    for a, b in segs:
        red = is_filleted(case, a, b)
        p, q = pn.xy(proj(a, az, el)), pn.xy(proj(b, az, el))
        out.append(f'<line x1="{p[0]:.1f}" y1="{p[1]:.1f}" x2="{q[0]:.1f}" y2="{q[1]:.1f}" stroke="{PAL["fail"] if red else PAL["mute"]}" stroke-width="{3.4 if red else 1.2}"/>')
    return out + tag_label(pn, label)


def view_bounds(case, az, el, focus=None, rad=None):
    if focus is None:
        return [proj(p, az, el) for s in input_solid(case) for p in s]
    fx, fy, fz = focus
    if case.kind == "poly":                     # a reflex vertex: the solid is on every side but one
        lo, hi = (-rad, -rad, -rad), (rad, rad, 0.6)
    else:                                       # the corner at the origin: the solid is on the positive side
        lo, hi = (-0.4, -0.4, -rad), (rad, rad, 0.6)
    pts = [(fx + (lo[0] if sx else hi[0]), fy + (lo[1] if sy else hi[1]), fz + (lo[2] if sz else hi[2])) for sx in (0, 1) for sy in (0, 1) for sz in (0, 1)]
    return [proj(p, az, el) for p in pts]


def mesh_panel(pn, case, res, az, el, label, focus=None, rad=None, overlay=None, clip=False):
    out = frame_rect(pn)
    if res is None:
        return wire_panel(pn, case, az, el, label)
    pr = prims(res, az, el)
    pn.fit(view_bounds(case, az, el, focus, rad), pad=0.06)
    cid = "c%d" % abs(hash((pn.x0, pn.y0, label)))
    out.append(f'<clipPath id="{cid}"><rect x="{pn.x0}" y="{pn.y0}" width="{pn.w}" height="{pn.h}"/></clipPath><g clip-path="url(#{cid})">')
    out += draw(pn, pr)
    if overlay is not None:
        for a, b in overlay["E"]:
            P = [proj(a, az, el), proj(b, az, el)]
            p, q = pn.xy(P[0]), pn.xy(P[1])
            out.append(f'<line x1="{p[0]:.1f}" y1="{p[1]:.1f}" x2="{q[0]:.1f}" y2="{q[1]:.1f}" stroke="{PAL["blue"]}" stroke-width="1.3" stroke-dasharray="5 3" opacity="0.9"/>')
    out.append("</g>")
    return out + tag_label(pn, label)


def slice_segments(res, axis, val):
    """Segments of the mesh in the plane axis = val, as (u, z) pairs; axis 1 = y (u = x), 0 = x (u = y)."""
    segs = []
    ua = 0 if axis == 1 else 1
    for tri in res["T"]:
        d = [v[axis] - val for v in tri]
        pts = []
        for i in range(3):
            j = (i + 1) % 3
            if d[i] == 0:
                pts.append((tri[i][ua], tri[i][2]))
            elif d[i] * d[j] < 0:
                t = d[i] / (d[i] - d[j])
                pts.append((tri[i][ua] + t * (tri[j][ua] - tri[i][ua]), tri[i][2] + t * (tri[j][2] - tri[i][2])))
        if len(pts) >= 2:
            segs.append((pts[0], pts[1]))
    return segs


def section_geo(case):
    """(geo for the analytic panel, width, height, slice axis, slice value, u offset), None when the case has no clean section."""
    k = case.kind
    rs = [r for r, _ in case.edges]
    if k in ("adjacent", "corner3"):
        r = case.edges[1][0]                                  # the left edge, along Y
        return R.build_single(C.W, C.H, r), C.W, C.H, 1, C.D / 2, 0.0, "section across the left edge (along Y), y = 5"
    if k == "frame":
        r = rs[1]                                              # the edges along Y, whose arcs make the section across X
        x = case.poly[2][0]
        return R.build_add(x, case.H, r, r), x, case.H, 1, case.poly[2][1] / 2, 0.0, "section across the flat top, halfway along"
    if k == "rounded":
        r = rs[0]
        return R.build_add(C.W, C.H, r, r), C.W, C.H, 1, C.D / 2, 0.0, "section across the top, y = 5"
    if k == "poly":
        r = rs[0]
        return R.build_add(3.0, case.H, r, r), 3.0, case.H, 1, 5.5 if len(case.poly) == 6 else 5.0, 0.0, "section across the 3 mm arm at x = 0..3"
    return None


class FakeCase:
    pass


def section_panel(pn, case, res):
    sg = section_geo(case)
    if sg is None:
        return frame_rect(pn)
    g, w, h, axis, val, u0, label = sg
    fc = FakeCase()
    fc.box = (w, 1.0, h)
    fc.geo = g
    out = R.section_panel(pn, fc, None)
    if res:
        col = PAL["ok"] if res["valid"] else PAL["warn"]
        for (u1, z1), (u2, z2) in slice_segments(res, axis, val):
            if u1 < -0.01 or u2 < -0.01 or u1 > w + 0.01 or u2 > w + 0.01:
                continue
            p, q = pn.xy((u1, z1)), pn.xy((u2, z2))
            out.insert(len(out) - 1, f'<line x1="{p[0]:.1f}" y1="{p[1]:.1f}" x2="{q[0]:.1f}" y2="{q[1]:.1f}" stroke="{col}" stroke-width="2.6" stroke-linecap="round"/>')
    out.append(text(pn.x0 + 8, pn.y0 + 16, "analytic " + label + ", kernel slice green", 11.5, PAL["mute"], "normal", "start"))
    return out, g


def classify(r):
    if r is None:
        return "no run", PAL["mute"]
    if r.get("timeout"):
        return "HANG: no answer after 60 s", PAL["fail"]
    if "kernel" not in r:
        return "crash (rc %s)" % r.get("rc"), PAL["fail"]
    k = r["kernel"]
    if not k["done"]:
        return "declined (IsDone false)", PAL["fail"]
    d = r.get("diff", {})
    ref = r.get("ref", {}).get("vol")
    if not k["valid"]:
        return "done but INVALID, volume %.3g" % k["vol"], PAL["warn"]
    dv = ("%+.4f" % (k["vol"] - ref)) if ref is not None else "?"
    same = d and d.get("kernel_minus_ref", 1) < 1e-6 and d.get("ref_minus_kernel", 1) < 1e-6
    return "valid %.4f, vs reference %s" % (k["vol"], dv), PAL["ok"] if same else PAL["warn"]


def usable(r, key):
    k = r.get(key, {}).get("kernel")
    return bool(k and k.get("done") and k.get("valid") and not r[key].get("timeout"))


def load_variant(case, bindir, r):
    """The mesh of the best kernel result: the 0061 candidate, else this branch (0060), only if valid (an invalid solid can stall the tessellator)."""
    for key, exe, label in (("p61", "cdump_61", "this branch + candidate 0061"), ("new", "cdump_new", "this branch (0060)")):
        if usable(r, key):
            return load_mesh(os.path.join(bindir, exe), case, "fillet"), label, key
    return None, "no valid solid from this branch or the candidate: the input, filleted edges red", None


def figure(case, bindir, res_all, out):
    r = res_all[case.stem]
    newm, newlabel, nkey = load_variant(case, bindir, r)
    refm = load_mesh(os.path.join(bindir, "cdump_new"), case, "ref")
    Wd, Hd = 1560, 1200
    el = [text(Wd / 2, 32, case.title, 18, weight="bold")]
    A, B, Cp = Panel(20, 56, 480, 380), Panel(520, 56, 520, 380), Panel(1060, 56, 480, 380)
    D, E, F = Panel(20, 446, 480, 340), Panel(520, 446, 520, 340), Panel(1060, 446, 480, 340)
    G, H, I = Panel(20, 796, 480, 340), Panel(520, 796, 520, 340), Panel(1060, 796, 480, 340)
    sec = section_panel(A, case, newm)
    g = None
    if isinstance(sec, tuple):
        sec, g = sec
    el += sec
    az, ev = case.view, 28
    fx, fy = (case.focus or (0.0, 0.0))
    foc = (fx, fy, case.H)
    rad = max(r_ for r_, _ in case.edges) * 1.15 + 0.6
    el += mesh_panel(B, case, newm, az, ev, newlabel + ", oblique" if newm else newlabel)
    el += mesh_panel(Cp, case, refm, az, ev, "reference: " + case.ref_label)
    zoom = dict(focus=foc, rad=rad * 2.0) if case.kind in ("adjacent", "corner3", "poly") else {}
    el += mesh_panel(E, case, newm, 0, 90, "from above; reference edges dashed blue", overlay=refm, **zoom)
    el += mesh_panel(F, case, refm, 0, 90, "reference, from above", **zoom)
    fx, fy = (case.focus or (0.0, 0.0))
    foc = (fx, fy, case.H)
    rad = max(r_ for r_, _ in case.edges) * 1.15 + 0.6
    el += mesh_panel(H, case, newm, case.view, 22, "corner close-up", focus=foc, rad=rad)
    el += mesh_panel(I, case, refm, case.view, 22, "reference, corner close-up", focus=foc, rad=rad)
    y = 466
    el.append(text(30, y, "Expected (from the rule)", 13, PAL["ink"], "bold", "start"))
    for ln in wrap(case.expect, 62):
        y += 17
        el.append(text(30, y, ln, 11.5, PAL["ink"], "normal", "start"))
    y += 8
    for n in case.notes:
        for ln in wrap(n, 62):
            y += 16
            el.append(text(30, y, ln, 11.5, PAL["mute"], "normal", "start"))
    if g is not None:
        y += 24
        el.append(text(30, y, "Section numbers", 13, PAL["ink"], "bold", "start"))
        for kind, p, lab in sorted(g.marks, key=lambda t: {"T": 0, "P": 1, "J": 2, "C": 3}[t[0]]):
            y += 15
            sym = {"T": "o", "P": "<>", "J": "o", "C": "+"}[kind]
            el.append(text(30, y, sym + "  " + lab, 10.5, {"T": PAL["tan"], "P": PAL["piv"], "J": PAL["blue"], "C": PAL["blue"]}[kind], "normal", "start"))
        for n in g.notes:
            y += 15
            el.append(text(30, y, "- " + n, 10.5, PAL["ink"], "bold", "start"))
    y = 822
    refr = r["ref"].get("ref", {})
    el.append(text(30, y - 12, "Results (one process per kernel)", 13, PAL["ink"], "bold", "start"))
    for lab, key in (("this branch + candidate 0061", "p61"), ("this branch (0060)", "new"), ("main (0059)", "main"), ("kernel.5 (pinned)", "k5")):
        s_, c = classify(r[key])
        el.append(chip(250, y + 10, 460, lab + ": " + s_, c))
        y += 34
    el.append(chip(250, y + 10, 460, "reference: %s %.4f" % ("valid" if refr.get("valid") else "INVALID", refr.get("vol", 0)), PAL["ok"] if refr.get("valid") else PAL["fail"]))
    el.append(text(30, y + 40, "green = same solid as the reference (volume difference of the two Boolean cuts below 1e-6)", 10.5, PAL["mute"], "normal", "start"))
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{Wd}" height="{Hd}" viewBox="0 0 {Wd} {Hd}"><rect width="{Wd}" height="{Hd}" fill="{PAL["bg"]}"/>{"".join(el)}</svg>'
    path = os.path.join(out, case.stem + ".svg")
    open(path, "w").write(svg)
    subprocess.run(["rsvg-convert", "-z", "1.0", "-o", path[:-4] + ".png", path], check=True)
    return g


def candidate_sets(case, bindir, r):
    """[(label, mesh or None, volume text)] for the decision image."""
    kern, klabel, key = load_variant(case, bindir, r)
    exe = os.path.join(bindir, "cdump_new")
    out = []
    if case.kind == "poly":
        ridge = load_mesh_items(exe, case, case.ridge)
        out = [("A: what the kernel gives today (a blend patch)", kern, vol_text(kern)),
               ("B: the two fillets meet in a diagonal mitre (ridge), r past the corner", ridge, vol_text(ridge)),
               ("C: rolling ball round the vertical edge (the edge is the pivot): the profile revolved 90 deg", load_mesh(exe, case, "ref"), vol_text(load_mesh(exe, case, "ref")))]
    else:
        pointed = load_mesh(exe, case, "ref")
        out = [("A: " + ("what the kernel gives today (a vertex blend)" if kern else "the kernel declines (IsDone false), as today"), kern, vol_text(kern) if kern else "declined"),
               ("B: the intersection of the single-edge fillets: pointed corners", pointed, vol_text(pointed))]
    return out


def vol_text(m):
    return "volume %.4f" % m["vol"] if m else "no solid"


def load_mesh_items(exe, case, items):
    p = subprocess.run([exe, "ref", case.shape, "--"] + items, capture_output=True, text=True, timeout=90, start_new_session=True)
    st, T, E = None, [], []
    for l in p.stdout.splitlines():
        t = l.split()
        if t[0] == "STATUS":
            st = t
        elif t[0] == "T":
            T.append([tuple(map(float, t[1 + 3 * i:4 + 3 * i])) for i in range(3)])
        elif t[0] == "E":
            E.append((tuple(map(float, t[1:4])), tuple(map(float, t[4:7]))))
    d = dict(x.split("=") for x in st[3:])
    return dict(valid=d["valid"] == "1", vol=float(d["vol"]), T=T, E=E)


def decision_figure(case, bindir, res_all, out):
    r = res_all[case.stem]
    cands = candidate_sets(case, bindir, r)
    n = len(cands)
    Wd, Hd = 520 * n + 20, 1190
    el = [text(Wd / 2, 30, "DECISION: " + case.title, 17, weight="bold"), text(Wd / 2, 52, "Not geometry the rule fixes: pick one. Same view, same scale in every column.", 12.5, PAL["mute"])]
    fx, fy = (case.focus or (0.0, 0.0))
    foc = (fx, fy, case.H)
    rad = max(q for q, _ in case.edges) * 1.15 + 0.6
    for i, (lab, m, vt) in enumerate(cands):
        x0 = 10 + 520 * i
        for ln_i, ln in enumerate(wrap(lab, 62)):
            el.append(text(x0 + 255, 78 + 15 * ln_i, ln, 12.5, PAL["ink"], "bold"))
        el.append(text(x0 + 255, 112, vt, 12, PAL["mute"]))
        el += mesh_panel(Panel(x0, 124, 500, 340), case, m, case.view, 28, "oblique")
        zoom = dict(focus=foc, rad=rad * 2.0) if case.kind in ("adjacent", "corner3", "poly") else {}
        el += mesh_panel(Panel(x0, 474, 500, 340), case, m, 0, 90, "from above", **zoom)
        el += mesh_panel(Panel(x0, 824, 500, 340), case, m, case.view, 22, "corner close-up", focus=foc, rad=rad)
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{Wd}" height="{Hd}" viewBox="0 0 {Wd} {Hd}"><rect width="{Wd}" height="{Hd}" fill="{PAL["bg"]}"/>{"".join(el)}</svg>'
    path = os.path.join(out, case.stem + "-decision.svg")
    open(path, "w").write(svg)
    subprocess.run(["rsvg-convert", "-z", "1.0", "-o", path[:-4] + ".png", path], check=True)
    return [(lab, vt) for lab, m, vt in cands]


def wrap(s, n):
    words, lines, cur = s.split(), [], ""
    for w in words:
        if len(cur) + len(w) + 1 > n:
            lines.append(cur)
            cur = w
        else:
            cur = (cur + " " + w).strip()
    if cur:
        lines.append(cur)
    return lines


if __name__ == "__main__":
    out, bindir, mj = sys.argv[1:4]
    only = sys.argv[4:]
    os.makedirs(out, exist_ok=True)
    res_all = json.load(open(mj))
    for c in C.CASES:
        if only and c.stem not in only:
            continue
        figure(c, bindir, res_all, out)
        if c.decision:
            decision_figure(c, bindir, res_all, out)
        print("rendered", c.stem, flush=True)
