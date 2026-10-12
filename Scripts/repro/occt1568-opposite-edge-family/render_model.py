#!/usr/bin/env python3
"""Figures for the model attached to OCCT#1568 (FreeCAD#25289): the input with its edges, the outcome table, and results.

  render_model.py <outdir> <model.brep> <k5 dir with brepfillet_k5> <brepfillet_ir.sh> <brepfillet_new.sh> <meshdump_ir.sh> <meshdump_new.sh>
"""
import sys, os, subprocess, math
sys.argv_saved = sys.argv[:]
OUT, MODEL, BF_K5, BF_IR, BF_NEW, MD_IR, MD_NEW = sys.argv[1:8]
sys.argv = [sys.argv[0], OUT, "-", "-", "-"]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render as R
from render import PAL, text, chip, Panel, solid, proj, hexshade

INNER = [13, 14, 15, 16, 17, 18, 19, 12]
OUTER = [3, 9, 11, 6]
SETS = [("outer 4 (3 9 11 6)", OUTER), ("inner 8 (12 to 19)", INNER), ("all 12 (the script)", OUTER + INNER)]
RADII = ["1.0", "1.49", "1.4999999", "1.5", "1.5000001", "1.6"]


def run(exe, r, es):
    p = subprocess.run([exe, MODEL, r] + [str(e) for e in es], capture_output=True, text=True, timeout=120)
    ls = [l for l in p.stdout.splitlines() if l.startswith("RESULT")]
    if not ls:
        return ("none", "")
    l = ls[0]
    if "SIGNAL" in l:
        return ("SIGSEGV", PAL["fail"])
    kv = dict(t.split("=") for t in l.split()[1:] if "=" in t)
    if kv["done"] == "0":
        return ("declined", PAL["warn"])
    if kv["valid"] == "1":
        return ("valid %.1f" % float(kv["vol"]), PAL["ok"])
    return ("INVALID %.0f" % float(kv["vol"]), PAL["fail"])


def table():
    rows = []
    for name, es in SETS:
        for r in RADII:
            rows.append((name, r, run(BF_K5, r, es), run(BF_IR, r, es), run(BF_NEW, r, es)))
    with open(os.path.join(OUT, "model-1568.tsv"), "w") as f:
        f.write("edges\tradius\tkernel5\tIR_before\tIR_with_series\n")
        for n, r, a, b, c in rows:
            f.write(f"{n}\t{r}\t{a[0]}\t{b[0]}\t{c[0]}\n")
    return rows


def fig_table(rows):
    Wd, Hd = 1500, 140 + 26 * len(rows)
    el = [text(Wd / 2, 34, "The model of OCCT#1568: every radius, every edge set, three kernels (one process per cell)", 19, weight="bold")]
    x = [40, 330, 470, 860, 1180]
    for i, h in enumerate(["edge set", "radius", "kernel.5 (8.0.1, pinned)", "upstream IR before", "IR with this series"]):
        el.append(text(x[i], 80, h, 13, PAL["ink"], "bold", "start"))
    for k, (n, r, a, b, c) in enumerate(rows):
        y = 112 + 26 * k
        el.append(text(x[0], y, n, 12.5, PAL["ink"], "normal", "start"))
        el.append(text(x[1], y, r, 12.5, PAL["ink"], "normal", "start"))
        for j, cell in enumerate((a, b, c)):
            el.append(f'<rect x="{x[2 + j] - 6}" y="{y - 16}" width="{320 if j == 0 else 300}" height="22" rx="4" fill="{cell[1]}" fill-opacity="0.16"/>')
            el.append(text(x[2 + j], y, cell[0], 12.5, cell[1] or PAL["ink"], "bold", "start"))
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{Wd}" height="{Hd}"><rect width="{Wd}" height="{Hd}" fill="#fff"/>{"".join(el)}</svg>'
    p = os.path.join(OUT, "model-1568-table.svg")
    open(p, "w").write(svg)
    subprocess.run(["rsvg-convert", "-o", p[:-4] + ".png", p], check=True)


def dump_model(exe, args):
    return R.dump(exe, args)


def fig_results():
    Wd, Hd = 2080, 620
    el = [text(Wd / 2, 34, "The model of OCCT#1568: input, a radius that builds, and the radius of the report", 19, weight="bold")]
    # input with edges
    p = subprocess.run([MD_NEW, "brep", MODEL] + [str(e) for e in INNER + OUTER], capture_output=True, text=True)
    T, E = [], []
    for l in p.stdout.splitlines():
        t = l.split()
        if t[0] == "T":
            T.append([tuple(map(float, t[1 + 3 * i:4 + 3 * i])) for i in range(3)])
        elif t[0] == "E":
            E.append((tuple(map(float, t[1:4])), tuple(map(float, t[4:7])), t[7]))
    A = Panel(20, 70, 660, 440)
    prim = []
    for tri in T:
        P = [proj(v) for v in tri]
        prim.append((sum(q[2] for q in P) / 3, "t", P, R.shade(tri), None))
    for a, b, tg in E:
        P = [proj(a), proj(b)]
        prim.append(((P[0][2] + P[1][2]) / 2 + 0.5, "e", P, 0, tg))
    A.fit([q for _, _, P, _, _ in prim for q in P])
    for _, k, P, f, tg in sorted(prim, key=lambda t: t[0]):
        if k == "t":
            c = hexshade(PAL["face"], f)
            el.append(f'<polygon points="{" ".join("%.1f,%.1f" % A.xy(q) for q in P)}" fill="{c}" stroke="{c}" stroke-width="0.5"/>')
        else:
            col = PAL["fail"] if int(tg) in INNER else "#e08a1e"
            a, b = A.xy(P[0]), A.xy(P[1])
            el.append(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" stroke="{col}" stroke-width="3.4" stroke-linecap="round"/>')
    el.append(text(350, 540, "input: inner rim 12 to 19 red, outer edges 3 9 11 6 orange", 13, PAL["ink"], "bold"))
    el.append(text(350, 562, "the top face is a ring 3 wide: r = 1.5 on both sides meets exactly (OCCT#1177)", 12, PAL["mute"]))
    cells = [("inner rim 12 to 19, r = 1.49", ["1.49"] + [str(e) for e in INNER]),
             ("inner rim 12 to 19, r = 1.6", ["1.6"] + [str(e) for e in INNER]),
             ("inner rim 12 to 19, r = 1.5 (the report)", ["1.5"] + [str(e) for e in INNER])]
    xs = [700, 1050, 1400]
    for (lab, args), x0 in zip(cells, xs):
        res = R.dump(MD_NEW, ["brepfillet", MODEL] + args)
        pn = Panel(x0, 70, 340, 440)
        if res:
            el += solid(pn, res)
            st = ("valid, %.1f" % res["vol"], PAL["ok"]) if res["valid"] else ("INVALID", PAL["warn"])
        else:
            el += solid(pn, dict(T=T, E=[(a, b) for a, b, tg in E if int(tg) in INNER]))
            st = ("declined (IsDone false)", PAL["fail"])
        el.append(text(x0 + 170, 540, lab, 12.5, PAL["ink"], "bold"))
        el.append(chip(x0 + 170, 585, 300, st[0], st[1]))
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{Wd}" height="{Hd}"><rect width="{Wd}" height="{Hd}" fill="#fff"/>{"".join(el)}</svg>'
    p = os.path.join(OUT, "model-1568.svg")
    open(p, "w").write(svg)
    subprocess.run(["rsvg-convert", "-o", p[:-4] + ".png", p], check=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    fig_results()
    fig_table(table())
