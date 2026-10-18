#!/usr/bin/env python3
"""#3487: group the crashing cases of a matrix run by crash site.

usage: sites.py <probe> <results.tsv> <mode> [--sample N] [--class SIG10|SIG11|SIG6|HANG]

Re-runs each sampled SIG case alone through `probe read <mode> <file>` (whose signal handler prints
a backtrace) and groups the cases by the first frames below the handler. Prints one line per site
with its count, one example case and the frames.
"""
import random
import re
import subprocess
import sys
from collections import defaultdict


def frames(stderr):
    out = []
    for line in stderr.splitlines():
        m = re.match(r"\d+\s+\S+\s+0x[0-9a-f]+\s+(\S+) \+ \d+", line)
        if m:
            out.append(m.group(1))
    # drop the handler and the signal trampoline
    return [f for f in out if f not in ("_ZL5onSigi", "_sigtramp")]


def main():
    probe, results, mode = sys.argv[1:4]
    sample = int(sys.argv[sys.argv.index("--sample") + 1]) if "--sample" in sys.argv else 400
    only = sys.argv[sys.argv.index("--class") + 1] if "--class" in sys.argv else None
    rows = [l.rstrip("\n").split("\t") for l in open(results)]
    crashes = [r for r in rows if "SIG" in r[3] or "HANG" in r[3]]
    if only:
        crashes = [r for r in crashes if r[3] == only]
    random.Random(3487).shuffle(crashes)
    sites = defaultdict(list)
    for name, kind, label, cls, path in crashes[:sample]:
        p = subprocess.run([probe, "read", mode, path], capture_output=True, text=True)
        fr = frames(p.stderr)
        key = " <- ".join(fr[:3]) if fr else f"(no backtrace: {cls})"
        sites[key].append((kind, label, cls, path))
    for key, cases in sorted(sites.items(), key=lambda kv: -len(kv[1])):
        kind, label, cls, path = cases[0]
        print(f"{len(cases):5d}  {key}\n       e.g. {kind} {label} {cls} {path}")


if __name__ == "__main__":
    main()
