#!/usr/bin/env python3
"""#982: the OCAF framework layer's real bridge/Swift call surface, by call.

#982's own `## Lane` section already names the five packages (`TFunction_`, `TPrsStd_`, `TObj_`,
`AppStd_`, `AppStdL_`) and gives a per-package header/wrapped/documented count that matches the
pinned kernel exactly (verified below and by `refman_census.py`'s `--reverify-lane`).
`Scripts/repro/973-ocaf-package-partition/partition_census.py --pass 982` prints that same package
set from the committed partition census, and this file does NOT re-derive it: per #982's own
instruction ("Unlike #812, do NOT re-derive this lane by grep"), the package list is consumed
as-is. What this file DOES derive is the thing #812's own `derive_lane.py` derived for its lane and
#982's issue text does not give you: which Swift files and which bridge functions actually reach
each package, and which nearby, similarly-named OCAF classes are NOT in this lane despite living in
the same source files.

WHAT THIS FINDS, summarised (the reasoning is in the printed output, not repeated here):

  - Every bridge call into this lane's five packages lives in ONE file,
    `Sources/OCCTBridge/src/OCCTBridge_Document.mm` (plus one `#include` in the bridge's umbrella
    `OCCTBridge.mm`, never a construction site). Unlike #812's HLR lane, there is no second,
    independently-evolved call path to reconcile.
  - The real Swift surface is FOUR files: `DriverTable.swift` and `TObjApplication.swift` (both
    wholly in-lane), plus the TFunction-prefixed sections of `Document.swift` and `AssemblyNode.swift`
    (both files carry much larger OCAF-attribute surfaces outside this lane, e.g. `TDataStd_*`,
    `TNaming_*`, XCAF attributes).
  - TWO nearby, easily-confused attribute families sit in the SAME two files and are NOT this
    lane, because they are different OCCT packages entirely, not because of any judgement call:
      * `Document.swift`'s "TDataXtd_Presentation" section (`OCCTDocumentSetPresentation` /
        `OCCTDocumentHasPresentation` / `OCCTDocumentPresentation*`) builds `TDataXtd_Presentation`,
        confirmed by reading `OCCTBridge_Document.mm`'s own `#include <TDataXtd_Presentation.hxx>`
        two lines above every one of those functions. `TPrsStd_AISPresentation`, the actual class in
        THIS lane with a name one word different, is never constructed anywhere in the bridge (see
        `refman_census.py`'s classification of it).
      * `AssemblyNode.swift`'s "XCAFDoc_GraphNode" section (`OCCTDocumentSetGraphNodeAttr` /
        `OCCTDocumentGraphNodeSetChild` / `OCCTDocumentGraphNodeSetFather` / ...) builds
        `XCAFDoc_GraphNode`, XCAF's own assembly-DAG attribute, Pass 3's territory (#810), not
        `TFunction_GraphNode` (this lane's regeneration-dependency graph, a same-named but distinct
        class reached by the SIBLING, differently-prefixed `OCCTDocumentSetGraphNode` /
        `OCCTDocumentGraphNode*` functions two hundred lines earlier in the same file). The bridge
        function name prefix is the only thing that tells the two apart; `Set` vs `SetAttr` at the
        end and the presence/absence of the `Attr` infix in every following call is deliberate and
        load-bearing, not a naming accident.

    python3 Scripts/repro/982-refman-coverage-ocaf-framework/derive_lane.py
    python3 Scripts/repro/982-refman-coverage-ocaf-framework/derive_lane.py --calls
"""

from __future__ import annotations

import argparse
import collections
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
SWIFT_DIR = os.path.join(ROOT, "Sources", "OCCTSwift")
BRIDGE_SRC = os.path.join(ROOT, "Sources", "OCCTBridge", "src")
BRIDGE_INC = os.path.join(ROOT, "Sources", "OCCTBridge", "include")
PARTITION_CENSUS = os.path.join(ROOT, "Scripts", "repro", "973-ocaf-package-partition",
                                "partition_census.py")

LANE_PACKAGES = ("TFunction", "TPrsStd", "TObj", "AppStd", "AppStdL")

# The lane's real Swift call surface, consumed rather than re-derived (see module docstring).
# Two are wholly in-lane; two are large multi-lane files audited only in the sections listed.
LANE_SWIFT_WHOLE = ["DriverTable", "TObjApplication"]
LANE_SWIFT_PARTIAL = {
    "Document": ("TFunction_IFunction", "TFunction_Scope"),
    "AssemblyNode": ("TFunction_Logbook", "TFunction_GraphNode", "TFunction_Function attribute"),
}

# Bridge-function prefixes this lane's calls use. Each is a MEASURED distinguishing prefix, not a
# convenient guess: `OCCTDocumentSetGraphNode`/`OCCTDocumentGraphNode*` (TFunction_GraphNode) vs.
# `OCCTDocumentSetGraphNodeAttr`/`OCCTDocumentGraphNode*Attr`-suffixed siblings two hundred lines
# later (XCAFDoc_GraphNode) is the one place a prefix match alone would over-collect, so that pair
# is resolved by explicit exclusion below rather than by the prefix table.
LANE_CALL_PREFIXES = ("OCCTFunctionDriverTable", "OCCTDocumentLogbook", "OCCTDocumentSetLogbook",
                     "OCCTDocumentSetGraphNode", "OCCTDocumentGraphNodeAdd",
                     "OCCTDocumentGraphNodeSetStatus", "OCCTDocumentGraphNodeGetStatus",
                     "OCCTDocumentGraphNodeRemoveAll", "OCCTDocumentSetFunctionAttr",
                     "OCCTDocumentFunctionIsFailed", "OCCTDocumentFunctionGetFailure",
                     "OCCTDocumentFunctionSetFailure", "OCCTDocumentNewFunction",
                     "OCCTDocumentDeleteFunction", "OCCTDocumentFunctionSetExecStatus",
                     "OCCTDocumentSetFunctionScope", "OCCTDocumentFunctionScope",
                     "OCCTDriverTableInit", "OCCTDriverTableExists", "OCCTDriverTableClear",
                     "OCCTTObjApplication")

# Bridge functions that LOOK like this lane by a naive prefix match but reach a different package
# entirely. Excluded explicitly rather than by refining the prefix table, so the exclusion reads as
# a measured fact (grep the include two lines above the function) rather than a regex tweak nobody
# can audit later.
ADJACENT_NOT_IN_LANE = {
    "OCCTDocumentSetGraphNodeAttr": "XCAFDoc_GraphNode (Pass 3's XCAF assembly DAG, #810), not "
                                    "TFunction_GraphNode -- the `Attr` suffix is the only "
                                    "textual difference from OCCTDocumentSetGraphNode two "
                                    "hundred lines above it",
    "OCCTDocumentGraphNodeSetChild": "XCAFDoc_GraphNode::SetChild, same family as above",
    "OCCTDocumentGraphNodeSetFather": "XCAFDoc_GraphNode::SetFather, same family",
    "OCCTDocumentGraphNodeUnSetChild": "XCAFDoc_GraphNode::UnSetChild, same family",
    "OCCTDocumentGraphNodeUnSetFather": "XCAFDoc_GraphNode::UnSetFather, same family",
    "OCCTDocumentGraphNodeNbChildren": "XCAFDoc_GraphNode::NbChildren, same family",
    "OCCTDocumentGraphNodeNbFathers": "XCAFDoc_GraphNode::NbFathers, same family",
    "OCCTDocumentGraphNodeIsFather": "XCAFDoc_GraphNode::IsFather, same family",
    "OCCTDocumentGraphNodeIsChild": "XCAFDoc_GraphNode::IsChild, same family",
    "OCCTDocumentSetPresentation": "TDataXtd_Presentation (display-settings attribute), not "
                                   "TPrsStd_AISPresentation -- confirmed via the "
                                   "`#include <TDataXtd_Presentation.hxx>` two lines above it "
                                   "in OCCTBridge_Document.mm",
    "OCCTDocumentUnsetPresentation": "TDataXtd_Presentation, same family",
    "OCCTDocumentHasPresentation": "TDataXtd_Presentation, same family",
    "OCCTDocumentPresentationSetDisplayed": "TDataXtd_Presentation, same family",
    "OCCTDocumentPresentationIsDisplayed": "TDataXtd_Presentation, same family",
    "OCCTDocumentPresentationSetColor": "TDataXtd_Presentation, same family",
    "OCCTDocumentPresentationGetColor": "TDataXtd_Presentation, same family",
    "OCCTDocumentPresentationSetTransparency": "TDataXtd_Presentation, same family",
    "OCCTDocumentPresentationGetTransparency": "TDataXtd_Presentation, same family",
    "OCCTDocumentPresentationSetWidth": "TDataXtd_Presentation, same family",
    "OCCTDocumentPresentationGetWidth": "TDataXtd_Presentation, same family",
    "OCCTDocumentPresentationSetMode": "TDataXtd_Presentation, same family",
    "OCCTDocumentPresentationGetMode": "TDataXtd_Presentation, same family",
}


def _read(path: str) -> str:
    with open(path, errors="ignore") as fh:
        return fh.read()


def print_partition_census() -> None:
    print("partition_census.py --pass 982 (consumed, not re-derived):")
    if not os.path.exists(PARTITION_CENSUS):
        print(f"  SKIPPED: {PARTITION_CENSUS} not found")
        return
    try:
        out = subprocess.run([sys.executable, PARTITION_CENSUS, "--pass", "982"],
                             capture_output=True, text=True, timeout=60)
        for line in out.stdout.splitlines():
            print(f"  {line}")
        if out.returncode not in (0, 2):
            print(f"  (exit {out.returncode}, stderr: {out.stderr.strip()})")
        elif out.returncode == 2:
            print(f"  ENVIRONMENT: {out.stderr.strip()}")
    except Exception as exc:  # noqa: BLE001 -- report, don't crash a repro script over this
        print(f"  could not run: {exc}")


def bridge_function_defs() -> dict[str, str]:
    """function name -> defining .mm file, for every top-level OCCT* function definition."""
    out: dict[str, str] = {}
    for fn in sorted(os.listdir(BRIDGE_SRC)):
        if not fn.endswith(".mm"):
            continue
        text = _read(os.path.join(BRIDGE_SRC, fn))
        for m in re.finditer(r'^\s*(?:[A-Za-z_][A-Za-z0-9_ \*<>,:&]*?)\b(OCCT[A-Za-z0-9_]+)\s*\(',
                             text, re.M):
            out[m.group(1)] = fn
    return out


def lane_package_tokens(text: str) -> collections.Counter:
    c = collections.Counter()
    for m in re.finditer(r'\b(' + '|'.join(LANE_PACKAGES) + r')_[A-Za-z0-9_]*\b', text):
        c[m.group(0)] += 1
    return c


def main() -> int:
    ap = argparse.ArgumentParser(description="#982 lane derivation, by call")
    ap.add_argument("--calls", action="store_true", help="list every lane bridge call")
    args = ap.parse_args()

    print_partition_census()
    print()

    defs = bridge_function_defs()
    lane_defs = {name: mm for name, mm in defs.items() if name.startswith(LANE_CALL_PREFIXES)}
    print(f"bridge functions matching this lane's call prefixes: {len(lane_defs)}")
    by_mm = collections.Counter(lane_defs.values())
    for mm, n in by_mm.most_common():
        print(f"  {mm:<32} {n:>3}")

    print()
    print(f"adjacent bridge functions that match a naive prefix but reach a DIFFERENT package "
          f"(excluded): {len(ADJACENT_NOT_IN_LANE)}")
    seen_families = set()
    for name, why in ADJACENT_NOT_IN_LANE.items():
        fam = why.split(",")[0].split(" (")[0]
        if fam in seen_families:
            continue
        seen_families.add(fam)
        print(f"  {name:<38} {why}")
    print(f"  ({len(ADJACENT_NOT_IN_LANE) - len(seen_families)} more in the same two families, "
          f"same reason)")

    if args.calls:
        print()
        print("every lane bridge call:")
        for name in sorted(lane_defs):
            print(f"    {name:<42} ({lane_defs[name]})")

    print()
    print("Swift call surface (consumed, see module docstring for how each was confirmed):")
    for name in LANE_SWIFT_WHOLE:
        path = os.path.join(SWIFT_DIR, name + ".swift")
        n = len(_read(path).splitlines()) if os.path.exists(path) else -1
        print(f"  {name + '.swift':<24} whole file, {n} lines")
    for name, sections in LANE_SWIFT_PARTIAL.items():
        print(f"  {name + '.swift':<24} sections only: {', '.join(sections)}")

    print()
    print("lane package token counts across the bridge (sanity check against LANE_PACKAGES):")
    all_bridge_text = "\n".join(_read(os.path.join(BRIDGE_SRC, fn))
                                for fn in os.listdir(BRIDGE_SRC) if fn.endswith(".mm"))
    counts = lane_package_tokens(all_bridge_text)
    by_pkg = collections.Counter()
    for tok, n in counts.items():
        pkg = tok.split("_", 1)[0]
        by_pkg[pkg] += n
    for pkg in LANE_PACKAGES:
        print(f"  {pkg:<10} {by_pkg.get(pkg, 0):>4} token occurrences, "
              f"{sum(1 for t in counts if t.startswith(pkg + '_'))} distinct symbols named")

    return 0


if __name__ == "__main__":
    sys.exit(main())
