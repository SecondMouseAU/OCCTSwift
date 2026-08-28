#!/usr/bin/env python3
"""#814: re-derive the Mesh/presentation/misc lane's real Swift call surface BY CALL.

#814's own `## Lane` text names nine OCCT packages directly (`BRepMesh_*`, `Poly_*`,
`IMeshData_*`/`IMeshTools_*`, `AIS_*`, `Graphic3d_*`, `Image_*`, `StdPrs_*`, `StdSelect_*`) plus
"the `Mesh`/`Display`/`PixMap` Swift surface". Unlike #811/#812 (where the package list itself had
to be re-derived), the nine packages are not in question here, #973's partition put them here and
#814's own body re-states them with per-package header counts that match the pinned kernel exactly
(measured: 368, see `refman_census.py`'s own `--reverify-lane`). What #814 explicitly warns needs
re-derivation is narrower and more urgent: **the Swift-side call surface changed under this issue**.
Pass 4d (#388, whose duplication work #814 runs after) closed the same day this pass started:
`PresentationMesh.swift` gained two new private helpers (`buildShadedMeshData`/`buildEdgeMeshData`)
deduplicating four call sites' struct conversion, and `OCCTBridge_Mesh.mm`'s
`OCCTShapeWriteSTLBinary`/`OCCTShapeWriteSTLAscii` were rewritten to delegate elsewhere (#1225/#1230
territory). Confirmed by reading both diffs directly rather than assuming the pre-close shape: the
STL delegation is a body-inside-the-same-two-functions change (no OCCT class added or removed) and
the two new helpers are a pure-Swift refactor of struct fields already captured below, so neither
changes which OCCT classes this lane's Swift files reach. Re-derived rather than skipped, per
#814's own instruction not to assume the pre-Pass-4d shape.

    python3 Scripts/repro/814-refman-coverage-mesh-presentation-misc/derive_lane.py
    python3 Scripts/repro/814-refman-coverage-mesh-presentation-misc/derive_lane.py --calls
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
HEADERS = os.path.join(ROOT, "Libraries", "OCCT.xcframework", "macos-arm64", "Headers")

LANE_PACKAGES = ("BRepMesh", "Poly", "IMeshData", "IMeshTools", "AIS", "Graphic3d", "Image",
                 "StdPrs", "StdSelect")

# The Swift files that actually reach this lane's OCCT packages, confirmed by grepping every
# `OCCT*` identifier each one uses and reading the bridge function each resolves to. `Mesh`,
# `Display`, `PixMap` (#814's own shorthand) turn out to be eight files, not three: the Mesh/mesh-
# iterator/presentation-mesh surface is four files (`Mesh.swift` itself plus three siblings #814's
# shorthand doesn't name), `Display` is `DisplayDrawer.swift` (wraps `Prs3d_Drawer`, out of this
# lane's own packages, see NOT_IN_LANE below, but the file also has no other lane calls), and
# `PixMap` is `PixMap.swift`. A ninth file, `Annotation.swift`, is IN this lane (`AIS_TextLabel`)
# even though it is not one of #814's three shorthand names, because AIS_ is this lane's own
# package (unlike #812's HLR lane, where the identical file's AIS_/PrsDim_ calls were "adjacent,
# not in lane" -- there AIS_ was not that lane's package; here it is).
LANE_SWIFT_CALLERS = [
    "Mesh", "MeshCoordinateSystem", "MeshIterators", "MeshTypes", "PixMap", "PresentationMesh",
    "Shape+Mesh", "DisplayDrawer", "Annotation",
]

# Adjacent files/packages this lane's own calls touch, deliberately NOT audited here, with the
# measured reason -- stating why something is out is the point of re-deriving by call instead of
# trusting a name.
NOT_IN_LANE = {
    "Annotation.swift's Dimension* calls":
        "OCCTDimensionCreate* construct PrsDim_LengthDimension/RadiusDimension/AngleDimension/"
        "DiameterDimension (package PrsDim_), not named by #814's own ## Lane text",
    "DisplayDrawer.swift's Prs3d_Drawer wrap":
        "Prs3d_ is not one of #814's nine packages either (the same fact #812's README establishes "
        "for the Drawing lane); DisplayDrawer.swift has no other-lane call, it is listed above only "
        "because #814's own shorthand names 'Display'",
    "PresentationMesh.swift's OCCTShapeGetShadedMesh/EdgeMesh":
        "these build Poly_Triangulation/BRepMesh_ data directly (IN lane); named here only to record "
        "that the two new v#388 helpers (buildShadedMeshData/buildEdgeMeshData) are a pure-Swift "
        "struct-conversion refactor of the same OCCTShadedMeshData/OCCTEdgeMeshData fields, adding "
        "no OCCT class and removing none",
}


def read(path: str) -> str:
    with open(path, errors="ignore") as fh:
        return fh.read()


def strip_swift_comments(text: str) -> str:
    text = re.sub(r'/\*.*?\*/', ' ', text, flags=re.S)
    text = re.sub(r'//[^\n]*', ' ', text)
    text = re.sub(r'"""(?:.|\n)*?"""', ' ', text)
    text = re.sub(r'"(?:\\.|[^"\\\n])*"', ' ', text)
    return text


def bridge_definitions() -> dict[str, set[str]]:
    out: dict[str, set[str]] = {}
    for fn in sorted(os.listdir(BRIDGE_SRC)):
        if not fn.endswith(".mm"):
            continue
        text = read(os.path.join(BRIDGE_SRC, fn))
        for m in re.finditer(r'^\s*(?:[A-Za-z_][A-Za-z0-9_ \*<>,:&]*?)\b(OCCT[A-Za-z0-9_]+)\s*\(',
                             text, re.M):
            out.setdefault(m.group(1), set()).add(fn)
    return out


def _all_names() -> list[str]:
    return LANE_SWIFT_CALLERS


def derive():
    used: dict[str, set[str]] = collections.defaultdict(set)
    loc = {}
    names = _all_names()
    missing = [n for n in names if not os.path.exists(os.path.join(SWIFT_DIR, n + ".swift"))]
    if missing:
        raise SystemExit("lane names files that no longer exist: " + ", ".join(missing)
                         + "\nThe lane has drifted; re-audit those files before re-running.")
    for name in names:
        path = os.path.join(SWIFT_DIR, name + ".swift")
        raw = read(path)
        loc[name] = len(raw.splitlines())
        for m in re.finditer(r'\bOCCT[A-Za-z0-9_]*', strip_swift_comments(raw)):
            used[m.group(0)].add(name)
    defined = bridge_definitions()
    return used, loc, defined


def header_count(pkg: str) -> int:
    pat = re.compile(rf"^{pkg}(_[^.]+)?\.hxx$")
    if not os.path.isdir(HEADERS):
        return -1
    return sum(1 for fn in os.listdir(HEADERS) if pat.match(fn))


def main() -> int:
    ap = argparse.ArgumentParser(description="#814 lane derivation, by call")
    ap.add_argument("--calls", action="store_true", help="list every lane-relevant call")
    args = ap.parse_args()

    used, loc, defined = derive()

    print(f"lane Swift files audited for calls: {len(_all_names())}, {sum(loc.values())} lines")
    for name in _all_names():
        print(f"    {name + '.swift':<28} {loc[name]:>5} lines")
    print()

    print(f"pinned-kernel header counts (ls Libraries/.../Headers, matched against #814's own "
          f"## Lane text):")
    total = 0
    for pkg in LANE_PACKAGES:
        n = header_count(pkg)
        total += max(n, 0)
        print(f"    {pkg + '_':<12} {n:>4}")
    print(f"    {'TOTAL':<12} {total:>4}  (#814's own body says 368)")
    print()

    lane_defined = {s: files for s, files in defined.items()
                    if any(s in used and name in used[s] for name in _all_names())}
    by_prefix: dict[str, set[str]] = collections.defaultdict(set)
    for sym, files in lane_defined.items():
        # bucket by the bridge function's own OCCT*-name prefix, informational only
        by_prefix[sym.split("Create")[0] if "Create" in sym else sym].add(sym)

    print(f"distinct OCCT* bridge functions called across the {len(_all_names())} files: "
          f"{len(lane_defined)}")
    by_mm = collections.Counter()
    for sym, files in lane_defined.items():
        for f in files:
            by_mm[f] += 1
    print("  calls per .mm:")
    for f, n in by_mm.most_common():
        print(f"    {f:<32} {n:>3}")

    if args.calls:
        print()
        for sym in sorted(lane_defined):
            print(f"    {sym:<40} <- {', '.join(sorted(used[sym]))}  "
                  f"({', '.join(sorted(lane_defined[sym]))})")

    print()
    print("adjacent, deliberately NOT audited here:")
    for what, why in NOT_IN_LANE.items():
        print(f"  {what}")
        print(f"      {why}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
