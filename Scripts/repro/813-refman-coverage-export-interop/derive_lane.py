#!/usr/bin/env python3
"""#813: re-derive the Export/interop lane (Pass 4c of #807) from the pinned kernel's own headers,
and show which of it the bridge actually wraps.

#813's own `## Lane` text names eleven package prefixes and says "192 headers in the pinned
kernel." Re-deriving that count by a naive `startswith("STEPControl_")`-style prefix match on
`.hxx` files gives **190**, not 192, missing four bare `<Package>.hxx` package-utility headers that
carry no trailing underscore: `BinTools.hxx`, `RWObj.hxx`, `RWMesh.hxx`, `StlAPI.hxx` (the same
shape #812 found for `HLRAlgo.hxx`/`HLRBRep.hxx`). Once the regex accepts an optional `_Suffix`
(`^Prefix(_[^.]+)?\\.hxx$`), the count is exactly 192, matching the issue text. `.lxx` files
(`IGESControl_Reader.lxx`, `Interface_ParamList.lxx`) are inline-method files, not separate
headers, and are excluded either way.

    python3 Scripts/repro/813-refman-coverage-export-interop/derive_lane.py
    python3 Scripts/repro/813-refman-coverage-export-interop/derive_lane.py --wrapped
"""

from __future__ import annotations

import argparse
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
BRIDGE_SRC = os.path.join(ROOT, "Sources", "OCCTBridge", "src")
BRIDGE_INC = os.path.join(ROOT, "Sources", "OCCTBridge", "include")
OCCT_HEADERS = os.path.join(ROOT, "Libraries", "OCCT.xcframework", "macos-arm64", "Headers")

LANE_PREFIXES = ["STEPControl", "IGESControl", "StlAPI", "RWObj", "RWGltf", "RWPly", "RWMesh",
                  "Interface", "Transfer", "BinTools", "Resource"]

# The Swift-facing surface #813 calls out by name ("the Exporter/Importer Swift surface"),
# resolved to real files by grepping which .swift files call a bridge function defined in the four
# lane-relevant .mm files (OCCTBridge.mm, OCCTBridge_Document.mm, OCCTBridge_IO.mm,
# OCCTBridge_Mesh.mm). #813's own body warns the lane "just changed underneath this issue": Pass 4c
# (#387) landed the same day this audit was written, adding `validateExportInputs`,
# `DrawingEntityBuffer`, `dashLengths`, `writeWithProgress`, `dataViaTempFile` to
# Exporter/DXFExporter/PDFExporter/SVGExporter -- none of which touch OCCT at all, confirmed below.
LANE_SWIFT_CALLERS = [
    "Exporter", "Shape", "Document", "Shape+Mesh", "Shape+Topology", "ResourceManager",
    "UnicodeUtils", "StepHeader", "Units", "CoordinateSystem", "MeshIterators", "MeshTypes",
    "PerfMeter", "DirectoryUtils", "AssemblyNode",
]

# #813 flags this explicitly as a false-positive risk to get right, the same shape #812 had to
# handle for its own lane: PDF/SVG/DXF export is a pure-Swift dispatcher (#795), no OCCT
# counterpart at all. Measured: zero `OCCT*` identifiers in any of these three files.
PURE_SWIFT_NO_OCCT_COUNTERPART = ["PDFExporter", "SVGExporter", "DXFExporter"]


def read(path: str) -> str:
    with open(path, errors="ignore") as fh:
        return fh.read()


def lane_classes() -> dict[str, list[str]]:
    files = os.listdir(OCCT_HEADERS)
    out: dict[str, list[str]] = {}
    for p in LANE_PREFIXES:
        rx = re.compile(r"^" + re.escape(p) + r"(_[^.]+)?\.hxx$")
        out[p] = sorted(f[: -len(".hxx")] for f in files if rx.match(f))
    return out


_TOKEN_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def wrapped_classes(classes: set[str]) -> dict[str, list[str]]:
    """A class token on a non-comment line of any Sources/OCCTBridge/{src,include} file. Identical
    method to refman_census.py's own build_cache(), duplicated here (not imported) so this script
    stands alone as a derivation, matching #812's derive_lane.py / refman_census.py split."""
    out: dict[str, list[str]] = {}
    for d in (BRIDGE_SRC, BRIDGE_INC):
        for fn in sorted(os.listdir(d)):
            p = os.path.join(d, fn)
            if not (os.path.isfile(p) and fn.endswith((".mm", ".h"))):
                continue
            rel = os.path.relpath(p, ROOT)
            for line in read(p).splitlines():
                stripped = line.strip()
                if stripped.startswith(("#include", "#import", "//", "*", "/*")):
                    continue
                for tok in _TOKEN_RE.findall(stripped):
                    if tok in classes:
                        out.setdefault(tok, []).append(rel)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="#813 lane derivation, Export/interop")
    ap.add_argument("--wrapped", action="store_true", help="list each wrapped class's bridge hits")
    args = ap.parse_args()

    if not os.path.isdir(OCCT_HEADERS):
        print(f"SKIPPED: {OCCT_HEADERS} not present (the normal case in CI and a fresh clone)")
        return 0

    classes = lane_classes()
    total = sum(len(v) for v in classes.values())
    print(f"lane: {len(LANE_PREFIXES)} packages, {total} headers "
          f"(issue text says 192; naive no-bare-header prefix match gives 190)")
    for p in LANE_PREFIXES:
        print(f"  {p:<14} {len(classes[p]):>3}")

    all_classes = {c for cs in classes.values() for c in cs}
    wrapped = wrapped_classes(all_classes)
    print(f"\nwrapped (named on a non-comment bridge line): {len(wrapped)}")
    if args.wrapped:
        for c in sorted(wrapped):
            print(f"  {c:<38} {', '.join(sorted(set(wrapped[c])))}")
    else:
        for c in sorted(wrapped):
            print(f"  {c}")

    print(f"\nSwift-facing callers ({len(LANE_SWIFT_CALLERS)} files):")
    for name in LANE_SWIFT_CALLERS:
        print(f"  {name}.swift")

    print(f"\npure-Swift, no OCCT counterpart ({len(PURE_SWIFT_NO_OCCT_COUNTERPART)} files, "
          f"#813's own flagged false-positive risk, same shape as #812's ten drafting files):")
    swift_dir = os.path.join(ROOT, "Sources", "OCCTSwift")
    for name in PURE_SWIFT_NO_OCCT_COUNTERPART:
        path = os.path.join(swift_dir, name + ".swift")
        if not os.path.exists(path):
            print(f"  {name}.swift  *** MISSING, re-audit ***")
            continue
        occt_hits = re.findall(r"\bOCCT[A-Za-z0-9_]+", read(path))
        flag = "" if not occt_hits else f"  *** now calls {len(occt_hits)} OCCT* identifiers ***"
        print(f"  {name}.swift{flag}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
