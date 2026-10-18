#!/usr/bin/env python3
"""#3487 crash matrix: damaged BREP text through BRepTools::Read, one forked child per case (a 0.3 s CPU spin is a HANG).

usage: matrix.py <probe> <corpus-dir> <work-dir> <mode> [--jobs N] [--only prefix|byte|struct]
                 [--thin N] [--files a,b,c]

--thin N keeps every Nth prefix and byte case (all structural cases, and the last 80 bytes of every
file, are kept): a baseline run against the unfixed reader spends 0.1 s of CPU on each spin, so
the full matrix is run against the guarded stream and a thinned one against the unguarded.

<probe> is the binary build.sh makes; <corpus-dir> is what `probe gen <dir>` wrote; <mode> is one
of path, str, strx (see probe.mm). Cases are written under <work-dir>, run through `probe batch`
(a fault ends only the forked child), and counted per source file and case class. Exit 0 always:
this is a measurement, not a gate.
"""
import os
import random
import re
import subprocess
import sys
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor

SECTIONS = ["Locations", "Curve2ds", "Curves", "Polygon3D", "PolygonOnTriangulations",
            "Surfaces", "Triangulations", "TShapes"]


def prefix_cases(name, data):
    # every strict prefix of a small file; of a large one, every ninth and the last 80 bytes
    stride = 1 if len(data) <= 3000 else 9
    cuts = sorted(set(range(0, len(data), stride)) | set(range(max(0, len(data) - 80), len(data))))
    for n in cuts:
        yield ("prefix", f"{name}@{n}", data[:n])


def byte_cases(name, data):
    # every offset for a small file, a stride for a large one, five replacement values each
    stride = 2 if len(data) <= 3000 else 13
    for off in range(0, len(data), stride):
        for v in (0x00, 0xFF, ord("9"), ord("-"), ord("*")):
            if data[off] == v:
                continue
            d = bytearray(data)
            d[off] = v
            yield ("byte", f"{name}@{off}={v:02x}", bytes(d))


def struct_cases(name, data):
    text = data.decode("latin-1")
    # a count raised, a count lowered (every section header)
    for sec in SECTIONS:
        m = re.search(rf"^{sec} (-?\d+)", text, re.M)
        if not m:
            continue
        n = int(m.group(1))
        for label, nv in (("plus1", n + 1), ("plus100", n + 100), ("big", 10**6), ("max", 2**31 - 1),
                          ("over", 2**31), ("huge", 10**12), ("neg", -1), ("zero", 0),
                          ("minus1", n - 1), ("half", n // 2)):
            if nv == n:
                continue
            t = text[:m.start(1)] + str(nv) + text[m.end(1):]
            yield ("count", f"{name}:{sec}={label}", t.encode("latin-1"))
    # a reference to a missing TShape / location, root and in-record
    ts = re.search(r"^TShapes \d+\n", text, re.M)
    if ts:
        body_start = ts.end()
        refs = list(re.finditer(r"([+\-ie])(\d+) (\d+) ", text[body_start:]))
        rng = random.Random(name)
        picks = refs if len(refs) <= 40 else rng.sample(refs, 40)
        for m in picks:
            a, b = body_start + m.start(), body_start + m.end()
            for label, rep in (("shape9999", f"{m.group(1)}9999 {m.group(3)} "),
                               ("shape0", f"{m.group(1)}0 {m.group(3)} "),
                               ("shapeHuge", f"{m.group(1)}99999999999 {m.group(3)} "),
                               ("loc9999", f"{m.group(1)}{m.group(2)} 9999 "),
                               ("locNeg", f"{m.group(1)}{m.group(2)} -3 ")):
                yield ("ref", f"{name}:ref@{a}:{label}", (text[:a] + rep + text[b:]).encode("latin-1"))
    # the root line: missing, wrong index, wrong location, no location, junk
    root = re.search(r"\n[+\-ie]\d+ \d+ *$", text)
    if root:
        a = root.start() + 1
        for label, rep in (("rootMissing", ""), ("root9999", "+9999 0 "), ("root0", "+0 0 "),
                           ("rootNeg", "-1 0 "), ("rootLoc", "+1 9999 "), ("rootNoLoc", "+1"),
                           ("rootNull", "* "), ("rootJunk", "zzz"), ("rootSpace", "+1 0 \n\n\n")):
            yield ("root", f"{name}:{label}", (text[:a] + rep).encode("latin-1"))
    # long tokens where a fixed 255 byte buffer reads a word
    for label, needle in (("longTShapes", "TShapes"), ("longSection", "Curves")):
        if needle in text:
            yield ("long", f"{name}:{label}", text.replace(needle, "A" * 400, 1).encode("latin-1"))
    if ts:
        a = ts.end()
        yield ("long", f"{name}:longShapeType", (text[:a] + "Q" * 400 + text[a + 2:]).encode("latin-1"))
    # header variants
    yield ("header", f"{name}:V4", text.replace("Topology V3", "Topology V4").replace("Topology V2", "Topology V4").replace("Topology V1", "Topology V4").encode("latin-1"))
    yield ("header", f"{name}:noHeader", re.sub(r"^CASCADE.*\n", "", text, count=1, flags=re.M).encode("latin-1"))
    yield ("header", f"{name}:empty", b"")
    yield ("header", f"{name}:nl", b"\n" * 40)
    yield ("header", f"{name}:binary", bytes(range(256)))


def run_chunk(probe, mode, listfile):
    p = subprocess.run([probe, "batch", mode, listfile], capture_output=True, text=True)
    return p.stdout


def main():
    probe, corpus, work, mode = sys.argv[1:5]
    jobs = int(sys.argv[sys.argv.index("--jobs") + 1]) if "--jobs" in sys.argv else 8
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    thin = int(sys.argv[sys.argv.index("--thin") + 1]) if "--thin" in sys.argv else 1
    files = sys.argv[sys.argv.index("--files") + 1].split(",") if "--files" in sys.argv else None
    sizes = {}
    os.makedirs(work, exist_ok=True)
    cases = []
    for fn in sorted(os.listdir(corpus)):
        ext = ".bin" if mode == "bin" else ".brep"
        if not fn.endswith(ext):
            continue
        name = fn[: -len(ext)]
        if files and name not in files:
            continue
        data = open(os.path.join(corpus, fn), "rb").read()
        sizes[name] = len(data)
        gens = []
        if only in (None, "prefix"):
            gens.append(prefix_cases)
        if only in (None, "byte"):
            gens.append(byte_cases)
        if only in (None, "struct") and mode != "bin":  # the structural cases are BREP text
            gens.append(struct_cases)
        for g in gens:
            cases.extend((name, *c) for c in g(name, data))
    if thin > 1:
        kept = []
        for i, c in enumerate(cases):
            name, kind, label, blob = c
            tail = kind == "prefix" and len(blob) >= sizes[name] - 80
            if kind in ("prefix", "byte") and not tail and i % thin:
                continue
            kept.append(c)
        cases = kept
    casedir = os.path.join(work, "cases")
    os.makedirs(casedir, exist_ok=True)
    paths = []
    for i, (name, kind, label, blob) in enumerate(cases):
        p = os.path.join(casedir, f"{i}.brep")
        with open(p, "wb") as f:
            f.write(blob)
        paths.append(p)
    chunks = [paths[i::jobs] for i in range(jobs)]
    lists = []
    for j, ch in enumerate(chunks):
        lf = os.path.join(work, f"list{j}.txt")
        open(lf, "w").write("\n".join(ch) + "\n")
        lists.append(lf)
    with ThreadPoolExecutor(jobs) as ex:
        outs = list(ex.map(lambda lf: run_chunk(probe, mode, lf), lists))
    result = {}
    for out in outs:
        for line in out.splitlines():
            idx, cls, path = [x.strip() for x in line.split("|", 2)]
            result[path] = cls
    summary = defaultdict(Counter)
    rows = []
    for (name, kind, label, blob), p in zip(cases, paths):
        cls = result.get(p, "LOST")
        if cls.startswith("shape"):
            cls = "accepted-valid" if "valid=1" in cls else "accepted-INVALID"
        elif cls.startswith("null"):
            cls = "refused-null"
        elif cls.startswith("threw"):
            cls = "refused-threw"
        summary[(name, kind)][cls] += 1
        rows.append((name, kind, label, cls, p))
    with open(os.path.join(work, f"results-{mode}.tsv"), "w") as f:
        for r in rows:
            f.write("\t".join(r) + "\n")
    print(f"mode={mode} cases={len(cases)}")
    total = defaultdict(Counter)
    for (name, kind), c in sorted(summary.items()):
        total[kind].update(c)
        print(f"  {name:20s} {kind:7s} " + " ".join(f"{k}={v}" for k, v in sorted(c.items())))
    print("TOTAL by kind")
    for kind, c in total.items():
        print(f"  {kind:7s} " + " ".join(f"{k}={v}" for k, v in sorted(c.items())))


if __name__ == "__main__":
    main()
