#!/usr/bin/env python3
"""Fillet and chamfer every edge of every reproducer model, one edge at a time, on one or two kernels.

usage: sweep-edges.py ATTACHMENTS_DIR RADIUS PROBE_LABEL=PROBE [PROBE_LABEL=PROBE ...]

Example: sweep-edges.py attachments 0.5 k6=./dprobe_k6 ir=./dprobe_ir
One process per (model, edge, op, kernel), 20 s each; 'timeout' means the probe did not finish (Build returned; see
run_cases.py for the stage), 'exception' is "no suitable edges" (seams, degenerate edges).
"""
import collections
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

MODELS = {
    "1568": "1568/model.brep", "1421": "1421/example.brep", "1576": "1576/model.brep", "1569": "1569/model.brep",
    "1570": "1570/model.brep", "1430": "1430/model.brep", "1571": "1571/model.brep", "1427": "1427/tapered_2_9.brep",
    "736": "736/vol.brep", "737": "737/fillet_edge_blend_orientation.brep", "691": "691/curved-base-sweep-straight.brep",
    "692": "692/curved-base-sweep-curve-same-dir.brep", "694": "694/straight-base-sweep-straight.brep",
    "899": "899/curved-base-sweep-curve-opposite-dir.brep", "900": "900/straight-base-sweep-curve-opposite-dir.brep",
    "1619": "1619/fillet_uaf.brep", "1507": "1507/periodic_seam_fillet.brep", "1533": "1533/bug1177_corner.brep",
}


def classify(probe, path, op, radius, edge):
    try:
        p = subprocess.run([probe, path, op, f"{radius}:{edge}"], capture_output=True, text=True, timeout=20)
    except subprocess.TimeoutExpired:
        return "timeout"
    out = p.stdout
    if p.returncode != 0 and "RESULT" not in out and "BUILD" not in out:
        return "crash"
    if "done=0" in out and "EXC" in out:
        return "exception"
    if "done=0" in out:
        return "declined"
    if "valid=1" in out and "bopfaults=0" in out:
        return "valid"
    if "valid=1" in out:
        return "valid-bopfaulty"
    return "done-invalid"


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        return 2
    att, radius = sys.argv[1], float(sys.argv[2])
    probes = dict(a.split("=", 1) for a in sys.argv[3:])
    first = next(iter(probes.values()))
    jobs = []
    for model, rel in MODELS.items():
        path = f"{att}/{rel}"
        n = int(subprocess.run([first, path, "count"], capture_output=True, text=True).stdout.split("edges=")[1])
        for label, probe in probes.items():
            for op in ("blend", "chamf"):
                jobs += [(label, probe, model, path, op, e) for e in range(1, n + 1)]
    result = collections.defaultdict(lambda: collections.defaultdict(list))
    with ThreadPoolExecutor(6) as ex:
        futs = [(j, ex.submit(classify, j[1], j[3], j[4], radius, j[5])) for j in jobs]
        for j, f in futs:
            result[(j[2], j[4], j[0])][f.result()].append(j[5])
    for (model, op, label), cls in result.items():
        print(f"{model:5} {op:5} {label:3} " + " ".join(f"{c}={len(v)}" for c, v in sorted(cls.items())))
        for c in ("crash", "timeout"):
            if c in cls:
                print(f"      {c}: edges {cls[c]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
