#!/usr/bin/env python3
"""Renders for the reporter-window investigation (OCCT#1568), SVG then PNG (rsvg-convert), standard library only.

  render.py <outdir> <meshdump> <model.brep> <window.tsv> [label]

One figure per radius: the whole model, a close-up on the corner where the blend meets the existing r = 1.5
round (x = -53.75, y = 0), and a close-up on the far corner (x = -53.75, y = 88, the vertex whose 1.01e-3
tolerance sets the width of the window).  An IsDone() false result is drawn as the input with edge 13 in red under a
banner; a done result BRepCheck rejects is drawn as it came back, under an orange banner.  A last figure maps the
outcome against the radius."""
import sys, os, math, subprocess, csv
out, DUMP, MODEL, WINDOW = sys.argv[1:5]
LABEL = sys.argv[5] if len(sys.argv) > 5 else "pinned kernel (v4.0.0-kernel.5)"
os.makedirs(out, exist_ok=True)
PAL = dict(bg="#ffffff", ink="#1d2430", mute="#6b7280", ok="#2f9e5f", fail="#d64545", warn="#e08a1e", crash="#7a1f1f", face="#9fb4cc", edge="#3a4256")

def dump(args):
    p = subprocess.run([DUMP, MODEL] + args, capture_output=True, text=True, timeout=120)
    T, E, info = [], [], {}
    for l in p.stdout.splitlines():
        t = l.split()
        if not t: continue
        if t[0] == "T": T.append([tuple(map(float, t[1 + 3*i:4 + 3*i])) for i in range(3)])
        elif t[0] == "E": E.append((tuple(map(float, t[1:4])), tuple(map(float, t[4:7]))))
        elif t[0] == "FAIL": info["fail"] = t[1]
        elif t[0] == "INFO": info["valid"] = t[1] == "valid=1"
    return T, E, info

def proj(p, az, el):
    a, e = math.radians(az), math.radians(el)
    x, y, z = p
    x1 = x * math.cos(a) - y * math.sin(a); y1 = x * math.sin(a) + y * math.cos(a)
    return (x1, z * math.cos(e) - y1 * math.sin(e), y1 * math.cos(e) + z * math.sin(e))

def shade(tri):
    a, b, c = tri
    u = [b[i] - a[i] for i in range(3)]; v = [c[i] - a[i] for i in range(3)]
    n = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]]
    m = math.sqrt(sum(x*x for x in n)) or 1; n = [x/m for x in n]
    L = (-0.35, -0.55, 0.75); lm = math.sqrt(sum(x*x for x in L)); L = [x/lm for x in L]
    return 0.38 + 0.62 * max(0.0, sum(n[i]*L[i] for i in range(3)))

def hexshade(base, f):
    r, g, b = int(base[1:3], 16), int(base[3:5], 16), int(base[5:7], 16)
    return "#%02x%02x%02x" % (min(255, int(r*f)), min(255, int(g*f)), min(255, int(b*f)))

def txt(x, y, s, size=13, fill=PAL["ink"], weight="normal", anchor="middle"):
    s = s.replace("&", "&amp;").replace("<", "&lt;")
    return f'<text x="{x:.1f}" y="{y:.1f}" font-family="Helvetica, Arial, sans-serif" font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">{s}</text>'

def panel(x0, y0, w, h, T, E, az, el, centre=None, half=None, colour=None, edge_colour=PAL["fail"], title=""):
    """Draw triangles T (cropped to a cube of half-size `half` around `centre` when given) fitted into the w x h box."""
    els = [f'<rect x="{x0}" y="{y0}" width="{w}" height="{h}" fill="#f7f8fa" stroke="#d6dae0"/>']
    keep = []
    for t in T:
        if centre:
            cx = sum(v[0] for v in t) / 3; cy = sum(v[1] for v in t) / 3; cz = sum(v[2] for v in t) / 3
            if max(abs(cx - centre[0]), abs(cy - centre[1]), abs(cz - centre[2])) > half: continue
        keep.append(t)
    P = [[proj(v, az, el) for v in t] for t in keep]
    pts = [q for t in P for q in t] or [(0, 0, 0)]
    if centre:
        c = proj(centre, az, el); ext = half * 1.5
        xs = [c[0] - ext, c[0] + ext]; ys = [c[1] - ext, c[1] + ext]
    else:
        xs = [q[0] for q in pts]; ys = [q[1] for q in pts]
    sc = min(w * 0.92 / ((max(xs) - min(xs)) or 1), (h - 26) * 0.92 / ((max(ys) - min(ys)) or 1))
    mx, my = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    xy = lambda q: (x0 + w / 2 + (q[0] - mx) * sc, y0 + 26 + (h - 26) / 2 - (q[1] - my) * sc)
    order = sorted(range(len(keep)), key=lambda i: sum(q[2] for q in P[i]) / 3)
    for i in order:
        f = shade(keep[i]); col = hexshade(colour or PAL["face"], f)
        els.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="0.4"/>' % (" ".join("%.1f,%.1f" % xy(q) for q in P[i]), col, col))
    for a, b in E:
        if centre and max(abs(a[i] - centre[i]) for i in range(3)) > half * 1.6: continue
        p, q = xy(proj(a, az, el)), xy(proj(b, az, el))
        els.append(f'<line x1="{p[0]:.1f}" y1="{q[1] if False else p[1]:.1f}" x2="{q[0]:.1f}" y2="{q[1]:.1f}" stroke="{edge_colour}" stroke-width="3"/>'.replace(f'x1="{p[0]:.1f}"', f'x1="{p[0]:.1f}"'))
    els.append(txt(x0 + 8, y0 + 17, title, 12, PAL["mute"], anchor="start"))
    return els

def rows(path):
    with open(path) as f: return list(csv.DictReader(f, delimiter="\t"))

VIEWS = [("whole model", None, None, -35, 28), ("front corner, x = -53.75, y = 0 (blend meets the r = 1.5 round)", (-53.75, 0.0, 19.0), 4.5, -150, 32),
         ("far corner, x = -53.75, y = 88 (vertex tol 1.01e-3)", (-53.75, 87.9, 19.4), 3.5, -30, 28)]
RADII = [1.45, 1.4985, 1.5, 1.5001, 1.55]
verdicts = {}
for r in RADII:
    T, E, info = dump([repr(r), "13", "draw"])
    if "fail" in info:
        T, E, _ = dump(["input", "13"])
        banner, colr = ("IsDone() false (%s): the input is drawn, edge 13 in red" % info["fail"], PAL["fail"] if info["fail"] == "notdone" else PAL["crash"])
        base = "#c9d1dc"
    elif not info.get("valid", True):
        banner, colr, base = ("DONE but BRepCheck says INVALID: this is what Shape.filleted would hand back", PAL["warn"], "#e8c79a")
    else:
        banner, colr, base = ("done, valid", PAL["ok"], PAL["face"])
    verdicts[r] = banner
    W, H = 1500, 560
    el = [f'<rect width="{W}" height="{H}" fill="{PAL["bg"]}"/>', txt(24, 32, "edge 13 of the reporter's model filleted at r = %s" % repr(r), 20, anchor="start", weight="bold"),
          txt(24, 54, LABEL, 13, PAL["mute"], anchor="start"), f'<rect x="24" y="66" width="{W-48}" height="30" fill="{colr}" fill-opacity="0.14" stroke="{colr}"/>',
          txt(W / 2, 87, banner, 15, colr, "bold")]
    pw = (W - 48 - 2 * 12) / 3
    for k, (title, centre, half, az, el_) in enumerate(VIEWS):
        el += panel(24 + k * (pw + 12), 108, pw, 430, T, E, az, el_, centre, half, base, PAL["fail"], title)
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">' + "\n".join(el) + "</svg>"
    name = os.path.join(out, "edge13-r%s.svg" % repr(r).replace(".", "_"))
    open(name, "w").write(svg); subprocess.run(["rsvg-convert", "-z", "1.4", "-o", name[:-4] + ".png", name], check=True)
    print(r, banner)

# outcome strip from the dense window table
R = rows(WINDOW)
R = [x for x in R if 1.4975 <= float(x["radius"]) <= 1.5025]
R.sort(key=lambda x: float(x["radius"]))
W, H = 1500, 300
el = [f'<rect width="{W}" height="{H}" fill="{PAL["bg"]}"/>', txt(24, 32, "Outcome against radius, edge 13 (draw parameters), " + LABEL, 17, anchor="start", weight="bold")]
lo, hi = 1.4975, 1.5025
X = lambda r: 60 + (r - lo) / (hi - lo) * (W - 120)
def cls(x):
    s = x["status"]
    if s == "done": return (PAL["ok"], "valid") if x["valid"] == "1" else (PAL["warn"], "done, INVALID")
    if s.startswith("signal"): return (PAL["crash"], "SIGSEGV")
    return (PAL["fail"], "IsDone() false")
for i, x in enumerate(R):
    r = float(x["radius"]); c, _ = cls(x)
    x0 = X(r); x1 = X(float(R[i + 1]["radius"])) if i + 1 < len(R) else x0 + 6
    el.append(f'<rect x="{x0:.1f}" y="90" width="{max(x1 - x0, 2):.1f}" height="90" fill="{c}"/>')
for r in (1.4975, 1.498, 1.4985, 1.499, 1.4995, 1.5, 1.5005, 1.501, 1.5015, 1.502, 1.5025):
    el.append(f'<line x1="{X(r):.1f}" y1="180" x2="{X(r):.1f}" y2="188" stroke="{PAL["ink"]}"/>' + txt(X(r), 206, "%.4f" % r, 12))
for c, s, k in ((PAL["ok"], "valid", 0), (PAL["warn"], "done but BRepCheck invalid", 1), (PAL["fail"], "IsDone() false", 2), (PAL["crash"], "SIGSEGV (kernel.4 only)", 3)):
    el.append(f'<rect x="{60 + k * 300}" y="240" width="16" height="16" fill="{c}"/>' + txt(84 + k * 300, 253, s, 13, anchor="start"))
svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">' + "\n".join(el) + "</svg>"
name = os.path.join(out, "outcome-strip.svg"); open(name, "w").write(svg); subprocess.run(["rsvg-convert", "-z", "1.2", "-o", name[:-4] + ".png", name], check=True)
