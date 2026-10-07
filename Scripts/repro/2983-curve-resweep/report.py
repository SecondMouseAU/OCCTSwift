#!/usr/bin/env python3
"""Compare two matrices written by run-injection-matrix.py, from the committed JSON alone.

usage: python3 Scripts/repro/2983-shapehealing-resweep/report.py BEFORE_LABEL AFTER_LABEL

Switches are categorised by the `# ---- GROSS|SEMANTIC|FIXTURE` header they sit under in
`switches.txt`: GROSS is a total failure (nil) or the subject doing nothing, SEMANTIC is a
wrong-but-plausible answer, FIXTURE changes what a test's own setup means. Prints the family table,
which switches nothing reddens, and how many semantic switches redden each test.
"""
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent

FAMILIES = [
    ("solid(from:)", ("SOLID_",)),
    ("solidWithFullHistory", ("HIST_",)),
    ("solidFromShellFixed", ("SFS_",)),
    ("fixSolid", ("FIX_",)),
    ("upgraded", ("UP_",)),
    ("healed", ("HEAL_",)),
    ("analyze / analyzeShell", ("AN_", "ASH_")),
    ("totalProblems / isHealthy", ("TP_", "HEALTHY_")),
    ("validity and self-intersection", ("VS_", "ISVALID_", "SI_")),
    ("fixtures", ("FX_",)),
]


def categories():
    cat, out = None, {}
    for line in (HERE / "switches.txt").read_text().splitlines():
        line = line.strip()
        if line.startswith("# ----"):
            cat = line.split()[2].rstrip(":")
        elif line and not line.startswith("#"):
            out[line] = cat
    return out


def family(switch):
    for name, prefixes in FAMILIES:
        if switch.startswith(prefixes):
            return name
    return "?"


def main():
    before = json.loads((HERE / f"matrix-{sys.argv[1]}.json").read_text())
    after = json.loads((HERE / f"matrix-{sys.argv[2]}.json").read_text())
    cats = categories()

    print("| family | switches | redden nothing, before | redden nothing, after |")
    print("|---|---|---|---|")
    totals = [0, 0, 0]
    for name, _ in FAMILIES:
        sws = [s for s in after["rows"] if family(s) == name]
        dead_b = [s for s in sws if not before["rows"][s]["red"]]
        dead_a = [s for s in sws if not after["rows"][s]["red"]]
        totals = [totals[0] + len(sws), totals[1] + len(dead_b), totals[2] + len(dead_a)]
        print(f"| {name} | {len(sws)} | {len(dead_b)} | {len(dead_a)} |")
    print(f"| all | {totals[0]} | {totals[1]} | {totals[2]} |")
    for cat in ("GROSS", "SEMANTIC", "FIXTURE"):
        sws = [s for s in after["rows"] if cats.get(s) == cat]
        dead_b = [s for s in sws if not before["rows"][s]["red"]]
        dead_a = [s for s in sws if not after["rows"][s]["red"]]
        print(f"{cat:8s} {len(sws):3d} switches, redden nothing: before {len(dead_b)}, after {len(dead_a)}")
    print("before, redden nothing:", [s for s, r in before["rows"].items() if not r["red"]])
    print("after,  redden nothing:", [s for s, r in after["rows"].items() if not r["red"]])

    def per_test(d):
        out = {t: 0 for t in d["tests"]}
        for s, r in d["rows"].items():
            if cats.get(s) == "SEMANTIC":
                for t in r["red"]:
                    out[t] = out.get(t, 0) + 1
        return out

    pb, pa = per_test(before), per_test(after)
    for k in (1, 3):
        print(f"tests red under at most {k} semantic switch(es): "
              f"before {sum(1 for v in pb.values() if v <= k)} of {len(pb)}, "
              f"after {sum(1 for v in pa.values() if v <= k)} of {len(pa)}")
    print("median semantic switches per test: before",
          sorted(pb.values())[len(pb) // 2], "after", sorted(pa.values())[len(pa) // 2])


if __name__ == "__main__":
    main()
