#!/usr/bin/env python3
"""Derive the OCCTBridge.h -> per-domain header split from the .mm files (#395).

The implementation side of the bridge was split into 16 domain files long ago; the header
followed in #395, into 15 per-domain headers plus a slim umbrella (OCCTBridge.mm itself has no
domain header of its own -- its 2 functions live in the umbrella). This computes, for every
function declared across those 16 header files, which .mm file defines it, which is the only
thing the split needs to be decided by. Run it before touching the split and again afterwards to
prove nothing moved to the wrong header.

    python3 Scripts/derive-bridge-header-split.py            # print the manifest summary
    python3 Scripts/derive-bridge-header-split.py --list      # print every symbol and its target
    python3 Scripts/derive-bridge-header-split.py --verify    # exit 1 if the split is not total

Exits 2 if run from anywhere but the repo root, matching the other gate scripts (#625).

Why this is a script and not a list in an issue: the repo's history is full of censuses that were
built by grep, written into an issue body, and then turned out to be wrong once measured (#558,
#571, #583, #595, #573). A derivation that can be re-run does not go stale in the same way.

Before #395 this read a single 21,896-line OCCTBridge.h. After #395 the declarations live across
16 files (Sources/OCCTBridge/include/OCCTBridge*.h); this reads all of them and concatenates their
text before deriving, so the script keeps meaning the same thing (does every declared function map
to exactly one .mm file) whether run pre-split, mid-split, or on the settled post-split tree.
"""

import argparse
import collections
import glob
import json
import os
import re
import sys

SRC_DIR = "Sources/OCCTBridge/src"
HEADER_DIR = "Sources/OCCTBridge/include"
UMBRELLA = os.path.join(HEADER_DIR, "OCCTBridge.h")

# A definition line in a .mm: optional return type, then the OCCT-prefixed name, then '('.
DEFN = re.compile(r"^[A-Za-z_][\w\s\*\(\)<>,:]*?\b(OCCT[A-Za-z0-9_]+)\s*\(", re.M)
# Any OCCT-prefixed name used in call/declaration position in the header.
DECL = re.compile(r"\b(OCCT[A-Za-z0-9_]+)\s*\(")
# Opaque handle typedefs stay in the umbrella header, they are not functions.
TYPEDEF = re.compile(r"typedef\s+struct\s+\w+\s*\*\s*(OCCT[A-Za-z0-9_]+)\s*;")


def target_header(mm_name):
    """OCCTBridge_Modeling.mm -> OCCTBridge_Modeling.h; OCCTBridge.mm -> the umbrella."""
    stem = mm_name[:-3]
    return "OCCTBridge.h" if stem == "OCCTBridge" else f"{stem}.h"


def header_files():
    """All 16 bridge header files: the umbrella plus the 15 per-domain headers (#395)."""
    return sorted(glob.glob(os.path.join(HEADER_DIR, "OCCTBridge*.h")))


def derive():
    definitions = {}
    for name in sorted(os.listdir(SRC_DIR)):
        if name.endswith(".mm"):
            text = open(os.path.join(SRC_DIR, name), errors="ignore").read()
            definitions[name] = set(DEFN.findall(text))

    header = ""
    for path in header_files():
        header += open(path, errors="ignore").read()
    declared = set(DECL.findall(header)) - set(TYPEDEF.findall(header))

    mapping, ambiguous, unmapped = {}, {}, []
    for symbol in sorted(declared):
        owners = [mm for mm, names in definitions.items() if symbol in names]
        if len(owners) == 1:
            mapping[symbol] = target_header(owners[0])
        elif owners:
            ambiguous[symbol] = [target_header(o) for o in owners]
        else:
            unmapped.append(symbol)
    return mapping, ambiguous, unmapped


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true", help="print every symbol and its target header")
    ap.add_argument("--verify", action="store_true", help="exit 1 unless every symbol maps to one header")
    ap.add_argument("--json", metavar="PATH", help="write the manifest as JSON")
    args = ap.parse_args()

    if not os.path.isdir(SRC_DIR) or not os.path.isfile(UMBRELLA):
        print(f"error: run from the repo root (expected {SRC_DIR} and {UMBRELLA})", file=sys.stderr)
        return 2

    mapping, ambiguous, unmapped = derive()

    if args.list:
        for symbol, header in sorted(mapping.items(), key=lambda kv: (kv[1], kv[0])):
            print(f"{header}\t{symbol}")
    else:
        for header, count in collections.Counter(mapping.values()).most_common():
            print(f"  {count:5d}  {header}")

    print(f"\nmapped: {len(mapping)}   ambiguous: {len(ambiguous)}   unmapped: {len(unmapped)}")

    for symbol, headers in sorted(ambiguous.items()):
        print(f"  AMBIGUOUS  {symbol}: {', '.join(headers)}", file=sys.stderr)
    for symbol in unmapped:
        print(f"  UNMAPPED   {symbol}", file=sys.stderr)

    if args.json:
        json.dump(mapping, open(args.json, "w"), indent=0, sort_keys=True)
        print(f"manifest written to {args.json}")

    if args.verify and (ambiguous or unmapped):
        print(
            "\nThe split is not total. Resolve each symbol above before moving declarations:\n"
            "  AMBIGUOUS means two .mm files define the same symbol, which is a real defect.\n"
            "  UNMAPPED means the header declares something no .mm defines, so it is either dead\n"
            "  or defined somewhere the parser does not look.",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
