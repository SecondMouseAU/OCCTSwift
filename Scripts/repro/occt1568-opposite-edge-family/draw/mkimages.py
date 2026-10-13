#!/usr/bin/env python3
"""Pictures of the DRAW cases, one panel per kernel state, made by DRAW itself (vinit/vdisplay/vdump).

  mkimages.py --build <occt-draw-build> --out <dir> --state NAME[=<libdir>] ... [scripts...]

For every case script and every state, DRAWEXE is started with a window (vinit has no Cocoa
application in -b mode), render-images.tcl is sourced before the script, and each case writes a
PPM of two views. The PPMs are then composed (Pillow) into <out>/<case>.png: one column per
state, each with the view along the filleted edges over an axonometric one, captioned with the
outcome DRAW reported. Colours: gold valid, red invalid solid, grey input with the filleted edges
red for a refusal.
"""
import argparse, glob, os, re, subprocess, sys
from PIL import Image, ImageDraw, ImageFont

ap = argparse.ArgumentParser()
ap.add_argument("--build", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--state", action="append", required=True, help="NAME or NAME=libdir of replacement dylibs")
ap.add_argument("--timeout", type=int, default=180)
ap.add_argument("--no-check", action="append", default=[],
                help="state name for which FAM_NO_CHECK=1 is set (cases that set fam_check_may_hang skip checkshape)")
ap.add_argument("scripts", nargs="*")
a = ap.parse_args()

here = os.path.dirname(os.path.abspath(__file__))
scripts = a.scripts or sorted(glob.glob(os.path.join(here, "pr[123]_*.tcl")))
build = os.path.abspath(a.build)
out = os.path.abspath(a.out)
raw = os.path.join(out, "raw")
os.makedirs(raw, exist_ok=True)
tcl = os.environ.get("TCL_LIBDIR", "/opt/homebrew/opt/tcl-tk@8/lib")

states = []
for s in a.state:
    name, _, libs = s.partition("=")
    states.append((name, libs))

results = {}  # (state, label) -> dict of the FAMILY line
for name, libs in states:
    dyld = f"{build}/mac64/clang/lib:{tcl}"
    if libs:
        dyld = os.path.abspath(libs) + ":" + dyld
    for sc in scripts:
        logf = os.path.join(raw, f"{name}--{os.path.basename(sc)}.log")
        if os.path.exists(logf):
            os.remove(logf)
        env = dict(os.environ, FAM_OUT=raw, FAM_STATE=name, FAM_LOG=logf)
        if name in a.no_check:
            env["FAM_NO_CHECK"] = "1"
        cmd = (f'cd {build} && source ./env.sh >/dev/null 2>&1 && export DYLD_LIBRARY_PATH="{dyld}" '
               f'&& cd {here} && {build}/mac64/clang/bin/DRAWEXE -c "source {here}/render-images.tcl; '
               f'source {sc}; exit"')
        try:
            p = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True, env=env,
                               timeout=a.timeout, start_new_session=True)
            txt = p.stdout + p.stderr
        except subprocess.TimeoutExpired as e:
            txt = (e.stdout or b"").decode() if isinstance(e.stdout, bytes) else (e.stdout or "")
            print(f"TIMEOUT {name} {os.path.basename(sc)}", file=sys.stderr)
        txt = open(logf).read() if os.path.exists(logf) else ""
        for l in re.findall(r"^FAMILY (.*)$", txt, re.M):
            d = dict(kv.split("=", 1) for kv in l.split())
            results[(name, d["label"])] = d
        print(f"done {name} {os.path.basename(sc)}", flush=True)

labels = sorted({k[1] for k in results})
try:
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 15)
    big = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 18)
except Exception:
    font = big = ImageFont.load_default()

def outcome(d):
    if d["done"] != "1":
        return "IsDone false (refused)", (90, 90, 90)
    if d["valid"] == "hang":
        return "IsDone true; BRepCheck of it never returns", (190, 30, 30)
    if d["valid"] != "1":
        return f"INVALID solid, volume {float(d['vol']):.4f}", (190, 30, 30)
    return f"valid, volume {float(d['vol']):.6f}", (20, 120, 50)

W = 360
for label in labels:
    key = label.replace("/", "_").replace(" ", "_")
    cols = []
    for name, _ in states:
        d = results.get((name, label))
        imgs = []
        for v in ("prof", "axo"):
            p = os.path.join(raw, f"{name}--{key}--{v}.ppm")
            if os.path.exists(p):
                im = Image.open(p).convert("RGB")
                im = im.resize((W, int(im.height * W / im.width)))
            else:
                im = Image.new("RGB", (W, 290), (230, 230, 230))
            imgs.append(im)
        cols.append((name, d, imgs))
    h = 70 + sum(i.height for i in cols[0][2]) + 60
    sheet = Image.new("RGB", (len(cols) * (W + 20) + 20, h), (255, 255, 255))
    dr = ImageDraw.Draw(sheet)
    want = next((c[1]["want"] for c in cols if c[1]), "")
    dr.text((20, 8), f"{label}   analytic volume {want}", fill=(0, 0, 0), font=big)
    for ci, (name, d, imgs) in enumerate(cols):
        x = 20 + ci * (W + 20)
        dr.text((x, 38), name, fill=(0, 0, 0), font=big)
        y = 70
        for im in imgs:
            sheet.paste(im, (x, y))
            y += im.height
        if d:
            txt, col = outcome(d)
            dr.text((x, y + 6), txt, fill=col, font=font)
            dr.text((x, y + 28), f"verdict {d['verdict']}", fill=col, font=font)
    sheet.save(os.path.join(out, f"{key}.png"))
    print("wrote", f"{key}.png")
