#!/usr/bin/env python3
"""#812: re-derive the Drawing/2D-annotation lane's real bridge surface BY CALL, not by keyword.

#812's own `## Lane` text names three OCCT packages (`HLRBRep_*`, `HLRAlgo_*`, `Prs3d_* where it
backs 2D output`) plus "the `Drawing`/`DrawingAnnotation`/`DrawingSheet` Swift surface". Both halves
move once you trace actual bridge calls rather than trusting either list:

  - `Prs3d_*` contributes **zero** classes. The only two bridge sites that ever construct a
    `Prs3d_*` object (`Prs3d_Drawer`, `Prs3d_Presentation`) are `OCCTBridge_Visualization.mm` and
    `OCCTBridge.mm`, both behind `DisplayDrawer.swift` ("affect mesh generation quality" in its own
    doc comment, i.e. Metal *3D* tessellation control), never behind `Drawing.swift`/
    `DrawingAnnotation.swift`/`DrawingSheet.swift`. `grep -rn TypeOfHLR Sources/ docs/` (the one
    Prs3d_ enum that sounds 2D-shaped, `Prs3d_TypeOfHLR`) also returns nothing: nothing in this
    bridge reads it. So the lane's own qualifier ("where it backs 2D output") evaluates to nothing
    to audit, and that is a finding to STATE, not a null result to drop silently.
  - The Swift-file list undercounts in one direction and overcounts in another, and #386's own
    14-file "## Files" list (a *duplication-audit* scope, a different question) is evidence for
    neither by itself:
      * `Annotation.swift` calls `OCCTDimensionCreate*`/`OCCTTextLabelCreate`/`OCCTPointCloudCreate`,
        all defined in `OCCTBridge_AIS.mm` (`AIS_*`/`PrsDim_*`), and its own doc comments say
        "for Metal rendering" / "for visualization" throughout. Nothing under `Drawing*.swift` calls
        any of its types (`grep -rl DimensionGeometry Sources/OCCTSwift` finds only the file
        itself). It is 3D-interactive, not 2D-drawing-sheet output, and out of this lane.
      * `HatchPattern.swift` calls `OCCTHatchLines`, which builds a `Hatch_Hatcher` (package
        `Hatch_`, not `HLRBRep_`/`HLRAlgo_`/`Prs3d_`/`HLRAppli_`). Real 2D output, wrong package:
        adjacent to this lane, not IN it by the issue's own package-scoped text.
      * `Shape+Topology.swift` (never in #386's list at all) has a whole `// MARK: - v0.73.0: TKHlr.
        Extended HLR, ReflectLines, TopCnx, Intrv` section calling `OCCTHLRGetEdgesByCategory`,
        `OCCTHLRPolyGetEdgesByCategory` and `OCCTHLRCompoundOfEdges`, all defined in
        `OCCTBridge_Modeling.mm` (NOT `OCCTBridge_HLR.mm`), a second, independent HLR call path
        #1071's bridge split (PR #1130) never migrated. Documented at
        `docs/reference/Shape-HLR-Geom.md`.
      * `Shape+Drawing.swift` is split down the middle: its first half
        (`normalProjection`/`projectWire`) is `BRepOffsetAPI_NormalProjection`, #811's lane
        (Pass 4a), already audited there. Its second half calls `OCCTHLRReflectLines` /
        `OCCTHLRReflectLinesFiltered`, which construct `HLRAppli_ReflectLines`, a fourth package
        the issue text does not name at all, reached by the SAME `OCCTBridge_Modeling.mm` HLR block
        as `Shape+Topology.swift`'s calls, two lines below `OCCTHLRCompoundOfEdges`.

So the real Swift surface driving OCCT calls is four files, not three and not #386's fourteen:
`Drawing.swift`, `DrawingAutoCenterlines.swift`, `Shape+Topology.swift` (its HLR section only) and
`Shape+Drawing.swift` (its ReflectLines section only). The other ten Drawing*.swift files
(`DrawingAnnotation`, `DrawingDispatch`, `DrawingSheet`, `DrawingSymbols`, `DrawingComposition`,
`DrawingStyle`, `DrawingAutoDimensions`, `DrawingThreadAnnotation`, `Section2D`, `SheetLayout`) call
**zero** `OCCT*` symbols: pure Swift ISO 128/3098/5455 drafting-convention code, exactly what #812's
own body predicts and asks the artifact to say explicitly rather than flag as false positives.

And the audited OCCT package set widens by one for a measured reason, following #811's own
precedent (`Plate_`/`NLPlate_`/`GeomPlate_`/`BRepMAT2d_` added the same way): `HLRAppli_` is reached
directly by this lane's own calls, in the same bridge functions cluster as the HLRBRep_/HLRAlgo_
calls beside it, so it is audited here rather than left to fall through Phase 6's cracks. `TopCnx_`,
named in the same `Shape-HLR-Geom.md` section heading two words after `ReflectLines`, is NOT added:
it is edge-face transition classification for BOP/healing, a different capability that happens to
have shipped in the same v0.73.0 release batch, not a hidden-line-removal one.

    python3 Scripts/repro/812-refman-coverage-drawing/derive_lane.py
    python3 Scripts/repro/812-refman-coverage-drawing/derive_lane.py --calls
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

# Files with ZERO OCCT* identifiers (measured: `grep -oE '\bOCCT[A-Za-z0-9_]*'` returns nothing),
# pure-Swift ISO drafting-convention code. Listed so a re-run that finds one newly calling OCCT can
# report the drift rather than silently keep classifying it as inert.
LANE_SWIFT_PURE = [
    "DrawingAnnotation", "DrawingDispatch", "DrawingSheet", "DrawingSymbols",
    "DrawingComposition", "DrawingStyle", "DrawingAutoDimensions", "DrawingThreadAnnotation",
    "Section2D", "SheetLayout",
]

# Files that DO call into this lane's OCCT packages. Two are audited whole; two are audited only in
# the named section, because the rest of the file belongs to a different lane (Shape+Drawing.swift's
# normalProjection/projectWire half is #811's) or is unrelated Topology surface entirely
# (Shape+Topology.swift is 3354 lines; the HLR section is one `// MARK:` block near the end). Every
# bridge FUNCTION this lane's own capability calls is spelled `OCCTDrawing*` or `OCCTHLR*` --
# confirmed by reading every one of the six call sites, not assumed from the prefix -- so that
# prefix is used below to separate this lane's calls from the other ~250 Topology/Modeling/Healing
# calls the two partial files also make, rather than hand-carving line ranges out of either file.
LANE_SWIFT_CALLERS = ["Drawing", "DrawingAutoCenterlines", "Shape+Topology", "Shape+Drawing"]
LANE_CALL_PREFIXES = ("OCCTDrawing", "OCCTHLR")

# Adjacent files that call OCCT, but not into this lane's packages. Reported, not audited: stating
# why they're out is the whole point of a lane that re-derives itself by call instead of by name.
ADJACENT_NOT_IN_LANE = {
    "HatchPattern": "OCCTHatchLines builds a Hatch_Hatcher (package Hatch_, not named by #812)",
    "Annotation": "OCCTDimensionCreate*/OCCTTextLabelCreate/OCCTPointCloudCreate all reach "
                 "OCCTBridge_AIS.mm (AIS_*/PrsDim_*), 3D-interactive/Metal per its own doc "
                 "comments, not the 2D drawing-sheet surface; nothing under Drawing*.swift uses "
                 "its types",
    "DisplayDrawer": "wraps Prs3d_Drawer for Metal tessellation quality (\"affect mesh generation "
                     "quality\" in its own doc comment) -- backs 3D display, the one Prs3d_ use "
                     "site in the whole bridge, and exactly what #812's own qualifier "
                     "(\"where it backs 2D output\") excludes",
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


def bridge_declarations() -> dict[str, set[str]]:
    out: dict[str, set[str]] = {}
    for fn in sorted(os.listdir(BRIDGE_INC)):
        if not fn.endswith(".h"):
            continue
        text = read(os.path.join(BRIDGE_INC, fn))
        for m in re.finditer(r'\b(OCCT[A-Za-z0-9_]+)\b', text):
            out.setdefault(m.group(1), set()).add(fn)
    return out


def _all_names() -> list[str]:
    return LANE_SWIFT_PURE + LANE_SWIFT_CALLERS


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


def main() -> int:
    ap = argparse.ArgumentParser(description="#812 lane derivation, by call")
    ap.add_argument("--calls", action="store_true", help="list every call, grouped by .mm")
    args = ap.parse_args()

    used, loc, calls, types, unresolved = derive()

    print(f"lane Swift files audited for calls: {len(_all_names())}, {sum(loc.values())} lines")
    print(f"  pure-Swift, zero OCCT* identifiers ({len(LANE_SWIFT_PURE)}):")
    for name in LANE_SWIFT_PURE:
        n = sum(1 for uses in used.values() if name in uses)
        flag = "" if n == 0 else f"  *** now calls {n} OCCT* identifiers, re-audit ***"
        print(f"    {name + '.swift':<28} {loc[name]:>5} lines{flag}")
    print(f"  callers of this lane's packages ({len(LANE_SWIFT_CALLERS)}):")
    for name in LANE_SWIFT_CALLERS:
        print(f"    {name + '.swift':<28} {loc[name]:>5} lines")
    print()
    print(f"distinct OCCT* identifiers used across all 4 files (Shape+Topology.swift and "
          f"Shape+Drawing.swift\n  in full, including their OTHER lanes): {len(used)}")
    print(f"  of those, bridge FUNCTIONS called: {len(calls)}, "
          f"types/enums referenced: {len(types)}, unresolved: {len(unresolved)}  "
          f"{', '.join(sorted(unresolved)) if unresolved else ''}")
    print()

    lane_calls = {s: files for s, files in calls.items() if s.startswith(LANE_CALL_PREFIXES)}
    lane_types = {s: files for s, files in types.items() if s.startswith(LANE_CALL_PREFIXES)}
    print(f"THIS LANE's calls only (name starts with {LANE_CALL_PREFIXES}):")
    print(f"  bridge FUNCTIONS called         : {len(lane_calls)}")
    print(f"  bridge types/enums referenced   : {len(lane_types)}")
    by_mm = collections.Counter()
    for files in lane_calls.values():
        for f in files:
            by_mm[f] += 1
    print("  bridge calls per .mm:")
    for f, n in by_mm.most_common():
        print(f"    {f:<40} {n:>3}")

    if args.calls:
        print()
        for sym in sorted(lane_calls):
            print(f"    {sym:<40} <- {', '.join(sorted(used[sym]))}  "
                  f"({', '.join(sorted(lane_calls[sym]))})")
        for sym in sorted(lane_types):
            print(f"    {sym:<40} <- {', '.join(sorted(used[sym]))}  [type/enum]")

    print()
    print("adjacent files that call OCCT but not into this lane's packages:")
    for name, why in ADJACENT_NOT_IN_LANE.items():
        print(f"  {name + '.swift':<20} {why}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
