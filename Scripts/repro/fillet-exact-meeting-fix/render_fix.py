#!/usr/bin/env python3
"""Renders for the exact-meeting fillet fix, SVG then PNG (rsvg-convert). Standard library only.

  render_fix.py <outdir> <meshdump_baseline> <meshdump_patched> [<fillet-sweep.tsv>]

For each radius: the end-view cross-section (looking along Y) with the ANALYTIC profile overlaid,
the patched kernel's result in 3D with its edges drawn, and the reference construction (the
intersection of the two single-edge fillets, not part of the patch). Status chips say valid /
invalid / failed and give the volume against the analytic one (oracle.py).
"""
import sys, os, math, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import oracle

out, MD_BASE, MD_PATCH = sys.argv[1:4]
os.makedirs(out, exist_ok=True)
W_, H_, L_ = 4.0, 6.0, 10.0
PAL = dict(bg="#ffffff", ink="#1d2430", mute="#6b7280", ok="#2f9e5f", fail="#d64545", warn="#e08a1e",
           edge="#2b3345", face="#9fb4cc", blue="#2563eb")

def dump(exe, mode, r):
    p = subprocess.run([exe, mode, "4", "10", "6", repr(r), "0,5,6", "4,5,6"], capture_output=True, text=True, timeout=120)
    ls = p.stdout.splitlines()
    if not ls or ls[0] == "FAIL": return None
    st = dict(t.split("=") for t in ls[0].split()[1:])
    T, E = [], []
    for l in ls[1:]:
        t = l.split()
        if t[0] == "T": T.append([tuple(map(float, t[1 + 3 * i:4 + 3 * i])) for i in range(3)])
        elif t[0] == "E": E.append((tuple(map(float, t[1:4])), tuple(map(float, t[4:7]))))
    return dict(valid=st["valid"] == "1", vol=float(st["vol"]), T=T, E=E)

def proj(p, az=-38, el=26):
    a, e = math.radians(az), math.radians(el)
    x, y, z = p
    x1 = x * math.cos(a) - y * math.sin(a); y1 = x * math.sin(a) + y * math.cos(a)
    return (x1, z * math.cos(e) - y1 * math.sin(e), y1 * math.cos(e) + z * math.sin(e))

def shade(tri):
    a, b, c = tri
    u = [b[i] - a[i] for i in range(3)]; v = [c[i] - a[i] for i in range(3)]
    n = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
    m = math.sqrt(sum(x * x for x in n)) or 1; n = [x / m for x in n]
    L = (-0.35, -0.55, 0.75); lm = math.sqrt(sum(x * x for x in L)); L = [x / lm for x in L]
    return 0.38 + 0.62 * max(0.0, sum(n[i] * L[i] for i in range(3)))

def hexshade(base, f):
    r, g, b = int(base[1:3], 16), int(base[3:5], 16), int(base[5:7], 16)
    return "#%02x%02x%02x" % (min(255, int(r * f)), min(255, int(g * f)), min(255, int(b * f)))

def text(x, y, s, size=13, fill=PAL["ink"], weight="normal", anchor="middle"):
    s = s.replace("&", "&amp;").replace("<", "&lt;")
    return f'<text x="{x:.1f}" y="{y:.1f}" font-family="Helvetica, Arial, sans-serif" font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">{s}</text>'

def chip(x, y, w, label, color):
    return (f'<rect x="{x - w / 2:.1f}" y="{y - 16}" width="{w}" height="24" rx="12" fill="{color}"/>' + text(x, y, label, 12.5, "#ffffff", "bold"))

class Panel:
    def __init__(self, x0, y0, w, h): self.x0, self.y0, self.w, self.h = x0, y0, w, h
    def fit(self, pts, pad=0.1):
        xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
        self.s = min(self.w * (1 - 2 * pad) / ((max(xs) - min(xs)) or 1), self.h * (1 - 2 * pad) / ((max(ys) - min(ys)) or 1))
        self.cx, self.cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    def xy(self, p): return (self.x0 + self.w / 2 + (p[0] - self.cx) * self.s, self.y0 + self.h / 2 - (p[1] - self.cy) * self.s)

def solid(pn, res):
    """Painter's algorithm: triangles and edge segments in one depth-sorted list, so hidden edges are covered."""
    prim = []
    for tri in res["T"]:
        P = [proj(v) for v in tri]
        prim.append((sum(q[2] for q in P) / 3, "t", P, shade(tri)))
    for a, b in res["E"]:
        P = [proj(a), proj(b)]
        prim.append(((P[0][2] + P[1][2]) / 2 - 0.05, "e", P, 0))
    pn.fit([q for _, _, P, _ in prim for q in P])
    el = []
    for _, k, P, f in sorted(prim, key=lambda t: t[0]):
        if k == "t":
            c = hexshade(PAL["face"], f)
            el.append(f'<polygon points="{" ".join("%.1f,%.1f" % pn.xy(q) for q in P)}" fill="{c}" stroke="{c}" stroke-width="0.5"/>')
        else:
            p, q = pn.xy(P[0]), pn.xy(P[1])
            el.append(f'<line x1="{p[0]:.1f}" y1="{p[1]:.1f}" x2="{q[0]:.1f}" y2="{q[1]:.1f}" stroke="{PAL["edge"]}" stroke-width="1.5" stroke-linecap="round"/>')
    return el

def input_box(pn, red):
    V = [(a, b, c) for a in (0, W_) for b in (0, L_) for c in (0, H_)]
    pn.fit([proj(v) for v in V])
    el = []
    for a in V:
        for b in V:
            if a < b and sum(1 for i in range(3) if a[i] != b[i]) == 1:
                mid = tuple((a[i] + b[i]) / 2 for i in range(3)); isred = any(max(abs(mid[i] - m[i]) for i in range(3)) < 1e-9 for m in red)
                p, q = pn.xy(proj(a)), pn.xy(proj(b))
                el.append(f'<line x1="{p[0]:.1f}" y1="{p[1]:.1f}" x2="{q[0]:.1f}" y2="{q[1]:.1f}" stroke="{PAL["fail"] if isred else PAL["mute"]}" stroke-width="{3.4 if isred else 1.2}"/>')
    return el

def analytic_profile(r, n=60):
    """Top profile (x, z) of the kept region, left to right: left side up, the two arcs, right side down."""
    pts = [(0, 0), (0, H_ - r)]
    def zl(x): return H_ - r + math.sqrt(max(r * r - (x - r) ** 2, 0)) if x < r else H_
    def zr(x): return H_ - r + math.sqrt(max(r * r - (x - (W_ - r)) ** 2, 0)) if x > W_ - r else H_
    for k in range(1, n):
        x = W_ * k / n; pts.append((x, min(zl(x), zr(x))))
    pts += [(W_, H_ - r), (W_, 0)]
    return pts

def section(pn, r, res):
    pn.fit([(-0.4, -0.6), (W_ + 0.4, H_ + 0.9)], pad=0.04)
    el = [f'<rect x="{pn.x0}" y="{pn.y0}" width="{pn.w}" height="{pn.h}" fill="#f6f8fb" stroke="#d5dbe5"/>']
    box = [(0, 0), (W_, 0), (W_, H_), (0, H_), (0, 0)]
    el.append(f'<path d="M {" L ".join("%.1f,%.1f" % pn.xy(p) for p in box)}" fill="none" stroke="{PAL["mute"]}" stroke-width="1" stroke-dasharray="2 4"/>')
    pr = analytic_profile(r)
    el.append(f'<path d="M {" L ".join("%.1f,%.1f" % pn.xy(p) for p in pr)} Z" fill="{PAL["blue"]}" fill-opacity="0.07" stroke="{PAL["blue"]}" stroke-width="2.2" stroke-dasharray="7 4"/>')
    if res:
        col = PAL["ok"] if res["valid"] else PAL["warn"]
        for a, b in res["E"]:                       # the end face y = 0 is the cross-section
            if abs(a[1]) < 1e-6 and abs(b[1]) < 1e-6:
                p, q = pn.xy((a[0], a[2])), pn.xy((b[0], b[2]))
                el.append(f'<line x1="{p[0]:.1f}" y1="{p[1]:.1f}" x2="{q[0]:.1f}" y2="{q[1]:.1f}" stroke="{col}" stroke-width="3.2" stroke-linecap="round"/>')
    if r >= W_ / 2 - 1e-12:
        ys = H_ - r + math.sqrt(max(W_ * r - W_ * W_ / 4, 0))
        p = pn.xy((W_ / 2, ys)); el.append(f'<circle cx="{p[0]:.1f}" cy="{p[1]:.1f}" r="4.5" fill="{PAL["blue"]}"/>')
        ang = 180 - 2 * math.degrees(math.asin(max(r - W_ / 2, 0) / r))
        el.append(text(p[0], p[1] - 12, "arcs meet at %.2f mm above the base, %.2f deg between them" % (ys, ang) if r > W_ / 2 + 1e-9 else "arcs meet tangentially: a semicircle (180 deg)", 11.5, PAL["blue"], "bold"))
    return el

def figure(label, r):
    base = dump(MD_BASE, "fillet", r); patched = dump(MD_PATCH, "fillet", r); ref = dump(MD_PATCH, "common", r)
    ov = oracle.volume(W_, H_, L_, r)
    Wd, Hd = 1560, 600
    el = [text(Wd / 2, 34, "Two fillets of radius %s on the top edges of a 4 x 10 x 6 box (face 4 mm wide)" % label, 20, weight="bold"),
          text(Wd / 2, 56, "analytic volume %.6f; analytic profile dashed blue; end view looks along Y" % ov, 13, PAL["mute"])]
    A, B, C = Panel(20, 80, 480, 400), Panel(520, 80, 520, 400), Panel(1060, 80, 480, 400)
    el += section(A, r, patched)
    el.append(text(260, 504, "cross-section: analytic profile vs the patched kernel's end face", 12, PAL["mute"]))
    def status(res):
        if res is None: return "IsDone() = false", PAL["fail"]
        d = res["vol"] - ov
        return ("valid, volume %.6f (%+.1e)" % (res["vol"], d) if res["valid"] else "done but INVALID, volume %.3f (%+.3f)" % (res["vol"], d)), (PAL["ok"] if res["valid"] else PAL["warn"])
    # patched kernel panel
    if patched: el += solid(B, patched)
    else: el += input_box(B, [(0, 5, 6), (4, 5, 6)])
    s, c = status(patched); el.append(chip(780, 504, 400, "patched kernel: " + s, c))
    s0, c0 = status(base); el.append(chip(780, 540, 400, "kernel.5 (unpatched): " + s0, c0))
    el.append(text(780, 572, "3D result with edges drawn" if patched else "failed: the input box, filleted edges red", 12, PAL["mute"]))
    if ref: el += solid(C, ref)
    s2, c2 = status(ref); el.append(chip(1300, 504, 470, "reference (Common): " + s2, c2))
    el.append(text(1300, 540, "not in the patch: shows what r > w/2 should look like", 12, PAL["mute"]))
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{Wd}" height="{Hd}" viewBox="0 0 {Wd} {Hd}"><rect width="{Wd}" height="{Hd}" fill="{PAL["bg"]}"/>{"".join(el)}</svg>'
    name = "r-" + label.replace(".", "_")
    path = os.path.join(out, name + ".svg"); open(path, "w").write(svg)
    subprocess.run(["rsvg-convert", "-z", "1.4", "-o", path[:-4] + ".png", path], check=True)
    return name, base, patched, ref, ov

if __name__ == "__main__":
    rows = []
    for lab, r in [("1.9999", 1.9999), ("2.0", 2.0), ("2.0001", 2.0001), ("2.2", 2.2), ("2.5", 2.5), ("3.0", 3.0)]:
        rows.append((lab,) + figure(lab, r))
    with open(os.path.join(out, "table.tsv"), "w") as f:
        f.write("r\tfile\tkernel5\tpatched\treference\tanalytic\n")
        for lab, name, base, patched, ref, ov in rows:
            fmt = lambda x: "IsDone false" if x is None else ("valid %.6f" % x["vol"] if x["valid"] else "INVALID %.3f" % x["vol"])
            f.write(f"{lab}\t{name}.png\t{fmt(base)}\t{fmt(patched)}\t{fmt(ref)}\t{ov:.6f}\n")
    print(open(os.path.join(out, "table.tsv")).read())
