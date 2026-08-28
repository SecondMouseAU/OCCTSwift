#!/usr/bin/env python3
"""#983 (Pass 3c of #807): confirm the already-derived lane, and show it BY CALL.

#983's own `## Lane` text names the lane directly and points at #973's own artifact
(`Scripts/repro/973-ocaf-package-partition/partition_census.py --pass 983`) as the source of
truth, with an explicit instruction not to re-derive it by grep. This file does not re-derive it:
it (1) diffs #983's `## Lane` prose and this directory's own embedded package list against
`partition_census.py`'s output, so a divergence in either direction is a finding rather than a
silent drift, and (2) shows the one thing #973's package-level table does not: which of the 342
headers are individual *classes* the bridge reaches BY CALL, i.e. the format-registration surface
#983's own body names -- `BinDrivers`, `BinLDrivers`, `XmlDrivers`, `XmlLDrivers`, `BinXCAFDrivers`,
`XmlXCAFDrivers`, `PCDM_ReaderStatus`, `PCDM_StoreStatus` -- confirmed against the real bridge
source rather than assumed from the issue text.

    python3 Scripts/repro/983-ocaf-persistence-drivers/derive_lane.py
    python3 Scripts/repro/983-ocaf-persistence-drivers/derive_lane.py --calls
    python3 Scripts/repro/983-ocaf-persistence-drivers/derive_lane.py --diff-973
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
BRIDGE_SRC = os.path.join(ROOT, "Sources", "OCCTBridge", "src")
BRIDGE_INC = os.path.join(ROOT, "Sources", "OCCTBridge", "include")
PARTITION_SCRIPT = os.path.join(ROOT, "Scripts", "repro", "973-ocaf-package-partition",
                                "partition_census.py")

# The 38 packages and their header counts, per #983's own `## Lane` text and
# `partition_census.py --pass 983`. Kept here as a second, independent copy (not imported from
# `refman_census.py`) so the two files can be diffed against each other as well as against #973's.
FAMILY_COUNTS: dict[str, int] = {
    "BinDrivers": 4, "BinLDrivers": 6, "BinMDF": 9, "BinMDataStd": 23, "BinMDataXtd": 7,
    "BinMDocStd": 2, "BinMFunction": 4, "BinMNaming": 3, "BinMXCAFDoc": 15, "BinObjMgt": 10,
    "BinTObjDrivers": 8, "BinXCAFDrivers": 3, "FSD": 7, "LDOM": 24, "PCDM": 19, "Plugin": 4,
    "ShapePersistent": 13, "StdDrivers": 2, "StdLDrivers": 2, "StdLPersistent": 16,
    "StdObjMgt": 6, "StdObject": 7, "StdPersistent": 9, "StdStorage": 11, "Storage": 36,
    "UTL": 1, "XmlDrivers": 3, "XmlLDrivers": 5, "XmlMDF": 8, "XmlMDataStd": 23,
    "XmlMDataXtd": 7, "XmlMDocStd": 2, "XmlMFunction": 4, "XmlMNaming": 4, "XmlMXCAFDoc": 15,
    "XmlObjMgt": 9, "XmlTObjDrivers": 8, "XmlXCAFDrivers": 3,
}
LANE_TOTAL = 342

# The eight classes #983's own body names as "named on a real line of Sources/OCCTBridge today".
# Confirmed below by grepping the real bridge source, not assumed from the issue text.
FORMAT_REGISTRATION_SURFACE = [
    "BinDrivers", "BinLDrivers", "XmlDrivers", "XmlLDrivers",
    "BinXCAFDrivers", "XmlXCAFDrivers", "PCDM_ReaderStatus", "PCDM_StoreStatus",
]


def _read(path: str) -> str:
    with open(path, errors="ignore") as fh:
        return fh.read()


def bridge_files() -> list[str]:
    out = []
    for d in (BRIDGE_SRC, BRIDGE_INC):
        for fn in sorted(os.listdir(d)):
            if fn.endswith((".mm", ".h")):
                out.append(os.path.join(d, fn))
    return out


def find_calls(cls: str) -> list[tuple[str, int, str]]:
    """Every non-comment line in the bridge naming `cls` as a bare token (`Cls::Method`,
    `Cls(...)`, `#include <Cls.hxx>` does NOT count -- an include is a use of nothing)."""
    hits = []
    pat = re.compile(r"\b" + re.escape(cls) + r"\b")
    for path in bridge_files():
        rel = os.path.relpath(path, ROOT)
        for lineno, line in enumerate(_read(path).splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith(("#include", "#import", "//", "*", "/*")):
                continue
            if pat.search(stripped):
                hits.append((rel, lineno, stripped))
    return hits


def diff_973() -> int:
    """Run #973's own partition census and diff its `--pass 983` package/header table against
    FAMILY_COUNTS above. This is the "consume it, don't re-derive it" check #983 asks for."""
    if not os.path.exists(PARTITION_SCRIPT):
        print(f"SKIPPED: {PARTITION_SCRIPT} not found")
        return 2
    proc = subprocess.run([sys.executable, PARTITION_SCRIPT, "--pass", "983"],
                          capture_output=True, text=True)
    out = proc.stdout
    if proc.returncode == 2:
        print("#973's partition_census.py --pass 983 could not run (environment):")
        print(out.strip() or proc.stderr.strip())
        return 2
    found: dict[str, int] = {}
    for m in re.finditer(r"^\s*([A-Za-z]+)_\s+(\d+) headers", out, re.M):
        found[m.group(1)] = int(m.group(2))
    msgs = []
    for pkg in sorted(set(found) | set(FAMILY_COUNTS)):
        if found.get(pkg) != FAMILY_COUNTS.get(pkg):
            msgs.append(f"  {pkg}: partition_census.py says {found.get(pkg)!r}, "
                        f"this file says {FAMILY_COUNTS.get(pkg)!r}")
    if msgs:
        print("DRIFT against Scripts/repro/973-ocaf-package-partition/partition_census.py "
              "--pass 983:")
        for m in msgs:
            print(m)
        return 1
    total_973 = sum(found.values())
    print(f"agrees with partition_census.py --pass 983: {len(found)} packages, "
          f"{total_973} headers")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="#983 lane derivation and confirmation")
    ap.add_argument("--calls", action="store_true",
                    help="print every bridge call site for the 8 format-registration classes")
    ap.add_argument("--diff-973", action="store_true",
                    help="diff this file's FAMILY_COUNTS against partition_census.py --pass 983")
    args = ap.parse_args()

    if args.diff_973:
        return diff_973()

    table_total = sum(FAMILY_COUNTS.values())
    exit_code = 0
    if table_total != LANE_TOTAL:
        print(f"LANE TOTAL DRIFT: FAMILY_COUNTS sums to {table_total}, LANE_TOTAL says "
              f"{LANE_TOTAL}")
        exit_code = 1
    if len(FAMILY_COUNTS) != 38:
        print(f"PACKAGE COUNT DRIFT: FAMILY_COUNTS has {len(FAMILY_COUNTS)} packages, "
              "#983 says 38")
        exit_code = 1

    print(f"#983 OCAF persistence and format drivers: {len(FAMILY_COUNTS)} packages, "
          f"{table_total} headers")
    print()
    print("format-registration surface (the whole point of this lane, per #983's own body):")
    for cls in FORMAT_REGISTRATION_SURFACE:
        hits = find_calls(cls)
        files = sorted({f for f, _, _ in hits})
        status = f"{len(hits)} call site(s) in {', '.join(files)}" if hits else "NO CALL SITE FOUND"
        print(f"  {cls:<20} {status}")
        if not hits:
            exit_code = 1
        if args.calls:
            for f, lineno, line in hits:
                print(f"      {f}:{lineno}  {line}")

    print()
    print("all other classes in this lane are machinery those seven functions plus the six")
    print("OCCTDocumentDefineFormat* / OCCTDocumentSaveOCAF* / OCCTDocumentLoadOCAF entry points")
    print("configure; see refman_census.py for the per-class table.")

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
