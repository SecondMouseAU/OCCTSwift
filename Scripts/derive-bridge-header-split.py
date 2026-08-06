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
    python3 Scripts/derive-bridge-header-split.py --self-test # prove each failure mode is caught

Exits 2 if run from anywhere but the repo root, matching the other gate scripts (#625).
`--self-test` runs on synthetic fixtures and does not need the repo tree, so it is exempt.

Why this is a script and not a list in an issue: the repo's history is full of censuses that were
built by grep, written into an issue body, and then turned out to be wrong once measured (#558,
#571, #583, #595, #573). A derivation that can be re-run does not go stale in the same way.

Before #395 this read a single 21,896-line OCCTBridge.h. After #395 the declarations live across
16 files (Sources/OCCTBridge/include/OCCTBridge*.h). `--verify` originally only asked whether every
declared function maps to exactly one .mm file, which was the whole question before there was more
than one header to get wrong. #673: after the split there is a second question -- is each
declaration actually in the header its .mm owns? A declaration can sit in the wrong domain header
and still map to exactly one .mm, so the first question passing says nothing about the second.
This now tracks declarations per header file, not just concatenated across all of them, so it can
answer both: MISFILED symbols below are declared somewhere other than the header their .mm owns.

Comments are excluded from the per-header declaration scan. The umbrella's cross-reference index
names hundreds of symbols in `// Class -> OCCTFoo (aside)` lines, and a mention followed by a
parenthetical aside matches the same `name(` shape a real declaration does -- reading those as
declarations was how a hand check for #673 first turned up 29 apparent duplicates, all of them
comment mentions rather than a second real declaration.
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
LINE_COMMENT = re.compile(r"//[^\n]*")
BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)


def strip_comments(text):
    """Remove // line comments and /* */ block comments (#673).

    A per-header declaration scan has to run on this, not the raw text: the cross-reference
    index names symbols in `// Class -> OCCTFoo (aside)` lines, and a parenthetical aside
    right after the name matches the same `name(` shape DECL looks for. Left in, a mention
    inside a comment reads as a second declaration of a symbol that is for real declared
    somewhere else -- the false "duplicate" shape #673's hand check found.
    """
    return LINE_COMMENT.sub("", BLOCK_COMMENT.sub(" ", text))


def target_header(mm_name):
    """OCCTBridge_Modeling.mm -> OCCTBridge_Modeling.h; OCCTBridge.mm -> the umbrella."""
    stem = mm_name[:-3]
    return "OCCTBridge.h" if stem == "OCCTBridge" else f"{stem}.h"


def header_files():
    """All 16 bridge header files: the umbrella plus the 15 per-domain headers (#395)."""
    return sorted(glob.glob(os.path.join(HEADER_DIR, "OCCTBridge*.h")))


def declared_in(header_text):
    """The real (non-comment) OCCT-prefixed declarations in one header's text."""
    stripped = strip_comments(header_text)
    return set(DECL.findall(stripped)) - set(TYPEDEF.findall(stripped))


def compute(mm_texts, header_texts):
    """Everything this script reports, computed from in-memory text.

    Kept separate from disk I/O so `--self-test` can run the exact same logic `--verify`
    runs, on synthetic fixtures, rather than a parallel implementation that could drift
    from what the real gate checks. `mm_texts` and `header_texts` are name -> file text.

    Returns (mapping, ambiguous, unmapped, misfiled):
      mapping    symbol -> the one header its owning .mm's domain header should be
      ambiguous  symbol -> headers, when more than one .mm defines the same symbol
      unmapped   symbols the header(s) declare that no .mm defines
      misfiled   (symbol, wrong headers, expected header) for #673: a header, other than
                 the one mapping says the symbol belongs in, that declares it for real.
                 Checked per declaration site, not per symbol, so a symbol correctly
                 declared in its own header AND, wrongly, also in a second one is still
                 reported for that second header even though a correct declaration
                 exists elsewhere.
    """
    # Comment-stripped on every path, not just the misfiled one. `declared` and `definitions`
    # scanned raw text until #673's review pointed out they carry the identical false-positive
    # shape this script's own `home` computation was hardened against: a symbol named only inside
    # a comment. In a header that reads as a spurious `declared` entry, and if nothing defines it,
    # a false UNMAPPED; in a `.mm` it makes one file look like a second definer, a false AMBIGUOUS.
    # The umbrella header's cross-reference index block is exactly the shape that would do it.
    # Today's tree is clean either way, so this is hardening rather than a fix, but leaving one of
    # three scans raw while hardening the other two is the inconsistency that lets it come back.
    definitions = {mm: set(DEFN.findall(strip_comments(text))) for mm, text in mm_texts.items()}

    concatenated = strip_comments("".join(header_texts.values()))
    declared = set(DECL.findall(concatenated)) - set(TYPEDEF.findall(concatenated))

    mapping, ambiguous, unmapped = {}, {}, []
    for symbol in sorted(declared):
        owners = [mm for mm, names in definitions.items() if symbol in names]
        if len(owners) == 1:
            mapping[symbol] = target_header(owners[0])
        elif owners:
            ambiguous[symbol] = [target_header(o) for o in owners]
        else:
            unmapped.append(symbol)

    home = collections.defaultdict(set)
    for header, text in header_texts.items():
        for symbol in declared_in(text):
            home[symbol].add(header)

    misfiled = []
    for symbol, expected in mapping.items():
        wrong = home.get(symbol, set()) - {expected}
        if wrong:
            misfiled.append((symbol, sorted(wrong), expected))

    return mapping, ambiguous, unmapped, sorted(misfiled)


def derive():
    mm_texts = {}
    for name in sorted(os.listdir(SRC_DIR)):
        if name.endswith(".mm"):
            mm_texts[name] = open(os.path.join(SRC_DIR, name), errors="ignore").read()

    header_texts = {}
    for path in header_files():
        header_texts[os.path.basename(path)] = open(path, errors="ignore").read()

    return compute(mm_texts, header_texts)


# Each case is its own tiny .mm/.h universe, not a shared fixture, so removing one guard
# cannot make an unrelated case fail for the wrong reason. `check` is handed compute()'s
# own return value and answers True/False for that one case's claim only -- the same
# function --verify calls, not a parallel implementation that could drift from it.
SELF_TEST = [
    (
        "clean split: nothing flagged",
        {"OCCTBridge_A.mm": "void OCCTFooA(void) {}\n"},
        {"OCCTBridge_A.h": "void OCCTFooA(void);\n"},
        lambda mapping, ambiguous, unmapped, misfiled: (
            mapping.get("OCCTFooA") == "OCCTBridge_A.h" and not ambiguous and not unmapped and not misfiled
        ),
    ),
    (
        "ambiguous: two .mm files define the same symbol",
        {
            "OCCTBridge_A.mm": "void OCCTFooA(void) {}\n",
            "OCCTBridge_B.mm": "void OCCTFooA(void) {}\n",
        },
        {"OCCTBridge_A.h": "void OCCTFooA(void);\n"},
        lambda mapping, ambiguous, unmapped, misfiled: "OCCTFooA" in ambiguous,
    ),
    (
        "unmapped: header declares a symbol no .mm defines",
        {"OCCTBridge_A.mm": ""},
        {"OCCTBridge_A.h": "void OCCTGhost(void);\n"},
        lambda mapping, ambiguous, unmapped, misfiled: "OCCTGhost" in unmapped,
    ),
    (
        "misfiled: declared in B.h, defined in A.mm (#673)",
        {"OCCTBridge_A.mm": "void OCCTFooA(void) {}\n"},
        {"OCCTBridge_A.h": "", "OCCTBridge_B.h": "void OCCTFooA(void);\n"},
        lambda mapping, ambiguous, unmapped, misfiled: (
            "OCCTFooA", ["OCCTBridge_B.h"], "OCCTBridge_A.h") in misfiled,
    ),
    (
        "line-comment mention elsewhere is not a misfile (#673)",
        {"OCCTBridge_A.mm": "void OCCTFooA(void) {}\n"},
        {
            "OCCTBridge_A.h": "void OCCTFooA(void);\n",
            "OCCTBridge_B.h": "// SomeClass -> OCCTFooA (see the real header)\n",
        },
        lambda mapping, ambiguous, unmapped, misfiled: not misfiled,
    ),
    (
        "block-comment mention elsewhere is not a misfile (#673)",
        {"OCCTBridge_A.mm": "void OCCTFooA(void) {}\n"},
        {
            "OCCTBridge_A.h": "void OCCTFooA(void);\n",
            "OCCTBridge_B.h": "/* mentions OCCTFooA(void) here too */\n",
        },
        lambda mapping, ambiguous, unmapped, misfiled: not misfiled,
    ),
    (
        # The review of #673 noted the six cases above all exercise the `home`/misfiled path,
        # which was hardened against comment mentions, while `declared` and `definitions` scanned
        # raw text and carried the identical shape. These two cover that, one per scan.
        "a symbol named only in a header comment is not declared (#673 review)",
        {"OCCTBridge_A.mm": "void OCCTFooA(void) {}\n"},
        {
            "OCCTBridge_A.h": "void OCCTFooA(void);\n",
            # OCCTGoneAway is defined by nothing. Counted as declared, it is a false UNMAPPED.
            "OCCTBridge_B.h": "// index: SomeClass -> OCCTGoneAway(void), retired in v1.9\n",
        },
        lambda mapping, ambiguous, unmapped, misfiled: not unmapped and "OCCTGoneAway" not in mapping,
    ),
    (
        "a symbol named only in a .mm comment does not make it a second definer (#673 review)",
        {
            "OCCTBridge_A.mm": "void OCCTFooA(void) {}\n",
            # A mention, not a definition, inside a BLOCK comment whose inner line begins with
            # the identifier. A `//` line cannot reach DEFN at all, which is anchored at ^ with
            # [A-Za-z_], so a `//` fixture here would pass with or without stripping and prove
            # nothing. This shape does reach it.
            "OCCTBridge_B.mm": "/* dispatch notes:\nvoid OCCTFooA(void) handles the planar case\n*/\n",
        },
        {"OCCTBridge_A.h": "void OCCTFooA(void);\n"},
        lambda mapping, ambiguous, unmapped, misfiled: not ambiguous and mapping.get("OCCTFooA") == "OCCTBridge_A.h",
    ),
]


def self_test():
    """Prove each failure mode this script covers is caught, and each correct shape is not."""
    failed = 0
    for name, mm_texts, header_texts, check in SELF_TEST:
        mapping, ambiguous, unmapped, misfiled = compute(mm_texts, header_texts)
        ok = check(mapping, ambiguous, unmapped, misfiled)
        failed += not ok
        print(f"  {'ok  ' if ok else 'FAIL'}  {name}")
    total = len(SELF_TEST)
    print(f"{total - failed}/{total} cases correct")
    return 1 if failed else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true", help="print every symbol and its target header")
    ap.add_argument("--verify", action="store_true", help="exit 1 unless every symbol maps to one header")
    ap.add_argument("--json", metavar="PATH", help="write the manifest as JSON")
    ap.add_argument("--self-test", action="store_true", help="prove each failure mode is caught")
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    if not os.path.isdir(SRC_DIR) or not os.path.isfile(UMBRELLA):
        print(f"error: run from the repo root (expected {SRC_DIR} and {UMBRELLA})", file=sys.stderr)
        return 2

    mapping, ambiguous, unmapped, misfiled = derive()

    if args.list:
        for symbol, header in sorted(mapping.items(), key=lambda kv: (kv[1], kv[0])):
            print(f"{header}\t{symbol}")
    else:
        for header, count in collections.Counter(mapping.values()).most_common():
            print(f"  {count:5d}  {header}")

    print(f"\nmapped: {len(mapping)}   ambiguous: {len(ambiguous)}   "
          f"unmapped: {len(unmapped)}   misfiled: {len(misfiled)}")

    for symbol, headers in sorted(ambiguous.items()):
        print(f"  AMBIGUOUS  {symbol}: {', '.join(headers)}", file=sys.stderr)
    for symbol in unmapped:
        print(f"  UNMAPPED   {symbol}", file=sys.stderr)
    for symbol, wrong, expected in misfiled:
        print(f"  MISFILED   {symbol}: declared in {', '.join(wrong)}, owned by {expected}", file=sys.stderr)

    if args.json:
        json.dump(mapping, open(args.json, "w"), indent=0, sort_keys=True)
        print(f"manifest written to {args.json}")

    if args.verify and (ambiguous or unmapped or misfiled):
        print(
            "\nThe split is not total. Resolve each symbol above before moving declarations:\n"
            "  AMBIGUOUS means two .mm files define the same symbol, which is a real defect.\n"
            "  UNMAPPED means the header declares something no .mm defines, so it is either dead\n"
            "  or defined somewhere the parser does not look.\n"
            "  MISFILED means the symbol is declared in a header other than the one its .mm owns\n"
            "  (#673) -- move the declaration to the header the summary above says it should be in.",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
