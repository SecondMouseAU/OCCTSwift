#!/usr/bin/env python3
"""#811: re-derive the features lane's real bridge surface BY CALL, not by keyword.

#385's scope section says `OCCTBridge_ProjLib_NLPlate.mm` "holds 15 of this lane's 32 bridge
calls". Both halves of that were taken when `GDTInfo.swift` was 29 lines. It is now
`GDTRead.swift`, several hundred lines longer, and the lane calls 60 bridge functions, not 32.
Line counts are not quoted in any prose around this script, only printed by it, because every
figure this pass typed by hand went stale inside the branch that typed it.

The derivation is deliberately not a keyword grep. #385's own first scope came from one and was
inverted: it pointed the pass at `OCCTBridge_Modeling.mm`, which backs exactly ONE of this lane's
calls, and missed `OCCTBridge_ProjLib_NLPlate.mm`, which backs fifteen. So this walks:

    lane Swift file -> every OCCT* identifier in it, comments and strings stripped
                    -> the .mm that DEFINES that symbol
                    -> the count per .mm

A symbol that resolves to no definition is reported rather than dropped, and the shipped run
reports **0**. That zero is the comment stripper's doing and is the reason it exists. Measured
with the stripper switched off, the run reports **two**: `OCCT` and `OCCTDesignLoop`, both
prose inside `///` text.

An earlier draft said three, adding `OCCTFacesAreAdjacent`, and that was wrong for an
instructive reason. It IS named only in comments, in `FeatureRecognition.swift` and in
`OCCTBridge_BRepGraph.h`, and #784 removed the function itself. But `bridge_declarations()`
does not strip comments, so the header's `///` mention still resolves it and it lands in
`types` rather than in `unresolved`. The stripper on the SWIFT side is what this docstring is
about; the bridge side has no equivalent and does not need one, because a false `types` entry
changes no count this census reports. `OCCTFaceGetSharedEdgeCount` and
`OCCTFaceGetSharedEdges` are the shape one step behind: still real, still declared, and taken
off this lane's call path by #783.

    python3 Scripts/repro/811-refman-coverage-features/derive_lane.py
    python3 Scripts/repro/811-refman-coverage-features/derive_lane.py --calls
    python3 Scripts/repro/811-refman-coverage-features/derive_lane.py --substrate

`--substrate` prints the fifteen packages below this lane that no pass of #807 names, with their
measured bridge and docs reach: the table `refman_census.py`'s docstring hands off.
"""

from __future__ import annotations

import argparse
import collections
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
SWIFT_DIR = os.path.join(ROOT, "Sources", "OCCTSwift")
BRIDGE_SRC = os.path.join(ROOT, "Sources", "OCCTBridge", "src")
BRIDGE_INC = os.path.join(ROOT, "Sources", "OCCTBridge", "include")
DOCS_DIR = os.path.join(ROOT, "docs")
OCCT_HEADERS = os.path.join(ROOT, "Libraries", "OCCT.xcframework", "macos-arm64", "Headers")

# Pass 4a's settled lane, re-measured on 2026-08-21. `DraftInfo.swift` was deleted during the pass
# and `GDTInfo.swift` became `GDTRead.swift`, which is why #385's own file list does not match.
LANE_SWIFT = ["FeatureRecognition", "ThreadFeatures", "SheetMetal", "FeatureReconstructor",
              "PlateSolver", "GDTWrite", "GDTRead", "Sketch", "Helix"]

# The fifteen packages below this lane's public API that no pass of #807 names. Established by
# grepping every sub-issue body of #807 for each prefix; only #1021, a follow-up rather than a lane
# owner, names any of them.
SUBSTRATE_PACKAGES = ["BRepBlend", "Blend", "BlendFunc", "ChFiDS", "ChFiKPart", "BRepOffset",
                      "Draft", "BiTgte", "MAT", "MAT2d", "Bisector", "BRepFill", "GeomFill",
                      "AdvApp2Var", "AdvApprox"]


def read(path: str) -> str:
    with open(path, errors="ignore") as fh:
        return fh.read()


def strip_swift_comments(text: str) -> str:
    """Remove // and /* */ comments and string literals, so a name in prose is not a call."""
    text = re.sub(r'/\*.*?\*/', ' ', text, flags=re.S)
    text = re.sub(r'//[^\n]*', ' ', text)
    text = re.sub(r'"""(?:.|\n)*?"""', ' ', text)
    text = re.sub(r'"(?:\\.|[^"\\\n])*"', ' ', text)
    return text


def bridge_definitions() -> dict[str, set[str]]:
    """Every OCCT* function DEFINED in a bridge .mm, mapped to the files defining it."""
    out: dict[str, set[str]] = {}
    for fn in sorted(os.listdir(BRIDGE_SRC)):
        if not fn.endswith(".mm"):
            continue
        text = read(os.path.join(BRIDGE_SRC, fn))
        for m in re.finditer(r'^\s*(?:[A-Za-z_][A-Za-z0-9_ \*<>,:&]*?)\b(OCCT[A-Za-z0-9_]+)\s*\(',
                             text, re.M):
            out.setdefault(m.group(1), set()).add(fn)
    return out


def bridge_declarations() -> dict[str, set[str]]:
    out: dict[str, set[str]] = {}
    for fn in sorted(os.listdir(BRIDGE_INC)):
        if not fn.endswith(".h"):
            continue
        text = read(os.path.join(BRIDGE_INC, fn))
        for m in re.finditer(r'\b(OCCT[A-Za-z0-9_]+)\b', text):
            out.setdefault(m.group(1), set()).add(fn)
    return out


def derive():
    used: dict[str, set[str]] = collections.defaultdict(set)
    loc = {}
    missing = [n for n in LANE_SWIFT if not os.path.exists(os.path.join(SWIFT_DIR, n + ".swift"))]
    if missing:
        # LANE_SWIFT has drifted twice already (`DraftInfo.swift` deleted, `GDTInfo.swift`
        # renamed), so report the drift rather than dying on a FileNotFoundError.
        raise SystemExit("LANE_SWIFT names files that no longer exist: "
                         + ", ".join(missing)
                         + "\nThe lane has drifted; audit those classes before re-running.")
    for name in LANE_SWIFT:
        path = os.path.join(SWIFT_DIR, name + ".swift")
        raw = read(path)
        loc[name] = len(raw.splitlines())
        for m in re.finditer(r'\bOCCT[A-Za-z0-9_]*', strip_swift_comments(raw)):
            used[m.group(0)].add(name)
    defined = bridge_definitions()
    declared = bridge_declarations()

    calls, types, unresolved = {}, {}, {}
    for sym in sorted(used):
        if sym in defined:
            calls[sym] = defined[sym]
        elif sym in declared:
            types[sym] = declared[sym]
        else:
            unresolved[sym] = used[sym]
    return used, loc, calls, types, unresolved


def substrate_table() -> list[tuple[str, int, int, int]]:
    if not os.path.isdir(OCCT_HEADERS):
        return []
    classes = collections.defaultdict(list)
    for fn in sorted(os.listdir(OCCT_HEADERS)):
        if not fn.endswith(".hxx"):
            continue
        stem = fn[:-4]
        pkg = stem.split("_", 1)[0] if "_" in stem else stem
        if pkg in SUBSTRATE_PACKAGES:
            classes[pkg].append(stem)

    bridge = []
    for d in (BRIDGE_SRC, BRIDGE_INC):
        for fn in sorted(os.listdir(d)):
            p = os.path.join(d, fn)
            if os.path.isfile(p) and fn.endswith((".mm", ".h")):
                bridge.append(read(p).splitlines())
    docs = []
    for dirpath, _dirs, files in os.walk(DOCS_DIR):
        for fn in sorted(files):
            if fn.endswith(".md") and fn != "CHANGELOG.md":
                docs.append(read(os.path.join(dirpath, fn)))

    rows = []
    for pkg in SUBSTRATE_PACKAGES:
        cs = classes.get(pkg, [])
        nb = nd = 0
        for c in cs:
            pat = re.compile(r"\b" + re.escape(c) + r"\b")
            if any(pat.search(s.strip()) and not s.strip().startswith(("#include", "//", "*", "/*"))
                   for lines in bridge for s in lines):
                nb += 1
            if any(pat.search(t) for t in docs):
                nd += 1
        rows.append((pkg, len(cs), nb, nd))
    return rows


def main() -> int:
    ap = argparse.ArgumentParser(description="#811 lane derivation, by call")
    ap.add_argument("--calls", action="store_true", help="list every call, grouped by .mm")
    ap.add_argument("--substrate", action="store_true",
                    help="the fifteen unowned packages below this lane, with measured reach")
    args = ap.parse_args()

    used, loc, calls, types, unresolved = derive()

    print(f"lane Swift files: {len(LANE_SWIFT)}, {sum(loc.values())} lines")
    for name in LANE_SWIFT:
        print(f"  {name + '.swift':<32} {loc[name]:>5}")
    print()
    print(f"distinct OCCT* identifiers used : {len(used)}")
    print(f"bridge FUNCTIONS called         : {len(calls)}")
    print(f"bridge types/enums referenced   : {len(types)}")
    print(f"unresolved (prose, not calls)   : {len(unresolved)}  "
          f"{', '.join(sorted(unresolved)) if unresolved else ''}")
    print()
    by_mm = collections.Counter()
    for files in calls.values():
        for f in files:
            by_mm[f] += 1
    print("bridge calls per .mm:")
    for f, n in by_mm.most_common():
        print(f"  {f:<40} {n:>3}")

    if args.calls:
        print()
        for f, _n in by_mm.most_common():
            print(f"--- {f} ---")
            for sym in sorted(s for s in calls if f in calls[s]):
                print(f"    {sym:<50} <- {', '.join(sorted(used[sym]))}")

    if args.substrate:
        rows = substrate_table()
        print()
        if not rows:
            print(f"substrate table: SKIPPED, {OCCT_HEADERS} not present")
        else:
            print("packages below this lane that no pass of #807 names:")
            print(f"  {'package':<16}{'headers':>9}{'bridge-named':>14}{'docs-named':>12}")
            tot = [0, 0, 0]
            for pkg, h, nb, nd in rows:
                print(f"  {pkg:<16}{h:>9}{nb:>14}{nd:>12}")
                tot[0] += h
                tot[1] += nb
                tot[2] += nd
            print(f"  {'TOTAL':<16}{tot[0]:>9}{tot[1]:>14}{tot[2]:>12}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
