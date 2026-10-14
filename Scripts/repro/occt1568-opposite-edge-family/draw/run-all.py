#!/usr/bin/env python3
"""Run every case script in this directory against one OCCT build with DRAW and print a table.

  run-all.py --build <occt-build-dir> [--libs <dir>] [--timeout 120] [--name <state>] [scripts...]

<occt-build-dir> is a configured OCCT build with BUILD_MODULE_Draw=ON (it holds env.sh and
mac64/clang/bin/DRAWEXE). --libs puts a directory of replacement dylibs ahead of the build's own
(DYLD_LIBRARY_PATH), which is how "upstream IR before the series" and "commits 1 to 4" are run
against one Draw build: only libTKFillet differs. One DRAWEXE process per script, because the
defect of OCCT#1568 is an uncatchable SIGSEGV (a script that dies prints CRASH).

Each case prints one `FAMILY label=... verdict=PASS|FAIL` line (see common.tcl). PASS means the
behaviour the series chose; on a kernel without the series, FAIL is the defect.
"""
import argparse, glob, os, re, subprocess, sys

ap = argparse.ArgumentParser()
ap.add_argument("--build", required=True)
ap.add_argument("--libs", default="")
ap.add_argument("--timeout", type=int, default=120)
ap.add_argument("--name", default="")
ap.add_argument("scripts", nargs="*")
a = ap.parse_args()

here = os.path.dirname(os.path.abspath(__file__))
scripts = a.scripts or sorted(glob.glob(os.path.join(here, "pr[123]_*.tcl")))
build = os.path.abspath(a.build)

# env.sh of the build sets CASROOT, the resource paths and DYLD_LIBRARY_PATH for the build's libs.
pre = f"cd {build} && source ./env.sh >/dev/null 2>&1"
# env.sh also puts /opt/homebrew/lib first, which can hold another OCCT's libraries: use the build's own
tcl = os.environ.get("TCL_LIBDIR", "/opt/homebrew/opt/tcl-tk@8/lib")
dyld = f"{build}/mac64/clang/lib:{tcl}"
if a.libs:
    dyld = os.path.abspath(a.libs) + ":" + dyld
pre += f' && export DYLD_LIBRARY_PATH="{dyld}"'

rows = []
for s in scripts:
    cmd = f'{pre} && cd {here} && {build}/mac64/clang/bin/DRAWEXE -b -c "source {s}; exit"'
    try:
        p = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True,
                           timeout=a.timeout, start_new_session=True)
        out, rc = p.stdout + p.stderr, p.returncode
    except subprocess.TimeoutExpired as e:
        out, rc = (e.stdout or b"").decode() if isinstance(e.stdout, bytes) else (e.stdout or ""), "TIMEOUT"
    lines = re.findall(r"^FAMILY (.*)$", out, re.M)
    base = os.path.basename(s)
    if not lines:
        why = "TIMEOUT" if rc == "TIMEOUT" else f"CRASH rc={rc}"
        rows.append((base, "-", why, "-", "-", "-", "-"))
        continue
    for l in lines:
        d = dict(kv.split("=", 1) for kv in l.split())
        rows.append((base, d["label"], "done" if d["done"] == "1" else "refused",
                     ("valid" if d["valid"] == "1" else ("check-hangs" if d["valid"] == "hang" else "INVALID")) if d["done"] == "1" else "-",
                     d["vol"], d["want"], d["verdict"]))
    if rc not in (0, "TIMEOUT") and len(lines) < 1:
        rows.append((base, "-", f"CRASH rc={rc}", "-", "-", "-", "-"))
    if rc != 0:
        rows.append((base, "(process)", f"died rc={rc} after the lines above", "-", "-", "-", "FAIL"))

print(f"# state: {a.name or build}" + (f" libs={a.libs}" if a.libs else ""))
print("\t".join(["script", "case", "outcome", "validity", "volume", "analytic", "verdict"]))
for r in rows:
    print("\t".join(r))
