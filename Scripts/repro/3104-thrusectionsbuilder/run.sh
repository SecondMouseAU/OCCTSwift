#!/bin/bash
# #3104: ThruSectionsBuilder with too few sections. One input per process, 60 s timeout each,
# the child that was started is the one killed. Run from the repo root.
#
# Build the probe first (a scratch package outside the repo, depending on this checkout):
#   mkdir -p $S/Sources/probe && cp Scripts/repro/3104-thrusectionsbuilder/probe.swift $S/Sources/probe/main.swift
#   $S/Package.swift: executableTarget "probe" depending on product OCCTSwift of this checkout
#   (path dependency, swiftLanguageMode .v5), then `swift build` in $S. Export PROBE=$S/.build/debug/probe
set -u
exec python3 - "$@" <<'PY'
import os, subprocess, signal, sys
P = os.environ["PROBE"]
orders = ["", "W", "V", "WV", "VW", "WW", "VV", "WWW", "VWW", "WWV", "VWV", "VWWV"]
optsets = ["", "smooth1", "smooth0,deg,cont", "compat0,par,weight", "build0", "twice"]
for order in orders:
    for solid in "10":
        for ruled in "10":
            for opts in optsets:
                args = [P, order or "-", solid, ruled, opts]
                p = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                try:
                    out, _ = p.communicate(timeout=60)
                    rc = p.returncode
                except subprocess.TimeoutExpired:
                    p.kill(); out, _ = p.communicate(); rc = "HANG"
                if isinstance(rc, int) and rc < 0:
                    rc = "SIG%d(%s)" % (-rc, signal.Signals(-rc).name)
                print("order=%-5s solid=%s ruled=%s opts=%-20s rc=%s %s" % (order or "-", solid, ruled, opts or "-", rc, " | ".join(out.split("\n")[:-1])))
PY
