#!/usr/bin/env python3
"""Score the four detectors of #1001 against `adjudicated-sample.tsv`, and print each rate.

Five batches, scored separately and NEVER pooled. Each answers a question about one detector on one
tree, and pooling them would produce a number that is not a rate of anything.

The rates were measured at #1001's branch point. Re-run this after any change to a detector: a
change that quietens the corpus is only an improvement if it removes FALSE rows faster than TRUE
ones, and the total finding count alone cannot tell those apart. A row the detector no longer
reports is DROPPED, split by verdict, since dropping a TRUE row is a recall loss and dropping a
FALSE row is the intended effect.

Line numbers belong to the tree named in each batch header, so a batch is scored against that tree
(exported with `git archive` when it names a commit). Scoring against the wrong tree makes the
matching nonsense, and the script says so rather than reporting a small number quietly.

    python3 Scripts/repro/1001-detector-fp-rates/score_sample.py
"""

import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SAMPLE = os.path.join(HERE, "adjudicated-sample.tsv")
COVERAGE = os.path.join(ROOT, "Scripts", "repro", "385-coverage-sample")
CENSUS_1008 = os.path.join(ROOT, "Scripts", "repro", "1008-topods-cast-guard",
                           "shapetype_census.py")
HEADERS = os.path.join(ROOT, "Libraries", "OCCT.xcframework", "macos-arm64", "Headers")

BATCH = "# [batch: "

_n = [0]


def load(path):
    _n[0] += 1
    spec = importlib.util.spec_from_file_location(f"_d{_n[0]}", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def load_sample():
    """Rows grouped by batch, each batch carrying the detector and tree named in its header."""
    batches, current = {}, None
    for line in open(SAMPLE, encoding="utf-8"):
        line = line.rstrip("\n")
        if line.startswith(BATCH):
            spec = dict(
                part.strip().split(": ", 1)
                for part in line[len(BATCH):].rstrip("]").split(" | ")
                if ": " in part
            )
            name = line[len(BATCH):].split(" |", 1)[0].strip()
            current = name
            batches[current] = {"detector": spec.get("detector"), "tree": spec.get("tree"),
                                "rows": []}
            continue
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 3 or current is None:
            continue
        batches[current]["rows"].append(tuple(parts[:3]))
    return batches


def export(commit):
    tmp = tempfile.mkdtemp(prefix="occtswift-1001-score-")
    tar = subprocess.run(["git", "archive", commit, "Sources/OCCTBridge/src"],
                         cwd=ROOT, capture_output=True)
    if tar.returncode != 0:
        raise SystemExit(f"git archive {commit} failed")
    subprocess.run(["tar", "-x", "-C", tmp], input=tar.stdout, check=True)
    return tmp, os.path.join(tmp, "Sources", "OCCTBridge", "src")


def keys_hardcoded(src_dir):
    mod = load(os.path.join(COVERAGE, "detect-hardcoded-arguments.py"))
    return {f"{path}:{line}" for path, line, _c, _l, _e in mod.scan_dir(src_dir)}


def keys_dead(src_dir):
    mod = load(os.path.join(COVERAGE, "detect-dead-parameters.py"))
    return {f"{path}:{line}" for path, line, _n, _d, _t in mod.scan_dir(src_dir)}


def keys_shapetype(src_dir):
    proc = subprocess.run([sys.executable, CENSUS_1008, src_dir], capture_output=True, text=True)
    found = set()
    for line in proc.stdout.split("\n"):
        line = line.strip()
        if line.startswith("OCCTBridge_") and "  " in line:
            loc, _, fn = line.partition("  ")
            found.add(f"{loc.strip()}|{fn.strip()}")
    return found


def keys_coverage(_src_dir):
    """Every (class, unreached method) row the coverage detector reports for the sampled classes."""
    if not os.path.isdir(HEADERS):
        return None
    sampler = load(os.path.join(HERE, "sample_class_coverage.py"))
    det = sampler.load_detector()
    bridge = [f for f in os.listdir(det.BR) if f.endswith(".mm") or f.endswith(".h")]
    found = set()
    for cls in sampler.CLASSES:
        pub = det.occt_public_methods(cls)
        if pub is None:
            continue
        for name in sorted(pub - det.bridge_calls(cls, bridge)):
            found.add(f"{cls}|{name}")
    return found


HANDLERS = {
    "detect-hardcoded-arguments.py": (keys_hardcoded, lambda r: r[0]),
    "detect-dead-parameters.py": (keys_dead, lambda r: r[0]),
    "shapetype_census.py": (keys_shapetype, lambda r: f"{r[0]}|{r[1]}"),
    "occt-class-coverage.py": (keys_coverage, lambda r: f"{r[0]}|{r[1]}"),
}


def main():
    batches = load_sample()
    for name, batch in batches.items():
        detector, tree, rows = batch["detector"], batch["tree"], batch["rows"]
        handler = HANDLERS.get(detector)
        print(f"\n=== {name}   ({detector}, tree {tree})")
        if handler is None:
            print("  no handler for this detector")
            continue
        keyfn, rowkey = handler

        tmp = None
        try:
            if tree and tree != "working":
                tmp, src_dir = export(tree)
            else:
                src_dir = os.path.join(ROOT, "Sources", "OCCTBridge", "src")
            reported = keyfn(src_dir)
        finally:
            if tmp:
                shutil.rmtree(tmp, ignore_errors=True)

        if reported is None:
            print("  SKIPPED: Libraries/OCCT.xcframework is absent, so this batch cannot be scored.")
            continue

        kept = {"TRUE": 0, "FALSE": 0}
        dropped = {"TRUE": [], "FALSE": []}
        for row in rows:
            verdict = row[2]
            if rowkey(row) in reported:
                kept[verdict] += 1
            else:
                dropped[verdict].append(rowkey(row))

        n = kept["TRUE"] + kept["FALSE"]
        print(f"  sample rows                : {len(rows)}")
        print(f"  still reported             : {n}  (TRUE {kept['TRUE']}, FALSE {kept['FALSE']})")
        print(f"  no longer reported         : {len(rows) - n}  "
              f"(TRUE {len(dropped['TRUE'])}, FALSE {len(dropped['FALSE'])})")
        print(f"  total findings on this tree: {len(reported)}")
        if n:
            print(f"  FALSE-POSITIVE RATE        : {kept['FALSE']}/{n} = "
                  f"{100 * kept['FALSE'] / n:.1f}%")
        if len(rows) - n == len(rows):
            print("  NOTE: nothing matched at all. Score this batch against the tree its header")
            print("  names, not a different one.")
        if dropped["TRUE"]:
            print("  RECALL LOST, adjudicated-TRUE rows this version no longer reports:")
            for k in dropped["TRUE"]:
                print(f"    {k}")
        if dropped["FALSE"]:
            print("  FALSE POSITIVES REMOVED since the sample was adjudicated:")
            for k in dropped["FALSE"]:
                print(f"    {k}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
