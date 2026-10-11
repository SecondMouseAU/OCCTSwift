#!/usr/bin/env python3
"""Review images for the chamfer parity cases, in the style of fillet-pivot-edges/render.py (whose drawing helpers this imports).

  render_chamfer.py <outdir> <cprobe_pinned> <cprobe_decline> <cprobe_pivot> <cprobe_half> [stem ...]

cprobe_pinned   linked against the pinned kernel.6 (what main ships)
cprobe_decline  kernel.6 + patch 0063, runout reading 0 (a distance past its face is declined, as before)
cprobe_pivot    kernel.6 + patch 0063, runout reading 1 (pivot: the cut passes through the far edge)
cprobe_half     kernel.6 + patch 0063, runout reading 2 (half-space: the plane is extended and clipped by the solid)

One image per case. Where one answer is right (nothing runs past its face), three panels as in the fillet set: left the end view
looking along Y with the analytic profile dashed blue and the cut lines marked, middle the kernel's 3D result, right the reference
(the profile sketched and extruded, no chamfer code). Where the distance runs past its face the right answer is a decision for the
maintainer, so the image shows BOTH candidates side by side: the pivot reading (blue) and the half-space reading (orange), each with
the kernel's result under the matching 0063 build and its own reference. Chips: valid / declined / volume difference.
"""
import sys, os, math, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
ARGV = list(sys.argv)
OUT, P_PIN, P_DEC, P_PIV, P_HALF = sys.argv[1:6]
sys.argv = ["render.py", OUT, "-", "-", "-"]
sys.path.insert(0, os.path.join(HERE, "..", "fillet-pivot-edges"))
import render as R                      # the fillet set's drawing helpers (importing it only defines them)
import chamfer_cases as C

PAL = R.PAL
os.makedirs(OUT, exist_ok=True)
W, H, L = C.W, C.H, C.LEN


# ---------------------------------------------------------------- kernel output
def mesh(probe, case):
    p = subprocess.run([probe, "mesh", f"box:{W:g},{L:g},{H:g}"] + case.op, capture_output=True, text=True, timeout=120)
    lines = p.stdout.splitlines()
    st = [l for l in lines if l.startswith("STATUS")]
    if not st:
        return None
    kv = dict(t.split("=") for t in st[0].split()[1:])
    T, E = [], []
    for l in lines:
        t = l.split()
        if t and t[0] == "T":
            T.append([tuple(map(float, t[1 + 3 * i:4 + 3 * i])) for i in range(3)])
        elif t and t[0] == "E":
            E.append((tuple(map(float, t[1:4])), tuple(map(float, t[4:7]))))
    return dict(valid=kv["valid"] == "1", vol=float(kv["vol"]), faces=int(kv["faces"]), T=T, E=E)


def reference(poly):
    args = [P_PIV, "profile", repr(L)]
    for i, (x, z) in enumerate(poly):
        args += ["S" if i == 0 else "L", repr(x), repr(z)]
    p = subprocess.run(args, capture_output=True, text=True, timeout=60)
    lines = p.stdout.splitlines()
    st = [l for l in lines if l.startswith("STATUS")]
    kv = dict(t.split("=") for t in st[0].split()[1:])
    T, E = [], []
    for l in lines:
        t = l.split()
        if t and t[0] == "T":
            T.append([tuple(map(float, t[1 + 3 * i:4 + 3 * i])) for i in range(3)])
        elif t and t[0] == "E":
            E.append((tuple(map(float, t[1:4])), tuple(map(float, t[4:7]))))
    return dict(valid=kv["valid"] == "1", vol=float(kv["vol"]), faces=int(kv["faces"]), T=T, E=E)


# ---------------------------------------------------------------- drawing
def status(res, vol):
    if res is None:
        return "declined (IsDone false)", PAL["fail"]
    d = res["vol"] - vol
    if res["valid"]:
        return "valid, %.6f (%+.1e)" % (res["vol"], d), PAL["ok"]
    return "done but INVALID, %.3f (%+.3f)" % (res["vol"], d), PAL["warn"]


def cut_geometry(case, model):
    """For each cut: the two points of its line (in x, z), whether each end is on its face or a pivot or outside the face."""
    out = []
    top_left, top_right = 0.0, W
    for side, d1, d2 in case.cuts:
        if case.sequential:
            a, b = C.cut_points(side, d1, d2, model, top_right - top_left, top_left)
        else:
            a, b = C.cut_points(side, d1, d2, model)
        out.append((side, d1, d2, a, b))
        if side == "L":
            top_left = max(top_left, a[0])
        else:
            top_right = min(top_right, a[0])
    return out


def section_panel(pn, case, ker, models):
    pn.fit([(-0.6, -0.5), (W + 0.6, H + 0.8)], pad=0.03)
    el = [f'<rect x="{pn.x0}" y="{pn.y0}" width="{pn.w}" height="{pn.h}" fill="#f6f8fb" stroke="#d5dbe5"/>']
    box = [(0, 0), (W, 0), (W, H), (0, H), (0, 0)]
    el.append(f'<path d="M {" L ".join("%.1f,%.1f" % pn.xy(p) for p in box)}" fill="none" stroke="{PAL["mute"]}" stroke-width="1" stroke-dasharray="2 4"/>')
    el.append(f'<clipPath id="cp{pn.x0}"><rect x="{pn.x0}" y="{pn.y0}" width="{pn.w}" height="{pn.h}"/></clipPath><g clip-path="url(#cp{pn.x0})">')
    colour = {"P": PAL["blue"], "H": PAL["warn"]}
    for m in models:
        poly = case.poly[m]
        dash = "7 4" if m == "P" else "3 3"
        el.append(f'<path d="M {" L ".join("%.1f,%.1f" % pn.xy(p) for p in poly)} Z" fill="{colour[m]}" fill-opacity="{0.07 if m == "P" else 0.0}" '
                  f'stroke="{colour[m]}" stroke-width="2.2" stroke-dasharray="{dash}"/>')
        # the cut lines extended a little, and the points where they meet the faces
        for side, d1, d2, a, b in cut_geometry(case, m):
            for (x, z), face_len, own in ((a, W, "top"), (b, H, "wall")):
                px, py = pn.xy((x, z))
                inside = -1e-9 <= x <= W + 1e-9 and -1e-9 <= z <= H + 1e-9
                if not inside:
                    el.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="5" fill="none" stroke="{colour[m]}" stroke-width="1.6"/>')
                    continue
                far = (own == "top" and (abs(x) < 1e-9 or abs(x - W) < 1e-9) and abs(z - H) < 1e-9 and (d1 > W + 1e-9 or False))
                el.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="4.8" fill="{PAL["tan"]}"/>')
    # pivots: where a distance ran past its face and the reading ends the cut at the far edge
    if "P" in models:
        for side, d1, d2, a, b in cut_geometry(case, "P"):
            if d1 > W + 1e-9:
                px, py = pn.xy(a)
                el.append(f'<rect x="{px - 5:.1f}" y="{py - 5:.1f}" width="10" height="10" fill="{PAL["piv"]}" transform="rotate(45 {px:.1f} {py:.1f})"/>')
            if d2 > H + 1e-9:
                px, py = pn.xy(b)
                el.append(f'<rect x="{px - 5:.1f}" y="{py - 5:.1f}" width="10" height="10" fill="{PAL["piv"]}" transform="rotate(45 {px:.1f} {py:.1f})"/>')
    if ker:
        col = PAL["ok"] if ker["valid"] else PAL["warn"]
        for a, b in ker["E"]:
            if abs(a[1]) < 1e-6 and abs(b[1]) < 1e-6:
                p, q = pn.xy((a[0], a[2])), pn.xy((b[0], b[2]))
                el.append(f'<line x1="{p[0]:.1f}" y1="{p[1]:.1f}" x2="{q[0]:.1f}" y2="{q[1]:.1f}" stroke="{col}" stroke-width="3.2" stroke-linecap="round"/>')
    el.append("</g>")
    return el


def legend(case, x, y, models):
    el = []
    i = 0
    for m in models:
        name = {"P": "pivot reading", "H": "half-space reading"}[m] if len(models) > 1 else "profile"
        pts = " ".join("(%.3g, %.3g)" % p for p in case.poly[m])
        el.append(R.text(x, y + 16 * i, f"{name}: {pts}", 11, PAL["blue"] if m == "P" else PAL["warn"], "normal", "start"))
        i += 1
    for side, d1, d2, a, b in cut_geometry(case, "P" if "P" in models else "H"):
        e = "left" if side == "L" else "right"
        el.append(R.text(x, y + 16 * i, f"{e} cut: {d1:g} top, {d2:g} wall -> ({a[0]:.3f}, {a[1]:.3f}) to ({b[0]:.3f}, {b[1]:.3f})", 11, PAL["ink"], "normal", "start"))
        i += 1
    return el


def figure(case):
    pin = mesh(P_PIN, case)
    dec = mesh(P_DEC, case)
    one_answer = case.same
    Wd = 1560 if one_answer else 1700
    Hd = 760 if one_answer else 940
    title = case.title
    el = [R.text(Wd / 2, 34, title, 19, weight="bold")]
    if one_answer:
        vol = case.vol["P"]
        el.append(R.text(Wd / 2, 56, "analytic volume %.6f; analytic profile dashed blue; the end view looks along Y" % vol, 13, PAL["mute"]))
        A, B, Cp = R.Panel(20, 80, 480, 400), R.Panel(520, 80, 520, 400), R.Panel(1060, 80, 480, 400)
        el += section_panel(A, case, dec, ["P"])
        el += legend(case, 28, 502, ["P"])
        if dec:
            el += R.solid(B, dec)
        else:
            el += R.input_box(B, (W, L, H), [EDGE_PT[s] for s, _, _ in case.cuts])
        ref = reference(case.poly["P"])
        el += R.solid(Cp, ref)
        s, c = status(dec, vol)
        el.append(R.chip(780, 580, 500, "kernel.6 + 0063: " + s, c))
        s, c = status(pin, vol)
        el.append(R.chip(780, 616, 500, "kernel.6 (pinned): " + s, c))
        el.append(R.text(780, 650, "3D result with edges drawn" if dec else "declined: the input, chamfered edges red", 12, PAL["mute"]))
        s2, c2 = status(ref, vol)
        el.append(R.chip(1300, 580, 500, "reference (sketch + extrude): " + s2, c2))
        el.append(R.text(1300, 616, "the profile extruded: what Shapr3D gives", 12, PAL["mute"]))
        if case.note:
            el.append(R.text(Wd / 2, 700, case.note, 12.5, PAL["ink"]))
    else:
        el.append(R.text(Wd / 2, 56, "DECISION: a distance runs past its face, two readings, both drawn. Pivot (blue) volume %.4f; half-space (orange) volume %.4f. The end view looks along Y."
                         % (case.vol["P"], case.vol["H"]), 13, PAL["mute"]))
        A = R.Panel(20, 80, 440, 400)
        el += section_panel(A, case, mesh(P_PIV, case), ["P", "H"])
        el += legend(case, 28, 502, ["P", "H"])
        grid = [("P", P_PIV, 96), ("H", P_HALF, 500)]
        for m, probe, y0 in grid:
            k = mesh(probe, case)
            ref = reference(case.poly[m])
            Bp, Cp = R.Panel(480, y0, 380, 330), R.Panel(870, y0, 380, 330)
            el += R.solid(Bp, k) if k else R.input_box(Bp, (W, L, H), [EDGE_PT[s] for s, _, _ in case.cuts])
            el += R.solid(Cp, ref)
            name = "pivot reading" if m == "P" else "half-space reading"
            colour = PAL["blue"] if m == "P" else PAL["warn"]
            el.append(R.text(865, y0 - 4, name, 15, colour, "bold"))
            s, c = status(k, case.vol[m])
            el.append(R.chip(670, y0 + 352, 360, "kernel.6 + 0063, " + ("pivot" if m == "P" else "half-space") + ": " + s, c))
            s2, c2 = status(ref, case.vol[m])
            el.append(R.chip(1060, y0 + 352, 360, "reference (sketch + extrude): " + s2, c2))
        s, c = status(pin, case.vol["P"])
        el.append(R.chip(1470, 140, 400, "kernel.6 (pinned): " + s.split(",")[0] if pin is None else "kernel.6 (pinned): valid " + ("%.4f" % pin["vol"]), c))
        s, c = status(dec, case.vol["P"])
        el.append(R.chip(1470, 190, 400, "0063, runout declined: " + (s.split(",")[0] if dec is None else "valid %.4f" % dec["vol"]), c))
        el.append(R.text(1470, 232, "Pivot and half-space differ in the cut line", 12, PAL["mute"]))
        el.append(R.text(1470, 250, "and so in the volume: the decision is yours.", 12, PAL["mute"]))
        if case.note:
            el.append(R.text(Wd / 2, 920, case.note, 12.5, PAL["ink"]))
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{Wd}" height="{Hd}" viewBox="0 0 {Wd} {Hd}"><rect width="{Wd}" height="{Hd}" fill="{PAL["bg"]}"/>{"".join(el)}</svg>'
    path = os.path.join(OUT, case.stem + ".svg")
    open(path, "w").write(svg)
    subprocess.run(["rsvg-convert", "-z", "1.3", "-o", path[:-4] + ".png", path], check=True)
    return pin, dec


EDGE_PT = {"L": (0, 5, 6), "R": (4, 5, 6)}


def fmtres(x, vol):
    if x is None:
        return "declined"
    return ("valid %.6f" % x["vol"]) if x["valid"] else ("INVALID %.3f" % x["vol"])


def recipe(case, pin, dec, piv, half):
    out = [f"### {case.title}", ""]
    ops = "; ".join(f"{d1:g} on the top face and {d2:g} on the {'left' if s == 'L' else 'right'} wall, on the {'left' if s == 'L' else 'right'} top edge (middle ({EDGE_PT[s][0]}, {EDGE_PT[s][1]}, {EDGE_PT[s][2]}))"
                    for s, d1, d2 in case.cuts)
    how = ", one after the other in that order" if case.sequential else (", all in one operation" if len(case.cuts) > 1 else "")
    out += [f"File `{case.stem}.png`. Box 4 x 10 x 6 (X x Y x Z), one corner at the origin, top face Z = 6. Chamfer: {ops}{how}.", ""]
    for m in (["P"] if case.same else ["P", "H"]):
        name = "" if case.same else (" (pivot reading)" if m == "P" else " (half-space reading)")
        out += [f"Shapr3D, construction{name}: sketch on the XZ plane (the front plane, looking along Y) with the origin at the box's lower-left corner, one closed profile, extrude 10 along +Y:", ""]
        for i, (x, z) in enumerate(case.poly[m]):
            out.append(f"{i + 1}. " + (f"Start at ({x:.4f}, {z:.4f})." if i == 0 else f"Line to ({x:.4f}, {z:.4f})."))
        out.append(f"{len(case.poly[m]) + 1}. Close the profile back to the start with a line, then extrude 10.")
        out += ["", f"Volume {case.vol[m]:.6f} (the profile area is {case.vol[m] / L:.6f}).", ""]
    out += ["Check against the chamfer tool: apply the same distances to the same edges of a plain box, with the top face as the reference face for the first distance, and compare the profile with the sketch above; they should coincide.", ""]
    if case.same:
        out.append(f"Kernel results: pinned kernel.6 {fmtres(pin, 0)}; kernel.6 + 0063 {fmtres(dec, 0)}; reference extrusion valid {case.vol['P']:.6f}.")
    else:
        out.append(f"Kernel results: pinned kernel.6 {fmtres(pin, 0)}; 0063 with the runout declined {fmtres(dec, 0)}; 0063 pivot reading {fmtres(piv, 0)} (expected {case.vol['P']:.6f}); 0063 half-space reading {fmtres(half, 0)} (expected {case.vol['H']:.6f}).")
    out.append("")
    return "\n".join(out)


GROUPS = [("S", "S: one symmetric chamfer on one top edge"), ("T", "T: one chamfer with two distances (first distance on the top face)"),
          ("W", "W: the reference face is the WALL"), ("B", "B: both top edges in one operation"), ("D", "D: one after the other"),
          ("A", "A: distance and angle")]

HEAD = """# Chamfer parity: what to look at, and the Shapr3D recipe for every case

Nothing here is submitted. Companion to the fillet pivot-edge review; the chamfer analogue of the same rule.

Every image: the end view looking along Y with the analytic profile dashed (blue, and orange where a second reading exists), the points
where a cut meets a face (green discs), a hollow ring where a reading puts the cut end outside the face, a red diamond where a reading
ends the cut at the far edge of a face (the pivot), the kernel's end face drawn over it in green; the kernel's 3D result; the reference,
the profile sketched and extruded (a sketch and an extrude, independent of the chamfer code). Chips: valid / declined, the volume, and
the difference from the analytic one, for the pinned kernel.6 and for kernel.6 plus the candidate patch 0063.

Coordinates: X across the top face (4 wide), Y along the edges (10), Z up (6). The first distance of a two-distance chamfer is
measured on the top face, the second on the wall, unless the case says the wall is the reference face. Distance and angle: the
distance is on the top face and the angle is between the chamfer and the top face, so the wall distance is d tan(angle), which the
valid cases confirm.

The two readings of a distance that runs past its face (cases where both are drawn):

- PIVOT (blue): the face ends at its far edge, the cut line passes through that edge and keeps the distance that fits. The analogue of
  the fillet rule, and order dependent when two chamfers are applied one after the other.
- HALF-SPACE (orange): the cut is the plane through the two distances, extended past the face and clipped by the box. Order does not
  matter.
- Or keep declining (the pinned kernel's behaviour).

Where nothing runs past a face the answer is one shape, and the pinned kernel declines it whenever a distance EQUALS its face or two
cuts meet or cross on the face (the analogue of OCCT#1177 for chamfers). Those are the cases patch 0063 builds in every reading.

"""


if __name__ == "__main__":
    only = ARGV[6:] if len(ARGV) > 6 else None
    rows = []
    for case in C.CASES:
        if only and case.stem not in only:
            continue
        pin, dec = figure(case)
        piv, half = mesh(P_PIV, case), mesh(P_HALF, case)
        rows.append((case, pin, dec, piv, half))
        print(case.stem, fmtres(pin, 0), "|", fmtres(dec, 0), "|", fmtres(piv, 0), "|", fmtres(half, 0), flush=True)
    if not only:
        with open(os.path.join(OUT, "chamfer-index.md"), "w") as f:
            f.write(HEAD)
            for g, name in GROUPS:
                f.write(f"## {name}\n\n")
                for case, pin, dec, piv, half in rows:
                    if case.group == g:
                        f.write(recipe(case, pin, dec, piv, half) + "\n")
        with open(os.path.join(OUT, "chamfer-table.tsv"), "w") as f:
            f.write("file\tcase\tcategory\texpected_pivot\texpected_halfspace\tpinned_kernel6\t0063_decline\t0063_pivot\t0063_halfspace\n")
            for case, pin, dec, piv, half in rows:
                f.write(f"{case.stem}.png\t{case.title}\t{'one answer' if case.same else 'DECISION'}\t{case.vol['P']:.6f}\t{case.vol['H']:.6f}\t"
                        f"{fmtres(pin, 0)}\t{fmtres(dec, 0)}\t{fmtres(piv, 0)}\t{fmtres(half, 0)}\n")
