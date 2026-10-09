#!/usr/bin/env python3
"""Groups the crashing pairs of scan.py by source line of the fault. usage: fault-sites.py <probe> <scan.txt> <mpr.o>
<probe> must link a -g -DNo_Exception build of BRepOffsetAPI_MiddlePath.cxx ahead of the kernel archive
(see README.md); <rem.txt> is scan.py output. The frame address is symbolised with atos against the
static address of Build()."""
import re, subprocess, sys, collections
probe, scan = sys.argv[1], sys.argv[2]
obj = sys.argv[3]  # the -g object of BRepOffsetAPI_MiddlePath.cxx the probe links
nm = subprocess.run(["nm", obj], capture_output=True, text=True).stdout
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
    a = hex(build + off - 1)  # the frame is a return address: look up the call
    # atos lost the symbol table on the current toolchain; dwarfdump reads the line table directly
    line = subprocess.run(["dwarfdump", "--lookup=" + a, obj], capture_output=True, text=True).stdout
    m = re.search(r"Line info: file '[^']*MiddlePath\.cxx', line (\d+)", line)
    sites[m.group(1) if m else "unresolved " + a].append(f"{sh} {i} {j}")
for k, v in sorted(sites.items()):
    print(f"line {k}: {len(v)} pairs, e.g. {v[:4]}")
