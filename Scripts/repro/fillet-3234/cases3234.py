#!/usr/bin/env python3
"""The #3234 cases: what the pivot rule gives beyond a right-angle planar rectangle, and what each kernel does.

  cases3234.py <bin dir> [stem ...]     prints one row per case: rule volume | kernel.5 | main (0059) | branch (0060) | reference

Each case is a section (lines and circular arcs, XZ plane), a body (prism along Y, or revolved about Z), and the corners to
fillet. The expected result is the rule applied to the section (section.py), its area or first moment giving the volume
exactly. The REFERENCE is that expected section built as a solid by gprobe (a sketch plus an extrude or a revolve: no fillet
code), so a reference volume that differs from the rule volume would be a defect of this script, not of a kernel.
Binaries: <bin dir>/gprobe-k5, gprobe-main, gprobe-new, and gprobe-62 when patch 0062 exists.
"""
import math, os, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import section as sec

LEN = 10.0
CASES = []


class Case:
    def __init__(self, stem, group, title, kind, tokens, fillets, L=LEN, mode="add", note="", tags=()):
        self.stem, self.group, self.title, self.kind, self.tokens, self.fillets, self.L, self.mode, self.note = stem, group, title, kind, tokens, fillets, L, mode, note
        self.tags = tags
        self.edges = sec.parse_path(tokens)
        self.new, self.info = self.apply()
        # a rule result that leaves the part, or none at all: the rule is undefined here (no circle of this radius fits)
        self.undefined = self.new is None or bool(self.info.get("escapes")) or bool(self.info.get("s1", {}).get("escapes"))
        if self.undefined:
            self.new = None

    def apply(self):
        ed = self.edges
        if len(self.fillets) == 1:
            r, V = self.fillets[0]
            return sec.fillet_corner(ed, sec.corner_index(ed, V), r)
        (r1, V1), (r2, V2) = self.fillets
        return sec.fillet_pair(ed, sec.corner_index(ed, V1), r1, sec.corner_index(ed, V2), r2)

    def volume(self, edges):
        if self.kind == "prism":
            return self.L * sec.area(edges)
        return 2 * math.pi * sec.moment_x(edges)

    def pick(self, V):
        return (V[0], self.L / 2, V[1]) if self.kind == "prism" else (0.0, V[0], V[1])

    def gargs(self, tokens_edges=None, ref=False):
        a = ["prism", repr(self.L)] if self.kind == "prism" else ["revolve"]
        toks = sec.to_path(tokens_edges if tokens_edges is not None else self.edges)
        for t in toks:
            a.append(t[0])
            for p in t[1:]:
                a += [repr(p[0]), repr(p[1])]
        a.append("--")
        if ref:
            return a + ["ref"]
        a.append(self.mode)
        for r, V in self.fillets:
            a.append("%r:%s" % (r, ",".join(repr(v) for v in self.pick(V))))
        return a


def tag(r): return ("%g" % r).replace(".", "_")


# ---------------------------------------------------------------- E: dihedral angles other than 90, one fillet
def wedge_tokens(theta, a=4.0, b=6.0):
    d = (math.cos(math.radians(theta)), -math.sin(math.radians(theta)))
    P1, P2 = (a, 0.0), (b * d[0], b * d[1])
    Q = (P1[0] + P2[0], P1[1] + P2[1])
    return ["S", *P1, "L", 0.0, 0.0, "L", *P2, "L", *Q]


E_RADII = {45: [1.25, 1.65, 2.0, 3.0], 60: [1.75, 2.3, 3.0, 4.2], 120: [5.2, 6.9, 8.7, 12.2], 135: [7.25, 9.6, 12.0, 17.0]}
for theta, radii in E_RADII.items():
    for r in radii:
        t = r / math.tan(math.radians(theta) / 2)
        reg = "tangent length %.2f: fits both faces (4 and 6)" % t if t <= 4 - 0.05 else (
            "tangent length %.2f: about the 4 mm face" % t if t <= 4.05 else (
                "tangent length %.2f: the 4 mm face runs out" % t if t <= 6 else "tangent length %.2f: both faces run out" % t))
        CASES.append(Case(f"E{theta}-r{tag(r)}", "E", f"E: one fillet r = {r:g} on the {theta} degree edge of a parallelogram prism (faces 4 and 6 wide)", "prism",
                          wedge_tokens(theta), [(r, (0.0, 0.0))], note=""))


# ---------------------------------------------------------------- F: two fillets at once on a trapezoid, walls at 60 or 120 degrees
def trap_tokens(theta, w=4.0, b=3.0):
    c, s = math.cos(math.radians(theta)), math.sin(math.radians(theta))
    return ["S", w / 2, 0.0, "L", -w / 2, 0.0, "L", -w / 2 + b * c, -b * s, "L", w / 2 - b * c, -b * s]


F_RADII = {60: [1.15, 1.45, 1.6], 120: [3.5, 4.3, 4.85]}
for theta, radii in F_RADII.items():
    for r in radii:
        t = r / math.tan(math.radians(theta) / 2)
        CASES.append(Case(f"F{theta}-r{tag(r)}", "F", f"F: equal radii {r:g} on both top edges of a trapezoid prism, top 4 wide, walls 3 long at {theta} degrees", "prism",
                          trap_tokens(theta), [(r, (2.0, 0.0)), (r, (-2.0, 0.0))],
                          note="tangent length %.2f each, two of them against the 4 mm top: %s" % (t, "tangent to each other" if abs(2 * t - 4) < 0.1 else ("the arcs cross" if 2 * t > 4 else "a flat between"))))


# ---------------------------------------------------------------- G: concave edge, inside corner of an L profile
L_TOK = ["S", 0.0, 0.0, "L", 6.0, 0.0, "L", 6.0, 3.0, "L", 2.0, 3.0, "L", 2.0, 6.0, "L", 0.0, 6.0]
for r in [2.5, 3.5, 5.0, 8.0]:
    CASES.append(Case(f"G-L-r{tag(r)}", "G", f"G: concave edge, radius {r:g} in the inside corner of an L profile (foot 4 past the wall, wall 3 above the foot)", "prism",
                      L_TOK, [(r, (2.0, 3.0))]))


# ---------------------------------------------------------------- H: faces that are curved or of revolution
CYL = ["S", 0.0, 0.0, "L", 5.0, 0.0, "L", 5.0, 6.0, "L", 0.0, 6.0]
for r in [3.0, 5.0, 5.5, 7.0]:
    CASES.append(Case(f"H1-cyl-r{tag(r)}", "H", f"H1: top edge of a cylinder (radius 5, height 6), fillet {r:g}", "revolve", CYL, [(r, (5.0, 6.0))], L=0,
                      tags=("axis",) if r > 5 else ()))
CYL3 = ["S", 0.0, 0.0, "L", 5.0, 0.0, "L", 5.0, 3.0, "L", 0.0, 3.0]
for r in [3.5, 4.5]:
    CASES.append(Case(f"H2-cyl3-r{tag(r)}", "H", f"H2: top edge of a short cylinder (radius 5, height 3), fillet {r:g}: the wall runs out, the bottom circle is the pivot", "revolve",
                      CYL3, [(r, (5.0, 3.0))], L=0))
CONE = ["S", 0.0, 0.0, "L", 5.0, 0.0, "L", 0.0, 6.0]
for r in [1.5, 2.2, 2.5, 3.5]:
    CASES.append(Case(f"H3-cone-r{tag(r)}", "H", f"H3: base edge of a cone (base radius 5, apex 6 above), fillet {r:g}", "revolve", CONE, [(r, (5.0, 0.0))], L=0,
                      tags=("axis",) if r > 2.4 else ()))
HEMI = ["S", 0.0, 0.0, "L", 6.0, 0.0, "A", 6.0 * math.sin(math.radians(45)), 6.0 * math.cos(math.radians(45)), 0.0, 6.0]
for r in [1.5, 2.5, 4.5]:
    CASES.append(Case(f"H4-dome-r{tag(r)}", "H", f"H4: rim of a hemispherical dome (sphere radius 6, flat base), fillet {r:g} between the base disc and the sphere", "revolve",
                      HEMI, [(6.0, 0.0) if False else (r, (6.0, 0.0))], L=0, tags=("axis",) if r > 3 else ()))
WASH = ["S", 3.0, 0.0, "L", 6.0, 0.0, "L", 6.0, 6.0, "L", 3.0, 6.0]
for r in [2.0, 3.5, 5.0, 7.0]:
    CASES.append(Case(f"H5-washer-r{tag(r)}", "H", f"H5: bore edge of a washer (outer radius 6, bore radius 3, height 6), fillet {r:g}: the 3 mm ring runs out onto the outer circle", "revolve",
                      WASH, [(r, (3.0, 6.0))], L=0))
DPR = ["S", 4.0, 3.0, "L", -4.0, 3.0, "A", 0.0, -5.0, 4.0, 3.0]
for r in [1.5, 3.0, 4.5, 8.0]:
    CASES.append(Case(f"H6-dprism-r{tag(r)}", "H", f"H6: edge between a flat (8 wide) and a convex cylinder (radius 5), fillet {r:g}", "prism", DPR, [(r, (-4.0, 3.0))]))
GRV = ["S", 0.0, 0.0, "L", 12.0, 0.0, "L", 12.0, 6.0, "L", 9.0, 6.0, "A", 6.0, 3.0, 3.0, 6.0, "L", 0.0, 6.0]
for r in [2.0, 4.0, 5.0, 8.0]:
    CASES.append(Case(f"H7-groove-r{tag(r)}", "H", f"H7: edge between the 3 mm flat and a concave cylindrical groove (radius 3) in a 12 x 6 block, fillet {r:g}", "prism", GRV, [(r, (9.0, 6.0))]))


BY_STEM = {c.stem: c for c in CASES}
VARIANTS = ["k5", "main", "new", "62"]


def run(binary, args, env=None, timeout=240):
    e = dict(os.environ)
    e.update(env or {})
    try:
        p = subprocess.run([binary] + args, capture_output=True, text=True, timeout=timeout, env=e, start_new_session=True)
    except subprocess.TimeoutExpired:
        return None, "TIMEOUT", []
    out = p.stdout.splitlines()
    res = [l for l in out if l.startswith("RESULT")]
    return (res[0][7:] if res else "NORESULT rc=%d" % p.returncode), p.returncode, out


def parse_result(s):
    if s is None or not s.startswith("done"):
        return None
    d = dict(t.split("=") for t in s.split())
    return dict(done=d["done"] == "1", valid=d["valid"] == "1", vol=float(d["vol"]), faces=int(d["faces"]), solids=int(d["solids"]),
                free=int(d["free"]), nonman=int(d["nonman"]), meshbad=int(d["meshbad"]), raw=s)


def classify(res, want):
    """declined | INVALID (done, BRepCheck or closure fails) | wrong (valid, volume off) | right."""
    if res is None:
        return "declined"
    if not res["done"]:
        return "declined"
    if not res["valid"] or res["solids"] != 1 or res["free"] or res["nonman"] or res["meshbad"]:
        return "INVALID"
    return "right" if abs(res["vol"] - want) <= 1e-6 * max(abs(want), 1.0) else "wrong"


if __name__ == "__main__":
    bins = sys.argv[1]
    only = sys.argv[2:]
    for c in CASES:
        if only and c.stem not in only:
            continue
        if c.new is None:
            print(f"{c.stem:24s} RULE UNDEFINED", " | ".join(v + ":" + (lambda r: "declined" if not r or not r["done"] else ("built %.6f valid=%s" % (r["vol"], r["valid"])))(parse_result(run(os.path.join(bins, "gprobe-" + v), c.gargs())[0])) for v in VARIANTS if os.path.exists(os.path.join(bins, "gprobe-" + v))))
            continue
        want = c.volume(c.new)
        row = [f"{c.stem:24s} rule {want:12.6f} [{c.info.get('case', c.info.get('s1', {}).get('case'))}]"]
        ref, _, _ = run(os.path.join(bins, "gprobe-new"), c.gargs(c.new, ref=True))
        r = parse_result(ref)
        row.append("ref " + (f"{r['vol']:.6f}{'' if r['valid'] else '!'}" if r else "?"))
        for v in VARIANTS:
            b = os.path.join(bins, "gprobe-" + v)
            if not os.path.exists(b):
                continue
            s, rc, _ = run(b, c.gargs())
            res = parse_result(s)
            cl = classify(res, want)
            row.append(f"{v}:{cl}" + (f"({res['vol'] - want:+.2e})" if res and res['done'] else ""))
        print(" | ".join(row), flush=True)
