#!/usr/bin/env python3
"""Replay the upstream reproducers through dprobe, one process per case.

usage: run_cases.py PROBE ATTACHMENTS_DIR [REPS]

PROBE is a built dprobe (see build-probe.sh). ATTACHMENTS_DIR is what fetch-attachments.sh filled.
A case that does not finish inside TIMEOUT seconds says which stage (build, brepcheck, volume, bopcheck) it was last seen in; a signal is CRASH.
"""
import subprocess
import sys

TIMEOUT = 60


def cases(att):
    def a(issue, name):
        return f"{att}/{issue}/{name}"

    c = [
        ("1177", "10 cube, one edge d=10 (fillet)", "box:10,10,10", "blend", ["10:10"]),
        ("1177", "10 cube, fillets 5+5 on opposite edges", "box:10,10,10", "blend", ["5:10", "5:9"]),
        ("1177", "10 cube, chamfer d=10", "box:10,10,10", "chamf", ["10:10"]),
        ("1177", "10 cube, chamfers 5+5 on opposite edges", "box:10,10,10", "chamf", ["5:10", "5:9"]),
        ("1568", "reporter script, 12 edges r=1.5", a(1568, "model.brep"), "blend",
         [f"1.5:{i}" for i in (3, 9, 11, 6, 13, 14, 15, 16, 17, 18, 19, 12)]),
        ("1568", "edge 13 alone r=1.5", a(1568, "model.brep"), "blend", ["1.5:13"]),
        ("1568", "edge 13 alone r=1.49", a(1568, "model.brep"), "blend", ["1.49:13"]),
        ("1421", "example.brep r=1 edge 22", a(1421, "example.brep"), "blend", ["1:22"]),
        ("1576", "chamfer d=1 edge 11 (the issue's script)", a(1576, "model.brep"), "chamf", ["1:11"]),
        ("1576", "chamfer d=1 edge 14", a(1576, "model.brep"), "chamf", ["1:14"]),
        ("1217", "prism Y=-76.6894 chamfer d=1 edge 3", "s1217:-76.6894", "chamf", ["1:3"]),
        ("1217", "prism Y=-76.75 chamfer d=1 edge 3 (control)", "s1217:-76.75", "chamf", ["1:3"]),
        ("1570", "r=5 edges 1,8", a(1570, "model.brep"), "blend", ["5:1", "5:8"]),
        ("1570", "r=5.5 edges 1,8", a(1570, "model.brep"), "blend", ["5.5:1", "5.5:8"]),
        ("1570", "r=29 edges 1,8", a(1570, "model.brep"), "blend", ["29:1", "29:8"]),
        ("1569", "r=1 edge 12", a(1569, "model.brep"), "blend", ["1:12"]),
        ("1430", "crash_1 r=2 edges 2,5", a(1430, "model.brep"), "blend", ["2:2", "2:5"]),
        ("1430", "crash_2 r=2 edges 51,54", a(1430, "model.brep"), "blend", ["2:51", "2:54"]),
        ("1430", "self_intersection_1 r=1 edges 92,95,98,99", a(1430, "model.brep"), "blend",
         ["1:92", "1:95", "1:98", "1:99"]),
        ("1430", "self_intersection_2 r=1.7 edge 2", a(1430, "model.brep"), "blend", ["1.7:2"]),
        ("1430", "self_intersection_3 r=1.7 edge 51", a(1430, "model.brep"), "blend", ["1.7:51"]),
        ("1430", "r=1 edge 67 (found by the sweep)", a(1430, "model.brep"), "blend", ["1:67"]),
        ("1571", "2 edges r=1 (13,43)", a(1571, "model.brep"), "blend", ["1:13", "1:43"]),
        ("1571", "4 edges r=1 (13,43,58,35)", a(1571, "model.brep"), "blend", ["1:13", "1:43", "1:58", "1:35"]),
        ("1427", "tapered 2.8 deg r=1 edge 12 (the good case)", a(1427, "tapered_2_8.brep"), "blend", ["1:12"]),
        ("1427", "tapered 2.9 deg r=1 edge 12", a(1427, "tapered_2_9.brep"), "blend", ["1:12"]),
        ("736", "vol.brep r=1 edge 6", a(736, "vol.brep"), "blend", ["1:6"]),
        ("736", "vol.brep r=0.99 edge 6", a(736, "vol.brep"), "blend", ["0.99:6"]),
        ("736", "vol.brep r=1.01 edge 6", a(736, "vol.brep"), "blend", ["1.01:6"]),
        ("737", "r=1 edge 13", a(737, "fillet_edge_blend_orientation.brep"), "blend", ["1:13"]),
        ("737", "chamfer d=1 edge 13", a(737, "fillet_edge_blend_orientation.brep"), "chamf", ["1:13"]),
        ("691", "r=1 edge 20", a(691, "curved-base-sweep-straight.brep"), "blend", ["1:20"]),
        ("692", "r=1 edge 17", a(692, "curved-base-sweep-curve-same-dir.brep"), "blend", ["1:17"]),
        ("694", "r=1 edge 6", a(694, "straight-base-sweep-straight.brep"), "blend", ["1:6"]),
        ("899", "r=1 edge 13", a(899, "curved-base-sweep-curve-opposite-dir.brep"), "blend", ["1:13"]),
        ("900", "r=1 edge 5", a(900, "straight-base-sweep-curve-opposite-dir.brep"), "blend", ["1:5"]),
        ("1619", "s_26+s_35 r=1.25 (x20)", a(1619, "fillet_uaf.brep"), "blend", ["1.25:26", "1.25:35"]),
        ("1619", "s_26+s_35 r=1.0 (control)", a(1619, "fillet_uaf.brep"), "blend", ["1:26", "1:35"]),
        ("1507", "PR 1507 data, first 24 of its 34 edges, r=2", a(1507, "periodic_seam_fillet.brep"), "blend",
         [f"2:{i}" for i in (9, 33, 32, 31, 30, 8, 7, 6, 11, 12, 13, 14, 38, 37, 36, 35, 19, 18, 17, 16, 40, 41, 42, 28)]),
        ("1507", "PR 1507 data, all 34 edges, r=2", a(1507, "periodic_seam_fillet.brep"), "blend",
         [f"2:{i}" for i in (9, 33, 32, 31, 30, 8, 7, 6, 11, 12, 13, 14, 38, 37, 36, 35, 19, 18, 17, 16, 40, 41, 42,
                              28, 26, 23, 22, 21, 20, 44, 45, 46, 49, 43)]),
        ("1533", "PR 1533 corner brep, edge 31 d=0.5", a(1533, "bug1177_corner.brep"), "chamf", ["0.5:31"]),
        ("1533", "PR 1533 corner brep, edge 31 d=1", a(1533, "bug1177_corner.brep"), "chamf", ["1:31"]),
        ("1533", "PR 1533 corner brep, edge 31 d=2", a(1533, "bug1177_corner.brep"), "chamf", ["2:31"]),
    ]
    return c


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    exe, att = sys.argv[1], sys.argv[2]
    reps = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    for cid, label, src, op, specs in cases(att):
        n = 20 if label.endswith("(x20)") else reps
        outs = []
        for _ in range(n):
            try:
                p = subprocess.run([exe, src, op] + specs, capture_output=True, text=True, timeout=TIMEOUT)
                line = [x for x in p.stdout.splitlines() if x.startswith("RESULT")]
                res = line[0][7:] if line else f"NO RESULT exit={p.returncode}"
                if p.returncode < 0:
                    res = f"CRASH signal {-p.returncode}"
            except subprocess.TimeoutExpired as e:
                got = e.stdout.decode() if isinstance(e.stdout, bytes) else (e.stdout or "")
                stages = [x for x in got.splitlines() if x.startswith(("BUILD", "STAGE"))]
                last = stages[-1].split()[1] if stages else "build"
                built = next((x for x in stages if x.startswith("BUILD")), None)
                res = f"NO RETURN in {TIMEOUT}s after {last}" + (f" ({built})" if built else " (Build itself did not return)")
            outs.append(res)
        distinct = sorted(set(outs))
        shown = distinct[0] + (f" (x{n}, identical)" if n > 1 else "") if len(distinct) == 1 \
            else " | ".join(f"{o} x{outs.count(o)}" for o in distinct)
        print(f"#{cid:5} {label:55} {shown}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
