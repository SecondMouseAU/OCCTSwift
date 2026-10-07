#!/usr/bin/env python3
"""Compare the two matrices from the committed JSON alone, no build needed.

usage: python3 Scripts/repro/2983-xcaf-resweep/report.py

Prints, per test file, how many of its own switches there are, how many the old tests caught and
how many the rewrites catch. A switch counts as caught when at least one test of the nine files goes
red under it, or the process dies (a crash is a detection of a kind, and is counted separately, since
a test that dies on a wrong answer leaves the later tests unrun). Switches are assigned to the file
whose subject they distort; `C_MAT_*` is XCAFComponentMatrixTests's and the rest of `C_*` is
XDEAssemblyOperationTests's. Then it lists the switches that redden nothing, and the tests red under
at most one SEMANTIC switch.
"""
import json
import pathlib

HERE = pathlib.Path(__file__).resolve().parent

# (file, prefixes), first match wins
OWNERS = [
    ("Issue443TriangulationAttributeTests", ("T_",)),
    ("TDFLabelPropertyTests", ("L_",)),
    ("BRepGraphAttributeTests", ("A_", "B_")),
    ("XCAFComponentMatrixTests", ("C_MAT_",)),
    ("XDEAssemblyOperationTests", ("C_",)),
    ("DocumentExplorerExtensionTests", ("E_",)),
    ("XCAFPrsStyleTests", ("P_",)),
    ("GDTDimensionAccessorTests", ("G_DIM", "G_CLASS", "W_DIM")),
    ("GDTToleranceDatumAccessorTests", ("G_TOL", "G_DAT", "W_TOL", "W_DAT")),
]


def owner(switch):
    for name, prefixes in OWNERS:
        if switch.startswith(prefixes):
            return name
    return "?"


def categories():
    cat, out = None, {}
    for line in (HERE / "switches.txt").read_text().splitlines():
        line = line.strip()
        if line.startswith("# ----"):
            cat = line.split()[2].rstrip(":")
        elif line and not line.startswith("#"):
            out[line] = cat
    return out


def caught(row):
    return bool(row["red"]) or row["crash"]


def main():
    before = json.loads((HERE / "matrix-before.json").read_text())
    after = json.loads((HERE / "matrix-after.json").read_text())
    cats = categories()
    assert set(before["rows"]) == set(after["rows"]) == set(cats), "switch sets differ"

    print("| file | switches | caught by old | caught by new | old crashed the process |")
    print("|---|---|---|---|---|")
    tot = [0, 0, 0, 0]
    for name, _ in OWNERS:
        sws = [s for s in after["rows"] if owner(s) == name]
        cb = sum(caught(before["rows"][s]) for s in sws)
        ca = sum(caught(after["rows"][s]) for s in sws)
        cr = sum(before["rows"][s]["crash"] for s in sws)
        print(f"| {name} | {len(sws)} | {cb} | {ca} | {cr} |")
        for i, v in enumerate((len(sws), cb, ca, cr)):
            tot[i] += v
    print(f"| **all** | **{tot[0]}** | **{tot[1]}** | **{tot[2]}** | **{tot[3]}** |")
    assert all(owner(s) != "?" for s in after["rows"]), [s for s in after["rows"] if owner(s) == "?"]

    for label, m in (("old", before), ("new", after)):
        dead = [s for s, r in m["rows"].items() if not caught(r)]
        sem = [s for s in dead if cats[s] == "SEMANTIC"]
        print(f"\n{label}: {len(dead)} switches redden nothing ({len(sem)} semantic, "
              f"{len(dead) - len(sem)} gross)")
        if label == "new":
            for s in dead:
                print(f"  {s} ({cats[s]}, {owner(s)})")

    sem_rows = [s for s in after["rows"] if cats[s] == "SEMANTIC"]
    for label, m in (("old", before), ("new", after)):
        counts = {t: 0 for t in m["tests"]}
        for s in sem_rows:
            for t in m["rows"][s]["red"]:
                counts[t] += 1
        thin = sorted(t for t, c in counts.items() if c <= 1)
        print(f"\n{label}: {len(thin)} of {len(counts)} tests are red under at most one semantic switch")
        if label == "new":
            for t in thin:
                print(f"  {t}: {counts[t]}")


main()
