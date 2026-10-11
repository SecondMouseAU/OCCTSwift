#!/usr/bin/env python3
"""Radius sweeps for #3234: for each section family, the radius from small to far past the faces in fine steps, one process
per radius, the branch kernel (gprobe-new) against the rule. Prints, per family, a run-length summary of the outcomes
(right / declined / wrong / INVALID) so a done-but-invalid or wrong-volume window cannot hide between the sampled cases.

  sweep3234.py <bin dir> [variant] [family ...]
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cases3234 as c

FAMILIES = {
    "E45": ("prism", c.wedge_tokens(45), (0.0, 0.0), 0.3, 5.0),
    "E60": ("prism", c.wedge_tokens(60), (0.0, 0.0), 0.3, 7.0),
    "E90": ("prism", c.wedge_tokens(90), (0.0, 0.0), 0.3, 12.0),
    "E120": ("prism", c.wedge_tokens(120), (0.0, 0.0), 1.0, 20.0),
    "E135": ("prism", c.wedge_tokens(135), (0.0, 0.0), 1.0, 28.0),
    "G": ("prism", c.L_TOK, (2.0, 3.0), 0.3, 10.0),
    "H1": ("revolve", c.CYL, (5.0, 6.0), 0.3, 9.0),
    "H2": ("revolve", c.CYL3, (5.0, 3.0), 0.3, 9.0),
    "H3": ("revolve", c.CONE, (5.0, 0.0), 0.3, 6.0),
    "H5": ("revolve", c.WASH, (3.0, 6.0), 0.3, 9.0),
    "H7": ("prism", c.GRV, (9.0, 6.0), 0.3, 12.0),
}
bins = sys.argv[1]
variant = sys.argv[2] if len(sys.argv) > 2 else "new"
only = sys.argv[3:]
N = 60
for fam, (kind, tokens, V, r0, r1) in FAMILIES.items():
    if only and fam not in only:
        continue
    runs, last, detail = [], None, []
    for i in range(N + 1):
        r = round(r0 + (r1 - r0) * i / N, 4)
        case = c.Case("s", "S", "sweep", kind, tokens, [(r, V)], L=c.LEN if kind == "prism" else 0)
        if case.new is None:
            out = "norule"
        else:
            want = case.volume(case.new)
            s, rc, _ = c.run(os.path.join(bins, "gprobe-" + variant), case.gargs())
            out = c.classify(c.parse_result(s), want)
            if out not in ("right", "declined"):
                detail.append((r, out, s))
        key = out + ("[" + case.info["case"] + "]" if case.new is not None and out == "right" else "")
        if key != last:
            runs.append([key, r, r]); last = key
        else:
            runs[-1][2] = r
    print(f"{fam:5s} " + "  ".join(f"{k} {a:g}..{b:g}" for k, a, b in runs), flush=True)
    for d in detail:
        print("   !!", d, flush=True)
