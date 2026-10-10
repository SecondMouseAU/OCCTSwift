#!/usr/bin/env python3
"""Renders for the exactly-meeting-fillet investigation, as SVG then PNG (rsvg-convert).

  render.py <outdir> <meshdump> <sweep results.tsv> <occt1568 model.brep> <window.txt>

No dependencies beyond the standard library and rsvg-convert. Solids are drawn with a painter's algorithm
(flat shading); a configuration that OCCT refuses is drawn as the input box with the requested edges in
red and the shape the fillets would have made, dashed, under a red banner.
"""
import sys, os, math, subprocess, csv, collections
out, MESHDUMP, RESULTS, MODEL, WINDOW = sys.argv[1:6]
os.makedirs(out, exist_ok=True)
PAL = dict(bg="#ffffff", ink="#1d2430", mute="#6b7280", ok="#2f9e5f", fail="#d64545", warn="#e08a1e", crash="#7a1f1f",
           edge="#3a4256", face="#9fb4cc", blue="#2563eb")

def run_dump(args):
    p = subprocess.run([MESHDUMP] + args, capture_output=True, text=True, timeout=120)
    return p.stdout.splitlines()

def proj(p, az=-35, el=28):
    a, e = math.radians(az), math.radians(el)
    x, y, z = p
    x1 = x * math.cos(a) - y * math.sin(a); y1 = x * math.sin(a) + y * math.cos(a)
    return (x1, z * math.cos(e) - y1 * math.sin(e), y1 * math.cos(e) + z * math.sin(e))   # (screen x, screen y up, depth)

def tris_of(lines):
    T, E = [], []
    for l in lines:
        t = l.split()
        if t and t[0] == "T": T.append(([tuple(map(float, t[1 + 3*i:4 + 3*i])) for i in range(3)], int(t[10])))
        if t and t[0] == "E": E.append((tuple(map(float, t[1:4])), tuple(map(float, t[4:7])), t[7] if len(t) > 7 else ""))
    return T, E

def shade(tri):
    (a, b, c) = tri
    u = [b[i] - a[i] for i in range(3)]; v = [c[i] - a[i] for i in range(3)]
    n = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]]
    m = math.sqrt(sum(x*x for x in n)) or 1; n = [x/m for x in n]
    L = (-0.35, -0.55, 0.75); lm = math.sqrt(sum(x*x for x in L)); L = [x/lm for x in L]
    d = max(0.0, sum(n[i]*L[i] for i in range(3)))
    return 0.38 + 0.62 * d

def hexshade(base, f):
    r, g, b = int(base[1:3], 16), int(base[3:5], 16), int(base[5:7], 16)
    return "#%02x%02x%02x" % (min(255, int(r*f)), min(255, int(g*f)), min(255, int(b*f)))

class Panel:
    """A fixed-size drawing area that maps model coordinates to SVG, accumulated as a list of elements."""
    def __init__(self, x0, y0, w, h):
        self.x0, self.y0, self.w, self.h, self.el = x0, y0, w, h, []
        self.scale = 1; self.cx = self.cy = 0
    def fit(self, pts, pad=0.1):
        xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
        self.scale = min(self.w * (1 - 2*pad) / ((max(xs) - min(xs)) or 1), self.h * (1 - 2*pad) / ((max(ys) - min(ys)) or 1))
        self.cx, self.cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    def xy(self, p):
        return (self.x0 + self.w/2 + (p[0] - self.cx) * self.scale, self.y0 + self.h/2 - (p[1] - self.cy) * self.scale)

def svg_text(x, y, s, size=13, fill=PAL["ink"], weight="normal", anchor="middle", family="Helvetica, Arial, sans-serif"):
    s = s.replace("&", "&amp;").replace("<", "&lt;")
    return f'<text x="{x:.1f}" y="{y:.1f}" font-family="{family}" font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">{s}</text>'

def solid_panel(pn, lines, az=-35, el=28, edge_lines=True, alpha=1.0, base=None):
    T, E = tris_of(lines)
    P = [[proj(v, az, el) for v in tri] for tri, _ in T]
    pn.fit([q for t in P for q in t] or [(0, 0)], pad=0.08)
    order = sorted(range(len(T)), key=lambda i: sum(q[2] for q in P[i]) / 3)
    for i in order:
        pts = " ".join("%.1f,%.1f" % pn.xy(q) for q in P[i])
        f = shade([proj(v, az, el)[0:3] if False else v for v in T[i][0]])
        pn.el.append(f'<polygon points="{pts}" fill="{hexshade(base or PAL["face"], f)}" stroke="{hexshade(base or PAL["face"], f)}" stroke-width="0.4" fill-opacity="{alpha}"/>')

def box_wire(pn, dims, edges_red, az=-35, el=28, dashed_profile=None):
    x, y, z = dims
    V = [(a, b, c) for a in (0, x) for b in (0, y) for c in (0, z)]
    E = []
    for a in V:
        for b in V:
            if a < b and sum(1 for i in range(3) if a[i] != b[i]) == 1: E.append((a, b))
    allp = [proj(v, az, el) for v in V]
    pn.fit(allp, pad=0.1)
    # translucent faces
    faces = [[(0,0,0),(x,0,0),(x,0,z),(0,0,z)], [(0,y,0),(x,y,0),(x,y,z),(0,y,z)], [(0,0,0),(0,y,0),(0,y,z),(0,0,z)],
             [(x,0,0),(x,y,0),(x,y,z),(x,0,z)], [(0,0,0),(x,0,0),(x,y,0),(0,y,0)], [(0,0,z),(x,0,z),(x,y,z),(0,y,z)]]
    for f in sorted(faces, key=lambda f: sum(proj(v, az, el)[2] for v in f)):
        pn.el.append('<polygon points="%s" fill="#dbe4f0" fill-opacity="0.55" stroke="none"/>' % " ".join("%.1f,%.1f" % pn.xy(proj(v, az, el)) for v in f))
    for a, b in E:
        mid = tuple((a[i] + b[i]) / 2 for i in range(3))
        red = any(max(abs(mid[i] - m[i]) for i in range(3)) < 1e-9 for m in edges_red)
        p, q = pn.xy(proj(a, az, el)), pn.xy(proj(b, az, el))
        pn.el.append(f'<line x1="{p[0]:.1f}" y1="{p[1]:.1f}" x2="{q[0]:.1f}" y2="{q[1]:.1f}" stroke="{PAL["fail"] if red else PAL["edge"]}" stroke-width="{3.2 if red else 1.1}"/>')

def profile_points(w, h, r, n=24):
    """End-view outline of a w x h rectangle with both top corners rounded by r (r may exceed w/2: the arcs then cross)."""
    pts = [(0, 0), (w, 0), (w, h - r)]
    for k in range(n + 1):
        t = math.pi / 2 * k / n; pts.append((w - r + r * math.cos(t), h - r + r * math.sin(t)))
    for k in range(n + 1):
        t = math.pi / 2 + math.pi / 2 * k / n; pts.append((r + r * math.cos(t), h - r + r * math.sin(t)))
    pts.append((0, h - r)); return pts

def profile_panel(pn, w, h, r, verdict_color, dashed):
    pn.fit([(0, 0), (w, h)], pad=0.14)
    pts = profile_points(w, h, r)
    d = "M " + " L ".join("%.1f,%.1f" % pn.xy(p) for p in pts) + " Z"
    pn.el.append(f'<path d="{d}" fill="{PAL["face"]}" fill-opacity="{0.0 if dashed else 0.7}" stroke="{verdict_color}" stroke-width="2" {"stroke-dasharray=\"6 4\"" if dashed else ""}/>')
    # the two tangent lines on the top face, and the apex
    for xx in (r, w - r):
        p = pn.xy((xx, h)); pn.el.append(f'<circle cx="{p[0]:.1f}" cy="{p[1]:.1f}" r="3" fill="{PAL["blue"]}"/>')

def write_svg(path, W, H, elements, title=None):
    body = "\n".join(elements)
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}"><rect width="{W}" height="{H}" fill="{PAL["bg"]}"/>{body}</svg>'
    open(path, "w").write(svg)
    subprocess.run(["rsvg-convert", "-z", "1.6", "-o", path[:-4] + ".png", path], check=True)

# ---------------------------------------------------------------- figure 1: the forum case
def fig_forum():
    cases = [("r = 1.9", 1.9, None), ("r = 1.9999", 1.9999, None), ("r = 2 (exactly half of 4)", 2.0, None), ("r = 2.0001", 2.0001, None)]
    W, H = 1400, 760; el = []
    el.append(svg_text(W/2, 34, "Two fillets on opposite edges of a 4 mm wide face (box 4 x 10 x 6)", 20, weight="bold"))
    el.append(svg_text(W/2, 58, "OCCT 8.0.1 BRepFilletAPI_MakeFillet, kernel.4 and kernel.5 identical. Blue dots: where each blend's tangent line meets the top face.", 13, PAL["mute"]))
    for i, (label, r, _) in enumerate(cases):
        x0 = 20 + i * 345
        lines = run_dump(["fillet", "4", "10", "6", repr(r), "0,5,6", "4,5,6"])
        failed = lines and lines[0] == "FAIL"
        top = Panel(x0, 80, 335, 330); bot = Panel(x0, 440, 335, 230)
        if failed:
            box_wire(top, (4, 10, 6), [(0, 5, 6), (4, 5, 6)])
            col, banner = PAL["fail"], "IsDone() = false"
        else:
            solid_panel(top, lines); col, banner = PAL["ok"], "valid solid"
        profile_panel(bot, 4, 6, r, col, dashed=failed)
        el += top.el + bot.el
        el.append(svg_text(x0 + 167, 98, label, 15, weight="bold"))
        el.append(f'<rect x="{x0+60}" y="410" width="215" height="24" rx="12" fill="{col}"/>')
        el.append(svg_text(x0 + 167, 427, banner, 13, "#ffffff", "bold"))
        why = {"r = 2 (exactly half of 4)": "OneCorner: fillets have too big radiuses", "r = 2.0001": "same message (arcs now cross)"}.get(label, "flat strip of %.4g mm remains" % (4 - 2*r))
        el.append(svg_text(x0 + 167, 688, why, 12, PAL["mute"]))
        el.append(svg_text(x0 + 167, 706, "end view of the y = 0 face" if i == 0 else "", 11, PAL["mute"]))
    el.append(svg_text(W/2, 740, "Failure is raised at the box corners, not along the fillets: NbFaultyContours = 0, NbFaultyVertices = 2.", 13, PAL["ink"]))
    write_svg(os.path.join(out, "forum-case-two-fillets-meeting.svg"), W, H, el)

# ---------------------------------------------------------------- figure 2: the sweep map
def fig_sweep():
    rows = list(csv.DictReader(open(RESULTS), delimiter="\t"))
    labels = ["0.5c", "c-1e-3", "c-1e-4", "c-1e-8", "c-1ulp", "c", "c+1ulp", "c+1e-8", "c+1e-4", "c+1e-3", "1.5c"]
    names = {"c-1e-3": "c-1e-3", "c-1e-4": "c-1e-4", "c-1e-8": "c-1e-8", "c-1ulp": "c-1ulp", "c": "c", "c+1ulp": "c+1ulp", "c+1e-8": "c+1e-8", "c+1e-4": "c+1e-4", "c+1e-3": "c+1e-3", "0.5c": "0.5c", "1.5c": "1.5c"}
    piv = collections.OrderedDict()
    for r in rows:
        if r["kernel"] == "k5" and r["mode"] == "add": piv.setdefault((r["case"], r["crit"]), {})[r["label"]] = r["outcome"]
    cw, ch, left, top = 74, 26, 300, 110
    W, H = left + cw * len(labels) + 30, top + ch * len(piv) + 90
    el = [svg_text(W/2, 32, "Does a fillet that meets exactly work? Radius swept around c (the radius at which the blends meet)", 18, weight="bold"),
          svg_text(W/2, 54, "One process per case, box fillets through BRepFilletAPI_MakeFillet (one builder, one Add per edge). Green valid, red IsDone() false, orange done but BRepCheck-invalid.", 12, PAL["mute"])]
    for j, l in enumerate(labels): el.append(svg_text(left + cw*j + cw/2, top - 10, names[l], 12, PAL["ink"], "bold"))
    col = {"valid": PAL["ok"], "IsDone=false": PAL["fail"], "done, INVALID": PAL["warn"]}
    for i, ((case, crit), v) in enumerate(piv.items()):
        y = top + ch * i
        el.append(svg_text(left - 10, y + 17, f"{case}  c = {crit}", 12, PAL["ink"], anchor="end"))
        for j, l in enumerate(labels):
            o = v.get(l, ""); c = col.get(o, PAL["crash"])
            el.append(f'<rect x="{left+cw*j+2}" y="{y+2}" width="{cw-4}" height="{ch-4}" rx="4" fill="{c}"/>')
            el.append(svg_text(left + cw*j + cw/2, y + 17, {"valid": "ok", "IsDone=false": "fail", "done, INVALID": "INVALID"}.get(o, o), 11, "#ffffff", "bold"))
    el.append(svg_text(W/2, H - 40, "c-1ulp, c, c+1ulp are the doubles either side of c. No case crashed, and kernel.4 (no patch 0054) gave the same table as kernel.5.", 12, PAL["mute"]))
    el.append(svg_text(W/2, H - 20, "Rows with c = a face width (C4, C5, C6, c = 4): one blend reaches the opposite edge, the other family in OCCT#1177.", 12, PAL["mute"]))
    write_svg(os.path.join(out, "sweep-map-box-cases.svg"), W, H, el)

# ---------------------------------------------------------------- figure 3: the reporter's model
def fig_reporter():
    lines = run_dump(["brep", MODEL] + [str(i) for i in range(1, 43)])
    T, E = tris_of(lines)
    W, H = 1500, 840; el = []
    el.append(svg_text(W/2, 34, "The reporter's model (OCCT#1568 / FreeCAD#25289): fillet r = 1.5 on edge 13", 20, weight="bold"))
    # left: iso view with edge 13 highlighted
    pn = Panel(10, 60, 800, 600)
    az, elv = -30, 32
    P = [[proj(v, az, elv) for v in tri] for tri, _ in T]
    pn.fit([q for t in P for q in t], pad=0.06)
    for i in sorted(range(len(T)), key=lambda i: sum(q[2] for q in P[i]) / 3):
        pts = " ".join("%.1f,%.1f" % pn.xy(q) for q in P[i]); f = shade(T[i][0])
        pn.el.append(f'<polygon points="{pts}" fill="{hexshade(PAL["face"], f)}" stroke="{hexshade(PAL["face"], f)}" stroke-width="0.3"/>')
    for a, b, tag in E:
        if tag != "13": continue
        p, q = pn.xy(proj(a, az, elv)), pn.xy(proj(b, az, elv))
        pn.el.append(f'<line x1="{p[0]:.1f}" y1="{p[1]:.1f}" x2="{q[0]:.1f}" y2="{q[1]:.1f}" stroke="{PAL["fail"]}" stroke-width="4"/>')
    cl0, cl1 = pn.xy(proj((-55.25, 1.5, 20), az, elv)), pn.xy(proj((55.25, 1.5, 20), az, elv))
    pn.el.append(f'<line x1="{cl0[0]:.1f}" y1="{cl0[1]:.1f}" x2="{cl1[0]:.1f}" y2="{cl1[1]:.1f}" stroke="{PAL["blue"]}" stroke-width="2.4" stroke-dasharray="7 4"/>')
    el += pn.el
    el.append(svg_text(410, 705, "red: edge 13 (the edge filleted).  blue dashed: where a radius 1.5 blend meets the top face (offset 1.5 from edge 13).", 12, PAL["mute"]))
    # right: top-down zoom at the +x end, feature lines only
    z = Panel(830, 60, 660, 470)
    x_lo, x_hi, y_lo, y_hi = 44, 62, -4, 14
    z.scale = min(z.w / (x_hi - x_lo), z.h / (y_hi - y_lo)); z.cx, z.cy = (x_lo + x_hi) / 2, (y_lo + y_hi) / 2
    z.el.append(f'<rect x="{z.x0}" y="{z.y0}" width="{z.w}" height="{z.h}" fill="#f3f6fa" stroke="{PAL["mute"]}"/>')
    for a, b, tag in E:
        if not (a[2] > 19.9 or True): continue
        if not ((x_lo - 2 <= a[0] <= x_hi + 2) and (y_lo - 2 <= a[1] <= y_hi + 2)): continue
        p, q = z.xy((a[0], a[1])), z.xy((b[0], b[1]))
        isel = tag == "13"
        z.el.append(f'<line x1="{p[0]:.1f}" y1="{p[1]:.1f}" x2="{q[0]:.1f}" y2="{q[1]:.1f}" stroke="{PAL["fail"] if isel else PAL["edge"]}" stroke-width="{3.5 if isel else 1.3}"/>')
    c0, c1 = z.xy((x_lo, 1.5)), z.xy((x_hi, 1.5))
    z.el.append(f'<line x1="{c0[0]:.1f}" y1="{c0[1]:.1f}" x2="{c1[0]:.1f}" y2="{c1[1]:.1f}" stroke="{PAL["blue"]}" stroke-width="2.2" stroke-dasharray="7 4"/>')
    v = z.xy((55.25, 1.5)); z.el.append(f'<circle cx="{v[0]:.1f}" cy="{v[1]:.1f}" r="7" fill="none" stroke="{PAL["warn"]}" stroke-width="3"/>')
    el.append('<clipPath id="zc"><rect x="%d" y="%d" width="%d" height="%d"/></clipPath><g clip-path="url(#zc)">' % (z.x0, z.y0, z.w, z.h)); el += z.el; el.append('</g>')
    el.append(svg_text(1160, 552, "top view, +x end of edge 13 (x 44 to 62, y -4 to 14)", 13, PAL["ink"], "bold"))
    el.append(svg_text(1160, 572, "orange ring: vertex v12 at x = 55.25, exactly 1.5 from edge 13", 12, PAL["mute"]))
    el.append(svg_text(1160, 590, "the existing r = 1.5 round (torus f9) ends there, so the new blend's", 12, PAL["mute"]))
    el.append(svg_text(1160, 608, "boundary runs exactly through the existing round's end vertex", 12, PAL["mute"]))
    # bottom: the window
    wl = [l.split() for l in open(WINDOW).read().splitlines()[1:] if l.strip()]
    x0, y0, bw = 40, 775, 1420
    el.append(svg_text(x0, y0 - 38, "edge 13 alone, radius r: kernel.4 / kernel.5", 12, PAL["ink"], "bold", "start"))
    cwid = bw / len(wl)
    colmap = {"done": PAL["ok"], "IsDone=false": PAL["fail"], "SIGSEGV": PAL["crash"]}
    for i, w in enumerate(wl):
        r, k4, k5 = w[0], w[1], w[2]
        el.append(f'<rect x="{x0+i*cwid:.1f}" y="{y0-26}" width="{cwid-2:.1f}" height="18" fill="{colmap.get(k4, PAL["mute"])}"/>')
        el.append(f'<rect x="{x0+i*cwid:.1f}" y="{y0-6}" width="{cwid-2:.1f}" height="18" fill="{colmap.get(k5, PAL["mute"])}"/>')
        if i % 2 == 0 or r == "1.5": el.append(svg_text(x0 + i*cwid + cwid/2, y0 + 28, r[:11], 8.5, PAL["mute"]))
    el.append(svg_text(x0, y0 + 48, "green: IsDone true   red: IsDone false   dark red: SIGSEGV.  Top strip kernel.4 (no patch 0054), bottom kernel.5.  Crash only within 1e-9 of 1.5; IsDone false from 1.49853.", 12, PAL["ink"], anchor="start"))
    write_svg(os.path.join(out, "reporter-case-edge13-radius-1.5.svg"), W, H, el)

# ---------------------------------------------------------------- figure 4: result gallery of valid near-critical solids
fig_forum(); fig_sweep(); fig_reporter()
print("rendered")
