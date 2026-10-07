#!/usr/bin/env python3
"""Groups the crashing pairs of scan.py by source line of the fault. usage: fault-sites.py <probe> <rem.txt>
<probe> must link a -g -DNo_Exception build of BRepOffsetAPI_MiddlePath.cxx ahead of the kernel archive
(see run.sh); <rem.txt> is scan.py output. The frame address is symbolised with atos against the
static address of Build()."""
import re, subprocess, sys, collections
probe, scan = sys.argv[1], sys.argv[2]
nm = subprocess.run(["nm", probe], capture_output=True, text=True).stdout
build = int(next(l for l in nm.splitlines() if "BRepOffsetAPI_MiddlePath5Build" in l).split()[0], 16)
sites = collections.defaultdict(list)
for l in open(scan):
    m = re.match(r"(\w+) (\d+) (\d+) sharedVerts=0 .*exit=139", l)
    if not m or "same=1" in l:
        continue
    sh, i, j = m.groups()
    r = subprocess.run([probe, "pair", sh, i, j], capture_output=True, text=True)
    frames = [f for f in r.stderr.splitlines() if "MiddlePath5Build" in f]
    if not frames:
        sites["outside Build"].append(f"{sh} {i} {j}"); continue
    off = int(frames[0].rsplit("+", 1)[1])
    top = [f for f in r.stderr.splitlines() if re.match(r"^\d+\s", f)][2:3]
    a = hex(build + off)
    line = subprocess.run(["atos", "-o", probe, "-l", "0x100000000", a], capture_output=True, text=True).stdout.strip()
    sites[re.search(r"cxx:(\d+)", line).group(1) if "cxx:" in line else line].append(f"{sh} {i} {j}")
for k, v in sorted(sites.items()):
    print(f"line {k}: {len(v)} pairs, e.g. {v[:4]}")
