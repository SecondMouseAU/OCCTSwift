#!/usr/bin/env python3
"""Prove each guard in `refman_census`'s method-attribution detector is load-bearing (#810).

`okf/policies/prove-the-test-fails.md`: a self-test that passes with a guard removed proves
nothing about that guard. The detector has two halves and this script covers both.

`declares_member` has four accepting shapes; the matrix disables each in turn, in memory, re-runs
the ten header cases, and reports which fail. `_ATTRIBUTION_RE` has two constraints (a leading
backtick, and no anchor on a closing one); the matrix restores each constraint's opposite and
re-runs the four parser cases. A guard that fails no case is decorative, and either the guard or
the battery is wrong.

The closing-backtick anchor is why this half exists. The pattern was anchored on it in this
file's first version, which silently skipped `XCAFDoc_ShapeMapTool::Map().Extent()`, a real
finding, and no case at the time could tell.

Run from anywhere:

    python3 Scripts/repro/810-refman-document-xde/selftest_removal_matrix.py

Exits 1 if any guard fails zero cases, or if either unmodified battery does not pass. The parser
half runs anywhere; the header half needs `Libraries/OCCT.xcframework` and reports SKIPPED without
it, which is the case in CI.
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


# Each variant re-imposes one constraint the shipped pattern deliberately does not have.
PATTERN_VARIANTS = {
    "closing-backtick-anchor": r"`([A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)?)::([A-Za-z_][A-Za-z0-9_]*)`",
    "no-leading-backtick": r"([A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)?)::([A-Za-z_][A-Za-z0-9_]*)",
}


def parser_matrix() -> int:
    """Run the parser cases against each variant; every variant must fail at least one."""
    cases = census.PARSE_SELF_TEST_CASES
    baseline = [
        (line, expected, census._ATTRIBUTION_RE.findall(line) == expected)
        for line, expected, _why in cases
    ]
    if not all(ok for *_r, ok in baseline):
        print("PARSER BASELINE FAILED: the shipped pattern does not pass its own cases.")
        return 1
    print(f"parser baseline: {len(cases)}/{len(cases)} cases pass with the shipped pattern")
    print()

    exit_code = 0
    for name, pattern in PATTERN_VARIANTS.items():
        rx = re.compile(pattern)
        broken = [line for line, expected, _why in cases if rx.findall(line) != expected]
        status = "load-bearing" if broken else "DECORATIVE"
        print(f"{name:26} imposed -> {len(broken)}/{len(cases)} cases fail  [{status}]")
        for b in broken:
            print(f"                            {b[:78]!r}")
        if not broken:
            print("                            No case distinguishes this constraint. The pattern")
            print("                            could be tightened this way with nothing noticing.")
            exit_code = 1
        print()
    return exit_code


def main() -> int:
    exit_parser = parser_matrix()

    if not os.path.isdir(census.OCCT_HEADERS):
        print("HEADER MATRIX SKIPPED: Libraries/OCCT.xcframework is not present, so the pinned")
        print("headers that half reads are unavailable. This is the normal case in CI and a")
        print("fresh clone. The parser matrix above ran.")
        return exit_parser

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
    print(f"header baseline: {len(cases)}/{len(cases)} cases pass unmodified")
    print()

    exit_code = exit_parser
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
        print("MATRIX PASSED: every accepting shape in declares_member, and every constraint the")
        print("attribution pattern deliberately omits, fails at least one case.")
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
