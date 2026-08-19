#!/usr/bin/env python3
"""Prove each guard in `refman_census.declares_member` is load-bearing (#810).

`okf/policies/prove-the-test-fails.md`: a self-test that passes with a guard removed proves
nothing about that guard. `refman_census.py --self-test` has eight cases and `declares_member`
has four accepting shapes; this script disables each shape in turn, in memory, re-runs the eight
cases, and reports which fail. A shape that fails no case is decorative and either the shape or
the case is wrong.

Run from anywhere:

    python3 Scripts/repro/810-refman-document-xde/selftest_removal_matrix.py

Exits 1 if any shape fails zero cases, or if the unmodified battery does not pass. Needs
`Libraries/OCCT.xcframework`, like the self-test itself; reports SKIPPED and exits 0 without it,
which is the case in CI.
"""

from __future__ import annotations

import importlib.util
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CENSUS = os.path.join(HERE, "refman_census.py")

_spec = importlib.util.spec_from_file_location("refman_census_810", CENSUS)
census = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(census)

# Each shape is the regex `declares_member` tries, plus the base-class walk. Removing a shape means
# making that branch never fire.
SHAPES = ["method-call", "nested-type", "data-member", "base-class-walk"]


def declares_member_without(cls: str, member: str, disabled: str,
                            seen: set[str] | None = None) -> bool | None:
    """A copy of `census.declares_member` with one accepting shape switched off."""
    seen = seen if seen is not None else set()
    if cls in seen:
        return False
    seen.add(cls)
    path = os.path.join(census.OCCT_HEADERS, cls + ".hxx")
    if not os.path.exists(path):
        return None
    text = census._read(path)
    if disabled != "method-call" and re.search(r"\b" + re.escape(member) + r"\s*\(", text):
        return True
    if disabled != "nested-type" and re.search(
            r"\b(?:enum|class|struct|using|typedef)\s+(?:class\s+)?" + re.escape(member) + r"\b",
            text):
        return True
    if disabled != "data-member" and re.search(r"\b" + re.escape(member) + r"\s*[;=]", text):
        return True
    if disabled != "base-class-walk":
        for base in census._header_bases(cls):
            if declares_member_without(base, member, disabled, seen) is True:
                return True
    return False


def main() -> int:
    if not os.path.isdir(census.OCCT_HEADERS):
        print("SKIPPED: Libraries/OCCT.xcframework is not present, so the pinned headers this")
        print("matrix reads are unavailable. This is the normal case in CI and a fresh clone.")
        return 0

    cases = census.SELF_TEST_CASES
    baseline = [
        (cls, member, expected, census.declares_member(cls, member) is expected)
        for cls, member, expected, _why in cases
    ]
    if not all(ok for *_r, ok in baseline):
        print("BASELINE FAILED: the unmodified self-test does not pass. Fix that first.")
        for cls, member, expected, ok in baseline:
            if not ok:
                print(f"  {cls}::{member} expected {expected}")
        return 1
    print(f"baseline: {len(cases)}/{len(cases)} cases pass unmodified")
    print()

    exit_code = 0
    for shape in SHAPES:
        broken = []
        for cls, member, expected, _why in cases:
            got = declares_member_without(cls, member, shape)
            if got is not expected:
                broken.append(f"{cls}::{member}")
        status = "load-bearing" if broken else "DECORATIVE"
        print(f"{shape:18} disabled -> {len(broken)}/{len(cases)} cases fail  [{status}]")
        for b in broken:
            print(f"                     {b}")
        if not broken:
            print("                     No case distinguishes this shape. Either the shape is")
            print("                     dead code or the battery is missing a case for it.")
            exit_code = 1
        print()

    if exit_code == 0:
        print("MATRIX PASSED: every accepting shape in declares_member fails at least one case.")
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
