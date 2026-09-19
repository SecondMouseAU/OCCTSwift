#!/usr/bin/env python3
"""CENSUS, not a gate: `docs/API_REFERENCE.md` category-row entries that resolve to nothing.

#1679. `API_REFERENCE.md`'s category tables carry a third column listing the operations in each
category. Nothing checks those names against the Swift surface, so a public API can be **removed**
and its name left behind in a row, with every gate green:

  * #1666 removed `ExtremaElSS.planeToSphere` and `sphereToSphere` from `Sources/`; the row kept
    listing all three. Caught by hand during the 2026-09-08 merge sequence and fixed in PR #1678.
  * #1634 removed `revolutionToElementary`; the Healing/Analysis row still listed it until this
    census found it.

`count-operations.py` cannot catch either: it compares the three headline totals against the
derived operation count and treats the per-category rows as illustrative, which the file itself
says. `check-docs-existence.py` (#802) reads `docs/reference/` pages, never `API_REFERENCE`'s
tables.

WHY THIS IS A CENSUS AND NOT A GATE
-----------------------------------
The third column is prose as much as it is API. Measured over 468 rows and 2,588 strict-identifier
entries, ~3% resolve to nothing, and the residue is NOT all stale:

  * **Umbrella names.** `booleanCheck` stands for `OCCTShapeBooleanCheckSingle` AND
    `...CheckPair`; no single declaration bears the name. `OCCTShapeBooleanCheck` exists only
    inside a comment.
  * **Abbreviations.** `thruSectionsCreate` is the row's name for
    `OCCTShapeThruSectionsCreate`.
  * **Category labels.** `boss` names a recognised feature kind, not a callable.

Separating those from a genuine removal needs a name-mapping the rows do not carry, so a gate here
would fail on correct documentation. Per `okf/policies/static-gates.md`'s gate/census distinction,
this reports and always exits 0; a human adjudicates. #1407's precedent is the same: measure the
rate before deciding whether it can gate.

    python3 Scripts/census-api-reference-rows.py
    python3 Scripts/census-api-reference-rows.py --self-test
"""

from __future__ import annotations

import argparse
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
API_REFERENCE = os.path.join(ROOT, "docs", "API_REFERENCE.md")

ROW = re.compile(r"^\| \*\*(?P<cat>.+?)\*\* \| (?P<count>\d+) \| (?P<names>.+?) \|\s*$")
IDENT = re.compile(r"^[a-z][A-Za-z0-9]*$")
CALL = re.compile(r"^([a-z][A-Za-z0-9]*)\(")
DECL = re.compile(r"\b(?:func|var|let|case)\s+([a-zA-Z_][A-Za-z0-9_]*)")
BRIDGE = re.compile(r"\b(OCCT[A-Za-z0-9_]*)")

# Entries known to be prose rather than a symbol. Each needs a reason; this is the census's own
# record of what it has already adjudicated, so a re-run surfaces only what is new.
ADJUDICATED = {
    "booleanCheck": "umbrella for OCCTShapeBooleanCheckSingle and ...CheckPair",
    "boss": "a recognised feature kind in the Feature-Based row, not a callable",
}


def declared_names(root: str) -> set[str]:
    out: set[str] = set()
    for base, _dirs, files in os.walk(root):
        for fn in files:
            if not fn.endswith((".swift", ".h")):
                continue
            pat = DECL if fn.endswith(".swift") else BRIDGE
            with open(os.path.join(base, fn), encoding="utf-8", errors="ignore") as fh:
                for line in fh:
                    for m in pat.finditer(line):
                        out.add(m.group(1))
    return out


def rows(path: str):
    with open(path, encoding="utf-8") as fh:
        for i, line in enumerate(fh, 1):
            m = ROW.match(line)
            if m:
                yield i, m.group("cat"), int(m.group("count")), m.group("names")


def base_of(entry: str) -> str | None:
    """The symbol an entry names, or None when the entry is not identifier-shaped."""
    m = CALL.match(entry)
    if m:
        return m.group(1)
    return entry if IDENT.match(entry) else None


def unresolved(path: str, swift: set[str], bridge_blob: str, swift_lower: set[str]):
    for line_no, cat, _count, names in rows(path):
        for raw in names.split(", "):
            entry = raw.strip()
            base = base_of(entry)
            if base is None or base in ADJUDICATED:
                continue
            low = base.lower()
            if low in swift_lower or low in bridge_blob:
                continue
            yield line_no, cat, entry


def census() -> int:
    swift = declared_names(os.path.join(ROOT, "Sources", "OCCTSwift"))
    bridge = declared_names(os.path.join(ROOT, "Sources", "OCCTBridge", "include"))
    swift_lower = {s.lower() for s in swift}
    bridge_blob = " ".join(bridge).lower()

    found = list(unresolved(API_REFERENCE, swift, bridge_blob, swift_lower))
    total = sum(1 for _l, _c, _n, names in rows(API_REFERENCE)
                for raw in names.split(", ") if base_of(raw.strip()))

    print("census-api-reference-rows: docs/API_REFERENCE.md category-row entries")
    print(f"  identifier-shaped entries checked: {total}")
    print(f"  adjudicated as prose (see ADJUDICATED): {len(ADJUDICATED)}")
    print(f"  resolving to nothing in Sources/: {len(found)}")
    if found:
        print()
        for line_no, cat, entry in found:
            print(f"  API_REFERENCE.md:{line_no}  {cat}: {entry}")
        print()
        print("  Each is a candidate, not a defect. A removed API leaves this shape, and so do an")
        print("  umbrella name, an abbreviation and a category label. Adjudicate, then either fix")
        print("  the row or add the entry to ADJUDICATED with its reason.")
    return 0


def self_test() -> int:
    """Prove the census reports what it claims, and stays silent on what it should not."""
    cases = []

    swift = {"realThing", "anotherThing"}
    swift_lower = {s.lower() for s in swift}
    blob = "occtshaperealbridgething occtshapethrusectionscreate"

    import tempfile

    def run(table: str):
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False, encoding="utf-8") as fh:
            fh.write(table)
            p = fh.name
        try:
            return list(unresolved(p, swift, blob, swift_lower))
        finally:
            os.unlink(p)

    # 1. A removed API is reported. This is #1666's and #1634's shape.
    got = run("| **Cat** | 1 | goneForever |\n")
    cases.append(("a name resolving to nothing is reported", len(got) == 1))

    # 2. A live Swift declaration is not reported.
    got = run("| **Cat** | 1 | realThing |\n")
    cases.append(("a live Swift name is silent", got == []))

    # 3. A bridge abbreviation is not reported, which is the largest false-positive class.
    got = run("| **Cat** | 1 | thruSectionsCreate |\n")
    cases.append(("a bridge abbreviation is silent", got == []))

    # 4. Prose is not identifier-shaped and must never be reported.
    got = run("| **Cat** | 2 | pipe sweep, union (+) |\n")
    cases.append(("prose entries are skipped", got == []))

    # 5. A call-shaped entry resolves through its base name.
    got = run("| **Cat** | 1 | realThing(with:) |\n")
    cases.append(("a call-shaped entry resolves on its base", got == []))

    # 6. An adjudicated entry stays silent even though it resolves to nothing.
    got = run("| **Cat** | 1 | booleanCheck |\n")
    cases.append(("an adjudicated entry is suppressed", got == []))

    # 7. A non-row line is ignored entirely.
    got = run("Some prose about goneForever in a paragraph.\n")
    cases.append(("non-table lines are ignored", got == []))

    failures = 0
    for label, ok in cases:
        print(f"  {'PASS' if ok else 'FAIL'}  {label}")
        failures += 0 if ok else 1
    print(f"\n{len(cases) - failures}/{len(cases)} self-test cases pass")
    return 1 if failures else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if not os.path.isfile(API_REFERENCE):
        print("run me from the repo root", file=sys.stderr)
        return 2
    return self_test() if args.self_test else census()


if __name__ == "__main__":
    sys.exit(main())
