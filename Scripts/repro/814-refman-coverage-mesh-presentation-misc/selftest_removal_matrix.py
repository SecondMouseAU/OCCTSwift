#!/usr/bin/env python3
"""#814: proves `refman_census.py`'s `--self-test` guards are load-bearing, not decorative.

Same shape as #811/#812/#982/#983's own removal matrices: switch off each accepting branch of
`declares_member` and `_ATTRIBUTION_RE` in turn, re-run the self-test cases against the crippled
function, and report how many cases fail. A branch that fails 0 cases with it removed was never
exercised by anything in `SELF_TEST_CASES` and is decoration, the exact failure mode
`okf/policies/prove-the-test-fails.md` exists to catch (#812's own `data-member` shape, #982's
`base-class-walk` `None`-propagation branch, and #983's two lane-specific checks were all found
exactly this way, on their first real run rather than by design).

This lane adds a FIFTH shape to `declares_member` beyond the four every prior lane carried
(method-call, nested-type, data-member, base-class-walk): enum-value membership, found live on this
lane's own first real run (`Graphic3d_Camera::Projection_Perspective`, a genuine citation in
`docs/reference/Display.md` that no prior shape could resolve). This matrix's own first run is what
proves that fifth shape is load-bearing rather than a shape invented and never actually needed.

    python3 Scripts/repro/814-refman-coverage-mesh-presentation-misc/selftest_removal_matrix.py
"""

from __future__ import annotations

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import refman_census as census  # noqa: E402


def run_header_cases(declares_member_fn) -> tuple[int, int]:
    """Only SELF_TEST_CASES (declares_member), unaffected by any _ATTRIBUTION_RE variant."""
    passed = failed = 0
    if not os.path.isdir(census.OCCT_HEADERS):
        return 0, 0
    for cls, member, expected, _why in census.SELF_TEST_CASES:
        got = declares_member_fn(cls, member)
        if got is expected:
            passed += 1
        else:
            failed += 1
    return passed, failed


def run_parser_cases(attribution_re) -> tuple[int, int]:
    """Only PARSE_SELF_TEST_CASES (_ATTRIBUTION_RE), unaffected by any declares_member variant."""
    passed = failed = 0
    for line, expected, _why in census.PARSE_SELF_TEST_CASES:
        got = attribution_re.findall(line)
        if got == expected:
            passed += 1
        else:
            failed += 1
    return passed, failed


# ------------------------------------------------------------------------------------------------
# Each variant below re-implements `declares_member` (or a regex) with exactly one accepting shape
# disabled, mirroring the shipped function's structure so the diff is legible.
# ------------------------------------------------------------------------------------------------

def dm_no_method_call(cls, member, seen=None):
    seen = seen if seen is not None else set()
    if cls in seen:
        return False
    seen.add(cls)
    path = os.path.join(census.OCCT_HEADERS, cls + ".hxx")
    if not os.path.exists(path):
        return None
    text = census._read(path)
    # method-call shape DISABLED
    if re.search(r"\b(?:enum|class|struct|using|typedef)\s+(?:class\s+)?" + re.escape(member)
                 + r"\b", text):
        return True
    if re.search(r"\b" + re.escape(member) + r"\s*[;=]", text):
        return True
    if census._is_enum_value(text, member):
        return True
    for base in census._header_bases(cls):
        sub = dm_no_method_call(base, member, seen)
        if sub is True:
            return True
        if sub is None:
            return None
    return False


def dm_no_nested_type(cls, member, seen=None):
    seen = seen if seen is not None else set()
    if cls in seen:
        return False
    seen.add(cls)
    path = os.path.join(census.OCCT_HEADERS, cls + ".hxx")
    if not os.path.exists(path):
        return None
    text = census._read(path)
    if re.search(r"\b" + re.escape(member) + r"\s*\(", text):
        return True
    # nested-type shape DISABLED
    if re.search(r"\b" + re.escape(member) + r"\s*[;=]", text):
        return True
    if census._is_enum_value(text, member):
        return True
    for base in census._header_bases(cls):
        sub = dm_no_nested_type(base, member, seen)
        if sub is True:
            return True
        if sub is None:
            return None
    return False


def dm_no_data_member(cls, member, seen=None):
    seen = seen if seen is not None else set()
    if cls in seen:
        return False
    seen.add(cls)
    path = os.path.join(census.OCCT_HEADERS, cls + ".hxx")
    if not os.path.exists(path):
        return None
    text = census._read(path)
    if re.search(r"\b" + re.escape(member) + r"\s*\(", text):
        return True
    if re.search(r"\b(?:enum|class|struct|using|typedef)\s+(?:class\s+)?" + re.escape(member)
                 + r"\b", text):
        return True
    # data-member shape DISABLED
    if census._is_enum_value(text, member):
        return True
    for base in census._header_bases(cls):
        sub = dm_no_data_member(base, member, seen)
        if sub is True:
            return True
        if sub is None:
            return None
    return False


def dm_no_enum_value(cls, member, seen=None):
    seen = seen if seen is not None else set()
    if cls in seen:
        return False
    seen.add(cls)
    path = os.path.join(census.OCCT_HEADERS, cls + ".hxx")
    if not os.path.exists(path):
        return None
    text = census._read(path)
    if re.search(r"\b" + re.escape(member) + r"\s*\(", text):
        return True
    if re.search(r"\b(?:enum|class|struct|using|typedef)\s+(?:class\s+)?" + re.escape(member)
                 + r"\b", text):
        return True
    if re.search(r"\b" + re.escape(member) + r"\s*[;=]", text):
        return True
    # enum-value shape DISABLED
    for base in census._header_bases(cls):
        sub = dm_no_enum_value(base, member, seen)
        if sub is True:
            return True
        if sub is None:
            return None
    return False


def dm_no_base_walk(cls, member, seen=None):
    seen = seen if seen is not None else set()
    if cls in seen:
        return False
    seen.add(cls)
    path = os.path.join(census.OCCT_HEADERS, cls + ".hxx")
    if not os.path.exists(path):
        return None
    text = census._read(path)
    if re.search(r"\b" + re.escape(member) + r"\s*\(", text):
        return True
    if re.search(r"\b(?:enum|class|struct|using|typedef)\s+(?:class\s+)?" + re.escape(member)
                 + r"\b", text):
        return True
    if re.search(r"\b" + re.escape(member) + r"\s*[;=]", text):
        return True
    if census._is_enum_value(text, member):
        return True
    # base-class-walk DISABLED entirely
    return False


# The shipped `_ATTRIBUTION_RE` requires a LEADING backtick (a literal `` ` `` before the class
# name) but imposes no closing anchor at all (so `` `Foo::Bar()` `` matches with the member captured
# as bare `Bar`, parens and all left outside the group). Each variant below flips exactly one of
# those two choices to prove it is deliberate, not incidental.
_RE_CLOSING_BACKTICK_IMPOSED = re.compile(
    r"`([A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)?)::([A-Za-z_][A-Za-z0-9_]*)`")

_RE_NO_LEADING_BACKTICK_IMPOSED = re.compile(
    r"([A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)?)::([A-Za-z_][A-Za-z0-9_]*)")


def main() -> int:
    if not os.path.isdir(census.OCCT_HEADERS):
        print(f"SKIPPED: {census.OCCT_HEADERS} not present; the header-reading half of every "
              "variant below cannot run without it (the normal case in CI / a fresh clone)")
        return 0

    header_total = len(census.SELF_TEST_CASES)
    parser_total = len(census.PARSE_SELF_TEST_CASES)
    hp, hf = run_header_cases(census.declares_member)
    pp, pf = run_parser_cases(census._ATTRIBUTION_RE)
    print(f"declares_member baseline: {hp}/{header_total} cases pass unmodified")
    print(f"_ATTRIBUTION_RE baseline: {pp}/{parser_total} cases pass unmodified")
    if hf or pf:
        print(f"  BASELINE ITSELF FAILS {hf + pf} CASE(S): fix refman_census.py before "
              "trusting this matrix")
        return 1
    print()

    variants = [
        ("method-call", dm_no_method_call),
        ("nested-type", dm_no_nested_type),
        ("data-member", dm_no_data_member),
        ("enum-value", dm_no_enum_value),
        ("base-class-walk", dm_no_base_walk),
    ]
    exit_code = 0
    for name, fn in variants:
        _passed, failed = run_header_cases(fn)
        tag = "load-bearing" if failed > 0 else "DECORATION -- no case needs this shape"
        print(f"  {name:<18} disabled -> {failed}/{header_total} cases fail  [{tag}]")
        if failed == 0:
            exit_code = 1

    print()
    print(f"_ATTRIBUTION_RE baseline: {pp}/{parser_total} cases pass with the shipped pattern")
    for name, are in [
        ("closing-backtick-anchor", _RE_CLOSING_BACKTICK_IMPOSED),
        ("no-leading-backtick", _RE_NO_LEADING_BACKTICK_IMPOSED),
    ]:
        _passed, failed = run_parser_cases(are)
        tag = "load-bearing" if failed > 0 else "DECORATION"
        print(f"  {name:<26} imposed -> {failed}/{parser_total} cases fail  [{tag}]")
        if failed == 0:
            exit_code = 1

    # classify() ordering + gaps.md exclusion, same two checks every prior lane's matrix runs.
    print()
    cache = census.build_cache()

    def tally():
        t = {"ok": 0, "deliberate, recorded": 0, "under": 0}
        for pkg in census.LANE_CLASSES:
            for cls in census.LANE_CLASSES[pkg]:
                v, _n, _b, _d = census.classify(cls, cache)
                t[v] += 1
        return t

    real = tally()
    print(f"classify baseline (real tree): {real}")

    # docs-first ordering: check `docs` before `bridge`/`CURATED` (loses the wrapped-first rule)
    orig_classify = census.classify

    def classify_docs_first(cls, cache):
        bridge = census.named_in_bridge(cls, cache)
        docs = census.named_in_docs(cls, cache)
        if docs:
            return ("ok", "documented (docs-first variant)", bridge, docs)
        if bridge:
            return ("ok", "wrapped", bridge, docs)
        if cls in census.CURATED:
            label, why = census.CURATED[cls]
            if census.recorded_in_gaps(cls, cache):
                return ("deliberate, recorded", f"{label}: {why}", bridge, docs)
            return ("under", f"{label}: {why}", bridge, docs)
        if census.recorded_in_gaps(cls, cache):
            return ("deliberate, recorded", "named in gaps.md", bridge, docs)
        return ("under", "neither wrapped nor documented", bridge, docs)

    census.classify = classify_docs_first

    def tally_with_gaps_as_docs():
        # also fold gaps.md text into the "docs" test, per the same combined variant every prior
        # lane's matrix runs
        t = {"ok": 0, "deliberate, recorded": 0, "under": 0}
        for pkg in census.LANE_CLASSES:
            for cls in census.LANE_CLASSES[pkg]:
                bridge = census.named_in_bridge(cls, cache)
                docs = census.named_in_docs(cls, cache)
                gaps_hit = census.recorded_in_gaps(cls, cache)
                if docs or gaps_hit:
                    t["ok"] += 1
                elif bridge:
                    t["ok"] += 1
                else:
                    t["under"] += 1
        return t

    combined = tally_with_gaps_as_docs()
    ordering_only = tally()
    census.classify = orig_classify

    print(f"  docs-first AND gaps.md-as-docs -> {combined}  "
          f"[{'load-bearing' if combined != real else 'redundant on this lane'}]")
    print(f"    ordering alone                -> {ordering_only}  "
          f"[{'load-bearing' if ordering_only != real else 'redundant on this lane'}]")

    if combined == real:
        exit_code = 1

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
