#!/usr/bin/env python3
"""#3494 count matrix: every count and reference a record declares, made negative or too large.

usage: counts.py <probe> <corpus-dir>... <work-dir> <mode> [--jobs N] [--thin N] [--files a,b,c]

<probe> is what Scripts/repro/3487/build.sh makes; each <corpus-dir> holds the files <mode> reads
(`probe gen` writes the #3487 corpus, `fixtures` the #3494 one). <mode> is one of
  path, str   text BREP through BRepTools::Read (file, stream)         class `tok`
  binset      BinTools::Read, the BinTools_ShapeSet reader (*.bset)    class `bint`
  bin         BinTools_ShapeReader (*.bin)                             class `bint`
Class `tok`: every standalone integer token of the text, replaced by each of -1, -2^31, 2^31-1,
10^6 and 10^8 (a count, an index, a degree, a flag). Class `bint`: the four bytes at every offset
of the binary file replaced by the same values as a little-endian int. One forked child per case
(`probe batch`), so a fault ends only that child and a spin ends at 0.1 s of its own CPU (HANG).
Exit 0 always: a measurement, not a gate.
"""
import os
import re
import struct
import subprocess
import sys
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor

VALUES = (-1, -(2**31), 2**31 - 1, 10**6, 10**8)


def tok_cases(name, data):
    text = data.decode("latin-1")
    for m in re.finditer(r"(?<=\s)\d+(?=\s)", text):
        for v in VALUES:
            yield ("tok", f"{name}@{m.start()}={v}", (text[: m.start()] + str(v) + text[m.end():]).encode("latin-1"))


def bint_cases(name, data, stride):
    for off in range(0, len(data) - 3, stride):
        for v in VALUES:
            d = bytearray(data)
            d[off:off + 4] = struct.pack("<i", v)
            if bytes(d) != data:
                yield ("bint", f"{name}@{off}={v}", bytes(d))


def run_chunk(probe, mode, listfile):
    return subprocess.run([probe, "batch", mode, listfile], capture_output=True, text=True).stdout


def main():
    args = sys.argv[1:]
    opts = {}
    for key in ("--jobs", "--thin", "--files"):
        if key in args:
            i = args.index(key)
            opts[key] = args[i + 1]
            del args[i:i + 2]
    probe, *dirs, work, mode = args
    jobs = int(opts.get("--jobs", 8))
    thin = int(opts.get("--thin", 1))
    files = opts["--files"].split(",") if "--files" in opts else None
    ext = {"path": ".brep", "str": ".brep", "binset": ".bset", "bin": ".bin"}[mode]
    cases = []
    for corpus in dirs:
        for fn in sorted(os.listdir(corpus)):
            if not fn.endswith(ext):
                continue
            name = fn[: -len(ext)]
            if files and name not in files:
                continue
            data = open(os.path.join(corpus, fn), "rb").read()
            if ext == ".brep":
                gen = tok_cases(name, data)
            else:
                gen = bint_cases(name, data, 1 if len(data) <= 8000 else 4)
            cases.extend((name, *c) for c in gen)
    if thin > 1:
        cases = [c for i, c in enumerate(cases) if i % thin == 0]
    casedir = os.path.join(work, "cases")
    os.makedirs(casedir, exist_ok=True)
    paths = []
    for i, (name, kind, label, blob) in enumerate(cases):
        p = os.path.join(casedir, f"{i}{ext}")
        with open(p, "wb") as f:
            f.write(blob)
        paths.append(p)
    lists = []
    for j in range(jobs):
        lf = os.path.join(work, f"list{j}.txt")
        open(lf, "w").write("\n".join(paths[j::jobs]) + "\n")
        lists.append(lf)
    with ThreadPoolExecutor(jobs) as ex:
        outs = list(ex.map(lambda lf: run_chunk(probe, mode, lf), lists))
    result = {}
    for out in outs:
        for line in out.splitlines():
            idx, cls, path = [x.strip() for x in line.split("|", 2)]
            result[path] = cls
    summary = defaultdict(Counter)
    with open(os.path.join(work, f"results-{mode}.tsv"), "w") as f:
        for (name, kind, label, blob), p in zip(cases, paths):
            cls = result.get(p, "LOST")
            if cls.startswith("shape"):
                cls = "accepted-valid" if "valid=1" in cls else "accepted-INVALID"
            elif cls.startswith("null"):
                cls = "refused-null"
            elif cls.startswith("threw"):
                cls = "refused-threw"
            summary[name][cls] += 1
            f.write("\t".join((name, kind, label, cls, p)) + "\n")
    print(f"mode={mode} cases={len(cases)}")
    total = Counter()
    for name, c in sorted(summary.items()):
        total.update(c)
        print(f"  {name:20s} " + " ".join(f"{k}={v}" for k, v in sorted(c.items())))
    print("TOTAL " + " ".join(f"{k}={v}" for k, v in sorted(total.items())))


if __name__ == "__main__":
    main()
